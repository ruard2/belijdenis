# Railway Deployment

## Doel

De FastAPI backend draait op Railway met PostgreSQL.

## Railway services

- Backend service
- PostgreSQL service

## Start command

```text
uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

## Healthcheck

Endpoint:

```text
GET /health
```

Response:

```json
{
  "status": "ok"
}
```

## Environment variables

```text
DATABASE_URL=
JWT_SECRET=
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
STORAGE_PROVIDER=
STORAGE_BUCKET=
STORAGE_ENDPOINT=
STORAGE_ACCESS_KEY_ID=
STORAGE_SECRET_ACCESS_KEY=
CORS_ORIGINS=
ENVIRONMENT=production
```

## Database migrations

Gebruik Alembic.

Aanbevolen:
- migrations in Git
- geen automatische destructieve migrations
- seed-script apart uitvoeren
- eerst migreren, dan deploy verifieren

## Railway checklist

- GitHub repo gekoppeld
- Railway PostgreSQL toegevoegd
- `DATABASE_URL` aanwezig
- `$PORT` gebruikt door uvicorn
- `/health` werkt
- CORS correct ingesteld
- logs controleren na deploy
- seed-data alleen gecontroleerd uitvoeren
