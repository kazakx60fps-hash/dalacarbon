"""Google арқылы кіру: Google-дың өзіне сұраныс жібермей, Authlib клиентін алмастырып тексереміз."""

import re

import psycopg
import pytest
from authlib.integrations.base_client.errors import OAuthError
from flask import redirect

from app import create_app
from app.google_auth import NOTICES
from app.validators import MESSAGES

GOOGLE_USER = {"sub": "1098765432100", "email": "Fermer.Dala@gmail.com", "email_verified": True, "name": "Ерлан Дала"}


@pytest.fixture()
def gapp(app, db_url):
    """Google кілттері бар қосымша (кілттер жалған — желіге шықпаймыз)."""
    return create_app({
        "TESTING": True, "SECRET_KEY": "test-secret", "DATABASE_URL": db_url,
        "GOOGLE_CLIENT_ID": "test-client.apps.googleusercontent.com", "GOOGLE_CLIENT_SECRET": "test-secret",
    })


@pytest.fixture()
def gclient(gapp):
    return gapp.test_client()


@pytest.fixture()
def google_says(gapp, monkeypatch):
    """Google-дың жауабын орнатады: google_says(userinfo) немесе google_says(error=True)."""
    client = gapp.extensions["dalacarbon_oauth"].create_client("google")
    monkeypatch.setattr(client, "authorize_redirect",
                        lambda uri, **kw: redirect("https://accounts.google.com/o/oauth2/v2/auth?redirect_uri=" + uri))

    def _set(userinfo=None, error=False):
        def fake_token(**kwargs):
            if error:
                raise OAuthError(error="access_denied")
            return {"access_token": "x", "userinfo": userinfo}
        monkeypatch.setattr(client, "authorize_access_token", fake_token)

    return _set


def csrf(client, path):
    html = client.get(path).get_data(as_text=True)
    return re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)


def user_row(db_url, email):
    with psycopg.connect(db_url) as conn:
        return conn.execute(
            "SELECT username, google_sub, password_hash, region FROM users WHERE LOWER(email) = LOWER(%s)", (email,)
        ).fetchone()


def test_button_is_notice_when_not_configured(client):
    html = client.get("/login").get_data(as_text=True)
    assert 'href="/auth/google"' not in html
    res = client.get("/auth/google")
    assert res.headers["Location"].endswith("/login")
    assert NOTICES["not_configured"] in client.get("/login").get_data(as_text=True)


def test_button_links_to_google_when_configured(gclient, google_says):
    google_says(GOOGLE_USER)
    assert 'href="/auth/google"' in gclient.get("/login").get_data(as_text=True)
    res = gclient.get("/auth/google")
    assert res.status_code == 302
    assert res.headers["Location"].startswith("https://accounts.google.com/")
    assert "/auth/google/callback" in res.headers["Location"]


def test_new_google_user_completes_profile(gclient, google_says, db_url):
    google_says(GOOGLE_USER)
    res = gclient.get("/auth/google/callback")
    assert res.headers["Location"].endswith("/auth/google/complete")

    page = gclient.get("/auth/google/complete").get_data(as_text=True)
    assert "fermer.dala@gmail.com" in page
    assert 'value="fermer_dala"' in page        # email-ден ұсынылған логин
    assert 'value="Ерлан Дала"' in page

    res = gclient.post("/auth/google/complete", data={
        "csrf_token": csrf(gclient, "/auth/google/complete"),
        "full_name": "Ерлан Дала", "username": "fermer_dala", "region": "kostanay", "farm_type": "farm",
    })
    assert res.status_code == 302 and res.headers["Location"].endswith("/dashboard")
    row = user_row(db_url, "fermer.dala@gmail.com")
    assert row == ("fermer_dala", "1098765432100", None, "kostanay")  # құпиясөз хеші жоқ
    page = gclient.get("/dashboard").get_data(as_text=True)
    assert "Басқару тақтасы" in page and "Ерлан Дала" in page


def test_returning_google_user_logs_straight_in(gclient, google_says):
    google_says(GOOGLE_USER)
    gclient.get("/auth/google/callback")
    gclient.post("/auth/google/complete", data={
        "csrf_token": csrf(gclient, "/auth/google/complete"),
        "username": "fermer_dala", "region": "akmola", "farm_type": "farm",
    })
    gclient.post("/logout", data={"csrf_token": csrf(gclient, "/dashboard")})

    res = gclient.get("/auth/google/callback")
    assert res.headers["Location"].endswith("/dashboard")


def test_existing_password_account_gets_linked(gclient, google_says, db_url):
    gclient.post("/register", data={
        "csrf_token": csrf(gclient, "/register"), "email": "fermer.dala@gmail.com", "username": "jasyl_dala",
        "password": "Dala2026soil", "password_confirm": "Dala2026soil", "region": "akmola", "farm_type": "farm",
    })
    google_says(GOOGLE_USER)
    res = gclient.get("/auth/google/callback")
    assert res.headers["Location"].endswith("/dashboard")
    username, sub, pw_hash, _ = user_row(db_url, "fermer.dala@gmail.com")
    assert (username, sub) == ("jasyl_dala", "1098765432100")
    assert pw_hash.startswith("$argon2id$")  # құпиясөзбен кіру де сақталды


def test_unverified_email_is_refused(gclient, google_says, db_url):
    google_says({**GOOGLE_USER, "email_verified": False})
    res = gclient.get("/auth/google/callback")
    assert res.headers["Location"].endswith("/login")
    assert NOTICES["unverified"] in gclient.get("/login").get_data(as_text=True)
    assert user_row(db_url, "fermer.dala@gmail.com") is None


def test_cancelled_or_failed_google_login(gclient, google_says):
    google_says(error=True)
    res = gclient.get("/auth/google/callback")
    assert res.headers["Location"].endswith("/login")
    assert NOTICES["failed"] in gclient.get("/login").get_data(as_text=True)
    assert gclient.get("/dashboard").status_code == 302


def test_complete_validates_and_rejects_taken_username(gclient, google_says):
    gclient.post("/register", data={
        "csrf_token": csrf(gclient, "/register"), "email": "other@example.kz", "username": "fermer_dala",
        "password": "Dala2026soil", "password_confirm": "Dala2026soil", "region": "akmola", "farm_type": "farm",
    })
    google_says(GOOGLE_USER)
    gclient.get("/auth/google/callback")
    token = csrf(gclient, "/auth/google/complete")

    empty = gclient.post("/auth/google/complete", data={"csrf_token": token, "username": ""})
    html = empty.get_data(as_text=True)
    assert empty.status_code == 422
    assert MESSAGES["username_required"] in html and MESSAGES["region_required"] in html

    taken = gclient.post("/auth/google/complete", data={
        "csrf_token": token, "username": "FERMER_DALA", "region": "akmola", "farm_type": "farm"})
    assert taken.status_code == 422
    assert MESSAGES["username_taken"] in taken.get_data(as_text=True)


def test_google_only_account_cannot_use_password_login(gclient, google_says):
    google_says(GOOGLE_USER)
    gclient.get("/auth/google/callback")
    gclient.post("/auth/google/complete", data={
        "csrf_token": csrf(gclient, "/auth/google/complete"),
        "username": "fermer_dala", "region": "akmola", "farm_type": "farm",
    })
    gclient.post("/logout", data={"csrf_token": csrf(gclient, "/dashboard")})

    res = gclient.post("/login", data={"csrf_token": csrf(gclient, "/login"),
                                       "login": "fermer_dala", "password": "anything"})
    assert res.status_code == 401


def test_complete_page_requires_pending_google_login(gclient):
    assert gclient.get("/auth/google/complete").headers["Location"].endswith("/login")


def test_cancel_drops_pending_profile(gclient, google_says):
    google_says(GOOGLE_USER)
    gclient.get("/auth/google/callback")
    res = gclient.post("/auth/google/cancel", data={"csrf_token": csrf(gclient, "/auth/google/complete")})
    assert res.status_code == 303
    assert gclient.get("/auth/google/complete").headers["Location"].endswith("/login")
