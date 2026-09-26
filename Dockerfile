# ============================================================
# Estágio 1 — Construir
# ============================================================

FROM python:3.12-alpine AS builder

WORKDIR /build

COPY requirements.txt .

RUN pip install \
    --no-cache-dir \
    --prefix=/install \
    -r requirements.txt


# ============================================================
# Estágio 2 — executar e copiar somente o artefato
# ============================================================

FROM python:3.12-alpine

WORKDIR /app

# Apenas as dependências prontas do estágio anterior.
COPY --from=builder /install /usr/local

# Usuário sem privilégios.
RUN addgroup -S appgroup \
    && adduser -S -G appgroup appuser

COPY . .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8000

HEALTHCHECK \
    --interval=5s \
    --timeout=3s \
    --start-period=5s \
    --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]