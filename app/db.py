"""PostgreSQL-мен жұмыс (psycopg 3).

Барлық сұраныстар параметрленген (%s / %(name)s) — SQL-инъекцияға жол жоқ.
"""

from __future__ import annotations

from pathlib import Path

import click
import psycopg
from flask import current_app, g
from psycopg.rows import dict_row

SCHEMA_PATH = Path(__file__).resolve().parent.parent / "db" / "schema.sql"


class DuplicateUserError(Exception):
    """Email немесе логин бұрыннан бар (UNIQUE шектеуі)."""

    def __init__(self, fields: set[str]):
        self.fields = fields
        super().__init__(", ".join(sorted(fields)))


def get_db() -> psycopg.Connection:
    """Ағымдағы сұранысқа арналған дерекқор қосылымы."""
    if "db" not in g:
        url = current_app.config.get("DATABASE_URL")
        if not url:
            raise RuntimeError("DATABASE_URL орнатылмаған (.env файлын тексеріңіз)")
        g.db = psycopg.connect(url, autocommit=True, row_factory=dict_row, connect_timeout=5)
    return g.db


def close_db(_exc: BaseException | None = None) -> None:
    conn = g.pop("db", None)
    if conn is not None:
        conn.close()


def init_schema(url: str | None = None) -> None:
    """db/schema.sql файлын орындайды (кестелер мен индекстер)."""
    url = url or current_app.config["DATABASE_URL"]
    with psycopg.connect(url, autocommit=True, connect_timeout=5) as conn:
        conn.execute(SCHEMA_PATH.read_text(encoding="utf-8"))


def find_taken_fields(conn: psycopg.Connection, email: str, username: str) -> set[str]:
    """Бос емес өрістерді қайтарады: {'email'}, {'username'} немесе екеуі."""
    rows = conn.execute(
        """
        SELECT LOWER(email) = LOWER(%(email)s)       AS email_taken,
               LOWER(username) = LOWER(%(username)s) AS username_taken
          FROM users
         WHERE LOWER(email) = LOWER(%(email)s)
            OR LOWER(username) = LOWER(%(username)s)
        """,
        {"email": email, "username": username},
    ).fetchall()
    taken: set[str] = set()
    for row in rows:
        if row["email_taken"]:
            taken.add("email")
        if row["username_taken"]:
            taken.add("username")
    return taken


def insert_user(
    conn: psycopg.Connection,
    *,
    email: str,
    username: str,
    full_name: str | None,
    password_hash: str,
    region: str,
    farm_type: str,
    newsletter: bool,
) -> int:
    """Жаңа пайдаланушыны сақтап, оның id-сін қайтарады."""
    try:
        row = conn.execute(
            """
            INSERT INTO users (email, username, full_name, password_hash, region, farm_type, newsletter)
            VALUES (%(email)s, %(username)s, %(full_name)s, %(password_hash)s,
                    %(region)s, %(farm_type)s, %(newsletter)s)
            RETURNING id
            """,
            {
                "email": email,
                "username": username,
                "full_name": full_name,
                "password_hash": password_hash,
                "region": region,
                "farm_type": farm_type,
                "newsletter": newsletter,
            },
        ).fetchone()
    except psycopg.errors.UniqueViolation as exc:
        # Екі адам бір логинді бір мезетте тіркесе — тексеруден өтіп кеткен жағдай.
        constraint = exc.diag.constraint_name or ""
        raise DuplicateUserError({"email"} if "email" in constraint else {"username"}) from exc
    return row["id"]


_USER_COLUMNS = "id, email, username, full_name, password_hash, google_sub, region, farm_type, created_at"


def find_user_by_google_sub(conn: psycopg.Connection, sub: str) -> dict | None:
    return conn.execute(f"SELECT {_USER_COLUMNS} FROM users WHERE google_sub = %s", (sub,)).fetchone()


def find_user_by_email(conn: psycopg.Connection, email: str) -> dict | None:
    return conn.execute(
        f"SELECT {_USER_COLUMNS} FROM users WHERE LOWER(email) = LOWER(%s)", (email,)
    ).fetchone()


def link_google(conn: psycopg.Connection, user_id: int, sub: str) -> None:
    """Бар аккаунтқа Google-ды байланыстырады (тек бос болса)."""
    conn.execute(
        "UPDATE users SET google_sub = %s WHERE id = %s AND google_sub IS NULL", (sub, user_id)
    )


def insert_google_user(
    conn: psycopg.Connection,
    *,
    email: str,
    username: str,
    full_name: str | None,
    google_sub: str,
    region: str,
    farm_type: str,
    newsletter: bool,
) -> int:
    """Google арқылы тіркелген пайдаланушы: құпиясөз хеші жоқ (NULL)."""
    try:
        row = conn.execute(
            """
            INSERT INTO users (email, username, full_name, google_sub, region, farm_type, newsletter)
            VALUES (%(email)s, %(username)s, %(full_name)s, %(google_sub)s,
                    %(region)s, %(farm_type)s, %(newsletter)s)
            RETURNING id
            """,
            {
                "email": email,
                "username": username,
                "full_name": full_name,
                "google_sub": google_sub,
                "region": region,
                "farm_type": farm_type,
                "newsletter": newsletter,
            },
        ).fetchone()
    except psycopg.errors.UniqueViolation as exc:
        constraint = exc.diag.constraint_name or ""
        fields = {"email"} if "email" in constraint else {"username"}
        if "google_sub" in constraint:
            fields = {"google"}
        raise DuplicateUserError(fields) from exc
    return row["id"]


def find_user_by_login(conn: psycopg.Connection, identifier: str) -> dict | None:
    """Логин немесе email бойынша пайдаланушыны табады (регистрге қарамай)."""
    return conn.execute(
        f"""
        SELECT {_USER_COLUMNS}
          FROM users
         WHERE LOWER(username) = LOWER(%(id)s) OR LOWER(email) = LOWER(%(id)s)
         LIMIT 1
        """,
        {"id": identifier},
    ).fetchone()


def get_user(conn: psycopg.Connection, user_id: int) -> dict | None:
    return conn.execute(f"SELECT {_USER_COLUMNS} FROM users WHERE id = %s", (user_id,)).fetchone()


def update_password_hash(conn: psycopg.Connection, user_id: int, password_hash: str) -> None:
    conn.execute("UPDATE users SET password_hash = %s WHERE id = %s", (password_hash, user_id))


_PARCEL_COLUMNS = "id, name, area_ha, crop, practice, created_at"


def list_parcels(conn: psycopg.Connection, user_id: int) -> list[dict]:
    return conn.execute(
        f"SELECT {_PARCEL_COLUMNS} FROM parcels WHERE user_id = %s ORDER BY created_at, id", (user_id,)
    ).fetchall()


def insert_parcel(conn: psycopg.Connection, user_id: int, data: dict) -> dict:
    return conn.execute(
        f"""
        INSERT INTO parcels (user_id, name, area_ha, crop, practice)
        VALUES (%(user_id)s, %(name)s, %(area_ha)s, %(crop)s, %(practice)s)
        RETURNING {_PARCEL_COLUMNS}
        """,
        {**data, "user_id": user_id},
    ).fetchone()


def delete_parcel(conn: psycopg.Connection, user_id: int, parcel_id: int) -> bool:
    """Тек өз алқабын өшіре алады: user_id шарты басқа біреудің жазбасын қорғайды."""
    cur = conn.execute("DELETE FROM parcels WHERE id = %s AND user_id = %s", (parcel_id, user_id))
    return cur.rowcount == 1


@click.command("init-db")
def init_db_command() -> None:
    """Дерекқор кестелерін жасау: flask --app run init-db"""
    init_schema()
    click.echo("Дерекқор кестелері дайын.")


def init_app(app) -> None:
    app.teardown_appcontext(close_db)
    app.cli.add_command(init_db_command)
