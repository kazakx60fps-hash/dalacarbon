"""Тіркелу, кіру және шығу маршруттары."""

from __future__ import annotations

import hashlib
import secrets
from functools import wraps

from flask import Blueprint, current_app, g, redirect, render_template, request, session, url_for

from .db import (
    DuplicateUserError,
    complete_password_reset,
    create_password_reset,
    find_password_reset,
    find_taken_fields,
    find_user_by_email,
    find_user_by_login,
    get_db,
    get_user,
    insert_user,
    reset_recently_requested,
    update_password_hash,
)
from .mailer import send_mail
from .security import check_csrf, hash_password, needs_rehash, verify_dummy, verify_password
from .validators import (
    FARM_TYPES,
    MESSAGES,
    REGIONS,
    validate_login,
    validate_new_password,
    validate_registration,
    validate_reset_request,
)

bp = Blueprint("auth", __name__)

# Құпиясөздер қайтадан формаға ешқашан жазылмайды.
_KEPT_FIELDS = ("email", "full_name", "username", "region", "farm_type")


# ---------- Сессия ----------

@bp.before_app_request
def load_current_user() -> None:
    """Сессиядағы user_id бойынша g.user орнатады (жоқ болса None)."""
    g.user = None
    user_id = session.get("user_id")
    if user_id is None or request.endpoint == "static":
        return
    g.user = get_user(get_db(), user_id)
    # Аккаунт өшірілсе немесе құпиясөз қалпына келтірілсе (session_epoch өседі) — сессия жабылады.
    if g.user is None or session.get("epoch", 0) != g.user["session_epoch"]:
        g.user = None
        session.clear()


def start_session(user: dict, remember: bool = False) -> None:
    """Жаңа сессия (session fixation-ға қарсы) + қазіргі дәуір белгісі."""
    session.clear()
    session["user_id"] = user["id"]
    session["epoch"] = user["session_epoch"]
    session.permanent = remember


def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if g.user is None:
            return redirect(url_for("auth.login"))
        return view(*args, **kwargs)

    return wrapped


@bp.get("/")
def index():
    return redirect(url_for("main.dashboard" if g.user else "auth.login"))


# ---------- Тіркелу ----------

def _render_register(form, errors: dict[str, str], status: int = 200):
    values = {name: form.get(name, "") for name in _KEPT_FIELDS}
    html = render_template(
        "register.html",
        values=values,
        newsletter=form.get("newsletter") == "on",
        errors=errors,
        regions=REGIONS,
        farm_types=FARM_TYPES,
    )
    return html, status


@bp.route("/register", methods=["GET", "POST"])
def register():
    if g.user:
        return redirect(url_for("main.dashboard"))
    if request.method == "GET":
        return _render_register({}, {})

    check_csrf()
    data, errors = validate_registration(request.form)

    if not errors:
        conn = get_db()
        for field in find_taken_fields(conn, data["email"], data["username"]):
            errors[field] = MESSAGES[f"{field}_taken"]

    if not errors:
        try:
            insert_user(
                conn,
                email=data["email"],
                username=data["username"],
                full_name=data["full_name"],
                password_hash=hash_password(data["password"]),
                region=data["region"],
                farm_type=data["farm_type"],
                newsletter=data["newsletter"],
            )
        except DuplicateUserError as exc:
            for field in exc.fields:
                errors[field] = MESSAGES[f"{field}_taken"]

    if errors:
        return _render_register(request.form, errors, status=422)

    # Post/Redirect/Get: бетті жаңарту форманы қайта жібермейді.
    session["registered_username"] = data["username"]
    return redirect(url_for("auth.register_success"), code=303)


@bp.get("/register/success")
def register_success():
    username = session.pop("registered_username", None)
    if not username:
        return redirect(url_for("auth.register"))
    session["login_prefill"] = username
    return render_template("register_success.html", username=username)


# ---------- Кіру ----------

def _render_login(login_value: str, errors: dict[str, str], failed: bool, remember: bool,
                  status: int = 200, notice: str | None = None, success: str | None = None):
    html = render_template(
        "login.html",
        login_value=login_value,
        errors=errors,
        failed=failed,
        remember=remember,
        auth_notice=notice,
        success_notice=success,
    )
    return html, status


@bp.route("/login", methods=["GET", "POST"])
def login():
    if g.user:
        return redirect(url_for("main.dashboard"))
    if request.method == "GET":
        return _render_login(session.pop("login_prefill", ""), {}, failed=False, remember=False,
                             notice=session.pop("auth_notice", None), success=session.pop("login_success", None))

    check_csrf()
    data, errors = validate_login(request.form)
    if errors:
        return _render_login(data["login"], errors, failed=False, remember=data["remember"], status=422)

    conn = get_db()
    user = find_user_by_login(conn, data["login"])
    if user is None:
        verify_dummy(data["password"])  # уақыт бойынша айырмашылық болмасын
        ok = False
    else:
        ok = verify_password(user["password_hash"], data["password"])

    if not ok:
        # Логин жоқ па, құпиясөз қате ме — пайдаланушыға бірдей жауап.
        return _render_login(data["login"], {}, failed=True, remember=data["remember"], status=401)

    if needs_rehash(user["password_hash"]):
        update_password_hash(conn, user["id"], hash_password(data["password"]))

    start_session(user, remember=data["remember"])
    return redirect(url_for("main.dashboard"), code=303)


@bp.post("/logout")
def logout():
    check_csrf()
    session.clear()
    return redirect(url_for("auth.login"), code=303)


# ---------- Құпиясөзді қалпына келтіру ----------
# 1) /forgot — email енгізіледі. Жауап әрқашан бірдей (бұл email тіркелген бе — білінбейді).
# 2) Хатта бір реттік сілтеме: /reset/<token>. Базада тек токеннің SHA-256 хеші, мерзімі — 30 минут.
# 3) Жаңа құпиясөз сақталғанда: барлық сілтемелер жарамсыз, барлық ашық сессиялар жабылады.

RESET_THROTTLE_SECONDS = 60
SUCCESS_RESET = "Құпиясөз жаңартылды. Жаңа құпиясөзбен кіріңіз."


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _external_url(endpoint: str, **values) -> str:
    """APP_BASE_URL берілсе — сол (Host тақырыбына сенбейміз), әйтпесе сұраныстың хосты."""
    base = current_app.config.get("APP_BASE_URL")
    if base:
        return base + url_for(endpoint, **values)
    return url_for(endpoint, _external=True, **values)


def _reset_email(link: str, ttl: int) -> str:
    return (
        "Сәлеметсіз бе!\n\n"
        "DalaCarbon AI аккаунтыңыздың құпиясөзін қалпына келтіру сұралды.\n"
        f"Жаңа құпиясөз орнату үшін сілтемені ашыңыз (ол {ttl} минут жарамды және бір рет қана қолданылады):\n\n"
        f"{link}\n\n"
        "Егер мұны сіз сұрамасаңыз, хатты елемеңіз — құпиясөзіңіз өзгермейді.\n\n"
        "— DalaCarbon AI"
    )


def _no_referrer(response):
    """Сілтемедегі токен басқа сайтқа Referer арқылы кетпесін және кэште қалмасын."""
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "no-store"
    return response


@bp.route("/forgot", methods=["GET", "POST"])
def forgot_password():
    if request.method == "GET":
        return render_template("forgot.html", email_value="", error=None)

    check_csrf()
    email, error = validate_reset_request(request.form)
    if error:
        return render_template("forgot.html", email_value=email, error=error), 422

    conn = get_db()
    user = find_user_by_email(conn, email)
    if user and not reset_recently_requested(conn, user["id"], RESET_THROTTLE_SECONDS):
        token = secrets.token_urlsafe(32)
        ttl = current_app.config["PASSWORD_RESET_TTL_MIN"]
        create_password_reset(conn, user["id"], _token_hash(token), ttl)
        link = _external_url("auth.reset_password", token=token)
        send_mail(user["email"], "DalaCarbon AI — құпиясөзді қалпына келтіру", _reset_email(link, ttl))

    # Email бар ма, жоқ па — жауап бірдей (Post/Redirect/Get).
    session["reset_sent_to"] = email
    return redirect(url_for("auth.forgot_sent"), code=303)


@bp.get("/forgot/sent")
def forgot_sent():
    email = session.pop("reset_sent_to", None)
    if not email:
        return redirect(url_for("auth.forgot_password"))
    return render_template("forgot.html", sent_to=email, ttl=current_app.config["PASSWORD_RESET_TTL_MIN"])


@bp.route("/reset/<token>", methods=["GET", "POST"])
def reset_password(token: str):
    conn = get_db()
    record = find_password_reset(conn, _token_hash(token)) if 20 <= len(token) <= 128 else None
    if record is None:
        return _no_referrer(current_app.make_response((render_template("reset.html", invalid=True), 410)))

    if request.method == "GET":
        return _no_referrer(current_app.make_response(render_template("reset.html", errors={}, username=record["username"])))

    check_csrf()
    password, errors = validate_new_password(request.form, record["username"])
    if errors:
        html = render_template("reset.html", errors=errors, username=record["username"])
        return _no_referrer(current_app.make_response((html, 422)))

    complete_password_reset(conn, record["user_id"], hash_password(password))
    session.clear()
    session["login_prefill"] = record["username"]
    session["login_success"] = SUCCESS_RESET
    return redirect(url_for("auth.login"), code=303)
