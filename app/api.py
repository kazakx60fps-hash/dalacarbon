"""Мобильді қосымшаға арналған JSON API (/api/v1).

Кіру: `Authorization: Bearer <токен>`. Токен 30 күн жарамды, базада тек SHA-256 хеші сақталады.
Құпиясөз қалпына келтірілсе (users.session_epoch өседі) барлық токендер жарамсыз болады.
Cookie қолданылмайды, сондықтан CSRF токені қажет емес — браузер Bearer тақырыбын өзі жібермейді.
Тексеру ережелері мен қате мәтіндері сайттағымен бірдей (validators.py).
"""

from __future__ import annotations

import hashlib
import secrets
from functools import wraps

from flask import Blueprint, g, jsonify, request

from .auth import request_password_reset
from .db import (
    DuplicateUserError,
    create_api_token,
    delete_api_token,
    delete_parcel,
    find_api_token_user,
    find_taken_fields,
    find_user_by_login,
    get_db,
    insert_parcel,
    insert_user,
    list_parcels,
    update_password_hash,
)
from .main import _parcel_json, csv_response, dashboard_context
from .security import hash_password, needs_rehash, verify_dummy, verify_password
from .validators import (
    CROPS,
    FARM_TYPES,
    MESSAGES,
    PRACTICES,
    REGIONS,
    label_for,
    validate_login,
    validate_parcel,
    validate_registration,
    validate_reset_request,
)

bp = Blueprint("api", __name__, url_prefix="/api/v1")

TOKEN_DAYS = 30


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _form() -> dict[str, str]:
    """JSON денесін валидаторлар күтетін «форма» түріне келтіреді (true → "on", сандар → мәтін)."""
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return {}
    out: dict[str, str] = {}
    for key, value in payload.items():
        if isinstance(value, bool):
            out[key] = "on" if value else ""
        elif value is None:
            out[key] = ""
        else:
            out[key] = str(value)
    return out


def _error(message: str, status: int, **extra):
    return jsonify(ok=False, error=message, **extra), status


def _bearer() -> str | None:
    header = request.headers.get("Authorization", "")
    if header.startswith("Bearer "):
        token = header[7:].strip()
        if 20 <= len(token) <= 128:
            return token
    return None


def token_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        token = _bearer()
        user = find_api_token_user(get_db(), _hash(token)) if token else None
        if user is None:
            return _error("Кіру мерзімі өтті. Қайта кіріңіз.", 401)
        g.api_user = user
        g.api_token = token
        return view(*args, **kwargs)

    return wrapped


def _user_json(user: dict) -> dict:
    name = user["full_name"] or user["username"]
    methods = []
    if user["password_hash"]:
        methods.append("password")
    if user["google_sub"]:
        methods.append("google")
    return {
        "id": user["id"],
        "username": user["username"],
        "email": user["email"],
        "full_name": user["full_name"],
        "display_name": name,
        "region": user["region"],
        "region_label": label_for(REGIONS, user["region"]),
        "farm_type": user["farm_type"],
        "farm_type_label": label_for(FARM_TYPES, user["farm_type"]),
        "login_methods": methods,
        "created_at": user["created_at"].date().isoformat(),
    }


def _issue_token(user: dict) -> str:
    token = secrets.token_urlsafe(32)
    device = (request.headers.get("User-Agent") or "")[:80]
    create_api_token(get_db(), user, _hash(token), TOKEN_DAYS, device)
    return token


# ---------- Кіру / тіркелу ----------

@bp.post("/auth/login")
def login():
    data, errors = validate_login(_form())
    if errors:
        return _error("Өрістерді толтырыңыз", 422, errors=errors)
    conn = get_db()
    user = find_user_by_login(conn, data["login"])
    if user is None:
        verify_dummy(data["password"])  # жауап уақыты бойынша айырмашылық болмасын
        ok = False
    else:
        ok = verify_password(user["password_hash"], data["password"])
    if not ok:
        return _error(MESSAGES["invalid_credentials"], 401)  # OWASP: бірдей жауап
    if needs_rehash(user["password_hash"]):
        update_password_hash(conn, user["id"], hash_password(data["password"]))
    return jsonify(ok=True, token=_issue_token(user), user=_user_json(user))


@bp.post("/auth/register")
def register():
    data, errors = validate_registration(_form())
    conn = get_db()
    if not errors:
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
        return _error("Белгіленген өрістерді тексеріңіз", 422, errors=errors)
    user = find_user_by_login(conn, data["username"])
    return jsonify(ok=True, token=_issue_token(user), user=_user_json(user)), 201


@bp.post("/auth/forgot")
def forgot():
    email, error = validate_reset_request(_form())
    if error:
        return _error(error, 422, errors={"email": error})
    request_password_reset(email)
    # Email тіркелген бе, жоқ па — жауап бірдей.
    return jsonify(ok=True, message="Егер бұл email тіркелген болса, оған сілтеме жіберілді."), 202


@bp.post("/auth/logout")
@token_required
def logout():
    delete_api_token(get_db(), _hash(g.api_token))
    return "", 204


@bp.get("/meta")
def meta():
    """Тіркелу формасына керек тізімдер (кірмей-ақ)."""
    return jsonify(
        regions=[{"key": k, "label": v} for k, v in REGIONS],
        farm_types=[{"key": k, "label": v} for k, v in FARM_TYPES],
        crops=[{"key": k, "label": v} for k, v in CROPS],
        practices=[{"key": k, "label": v} for k, v in PRACTICES],
    )


# ---------- Деректер ----------

@bp.get("/me")
@token_required
def me():
    return jsonify(ok=True, user=_user_json(g.api_user))


@bp.get("/dashboard")
@token_required
def dashboard():
    ctx = dashboard_context(g.api_user)
    return jsonify(
        ok=True,
        user=_user_json(g.api_user),
        greeting=ctx["greeting"],
        today_label=ctx["today_label"],
        month_label=ctx["month_label"],
        initials=ctx["initials"],
        numbers=ctx["n"],
        inbox=ctx["inbox"],
        notifs=ctx["notifs"],
        activity=ctx["activity"],
        crops=[{"key": k, "label": v} for k, v in CROPS],
        practices=[{"key": k, "label": v} for k, v in PRACTICES],
        data=ctx["data"],
    )


@bp.get("/parcels")
@token_required
def parcels():
    rows = list_parcels(get_db(), g.api_user["id"])
    return jsonify(ok=True, parcels=[_parcel_json(r) for r in rows])


@bp.post("/parcels")
@token_required
def add_parcel():
    parcel, errors = validate_parcel(_form())
    if errors:
        return _error("Белгіленген өрістерді тексеріңіз", 422, errors=errors)
    row = insert_parcel(get_db(), g.api_user["id"], parcel)
    return jsonify(ok=True, parcel=_parcel_json(row)), 201


@bp.delete("/parcels/<int:parcel_id>")
@token_required
def remove_parcel(parcel_id: int):
    if not delete_parcel(get_db(), g.api_user["id"], parcel_id):
        return _error("Алқап табылмады", 404)
    return jsonify(ok=True)


@bp.get("/report.csv")
@token_required
def report():
    return csv_response(g.api_user)
