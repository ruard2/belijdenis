from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from scripts.migrate_sqlite_to_postgres import TABLES


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("sqlite_path", type=Path)
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, default=5432)
    args = parser.parse_args()

    os.environ["DATABASE_URL"] = (
        f"host={args.host} port={args.port} dbname={os.environ['PGDATABASE']} "
        f"user={os.environ['PGUSER']} password={os.environ['PGPASSWORD']}"
    )

    source = sqlite3.connect(f"file:{args.sqlite_path}?mode=ro", uri=True)
    source.row_factory = sqlite3.Row

    from app.database import connect

    with connect() as target:
        for table, columns in TABLES.items():
            order = "id" if "id" in columns else columns[0]
            query = f"SELECT {', '.join(columns)} FROM {table} ORDER BY {order}"
            source_rows = [tuple(row) for row in source.execute(query).fetchall()]
            target_rows = [
                tuple(row[column] for column in columns)
                for row in target.execute(query).fetchall()
            ]
            if source_rows != target_rows:
                raise SystemExit(f"mismatch={table}")
            print(f"verified_{table}={len(source_rows)}")

    source.close()
    print("verification=exact_match")


if __name__ == "__main__":
    main()
