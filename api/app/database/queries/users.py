"""User database queries."""

import asyncpg

from app.models.user import User


async def upsert_user(conn: asyncpg.Connection, firebase_claims: dict) -> User:
    """Insert user if not exists, or update last_login. Return User."""
    row = await conn.fetchrow(
        """
        INSERT INTO users (id, email, phone, display_name, photo_url)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (id) DO UPDATE SET
            last_login_at = NOW(),
            email = COALESCE(EXCLUDED.email, users.email),
            phone = COALESCE(EXCLUDED.phone, users.phone)
        RETURNING *
        """,
        firebase_claims["user_id"],
        firebase_claims.get("email"),
        firebase_claims.get("phone_number"),
        firebase_claims.get("name"),
        firebase_claims.get("picture"),
    )
    return User(**dict(row))


async def get_user_by_id(conn: asyncpg.Connection, user_id: str) -> User | None:
    row = await conn.fetchrow("SELECT * FROM users WHERE id = $1", user_id)
    return User(**dict(row)) if row else None
