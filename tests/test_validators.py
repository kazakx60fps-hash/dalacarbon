from app.security import hash_password, verify_password
from app.validators import MESSAGES, password_checks, validate_registration

VALID = {
    "email": "Info@Example.kz",
    "full_name": "  «Жасыл   Дала» ШҚ ",
    "username": "jasyl_dala",
    "password": "Dala2026soil",
    "password_confirm": "Dala2026soil",
    "region": "akmola",
    "farm_type": "farm",
    "newsletter": "on",
}


def test_valid_form_has_no_errors_and_is_normalised():
    data, errors = validate_registration(VALID)
    assert errors == {}
    assert data["email"] == "info@example.kz"
    assert data["full_name"] == "«Жасыл Дала» ШҚ"
    assert data["newsletter"] is True


def test_empty_form_reports_every_required_field():
    _, errors = validate_registration({})
    assert errors == {
        "email": MESSAGES["email_required"],
        "username": MESSAGES["username_required"],
        "password": MESSAGES["password_required"],
        "password_confirm": MESSAGES["confirm_required"],
        "region": MESSAGES["region_required"],
        "farm_type": MESSAGES["farm_type_required"],
    }


def test_full_name_is_optional():
    _, errors = validate_registration({**VALID, "full_name": ""})
    assert "full_name" not in errors


def test_bad_email_and_username():
    _, errors = validate_registration({**VALID, "email": "no-at-sign", "username": "ab"})
    assert errors["email"] == MESSAGES["email_invalid"]
    assert errors["username"] == MESSAGES["username_invalid"]


def test_cyrillic_username_rejected():
    _, errors = validate_registration({**VALID, "username": "дала_фермер"})
    assert errors["username"] == MESSAGES["username_invalid"]


def test_password_rules_in_order():
    cases = {
        "Ab1": "password_short",
        "dala2026soil": "password_case",
        "DalaSoilField": "password_digit",
        "x" * 129: "password_long",
    }
    for pw, key in cases.items():
        _, errors = validate_registration({**VALID, "password": pw, "password_confirm": pw})
        assert errors["password"] == MESSAGES[key], pw


def test_password_equal_to_username_rejected():
    form = {**VALID, "username": "Dala2026soil"}
    _, errors = validate_registration(form)
    assert errors["password"] == MESSAGES["password_is_username"]


def test_kazakh_letters_count_for_case_rule():
    assert password_checks("Құпия2026сөз")["case"] is True


def test_confirm_mismatch():
    _, errors = validate_registration({**VALID, "password_confirm": "Dala2026soi"})
    assert errors["password_confirm"] == MESSAGES["confirm_mismatch"]


def test_unknown_region_rejected():
    _, errors = validate_registration({**VALID, "region": "mars"})
    assert errors["region"] == MESSAGES["region_required"]


def test_argon2id_hash_roundtrip():
    h = hash_password("Dala2026soil")
    assert h.startswith("$argon2id$")
    assert "Dala2026soil" not in h
    assert verify_password(h, "Dala2026soil")
    assert not verify_password(h, "wrong")
    assert hash_password("Dala2026soil") != h  # әр жолы жаңа тұз
