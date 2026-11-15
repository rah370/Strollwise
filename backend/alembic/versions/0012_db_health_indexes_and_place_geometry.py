"""Indexes for hot filters and places.polygon_geometry PostGIS type.

Revision ID: 0012_db_health
Revises: 0011_password_reset_tokens
Create Date: 2026-11-16

Fixes:
- Visibility / active / created_at sequential scans on map and admin queues.
- places.polygon_geometry created as TEXT in 0005 while the ORM writes Geometry.

Hosted rows are GeoAlchemy EWKB hex (starts with ``01``), not WKT. A strict
``ST_GeomFromText`` convert aborted ``alembic upgrade head`` on Render and the
new API never bound $PORT.
"""
from __future__ import annotations

from alembic import op

revision = "0012_db_health"
down_revision = "0011_password_reset_tokens"
branch_labels = None
depends_on = None

# Keep this in the revision so tests can lock the hosted-safe convert path.
PLACE_POLYGON_PARSE_SQL = r"""
CREATE OR REPLACE FUNCTION public._strollwise_parse_place_polygon(src text, geojson jsonb)
RETURNS geometry
LANGUAGE plpgsql
AS $fn$
DECLARE
  t text;
  g geometry;
BEGIN
  IF geojson IS NOT NULL THEN
    BEGIN
      g := ST_SetSRID(ST_GeomFromGeoJSON(geojson::text), 4326);
    EXCEPTION WHEN OTHERS THEN
      g := NULL;
    END;
  END IF;

  IF g IS NULL AND src IS NOT NULL THEN
    t := btrim(src);
    IF t <> '' THEN
      BEGIN
        IF left(t, 1) = '{' THEN
          g := ST_SetSRID(ST_GeomFromGeoJSON(t), 4326);
        ELSIF upper(left(t, 5)) = 'SRID=' THEN
          g := ST_SetSRID(ST_GeomFromEWKT(t), 4326);
        ELSIF t ~ '^[0-9A-Fa-f]+$' AND (length(t) % 2) = 0 THEN
          g := ST_SetSRID(ST_GeomFromEWKB(decode(t, 'hex')), 4326);
        ELSE
          g := ST_SetSRID(ST_GeomFromText(t), 4326);
        END IF;
      EXCEPTION WHEN OTHERS THEN
        g := NULL;
      END;
    END IF;
  END IF;

  IF g IS NULL OR ST_IsEmpty(g) THEN
    RETURN NULL;
  END IF;

  BEGIN
    IF ST_SRID(g) = 0 THEN
      g := ST_SetSRID(g, 4326);
    END IF;
    g := ST_MakeValid(g);
    g := ST_CollectionExtract(g, 3);
    IF g IS NULL OR ST_IsEmpty(g) THEN
      RETURN NULL;
    END IF;
    RETURN ST_Multi(g);
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;
END;
$fn$;
"""


def upgrade() -> None:
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_reports_visibility_status
            ON public.reports (visibility_status);
        CREATE INDEX IF NOT EXISTS ix_reports_h3_visibility
            ON public.reports (h3_index, visibility_status);
        CREATE INDEX IF NOT EXISTS ix_merged_zones_is_active
            ON public.merged_zones (is_active);
        CREATE INDEX IF NOT EXISTS ix_places_is_active
            ON public.places (is_active);
        CREATE INDEX IF NOT EXISTS ix_h3_cell_aggregates_report_count
            ON public.h3_cell_aggregates (report_count);
        CREATE INDEX IF NOT EXISTS ix_audit_logs_created_at
            ON public.audit_logs (created_at DESC);
        """
    )
    op.execute(PLACE_POLYGON_PARSE_SQL)
    op.execute(
        """
        DO $geom$
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'places'
              AND column_name = 'polygon_geometry'
              AND data_type = 'text'
          ) THEN
            EXECUTE $sql$
              ALTER TABLE public.places
                ALTER COLUMN polygon_geometry TYPE geometry(MultiPolygon, 4326)
                USING public._strollwise_parse_place_polygon(
                  polygon_geometry, polygon_geojson
                )
            $sql$;
          END IF;
        END
        $geom$;
        """
    )
    op.execute(
        "DROP FUNCTION IF EXISTS public._strollwise_parse_place_polygon(text, jsonb)"
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_places_polygon_geometry
            ON public.places USING GIST (polygon_geometry)
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS public.ix_places_polygon_geometry")
    op.execute(
        """
        DO $geom$
        BEGIN
          IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'places'
              AND column_name = 'polygon_geometry'
              AND udt_name = 'geometry'
          ) THEN
            EXECUTE $sql$
              ALTER TABLE public.places
                ALTER COLUMN polygon_geometry TYPE text
                USING ST_AsText(polygon_geometry)
            $sql$;
          END IF;
        END
        $geom$;
        """
    )
    op.execute("DROP INDEX IF EXISTS public.ix_audit_logs_created_at")
    op.execute("DROP INDEX IF EXISTS public.ix_h3_cell_aggregates_report_count")
    op.execute("DROP INDEX IF EXISTS public.ix_places_is_active")
    op.execute("DROP INDEX IF EXISTS public.ix_merged_zones_is_active")
    op.execute("DROP INDEX IF EXISTS public.ix_reports_h3_visibility")
    op.execute("DROP INDEX IF EXISTS public.ix_reports_visibility_status")
