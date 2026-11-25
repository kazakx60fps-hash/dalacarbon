"""Жүйеге кіргеннен кейінгі негізгі бет."""

from __future__ import annotations

from flask import Blueprint, g, render_template

from .auth import login_required
from .validators import FARM_TYPES, REGIONS, label_for

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


def _pilot_numbers() -> dict:
    net_per_ha = PILOT["seq_t_per_ha"] * (1 - PILOT["buffer"])        # 0,6375 т
    revenue_per_ha = net_per_ha * PILOT["price_usd"]                   # $10,20
    farmer_per_ha = revenue_per_ha * PILOT["farmer_share"]             # $7,65
    return {
        "area": f"{PILOT['area_ha']:,}".replace(",", " "),
        "net_total": f"{round(net_per_ha * PILOT['area_ha']):,}".replace(",", " "),
        "farmer_total": f"${round(farmer_per_ha * PILOT['area_ha']):,}".replace(",", " "),
        "price": f"${PILOT['price_usd']}",
        "revenue_per_ha": f"${revenue_per_ha:.2f}".replace(".", ","),
        "farmer_per_ha": f"${farmer_per_ha:.2f}".replace(".", ","),
        "platform_per_ha": f"${revenue_per_ha - farmer_per_ha:.2f}".replace(".", ","),
        "net_per_ha": f"{net_per_ha:.4f}".rstrip("0").replace(".", ","),
    }


def _ndvi_cells(cols: int = 24, rows: int = 8) -> list[int]:
    cells = []
    for r in range(rows):
        for c in range(cols):
            base = 0.72 if c < 8 else (0.12 if (c < 15 and r > 4) else (0.45 if c < 15 else 0.9))
            noise = ((c * 37 + r * 61) % 7) / 7 * 0.3 - 0.15
            cells.append(int(min(max(base + noise, 0.0), 0.999) * 6))
    return cells


def _initials(name: str) -> str:
    words = ["".join(ch for ch in w if ch.isalnum()) for w in name.split()]
    letters = [w[0] for w in words if w][:2]
    return "".join(letters).upper() or "DC"


@bp.get("/dashboard")
@login_required
def dashboard():
    user = g.user
    display_name = user["full_name"] or user["username"]
    return render_template(
        "dashboard.html",
        display_name=display_name,
        initials=_initials(display_name),
        username=user["username"],
        region=label_for(REGIONS, user["region"]),
        farm_type=label_for(FARM_TYPES, user["farm_type"]),
        n=_pilot_numbers(),
        ndvi=_ndvi_cells(),
    )
