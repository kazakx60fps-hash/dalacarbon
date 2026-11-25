"""DalaCarbon AI — Flask қосымшасы."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

# Windows: psycopg-ке PostgreSQL-дің libpq.dll кітапханасын табуға көмектесеміз.
_pg_bin = os.environ.get("PG_BIN")
if os.name == "nt" and _pg_bin and os.path.isdir(_pg_bin):
    os.environ["PATH"] = _pg_bin + os.pathsep + os.environ.get("PATH", "")

from flask import Flask  # noqa: E402

from . import db  # noqa: E402
from datetime import timedelta  # noqa: E402

from .auth import bp as auth_bp  # noqa: E402
from .main import bp as main_bp  # noqa: E402
from .security import add_security_headers, csrf_token  # noqa: E402

_NDVI_RAMP = 6


def _parcel_cells() -> list[int]:
    """Фондағы NDVI алқап тақтасының 6×6 ұяшық түстері (0 — жалаңаш топырақ, 5 — қалың өсімдік)."""
    cells = []
    for r in range(6):
        for c in range(6):
            base = 0.8 if c < 3 else (0.15 if r > 3 else 0.5)
            noise = ((c * 37 + r * 61) % 7) / 7 * 0.3 - 0.15
            value = min(max(base + noise, 0.0), 0.999)
            cells.append(int(value * _NDVI_RAMP))
    return cells


def _qr_path(n: int = 25) -> str:
    """Безендіру үшін QR-код суреті (SVG path). Сканерленбейді — тек дизайн элементі."""

    def finder(r: int, c: int, r0: int, c0: int):
        i, j = r - r0, c - c0
        if not (-1 <= i <= 7 and -1 <= j <= 7):
            return None
        if not (0 <= i <= 6 and 0 <= j <= 6):
            return False
        return i in (0, 6) or j in (0, 6) or (2 <= i <= 4 and 2 <= j <= 4)

    parts = []
    for r in range(n):
        for c in range(n):
            f = finder(r, c, 0, 0)
            if f is None:
                f = finder(r, c, 0, n - 7)
            if f is None:
                f = finder(r, c, n - 7, 0)
            if f is not None:
                dark = f
            elif 9 <= r <= 15 and 9 <= c <= 15:
                dark = False  # ортасында логотип
            elif r == 6:
                dark = c % 2 == 0
            elif c == 6:
                dark = r % 2 == 0
            else:
                dark = (r * 131 + c * 71 + r * c * 7) % 11 < 5
            if dark:
                parts.append(f"M{c} {r}h1v1h-1z")
    return "".join(parts)


def create_app(test_config: dict | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_mapping(
        SECRET_KEY=os.environ.get("SECRET_KEY"),
        DATABASE_URL=os.environ.get("DATABASE_URL"),
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        MAX_CONTENT_LENGTH=64 * 1024,
        PERMANENT_SESSION_LIFETIME=timedelta(days=30),  # «Мені есте сақта»
    )
    if test_config:
        app.config.update(test_config)
    if not app.config["SECRET_KEY"]:
        raise RuntimeError("SECRET_KEY орнатылмаған (.env файлын тексеріңіз)")

    db.init_app(app)
    app.register_blueprint(auth_bp)
    app.register_blueprint(main_bp)
    app.after_request(add_security_headers)
    app.jinja_env.globals.update(csrf_token=csrf_token, parcel_cells=_parcel_cells(), qr_path=_qr_path())
    _register_error_pages(app)

    @app.get("/favicon.ico")
    def favicon():
        from flask import redirect, url_for

        return redirect(url_for("static", filename="img/mark-color.svg"), code=301)

    return app


_ERRORS = {
    400: ("Сұраныс қабылданбады", "Форманың мерзімі өтті немесе деректер бүлінген. Бетті жаңартып, қайта көріңіз."),
    404: ("Бет табылмады", "Мұндай мекенжай жоқ. Сілтемені тексеріңіз."),
    500: ("Сервер қатесі", "Бірдеңе дұрыс болмады. Біраз уақыттан соң қайта көріңіз."),
}


def _register_error_pages(app: Flask) -> None:
    from flask import render_template

    def make_handler(code: int):
        title, message = _ERRORS[code]

        def handler(_error):
            return render_template("error.html", title=title, message=message), code

        return handler

    for code in _ERRORS:
        app.register_error_handler(code, make_handler(code))
