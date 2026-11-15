"""Gedeelde borden en uploads.

Eén generieke opslag voor alles wat deelnemers met elkaar delen of
bewaren binnen een blok: reacties en emoji's op het groepsbord,
verdeelvragen, mediabord-posts, bijbel-aantekeningen en het leesrooster.

- scope: waar het item bij hoort, bijv. "block:<block_id>" of "bible:joh 1:1-18"
- kind:  soort item, bijv. "reply", "emoji", "distribution", "media", "annotation", "read"
- item_key: optioneel; met een key is er maximaal één item per gebruiker
  (upsert), zonder key wordt steeds een nieuw item toegevoegd.
"""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import Any

from app.database import connect, uses_postgres


MAX_DATA_BYTES = 20_000
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
ALLOWED_UPLOAD_PREFIXES = ("image/", "video/", "audio/")


class BoardError(Exception):
    pass


class NotAllowedError(Exception):
    pass


def init_board_db() -> None:
    schema = """
        CREATE TABLE IF NOT EXISTS board_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scope TEXT NOT NULL,
            kind TEXT NOT NULL,
            item_key TEXT NOT NULL,
            user_id TEXT NOT NULL,
            username TEXT NOT NULL,
            data_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE (scope, kind, user_id, item_key)
        );

        CREATE INDEX IF NOT EXISTS idx_board_items_scope
        ON board_items (scope, created_at);

        CREATE TABLE IF NOT EXISTS uploads (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            username TEXT NOT NULL,
            filename TEXT NOT NULL,
            content_type TEXT NOT NULL,
            size INTEGER NOT NULL,
            data BLOB NOT NULL,
            created_at TEXT NOT NULL
        );
    """
    if uses_postgres():
        schema = schema.replace(
            "id INTEGER PRIMARY KEY AUTOINCREMENT", "id BIGSERIAL PRIMARY KEY"
        ).replace("data BLOB NOT NULL", "data BYTEA NOT NULL")
    with connect() as connection:
        connection.executescript(schema)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _validate(scope: str, kind: str, data: Any) -> str:
    if not scope.strip() or len(scope) > 300:
        raise BoardError("Ongeldige scope.")
    if not kind.strip() or len(kind) > 40:
        raise BoardError("Ongeldig soort item.")
    if not isinstance(data, dict):
        raise BoardError("data moet een object zijn.")
    encoded = json.dumps(data, ensure_ascii=False)
    if len(encoded.encode("utf-8")) > MAX_DATA_BYTES:
        raise BoardError("Bericht is te lang.")
    return encoded


def _item_from_row(row) -> dict[str, Any]:
    key = row["item_key"]
    return {
        "id": int(row["id"]),
        "scope": row["scope"],
        "kind": row["kind"],
        "key": "" if key.startswith("~") else key,
        "user_id": row["user_id"],
        "username": row["username"],
        "data": json.loads(row["data_json"]),
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    }


def list_items(scope: str, visible_user_ids: set[str]) -> list[dict[str, Any]]:
    with connect() as connection:
        rows = connection.execute(
            "SELECT * FROM board_items WHERE scope = ? ORDER BY created_at ASC, id ASC",
            (scope,),
        ).fetchall()
    return [_item_from_row(row) for row in rows if row["user_id"] in visible_user_ids]


def put_item(
    scope: str, kind: str, key: str | None, data: Any, session: dict
) -> dict[str, Any]:
    encoded = _validate(scope, kind, data)
    now = _now()
    # Zonder key: altijd nieuw item (unieke interne key met ~ prefix).
    item_key = (key or "").strip()[:200] or f"~{uuid.uuid4().hex}"
    with connect() as connection:
        connection.execute(
            """
            INSERT INTO board_items (
                scope, kind, item_key, user_id, username, data_json, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (scope, kind, user_id, item_key) DO UPDATE SET
                data_json = excluded.data_json,
                username = excluded.username,
                updated_at = excluded.updated_at
            """,
            (scope, kind, item_key, session["user_id"], session["username"], encoded, now, now),
        )
        row = connection.execute(
            """
            SELECT * FROM board_items
            WHERE scope = ? AND kind = ? AND user_id = ? AND item_key = ?
            """,
            (scope, kind, session["user_id"], item_key),
        ).fetchone()
    return _item_from_row(row)


def delete_own_key(scope: str, kind: str, key: str, session: dict) -> None:
    with connect() as connection:
        connection.execute(
            """
            DELETE FROM board_items
            WHERE scope = ? AND kind = ? AND user_id = ? AND item_key = ?
            """,
            (scope, kind, session["user_id"], key),
        )


def delete_item(item_id: int, session: dict) -> None:
    with connect() as connection:
        row = connection.execute(
            "SELECT user_id FROM board_items WHERE id = ?", (item_id,)
        ).fetchone()
        if row is None:
            return
        if row["user_id"] != session["user_id"] and session["role"] != "admin":
            raise NotAllowedError("Je kunt alleen je eigen berichten verwijderen.")
        connection.execute("DELETE FROM board_items WHERE id = ?", (item_id,))


def delete_user_items(user_id: str) -> None:
    with connect() as connection:
        connection.execute("DELETE FROM board_items WHERE user_id = ?", (user_id,))
        connection.execute("DELETE FROM uploads WHERE user_id = ?", (user_id,))


# --------------------------------------------------------------------------
# Uploads
# --------------------------------------------------------------------------


def save_upload(filename: str, content_type: str, data: bytes, session: dict) -> dict[str, Any]:
    if not data:
        raise BoardError("Leeg bestand.")
    if len(data) > MAX_UPLOAD_BYTES:
        raise BoardError("Bestand is te groot (maximaal 10 MB).")
    content_type = (content_type or "").lower() or _guess_type(filename)
    if not content_type.startswith(ALLOWED_UPLOAD_PREFIXES):
        content_type = _guess_type(filename)
    if not content_type.startswith(ALLOWED_UPLOAD_PREFIXES) or "svg" in content_type:
        raise BoardError("Alleen foto's, video's en audio zijn toegestaan.")
    upload_id = uuid.uuid4().hex
    with connect() as connection:
        connection.execute(
            """
            INSERT INTO uploads (id, user_id, username, filename, content_type, size, data, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                upload_id,
                session["user_id"],
                session["username"],
                filename[:200] or "bestand",
                content_type,
                len(data),
                data,
                _now(),
            ),
        )
    return {
        "id": upload_id,
        "url": f"/uploads/{upload_id}",
        "filename": filename,
        "content_type": content_type,
        "size": len(data),
    }


def get_upload(upload_id: str) -> dict[str, Any] | None:
    with connect() as connection:
        row = connection.execute(
            "SELECT filename, content_type, data FROM uploads WHERE id = ?", (upload_id,)
        ).fetchone()
    if row is None:
        return None
    return {
        "filename": row["filename"],
        "content_type": row["content_type"],
        "data": bytes(row["data"]),
    }


def _guess_type(filename: str) -> str:
    name = (filename or "").lower()
    for ext, kind in (
        (".jpg", "image/jpeg"),
        (".jpeg", "image/jpeg"),
        (".png", "image/png"),
        (".gif", "image/gif"),
        (".webp", "image/webp"),
        (".heic", "image/heic"),
        (".mp4", "video/mp4"),
        (".mov", "video/quicktime"),
        (".webm", "video/webm"),
        (".mp3", "audio/mpeg"),
        (".m4a", "audio/mp4"),
    ):
        if name.endswith(ext):
            return kind
    return "application/octet-stream"
