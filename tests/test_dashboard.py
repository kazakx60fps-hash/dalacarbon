"""Басқару тақтасы: беттер, алқаптарды қосу/өшіру және CSV есеп."""

import re

import psycopg
import pytest

from app.validators import PARCEL_MESSAGES

USER = {"email": "info@example.kz", "full_name": "«Жасыл Дала» ШҚ", "username": "jasyl_dala",
        "password": "Dala2026soil", "password_confirm": "Dala2026soil", "region": "akmola", "farm_type": "farm"}
OTHER = {**USER, "email": "other@example.kz", "full_name": "", "username": "other_farm"}


def token(client, path):
    html = client.get(path).get_data(as_text=True)
    return re.search(r'name="csrf_token" value="([^"]+)"', html).group(1)


def sign_in(client, user):
    client.post("/register", data={**user, "csrf_token": token(client, "/register")})
    client.post("/login", data={"csrf_token": token(client, "/login"), "login": user["username"], "password": user["password"]})


@pytest.fixture()
def farmer(client):
    sign_in(client, USER)
    return client


def add(client, **form):
    data = {"name": "Солтүстік алқап", "area_ha": "250", "crop": "wheat", "practice": "notill", **form}
    return client.post("/dashboard/parcels", data={"csrf_token": token(client, "/dashboard"), **data})


def test_dashboard_has_all_sections_and_actions(farmer):
    html = farmer.get("/dashboard").get_data(as_text=True)
    for view in ["overview", "analytics", "parcels", "schedule", "ndvi-map", "inbox", "activity", "settings"]:
        assert f'data-view="{view}"' in html and f'data-go="{view}"' in html
    for dialog in ["parcel-modal", "palette", "drawer"]:
        assert f'id="{dialog}"' in html and f'data-open="{dialog}"' in html
    assert 'href="/dashboard/report.csv"' in html
    assert 'id="dash-data"' in html and "js/dash3.js" in html
    assert "Әзірге алқап жоқ" in html


def test_add_parcel_saves_and_returns_estimate(farmer, db_url):
    res = add(farmer, area_ha="250,5")
    assert res.status_code == 201
    parcel = res.get_json()["parcel"]
    assert parcel["name"] == "Солтүстік алқап" and parcel["area_ha"] == 250.5
    assert parcel["crop"] == "Бидай" and parcel["practice"] == "Жыртпай егу (No-till)"
    assert parcel["tonnes"] == round(250.5 * 0.6375, 1) and parcel["farmer_usd"] == round(250.5 * 0.6375 * 16 * 0.75)
    with psycopg.connect(db_url) as conn:
        assert conn.execute("SELECT COUNT(*) FROM parcels").fetchone()[0] == 1
    assert "Солтүстік алқап" in farmer.get("/dashboard").get_data(as_text=True)


@pytest.mark.parametrize("form, field, message", [
    ({"name": "  "}, "name", "name_required"),
    ({"name": "x" * 61}, "name", "name_too_long"),
    ({"area_ha": ""}, "area_ha", "area_required"),
    ({"area_ha": "0"}, "area_ha", "area_invalid"),
    ({"area_ha": "abc"}, "area_ha", "area_invalid"),
    ({"area_ha": "nan"}, "area_ha", "area_invalid"),
    ({"area_ha": "200000"}, "area_ha", "area_invalid"),
    ({"crop": "corn"}, "crop", "crop_required"),
    ({"practice": ""}, "practice", "practice_required"),
])
def test_add_parcel_validation(farmer, form, field, message):
    res = add(farmer, **form)
    assert res.status_code == 422
    assert res.get_json()["errors"][field] == PARCEL_MESSAGES[message]


def test_parcel_routes_need_login_and_csrf(client, farmer):
    assert farmer.post("/dashboard/parcels", data={"name": "A", "area_ha": "1", "crop": "wheat", "practice": "cover"}).status_code == 400
    farmer.post("/logout", data={"csrf_token": token(farmer, "/dashboard")})
    assert farmer.post("/dashboard/parcels").headers["Location"].endswith("/login")
    assert farmer.get("/dashboard/report.csv").status_code == 302


def test_delete_own_parcel_only(app, farmer):
    pid = add(farmer).get_json()["parcel"]["id"]

    intruder = app.test_client()
    sign_in(intruder, OTHER)
    res = intruder.post(f"/dashboard/parcels/{pid}/delete", data={"csrf_token": token(intruder, "/dashboard")})
    assert res.status_code == 404  # бөтен алқапты өшіре алмайды

    res = farmer.post(f"/dashboard/parcels/{pid}/delete", data={"csrf_token": token(farmer, "/dashboard")})
    assert res.status_code == 200 and res.get_json() == {"ok": True}
    assert "Әзірге алқап жоқ" in farmer.get("/dashboard").get_data(as_text=True)


def test_report_csv(farmer):
    add(farmer, name="Өзен бойы", area_ha="100")
    res = farmer.get("/dashboard/report.csv")
    assert res.status_code == 200
    assert res.mimetype == "text/csv"
    assert "attachment" in res.headers["Content-Disposition"]
    text = res.get_data(as_text=True)
    assert text.startswith("﻿DalaCarbon AI")
    assert "Өзен бойы;100,0;Бидай" in text
    assert "Фермер табысы, $/жыл;38250" in text


def dash_data(client):
    import json
    html = client.get("/dashboard").get_data(as_text=True)
    return html, json.loads(re.search(r'<script type="application/json" id="dash-data">(.*?)</script>', html, re.S).group(1))


def test_ndvi_map_uses_modis_without_key(farmer):
    html, data = dash_data(farmer)
    assert "vendor/leaflet/leaflet.js" in html and "data-lmap" in html
    assert data["ndvi"]["provider"] == "modis" and data["ndvi"]["instance"] == ""
    assert data["ndvi"]["region"] == "akmola" and len(data["ndvi"]["regions"]) == 17
    assert data["ndvi"]["border"].startswith("/static/data/kazakhstan.geojson")
    assert "NASA GIBS" in html
    csp = farmer.get("/dashboard").headers["Content-Security-Policy"]
    assert "https://gibs.earthdata.nasa.gov" in csp and "https://sh.dataspace.copernicus.eu" in csp
    assert "script-src 'self';" in csp  # Leaflet жобаның ішінен жүктеледі, CDN жоқ


def test_ndvi_map_switches_to_sentinel_with_instance_id(farmer, app):
    app.config["SENTINEL_HUB_INSTANCE_ID"] = "test-instance-id"
    html, data = dash_data(farmer)
    assert data["ndvi"]["provider"] == "sentinel" and data["ndvi"]["instance"] == "test-instance-id"
    assert "Copernicus Sentinel-2" in html


def test_kazakhstan_border_is_served(client):
    import json
    res = client.get("/static/data/kazakhstan.geojson")
    geom = json.loads(res.get_data(as_text=True))["features"][0]["geometry"]
    assert geom["type"] in ("Polygon", "MultiPolygon")
