# n8n
# 🚀 Self-Hosted n8n (Ubuntu 22.04) with Auto Upgrade

Production-ready scripts to deploy and maintain **[n8n](https://n8n.io)** on your own server using **Docker Compose**, **Nginx**, and **Let’s Encrypt**.

- ✅ One-command **installation** with HTTPS & PostgreSQL  
- 🔐 **Basic Auth** for n8n  
- 💾 **Backups** before every upgrade  
- ♻️ **Auto-upgrade** via cron or systemd timer  



---

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

