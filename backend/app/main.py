from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles

from app.activity_store import (
    create_admin_session,
    create_guest_session,
    list_activity,
    record_activity,
)
from app.bible_store import available_translations, get_passage
from app.content_store import (
    ContentNotFoundError,
    get_chapter,
    get_admin_chapters_for_course,
    get_chapters_for_course,
    get_course,
    init_db,
    load_courses,
    reseed_database,
    save_chapter,
)
from app.excel_content import WorkbookImportError, export_course_workbook, import_course_workbook


PROJECT_ROOT = Path(__file__).resolve().parents[2]
FRONTEND_DIST_DIR = PROJECT_ROOT / "frontend" / "build" / "web"
FRONTEND_INDEX = FRONTEND_DIST_DIR / "index.html"

app = FastAPI(
    title="Houvast API",
    description="Content-driven catechese backend voor Houvast.",
    version="0.1.0",
)

DEFAULT_CORS_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:5173",
    "http://127.0.0.1:5173",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
    "http://localhost:8081",
    "http://127.0.0.1:8081",
]


def cors_origins() -> list[str]:
    configured = os.getenv("CORS_ORIGINS", "")
    origins = [origin.strip() for origin in configured.split(",") if origin.strip()]
    return origins or DEFAULT_CORS_ORIGINS


app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def startup() -> None:
    init_db()


@app.get("/", response_model=None)
def root():
    if FRONTEND_INDEX.exists():
        return FileResponse(FRONTEND_INDEX)
    return {
        "name": "Houvast API",
        "status": "running",
        "docs": "/docs",
    }


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/auth/guest")
def auth_guest(payload: dict | None = None) -> dict:
    return create_guest_session((payload or {}).get("name"))


@app.post("/auth/admin")
def auth_admin(payload: dict) -> dict:
    try:
        return create_admin_session(str(payload.get("password", "")))
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc


@app.post("/activity")
def activity(payload: dict) -> dict:
    try:
        return record_activity(payload)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.get("/admin/activity")
def admin_activity(limit: int = 300) -> list[dict]:
    return list_activity(limit)


@app.get("/courses")
def courses() -> list[dict]:
    return load_courses()


@app.get("/courses/{course_id}")
def course(course_id: str) -> dict:
    try:
        return get_course(course_id)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.get("/courses/{course_id}/chapters")
def course_chapters(course_id: str) -> list[dict]:
    try:
        course_data = get_course(course_id)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    chapters = get_chapters_for_course(course_data["id"])
    return [
        {
            "id": chapter["id"],
            "slug": chapter["slug"],
            "course_id": chapter["course_id"],
            "title": chapter["title"],
            "subtitle": chapter["subtitle"],
            "description": chapter["description"],
            "xp": chapter["xp"],
            "status": chapter["status"],
            "sort_order": chapter["sort_order"],
            "block_count": chapter.get("block_count", 0),
        }
        for chapter in chapters
    ]


@app.get("/chapters/{chapter_id}")
def chapter(chapter_id: str) -> dict:
    try:
        return get_chapter(chapter_id)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.get("/admin/courses/{course_id}/chapters")
def admin_course_chapters(course_id: str) -> list[dict]:
    try:
        course_data = get_course(course_id)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return get_admin_chapters_for_course(course_data["id"])


@app.post("/admin/chapters/save")
def admin_save_chapter(chapter_data: dict) -> dict:
    try:
        return save_chapter(chapter_data)
    except KeyError as exc:
        raise HTTPException(status_code=422, detail=f"Missing field: {exc}") from exc


@app.get("/admin/courses/{course_id}/export.xlsx")
def admin_export_course(course_id: str) -> Response:
    try:
        workbook = export_course_workbook(course_id)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    filename = f"houvast-{course_id}-content.xlsx"
    return Response(
        content=workbook,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@app.post("/admin/courses/{course_id}/import.xlsx")
async def admin_import_course(course_id: str, file: UploadFile = File(...)) -> dict:
    if not file.filename.lower().endswith(".xlsx"):
        raise HTTPException(status_code=422, detail="Upload een .xlsx bestand.")

    content = await file.read()
    try:
        return import_course_workbook(course_id, content)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except WorkbookImportError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.get("/bible/translations")
def bible_translations() -> list[dict[str, str]]:
    return available_translations()


@app.get("/bible/passage")
def bible_passage(reference: str, translation: str = "HSV") -> dict:
    try:
        return get_passage(reference, translation)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/admin/reload-content")
def reload_content() -> dict[str, str]:
    reseed_database()
    return {"status": "reseeded"}


if FRONTEND_DIST_DIR.exists():
    app.mount("/", StaticFiles(directory=FRONTEND_DIST_DIR, html=True), name="frontend")
