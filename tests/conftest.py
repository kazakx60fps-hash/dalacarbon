import os
import re

import pytest

from app import create_app  # .env осы жерде жүктеледі


@pytest.fixture()
def db_url():
    url = os.environ.get("TEST_DATABASE_URL")
    if not url:
        pytest.skip("TEST_DATABASE_URL орнатылмаған — дерекқор тесттері өткізілді")
    return url


@pytest.fixture()
def app(db_url):
    import psycopg

    from app.db import init_schema

    init_schema(db_url)
    with psycopg.connect(db_url, autocommit=True) as conn:
        conn.execute("TRUNCATE users RESTART IDENTITY")
    # Google кілттері әдейі бос — .env-те шын кілттер болса да тесттер соларға тәуелді емес.
    return create_app({
        "TESTING": True, "SECRET_KEY": "test-secret", "DATABASE_URL": db_url,
        "GOOGLE_CLIENT_ID": "", "GOOGLE_CLIENT_SECRET": "",
    })


@pytest.fixture()
def client(app):
    return app.test_client()


@pytest.fixture()
def csrf(client):
    """GET /register жасап, беттегі CSRF токенін қайтарады."""

    def _get():
        html = client.get("/register").get_data(as_text=True)
        return re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)

    return _get


@pytest.fixture()
def fetch_user(db_url):
    import psycopg
    from psycopg.rows import dict_row

    def _fetch(username):
        with psycopg.connect(db_url, row_factory=dict_row) as conn:
            return conn.execute(
                "SELECT * FROM users WHERE LOWER(username) = LOWER(%s)", (username,)
            ).fetchone()

    return _fetch
