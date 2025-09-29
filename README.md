🧾 README.md
# 🚀 Self-Hosted n8n (Ubuntu 22.04) with Auto Upgrade

Production-ready scripts to deploy and maintain **[n8n](https://n8n.io)** on your own server using **Docker Compose**, **Nginx**, and **Let’s Encrypt**.

- ✅ One-command **installation** with HTTPS & PostgreSQL  
- 🔐 **Basic Auth** for n8n  
- 💾 **Backups** before every upgrade  
- ♻️ **Auto-upgrade** via cron or systemd timer  

## 🧰 Requirements

- Ubuntu 22.04 LTS
- Domain pointing to your server (A/AAAA record)
- Email address for Let’s Encrypt
- Chosen username/password for n8n basic auth

---

## ⚙️ Install

Run the installer (downloads from this repo and executes):

```bash
curl -fsSL https://raw.githubusercontent.com/shadl0u/n8n/main/install-n8n-with-domain.sh | sudo bash


It will:

Install Docker & Compose plugin

Deploy PostgreSQL + n8n

Configure Nginx reverse proxy

Issue and enable HTTPS (auto-renew)

Start on boot

When it finishes, open:

https://your-domain


Login with your chosen credentials.

⬆️ Upgrade (Manual)

Run the upgrade script any time:

curl -fsSL https://raw.githubusercontent.com/shadl0u/n8n/main/n8n-upgrade.sh | sudo bash


What it does:

Backs up PostgreSQL (pg_dump)

Backs up n8n data directory (tar.gz)

Pulls latest Docker images

Recreates containers

Health check (accepts HTTP 200/401)

Rotates old backups (default keep 7)

Backups live in: /opt/n8n/_backups

🔁 Auto-Upgrade (Weekly)
Option A — Cron (simple)

Run Sundays at 03:15:

sudo crontab -e


Add:

15 3 * * 0 curl -fsSL https://raw.githubusercontent.com/shadl0u/n8n/main/n8n-upgrade.sh | sudo bash >> /var/log/n8n-upgrade.log 2>&1

Option B — systemd Timer (advanced)

Create /etc/systemd/system/n8n-upgrade.service:

[Unit]
Description=n8n auto-upgrade service
[Service]
Type=oneshot
ExecStart=/usr/bin/curl -fsSL https://raw.githubusercontent.com/shadl0u/n8n/main/n8n-upgrade.sh | /usr/bin/sudo bash


Create /etc/systemd/system/n8n-upgrade.timer:

[Unit]
Description=Run n8n auto-upgrade weekly
[Timer]
OnCalendar=Sun *-*-* 03:15:00
Persistent=true
[Install]
WantedBy=timers.target


Enable:

sudo systemctl daemon-reload
sudo systemctl enable --now n8n-upgrade.timer


Check schedule:

systemctl list-timers | grep n8n-upgrade

📂 Paths
Item	Path
Compose file	/opt/n8n/docker-compose.yml
n8n data	/opt/n8n/data
PostgreSQL data	/opt/n8n/postgres
Backups	/opt/n8n/_backups
Nginx config	/etc/nginx/sites-available/n8n.conf
🔙 Rollback (example)

Pin an older image in /opt/n8n/docker-compose.yml:

image: n8nio/n8n:1.76.2


Apply:

cd /opt/n8n
sudo docker compose pull
sudo docker compose up -d


(Optional) Restore DB:

cat /opt/n8n/_backups/YYYYMMDD-XXXX/n8n_*.sql | sudo docker compose exec -T postgres psql -U n8n -d n8n

📝 License
