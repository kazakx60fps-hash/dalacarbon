"""Тіркелу, кіру және шығу маршруттары."""

from __future__ import annotations

from functools import wraps

from flask import Blueprint, g, redirect, render_template, request, session, url_for

from .db import (
    DuplicateUserError,
    find_taken_fields,
    find_user_by_login,
    get_db,
    get_user,
    insert_user,
    update_password_hash,
)
from .security import check_csrf, hash_password, needs_rehash, verify_dummy, verify_password
from .validators import FARM_TYPES, MESSAGES, REGIONS, validate_login, validate_registration

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
    if g.user is None:  # аккаунт өшірілген болса
        session.clear()


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

def _render_login(login_value: str, errors: dict[str, str], failed: bool, remember: bool, status: int = 200):
    html = render_template(
        "login.html",
        login_value=login_value,
        errors=errors,
        failed=failed,
        remember=remember,
    )
    return html, status


@bp.route("/login", methods=["GET", "POST"])
def login():
    if g.user:
        return redirect(url_for("main.dashboard"))
    if request.method == "GET":
        return _render_login(session.pop("login_prefill", ""), {}, failed=False, remember=False)

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

    # Сессияны жаңадан бастаймыз (session fixation-ға қарсы).
    session.clear()
    session["user_id"] = user["id"]
    session.permanent = data["remember"]
    return redirect(url_for("main.dashboard"), code=303)


@bp.post("/logout")
def logout():
    check_csrf()
    session.clear()
    return redirect(url_for("auth.login"), code=303)
