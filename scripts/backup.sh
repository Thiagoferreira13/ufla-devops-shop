#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/var/backups/ufla-shop"

TIMESTAMP="$(date +%Y-%m-%d-%H%M)"
TARGET="${BACKUP_DIR}/loja-${TIMESTAMP}.sql.gz"

: "${DATABASE_URL:?DATABASE_URL não definido}"

install -d -m 0755 "${BACKUP_DIR}"

TMP_FILE="$(mktemp "${BACKUP_DIR}/.loja-XXXXXX.sql.gz")"

cleanup() {
    rm -f "${TMP_FILE}"
}

trap cleanup EXIT

pg_dump "${DATABASE_URL}" | gzip > "${TMP_FILE}"

mv -f "${TMP_FILE}" "${TARGET}"

mapfile -t dumps < <(
    find "${BACKUP_DIR}" \
        -maxdepth 1 \
        -type f \
        -name 'loja-*.sql.gz' \
        -printf '%T@ %p\n' |
        sort -nr |
        cut -d' ' -f2-
)

if ((${#dumps[@]} > 7)); then
    for old_dump in "${dumps[@]:7}"; do
        rm -f -- "${old_dump}"
    done
fi

SIZE="$(du -h "${TARGET}" | cut -f1)"

logger \
    -t backup \
    "arquivo gerado: ${TARGET} (${SIZE})"

printf \
    'Backup criado: %s (%s)\n' \
    "${TARGET}" \
    "${SIZE}"