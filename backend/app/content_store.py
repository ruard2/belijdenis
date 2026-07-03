from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONTENT_SEEDS_DIR = PROJECT_ROOT / "content-seeds"
DATA_DIR = PROJECT_ROOT / "backend" / "data"
DB_PATH = DATA_DIR / "houvast.db"


class ContentNotFoundError(Exception):
    pass


def connect() -> sqlite3.Connection:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    return connection


def init_db() -> None:
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS courses (
                id TEXT PRIMARY KEY,
                slug TEXT NOT NULL UNIQUE,
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                image_url TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL,
                sort_order INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS chapters (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                slug TEXT NOT NULL UNIQUE,
                title TEXT NOT NULL,
                subtitle TEXT NOT NULL,
                description TEXT NOT NULL,
                xp INTEGER NOT NULL,
                status TEXT NOT NULL,
                sort_order INTEGER NOT NULL,
                FOREIGN KEY (course_id) REFERENCES courses(id)
            );

            CREATE TABLE IF NOT EXISTS blocks (
                id TEXT PRIMARY KEY,
                chapter_id TEXT NOT NULL,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                xp INTEGER NOT NULL,
                required INTEGER NOT NULL,
                sort_order INTEGER NOT NULL,
                content_json TEXT NOT NULL,
                FOREIGN KEY (chapter_id) REFERENCES chapters(id)
            );

            CREATE TABLE IF NOT EXISTS content_archives (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                course_id TEXT NOT NULL,
                archived_at TEXT NOT NULL,
                reason TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                FOREIGN KEY (course_id) REFERENCES courses(id)
            );

            CREATE TABLE IF NOT EXISTS activity_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                user_id TEXT NOT NULL,
                username TEXT NOT NULL,
                role TEXT NOT NULL,
                course_id TEXT NOT NULL DEFAULT '',
                chapter_id TEXT NOT NULL DEFAULT '',
                block_id TEXT NOT NULL DEFAULT '',
                block_type TEXT NOT NULL DEFAULT '',
                action TEXT NOT NULL,
                value_json TEXT NOT NULL,
                created_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_activity_user
            ON activity_events (user_id, created_at);

            CREATE INDEX IF NOT EXISTS idx_activity_block
            ON activity_events (block_id, action, created_at);

            CREATE TABLE IF NOT EXISTS xp_awards (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                username TEXT NOT NULL,
                role TEXT NOT NULL,
                course_id TEXT NOT NULL,
                chapter_id TEXT NOT NULL,
                block_id TEXT NOT NULL,
                block_type TEXT NOT NULL,
                xp INTEGER NOT NULL,
                reason TEXT NOT NULL,
                created_at TEXT NOT NULL,
                UNIQUE(user_id, block_id)
            );

            CREATE INDEX IF NOT EXISTS idx_xp_awards_user
            ON xp_awards (user_id, created_at);
            """
        )

        row = connection.execute("SELECT COUNT(*) AS count FROM courses").fetchone()
        if row and row["count"] == 0:
            seed_database(connection)


def reseed_database() -> None:
    with connect() as connection:
        connection.executescript(
            """
            DELETE FROM blocks;
            DELETE FROM chapters;
            DELETE FROM courses;
            """
        )
        seed_database(connection)


def seed_database(connection: sqlite3.Connection) -> None:
    for path in sorted(CONTENT_SEEDS_DIR.glob("course_*.json")):
        course = _read_json(path)
        connection.execute(
            """
            INSERT INTO courses (id, slug, title, description, image_url, status, sort_order)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                course["id"],
                course["slug"],
                course["title"],
                course["description"],
                course.get("image_url", ""),
                course["status"],
                course["sort_order"],
            ),
        )

    for path in sorted(CONTENT_SEEDS_DIR.glob("chapter_*.json")):
        chapter = _read_json(path)
        connection.execute(
            """
            INSERT INTO chapters (
                id, course_id, slug, title, subtitle, description, xp, status, sort_order
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                chapter["id"],
                chapter["course_id"],
                chapter["slug"],
                chapter["title"],
                chapter["subtitle"],
                chapter["description"],
                chapter["xp"],
                chapter["status"],
                chapter["sort_order"],
            ),
        )

        for block in chapter.get("blocks", []):
            connection.execute(
                """
                INSERT INTO blocks (
                    id, chapter_id, type, title, xp, required, sort_order, content_json
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    block["id"],
                    chapter["id"],
                    block["type"],
                    block["title"],
                    block["xp"],
                    1 if block["required"] else 0,
                    block["sort_order"],
                    json.dumps(block["content"], ensure_ascii=False),
                ),
            )


def _read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _course_from_row(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "slug": row["slug"],
        "title": row["title"],
        "description": row["description"],
        "image_url": row["image_url"],
        "status": row["status"],
        "sort_order": row["sort_order"],
    }


def _chapter_from_row(row: sqlite3.Row, blocks: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    chapter = {
        "id": row["id"],
        "course_id": row["course_id"],
        "slug": row["slug"],
        "title": row["title"],
        "subtitle": row["subtitle"],
        "description": row["description"],
        "xp": row["xp"],
        "status": row["status"],
        "sort_order": row["sort_order"],
    }
    if blocks is not None:
        chapter["blocks"] = blocks
    return chapter


def _block_from_row(row: sqlite3.Row) -> dict[str, Any]:
    return {
        "id": row["id"],
        "chapter_id": row["chapter_id"],
        "type": row["type"],
        "title": row["title"],
        "xp": row["xp"],
        "required": bool(row["required"]),
        "sort_order": row["sort_order"],
        "content": json.loads(row["content_json"]),
    }


def load_courses() -> list[dict[str, Any]]:
    with connect() as connection:
        rows = connection.execute(
            "SELECT * FROM courses WHERE status = 'published' ORDER BY sort_order"
        ).fetchall()
        return [_course_from_row(row) for row in rows]


def get_course(course_id: str) -> dict[str, Any]:
    with connect() as connection:
        row = connection.execute(
            "SELECT * FROM courses WHERE id = ? OR slug = ?",
            (course_id, course_id),
        ).fetchone()

    if row is None:
        raise ContentNotFoundError(f"Course not found: {course_id}")
    return _course_from_row(row)


def get_chapters_for_course(course_id: str) -> list[dict[str, Any]]:
    with connect() as connection:
        rows = connection.execute(
            """
            SELECT c.*,
                   (SELECT COUNT(*) FROM blocks b WHERE b.chapter_id = c.id) AS block_count
            FROM chapters c
            WHERE c.course_id = ? AND c.status = 'published'
            ORDER BY c.sort_order
            """,
            (course_id,),
        ).fetchall()

        chapters: list[dict[str, Any]] = []
        for row in rows:
            chapter = _chapter_from_row(row)
            chapter["block_count"] = row["block_count"]
            chapters.append(chapter)
        return chapters


def get_chapter(chapter_id: str) -> dict[str, Any]:
    with connect() as connection:
        chapter_row = connection.execute(
            "SELECT * FROM chapters WHERE id = ? OR slug = ?",
            (chapter_id, chapter_id),
        ).fetchone()
        if chapter_row is None:
            raise ContentNotFoundError(f"Chapter not found: {chapter_id}")

        block_rows = connection.execute(
            "SELECT * FROM blocks WHERE chapter_id = ? ORDER BY sort_order",
            (chapter_row["id"],),
        ).fetchall()

    return _chapter_from_row(chapter_row, [_block_from_row(row) for row in block_rows])


def get_admin_chapters_for_course(course_id: str) -> list[dict[str, Any]]:
    with connect() as connection:
        rows = connection.execute(
            """
            SELECT c.*,
                   (SELECT COUNT(*) FROM blocks b WHERE b.chapter_id = c.id) AS block_count
            FROM chapters c
            WHERE c.course_id = ?
            ORDER BY c.sort_order
            """,
            (course_id,),
        ).fetchall()

        chapters: list[dict[str, Any]] = []
        for row in rows:
            chapter = _chapter_from_row(row)
            chapter["block_count"] = row["block_count"]
            chapters.append(chapter)
        return chapters


def save_chapter(chapter: dict[str, Any]) -> dict[str, Any]:
    blocks = chapter.get("blocks", [])
    with connect() as connection:
        connection.execute(
            """
            INSERT INTO chapters (
                id, course_id, slug, title, subtitle, description, xp, status, sort_order
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                course_id = excluded.course_id,
                slug = excluded.slug,
                title = excluded.title,
                subtitle = excluded.subtitle,
                description = excluded.description,
                xp = excluded.xp,
                status = excluded.status,
                sort_order = excluded.sort_order
            """,
            (
                chapter["id"],
                chapter["course_id"],
                chapter["slug"],
                chapter["title"],
                chapter.get("subtitle", ""),
                chapter.get("description", ""),
                int(chapter.get("xp", 0)),
                chapter.get("status", "draft"),
                int(chapter.get("sort_order", 1)),
            ),
        )
        connection.execute("DELETE FROM blocks WHERE chapter_id = ?", (chapter["id"],))
        for index, block in enumerate(blocks, start=1):
            connection.execute(
                """
                INSERT INTO blocks (
                    id, chapter_id, type, title, xp, required, sort_order, content_json
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    block["id"],
                    chapter["id"],
                    block["type"],
                    block["title"],
                    int(block.get("xp", 0)),
                    1 if block.get("required", True) else 0,
                    int(block.get("sort_order", index)),
                    json.dumps(block.get("content", {}), ensure_ascii=False),
                ),
            )
    return get_chapter(chapter["id"])
