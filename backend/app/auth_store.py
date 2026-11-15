"""Gebruikers, inlogsessies en hoofdstuk-voortgang.

- Admin logt in met ADMIN_PASSWORD (omgevingsvariabele).
- Deelnemers worden door de admin aangemaakt en loggen in met
  gebruikersnaam + automatisch gegenereerde pincode (6 cijfers).
- Pincodes worden alleen gehasht opgeslagen; de admin ziet de code
  één keer (bij aanmaken of resetten).
- Hoofdstukken gaan één voor één open: het volgende hoofdstuk wordt
  zichtbaar zodra de deelnemer het vorige heeft afgerond.
"""

from __future__ import annotations

import hashlib
import hmac
import os
import re
import secrets
import time
import unicodedata
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from app.database import connect, uses_postgres


SESSION_DAYS = 180
PIN_LENGTH = 6
PBKDF2_ITERATIONS = 120_000
DEFAULT_ADMIN_PASSWORD = "ABCD1234"

MAX_FAILED_ATTEMPTS = 8
LOCKOUT_SECONDS = 15 * 60
_failed_logins: dict[str, list[float]] = {}


class AuthError(Exception):
    """Inloggen mislukt of sessie ongeldig."""


class LockedError(Exception):
    """Hoofdstuk is nog niet vrijgegeven voor deze gebruiker."""


class UserNotFoundError(Exception):
    pass


def admin_password() -> str:
    return os.getenv("ADMIN_PASSWORD", "").strip() or DEFAULT_ADMIN_PASSWORD


def admin_password_is_default() -> bool:
    return not os.getenv("ADMIN_PASSWORD", "").strip()


# --------------------------------------------------------------------------
# Schema
# --------------------------------------------------------------------------


def init_auth_db() -> None:
    schema = """
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            username TEXT NOT NULL UNIQUE,
            pin_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'student',
            active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            last_login_at TEXT NOT NULL DEFAULT ''
        );

        CREATE TABLE IF NOT EXISTS auth_sessions (
            token TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            display_name TEXT NOT NULL,
            role TEXT NOT NULL,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_auth_sessions_user
        ON auth_sessions (user_id);

        CREATE TABLE IF NOT EXISTS chapter_completions (
            user_id TEXT NOT NULL,
            course_id TEXT NOT NULL DEFAULT '',
            chapter_id TEXT NOT NULL,
            completed_at TEXT NOT NULL,
            PRIMARY KEY (user_id, chapter_id)
        );

        CREATE TABLE IF NOT EXISTS block_completions (
            user_id TEXT NOT NULL,
            chapter_id TEXT NOT NULL,
            block_id TEXT NOT NULL,
            completed_at TEXT NOT NULL,
            PRIMARY KEY (user_id, block_id)
        );
    """
    with connect() as connection:
        connection.executescript(schema)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: datetime) -> str:
    return value.isoformat()


def _hash_pin(pin: str, salt: str | None = None) -> str:
    salt = salt or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", pin.encode("utf-8"), salt.encode("utf-8"), PBKDF2_ITERATIONS
    ).hex()
    return f"pbkdf2_sha256${PBKDF2_ITERATIONS}${salt}${digest}"


def _verify_pin(pin: str, stored: str) -> bool:
    try:
        _, iterations, salt, digest = stored.split("$", 3)
        candidate = hashlib.pbkdf2_hmac(
            "sha256", pin.encode("utf-8"), salt.encode("utf-8"), int(iterations)
        ).hex()
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(candidate, digest)


def generate_pin() -> str:
    while True:
        pin = "".join(secrets.choice("0123456789") for _ in range(PIN_LENGTH))
        # Geen al te makkelijke codes (111111, 123456, ...)
        if len(set(pin)) >= 3 and pin not in "01234567890" and pin not in "98765432109":
            return pin


def _slugify_username(name: str) -> str:
    normalized = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    parts = re.findall(r"[a-z0-9]+", normalized.lower())
    if not parts:
        return "deelnemer"
    base = parts[0] if len(parts) == 1 else parts[0] + parts[-1][:1]
    return base[:20]


def _unique_username(connection, wanted: str) -> str:
    base = _slugify_username(wanted)
    candidate = base
    counter = 2
    while connection.execute(
        "SELECT 1 FROM users WHERE username = ?", (candidate,)
    ).fetchone():
        candidate = f"{base}{counter}"
        counter += 1
    return candidate


def _check_rate_limit(key: str) -> None:
    now = time.time()
    attempts = [t for t in _failed_logins.get(key, []) if now - t < LOCKOUT_SECONDS]
    _failed_logins[key] = attempts
    if len(attempts) >= MAX_FAILED_ATTEMPTS:
        minutes = int((LOCKOUT_SECONDS - (now - attempts[0])) // 60) + 1
        raise AuthError(
            f"Te veel mislukte pogingen. Probeer het over {minutes} minuten opnieuw."
        )


def _register_failure(key: str) -> None:
    _failed_logins.setdefault(key, []).append(time.time())


def _create_session(connection, user_id: str, display_name: str, role: str) -> dict:
    token = secrets.token_urlsafe(32)
    now = _now()
    connection.execute(
        """
        INSERT INTO auth_sessions (token, user_id, display_name, role, created_at, expires_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (token, user_id, display_name, role, _iso(now), _iso(now + timedelta(days=SESSION_DAYS))),
    )
    return {
        "session_id": token,
        "token": token,
        "user_id": user_id,
        "username": display_name,
        "role": role,
    }


# --------------------------------------------------------------------------
# Inloggen / sessies
# --------------------------------------------------------------------------


def login_admin(password: str) -> dict:
    _check_rate_limit("__admin__")
    if not hmac.compare_digest(password.encode("utf-8"), admin_password().encode("utf-8")):
        _register_failure("__admin__")
        raise AuthError("Onjuist admin-wachtwoord.")
    _failed_logins.pop("__admin__", None)
    with connect() as connection:
        return _create_session(connection, "admin", "Admin", "admin")


def login_user(username: str, pin: str) -> dict:
    key = username.strip().lower()
    if not key or not pin.strip():
        raise AuthError("Vul je gebruikersnaam en pincode in.")
    _check_rate_limit(key)
    with connect() as connection:
        row = connection.execute(
            "SELECT * FROM users WHERE username = ?", (key,)
        ).fetchone()
        if row is None or not _verify_pin(pin.strip(), row["pin_hash"]):
            _register_failure(key)
            raise AuthError("Gebruikersnaam of pincode klopt niet.")
        if not row["active"]:
            raise AuthError("Dit account is gedeactiveerd. Neem contact op met de catecheet.")
        _failed_logins.pop(key, None)
        connection.execute(
            "UPDATE users SET last_login_at = ? WHERE id = ?", (_iso(_now()), row["id"])
        )
        session = _create_session(connection, row["id"], row["display_name"], row["role"])
        session["login_name"] = row["username"]
        return session


def get_session(token: str | None) -> dict | None:
    if not token:
        return None
    with connect() as connection:
        row = connection.execute(
            "SELECT * FROM auth_sessions WHERE token = ?", (token,)
        ).fetchone()
        if row is None:
            return None
        if row["expires_at"] < _iso(_now()):
            connection.execute("DELETE FROM auth_sessions WHERE token = ?", (token,))
            return None
        login_name = ""
        if row["role"] != "admin":
            user = connection.execute(
                "SELECT username, display_name, active FROM users WHERE id = ?",
                (row["user_id"],),
            ).fetchone()
            if user is None or not user["active"]:
                connection.execute("DELETE FROM auth_sessions WHERE token = ?", (token,))
                return None
            login_name = user["username"]
            display_name = user["display_name"]
        else:
            display_name = row["display_name"]
    return {
        "session_id": token,
        "token": token,
        "user_id": row["user_id"],
        "username": display_name,
        "login_name": login_name,
        "role": row["role"],
    }


def logout(token: str) -> None:
    with connect() as connection:
        connection.execute("DELETE FROM auth_sessions WHERE token = ?", (token,))


# --------------------------------------------------------------------------
# Gebruikersbeheer (admin)
# --------------------------------------------------------------------------


def _user_from_row(row) -> dict:
    return {
        "id": row["id"],
        "display_name": row["display_name"],
        "username": row["username"],
        "role": row["role"],
        "active": bool(row["active"]),
        "created_at": row["created_at"],
        "last_login_at": row["last_login_at"] or None,
    }


def list_users() -> list[dict]:
    with connect() as connection:
        rows = connection.execute(
            "SELECT * FROM users ORDER BY LOWER(display_name)"
        ).fetchall()
        completions = connection.execute(
            "SELECT user_id, chapter_id, completed_at FROM chapter_completions"
        ).fetchall()
        xp_rows = connection.execute(
            "SELECT user_id, SUM(xp) AS xp FROM xp_awards GROUP BY user_id"
        ).fetchall()

    by_user: dict[str, list[dict]] = {}
    for item in completions:
        by_user.setdefault(item["user_id"], []).append(
            {"chapter_id": item["chapter_id"], "completed_at": item["completed_at"]}
        )
    xp_by_user = {item["user_id"]: int(item["xp"] or 0) for item in xp_rows}

    users = []
    for row in rows:
        user = _user_from_row(row)
        user["completed_chapters"] = sorted(
            by_user.get(row["id"], []), key=lambda c: c["completed_at"]
        )
        user["xp"] = xp_by_user.get(row["id"], 0)
        users.append(user)
    return users


def create_user(display_name: str, username: str | None = None) -> dict:
    display_name = display_name.strip()
    if not display_name:
        raise ValueError("Vul een naam in.")
    pin = generate_pin()
    with connect() as connection:
        if username and username.strip():
            wanted = _slugify_username(username)
            if connection.execute(
                "SELECT 1 FROM users WHERE username = ?", (wanted,)
            ).fetchone():
                raise ValueError(f"Gebruikersnaam '{wanted}' bestaat al.")
            login_name = wanted
        else:
            login_name = _unique_username(connection, display_name)
        user_id = f"u_{uuid.uuid4().hex[:12]}"
        connection.execute(
            """
            INSERT INTO users (id, display_name, username, pin_hash, role, active, created_at, last_login_at)
            VALUES (?, ?, ?, ?, 'student', 1, ?, '')
            """,
            (user_id, display_name, login_name, _hash_pin(pin), _iso(_now())),
        )
        row = connection.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    user = _user_from_row(row)
    user["pin"] = pin
    return user


def _require_user(connection, user_id: str):
    row = connection.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    if row is None:
        raise UserNotFoundError(f"Gebruiker niet gevonden: {user_id}")
    return row


def reset_pin(user_id: str) -> dict:
    pin = generate_pin()
    with connect() as connection:
        _require_user(connection, user_id)
        connection.execute(
            "UPDATE users SET pin_hash = ? WHERE id = ?", (_hash_pin(pin), user_id)
        )
        connection.execute("DELETE FROM auth_sessions WHERE user_id = ?", (user_id,))
        row = _require_user(connection, user_id)
    user = _user_from_row(row)
    user["pin"] = pin
    return user


def update_user(user_id: str, changes: dict[str, Any]) -> dict:
    with connect() as connection:
        _require_user(connection, user_id)
        if "display_name" in changes:
            name = str(changes["display_name"]).strip()
            if not name:
                raise ValueError("Naam mag niet leeg zijn.")
            connection.execute(
                "UPDATE users SET display_name = ? WHERE id = ?", (name, user_id)
            )
        if "active" in changes:
            active = 1 if changes["active"] else 0
            connection.execute(
                "UPDATE users SET active = ? WHERE id = ?", (active, user_id)
            )
            if not active:
                connection.execute(
                    "DELETE FROM auth_sessions WHERE user_id = ?", (user_id,)
                )
        row = _require_user(connection, user_id)
    return _user_from_row(row)


# Tabellen met per-gebruiker data die bij verwijderen volledig weg moeten.
USER_TABLES = (
    "auth_sessions",
    "chapter_completions",
    "block_completions",
    "activity_events",
    "xp_awards",
    "board_items",
    "uploads",
)


def _reaction_patterns(user_id: str) -> list[str]:
    """Reacties/emoji's van anderen die naar berichten van deze gebruiker wijzen."""
    return [
        f'%"target": "{user_id}:%',
        f'%"target": "dist:{user_id}"%',
    ]


def user_content_summary(user_id: str) -> dict[str, int]:
    with connect() as connection:
        _require_user(connection, user_id)

        def count(sql: str, params: tuple) -> int:
            row = connection.execute(sql, params).fetchone()
            return int(row["n"] or 0) if row else 0

        answers = count(
            "SELECT COUNT(*) AS n FROM activity_events WHERE user_id = ? AND action = 'question_answered'",
            (user_id,),
        )
        posts = count(
            "SELECT COUNT(*) AS n FROM board_items WHERE user_id = ? AND kind IN ('reply', 'media', 'distribution', 'annotation', 'read')",
            (user_id,),
        )
        uploads = count("SELECT COUNT(*) AS n FROM uploads WHERE user_id = ?", (user_id,))
        activity = count("SELECT COUNT(*) AS n FROM activity_events WHERE user_id = ?", (user_id,))
        reactions_on = sum(
            count("SELECT COUNT(*) AS n FROM board_items WHERE data_json LIKE ?", (pattern,))
            for pattern in _reaction_patterns(user_id)
        )
    return {
        "answers": answers,
        "posts": posts,
        "uploads": uploads,
        "activity": activity,
        "reactions_from_others": reactions_on,
    }


def delete_user(user_id: str) -> None:
    """Verwijdert de gebruiker en alles wat hij/zij geplaatst of opgebouwd heeft."""
    with connect() as connection:
        _require_user(connection, user_id)
        for table in USER_TABLES:
            connection.execute(f"DELETE FROM {table} WHERE user_id = ?", (user_id,))
        for pattern in _reaction_patterns(user_id):
            connection.execute("DELETE FROM board_items WHERE data_json LIKE ?", (pattern,))
        connection.execute("DELETE FROM users WHERE id = ?", (user_id,))


# --------------------------------------------------------------------------
# Voortgang
# --------------------------------------------------------------------------


def record_block_completion(user_id: str, chapter_id: str, block_id: str) -> None:
    if not (user_id and chapter_id and block_id):
        return
    with connect() as connection:
        connection.execute(
            """
            INSERT INTO block_completions (user_id, chapter_id, block_id, completed_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT (user_id, block_id) DO NOTHING
            """,
            (user_id, chapter_id, block_id, _iso(_now())),
        )


def completed_chapter_ids(user_id: str) -> set[str]:
    with connect() as connection:
        rows = connection.execute(
            "SELECT chapter_id FROM chapter_completions WHERE user_id = ?", (user_id,)
        ).fetchall()
    return {row["chapter_id"] for row in rows}


def get_progress(user_id: str) -> dict:
    with connect() as connection:
        chapters = connection.execute(
            "SELECT chapter_id, completed_at FROM chapter_completions WHERE user_id = ?",
            (user_id,),
        ).fetchall()
        blocks = connection.execute(
            "SELECT chapter_id, block_id FROM block_completions WHERE user_id = ?",
            (user_id,),
        ).fetchall()
        xp_rows = connection.execute(
            "SELECT chapter_id, block_id, xp FROM xp_awards WHERE user_id = ?",
            (user_id,),
        ).fetchall()

    block_set = {(row["chapter_id"], row["block_id"]) for row in blocks}
    block_set.update((row["chapter_id"], row["block_id"]) for row in xp_rows)
    return {
        "completed_chapters": [
            {"chapter_id": row["chapter_id"], "completed_at": row["completed_at"]}
            for row in chapters
        ],
        "completed_blocks": [
            {"chapter_id": chapter_id, "block_id": block_id}
            for chapter_id, block_id in sorted(block_set)
        ],
        "xp": [
            {"chapter_id": row["chapter_id"], "block_id": row["block_id"], "xp": row["xp"]}
            for row in xp_rows
        ],
    }


def annotate_chapters(chapters: list[dict], session: dict | None) -> list[dict]:
    """Voegt per hoofdstuk `completed` en `locked` toe voor de ingelogde gebruiker."""
    if session is None:
        return [{**chapter, "completed": False, "locked": index > 0} for index, chapter in enumerate(chapters)]
    is_admin = session["role"] == "admin"
    done = completed_chapter_ids(session["user_id"])
    result = []
    previous_done = True
    for chapter in chapters:
        completed = chapter["id"] in done
        locked = not is_admin and not previous_done
        result.append({**chapter, "completed": completed, "locked": locked})
        # Een afgerond hoofdstuk opent altijd het volgende.
        previous_done = completed
    return result


def set_chapter_completed(user_id: str, chapter_id: str, course_id: str, completed: bool) -> None:
    with connect() as connection:
        if completed:
            connection.execute(
                """
                INSERT INTO chapter_completions (user_id, course_id, chapter_id, completed_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT (user_id, chapter_id) DO NOTHING
                """,
                (user_id, course_id, chapter_id, _iso(_now())),
            )
        else:
            connection.execute(
                "DELETE FROM chapter_completions WHERE user_id = ? AND chapter_id = ?",
                (user_id, chapter_id),
            )


__all__ = [
    "AuthError",
    "LockedError",
    "UserNotFoundError",
    "admin_password_is_default",
    "annotate_chapters",
    "create_user",
    "delete_user",
    "get_progress",
    "get_session",
    "init_auth_db",
    "list_users",
    "login_admin",
    "login_user",
    "logout",
    "record_block_completion",
    "reset_pin",
    "set_chapter_completed",
    "update_user",
    "uses_postgres",
]


def active_user_ids() -> set[str]:
    with connect() as connection:
        rows = connection.execute("SELECT id FROM users WHERE active = 1").fetchall()
    return {row["id"] for row in rows}
