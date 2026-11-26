"""Құпиясөзді қалпына келтіру: хат, бір реттік сілтеме, мерзімі, сессияларды жабу."""

import re

import psycopg
import pytest

import app.auth as auth_module
from app.validators import MESSAGES

USER = {"email": "info@example.kz", "full_name": "«Жасыл Дала» ШҚ", "username": "jasyl_dala",
        "password": "Dala2026soil", "password_confirm": "Dala2026soil", "region": "akmola", "farm_type": "farm"}
NEW_PW = "Steppe2027Carbon"


def token(client, path):
    html = client.get(path).get_data(as_text=True)
    return re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)


@pytest.fixture()
def outbox(monkeypatch):
    sent = []
    monkeypatch.setattr(auth_module, "send_mail", lambda to, subject, text: sent.append((to, subject, text)))
    return sent


@pytest.fixture()
def user(client):
    client.post("/register", data={**USER, "csrf_token": token(client, "/register")})
    client.get("/register/success")
    return USER


def ask_reset(client, email):
    return client.post("/forgot", data={"csrf_token": token(client, "/forgot"), "email": email})


def reset_link(outbox):
    return re.search(r"http://localhost(/reset/\S+)", outbox[-1][2]).group(1)


def login(client, password):
    return client.post("/login", data={"csrf_token": token(client, "/login"), "login": "jasyl_dala", "password": password})


def test_login_page_links_to_forgot(client):
    html = client.get("/login").get_data(as_text=True)
    assert 'href="/forgot" data-swap' in html


def test_full_reset_flow(client, user, outbox):
    res = ask_reset(client, "INFO@example.kz")  # регистрге қарамайды
    assert res.status_code == 303 and res.headers["Location"].endswith("/forgot/sent")
    assert "Поштаңызды" in client.get("/forgot/sent").get_data(as_text=True)
    assert len(outbox) == 1 and outbox[0][0] == "info@example.kz"
    link = reset_link(outbox)

    page = client.get(link)
    assert page.status_code == 200 and "@jasyl_dala" in page.get_data(as_text=True)
    assert page.headers["Referrer-Policy"] == "no-referrer"
    assert page.headers["Cache-Control"] == "no-store"

    res = client.post(link, data={"csrf_token": token(client, link), "password": NEW_PW, "password_confirm": NEW_PW})
    assert res.status_code == 303 and res.headers["Location"].endswith("/login")
    html = client.get("/login").get_data(as_text=True)
    assert "Құпиясөз жаңартылды" in html and 'value="jasyl_dala"' in html

    assert login(client, "Dala2026soil").status_code == 401   # ескі құпиясөз жұмыс істемейді
    assert login(client, NEW_PW).status_code == 303           # жаңасы жұмыс істейді


def test_unknown_email_gets_same_answer_and_no_mail(client, user, outbox):
    known = ask_reset(client, "info@example.kz")
    client.get("/forgot/sent")
    unknown = ask_reset(client, "nobody@example.kz")
    assert known.status_code == unknown.status_code == 303
    assert known.headers["Location"] == unknown.headers["Location"]
    assert len(outbox) == 1  # тіркелмеген email-ге хат кетпейді


def test_link_is_single_use(client, user, outbox):
    ask_reset(client, "info@example.kz")
    link = reset_link(outbox)
    client.post(link, data={"csrf_token": token(client, link), "password": NEW_PW, "password_confirm": NEW_PW})
    again = client.get(link)
    assert again.status_code == 410 and "жарамсыз" in again.get_data(as_text=True)


def test_expired_link_is_refused(client, user, outbox, db_url):
    ask_reset(client, "info@example.kz")
    link = reset_link(outbox)
    with psycopg.connect(db_url, autocommit=True) as conn:
        conn.execute("UPDATE password_resets SET expires_at = NOW() - interval '1 minute'")
    assert client.get(link).status_code == 410


def test_garbage_token_is_refused(client):
    assert client.get("/reset/not-a-real-token-but-long-enough").status_code == 410
    assert client.get("/reset/x").status_code == 410


def test_token_stored_only_as_hash(client, user, outbox, db_url):
    ask_reset(client, "info@example.kz")
    raw = reset_link(outbox).rsplit("/", 1)[1]
    with psycopg.connect(db_url) as conn:
        stored = conn.execute("SELECT token_hash FROM password_resets").fetchone()[0]
    assert raw not in stored and len(stored) == 64


def test_throttle_one_mail_per_minute(client, user, outbox):
    ask_reset(client, "info@example.kz")
    ask_reset(client, "info@example.kz")
    assert len(outbox) == 1


def test_new_password_is_validated(client, user, outbox):
    ask_reset(client, "info@example.kz")
    link = reset_link(outbox)
    res = client.post(link, data={"csrf_token": token(client, link), "password": "short", "password_confirm": "other"})
    html = res.get_data(as_text=True)
    assert res.status_code == 422
    assert MESSAGES["password_short"] in html and MESSAGES["confirm_mismatch"] in html
    res = client.post(link, data={"csrf_token": token(client, link), "password": "Jasyl_dala1", "password_confirm": "Jasyl_dala1"})
    assert res.status_code == 303  # логинге ұқсас, бірақ дәл өзі емес — рұқсат


def test_forgot_validates_email_and_needs_csrf(client):
    res = client.post("/forgot", data={"csrf_token": token(client, "/forgot"), "email": "not-an-email"})
    assert res.status_code == 422 and MESSAGES["email_invalid"] in res.get_data(as_text=True)
    assert client.post("/forgot", data={"email": "info@example.kz"}).status_code == 400


def test_reset_closes_other_sessions(app, client, user, outbox):
    other_device = app.test_client()
    login(other_device, "Dala2026soil")
    assert other_device.get("/dashboard").status_code == 200

    ask_reset(client, "info@example.kz")
    link = reset_link(outbox)
    client.post(link, data={"csrf_token": token(client, link), "password": NEW_PW, "password_confirm": NEW_PW})

    res = other_device.get("/dashboard")
    assert res.status_code == 302 and res.headers["Location"].endswith("/login")


def test_mail_link_uses_app_base_url(app, client, user, outbox):
    app.config["APP_BASE_URL"] = "https://dalacarbon.example"
    evil = {"Host": "evil.example"}  # шабуылдаушы Host тақырыбын бұрмалайды
    html = client.get("/forgot", headers=evil).get_data(as_text=True)
    csrf = re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)
    client.post("/forgot", data={"csrf_token": csrf, "email": "info@example.kz"}, headers=evil)
    assert outbox, "хат жіберілуі тиіс еді"
    assert "https://dalacarbon.example/reset/" in outbox[-1][2] and "evil.example" not in outbox[-1][2]


def test_dev_mail_survives_cp1251_console(app, monkeypatch):
    """Windows терминалы cp1251 болса да, хат мәтінін шығару сервер қатесіне (500) әкелмейді."""
    import io
    import sys

    from app.mailer import send_mail

    raw = io.BytesIO()
    monkeypatch.setattr(sys, "stdout", io.TextIOWrapper(raw, encoding="cp1251"))
    with app.app_context():
        send_mail("info@example.kz", "Құпиясөз ә ү ұ", "Сілтеме: http://localhost/reset/abc123")
    sys.stdout.flush()
    out = raw.getvalue().decode("cp1251")
    assert "LINK: http://localhost/reset/abc123" in out
