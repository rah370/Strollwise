from app.utils.geo_utils import within_cebu_service_area


def test_cebu_center_is_inside_service_area():
    assert within_cebu_service_area(10.3157, 123.8854)


def test_manila_is_outside_service_area():
    assert not within_cebu_service_area(14.5995, 120.9842)
