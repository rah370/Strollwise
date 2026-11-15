from __future__ import annotations

from collections.abc import Iterator

from sqlalchemy import MetaData, create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import settings

NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

metadata_obj = MetaData(naming_convention=NAMING_CONVENTION)


class Base(DeclarativeBase):
    """SQLAlchemy 2.x declarative base used by every ORM model."""

    metadata = metadata_obj


_connect_args: dict[str, object] = {}
_engine_kwargs: dict[str, object] = {
    "pool_pre_ping": True,
    "future": True,
}
if settings.database_url.startswith("postgresql"):
    # Keep this short: Render health checks time out around 5s.
    _connect_args["connect_timeout"] = 3
    # Recycle before Render/Supabase idle-kill (~5–10 min) so checkout
    # does not stall the whole pool. Default size 5 is enough if SSE
    # does not hold sessions for the life of the stream.
    _engine_kwargs.update(
        pool_recycle=280,
        pool_size=5,
        max_overflow=10,
        pool_timeout=10,
    )

engine = create_engine(
    settings.database_url,
    connect_args=_connect_args,
    **_engine_kwargs,
)

SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
    class_=Session,
)


def get_db() -> Iterator[Session]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
