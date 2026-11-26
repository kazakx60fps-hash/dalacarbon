"""Жүйеге кіргеннен кейінгі басқару тақтасы: беттің деректері, алқаптар және CSV есеп."""

from __future__ import annotations

import csv
import io
from datetime import date, datetime, timedelta

from flask import Blueprint, Response, abort, current_app, g, jsonify, render_template, request, url_for

from .auth import login_required
from .db import delete_parcel, get_db, insert_parcel, list_parcels
from .security import check_csrf
from .validators import CROPS, FARM_TYPES, PRACTICES, REGIONS, label_for, validate_parcel

bp = Blueprint("main", __name__)

# Жоба құжатындағы базалық пилоттық сценарий (демо деректер):
# 5 000 га, 0,75 т CO₂e/га/жыл, 15% буферлік пул, $16/т, фермерге 75%.
PILOT = {
    "area_ha": 5_000,
    "seq_t_per_ha": 0.75,
    "buffer": 0.15,
    "price_usd": 16,
    "farmer_share": 0.75,
}
NET_PER_HA = PILOT["seq_t_per_ha"] * (1 - PILOT["buffer"])            # 0,6375 т CO₂e

MONTHS = ["Қаңтар", "Ақпан", "Наурыз", "Сәуір", "Мамыр", "Маусым",
          "Шілде", "Тамыз", "Қыркүйек", "Қазан", "Қараша", "Желтоқсан"]
MONTHS_SHORT = ["Қаң", "Ақп", "Нау", "Сәу", "Мам", "Мау", "Шіл", "Там", "Қыр", "Қаз", "Қар", "Жел"]
WEEKDAYS = ["Дүйсенбі", "Сейсенбі", "Сәрсенбі", "Бейсенбі", "Жұма", "Сенбі", "Жексенбі"]
WEEKDAYS_SHORT = ["Дс", "Сс", "Ср", "Бс", "Жм", "Сб", "Жк"]

# Жыл ішінде көміртегі қалай жиналады (өсу маусымы — сәуір–қыркүйек). Қосындысы 1.
SEASON = [0.01, 0.01, 0.02, 0.08, 0.14, 0.17, 0.16, 0.14, 0.11, 0.08, 0.05, 0.03]

# Пилоттық алаңның төрт учаскесі (NDVI картасындағы төрт полигон).
PILOT_PARCELS = [
    ("Солтүстік алқап", 1_976),
    ("Өзен бойы", 1_350),
    ("Шығыс телім", 1_002),
    ("Жайылым", 672),
]


# Облыс орталықтары (ендік, бойлық) — NDVI картасы пайдаланушының облысынан ашылады.
REGION_CENTERS = {
    "abai": (50.41, 80.23), "akmola": (53.28, 69.39), "aktobe": (50.28, 57.17), "almaty": (43.87, 77.07),
    "atyrau": (47.11, 51.88), "wko": (51.23, 51.37), "zhambyl": (42.90, 71.37), "zhetisu": (45.02, 78.37),
    "karaganda": (49.81, 73.09), "kostanay": (53.21, 63.62), "kyzylorda": (44.85, 65.51), "mangystau": (43.65, 51.20),
    "pavlodar": (52.29, 76.97), "nko": (54.87, 69.14), "turkistan": (43.30, 68.25), "ulytau": (47.78, 67.71),
    "eko": (49.95, 82.61),
}


def _ndvi_config(today: date, region: str) -> dict:
    """Карта дереккөзі: Sentinel-2 (Instance ID болса) немесе NASA MODIS (кілтсіз)."""
    instance = current_app.config.get("SENTINEL_HUB_INSTANCE_ID", "")
    # Өсу маусымы: маусым–тамыз. Қазан–наурызда жерді қар басады, NDVI «сұр» болып көрінеді.
    last_summer = today.year if today.month >= 9 else today.year - 1
    recent = today - timedelta(days=20)  # MODIS 16 күндік композиттері ~2 аптадан кейін шығады
    seasons = [
        {"key": f"s{last_summer}", "label": f"{last_summer} жазы", "from": f"{last_summer}-06-01",
         "to": f"{last_summer}-08-31", "date": f"{last_summer}-07-12"},
        {"key": f"s{last_summer - 1}", "label": f"{last_summer - 1} жазы", "from": f"{last_summer - 1}-06-01",
         "to": f"{last_summer - 1}-08-31", "date": f"{last_summer - 1}-07-12"},
        {"key": "recent", "label": "Соңғы сурет", "from": (today - timedelta(days=45)).isoformat(),
         "to": today.isoformat(), "date": recent.isoformat(), "winter": today.month in (11, 12, 1, 2, 3)},
    ]
    return {
        "provider": "sentinel" if instance else "modis",
        "instance": instance,
        "layer": current_app.config.get("SENTINEL_HUB_LAYER", "NDVI"),
        "seasons": seasons,
        "region": region,
        "regions": [{"key": k, "name": label_for(REGIONS, k), "center": REGION_CENTERS[k]} for k, _ in REGIONS],
        "border": url_for("static", filename="data/kazakhstan.geojson"),
    }


def _money(value: float) -> str:
    return f"${round(value):,}".replace(",", " ")


def _pilot_numbers() -> dict:
    revenue_per_ha = NET_PER_HA * PILOT["price_usd"]                    # $10,20
    farmer_per_ha = revenue_per_ha * PILOT["farmer_share"]             # $7,65
    return {
        "area_raw": PILOT["area_ha"],
        "area": f"{PILOT['area_ha']:,}".replace(",", " "),
        "net_raw": round(NET_PER_HA * PILOT["area_ha"]),
        "net_total": f"{round(NET_PER_HA * PILOT['area_ha']):,}".replace(",", " "),
        "farmer_raw": round(farmer_per_ha * PILOT["area_ha"]),
        "farmer_total": _money(farmer_per_ha * PILOT["area_ha"]),
        "price": f"${PILOT['price_usd']}",
        "revenue_per_ha": f"${revenue_per_ha:.2f}".replace(".", ","),
        "farmer_per_ha": f"${farmer_per_ha:.2f}".replace(".", ","),
        "platform_per_ha": f"${revenue_per_ha - farmer_per_ha:.2f}".replace(".", ","),
        "net_per_ha": f"{NET_PER_HA:.4f}".rstrip("0").replace(".", ","),
    }


def _initials(name: str) -> str:
    words = ["".join(ch for ch in w if ch.isalnum()) for w in name.split()]
    letters = [w[0] for w in words if w][:2]
    return "".join(letters).upper() or "DC"


def _greeting(hour: int) -> str:
    if 5 <= hour < 12:
        return "Қайырлы таң"
    if 12 <= hour < 18:
        return "Қайырлы күн"
    if 18 <= hour < 23:
        return "Қайырлы кеш"
    return "Қайырлы түн"


def _monthly_series(today: date) -> list[dict]:
    """Соңғы 12 айдағы секвестрация: өлшенген мән және RothC болжамы (демо)."""
    annual = NET_PER_HA * PILOT["area_ha"]
    out = []
    for back in range(11, -1, -1):
        m = (today.month - 1 - back) % 12
        forecast = annual * SEASON[m]
        wobble = 1 + (((m * 7 + 3) % 9) - 4) / 50                        # ±8%, тұрақты
        out.append({"label": MONTHS_SHORT[m], "measured": round(forecast * wobble), "forecast": round(forecast)})
    return out


def _events(today: date) -> dict[str, list[dict]]:
    """Ағымдағы айдағы жұмыс кестесі (демо): күн → оқиғалар."""
    plan = [
        ("09:30", "Топырақ сынамасын алу", "Солтүстік алқап", "field"),
        ("11:00", "Sentinel-2 суреті келеді", "Спутник", "sat"),
        ("14:00", "Агрономмен кездесу", "Онлайн", "meet"),
        ("10:00", "Верификатормен қоңырау", "Verra VVB", "meet"),
        ("16:30", "NDVI есебін тексеру", "Өзен бойы", "sat"),
        ("08:45", "Жамылғы дақыл егу", "Шығыс телім", "field"),
    ]
    start = today.replace(day=1)
    events: dict[str, list[dict]] = {}
    day = start
    while day.month == today.month:
        n = day.day
        items = []
        if n % 3 == 0 or day == today:
            items.append(plan[n % len(plan)])
        if n % 4 == 1 or day == today:
            items.append(plan[(n + 2) % len(plan)])
        if items:
            events[day.isoformat()] = [
                {"time": t, "title": title, "place": place, "kind": kind}
                for t, title, place, kind in sorted(set(items))
            ]
        day += timedelta(days=1)
    return events


def _parcel_json(row: dict) -> dict:
    area = float(row["area_ha"])
    tonnes = area * NET_PER_HA
    return {
        "id": row["id"],
        "name": row["name"],
        "area_ha": area,
        "crop": label_for(CROPS, row["crop"]),
        "practice": label_for(PRACTICES, row["practice"]),
        "tonnes": round(tonnes, 1),
        "farmer_usd": round(tonnes * PILOT["price_usd"] * PILOT["farmer_share"]),
    }


@bp.get("/dashboard")
@login_required
def dashboard():
    user = g.user
    now = datetime.now()
    today = now.date()
    monday = today - timedelta(days=today.weekday())
    display_name = user["full_name"] or user["username"]
    events = _events(today)
    parcels = [_parcel_json(r) for r in list_parcels(get_db(), user["id"])]

    data = {
        "today": today.isoformat(),
        "weekdays": WEEKDAYS,
        "weekdaysShort": WEEKDAYS_SHORT,
        "months": MONTHS,
        "series": _monthly_series(today),
        "events": events,
        "split": [{"name": name, "tonnes": round(ha * NET_PER_HA)} for name, ha in PILOT_PARCELS],
        "parcels": parcels,
        "netPerHa": NET_PER_HA,
        "price": PILOT["price_usd"],
        "farmerShare": PILOT["farmer_share"],
        "ndvi": _ndvi_config(today, user["region"]),
    }
    return render_template(
        "dashboard.html",
        display_name=display_name,
        initials=_initials(display_name),
        user=user,
        region=label_for(REGIONS, user["region"]),
        farm_type=label_for(FARM_TYPES, user["farm_type"]),
        greeting=_greeting(now.hour),
        today=today,
        today_label=f"{WEEKDAYS[today.weekday()]}, {today.day} {MONTHS[today.month - 1].lower()}",
        month_label=f"{MONTHS[today.month - 1]} {today.year}",
        week=[monday + timedelta(days=i) for i in range(7)],
        weekdays_short=WEEKDAYS_SHORT,
        weekday_name=WEEKDAYS[today.weekday()],
        today_events=events.get(today.isoformat(), []),
        n=_pilot_numbers(),
        parcels=parcels,
        crops=CROPS,
        practices=PRACTICES,
        data=data,
    )


@bp.post("/dashboard/parcels")
@login_required
def add_parcel():
    check_csrf()
    parcel, errors = validate_parcel(request.form)
    if errors:
        return jsonify(ok=False, errors=errors), 422
    row = insert_parcel(get_db(), g.user["id"], parcel)
    return jsonify(ok=True, parcel=_parcel_json(row)), 201


@bp.post("/dashboard/parcels/<int:parcel_id>/delete")
@login_required
def remove_parcel(parcel_id: int):
    check_csrf()
    if not delete_parcel(get_db(), g.user["id"], parcel_id):
        abort(404)
    return jsonify(ok=True)


@bp.get("/dashboard/report.csv")
@login_required
def report_csv():
    """Excel дұрыс ашуы үшін UTF-8 BOM және «;» бөлгіші."""
    today = date.today()
    n = _pilot_numbers()
    buf = io.StringIO()
    w = csv.writer(buf, delimiter=";")
    w.writerow(["DalaCarbon AI — MRV есебі", today.isoformat()])
    w.writerow(["Шаруашылық", g.user["full_name"] or g.user["username"], label_for(REGIONS, g.user["region"])])
    w.writerow([])
    w.writerow(["Пилоттық сценарий (демо)", "Мәні"])
    w.writerow(["Алаң, га", PILOT["area_ha"]])
    w.writerow(["Таза секвестрация, т CO₂e/жыл", n["net_raw"]])
    w.writerow(["Кредит бағасы, $/т", PILOT["price_usd"]])
    w.writerow(["Фермер табысы, $/жыл", n["farmer_raw"]])
    w.writerow([])
    w.writerow(["Ай", "Өлшенген, т CO₂e", "RothC болжамы, т CO₂e"])
    for point in _monthly_series(today):
        w.writerow([point["label"], point["measured"], point["forecast"]])
    w.writerow([])
    w.writerow(["Менің алқаптарым", "Аудан, га", "Дақыл", "Тәжірибе", "Секвестрация, т CO₂e/жыл", "Фермер табысы, $"])
    for p in (_parcel_json(r) for r in list_parcels(get_db(), g.user["id"])):
        w.writerow([p["name"], str(p["area_ha"]).replace(".", ","), p["crop"], p["practice"],
                    str(p["tonnes"]).replace(".", ","), p["farmer_usd"]])
    return Response(
        "﻿" + buf.getvalue(),
        mimetype="text/csv",
        headers={"Content-Disposition": f'attachment; filename="dalacarbon-report-{today.isoformat()}.csv"'},
    )
