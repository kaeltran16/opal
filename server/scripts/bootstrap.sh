#!/usr/bin/env bash
# One-time provisioning for the opal-api droplet. Idempotent. Run as root.
#   scp server/scripts/bootstrap.sh root@HOST:/root/ && ssh root@HOST 'bash /root/bootstrap.sh'
set -euo pipefail

APP_USER=opal
APP_DIR=/opt/opal-api
DOMAIN=opal.kael.life

echo "==> Installing Node 20 + build tools"
if ! command -v node >/dev/null || [ "$(node -v | cut -d. -f1 | tr -d v)" -lt 20 ]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
apt-get install -y build-essential python3 rsync curl

echo "==> Installing Caddy"
if ! command -v caddy >/dev/null; then
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get install -y caddy
fi

echo "==> Creating user + app dir"
id -u "$APP_USER" >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin "$APP_USER"
mkdir -p "$APP_DIR"
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

echo "==> Installing systemd unit"
cat >/etc/systemd/system/opal-api.service <<UNIT
[Unit]
Description=opal-api backend
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=/usr/bin/node dist/server.js
Restart=on-failure
User=$APP_USER

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable opal-api

echo "==> Installing Caddyfile"
cat >/etc/caddy/Caddyfile <<CADDY
$DOMAIN {
    reverse_proxy 127.0.0.1:8080
}
CADDY
systemctl reload caddy || systemctl restart caddy

echo "==> Writing .env (only if missing)"
if [ ! -f "$APP_DIR/.env" ]; then
  cat >"$APP_DIR/.env" <<ENV
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:?set OPENROUTER_API_KEY env before running}
PAL_PROVISIONING_KEY=${PAL_PROVISIONING_KEY:?set PAL_PROVISIONING_KEY env before running}
PAL_MODEL=${PAL_MODEL:-deepseek/deepseek-v4-flash}
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
PORT=8080
SQLITE_PATH=$APP_DIR/loop.sqlite
CORS_ORIGINS=
ENV
  chown "$APP_USER:$APP_USER" "$APP_DIR/.env"
  chmod 600 "$APP_DIR/.env"
  echo "    wrote $APP_DIR/.env"
else
  echo "    $APP_DIR/.env exists, leaving as-is"
fi

echo "==> Bootstrap complete. Deploy via GitHub Actions, then:"
echo "    curl https://$DOMAIN/healthz"
