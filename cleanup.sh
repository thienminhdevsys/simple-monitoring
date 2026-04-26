#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[INFO] $*"
}

err() {
  echo "[ERROR] $*" >&2
}

stop_netdata() {
  log "Stopping Netdata service if it exists..."

  if systemctl list-unit-files | grep -q '^netdata.service'; then
    sudo systemctl stop netdata || true
    sudo systemctl disable netdata || true
  else
    log "netdata.service not found."
  fi
}

find_uninstaller() {
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

  find / -name "netdata-uninstaller.sh" -type f -perm -u+x 2>/dev/null | head -n 1
}

uninstall_netdata() {
  local uninstaller

  uninstaller="$(find_uninstaller || true)"

  if [[ -n "${uninstaller}" ]]; then
    log "Found Netdata uninstaller: ${uninstaller}"
    log "Running uninstaller..."

    sudo "${uninstaller}" --yes || {
      err "Uninstaller failed. Try running manually:"
      err "sudo ${uninstaller}"
      exit 1
    }
  else
    err "Netdata uninstaller not found."
    err "You may need to uninstall using your package manager."
    err "Examples:"
    err "  sudo apt remove --purge netdata"
    err "  sudo dnf remove netdata"
    exit 1
  fi
}

remove_configs() {
  echo
  echo "Do you want to remove Netdata config/cache/library/log directories?"
  echo "This may delete local Netdata history and configuration."
  read -r -p "Type YES to remove them: " answer

  if [[ "${answer}" != "YES" ]]; then
    log "Skipping config/cache/library/log removal."
    return 0
  fi

  log "Removing Netdata directories..."

  sudo rm -rf /etc/netdata
  sudo rm -rf /var/lib/netdata
  sudo rm -rf /var/cache/netdata
  sudo rm -rf /var/log/netdata
  sudo rm -rf /opt/netdata

  log "Netdata directories removed."
}

verify_cleanup() {
  log "Verifying cleanup..."

  if systemctl list-unit-files | grep -q '^netdata.service'; then
    err "netdata.service still exists."
    systemctl status netdata --no-pager || true
  else
    log "netdata.service not found."
  fi

  if command -v curl >/dev/null 2>&1; then
    if curl -fsS "http://localhost:19999/api/v1/info" >/dev/null 2>&1; then
      err "Netdata API is still responding on port 19999."
    else
      log "Netdata API is not responding on port 19999."
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
