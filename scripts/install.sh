#!/usr/bin/env bash
# ==============================================================================
# OmniNexus Agent Universal 1-Line Installer for Linux (Ubuntu/Debian/RHEL/CentOS)
# Usage:
#   curl -sSL https://raw.githubusercontent.com/howtosecu/OmniNexus-Agent/main/scripts/install.sh | sudo bash -s -- [options]
# ==============================================================================

set -euo pipefail

HUB_ENDPOINT="127.0.0.1:9443"
ENROLLMENT_TOKEN="change-this-secret"
TENANT_ID="org-default"
INSTALL_DIR="/opt/omninexus"
REPO_URL="https://github.com/howtosecu/OmniNexus-Agent"

# Parse CLI flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --hub-endpoint=*)
      HUB_ENDPOINT="${1#*=}"
      shift
      ;;
    --token=*)
      ENROLLMENT_TOKEN="${1#*=}"
      shift
      ;;
    --tenant=*)
      TENANT_ID="${1#*=}"
      shift
      ;;
    --install-dir=*)
      INSTALL_DIR="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

echo "============================================================"
echo "⚡ Starting OmniNexus Endpoint Agent Installer"
echo "   Hub Endpoint: ${HUB_ENDPOINT}"
echo "   Tenant ID:    ${TENANT_ID}"
echo "   Install Dir:  ${INSTALL_DIR}"
echo "============================================================"

# Check root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "[-] Error: This installation script must be run as root (sudo)." >&2
  exit 1
fi

# 1. Detect Architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64)
    GOARCH="amd64"
    ;;
  aarch64|arm64)
    GOARCH="arm64"
    ;;
  *)
    echo "[-] Unsupported CPU architecture: $ARCH" >&2
    exit 1
    ;;
esac

echo "[+] Detected architecture: Linux-${GOARCH}"

# 2. Create Destination Directory & Dedicated User
mkdir -p "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}/bin"

if ! id "omninexus" &>/dev/null; then
  useradd --system --no-create-home --shell /usr/sbin/nologin omninexus || true
fi

# 3. Download Binary from GitHub Release
BINARY_NAME="nexus-agent-linux-${GOARCH}"
TARGET_PATH="${INSTALL_DIR}/bin/nexus-agent"

echo "[+] Fetching latest release binary from ${REPO_URL}..."
DOWNLOAD_URL="${REPO_URL}/releases/latest/download/${BINARY_NAME}"
if ! curl -sSL -f -o "${TARGET_PATH}" "${DOWNLOAD_URL}"; then
  echo "[-] Failed to download ${DOWNLOAD_URL}. Verify that a Release exists." >&2
  exit 1
fi

# Ensure executable permissions
chmod 755 "${TARGET_PATH}"

# 4. Generate Production Configuration
CONFIG_PATH="${INSTALL_DIR}/agent.yaml"
cat << EOF > "${CONFIG_PATH}"
hub:
  endpoint: "${HUB_ENDPOINT}"
  insecure: true
  reconnect_interval_sec: 5
  max_reconnect_interval_sec: 60

identity:
  tenant_id: "${TENANT_ID}"
  enrollment_token: "${ENROLLMENT_TOKEN}"
  key_file: "${INSTALL_DIR}/identity.key"
  tags:
    installer: "curl_bash"
    os: "linux"
    arch: "${GOARCH}"

telemetry:
  enabled: true
  interval_sec: 15
  enable_ebpf: true
  enable_process_monitoring: true

execution:
  allow_shell: true
  allow_file_transfer: true
  session_timeout_sec: 3600

logging:
  level: "info"
  format: "text"
EOF

chown -R omninexus:omninexus "${INSTALL_DIR}"
chmod 600 "${CONFIG_PATH}"

# 5. Create and Register Systemd Service
SERVICE_FILE="/etc/systemd/system/omninexus-agent.service"
echo "[+] Creating systemd service at ${SERVICE_FILE}..."

cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=OmniNexus Enterprise Endpoint Management Agent
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${TARGET_PATH} --config ${CONFIG_PATH}
Restart=always
RestartSec=5s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Reload and Enable Service
systemctl daemon-reload
systemctl enable omninexus-agent.service

echo "============================================================"
echo "✔ OmniNexus Agent successfully installed and registered!"
echo "   Start with: sudo systemctl start omninexus-agent"
echo "   Status:     sudo systemctl status omninexus-agent"
echo "   View Logs:  sudo journalctl -u omninexus-agent -f"
echo "============================================================"
