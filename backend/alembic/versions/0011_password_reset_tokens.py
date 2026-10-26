"""Store hashed forgot-password codes.

Revision ID: 0011_password_reset_tokens
Revises: 0010_supabase_advisor_hardening
Create Date: 2026-10-26
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0011_password_reset_tokens"
down_revision = "0010_supabase_advisor_hardening"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "password_reset_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )
    op.create_index(
        "ix_password_reset_tokens_user_id",
        "password_reset_tokens",
        ["user_id"],
    )
    op.create_index(
        "ix_password_reset_tokens_code_hash",
        "password_reset_tokens",
        ["code_hash"],
    )
    op.create_index(
        "ix_password_reset_tokens_expires_at",
        "password_reset_tokens",
        ["expires_at"],
    )
    op.execute(
        """
        DO $harden$
        BEGIN
          IF to_regclass('public.password_reset_tokens') IS NULL THEN
            RETURN;
          END IF;
          BEGIN
            EXECUTE 'ALTER TABLE public.password_reset_tokens ENABLE ROW LEVEL SECURITY';
          EXCEPTION
            WHEN others THEN NULL;
          END;
          IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
            RETURN;
          END IF;
          IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
            RETURN;
          END IF;
          BEGIN
            EXECUTE
              'CREATE POLICY strollwise_deny_data_api
                 ON public.password_reset_tokens
                 FOR ALL
                 TO anon, authenticated
                 USING (false)
                 WITH CHECK (false)';
          EXCEPTION
            WHEN duplicate_object THEN NULL;
          END;
        END
        $harden$;
        """
    )


def downgrade() -> None:
    op.execute(
        "DROP POLICY IF EXISTS strollwise_deny_data_api ON public.password_reset_tokens"
    )
    op.drop_index("ix_password_reset_tokens_expires_at", table_name="password_reset_tokens")
    op.drop_index("ix_password_reset_tokens_code_hash", table_name="password_reset_tokens")
    op.drop_index("ix_password_reset_tokens_user_id", table_name="password_reset_tokens")
    op.drop_table("password_reset_tokens")
