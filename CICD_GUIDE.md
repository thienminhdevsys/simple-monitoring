# 🤖 CI/CD với GitHub Actions Self-Hosted Runner

Phần này hướng dẫn tự động hóa việc deploy Netdata bằng GitHub Actions, chạy trực tiếp trên Ubuntu Server của bạn.

---

## 🏗️ Kiến trúc tổng quan

```
┌──────────────────────────────────────────────────────┐
│                     GitHub                           │
│                                                      │
│   git push main  ──►  GitHub Actions Workflow        │
│                            │                         │
│                     gửi job qua HTTPS                │
└────────────────────────────┼─────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────┐
│              Ubuntu Server của bạn                   │
│                                                      │
│   actions-runner (systemd service)                   │
│        │                                             │
│        ├──► bash setup.sh        (cài Netdata)       │
│        ├──► bash test_dashboard.sh (verify)          │
│        └──► Netdata dashboard :19999                 │
└──────────────────────────────────────────────────────┘
```

> **Tại sao self-hosted thay vì GitHub-hosted runner?**
> GitHub-hosted runner là máy ảo tạm thời — Netdata cài xong thì máy bị xóa, không dùng được. Self-hosted runner chạy trên server thật của bạn, Netdata cài lên và chạy luôn.

---

## 📁 Cấu trúc file CI/CD

```
simple-monitoring/
├── .github/
│   └── workflows/
│       └── deploy-monitoring.yml   # Workflow chính
├── register-runner.sh              # Đăng ký runner (chạy 1 lần)
├── unregister-runner.sh            # Gỡ runner (khi không cần)
├── setup.sh
├── cleanup.sh
└── test_dashboard.sh
```

---

## 🚀 Hướng dẫn setup từ đầu đến cuối

### Bước 1: Lấy Registration Token từ GitHub

1. Vào GitHub repo của bạn
2. **Settings** → **Actions** → **Runners**
3. Click **"New self-hosted runner"**
4. Chọn **Linux / x64**
5. GitHub hiển thị token dạng: `AXXXXXXXXXXXXXXXXXXXXXXXXX`

> **Token này chỉ có hiệu lực 1 giờ** — lấy xong phải dùng ngay.

---

### Bước 2: Đăng ký runner trên Ubuntu Server

SSH vào server, rồi chạy:

```bash
# Clone repo về server (nếu chưa có)
git clone https://github.com/<username>/simple-monitoring.git
cd simple-monitoring

# Cấp quyền thực thi
chmod +x register-runner.sh unregister-runner.sh

# Set biến môi trường
export GITHUB_REPO="your-username/simple-monitoring"
export GITHUB_TOKEN="AXXXXXXXXXXXXXXXXXXXXXXXXX"   # token từ bước 1

# Chạy đăng ký
bash register-runner.sh
```

Script sẽ tự động:
- Tải GitHub Actions Runner binary
- Cài system dependencies
- Đăng ký runner với label `self-hosted,ubuntu,netdata`
- Cài runner thành **systemd service** (tự chạy khi reboot)

Sau khi chạy xong, kiểm tra trên GitHub: **Settings → Actions → Runners** — runner sẽ hiện trạng thái **Idle** (màu xanh).

---

### Bước 3: Kích hoạt workflow

Sau khi runner đăng ký thành công, chỉ cần:

```bash
git add .
git commit -m "Add CI/CD workflow"
git push origin main
```

GitHub Actions sẽ tự động:
1. Nhận event `push` trên branch `main`
2. Gửi job xuống self-hosted runner của bạn
3. Runner chạy `setup.sh` → `test_dashboard.sh`
4. Hiển thị kết quả và URL dashboard trong tab **Summary**

---

### Bước 4: Xem kết quả

Vào **GitHub repo → Actions** → click vào workflow run mới nhất.

Mỗi step hiển thị log chi tiết. Tab **Summary** cuối workflow sẽ hiện:

| | URL |
|---|---|
| 🖥️ Local | http://localhost:19999 |
| 🌐 Network | http://192.168.x.x:19999 |

---

## 🔐 Bảo mật: Environment Protection cho Teardown

Workflow có job `teardown` (cleanup Netdata) chỉ chạy khi trigger thủ công. Để tránh vô tình xóa, nên bật **Environment Protection**:

1. GitHub repo → **Settings** → **Environments**
2. Click **New environment** → đặt tên `production`
3. Bật **Required reviewers** → thêm tên bạn
4. Từ nay, mỗi khi teardown chạy, GitHub sẽ yêu cầu bạn approve trước

> **Tại sao cần approval?** Cleanup xóa toàn bộ Netdata và data. Trong môi trường thật, bảo vệ bằng approval ngăn chặn accident hoặc pipeline bị tấn công.

---

## ⚙️ Quản lý Runner Service

```bash
# Xem trạng thái
sudo ~/actions-runner/svc.sh status

# Dừng runner
sudo ~/actions-runner/svc.sh stop

# Khởi động lại
sudo ~/actions-runner/svc.sh start

# Xem log real-time
sudo journalctl -u actions.runner.*.service -f
```

---

## 🧹 Gỡ Runner khi không cần

1. Lấy **removal token**: GitHub → Settings → Actions → Runners → click runner → **Remove** → copy token

```bash
export GITHUB_TOKEN="removal-token-here"
bash unregister-runner.sh
```

---

## 🧠 Kiến thức CI/CD ghi nhớ

| Khái niệm | Giải thích |
|---|---|
| `runs-on: self-hosted` | Chỉ định job chạy trên runner do bạn quản lý |
| `workflow_dispatch` | Cho phép trigger workflow thủ công từ GitHub UI |
| `needs: deploy` | Job teardown chỉ chạy sau khi deploy thành công |
| `environment: production` | Áp dụng protection rules (approval, secrets) |
| `$GITHUB_STEP_SUMMARY` | File đặc biệt — nội dung hiện trong tab Summary |
| Runner là systemd service | Tự khởi động cùng server, không cần can thiệp thủ công |
| Token chỉ dùng 1 lần | Registration token hết hạn sau 1h và chỉ dùng để đăng ký |
