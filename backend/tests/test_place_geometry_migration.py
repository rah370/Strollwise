from pathlib import Path
import importlib.util

_MIGRATION = (
    Path(__file__).resolve().parents[1]
    / "alembic"
    / "versions"
    / "0012_db_health_indexes_and_place_geometry.py"
)


def _load_migration():
    spec = importlib.util.spec_from_file_location("migration_0012", _MIGRATION)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_place_geometry_migration_accepts_ewkb_hex_and_invalid_rows():
    sql = _load_migration().PLACE_POLYGON_PARSE_SQL
    assert "ST_GeomFromGeoJSON" in sql
    assert "ST_GeomFromEWKB" in sql
    assert "decode(t, 'hex')" in sql
    assert "EXCEPTION WHEN OTHERS" in sql
    assert "ST_GeomFromText" in sql
    # Hosted failure was hex EWKB starting with little-endian 01, not WKT.
    assert "ST_GeomFromEWKT" in sql


def test_place_geometry_migration_converts_from_geojson_column():
    sql = _load_migration().PLACE_POLYGON_PARSE_SQL
    source = _MIGRATION.read_text()
    assert "polygon_geojson" in source
    assert "_strollwise_parse_place_polygon" in sql
