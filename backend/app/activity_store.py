from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

from app.database import connect


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
        awarded_xp = value.get("xp_awarded")
        if isinstance(awarded_xp, int) and awarded_xp > 0 and payload.get("block_id"):
            connection.execute(
                """
                INSERT OR IGNORE INTO xp_awards (
                    user_id, username, role, course_id, chapter_id, block_id,
                    block_type, xp, reason, created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    payload["user_id"],
                    payload["username"],
                    payload["role"],
                    payload.get("course_id", ""),
                    payload.get("chapter_id", ""),
                    payload.get("block_id", ""),
                    payload.get("block_type", ""),
                    awarded_xp,
                    payload["action"],
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


def list_xp_awards(limit: int = 1000) -> list[dict[str, Any]]:
    capped_limit = max(1, min(limit, 5000))
    with connect() as connection:
        rows = connection.execute(
            """
            SELECT *
            FROM xp_awards
            ORDER BY created_at DESC, id DESC
            LIMIT ?
            """,
            (capped_limit,),
        ).fetchall()

    return [
        {
            "id": row["id"],
            "user_id": row["user_id"],
            "username": row["username"],
            "role": row["role"],
            "course_id": row["course_id"],
            "chapter_id": row["chapter_id"],
            "block_id": row["block_id"],
            "block_type": row["block_type"],
            "xp": row["xp"],
            "reason": row["reason"],
            "created_at": row["created_at"],
        }
        for row in rows
    ]


def list_block_answers(block_id: str) -> list[dict[str, Any]]:
    """Laatste antwoord per deelnemer per vraag voor één blok (voor groepsbord)."""
    with connect() as connection:
        rows = connection.execute(
            """
            SELECT user_id, username, role, value_json, created_at
            FROM activity_events
            WHERE block_id = ? AND action = 'question_answered'
            ORDER BY created_at ASC, id ASC
            """,
            (block_id,),
        ).fetchall()

    latest: dict[tuple[str, int], dict[str, Any]] = {}
    for row in rows:
        try:
            value = json.loads(row["value_json"])
        except (TypeError, ValueError):
            continue
        index = value.get("question_index")
        answer = str(value.get("answer", "")).strip()
        if not isinstance(index, int) or not answer:
            continue
        latest[(row["user_id"], index)] = {
            "user_id": row["user_id"],
            "username": row["username"],
            "role": row["role"],
            "question_index": index,
            "answer": answer,
            "created_at": row["created_at"],
        }
    return sorted(latest.values(), key=lambda item: item["created_at"])
