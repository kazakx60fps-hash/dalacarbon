"""Мобильді қосымшаның JSON API-ы (/api/v1): токен, кіру/тіркелу, деректер, алқаптар."""

import re

import psycopg
import pytest

import app.auth as auth_module
from app.validators import MESSAGES

USER = {"email": "info@example.kz", "full_name": "«Жасыл Дала» ШҚ", "username": "jasyl_dala",
        "password": "Dala2026soil", "password_confirm": "Dala2026soil", "region": "akmola", "farm_type": "farm"}


def bearer(token):
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def token(client):
    res = client.post("/api/v1/auth/register", json=USER)
    assert res.status_code == 201, res.get_json()
    return res.get_json()["token"]


def test_register_returns_token_and_user(client, db_url):
    res = client.post("/api/v1/auth/register", json={**USER, "newsletter": True})
    body = res.get_json()
    assert res.status_code == 201 and body["ok"] is True
    assert body["user"]["username"] == "jasyl_dala" and body["user"]["region_label"] == "Ақмола облысы"
    assert body["user"]["login_methods"] == ["password"]
    with psycopg.connect(db_url) as conn:
        stored = conn.execute("SELECT token_hash FROM api_tokens").fetchone()[0]
    assert body["token"] not in stored and len(stored) == 64  # тек хеш


def test_register_validation_matches_website(client, token):
    res = client.post("/api/v1/auth/register", json={**USER, "password": "short", "password_confirm": "x"})
    errors = res.get_json()["errors"]
    assert res.status_code == 422
    assert errors["password"] == MESSAGES["password_short"]
    assert errors["password_confirm"] == MESSAGES["confirm_mismatch"]
    taken = client.post("/api/v1/auth/register", json=USER).get_json()["errors"]
    assert taken["username"] == MESSAGES["username_taken"] and taken["email"] == MESSAGES["email_taken"]


def test_login_with_username_or_email(client, token):
    for ident in ["JASYL_DALA", "Info@Example.kz"]:
        res = client.post("/api/v1/auth/login", json={"login": ident, "password": "Dala2026soil"})
        assert res.status_code == 200 and res.get_json()["token"]


def test_wrong_and_unknown_login_get_identical_answer(client, token):
    wrong = client.post("/api/v1/auth/login", json={"login": "jasyl_dala", "password": "Wrong2026pass"})
    unknown = client.post("/api/v1/auth/login", json={"login": "nobody_here", "password": "Wrong2026pass"})
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.get_json() == unknown.get_json()
    assert wrong.get_json()["error"] == MESSAGES["invalid_credentials"]


def test_empty_login_is_422(client):
    res = client.post("/api/v1/auth/login", json={})
    assert res.status_code == 422
    assert res.get_json()["errors"]["login"] == MESSAGES["login_required"]


@pytest.mark.parametrize("headers", [{}, {"Authorization": "Bearer not-a-real-token-at-all-xx"}, {"Authorization": "Token abc"}])
def test_protected_routes_need_valid_token(client, headers):
    for path in ["/api/v1/me", "/api/v1/dashboard", "/api/v1/parcels", "/api/v1/report.csv"]:
        res = client.get(path, headers=headers)
        assert res.status_code == 401 and res.get_json()["ok"] is False


def test_dashboard_payload(client, token):
    res = client.get("/api/v1/dashboard", headers=bearer(token))
    body = res.get_json()
    assert res.status_code == 200
    assert body["numbers"]["farmer_total"] == "$38 250" and body["numbers"]["revenue_per_ha"] == "$10,20"
    assert len(body["data"]["series"]) == 12 and len(body["data"]["split"]) == 4
    assert body["data"]["ndvi"]["provider"] == "modis" and len(body["data"]["ndvi"]["regions"]) == 17
    assert len(body["inbox"]) == 4 and len(body["notifs"]) == 2 and len(body["activity"]) == 5
    assert {c["key"] for c in body["crops"]} >= {"wheat", "pasture"}


def test_parcels_crud_and_ownership(app, client, token):
    res = client.post("/api/v1/parcels", headers=bearer(token),
                      json={"name": "Өзен бойы", "area_ha": 120.5, "crop": "barley", "practice": "cover"})
    assert res.status_code == 201
    parcel = res.get_json()["parcel"]
    assert parcel["crop"] == "Арпа" and parcel["area_ha"] == 120.5

    bad = client.post("/api/v1/parcels", headers=bearer(token), json={"name": "", "area_ha": 0})
    assert bad.status_code == 422 and set(bad.get_json()["errors"]) >= {"name", "area_ha", "crop", "practice"}

    listed = client.get("/api/v1/parcels", headers=bearer(token)).get_json()["parcels"]
    assert [p["name"] for p in listed] == ["Өзен бойы"]

    other = client.post("/api/v1/auth/register", json={**USER, "email": "o@example.kz", "username": "other_farm"})
    other_token = other.get_json()["token"]
    assert client.delete(f"/api/v1/parcels/{parcel['id']}", headers=bearer(other_token)).status_code == 404
    assert client.delete(f"/api/v1/parcels/{parcel['id']}", headers=bearer(token)).status_code == 200
    assert client.get("/api/v1/parcels", headers=bearer(token)).get_json()["parcels"] == []


def test_report_csv_with_token(client, token):
    res = client.get("/api/v1/report.csv", headers=bearer(token))
    assert res.status_code == 200 and res.mimetype == "text/csv"
    assert res.get_data(as_text=True).startswith("﻿DalaCarbon AI")


def test_logout_revokes_token(client, token):
    assert client.post("/api/v1/auth/logout", headers=bearer(token)).status_code == 204
    assert client.get("/api/v1/me", headers=bearer(token)).status_code == 401


def test_password_reset_revokes_tokens(client, token, monkeypatch):
    sent = []
    monkeypatch.setattr(auth_module, "send_mail", lambda to, subject, text: sent.append(text))
    res = client.post("/api/v1/auth/forgot", json={"email": "info@example.kz"})
    assert res.status_code == 202 and len(sent) == 1
    unknown = client.post("/api/v1/auth/forgot", json={"email": "nobody@example.kz"})
    assert unknown.status_code == 202 and unknown.get_json() == res.get_json() and len(sent) == 1

    link = re.search(r"http://localhost(/reset/\S+)", sent[0]).group(1)
    html = client.get(link).get_data(as_text=True)
    csrf = re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)
    client.post(link, data={"csrf_token": csrf, "password": "Steppe2027Carbon", "password_confirm": "Steppe2027Carbon"})
    assert client.get("/api/v1/me", headers=bearer(token)).status_code == 401  # ескі токен жабылды


def test_meta_and_json_errors(client):
    meta = client.get("/api/v1/meta").get_json()
    assert len(meta["regions"]) == 17 and len(meta["farm_types"]) == 4
    missing = client.get("/api/v1/nope")
    assert missing.status_code == 404 and missing.get_json()["ok"] is False
