#!/usr/bin/env bash
# ============================================================
# n8n Upgrade Script
# - Backs up PostgreSQL database (pg_dump)
# - Backs up n8n data directory
# - Pulls latest Docker images
# - Restarts containers
# - Performs health check (HTTP 200 or 401)
# ============================================================

set -euo pipefail

STACK_DIR="/opt/n8n"
BACKUP_DIR="/opt/n8n/_backups"
KEEP_BACKUPS="${KEEP_BACKUPS:-7}"

timestamp() { date +"%Y%m%d-%H%M%S"; }

# --- Helper functions ---
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

# --- Inferred values ---
DOMAIN="${DOMAIN:-$(infer_domain || true)}"
N8N_USER="${N8N_USER:-$(infer_env 'N8N_BASIC_AUTH_USER' || true)}"
N8N_PASS="${N8N_PASS:-$(infer_env 'N8N_BASIC_AUTH_PASSWORD' || true)}"
HEALTH_URL="${HEALTH_URL:-https://${DOMAIN:-localhost}/}"

# --- Banner ---
echo
echo "============================================="
echo "🚀 Starting n8n upgrade @ $(date)"
echo "Stack directory: ${STACK_DIR}"
echo "Backups directory: ${BACKUP_DIR}"
echo "Domain: ${DOMAIN:-unknown}"
echo "============================================="
echo

cd "$STACK_DIR"

command -v docker >/dev/null || { echo "❌ Docker not found."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "❌ docker compose plugin not found."; exit 1; }

# --- Create backup ---
TS="$(timestamp)"
THIS_BACKUP="${BACKUP_DIR}/${TS}"
mkdir -p "$THIS_BACKUP"

echo "🧾 Backing up PostgreSQL database..."
docker compose exec -T postgres pg_dump -U n8n -d n8n > "${THIS_BACKUP}/n8n_${TS}.sql"

echo "💾 Backing up n8n data directory..."
tar -C "$STACK_DIR" -czf "${THIS_BACKUP}/n8n_data_${TS}.tar.gz" ./data

# --- Pull new images ---
echo "⬇️  Pulling latest Docker images..."
docker compose pull

# --- Restart services ---
echo "🔄 Recreating containers..."
docker compose up -d

# --- Health check ---
echo "🔍 Checking health at ${HEALTH_URL} ..."
set +e
if [[ -n "${N8N_USER:-}" && -n "${N8N_PASS:-}" ]]; then
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "${N8N_USER}:${N8N_PASS}" --max-time 25 "${HEALTH_URL}")
else
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 25 "${HEALTH_URL}")
fi
set -e

if [[ "$CODE" == "200" || "$CODE" == "401" ]]; then
  echo "✅ Health check passed (HTTP ${CODE})"
else
  echo "⚠️  Warning: unexpected HTTP ${CODE}. Check logs:"
  docker compose logs --tail=50 n8n || true
fi

# --- Rotate old backups ---
echo "♻️  Rotating backups (keeping last ${KEEP_BACKUPS})..."
ls -1dt "${BACKUP_DIR}"/* 2>/dev/null | tail -n +$((KEEP_BACKUPS+1)) | xargs -r rm -rf --

# --- Summary ---
echo
echo "============================================="
echo "✅ n8n upgrade completed successfully!"
echo "🕒 Date: $(date)"
echo "📂 Backup saved to: ${THIS_BACKUP}"
echo "🌐 URL: ${HEALTH_URL}"
echo "💡 Tip: Next scheduled auto-upgrade will use this same script."
echo "============================================="
exit 0
