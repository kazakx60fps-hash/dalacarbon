"""Тіркелу формасын тексеру (сервер жағы).

Браузердегі static/js/register.js дәл осы ережелерді қайталайды, бірақ
шешуші тексеру әрқашан осы жерде — JavaScript-ті айналып өтуге болады.
"""

from __future__ import annotations

import re
from collections.abc import Mapping

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
USERNAME_RE = re.compile(r"^[A-Za-z0-9_]{4,32}$")

EMAIL_MAX = 254
FULL_NAME_MAX = 120
PASSWORD_MIN = 8
PASSWORD_MAX = 128

# Қазақстан облыстары (2022 жылғы әкімшілік бөліністен кейін).
REGIONS: list[tuple[str, str]] = [
    ("abai", "Абай облысы"),
    ("akmola", "Ақмола облысы"),
    ("aktobe", "Ақтөбе облысы"),
    ("almaty", "Алматы облысы"),
    ("atyrau", "Атырау облысы"),
    ("wko", "Батыс Қазақстан облысы"),
    ("zhambyl", "Жамбыл облысы"),
    ("zhetisu", "Жетісу облысы"),
    ("karaganda", "Қарағанды облысы"),
    ("kostanay", "Қостанай облысы"),
    ("kyzylorda", "Қызылорда облысы"),
    ("mangystau", "Маңғыстау облысы"),
    ("pavlodar", "Павлодар облысы"),
    ("nko", "Солтүстік Қазақстан облысы"),
    ("turkistan", "Түркістан облысы"),
    ("ulytau", "Ұлытау облысы"),
    ("eko", "Шығыс Қазақстан облысы"),
]

FARM_TYPES: list[tuple[str, str]] = [
    ("farm", "Шаруа қожалығы"),
    ("llp", "ЖШС"),
    ("coop", "Кооператив"),
    ("other", "Басқа"),
]

_REGION_KEYS = {key for key, _ in REGIONS}
_FARM_TYPE_KEYS = {key for key, _ in FARM_TYPES}

MESSAGES = {
    "email_required": "Email өрісін толтырыңыз",
    "email_invalid": "Email форматы дұрыс емес (мысалы, name@example.kz)",
    "email_too_long": "Email 254 таңбадан аспауы тиіс",
    "full_name_too_long": "Аты-жөні 120 таңбадан аспауы тиіс",
    "username_required": "Логин өрісін толтырыңыз",
    "username_invalid": "Логин 4–32 таңбадан тұруы тиіс: латын әріптері, сандар және «_»",
    "password_required": "Құпиясөзді енгізіңіз",
    "password_short": "Құпиясөз кемінде 8 таңбадан тұруы тиіс",
    "password_long": "Құпиясөз 128 таңбадан аспауы тиіс",
    "password_case": "Құпиясөзде бас және кіші әріп болуы тиіс",
    "password_digit": "Құпиясөзде кемінде бір сан болуы тиіс",
    "password_is_username": "Құпиясөз логинмен бірдей болмауы тиіс",
    "confirm_required": "Құпиясөзді қайталап енгізіңіз",
    "confirm_mismatch": "Енгізілген құпиясөздер бір-біріне сәйкес келмейді",
    "region_required": "Облысты таңдаңыз",
    "farm_type_required": "Шаруашылық түрін таңдаңыз",
    "email_taken": "Бұл email-мен аккаунт бұрыннан тіркелген. Кіріп көріңіз.",
    "username_taken": "Бұл логин бос емес. Басқа логин таңдаңыз.",
    "login_required": "Логин немесе email өрісін толтырыңыз",
    "login_password_required": "Құпиясөзді енгізіңіз",
    # OWASP: логин жоқ па, құпиясөз қате ме — айырмай, бір хабарлама.
    "invalid_credentials": "Логин немесе құпиясөз сәйкес келмейді. Мәліметтерді тексеріп, қайта көріңіз.",
}


def validate_login(form: Mapping[str, str]) -> tuple[dict, dict[str, str]]:
    """Кіру формасы: тек бос өрістерді тексереді (форматты емес — ол ақпарат береді)."""
    identifier = (form.get("login") or "").strip()
    password = form.get("password") or ""
    errors: dict[str, str] = {}
    if not identifier:
        errors["login"] = MESSAGES["login_required"]
    if not password:
        errors["password"] = MESSAGES["login_password_required"]
    data = {
        "login": identifier[:254],
        "password": password[:PASSWORD_MAX],
        "remember": form.get("remember") == "on",
    }
    return data, errors


def label_for(options: list[tuple[str, str]], key: str) -> str:
    return dict(options).get(key, key)


def password_checks(password: str) -> dict[str, bool]:
    """Құпиясөз талаптарының әрқайсысының орындалғанын қайтарады."""
    return {
        "length": len(password) >= PASSWORD_MIN,
        "case": any(c.islower() for c in password) and any(c.isupper() for c in password),
        "digit": any(c.isdigit() for c in password),
        "special": any(not c.isalnum() for c in password),  # ұсынылады, міндетті емес
    }


def _validate_password(password: str, username: str) -> str | None:
    if not password:
        return MESSAGES["password_required"]
    if len(password) > PASSWORD_MAX:
        return MESSAGES["password_long"]
    checks = password_checks(password)
    if not checks["length"]:
        return MESSAGES["password_short"]
    if not checks["case"]:
        return MESSAGES["password_case"]
    if not checks["digit"]:
        return MESSAGES["password_digit"]
    if username and password.lower() == username.lower():
        return MESSAGES["password_is_username"]
    return None


def validate_registration(form: Mapping[str, str]) -> tuple[dict, dict[str, str]]:
    """Форма деректерін тексеріп, (таза деректер, қателер) жұбын қайтарады.

    Қателер сөздігінің кілті — өріс атауы, мәні — пайдаланушыға көрсетілетін мәтін.
    """
    email = (form.get("email") or "").strip()
    full_name = " ".join((form.get("full_name") or "").split())
    username = (form.get("username") or "").strip()
    password = form.get("password") or ""
    confirm = form.get("password_confirm") or ""
    region = (form.get("region") or "").strip()
    farm_type = (form.get("farm_type") or "").strip()

    errors: dict[str, str] = {}

    if not email:
        errors["email"] = MESSAGES["email_required"]
    elif len(email) > EMAIL_MAX:
        errors["email"] = MESSAGES["email_too_long"]
    elif not EMAIL_RE.match(email):
        errors["email"] = MESSAGES["email_invalid"]

    if len(full_name) > FULL_NAME_MAX:
        errors["full_name"] = MESSAGES["full_name_too_long"]

    if not username:
        errors["username"] = MESSAGES["username_required"]
    elif not USERNAME_RE.match(username):
        errors["username"] = MESSAGES["username_invalid"]

    password_error = _validate_password(password, username)
    if password_error:
        errors["password"] = password_error

    if not confirm:
        errors["password_confirm"] = MESSAGES["confirm_required"]
    elif confirm != password:
        errors["password_confirm"] = MESSAGES["confirm_mismatch"]

    if region not in _REGION_KEYS:
        errors["region"] = MESSAGES["region_required"]
    if farm_type not in _FARM_TYPE_KEYS:
        errors["farm_type"] = MESSAGES["farm_type_required"]

    data = {
        "email": email.lower(),
        "full_name": full_name or None,
        "username": username,
        "password": password,
        "region": region,
        "farm_type": farm_type,
        "newsletter": form.get("newsletter") == "on",
    }
    return data, errors
