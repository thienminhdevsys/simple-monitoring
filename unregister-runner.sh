#!/usr/bin/env bash
# =============================================================
# unregister-runner.sh
# Gỡ GitHub Actions self-hosted runner khỏi Ubuntu Server
#
# Cách dùng:
#   export GITHUB_TOKEN="your_remove_token"
#   bash unregister-runner.sh
#
# Lấy GITHUB_TOKEN (removal token) tại:
#   GitHub repo → Settings → Actions → Runners → click runner → Remove
# =============================================================

set -euo pipefail

RUNNER_DIR="$HOME/actions-runner"

log() { echo "[INFO]  $*"; }
err() { echo "[ERROR] $*" >&2; exit 1; }

[[ -z "${GITHUB_TOKEN:-}" ]] && err "Thiếu GITHUB_TOKEN (removal token)."
[[ ! -d "$RUNNER_DIR" ]]    && err "Không tìm thấy thư mục runner: $RUNNER_DIR"

cd "$RUNNER_DIR"

log "Dừng và gỡ systemd service..."
sudo ./svc.sh stop   || true
sudo ./svc.sh uninstall || true

log "Hủy đăng ký runner với GitHub..."
./config.sh remove --token "${GITHUB_TOKEN}"

log "Xóa thư mục runner..."
cd "$HOME"
rm -rf "$RUNNER_DIR"

echo
echo "=============================================="
echo "✅ Runner đã được gỡ hoàn toàn"
echo "=============================================="
