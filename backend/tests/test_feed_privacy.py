from types import SimpleNamespace

from app.services.feed_privacy import author_kind_for, feed_author_handle


def test_anonymous_tag_stays_local_or_visitor():
    report = SimpleNamespace(
        traveler_type_snapshot="local",
        user_type_snapshot="local_resident",
        tags_json=["food", "anonymous"],
        city_of_origin_snapshot="Cebu City",
    )
    user = SimpleNamespace(display_name="Maryama", email="warsamemaryama01@gmail.com")
    assert author_kind_for(report) == "local"
    assert feed_author_handle(report, user) == "@local"


def test_public_handle_never_uses_email():
    report = SimpleNamespace(
        traveler_type_snapshot="local",
        user_type_snapshot="local_resident",
        tags_json=["food", "public"],
        city_of_origin_snapshot="Cebu City",
    )
    user = SimpleNamespace(display_name="user@gmail.com", email="user@gmail.com")
    handle = feed_author_handle(report, user)
    assert handle == "@local"
    assert "@gmail" not in handle


def test_public_handle_uses_name_and_city():
    report = SimpleNamespace(
        traveler_type_snapshot="international",
        user_type_snapshot="international_visitor",
        tags_json=["public"],
        city_of_origin_snapshot="Cebu City",
    )
    user = SimpleNamespace(display_name="Marco", email="marco@example.com")
    assert author_kind_for(report) == "visitor"
    assert feed_author_handle(report, user) == "@marco_cebucity"
