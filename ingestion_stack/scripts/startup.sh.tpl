#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# ===== SYSTEM SETUP =====
retry_apt() {
  for i in {1..10}; do
    if apt-get update -y && apt-get install -y python3 python3-venv python3-pip; then
      return 0
    fi
    echo "apt-get is locked or failed, retrying in 10s... ($i/10)"
    sleep 10
  done
  echo "apt-get failed after multiple retries"
  exit 1
}

retry_apt

# ===== CREATE APP USER AND DIRECTORIES =====
adduser --system --group --home /opt/kline kline || true
install -d -o kline -g kline -m 755 /opt/kline
install -d -o kline -g kline -m 755 /var/log/kline
sudo -u kline bash -lc 'touch /var/log/kline/kline.log'

# ===== DEPLOY APP CODE =====
cat >/opt/kline/binance_kline_streamer.py <<'PYCODE'
${streamer_py}
PYCODE
chown -R kline:kline /opt/kline

# ===== PYTHON VENV & DEPENDENCIES =====
sudo -u kline bash -lc '
  cd /opt/kline
  python3 -m venv .venv
  . .venv/bin/activate
  python -m pip install --upgrade pip
  python -m pip install websockets
  python -m pip install google-cloud-pubsub
  # Sanity check: imports must succeed
  python - <<PY
import websockets
print("websockets OK", websockets.__version__)

from google.cloud import pubsub_v1
print("google-cloud-pubsub OK")
PY
'

# ===== SYSTEMD UNIT =====
cat >/etc/systemd/system/kline.service <<'UNIT'
[Unit]
Description=Kline Streamer (Python)
After=network-online.target
Wants=network-online.target
# rate limiting belongs in [Unit]
StartLimitInterval=60
StartLimitBurst=10

[Service]
Type=simple
User=kline
WorkingDirectory=/opt/kline
Environment="PATH=/opt/kline/.venv/bin:/usr/bin"
EnvironmentFile=-/etc/default/kline

# Verify deps and log path before starting (prevents first-boot race)
ExecStartPre=/opt/kline/.venv/bin/python -c "import websockets"
ExecStartPre=/bin/bash -lc 'test -w /var/log/kline && echo ok'

ExecStart=/opt/kline/.venv/bin/python /opt/kline/binance_kline_streamer.py

Restart=always
RestartSec=5

StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/opt/kline /var/log/kline

[Install]
WantedBy=multi-user.target
UNIT

# Enable after everything is ready, then start
systemctl daemon-reload
systemctl enable --now kline

# Show status in serial console logs
systemctl --no-pager --full status kline || true
