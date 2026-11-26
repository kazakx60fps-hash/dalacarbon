"""Google арқылы кіру (OAuth 2.0 + OpenID Connect, Authlib).

Ағын:
  /auth/google            → Google-дың аккаунт таңдау беті (state, nonce, PKCE)
  /auth/google/callback   → id_token тексеріледі, пайдаланушы табылады/байланысады
  /auth/google/complete   → бірінші рет кіргенде: логин, облыс, шаруашылық түрі
"""

from __future__ import annotations

from authlib.integrations.base_client.errors import OAuthError
from authlib.integrations.flask_client import OAuth
from flask import Blueprint, current_app, g, redirect, render_template, request, session, url_for

from .db import (
    DuplicateUserError,
    find_taken_fields,
    find_user_by_email,
    find_user_by_google_sub,
    get_db,
    get_user,
    insert_google_user,
    link_google,
)
from .auth import start_session
from .security import check_csrf
from .validators import FARM_TYPES, MESSAGES, REGIONS, suggest_username, validate_google_profile

bp = Blueprint("google", __name__, url_prefix="/auth/google")

_PENDING = "google_pending"
GOOGLE_METADATA_URL = "https://accounts.google.com/.well-known/openid-configuration"

NOTICES = {
    "not_configured": "Google арқылы кіру әлі бапталмаған. Әзірге логин мен құпиясөзді пайдаланыңыз.",
    "failed": "Google арқылы кіру сәтсіз аяқталды немесе тоқтатылды. Қайта көріңіз.",
    "unverified": "Бұл Google аккаунтының email-і расталмаған. Басқа аккаунтты таңдаңыз.",
}


def init_google(app) -> None:
    """GOOGLE_CLIENT_ID/SECRET берілсе ғана Google клиентін тіркейді."""
    enabled = bool(app.config.get("GOOGLE_CLIENT_ID") and app.config.get("GOOGLE_CLIENT_SECRET"))
    app.config["GOOGLE_ENABLED"] = enabled
    if enabled:
        oauth = OAuth(app)
        oauth.register(
            name="google",
            client_id=app.config["GOOGLE_CLIENT_ID"],
            client_secret=app.config["GOOGLE_CLIENT_SECRET"],
            server_metadata_url=GOOGLE_METADATA_URL,
            client_kwargs={"scope": "openid email profile", "code_challenge_method": "S256"},
        )
        app.extensions["dalacarbon_oauth"] = oauth
    app.register_blueprint(bp)


def google_client():
    return current_app.extensions["dalacarbon_oauth"].create_client("google")


def _fail(reason: str):
    session["auth_notice"] = NOTICES[reason]
    return redirect(url_for("auth.login"))


def _login(user_id: int):
    start_session(get_user(get_db(), user_id))  # session fixation-ға қарсы + дәуір белгісі
    return redirect(url_for("main.dashboard"))


@bp.get("")
def start():
    if g.user:
        return redirect(url_for("main.dashboard"))
    if not current_app.config.get("GOOGLE_ENABLED"):
        return _fail("not_configured")
    redirect_uri = current_app.config.get("GOOGLE_REDIRECT_URI") or url_for("google.callback", _external=True)
    return google_client().authorize_redirect(redirect_uri, prompt="select_account")


@bp.get("/callback")
def callback():
    if not current_app.config.get("GOOGLE_ENABLED"):
        return _fail("not_configured")
    try:
        token = google_client().authorize_access_token()  # state, PKCE, id_token қолтаңбасы, nonce
    except OAuthError:
        return _fail("failed")

    info = token.get("userinfo") or {}
    sub, email = info.get("sub"), (info.get("email") or "").lower()
    if not sub or not email:
        return _fail("failed")
    if not info.get("email_verified"):
        return _fail("unverified")

    conn = get_db()
    user = find_user_by_google_sub(conn, sub)
    if user:
        return _login(user["id"])

    user = find_user_by_email(conn, email)
    if user:
        # Google email-ді растаған — бұрын тіркелген аккаунтқа байланыстырамыз.
        link_google(conn, user["id"], sub)
        return _login(user["id"])

    session[_PENDING] = {"sub": sub, "email": email, "name": info.get("name") or ""}
    return redirect(url_for("google.complete"))


def _render_complete(pending: dict, values: dict, errors: dict, status: int = 200):
    html = render_template(
        "google_complete.html",
        email=pending["email"],
        values=values,
        errors=errors,
        regions=REGIONS,
        farm_types=FARM_TYPES,
    )
    return html, status


@bp.route("/complete", methods=["GET", "POST"])
def complete():
    pending = session.get(_PENDING)
    if not pending:
        return redirect(url_for("auth.login"))

    if request.method == "GET":
        values = {"full_name": pending["name"], "username": suggest_username(pending["email"]),
                  "region": "", "farm_type": "", "newsletter": False}
        return _render_complete(pending, values, {})

    check_csrf()
    data, errors = validate_google_profile(request.form)
    conn = get_db()
    if not errors and "username" in find_taken_fields(conn, pending["email"], data["username"]):
        errors["username"] = MESSAGES["username_taken"]

    if not errors:
        try:
            user_id = insert_google_user(
                conn,
                email=pending["email"],
                username=data["username"],
                full_name=data["full_name"],
                google_sub=pending["sub"],
                region=data["region"],
                farm_type=data["farm_type"],
                newsletter=data["newsletter"],
            )
        except DuplicateUserError as exc:
            if "username" in exc.fields:
                errors["username"] = MESSAGES["username_taken"]
            else:  # email немесе Google аккаунты осы сәтте басқа жолмен тіркелген
                session.pop(_PENDING, None)
                return _fail("failed")
        else:
            return _login(user_id)

    values = {**data, "full_name": request.form.get("full_name", "")}
    return _render_complete(pending, values, errors, status=422)


@bp.post("/cancel")
def cancel():
    check_csrf()
    session.pop(_PENDING, None)
    return redirect(url_for("auth.login"), code=303)
