# Railway Deployment

## Doel

De FastAPI backend draait op Railway met PostgreSQL.

## Railway services

- Backend service
- PostgreSQL service, later voor echte pilot

De repo bevat nu een `railway.json` voor de backend. Railway kan vanaf de
GitHub repo deployen zonder handmatige start command.

## Start command

```text
uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

In `railway.json` staat dit als:

```text
cd backend && python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT
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
CORS_ORIGINS=https://jouw-frontend-domein.nl
ENVIRONMENT=production
```

Meerdere CORS origins kunnen komma-gescheiden:

```text
CORS_ORIGINS=https://frontend-1.nl,https://frontend-2.nl
```

## Huidige database-status

De app gebruikt nu nog SQLite (`backend/data/houvast.db`). Dat is prima voor
een technische Railway-test, maar admin-wijzigingen zijn dan niet duurzaam over
redeploys heen. Voor een echte pilot is de volgende stap:

- PostgreSQL-service toevoegen op Railway
- `DATABASE_URL` gebruiken in de backend
- migratie/seed-script toevoegen

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
- na deploy `/health` en `/docs` openen
