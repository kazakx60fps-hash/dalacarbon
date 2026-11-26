from app.validators import MESSAGES

FORM = {
    "email": "info@example.kz",
    "full_name": "«Жасыл Дала» ШҚ",
    "username": "jasyl_dala",
    "password": "Dala2026soil",
    "password_confirm": "Dala2026soil",
    "region": "akmola",
    "farm_type": "farm",
}


def post(client, csrf, **overrides):
    return client.post("/register", data={**FORM, "csrf_token": csrf(), **overrides})


def test_register_page_renders(client):
    res = client.get("/register")
    html = res.get_data(as_text=True)
    assert res.status_code == 200
    assert "DalaCarbon" in html and "Аккаунт ашу" in html
    assert 'type="password"' in html
    assert 'data-v7' in html and 'id="intro"' in html  # кіру бетімен бірдей макет (спутник + V7)
    assert 'href="/login" data-swap' in html
    assert "Content-Security-Policy" in res.headers


def test_successful_registration_stores_argon2_hash(client, csrf, fetch_user):
    res = post(client, csrf, newsletter="on")
    assert res.status_code == 303
    assert res.headers["Location"].endswith("/register/success")

    user = fetch_user("jasyl_dala")
    assert user["email"] == "info@example.kz"
    assert user["region"] == "akmola" and user["newsletter"] is True
    assert user["password_hash"].startswith("$argon2id$")
    assert "Dala2026soil" not in user["password_hash"]

    page = client.get("/register/success").get_data(as_text=True)
    assert "Тіркелу сәтті өтті" in page and "jasyl_dala" in page


def test_empty_fields_show_inline_errors(client, csrf, fetch_user):
    res = client.post("/register", data={"csrf_token": csrf()})
    html = res.get_data(as_text=True)
    assert res.status_code == 422
    for key in ("email_required", "username_required", "password_required", "region_required"):
        assert MESSAGES[key] in html
    assert fetch_user("jasyl_dala") is None


def test_password_mismatch_rejected_and_values_kept(client, csrf, fetch_user):
    res = post(client, csrf, password_confirm="Dala2026soi")
    html = res.get_data(as_text=True)
    assert res.status_code == 422
    assert MESSAGES["confirm_mismatch"] in html
    assert 'value="jasyl_dala"' in html          # енгізілген логин сақталды
    assert "Dala2026soil" not in html             # құпиясөз қайта шықпайды
    assert fetch_user("jasyl_dala") is None


def test_duplicate_username_and_email_are_polite(client, csrf):
    assert post(client, csrf).status_code == 303
    res = post(client, csrf, username="JASYL_DALA", email="INFO@example.kz")
    html = res.get_data(as_text=True)
    assert res.status_code == 422
    assert MESSAGES["username_taken"] in html
    assert MESSAGES["email_taken"] in html


def test_missing_csrf_token_is_refused(client, fetch_user):
    res = client.post("/register", data=FORM)
    assert res.status_code == 400
    assert fetch_user("jasyl_dala") is None


def test_sql_injection_attempt_is_just_an_invalid_login(client, csrf, db_url):
    import psycopg

    res = post(client, csrf, username="x'; DROP TABLE users; --")
    assert res.status_code == 422
    with psycopg.connect(db_url) as conn:  # кесте орнында
        assert conn.execute("SELECT COUNT(*) FROM users").fetchone()[0] == 0


def test_success_page_without_registration_redirects(client):
    res = client.get("/register/success")
    assert res.status_code == 302
