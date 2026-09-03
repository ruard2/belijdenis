from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))


TABLES: dict[str, tuple[str, ...]] = {
    "courses": (
        "id", "slug", "title", "description", "image_url", "status", "sort_order",
    ),
    "chapters": (
        "id", "course_id", "slug", "title", "subtitle", "description", "xp",
        "status", "sort_order",
    ),
    "blocks": (
        "id", "chapter_id", "type", "title", "xp", "required", "sort_order",
        "content_json",
    ),
    "content_archives": (
        "id", "course_id", "archived_at", "reason", "payload_json",
    ),
    "activity_events": (
        "id", "session_id", "user_id", "username", "role", "course_id",
        "chapter_id", "block_id", "block_type", "action", "value_json", "created_at",
    ),
    "xp_awards": (
        "id", "user_id", "username", "role", "course_id", "chapter_id", "block_id",
        "block_type", "xp", "reason", "created_at",
    ),
}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Copy all Houvast data from SQLite to PostgreSQL."
    )
    parser.add_argument("sqlite_path", type=Path)
    parser.add_argument("--host", help="Override the PostgreSQL host.")
    parser.add_argument("--port", type=int, help="Override the PostgreSQL port.")
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Replace all existing Houvast rows in the target database.",
    )
    args = parser.parse_args()

    if args.host:
        required = ("PGDATABASE", "PGUSER", "PGPASSWORD")
        missing = [name for name in required if not os.getenv(name, "").strip()]
        if missing:
            raise SystemExit(f"Missing PostgreSQL variables: {', '.join(missing)}")
        os.environ["DATABASE_URL"] = (
            f"host={args.host} port={args.port or 5432} "
            f"dbname={os.environ['PGDATABASE']} user={os.environ['PGUSER']} "
            f"password={os.environ['PGPASSWORD']}"
        )
    elif public_url := os.getenv("DATABASE_PUBLIC_URL", "").strip():
        os.environ["DATABASE_URL"] = public_url
    if not os.getenv("DATABASE_URL", "").strip():
        raise SystemExit("DATABASE_URL or DATABASE_PUBLIC_URL is required.")
    if not args.sqlite_path.is_file():
        raise SystemExit(f"SQLite backup not found: {args.sqlite_path}")

    source = sqlite3.connect(f"file:{args.sqlite_path}?mode=ro", uri=True)
    source.row_factory = sqlite3.Row
    integrity = source.execute("PRAGMA integrity_check").fetchone()[0]
    if integrity != "ok":
        raise SystemExit(f"SQLite integrity check failed: {integrity}")

    from app.content_store import init_db
    from app.database import connect

    init_db()
    with connect() as target:
        existing = target.execute("SELECT COUNT(*) AS count FROM activity_events").fetchone()
        if existing and existing["count"] and not args.replace:
            raise SystemExit(
                "Target already contains activity data; rerun with --replace only after backup."
            )

        if args.replace:
            for table in (
                "xp_awards", "activity_events", "blocks", "content_archives",
                "chapters", "courses",
            ):
                target.execute(f"DELETE FROM {table}")

        for table, columns in TABLES.items():
            rows = source.execute(f"SELECT {', '.join(columns)} FROM {table}").fetchall()
            placeholders = ", ".join("?" for _ in columns)
            sql = (
                f"INSERT INTO {table} ({', '.join(columns)}) "
                f"VALUES ({placeholders})"
            )
            for row in rows:
                target.execute(sql, tuple(row[column] for column in columns))
            print(f"{table}={len(rows)}")

        for table in ("content_archives", "activity_events", "xp_awards"):
            target.execute(
                "SELECT setval(pg_get_serial_sequence(?, 'id'), "
                f"COALESCE(MAX(id), 1), MAX(id) IS NOT NULL) FROM {table}",
                (table,),
            )

    source.close()
    print("migration=complete")


if __name__ == "__main__":
    main()
