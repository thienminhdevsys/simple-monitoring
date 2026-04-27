#!/usr/bin/env bash
set -euo pipefail

# Detect if running in CI (non-interactive)
CI_MODE="${CI:-false}"

log() { echo "[INFO] $*"; }
err() { echo "[ERROR] $*" >&2; }

stop_netdata() {
  log "Stopping Netdata service if it exists..."
  if systemctl list-unit-files | grep -q '^netdata.service'; then
    sudo systemctl stop netdata    || true
    sudo systemctl disable netdata || true
    log "Netdata service stopped and disabled."
  else
    log "netdata.service not found."
  fi
}

find_uninstaller() {
  # Check common locations first (fast)
  local candidates=(
    "/usr/libexec/netdata/netdata-uninstaller.sh"
    "/opt/netdata/usr/libexec/netdata/netdata-uninstaller.sh"
    "/usr/lib/netdata/netdata-uninstaller.sh"
  )
  for file in "${candidates[@]}"; do
    if [[ -x "$file" ]]; then
      echo "$file"
      return 0
    fi
  done

  # Fallback: search only likely directories (not full /)
  find /usr /opt /var -name "netdata-uninstaller.sh" \
    -type f -perm -u+x 2>/dev/null | head -n 1
}

uninstall_netdata() {
  local uninstaller
  uninstaller="$(find_uninstaller || true)"

  if [[ -n "${uninstaller}" ]]; then
    log "Found Netdata uninstaller: ${uninstaller}"
    log "Running uninstaller..."

    # --env flag needed for kickstart-installed Netdata
    local env_file="/etc/netdata/.environment"
    if [[ -f "${env_file}" ]]; then
      sudo "${uninstaller}" --yes --env "${env_file}" || {
        err "Uninstaller failed, attempting APT fallback..."
        _apt_remove || exit 1
      }
    else
      sudo "${uninstaller}" --yes || {
        err "Uninstaller failed, attempting APT fallback..."
        _apt_remove || exit 1
      }
    fi

  else
    log "Uninstaller not found, trying APT..."
    _apt_remove || {
      err "Could not remove Netdata. Try manually:"
      err "  sudo apt remove --purge netdata"
      exit 1
    }
  fi
}

_apt_remove() {
  if dpkg -l 2>/dev/null | grep -qi netdata; then
    sudo apt remove --purge -y netdata || return 1
    sudo apt autoremove -y             || true
    log "Netdata APT package removed."
  else
    log "No APT package found."
  fi
}

remove_configs() {
  # In CI mode: always remove without prompting
  if [[ "${CI_MODE}" == "true" ]]; then
    log "CI mode: removing Netdata directories automatically..."
    _do_remove_dirs
    return 0
  fi

  # Interactive mode: ask user
  echo
  read -r -p "Remove Netdata config/cache/library/log directories? Type YES to continue: " answer
  if [[ "${answer}" == "YES" ]]; then
    _do_remove_dirs
  else
    log "Skipping directory removal."
  fi
}

_do_remove_dirs() {
  local dirs=(/etc/netdata /var/lib/netdata /var/cache/netdata /var/log/netdata /opt/netdata)
  for d in "${dirs[@]}"; do
    if [[ -d "$d" ]]; then
      sudo rm -rf "$d"
      log "Removed: $d"
    fi
  done
}

verify_cleanup() {
  log "Verifying cleanup..."

  if systemctl list-unit-files 2>/dev/null | grep -q '^netdata.service'; then
    err "netdata.service still exists."
  else
    log "netdata.service: not found. OK"
  fi

  if command -v curl >/dev/null 2>&1; then
    if curl -fsS "http://localhost:19999/api/v1/info" >/dev/null 2>&1; then
      err "Netdata API still responding on port 19999."
    else
      log "Netdata API: not responding. OK"
    fi
  fi

  log "Cleanup check completed."
}

main() {
  stop_netdata
  uninstall_netdata
  remove_configs
  verify_cleanup

  echo
  echo "=========================================="
  echo "Netdata cleanup completed."
  echo "=========================================="
}

main "$@"
