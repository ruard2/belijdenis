from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, default=5432)
    args = parser.parse_args()
    os.environ["DATABASE_URL"] = (
        f"host={args.host} port={args.port} dbname={os.environ['PGDATABASE']} "
        f"user={os.environ['PGUSER']} password={os.environ['PGPASSWORD']}"
    )

    from app.activity_store import list_activity, list_xp_awards
    from app.content_store import (
        get_admin_chapters_for_course,
        get_chapter,
        get_course,
        init_db,
        load_courses,
    )
    from app.excel_content import export_course_workbook

    init_db()
    courses = load_courses()
    course = get_course("belijdenis")
    chapters = get_admin_chapters_for_course(course["id"])
    detailed = [get_chapter(chapter["id"]) for chapter in chapters]
    workbook = export_course_workbook(course["id"])
    print(f"courses={len(courses)}")
    print(f"chapters={len(detailed)}")
    print(f"blocks={sum(len(chapter['blocks']) for chapter in detailed)}")
    print(f"activities={len(list_activity(1000))}")
    print(f"xp_awards={len(list_xp_awards(5000))}")
    print(f"excel_bytes={len(workbook)}")
    print("smoke_test=ok")


if __name__ == "__main__":
    main()
