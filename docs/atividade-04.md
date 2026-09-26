# Atividade 04 — Containerizar a aplicação

## 1. Objetivo

O objetivo desta atividade foi containerizar a aplicação `ufla-devops-shop`, substituindo a execução direta no sistema operacional por uma imagem Docker reproduzível.

A imagem final deveria:

- utilizar build multi-stage;
- ter menos de 150 MB;
- executar com usuário não-root;
- declarar `HEALTHCHECK`;
- utilizar `CMD` em forma exec;
- responder corretamente em `/health`;
- disponibilizar os 12 produtos em `/api/produtos`;
- encerrar rapidamente ao receber `docker stop`.

## 2. Primeira versão funcional

A primeira versão utilizava `python:3.12-slim` e fazia a instalação das dependências diretamente na mesma imagem usada para executar a aplicação.

### Dockerfile inicial

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd --create-home appuser \
    && chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
```

### Build e tamanho da primeira versão

```bash
docker build -t ufla-shop:antes .
docker images ufla-shop
docker image inspect --format '{{.Size}}' ufla-shop:antes | numfmt --to=si
```

Resultados:

```text
IMAGE             ID             DISK USAGE   CONTENT SIZE
ufla-shop:antes   8c039e690e37        249MB         59.3MB
```

```text
250M
```

Portanto, a primeira versão era funcional, porém ultrapassava o limite de 150 MB.

### Teste da primeira versão

```bash
docker run -d   --name loja-antes   -p 8000:8000   ufla-shop:antes
```

O container iniciou em estado saudável:

```text
0c3be4bf3a51   ufla-shop:antes   Up 6 seconds (healthy)
```

Os logs confirmaram a inicialização com SQLite, cache em memória e carga inicial de 12 produtos:

```text
INFO:     Started server process [1]
2026-09-26 14:28:16,285 INFO loja: ufla-devops-shop 1.0.0 subindo (banco=sqlite, cache=memoria, instancia=0c3be4bf3a51)
2026-09-26 14:28:16,292 INFO loja.banco: carga inicial: 12 produtos
2026-09-26 14:28:16,295 INFO loja.banco: banco pronto (modo sqlite)
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

O endpoint de saúde respondeu:

```bash
curl -s localhost:8000/health
```

```json
{"status":"ok","versao":"1.0.0"}
```

O endpoint `/api/produtos` também retornou os 12 produtos esperados.

## 3. Otimização da imagem

A versão final passou a utilizar `python:3.12-alpine` e build multi-stage.

No primeiro estágio, as dependências são instaladas em `/install`. No segundo estágio, apenas essas dependências são copiadas para a imagem de runtime.



## 4. Dockerfile final

```dockerfile
# ============================================================
# Estágio 1 — Construir
# ============================================================

FROM python:3.12-alpine AS builder

WORKDIR /build

COPY requirements.txt .

RUN pip install     --no-cache-dir     --prefix=/install     -r requirements.txt

# ============================================================
# Estágio 2 — executar e copiar somente o artefato
# ============================================================

FROM python:3.12-alpine

WORKDIR /app

COPY --from=builder /install /usr/local

RUN addgroup -S appgroup     && adduser -S -G appgroup appuser

COPY . .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8000

HEALTHCHECK     --interval=5s     --timeout=3s     --start-period=5s     --retries=3     CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
```

## 5. Comparação de tamanho

Após a otimização:

```text
IMAGE             ID             DISK USAGE   CONTENT SIZE
ufla-shop:1.0     2af71b5d879d        130MB         30.1MB
ufla-shop:antes   8c039e690e37        249MB         59.3MB
```

Pela medição solicitada:

```text
Antes: 250 MB
Depois: 131 MB
```

A redução total foi:

```text
250 MB - 131 MB = 119 MB
```

Isso representa aproximadamente **47,6% de redução**.

Principais mudanças:

| Mudança | Antes | Depois | Efeito |
|---|---|---|---|
| Imagem base | `python:3.12-slim` | `python:3.12-alpine` | runtime menor |
| Estratégia de build | estágio único | multi-stage | só dependências prontas vão para o runtime |
| Cache do pip | `--no-cache-dir` | `--no-cache-dir` | sem cache desnecessário |
| Contexto | `.dockerignore` | `.dockerignore` ajustado | evita arquivos locais desnecessários |
| Tamanho final | 250 MB | 131 MB | economia de 119 MB |

As mudanças de Alpine e multi-stage foram aplicadas em conjunto, portanto a economia individual de cada uma não foi medida isoladamente; a redução observada entre a primeira imagem funcional e a imagem final foi de **119 MB**.

### 5.1 Análise das camadas com `docker history`

Para analisar onde ocorreu a redução de tamanho entre a primeira versão e a versão final, foram comparadas as camadas das duas imagens com:

```bash
docker history ufla-shop:antes
docker history ufla-shop:1.0
```

Na imagem inicial, baseada em `python:3.12-slim`, as principais camadas observadas foram:

```text
SIZE      CREATED BY
55.4MB    RUN pip install --no-cache-dir -r requirements.txt
270kB     RUN useradd --create-home appuser && chown -R appuser:appuser /app
201kB     COPY . .
41.4MB    camada da imagem base Python/Debian
87.6MB    camada base Debian
```

Na imagem final, baseada em `python:3.12-alpine` e construída com multi-stage, destacaram-se:

```text
SIZE      CREATED BY
43.9MB    COPY /install /usr/local
205kB     COPY . .
205kB     RUN chown -R appuser:appgroup /app
41kB      RUN addgroup -S appgroup && adduser -S -G appgroup appuser
44.1MB    camada da imagem base Python/Alpine
9.08MB    Alpine minirootfs
```

A comparação mostra que a imagem final utiliza uma base menor e copia para o estágio de execução apenas as dependências preparadas no estágio `builder`. Na versão inicial, a instalação das dependências gerava uma camada de **55,4 MB**, enquanto na versão final a cópia das dependências para o runtime ocupa **43,9 MB**.

As camadas de `COPY . .` e `chown` também ficaram pequenas, com aproximadamente **200 kB**, indicando que o `.dockerignore` está evitando que arquivos locais desnecessários sejam incluídos na imagem.

Como as otimizações foram aplicadas em conjunto, não é possível atribuir toda a redução a uma única alteração. O resultado medido foi a redução da imagem de **250 MB para 131 MB**, uma economia total de **119 MB**.

## 6. Verificações da imagem final

### Tamanho

```bash
docker image inspect --format '{{.Size}}' ufla-shop:1.0 | numfmt --to=si
```

```text
131M
```

### Usuário não-root

```bash
docker run --rm ufla-shop:1.0 id -u
```

```text
100
```

Como o UID é diferente de `0`, a aplicação não executa como root.

### HEALTHCHECK

```bash
docker inspect --format '{{.State.Health.Status}}' loja
```

```text
healthy
```

### Endpoint `/health`

```bash
curl -i localhost:8000/health
```

```text
HTTP/1.1 200 OK
server: uvicorn
content-type: application/json

{"status":"ok","versao":"1.0.0"}
```

### Endpoint `/api/produtos`

```bash
curl -s localhost:8000/api/produtos | jq 'length'
```

```text
12
```

### Tempo de parada

```bash
time docker stop loja
```

```text
loja
docker stop loja  0,01s user 0,03s system 6% cpu 0,501 total
```

O container encerrou em aproximadamente **0,501 s**, abaixo do limite de 2 segundos.

## 7. Por que o HEALTHCHECK usa `/health` e não `/ready`?

O `HEALTHCHECK` usa `/health` porque ele deve verificar se o processo da aplicação está vivo e respondendo dentro do próprio container. A rota `/ready` representa a prontidão da aplicação para atender requisições e pode envolver dependências externas, por isso `/health` é mais adequado para este teste nesta atividade.

## 8. Resultado final

A imagem final cumpriu os requisitos principais:

- build multi-stage;
- imagem com **131 MB**;
- usuário não-root (`UID 100`);
- estado `healthy`;
- `/health` com HTTP 200;
- `/api/produtos` com **12 produtos**;
- `CMD` em forma exec;
- parada em aproximadamente **0,501 s**.

A otimização reduziu a imagem de **250 MB para 131 MB**, economizando **119 MB**, aproximadamente **47,6%**.