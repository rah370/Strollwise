"""Indexes for hot filters and places.polygon_geometry PostGIS type.

Revision ID: 0012_db_health
Revises: 0011_password_reset_tokens
Create Date: 2026-11-16

Fixes:
- Visibility / active / created_at sequential scans on map and admin queues.
- places.polygon_geometry created as TEXT in 0005 while the ORM writes Geometry.
"""
from __future__ import annotations

from alembic import op

revision = "0012_db_health"
down_revision = "0011_password_reset_tokens"
branch_labels = None
depends_on = None


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
                USING (
                  CASE
                    WHEN polygon_geometry IS NULL
                      OR btrim(polygon_geometry) = '' THEN NULL
                    WHEN left(btrim(polygon_geometry), 2) = 'SR'
                      THEN ST_Multi(ST_SetSRID(ST_GeomFromEWKT(polygon_geometry), 4326))
                    ELSE ST_Multi(ST_SetSRID(ST_GeomFromText(polygon_geometry), 4326))
                  END
                )
            $sql$;
          END IF;
        END
        $geom$;
        """
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
