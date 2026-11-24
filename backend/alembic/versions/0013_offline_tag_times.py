"""Store when an offline tag was made and that it was uploaded later.

Revision ID: 0013_offline_tag_times
Revises: 0012_db_health
Create Date: 2026-11-24
"""
from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0013_offline_tag_times"
down_revision = "0012_db_health"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "reports",
        sa.Column("client_created_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "reports",
        sa.Column(
            "submitted_offline",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade() -> None:
    op.drop_column("reports", "submitted_offline")
    op.drop_column("reports", "client_created_at")
