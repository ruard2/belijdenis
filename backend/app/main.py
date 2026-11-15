from __future__ import annotations

import os
from pathlib import Path

from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles

from app.activity_store import (
    list_activity,
    list_block_answers,
    list_xp_awards,
    record_activity,
)
from app.auth_store import (
    AuthError,
    UserNotFoundError,
    active_user_ids,
    admin_password_is_default,
    annotate_chapters,
    create_user,
    delete_user,
    get_progress,
    get_session,
    init_auth_db,
    list_users,
    login_admin,
    login_user,
    logout,
    record_block_completion,
    reset_pin,
    set_chapter_completed,
    update_user,
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


APP_FILE = Path(__file__).resolve()


def find_project_root() -> Path:
    candidates = [
        APP_FILE.parents[2],
        APP_FILE.parents[1],
        Path.cwd(),
        Path.cwd().parent,
        Path("/app"),
    ]
    for candidate in candidates:
        if (candidate / "content-seeds").exists() or (candidate / "frontend" / "build" / "web").exists():
            return candidate
    return APP_FILE.parents[2]


PROJECT_ROOT = find_project_root()
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


@app.middleware("http")
async def prevent_stale_frontend_cache(request, call_next):
    response = await call_next(request)
    path = request.url.path
    if path == "/" or path.endswith((".html", ".js", ".json")):
        # Altijd bij de server checken (ETag -> 304), maar wel cachen:
        # scheelt ~4 MB download per app-start op telefoons.
        response.headers["Cache-Control"] = "no-cache"
    return response


@app.on_event("startup")
def startup() -> None:
    init_db()
    init_auth_db()
    if admin_password_is_default():
        print("WAARSCHUWING: ADMIN_PASSWORD is niet ingesteld; standaardwachtwoord actief.")


# ---------------------------------------------------------------------------
# Authenticatie
# ---------------------------------------------------------------------------


def _token_from_header(authorization: str | None) -> str | None:
    if authorization and authorization.lower().startswith("bearer "):
        return authorization[7:].strip() or None
    return None


def optional_session(authorization: str | None = Header(default=None)) -> dict | None:
    return get_session(_token_from_header(authorization))


def require_session(session: dict | None = Depends(optional_session)) -> dict:
    if session is None:
        raise HTTPException(status_code=401, detail="Log opnieuw in.")
    return session


def require_admin(
    authorization: str | None = Header(default=None),
    token: str | None = Query(default=None),
) -> dict:
    session = get_session(_token_from_header(authorization) or token)
    if session is None or session["role"] != "admin":
        raise HTTPException(status_code=401, detail="Alleen voor admin.")
    return session


def _published_chapters(course_id: str) -> list[dict]:
    try:
        course_data = get_course(course_id)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return get_chapters_for_course(course_data["id"])


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


@app.post("/auth/login")
def auth_login(payload: dict) -> dict:
    try:
        return login_user(str(payload.get("username", "")), str(payload.get("pin", "")))
    except AuthError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc


@app.post("/auth/admin")
def auth_admin(payload: dict) -> dict:
    try:
        return login_admin(str(payload.get("password", "")))
    except AuthError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc


@app.get("/auth/me")
def auth_me(session: dict = Depends(require_session)) -> dict:
    return session


@app.post("/auth/logout")
def auth_logout(session: dict = Depends(require_session)) -> dict:
    logout(session["token"])
    return {"status": "ok"}


@app.post("/activity")
def activity(payload: dict, session: dict = Depends(require_session)) -> dict:
    # Gebruiker komt uit de sessie, niet uit de payload.
    payload = {
        **payload,
        "session_id": session["token"][:16],
        "user_id": session["user_id"],
        "username": session["username"],
        "role": session["role"],
    }
    try:
        result = record_activity(payload)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    value = payload.get("value") or {}
    if isinstance(value, dict) and (
        value.get("block_completed") or (isinstance(value.get("xp_awarded"), int) and value["xp_awarded"] > 0)
    ):
        record_block_completion(
            session["user_id"], str(payload.get("chapter_id", "")), str(payload.get("block_id", ""))
        )
    return result


@app.get("/blocks/{block_id}/answers")
def block_answers(block_id: str, session: dict = Depends(require_session)) -> list[dict]:
    answers = list_block_answers(block_id)
    # Gedeactiveerde/verwijderde gebruikers en oude gastsessies niet tonen.
    valid = active_user_ids() | {"admin", session["user_id"]}
    return [a for a in answers if a["user_id"] in valid]


@app.get("/me/progress")
def my_progress(session: dict = Depends(require_session)) -> dict:
    return get_progress(session["user_id"])


@app.post("/me/chapters/{chapter_id}/complete")
def complete_my_chapter(chapter_id: str, session: dict = Depends(require_session)) -> dict:
    try:
        chapter_data = get_chapter(chapter_id)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    chapters = annotate_chapters(_published_chapters(chapter_data["course_id"]), session)
    current = next((c for c in chapters if c["id"] == chapter_data["id"]), None)
    if current is None or current["locked"]:
        raise HTTPException(status_code=403, detail="Dit hoofdstuk is nog niet open.")
    set_chapter_completed(session["user_id"], chapter_data["id"], chapter_data["course_id"], True)
    chapters = annotate_chapters(_published_chapters(chapter_data["course_id"]), session)
    ids = [c["id"] for c in chapters]
    index = ids.index(chapter_data["id"])
    next_chapter = chapters[index + 1] if index + 1 < len(chapters) else None
    return {
        "completed": chapter_data["id"],
        "next_chapter": None
        if next_chapter is None
        else {"id": next_chapter["id"], "title": next_chapter["title"], "sort_order": next_chapter["sort_order"]},
    }


# ---------------------------------------------------------------------------
# Gebruikersbeheer (admin)
# ---------------------------------------------------------------------------


@app.get("/admin/users")
def admin_users(_: dict = Depends(require_admin)) -> list[dict]:
    return list_users()


@app.post("/admin/users")
def admin_create_user(payload: dict, _: dict = Depends(require_admin)) -> dict:
    try:
        return create_user(str(payload.get("display_name", "")), payload.get("username"))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/admin/users/{user_id}/reset-pin")
def admin_reset_pin(user_id: str, _: dict = Depends(require_admin)) -> dict:
    try:
        return reset_pin(user_id)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.patch("/admin/users/{user_id}")
def admin_update_user(user_id: str, payload: dict, _: dict = Depends(require_admin)) -> dict:
    try:
        return update_user(user_id, payload)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.delete("/admin/users/{user_id}")
def admin_delete_user(user_id: str, _: dict = Depends(require_admin)) -> dict:
    try:
        delete_user(user_id)
    except UserNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return {"status": "deleted"}


@app.post("/admin/users/{user_id}/chapters/{chapter_id}")
def admin_set_user_chapter(
    user_id: str, chapter_id: str, payload: dict, _: dict = Depends(require_admin)
) -> dict:
    try:
        chapter_data = get_chapter(chapter_id)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    set_chapter_completed(
        user_id, chapter_data["id"], chapter_data["course_id"], bool(payload.get("completed", True))
    )
    return {"status": "ok"}


@app.get("/admin/activity")
def admin_activity(limit: int = 300, _: dict = Depends(require_admin)) -> list[dict]:
    return list_activity(limit)


@app.get("/admin/xp")
def admin_xp(limit: int = 1000, _: dict = Depends(require_admin)) -> list[dict]:
    return list_xp_awards(limit)


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
def course_chapters(course_id: str, session: dict | None = Depends(optional_session)) -> list[dict]:
    chapters = annotate_chapters(_published_chapters(course_id), session)
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
            "completed": chapter["completed"],
            "locked": chapter["locked"],
        }
        for chapter in chapters
    ]


@app.get("/chapters/{chapter_id}")
def chapter(chapter_id: str, session: dict = Depends(require_session)) -> dict:
    try:
        chapter_data = get_chapter(chapter_id)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    if session["role"] == "admin":
        return chapter_data
    chapters = annotate_chapters(_published_chapters(chapter_data["course_id"]), session)
    current = next((c for c in chapters if c["id"] == chapter_data["id"]), None)
    if current is None:
        raise HTTPException(status_code=404, detail="Hoofdstuk niet gevonden.")
    if current["locked"]:
        raise HTTPException(status_code=403, detail="Rond eerst het vorige hoofdstuk af.")
    return {**chapter_data, "completed": current["completed"]}


@app.get("/admin/courses/{course_id}/chapters")
def admin_course_chapters(course_id: str, _: dict = Depends(require_admin)) -> list[dict]:
    try:
        course_data = get_course(course_id)
    except ContentNotFoundError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return get_admin_chapters_for_course(course_data["id"])


@app.post("/admin/chapters/save")
def admin_save_chapter(chapter_data: dict, _: dict = Depends(require_admin)) -> dict:
    try:
        return save_chapter(chapter_data)
    except KeyError as exc:
        raise HTTPException(status_code=422, detail=f"Missing field: {exc}") from exc


@app.get("/admin/courses/{course_id}/export.xlsx")
def admin_export_course(course_id: str, _: dict = Depends(require_admin)) -> Response:
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
async def admin_import_course(
    course_id: str, file: UploadFile = File(...), _: dict = Depends(require_admin)
) -> dict:
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
def reload_content(_: dict = Depends(require_admin)) -> dict[str, str]:
    reseed_database()
    return {"status": "reseeded"}


if FRONTEND_DIST_DIR.exists():
    app.mount("/", StaticFiles(directory=FRONTEND_DIST_DIR, html=True), name="frontend")
