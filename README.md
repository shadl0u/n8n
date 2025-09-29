# 🚀 Self-Hosted n8n (Ubuntu 22.04) with Auto Upgrade

Production-ready scripts to **install**, **secure**, and **maintain** [n8n](https://n8n.io) — a powerful workflow automation platform — on your own Linux server using **Docker Compose**, **Nginx**, and **Let’s Encrypt**.

This setup is designed for:
- 🏭 **Production environments**
- 🔐 **Secure HTTPS access**
- 💾 **Automatic backups**
- 🔄 **One-command upgrades**
- 🕒 **Weekly auto-updates**

> 🧠 Example production domain: [https://cloud.codt.io](https://cloud.codt.io)

---

## 🧰 Requirements

- **Ubuntu 22.04 LTS**
- A **domain name** pointing to your server (A/AAAA record)
- A **valid email** (for SSL certificate)
- Desired **username/password** for n8n basic authentication

---

## ⚙️ Installation

Run this one-liner to install everything automatically:

```bash
curl -fsSL https://raw.githubusercontent.com/shadl0u/n8n/main/install-n8n-with-domain.sh | sudo bash
```

You’ll be prompted for:
- 🌍 Your domain name (e.g. `cloud.codt.io`)
- 📧 Email (for Let’s Encrypt SSL)
- 👤 Username and 🔑 password (for basic auth)
- 🔐 PostgreSQL password (internal use)

The script will:
- Install **Docker** and **Docker Compose**
- Deploy **PostgreSQL** and **n8n**
- Set up **Nginx** reverse proxy
- Issue and configure **HTTPS** with auto-renewal
- Start all services automatically

✅ Once complete, open:
```
https://your-domain
```
and log in using the credentials you provided.

---

## ⬆️ Manual Upgrade

You can upgrade n8n anytime with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/shadl0u/n8n/main/n8n-upgrade.sh | sudo bash
```

This script will:
1. 💾 Backup your PostgreSQL database (`pg_dump`)
2. 🗂 Backup your n8n data directory (`tar.gz`)
3. ⬇️ Pull the latest Docker images
4. 🔄 Restart the containers
5. ✅ Run a health check (expects HTTP 200 or 401)
6. ♻️ Rotate old backups (keeps last 7 by default)

Backups are stored in:
```
/opt/n8n/_backups
```

---

## 🔁 Automatic Weekly Upgrade

### Option A — **Cron Job** (easiest)

Run every **Sunday at 03:15 AM**:

```bash
sudo crontab -e
```
Add this line:
```
15 3 * * 0 curl -fsSL https://raw.githubusercontent.com/shadl0u/n8n/main/n8n-upgrade.sh | sudo bash >> /var/log/n8n-upgrade.log 2>&1
```

Logs: `/var/log/n8n-upgrade.log`

---

### Option B — **systemd Timer** (advanced)

Create the service file:
```bash
sudo nano /etc/systemd/system/n8n-upgrade.service
```
Paste:
```ini
[Unit]
Description=n8n auto-upgrade service
[Service]
Type=oneshot
ExecStart=/usr/bin/curl -fsSL https://raw.githubusercontent.com/shadl0u/n8n/main/n8n-upgrade.sh | /usr/bin/sudo bash
```

Then the timer:
```bash
sudo nano /etc/systemd/system/n8n-upgrade.timer
```
Paste:
```ini
[Unit]
Description=Run n8n auto-upgrade weekly
[Timer]
OnCalendar=Sun *-*-* 03:15:00
Persistent=true
[Install]
WantedBy=timers.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now n8n-upgrade.timer
```

Check:
```bash
systemctl list-timers | grep n8n-upgrade
```

---

## 📂 File & Directory Structure

| Item              | Path                                |
|-------------------|-------------------------------------|
| **n8n data**      | `/opt/n8n/data`                     |
| **PostgreSQL data** | `/opt/n8n/postgres`               |
| **Backups**       | `/opt/n8n/_backups`                 |
| **Docker Compose** | `/opt/n8n/docker-compose.yml`      |
| **Nginx config**  | `/etc/nginx/sites-available/n8n.conf` |

Each backup includes:
- `n8n_YYYYMMDD.sql` → Database dump  
- `n8n_data_YYYYMMDD.tar.gz` → Config, credentials, workflows  

---

## 🔙 Rollback Example

If you ever need to revert to an older version:

1. Edit the Docker image in `/opt/n8n/docker-compose.yml`:
   ```yaml
   image: n8nio/n8n:1.76.2
   ```
2. Recreate the stack:
   ```bash
   cd /opt/n8n
   sudo docker compose pull
   sudo docker compose up -d
   ```
3. (Optional) Restore a backup:
   ```bash
   cat /opt/n8n/_backups/YYYYMMDD/n8n_*.sql | sudo docker compose exec -T postgres psql -U n8n -d n8n
   ```

---

## 🧭 Useful Commands

| Task | Command |
|------|----------|
| Check containers | `sudo docker compose -f /opt/n8n/docker-compose.yml ps` |
| View logs | `sudo docker compose -f /opt/n8n/docker-compose.yml logs -f n8n` |
| Restart stack | `sudo docker compose -f /opt/n8n/docker-compose.yml restart` |
| Check version | `sudo docker compose exec n8n n8n --version` |

---

## 💡 Notes
- The scripts auto-detect your domain and credentials.
- You can edit settings anytime in `/opt/n8n/docker-compose.yml`.
- SSL certificates renew automatically with **Certbot**.

---

## 🧑‍💻 Author

**CODT Cloud Engineering**  
Maintained by [shadl0u](https://github.com/shadl0u)  
Production instance: [https://cloud.codt.io](https://cloud.codt.io)

---

## 📝 License

MIT License  

Copyright (c) 2025 **shadl0u**

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
