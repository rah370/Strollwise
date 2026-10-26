from __future__ import annotations

from uuid import UUID

from sqlalchemy import desc, func, select
from sqlalchemy.orm import Session

from app.models.user import User


class UserRepository:
    def __init__(self, db: Session) -> None:
        self.db = db

    def get_by_id(self, user_id: UUID) -> User | None:
        return self.db.get(User, user_id)

    def get_by_email(self, email: str) -> User | None:
        stmt = select(User).where(User.email == email.lower())
        return self.db.execute(stmt).scalar_one_or_none()

    def create(self, user: User) -> User:
        self.db.add(user)
        self.db.flush()
        return user

    def save(self, user: User) -> User:
        self.db.add(user)
        self.db.flush()
        return user

    def list_paginated(
        self,
        *,
        page: int = 1,
        page_size: int = 50,
        search: str | None = None,
        user_type: str | None = None,
        is_admin: bool | None = None,
        is_active: bool | None = None,
    ) -> tuple[list[User], int]:
        stmt = select(User)
        count_stmt = select(func.count()).select_from(User)
        if search:
            pattern = f"%{search.lower()}%"
            filt = (
                User.email.ilike(pattern)
                | User.display_name.ilike(pattern)
                | User.city_of_origin.ilike(pattern)
                | User.country_of_origin.ilike(pattern)
            )
            stmt = stmt.where(filt)
            count_stmt = count_stmt.where(filt)
        if user_type:
            stmt = stmt.where(User.user_type == user_type)
            count_stmt = count_stmt.where(User.user_type == user_type)
        if is_admin is not None:
            stmt = stmt.where(User.is_admin.is_(is_admin))
            count_stmt = count_stmt.where(User.is_admin.is_(is_admin))
        if is_active is not None:
            stmt = stmt.where(User.is_active.is_(is_active))
            count_stmt = count_stmt.where(User.is_active.is_(is_active))
        total = int(self.db.scalar(count_stmt) or 0)
        offset = max(page - 1, 0) * page_size
        stmt = stmt.order_by(desc(User.created_at)).offset(offset).limit(page_size)
        return list(self.db.execute(stmt).scalars()), total

    def count_all(self) -> int:
        return int(self.db.scalar(select(func.count()).select_from(User)) or 0)

    def count_admins(self) -> int:
        stmt = select(func.count()).select_from(User).where(User.is_admin.is_(True))
        return int(self.db.scalar(stmt) or 0)

    def count_active(self) -> int:
        stmt = select(func.count()).select_from(User).where(User.is_active.is_(True))
        return int(self.db.scalar(stmt) or 0)

    def count_by_user_type(self, user_type: str) -> int:
        stmt = select(func.count()).select_from(User).where(User.user_type == user_type)
        return int(self.db.scalar(stmt) or 0)
