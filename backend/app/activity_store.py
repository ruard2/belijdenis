from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import Any

from app.content_store import connect


ADMIN_PASSWORD = "ABCD1234"


def create_guest_session(name: str | None = None) -> dict[str, str]:
    session_id = uuid.uuid4().hex
    suffix = session_id[:4].upper()
    username = (name or "").strip() or f"Gast {suffix}"
    return {
        "session_id": session_id,
        "user_id": f"guest-{suffix.lower()}",
        "username": username,
        "role": "guest",
    }


def create_admin_session(password: str) -> dict[str, str]:
    if password != ADMIN_PASSWORD:
        raise ValueError("Onjuist admin-wachtwoord.")
    return {
        "session_id": uuid.uuid4().hex,
        "user_id": "admin",
        "username": "Admin",
        "role": "admin",
    }


def record_activity(payload: dict[str, Any]) -> dict[str, Any]:
    required = ["session_id", "user_id", "username", "role", "action"]
    for field in required:
        if not str(payload.get(field, "")).strip():
            raise ValueError(f"Ontbrekend activity-veld: {field}")

    value = payload.get("value", {})
    created_at = datetime.now(timezone.utc).isoformat()
    with connect() as connection:
        cursor = connection.execute(
            """
            INSERT INTO activity_events (
                session_id, user_id, username, role, course_id, chapter_id,
                block_id, block_type, action, value_json, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                payload["session_id"],
                payload["user_id"],
                payload["username"],
                payload["role"],
                payload.get("course_id", ""),
                payload.get("chapter_id", ""),
                payload.get("block_id", ""),
                payload.get("block_type", ""),
                payload["action"],
                json.dumps(value, ensure_ascii=False),
                created_at,
            ),
        )

    return {"id": cursor.lastrowid, "created_at": created_at}


def list_activity(limit: int = 300) -> list[dict[str, Any]]:
    capped_limit = max(1, min(limit, 1000))
    with connect() as connection:
        rows = connection.execute(
            """
            SELECT *
            FROM activity_events
            ORDER BY created_at DESC, id DESC
            LIMIT ?
            """,
            (capped_limit,),
        ).fetchall()

    events: list[dict[str, Any]] = []
    for row in rows:
        events.append(
            {
                "id": row["id"],
                "session_id": row["session_id"],
                "user_id": row["user_id"],
                "username": row["username"],
                "role": row["role"],
                "course_id": row["course_id"],
                "chapter_id": row["chapter_id"],
                "block_id": row["block_id"],
                "block_type": row["block_type"],
                "action": row["action"],
                "value": json.loads(row["value_json"]),
                "created_at": row["created_at"],
            }
        )
    return events
