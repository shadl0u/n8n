#!/usr/bin/env bash
# Safe n8n upgrade (Docker Compose)
# - Backs up Postgres (pg_dump)
# - Backs up n8n data dir
# - Pulls latest images
# - Recreates containers
# - Health check (accepts 200/401)
set -euo pipefail

STACK_DIR="/opt/n8n"
BACKUP_DIR="/opt/n8n/_backups"
KEEP_BACKUPS="${KEEP_BACKUPS:-7}"

timestamp() { date +"%Y%m%d-%H%M%S"; }

# --- Helper: Try to infer DOMAIN & auth from nginx / compose ---
infer_domain() {
  if [[ -f /etc/nginx/sites-enabled/n8n.conf ]]; then
    awk '/server_name/ {print $2}' /etc/nginx/sites-enabled/n8n.conf 2>/dev/null | sed 's/;//' | head -n1
  elif [[ -f /etc/nginx/sites-available/n8n.conf ]]; then
    awk '/server_name/ {print $2}' /etc/nginx/sites-available/n8n.conf 2>/dev/null | sed 's/;//' | head -n1
  elif [[ -f "${STACK_DIR}/docker-compose.yml" ]]; then
    awk -F': ' '/N8N_HOST:/{print $2}' "${STACK_DIR}/docker-compose.yml" 2>/dev/null | head -n1
  fi
}

infer_env() {
  local key="$1"
  if [[ -f "${STACK_DIR}/docker-compose.yml" ]]; then
    awk -F': ' -v k="$key" '$1 ~ k {print $2}' "${STACK_DIR}/docker-compose.yml" 2>/dev/null | head -n1
  fi
}

DOMAIN="${DOMAIN:-$(infer_domain || true)}"
N8N_USER="${N8N_USER:-$(infer_env 'N8N_BASIC_AUTH_USER' || true)}"
N8N_PASS="${N8N_PASS:-$(infer_env 'N8N_BASIC_AUTH_PASSWORD' || true)}"
HEALTH_URL="${HEALTH_URL:-https://${DOMAIN:-localhost}/}"

echo "== n8n upgrade started @ $(date) =="
echo "Stack dir: ${STACK_DIR}"
echo "Backups:   ${BACKUP_DIR}"
echo "Domain:    ${DOMAIN:-unknown}"

cd "$STACK_DIR"

command -v docker >/dev/null || { echo "Docker not found."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose plugin not found."; exit 1; }

TS="$(timestamp)"
THIS_BACKUP="${BACKUP_DIR}/${TS}"
mkdir -p "$THIS_BACKUP"

echo "-> Backing up Postgres (logical dump) and n8n data..."
# pg_dump (service must be called 'postgres')
docker compose exec -T postgres pg_dump -U n8n -d n8n > "${THIS_BACKUP}/n8n_${TS}.sql"

# Data archive
tar -C "$STACK_DIR" -czf "${THIS_BACKUP}/n8n_data_${TS}.tar.gz" ./data

echo "-> Pulling latest images..."
docker compose pull

echo "-> Recreating containers..."
docker compose up -d

echo "-> Health check..."
set +e
if [[ -n "${N8N_USER:-}" && -n "${N8N_PASS:-}" ]]; then
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "${N8N_USER}:${N8N_PASS}" --max-time 25 "${HEALTH_URL}")
else
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 25 "${HEALTH_URL}")
fi
set -e

if [[ "$CODE" == "200" || "$CODE" == "401" ]]; then
  echo "   OK: HTTP ${CODE}"
else
  echo "   WARNING: Unexpected HTTP ${CODE}. Recent logs:"
  docker compose logs --tail=200 n8n || true
fi

echo "-> Rotating backups, keeping last ${KEEP_BACKUPS}…"
ls -1dt "${BACKUP_DIR}"/* 2>/dev/null | tail -n +$((KEEP_BACKUPS+1)) | xargs -r rm -rf --

echo "== n8n upgrade complete @ $(date) =="
