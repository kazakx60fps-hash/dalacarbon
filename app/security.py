"""Құпиясөзді хештеу, CSRF қорғанысы және HTTP қауіпсіздік тақырыптары."""

from __future__ import annotations

import hmac
import secrets

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from flask import abort, request, session

# Argon2id (OWASP №1 ұсынысы). argon2-cffi әдепкі мәндері: 64 МиБ жад,
# 3 итерация, 4 параллель ағын — OWASP минимумынан (19 МиБ, t=2) жоғары.
# Тұз (salt) әр хешке автоматты түрде қосылады.
_hasher = PasswordHasher()


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password_hash: str | None, password: str) -> bool:
    if not password_hash:  # тек Google арқылы кіретін аккаунт
        verify_dummy(password)
        return False
    try:
        return _hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def needs_rehash(password_hash: str) -> bool:
    """Хеш параметрлері ескірсе (мысалы, жад көбейтілсе) — кіргенде жаңартамыз."""
    return _hasher.check_needs_rehash(password_hash)


# Логин табылмаса да Argon2 тексерісі бәрібір орындалады — жауап уақыты
# бойынша «мұндай логин бар ма» деген ақпарат сыртқа шықпайды (OWASP).
_DUMMY_HASH = _hasher.hash("dalacarbon-timing-equaliser")


def verify_dummy(password: str) -> None:
    try:
        _hasher.verify(_DUMMY_HASH, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        pass


_CSRF_SESSION_KEY = "_csrf_token"


def csrf_token() -> str:
    """Сессияға байланған CSRF токенін қайтарады (жоқ болса жасайды)."""
    token = session.get(_CSRF_SESSION_KEY)
    if not token:
        token = secrets.token_urlsafe(32)
        session[_CSRF_SESSION_KEY] = token
    return token


def check_csrf() -> None:
    """POST сұранысындағы токенді тексереді; сәйкес келмесе 400 қайтарады."""
    sent = request.form.get("csrf_token", "")
    expected = session.get(_CSRF_SESSION_KEY, "")
    if not expected or not hmac.compare_digest(sent, expected):
        abort(400, description="Форманың мерзімі өтті. Бетті жаңартып, қайта жіберіңіз.")


_CSP = "; ".join(
    [
        "default-src 'self'",
        "script-src 'self'",
        "style-src 'self' https://fonts.googleapis.com",
        "font-src 'self' https://fonts.gstatic.com",
        "img-src 'self' data:",
        "form-action 'self'",
        "frame-ancestors 'none'",
        "base-uri 'self'",
    ]
)


def add_security_headers(response):
    response.headers.setdefault("Content-Security-Policy", _CSP)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "same-origin")
    return response
