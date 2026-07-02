# API Contract

Basis:

```text
Base URL local: http://localhost:8000
Base URL prod: Railway app URL
Format: JSON
Auth: Bearer JWT
```

## Health

```text
GET /health
```

Response:

```json
{
  "status": "ok"
}
```

## Auth

```text
POST /auth/register
POST /auth/login
POST /auth/refresh
GET  /auth/me
POST /auth/logout
```

## Leerling content

```text
GET /courses
GET /courses/{course_id}
GET /courses/{course_id}/chapters
GET /chapters/{chapter_id}
GET /chapters/{chapter_id}/progress
POST /blocks/{block_id}/complete
POST /blocks/{block_id}/responses
```

## Admin content

```text
GET    /admin/courses
POST   /admin/courses
PATCH  /admin/courses/{course_id}
POST   /admin/courses/{course_id}/duplicate
POST   /admin/courses/{course_id}/archive

GET    /admin/courses/{course_id}/chapters
POST   /admin/chapters
PATCH  /admin/chapters/{chapter_id}
POST   /admin/chapters/{chapter_id}/duplicate
POST   /admin/chapters/{chapter_id}/publish
POST   /admin/chapters/{chapter_id}/archive

POST   /admin/blocks
PATCH  /admin/blocks/{block_id}
DELETE /admin/blocks/{block_id}
POST   /admin/chapters/{chapter_id}/reorder-blocks
```

## Groepen

```text
POST /groups
POST /groups/join
GET  /groups/{group_id}
GET  /groups/{group_id}/members
POST /groups/{group_id}/members/{user_id}/remove
```

## Ontdekkingen

```text
GET  /blocks/{block_id}/discoveries
POST /blocks/{block_id}/discoveries
POST /discoveries/{discovery_id}/comments
POST /discoveries/{discovery_id}/reactions
POST /discoveries/{discovery_id}/report
POST /admin/discoveries/{discovery_id}/hide
```

## Vragen

```text
GET  /blocks/{block_id}/questions
POST /blocks/{block_id}/questions
POST /questions/{question_id}/vote
POST /questions/{question_id}/answers
POST /admin/questions/{question_id}/pin
POST /admin/questions/{question_id}/close
POST /admin/questions/{question_id}/hide
```

## Media

```text
POST /media/upload-url
POST /media/complete
GET  /media/{media_id}
DELETE /media/{media_id}
```

## Response-regels

- 401 bij ontbrekende of ongeldige auth.
- 403 bij onvoldoende rol of groepsrechten.
- 404 als resource niet bestaat of niet zichtbaar is.
- 422 bij validatiefouten.
- 409 bij publicatieconflict of dubbele XP-toekenning.

