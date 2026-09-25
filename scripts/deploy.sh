#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ufla-shop"
APP_USER="ufla-shop"
APP_DIR="/opt/${APP_NAME}"

ENV_FILE="/etc/${APP_NAME}.env"
ENV_EXAMPLE="/etc/${APP_NAME}.env.example"

SYSTEMD_DIR="/etc/systemd/system"
NGINX_SSL_DIR="/etc/nginx/ssl"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() {
    printf '[%s] %s\n' "$(date -Is)" "$*"
}

if [[ "${EUID}" -ne 0 ]]; then
    echo "Execute este script com sudo." >&2
    exit 1
fi

if [[ ! -f "${REPO_DIR}/requirements.txt" ]]; then
    echo "requirements.txt não encontrado em ${REPO_DIR}." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log "Instalando dependências do sistema..."

apt-get update

apt-get install -y \
    python3-venv \
    postgresql \
    redis-server \
    nginx \
    openssl \
    curl \
    rsync

if ! id "${APP_USER}" &>/dev/null; then
    log "Criando usuário de sistema ${APP_USER}..."

    useradd \
        --system \
        --home-dir "${APP_DIR}" \
        --shell /usr/sbin/nologin \
        "${APP_USER}"
fi

install \
    -d \
    -o "${APP_USER}" \
    -g "${APP_USER}" \
    -m 0755 \
    "${APP_DIR}"

log "Sincronizando código para ${APP_DIR}..."

rsync -a --delete \
    --exclude='.git/' \
    --exclude='.venv/' \
    "${REPO_DIR}/" \
    "${APP_DIR}/"

chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"

if [[ ! -f "${ENV_EXAMPLE}" ]]; then
    log "Criando ${ENV_EXAMPLE}..."

    cat > "${ENV_EXAMPLE}" <<'EOF_ENV_EXAMPLE'
DATABASE_URL=postgresql://loja:troque-esta-senha@localhost:5432/loja
REDIS_URL=redis://localhost:6379/0
EOF_ENV_EXAMPLE

    chmod 0644 "${ENV_EXAMPLE}"
fi

if [[ ! -f "${ENV_FILE}" ]]; then
    log "Criando ${ENV_FILE} a partir do exemplo..."

    cp "${ENV_EXAMPLE}" "${ENV_FILE}"
    chmod 0600 "${ENV_FILE}"

    echo "Edite ${ENV_FILE} com a senha real do banco antes de usar o serviço." >&2
fi

log "Criando ou atualizando o ambiente Python..."

python3 -m venv --upgrade-deps "${APP_DIR}/.venv"

"${APP_DIR}/.venv/bin/pip" install \
    --disable-pip-version-check \
    -r "${APP_DIR}/requirements.txt"

log "Instalando units do systemd..."

install \
    -m 0644 \
    "${REPO_DIR}/systemd/ufla-shop.service" \
    "${SYSTEMD_DIR}/ufla-shop.service"

install \
    -m 0644 \
    "${REPO_DIR}/systemd/ufla-shop-backup.service" \
    "${SYSTEMD_DIR}/ufla-shop-backup.service"

install \
    -m 0644 \
    "${REPO_DIR}/systemd/ufla-shop-backup.timer" \
    "${SYSTEMD_DIR}/ufla-shop-backup.timer"

systemctl daemon-reload

systemctl enable --now postgresql
systemctl enable --now redis-server

log "Configurando certificado TLS autoassinado..."

install -d -m 0755 "${NGINX_SSL_DIR}"

if [[ ! -s "${NGINX_SSL_DIR}/loja.pem" ||
      ! -s "${NGINX_SSL_DIR}/loja.key" ]]; then

    openssl req \
        -x509 \
        -nodes \
        -days 365 \
        -newkey rsa:2048 \
        -keyout "${NGINX_SSL_DIR}/loja.key" \
        -out "${NGINX_SSL_DIR}/loja.pem" \
        -subj "/CN=localhost"

    chmod 0600 "${NGINX_SSL_DIR}/loja.key"
    chmod 0644 "${NGINX_SSL_DIR}/loja.pem"
fi

install \
    -m 0644 \
    "${REPO_DIR}/nginx/loja.conf" \
    /etc/nginx/sites-available/loja.conf

ln -sfn \
    /etc/nginx/sites-available/loja.conf \
    /etc/nginx/sites-enabled/loja.conf

rm -f /etc/nginx/sites-enabled/default

nginx -t

systemctl enable --now nginx
systemctl reload nginx

log "Habilitando serviço e timer..."

systemctl enable --now ufla-shop-backup.timer

systemctl enable --now ufla-shop

systemctl restart ufla-shop

log "Executando healthcheck em /ready..."

for attempt in $(seq 1 10); do
    if curl -fsS \
        -o /dev/null \
        http://127.0.0.1:8000/ready; then

        log "Healthcheck OK na tentativa ${attempt}."
        exit 0
    fi

    sleep 1
done

echo "Healthcheck falhou após 10 tentativas." >&2

systemctl status ufla-shop --no-pager >&2 || true

exit 1