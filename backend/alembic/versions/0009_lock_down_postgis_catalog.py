"""Lock PostGIS catalog tables away from the Supabase Data API.

Revision ID: 0009_lock_down_postgis_catalog
Revises: 0008_zone_catalog_entries
Create Date: 2026-09-02

``public.spatial_ref_sys`` is created by PostGIS (EPSG definitions, no user
data). Supabase Security Advisor flags it as ``rls_disabled_in_public`` because
it sits in the schema PostgREST exposes. StrollWise does not use PostgREST —
the FastAPI app connects as the ``postgres`` role — so the safe fix is:

1. Revoke ``anon`` / ``authenticated`` / ``PUBLIC`` access (closes the real hole).
2. Enable RLS when this role owns the table. On many Supabase projects the
   owner is ``supabase_admin`` and ``ALTER ... ENABLE ROW LEVEL SECURITY``
   fails with "must be owner"; that error is swallowed so deploys still boot.
"""
from __future__ import annotations

from alembic import op

revision = "0009_lock_down_postgis_catalog"
down_revision = "0008_zone_catalog_entries"
branch_labels = None
depends_on = None

_LOCKDOWN_SQL = r"""
DO $lockdown$
DECLARE
  obj text;
  relkind_char char;
BEGIN
  FOREACH obj IN ARRAY ARRAY[
    'spatial_ref_sys',
    'geometry_columns',
    'geography_columns',
    'raster_columns',
    'raster_overviews'
  ]
  LOOP
    SELECT c.relkind INTO relkind_char
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = obj;

    IF relkind_char IS NULL THEN
      CONTINUE;
    END IF;

    EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC', obj);

    BEGIN
      EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon', obj);
    EXCEPTION
      WHEN undefined_object THEN NULL;
    END;

    BEGIN
      EXECUTE format('REVOKE ALL ON TABLE public.%I FROM authenticated', obj);
    EXCEPTION
      WHEN undefined_object THEN NULL;
    END;

    BEGIN
      EXECUTE format('GRANT SELECT ON TABLE public.%I TO postgres', obj);
    EXCEPTION
      WHEN insufficient_privilege THEN NULL;
      WHEN undefined_object THEN NULL;
    END;

    BEGIN
      EXECUTE format('GRANT SELECT ON TABLE public.%I TO service_role', obj);
    EXCEPTION
      WHEN insufficient_privilege THEN NULL;
      WHEN undefined_object THEN NULL;
    END;

    -- RLS applies to tables and partitioned tables, not views.
    IF relkind_char IN ('r', 'p') THEN
      BEGIN
        EXECUTE format(
          'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',
          obj
        );
      EXCEPTION
        WHEN insufficient_privilege THEN
          RAISE NOTICE
            'Skipped RLS on public.%: not table owner (typical for PostGIS)',
            obj;
      END;
    END IF;
  END LOOP;
END
$lockdown$;

NOTIFY pgrst, 'reload schema';
"""


def upgrade() -> None:
    op.execute(_LOCKDOWN_SQL)


def downgrade() -> None:
    op.execute(
        """
        DO $undo$
        BEGIN
          ALTER TABLE public.spatial_ref_sys DISABLE ROW LEVEL SECURITY;
        EXCEPTION
          WHEN insufficient_privilege THEN NULL;
          WHEN undefined_table THEN NULL;
          WHEN wrong_object_type THEN NULL;
        END
        $undo$;
        """
    )
