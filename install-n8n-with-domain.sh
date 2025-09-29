#!/usr/bin/env bash
# Production n8n installer for Ubuntu 22.04
# - Docker + Compose plugin
# - PostgreSQL
# - n8n bound to localhost
# - Nginx reverse proxy
# - Let's Encrypt SSL (auto-renew)
# - Basic Auth for n8n
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

echo "=== n8n Production Installer (Ubuntu 22.04) ==="

read -rp "Enter your domain for n8n (e.g. cloud.codt.io): " DOMAIN
read -rp "Admin email for Let's Encrypt (for renewal notices): " LE_EMAIL
read -rp "n8n basic auth username [admin]: " N8N_USER
N8N_USER=${N8N_USER:-admin}
read -rsp "n8n basic auth password (will not echo): " N8N_PASS; echo
read -rsp "PostgreSQL password (will not echo): " PG_PASS; echo

# Generate secure encryption key for n8n secrets
N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)

apt update && apt -y upgrade
apt -y install ca-certificates curl gnupg lsb-release unzip

# Docker (official)
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt update
apt -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker --now

# Create app dirs
mkdir -p /opt/n8n/{data,postgres}
cd /opt/n8n

# docker-compose.yml
cat > /opt/n8n/docker-compose.yml <<'YML'
version: "3.8"
services:
  postgres:
    image: postgres:15
    restart: always
    environment:
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: ${PG_PASS}
      POSTGRES_DB: n8n
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n -d n8n"]
      interval: 10s
      timeout: 5s
      retries: 10
    volumes:
      - ./postgres:/var/lib/postgresql/data

  n8n:
    image: n8nio/n8n:latest
    restart: always
    depends_on:
      postgres:
        condition: service_healthy
    # Bind only to localhost; Nginx will reverse-proxy
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      # Database
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: n8n
      DB_POSTGRESDB_PASSWORD: ${PG_PASS}

      # Security & auth
      N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
      N8N_BASIC_AUTH_ACTIVE: "true"
      N8N_BASIC_AUTH_USER: ${N8N_USER}
      N8N_BASIC_AUTH_PASSWORD: ${N8N_PASS}

      # Public URL settings
      N8N_HOST: ${DOMAIN}
      N8N_PROTOCOL: https
      WEBHOOK_URL: https://${DOMAIN}/
      N8N_EDITOR_BASE_URL: https://${DOMAIN}/

      NODE_ENV: production
      TZ: UTC
    volumes:
      - ./data:/home/node/.n8n
YML

# Inject vars
sed -i "s|\${PG_PASS}|${PG_PASS}|g" /opt/n8n/docker-compose.yml
sed -i "s|\${N8N_ENCRYPTION_KEY}|${N8N_ENCRYPTION_KEY}|g" /opt/n8n/docker-compose.yml
sed -i "s|\${N8N_USER}|${N8N_USER}|g" /opt/n8n/docker-compose.yml
sed -i "s|\${N8N_PASS}|${N8N_PASS}|g" /opt/n8n/docker-compose.yml
sed -i "s|\${DOMAIN}|${DOMAIN}|g" /opt/n8n/docker-compose.yml

# Start stack
docker compose -f /opt/n8n/docker-compose.yml up -d

# Nginx + Certbot
apt -y install nginx certbot python3-certbot-nginx

cat > /etc/nginx/sites-available/n8n.conf <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        proxy_pass http://127.0.0.1:5678;
        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/n8n.conf /etc/nginx/sites-enabled/n8n.conf
nginx -t && systemctl restart nginx

# SSL (adds HTTPS + redirect)
certbot --nginx -d "${DOMAIN}" -m "${LE_EMAIL}" --agree-tos --redirect -n

# UFW (optional)
if command -v ufw >/dev/null 2>&1; then
  ufw allow OpenSSH || true
  ufw allow "Nginx Full" || true
fi

echo
echo "=== ✅ Done! n8n is live at: https://${DOMAIN} ==="
echo "Basic auth user: ${N8N_USER}"
echo
echo "Files:"
echo "  - Compose: /opt/n8n/docker-compose.yml"
echo "  - n8n data: /opt/n8n/data"
echo "  - Postgres data: /opt/n8n/postgres"
echo "  - Nginx: /etc/nginx/sites-available/n8n.conf"
echo
echo "Upgrade later with: curl -fsSL https://raw.githubusercontent.com/<YOUR_GH_USER>/<YOUR_REPO>/main/n8n-upgrade.sh | sudo bash"
