"""Harden public tables for Supabase advisors we can actually fix.

Revision ID: 0010_supabase_advisor_hardening
Revises: 0009_lock_down_postgis_catalog
Create Date: 2026-09-02

Fixes:
- INFO 0008: explicit deny policies for ``anon`` / ``authenticated`` on every
  StrollWise table (FastAPI uses the ``postgres`` owner, which bypasses RLS).
- INFO 0001: covering indexes on unindexed foreign keys.
- Duplicate unique indexes on email/slug.

Does not attempt:
- RLS on ``spatial_ref_sys`` (owned by ``supabase_admin``).
- Moving PostGIS out of ``public`` (extension is not safely relocatable).
"""
from __future__ import annotations

from alembic import op

revision = "0010_supabase_advisor_hardening"
down_revision = "0009_lock_down_postgis_catalog"
branch_labels = None
depends_on = None

_POLICY = "strollwise_deny_data_api"

_TABLES = (
    "alembic_version",
    "audit_logs",
    "h3_cell_aggregates",
    "media",
    "merged_zones",
    "places",
    "reports",
    "saved_zones",
    "system_settings",
    "user_visit_pins",
    "users",
    "zone_catalog_entries",
    "zone_snapshots",
)


def upgrade() -> None:
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_audit_logs_actor_user_id
            ON public.audit_logs (actor_user_id);
        CREATE INDEX IF NOT EXISTS ix_user_visit_pins_report_id
            ON public.user_visit_pins (report_id);
        DROP INDEX IF EXISTS public.ix_users_email;
        DROP INDEX IF EXISTS public.ix_merged_zones_slug;
        DROP INDEX IF EXISTS public.ix_places_slug;
        """
    )

    tables_sql = ", ".join(f"'{name}'" for name in _TABLES)
    op.execute(
        f"""
        DO $harden$
        DECLARE
          tbl text;
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            RETURN;
          END IF;
          IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
            RETURN;
          END IF;

          FOREACH tbl IN ARRAY ARRAY[{tables_sql}]
          LOOP
            IF to_regclass('public.' || tbl) IS NULL THEN
              CONTINUE;
            END IF;
            BEGIN
              EXECUTE format(
                'CREATE POLICY {_POLICY}
                   ON public.%I
                   FOR ALL
                   TO anon, authenticated
                   USING (false)
                   WITH CHECK (false)',
                tbl
              );
            EXCEPTION
              WHEN duplicate_object THEN NULL;
            END;
          END LOOP;
        END
        $harden$;
        """
    )


def downgrade() -> None:
    tables_sql = ", ".join(f"'{name}'" for name in _TABLES)
    op.execute(
        f"""
        DO $undo$
        DECLARE
          tbl text;
        BEGIN
          FOREACH tbl IN ARRAY ARRAY[{tables_sql}]
          LOOP
            IF to_regclass('public.' || tbl) IS NULL THEN
              CONTINUE;
            END IF;
            EXECUTE format(
              'DROP POLICY IF EXISTS {_POLICY} ON public.%I',
              tbl
            );
          END LOOP;
        END
        $undo$;
        """
    )
    op.execute("DROP INDEX IF EXISTS public.ix_audit_logs_actor_user_id")
    op.execute("DROP INDEX IF EXISTS public.ix_user_visit_pins_report_id")
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email
            ON public.users (email);
        CREATE UNIQUE INDEX IF NOT EXISTS ix_merged_zones_slug
            ON public.merged_zones (slug);
        CREATE INDEX IF NOT EXISTS ix_places_slug
            ON public.places (slug);
        """
    )
