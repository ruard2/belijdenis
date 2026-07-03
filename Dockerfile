FROM ghcr.io/cirruslabs/flutter:stable AS frontend-build

WORKDIR /app/frontend
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get
COPY frontend/ ./
RUN flutter build web --release

FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

COPY backend /app/backend
COPY bibles /app/bibles
COPY content-seeds /app/content-seeds
COPY --from=frontend-build /app/frontend/build/web /app/frontend/build/web

EXPOSE 8080

CMD ["sh", "-c", "cd /app/backend && python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
