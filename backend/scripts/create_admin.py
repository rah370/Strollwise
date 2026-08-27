"""Create or promote an admin without resetting existing passwords.

Usage:
    cd backend
    ADMIN_BOOTSTRAP_EMAIL=you@example.com ADMIN_BOOTSTRAP_PASSWORD='long-password' \\
      PYTHONPATH=. python3 scripts/create_admin.py
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.utils.user_type_utils import apply_user_type_to_user


def main() -> None:
    email = (os.environ.get("ADMIN_BOOTSTRAP_EMAIL") or "").strip().lower()
    password = os.environ.get("ADMIN_BOOTSTRAP_PASSWORD") or ""
    if not email or len(password) < 12:
        print("ADMIN_BOOTSTRAP_EMAIL and a password of at least 12 characters are required.")
        sys.exit(1)

    with SessionLocal() as db:
        repo = UserRepository(db)
        existing = repo.get_by_email(email)
        if existing is not None:
            existing.is_admin = True
            existing.is_active = True
            repo.save(existing)
            db.commit()
            print(f"Promoted existing user {email} to admin (password unchanged).")
            return

        user = User(
            email=email,
            password_hash=hash_password(password),
            display_name="StrollWise Admin",
            traveler_type="local",
            user_type="local_resident",
            country_of_origin="Philippines",
            city_of_origin="Cebu City",
            is_admin=True,
            is_active=True,
            accepted_research_consent=True,
        )
        apply_user_type_to_user(user)
        repo.create(user)
        db.commit()
        print(f"Created admin {email}.")


if __name__ == "__main__":
    main()
