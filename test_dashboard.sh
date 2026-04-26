#!/usr/bin/env bash
set -euo pipefail

NETDATA_PORT="19999"
CPU_LOAD_SECONDS="60"
DISK_TEST_FILE="/tmp/netdata-disk-test.img"

log() {
  echo "[INFO] $*"
}

err() {
  echo "[ERROR] $*" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Missing required command: $1"
    return 1
  fi
}

install_test_tools() {
  log "Checking stress/stress-ng..."

  if command -v stress >/dev/null 2>&1 || command -v stress-ng >/dev/null 2>&1; then
    log "CPU load tool already installed."
    return 0
  fi

  log "Installing stress tool..."

  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
  else
    err "Cannot detect OS."
    exit 1
  fi

  case "${ID:-unknown}" in
    ubuntu|debian|linuxmint|pop)
      sudo apt update
      sudo apt install -y stress
      ;;
    rhel|centos|rocky|almalinux|fedora)
      sudo dnf install -y stress-ng || sudo yum install -y stress-ng
      ;;
    *)
      err "Unsupported OS for automatic stress installation."
      exit 1
      ;;
  esac
}

check_netdata_api() {
  log "Checking Netdata API..."

  if ! curl -fsS "http://localhost:${NETDATA_PORT}/api/v1/info" >/dev/null; then
    err "Netdata API is not responding at http://localhost:${NETDATA_PORT}/api/v1/info"
    exit 1
  fi

  log "Netdata API is responding."
}

create_cpu_load() {
  log "Creating CPU load for ${CPU_LOAD_SECONDS} seconds..."

  if command -v stress >/dev/null 2>&1; then
    stress --cpu 1 --timeout "${CPU_LOAD_SECONDS}" &
  elif command -v stress-ng >/dev/null 2>&1; then
    stress-ng --cpu 1 --timeout "${CPU_LOAD_SECONDS}s" &
  else
    err "Neither stress nor stress-ng is available."
    exit 1
  fi

  log "CPU load started in background."
}

create_disk_io() {
  log "Creating disk I/O activity..."

  dd if=/dev/zero of="${DISK_TEST_FILE}" bs=64M count=8 oflag=direct status=progress || true
  sync
  rm -f "${DISK_TEST_FILE}"

  log "Disk I/O test completed."
}

check_metric() {
  local chart="$1"

  log "Checking chart: ${chart}"

  if curl -fsS "http://localhost:${NETDATA_PORT}/api/v1/data?chart=${chart}&after=-60&format=json" >/dev/null; then
    log "Metric returned data: ${chart}"
  else
    err "Metric did not return data: ${chart}"
    return 1
  fi
}

check_metrics() {
  log "Checking basic Netdata metrics via REST API..."

  check_metric "system.cpu"
  check_metric "system.ram"
  check_metric "system.load"
  check_metric "disk_space._"
}

show_active_alerts() {
  log "Showing current WARNING/CRITICAL alerts if jq is available..."

  if command -v jq >/dev/null 2>&1; then
    curl -s "http://localhost:${NETDATA_PORT}/api/v1/alarms?all" \
    | jq -r '
      .alarms
      | to_entries[]
      | select(.value.status=="WARNING" or .value.status=="CRITICAL")
      | "\(.value.status) | \(.value.name) | \(.value.context) | \(.value.value_string)"
    ' || true
  else
    log "jq not installed. Raw alarms endpoint:"
    curl -s "http://localhost:${NETDATA_PORT}/api/v1/alarms?all" | head -c 1000
    echo
  fi
}

main() {
  require_command curl || exit 1
  require_command dd || exit 1
  require_command sync || exit 1

  check_netdata_api
  install_test_tools
  create_cpu_load
  create_disk_io
  check_metrics
  show_active_alerts

  echo
  echo "=========================================="
  echo "Dashboard test completed."
  echo "Open:"
  echo "  http://localhost:${NETDATA_PORT}"
  echo "or:"
  echo "  http://$(hostname -I | awk '{print $1}'):${NETDATA_PORT}"
  echo "=========================================="
}

main "$@"
