# 🖥️ Simple Server Monitoring with Netdata

Dự án này thiết lập **Netdata** — một công cụ monitoring real-time mạnh mẽ — trên Ubuntu Server, kèm script tự động hóa toàn bộ quy trình: cài đặt, kiểm thử, và gỡ cài đặt.

> **Mục tiêu học thuật:** Nắm vững cách deploy monitoring stack từ đầu, hiểu từng bước WHY chứ không chỉ HOW.

---
Link mô tả project: https://roadmap.sh/projects/simple-monitoring-dashboard
## 📸 Kết quả thực tế

Dashboard Netdata sau khi cài đặt thành công — hiển thị CPU, RAM, Disk I/O, Network real-time:

![Netdata Dashboard](./screenshot.png)

---

## 📁 Cấu trúc dự án

```
simple-monitoring/
├── setup.sh           # Cài đặt Netdata tự động
├── cleanup.sh         # Gỡ cài đặt hoàn toàn
├── test_dashboard.sh  # Tạo tải giả lập & kiểm tra metrics
└── README.md
```

---

## ⚙️ Yêu cầu hệ thống

| Yêu cầu | Chi tiết |
|---|---|
| OS | Ubuntu 20.04+ / Debian 11+ / RHEL 8+ |
| RAM | Tối thiểu 512MB (khuyến nghị 1GB+) |
| Disk | ~300MB cho Netdata |
| Network | Có kết nối internet để tải installer |
| Quyền | User có `sudo` |

---

## 🚀 Hướng dẫn từ đầu đến cuối

### Bước 1: Chuẩn bị Ubuntu Server

Nếu bạn dùng máy ảo (VirtualBox/VMware/cloud VM), đảm bảo:

```bash
# Cập nhật hệ thống trước tiên
sudo apt update && sudo apt upgrade -y

# Kiểm tra IP của server (dùng để truy cập dashboard từ máy khác)
hostname -I
```

> **Tại sao phải update trước?** Tránh conflict giữa package cũ và dependency mới của Netdata. Đây là best practice khi cài bất kỳ phần mềm nào trên Linux.

---

### Bước 2: Clone repository

```bash
git clone https://github.com/<your-username>/simple-monitoring.git
cd simple-monitoring
```

---

### Bước 3: Cấp quyền thực thi cho các script

```bash
chmod +x setup.sh cleanup.sh test_dashboard.sh
```

> **Tại sao?** Trên Linux, file mới clone về không có execute permission mặc định — đây là cơ chế bảo mật của hệ thống file. Bạn phải cấp quyền tường minh.

---

### Bước 4: Chạy script cài đặt

```bash
./setup.sh
```

Script sẽ tự động thực hiện theo thứ tự:

1. **Kiểm tra OS** — xác định Ubuntu/Debian hay RHEL/Fedora để dùng đúng package manager
2. **Kiểm tra sudo** — đảm bảo bạn có quyền cài đặt
3. **Cài dependencies** — `curl`, `ca-certificates`
4. **Download & chạy Netdata kickstart** — script chính thức từ Netdata Cloud
5. **Enable & start service** — dùng `systemctl` để Netdata tự khởi động cùng server
6. **Kiểm tra API** — retry tối đa 30 lần (60 giây) để đợi service sẵn sàng
7. **In URL dashboard** — hiển thị địa chỉ truy cập

Output mẫu khi thành công:

```
==========================================
Netdata installation completed successfully
Local dashboard:
  http://localhost:19999

Network dashboard:
  http://192.168.1.x:19999
==========================================
```

> **Tại sao dùng kickstart script của Netdata?** Netdata có nhiều phiên bản (stable, nightly) và cấu hình phức tạp. Kickstart script chính thức xử lý tất cả edge case, đảm bảo cài đúng version ổn định nhất cho hệ điều hành của bạn.

---

### Bước 5: Truy cập Dashboard

Mở trình duyệt và truy cập:

- **Từ chính server:** `http://localhost:19999`
- **Từ máy khác trong mạng:** `http://<IP-server>:19999`

Bạn sẽ thấy dashboard real-time với các metrics:
- **CPU** usage theo từng core
- **RAM** usage và swap
- **Disk I/O** đọc/ghi
- **Network** inbound/outbound
- **System load** (1/5/15 phút)

---

### Bước 6: Kiểm thử dashboard (tuỳ chọn)

Để xem dashboard "sống" với dữ liệu thực, chạy script kiểm thử:

```bash
./test_dashboard.sh
```

Script sẽ:
1. **Tạo CPU load** trong 60 giây (dùng `stress`) — bạn sẽ thấy đường CPU tăng đột biến trên dashboard
2. **Tạo Disk I/O** — ghi file 512MB rồi xóa, tạo spike trên biểu đồ disk
3. **Verify metrics API** — kiểm tra 4 chart cơ bản: `system.cpu`, `system.ram`, `system.load`, `disk_space./`
4. **Hiển thị active alerts** — WARNING/CRITICAL nếu có

> **Tại sao cần test bằng tải giả lập?** Một dashboard đẹp nhưng không phản ánh đúng thực tế là vô nghĩa. Bằng cách tạo tải có chủ đích, bạn xác nhận Netdata thực sự đang capture dữ liệu chính xác — không phải chỉ hiển thị số đứng yên.

---

### Bước 7: Gỡ cài đặt (khi cần)

```bash
./cleanup.sh
```

Script sẽ hỏi xác nhận trước mỗi bước nguy hiểm:

```
This will stop and remove Netdata from this server. Type YES to continue:
```

Quá trình dọn dẹp:
1. **Dừng và disable service** — `systemctl stop` + `systemctl disable`
2. **Xóa package** — `apt remove --purge` + `apt autoremove`
3. **Xóa thư mục còn lại** — `/etc/netdata`, `/var/lib/netdata`, `/var/cache/netdata`, `/var/log/netdata`
4. **Verify** — kiểm tra service, package, binary, port đã thực sự sạch

> **Tại sao cần cleanup script riêng?** `apt remove` đơn thuần không xóa config files và data. Nếu reinstall sau đó, Netdata sẽ dùng lại config cũ — có thể gây lỗi khó debug. `--purge` và xóa thủ công các thư mục đảm bảo clean slate hoàn toàn.

---

## 🔍 Giải thích kỹ thuật quan trọng

### Tại sao port 19999?

Đây là port mặc định của Netdata. Nếu server của bạn có firewall (`ufw`), cần mở port này để truy cập từ xa:

```bash
sudo ufw allow 19999/tcp
sudo ufw status
```

### Tại sao dùng `systemctl enable --now`?

- `enable`: Tạo symlink để service tự khởi động khi server reboot
- `--now`: Đồng thời start service ngay lập tức

Thiếu `enable`, sau khi reboot bạn phải start Netdata thủ công mỗi lần — không phù hợp production.

### Tại sao verify API thay vì chỉ check service status?

`systemctl is-active netdata` chỉ cho biết process đang chạy. Nhưng service có thể đang trong quá trình khởi tạo và chưa sẵn sàng nhận request. Gọi API `/api/v1/info` mới xác nhận Netdata thực sự ready để phục vụ.

### Idempotency của setup.sh

Script kiểm tra `systemctl list-unit-files | grep -q '^netdata.service'` trước khi cài. Nếu Netdata đã tồn tại, bỏ qua bước cài đặt. Điều này đảm bảo chạy script nhiều lần không gây lỗi — một tính chất quan trọng của DevOps scripts.

---

## 🐛 Xử lý lỗi thường gặp

**Lỗi: "Netdata API did not respond on port 19999"**
```bash
# Kiểm tra service log
sudo journalctl -u netdata -n 50
# Kiểm tra port
sudo ss -lntp | grep 19999
```

**Lỗi: "This script was tested mainly on Ubuntu/Debian/RHEL-like systems"**

Script chỉ hỗ trợ các distro phổ biến. Trên Arch/Alpine cần cài Netdata thủ công theo tài liệu chính thức.

**Dashboard không truy cập được từ máy khác**
```bash
# Kiểm tra firewall
sudo ufw status
sudo ufw allow 19999/tcp
```

---

## 📚 Tài nguyên tham khảo

- [Netdata Official Documentation](https://learn.netdata.cloud)
- [Netdata GitHub](https://github.com/netdata/netdata)
- [Netdata API Reference](https://learn.netdata.cloud/docs/agent/web/api)

---

## 🧠 Kiến thức ghi nhớ cho setup sau

| Kiến thức | Áp dụng |
|---|---|
| Luôn `set -euo pipefail` trong bash script | Thoát ngay khi có lỗi, tránh silent failures |
| Dùng `systemctl enable --now` | Enable + start trong 1 lệnh |
| Verify bằng API call, không chỉ process status | Đảm bảo service thực sự ready |
| `apt remove --purge` + xóa `/var/lib`, `/etc` | Clean uninstall, không còn dư thừa |
| Retry loop khi chờ service khởi động | Service cần thời gian init, không check 1 lần duy nhất |
| Kiểm tra idempotency | Script chạy nhiều lần vẫn an toàn |
| `hostname -I \| awk '{print $1}'` | Lấy IP đầu tiên của server |
