#!/usr/bin/env bash
set -euo pipefail

NETDATA_PORT="19999"
KICKSTART_URL="https://get.netdata.cloud/kickstart.sh"
KICKSTART_FILE="/tmp/netdata-kickstart.sh"

log() {
  echo "[INFO] $*"
}

err() {
  echo "[ERROR] $*" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Missing required command: $1"
    exit 1
  fi
}

check_os() {
  log "Checking operating system..."

  if [[ ! -f /etc/os-release ]]; then
    err "Cannot detect OS. /etc/os-release not found."
    exit 1
  fi

  . /etc/os-release

  log "Detected OS: ${PRETTY_NAME:-unknown}"

  case "${ID:-unknown}" in
    ubuntu|debian|linuxmint|pop)
      log "Supported Debian/Ubuntu-based OS detected."
      ;;
    rhel|centos|rocky|almalinux|fedora)
      log "Supported RHEL/Fedora-based OS detected."
      ;;
    *)
      err "This script was tested mainly on Ubuntu/Debian/RHEL-like systems."
      err "Detected ID=${ID:-unknown}. Please verify compatibility before continuing."
      exit 1
      ;;
  esac
}

check_sudo() {
  log "Checking sudo permission..."
  sudo -n true || { err "No passwordless sudo. Run: sudo visudo"; exit 1; }
}

install_dependencies() {
  log "Installing basic dependencies..."

  . /etc/os-release

  case "${ID:-unknown}" in
    ubuntu|debian|linuxmint|pop)
      sudo apt update
      sudo apt install -y curl ca-certificates
      ;;
    rhel|centos|rocky|almalinux|fedora)
      sudo dnf install -y curl ca-certificates || sudo yum install -y curl ca-certificates
      ;;
  esac
}

install_netdata() {
  if systemctl list-unit-files | grep -q '^netdata.service'; then
    log "Netdata service already exists. Skipping installation."
  else
    log "Downloading Netdata kickstart installer..."
    curl -fsSL "$KICKSTART_URL" -o "$KICKSTART_FILE"

    log "Running Netdata installer..."
    sh "$KICKSTART_FILE" --non-interactive
  fi
}

verify_service() {
  log "Verifying Netdata service..."

  sudo systemctl enable --now netdata

  if ! systemctl is-active --quiet netdata; then
    err "Netdata service is not active."
    sudo systemctl status netdata --no-pager || true
    exit 1
  fi

  log "Netdata service is active."
}

verify_api() {
  log "Checking Netdata local API..."

  for i in {1..30}; do
    if curl -fsS "http://localhost:${NETDATA_PORT}/api/v1/info" >/dev/null 2>&1; then
      log "Netdata API is responding."
      return 0
    fi
    sleep 2
  done

  err "Netdata API did not respond on port ${NETDATA_PORT}."
  exit 1
}

print_dashboard_url() {
  local ip_addr

  ip_addr="$(hostname -I | awk '{print $1}')"

  echo
  echo "=========================================="
  echo "Netdata installation completed successfully"
  echo "Local dashboard:"
  echo "  http://localhost:${NETDATA_PORT}"
  echo
  echo "Network dashboard:"
  echo "  http://${ip_addr}:${NETDATA_PORT}"
  echo "=========================================="
}

main() {
  require_command curl
  require_command systemctl
  require_command hostname
  require_command awk

  check_os
  check_sudo
  install_dependencies
  install_netdata
  verify_service
  verify_api
  print_dashboard_url
}

main "$@"
