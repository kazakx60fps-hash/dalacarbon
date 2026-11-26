import re

import pytest

from app.validators import MESSAGES

USER = {
    "email": "info@example.kz",
    "full_name": "«Жасыл Дала» ШҚ",
    "username": "jasyl_dala",
    "password": "Dala2026soil",
    "password_confirm": "Dala2026soil",
    "region": "akmola",
    "farm_type": "farm",
}


def token(client, path="/login"):
    html = client.get(path).get_data(as_text=True)
    return re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)


@pytest.fixture()
def registered(client):
    res = client.post("/register", data={**USER, "csrf_token": token(client, "/register")})
    assert res.status_code == 303
    client.get("/register/success")
    return USER


def login(client, **form):
    return client.post("/login", data={"csrf_token": token(client), **form})


def test_login_page_renders(client):
    html = client.get("/login").get_data(as_text=True)
    assert 'id="login-title"' in html and "Қош <em>келдіңіз!</em>" in html
    assert 'data-v7' in html and "js/auth3.js" in html  # V7 шыны картасы + ауысу анимациясы
    assert 'href="/register" data-swap' in html
    assert 'name="login"' in html and 'type="password"' in html
    assert 'id="intro"' in html and "Анимацияны өткізу" in html  # Figma: анимациялы интро
    assert "Алқаптардың" in html and "Пилоттық алқап" in html


def test_success_page_prefills_login(client, registered):
    html = client.get("/login").get_data(as_text=True)
    assert 'value="jasyl_dala"' in html


def test_empty_fields_show_inline_errors(client):
    res = login(client)
    html = res.get_data(as_text=True)
    assert res.status_code == 422
    assert MESSAGES["login_required"] in html
    assert MESSAGES["login_password_required"] in html


def test_correct_credentials_open_dashboard(client, registered):
    res = login(client, login="jasyl_dala", password="Dala2026soil")
    assert res.status_code == 303
    assert res.headers["Location"].endswith("/dashboard")
    page = client.get("/dashboard").get_data(as_text=True)
    assert "Басқару тақтасы" in page
    assert "«Жасыл Дала» ШҚ" in page
    assert "Ақмола облысы" in page
    assert "$38 250" in page and "$10,20" in page  # жоба құжатындағы пилоттық сценарий
    assert 'id="ndvi"' in page and 'id="income"' in page


@pytest.mark.parametrize("identifier", ["JASYL_DALA", "Info@Example.kz"])
def test_login_by_email_or_any_case(client, registered, identifier):
    res = login(client, login=identifier, password="Dala2026soil")
    assert res.status_code == 303


def test_wrong_password_and_unknown_user_get_identical_answer(client, registered):
    wrong = login(client, login="jasyl_dala", password="Wrong2026pass")
    unknown = login(client, login="nobody_here", password="Wrong2026pass")
    assert wrong.status_code == unknown.status_code == 401

    def banner(res):
        html = res.get_data(as_text=True)
        return re.search(r'role="alert".*?</div>\s*</div>', html, re.S).group(0)

    assert banner(wrong) == banner(unknown)
    assert "Логин немесе құпиясөз сәйкес келмейді" in banner(wrong)
    assert client.get("/dashboard").status_code == 302  # кіргізбеді


def test_failed_login_keeps_identifier_but_not_password(client, registered):
    html = login(client, login="jasyl_dala", password="Wrong2026pass").get_data(as_text=True)
    assert 'value="jasyl_dala"' in html
    assert "Wrong2026pass" not in html


def test_dashboard_requires_login(client):
    res = client.get("/dashboard")
    assert res.status_code == 302 and res.headers["Location"].endswith("/login")


def test_remember_me_sets_persistent_cookie(client, registered):
    res = login(client, login="jasyl_dala", password="Dala2026soil", remember="on")
    assert "Expires=" in res.headers["Set-Cookie"]
    client.post("/logout", data={"csrf_token": token(client, "/dashboard")})
    res = login(client, login="jasyl_dala", password="Dala2026soil")
    assert "Expires=" not in res.headers["Set-Cookie"]


def test_logout_ends_session(client, registered):
    login(client, login="jasyl_dala", password="Dala2026soil")
    res = client.post("/logout", data={"csrf_token": token(client, "/dashboard")})
    assert res.status_code == 303
    assert client.get("/dashboard").status_code == 302


def test_logout_without_csrf_is_refused(client, registered):
    login(client, login="jasyl_dala", password="Dala2026soil")
    assert client.post("/logout").status_code == 400
    assert client.get("/dashboard").status_code == 200


def test_login_without_csrf_is_refused(client, registered):
    res = client.post("/login", data={"login": "jasyl_dala", "password": "Dala2026soil"})
    assert res.status_code == 400


def test_logged_in_user_skips_login_and_register(client, registered):
    login(client, login="jasyl_dala", password="Dala2026soil")
    assert client.get("/login").headers["Location"].endswith("/dashboard")
    assert client.get("/register").headers["Location"].endswith("/dashboard")
    assert client.get("/").headers["Location"].endswith("/dashboard")
