# ── Stage 1: builder ──────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /install
COPY app/requirements.txt .
RUN pip install --prefix=/deps --no-cache-dir -r requirements.txt


# ── Stage 2: image finale ──────────────────────────────────────────
FROM python:3.12-slim

LABEL maintainer="EST Salé — Université Mohammed V"
LABEL description="Formation App — Mini-Projet DevOps"

# Utilisateur non-root (sécurité)
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

WORKDIR /app

# Copier les dépendances depuis le builder
COPY --from=builder /deps /usr/local

# Copier le code source
COPY app/ .

# Dossier data pour SQLite (volume mount point)
RUN mkdir -p /data && chown appuser:appgroup /data

USER appuser

EXPOSE 5000

ENV FLASK_ENV=production \
    DB_PATH=/data/formations.db \
    PYTHONUNBUFFERED=1

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "60", "app:app"]
