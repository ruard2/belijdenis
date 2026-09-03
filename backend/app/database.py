from __future__ import annotations

import os
import sqlite3
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = PROJECT_ROOT / "backend" / "data"
DB_PATH = DATA_DIR / "houvast.db"


def uses_postgres() -> bool:
    return bool(os.getenv("DATABASE_URL", "").strip())


class Cursor:
    def __init__(self, cursor: Any, lastrowid: int | None = None):
        self._cursor = cursor
        self.lastrowid = lastrowid

    def fetchone(self):
        return self._cursor.fetchone()

    def fetchall(self):
        return self._cursor.fetchall()


class Connection:
    def __init__(self, connection: Any, postgres: bool):
        self._connection = connection
        self.postgres = postgres

    def __enter__(self):
        self._connection.__enter__()
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return self._connection.__exit__(exc_type, exc_value, traceback)

    def execute(self, sql: str, params: tuple[Any, ...] = ()) -> Cursor:
        if not self.postgres:
            cursor = self._connection.execute(sql, params)
            return Cursor(cursor, cursor.lastrowid)

        statement = sql.replace("?", "%s")
        if "INSERT OR IGNORE INTO xp_awards" in statement:
            statement = statement.replace(
                "INSERT OR IGNORE INTO xp_awards", "INSERT INTO xp_awards"
            ).rstrip()
            statement += " ON CONFLICT (user_id, block_id) DO NOTHING"

        needs_id = any(
            marker in statement
            for marker in (
                "INSERT INTO activity_events",
                "INSERT INTO content_archives",
            )
        )
        if needs_id and "RETURNING id" not in statement:
            statement = statement.rstrip() + " RETURNING id"

        cursor = self._connection.execute(statement, params)
        lastrowid = None
        if needs_id:
            row = cursor.fetchone()
            if row is not None:
                lastrowid = int(row["id"])
        return Cursor(cursor, lastrowid)

    def executescript(self, sql: str) -> None:
        if not self.postgres:
            self._connection.executescript(sql)
            return
        for statement in sql.split(";"):
            if statement.strip():
                self._connection.execute(statement)


def connect() -> Connection:
    database_url = os.getenv("DATABASE_URL", "").strip()
    if database_url:
        import psycopg
        from psycopg.rows import dict_row

        return Connection(
            psycopg.connect(database_url, row_factory=dict_row), postgres=True
        )

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    return Connection(connection, postgres=False)
