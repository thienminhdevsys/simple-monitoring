#!/usr/bin/env bash
# =============================================================
# register-runner.sh
# Đăng ký GitHub Actions self-hosted runner trên Ubuntu Server
#
# Cách dùng:
#   export GITHUB_REPO="your-username/simple-monitoring"
#   export GITHUB_TOKEN="your_registration_token"
#   bash register-runner.sh
#
# Lấy GITHUB_TOKEN tại:
#   GitHub repo → Settings → Actions → Runners → New self-hosted runner
# =============================================================

set -euo pipefail

RUNNER_VERSION="2.317.0"
RUNNER_DIR="$HOME/actions-runner"
RUNNER_ARCH="linux-x64"

log()  { echo "[INFO]  $*"; }
err()  { echo "[ERROR] $*" >&2; exit 1; }

# --- Kiểm tra biến môi trường bắt buộc ---
[[ -z "${GITHUB_REPO:-}" ]]  && err "Thiếu GITHUB_REPO. VD: export GITHUB_REPO=username/repo"
[[ -z "${GITHUB_TOKEN:-}" ]] && err "Thiếu GITHUB_TOKEN. Lấy từ GitHub repo Settings → Actions → Runners"

# --- Tải runner ---
log "Tạo thư mục runner: $RUNNER_DIR"
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

TARBALL="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${TARBALL}"

if [[ ! -f "$TARBALL" ]]; then
  log "Đang tải GitHub Actions Runner v${RUNNER_VERSION}..."
  curl -fsSL -o "$TARBALL" "$DOWNLOAD_URL"
else
  log "Runner tarball đã tồn tại, bỏ qua tải."
fi

log "Giải nén runner..."
tar xzf "$TARBALL"

# --- Cài dependencies hệ thống ---
log "Cài system dependencies..."
sudo ./bin/installdependencies.sh

# --- Đăng ký runner với GitHub ---
log "Đăng ký runner với repo: https://github.com/${GITHUB_REPO}"
./config.sh \
  --url "https://github.com/${GITHUB_REPO}" \
  --token "${GITHUB_TOKEN}" \
  --name "$(hostname)-runner" \
  --labels "self-hosted,ubuntu,netdata" \
  --work "_work" \
  --unattended    # Không hỏi input, tự dùng defaults

# --- Cài runner thành systemd service ---
log "Cài runner thành systemd service (tự khởi động cùng server)..."
sudo ./svc.sh install
sudo ./svc.sh start

log "Kiểm tra trạng thái service..."
sudo ./svc.sh status

echo
echo "=============================================="
echo "✅ GitHub Actions Runner đã đăng ký thành công"
echo ""
echo "Kiểm tra tại:"
echo "  https://github.com/${GITHUB_REPO}/settings/actions/runners"
echo ""
echo "Quản lý service:"
echo "  sudo $RUNNER_DIR/svc.sh status"
echo "  sudo $RUNNER_DIR/svc.sh stop"
echo "  sudo $RUNNER_DIR/svc.sh start"
echo "=============================================="
