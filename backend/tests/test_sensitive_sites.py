from __future__ import annotations

from app.services.sensitive_sites import (
    SENSITIVE_SITES,
    public_place_name,
    site_at,
    tags_name_facility,
    text_names_facility,
)


def test_hospital_centroid_is_on_building():
    hospital = next(s for s in SENSITIVE_SITES if s.kind == "hospital")
    assert site_at(hospital.lat, hospital.lng) is not None


def test_canteen_that_used_to_fail_is_outside_building():
    # Old bbox test pin: hospital-adjacent canteen, not the building.
    assert site_at(10.2968, 123.8946) is None


def test_forty_meters_off_hospital_is_taggable():
    hospital = next(s for s in SENSITIVE_SITES if s.kind == "hospital")
    assert site_at(hospital.lat + 0.00050, hospital.lng) is None


def test_identity_phrases_do_not_catch_police_nearby():
    assert tags_name_facility(["police nearby"], None) is False
    assert tags_name_facility(["cafe"], "Police nearby after 10pm") is False
    assert text_names_facility("hospital") is True
    assert tags_name_facility(["police station"], None) is True
    assert text_names_facility("Camp Sergio Osmeña") is True


def test_public_place_name_never_titles_police_station():
    name = public_place_name("Police Station", 10.3118, 123.8918)
    assert "police" not in name.lower()
    assert name
