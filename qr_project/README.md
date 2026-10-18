# Gọi món tại bàn bằng QR — Python (Flask + Kivy)

```
qr_project/
├── server/       Web + API (Flask, SQLite)  -> chạy trên máy tính của quán
├── flutter_app/  App Android (Flutter)      -> CHÍNH, có quét QR camera
└── android_app/  App Android (Kivy/Python)  -> bản thay thế
```

## 1. Chạy server
    cd server
    pip install -r requirements.txt
    python app.py
- Mở http://localhost:5000  (khách) và http://localhost:5000/admin (nhân viên, không cần đăng nhập)
- Chỉ cùng WiFi: dùng IP LAN. Muốn mạng nào cũng quét được: xem mục "Chạy qua Internet" bên dưới. Nếu quét QR không vào được: tắt/cho phép Python qua Windows Firewall.
- Nếu đã dùng bản cũ: file dữ liệu mới là `restaurant.db` (bản cũ `orders.db` không dùng nữa).

## Chạy qua Internet (điện thoại/4G/WiFi nào quét QR cũng vào được)
Trước đây QR chứa IP mạng LAN (vd `192.168.1.5`) nên chỉ máy cùng WiFi mới vào. Giờ QR dùng **địa chỉ Internet** của server. Có 2 cách:

**Cách A — Chạy thử nhanh, miễn phí (máy tính của quán vẫn là server)**
1. Chạy server: `python app.py`
2. Mở cửa sổ khác, tạo đường hầm công khai (chọn 1 trong 2):
   - Cloudflare: tải `cloudflared` rồi chạy `cloudflared tunnel --url http://localhost:5000` → hiện link dạng `https://xxxx.trycloudflare.com`
   - ngrok: `ngrok http 5000` → hiện link `https://xxxx.ngrok-free.app`
3. **Mở `https://xxxx.trycloudflare.com/qr` bằng chính link đó** (không mở bằng localhost) → mã QR sẽ chứa link Internet → bấm In.
   (Hoặc đặt cố định: `set PUBLIC_URL=https://xxxx.trycloudflare.com` rồi chạy `python app.py`.)
> Link miễn phí đổi mỗi lần chạy lại → phải in lại QR. Muốn QR dùng lâu dài thì dùng cách B.

**Cách B — Triển khai lên hosting (QR cố định, chạy 24/7)**
Ví dụ Render / Railway / VPS:
- Start command: `gunicorn app:app --bind 0.0.0.0:$PORT --workers 1 --threads 4` (đã có `Procfile`)
- Biến môi trường: `PUBLIC_URL=https://ten-quan.onrender.com`, `SECRET_KEY=<chuỗi bí mật>`
- Gắn ổ đĩa lưu trữ (persistent disk) vào `/data` và đặt `DATA_DIR=/data`, `UPLOAD_DIR=/data/uploads` để không mất đơn hàng/ảnh khi server khởi động lại.
- ⚠️ Trang `/admin` không có mật khẩu → khi để công khai trên Internet nên đặt mật khẩu/giới hạn truy cập trước khi dùng thật.

**App Flutter/Kivy:** quét QR là nhận link `https://...` nên cũng dùng được qua 4G; ô "địa chỉ server" nhập link Internet thay vì `192.168...`.

## Phân quyền & tài khoản
Khách **không cần đăng nhập** (quét QR → chọn món → gửi đơn → xem đơn/thanh toán/đánh giá). Nhân viên vào `/login`:

| Vai trò | Được làm |
|---|---|
| Khách | Quét QR, chọn món, gửi đơn, xem đơn, thanh toán VietQR, gọi nhân viên, đánh giá |
| Nhân viên (`/staff`) | Xem đơn khách gọi (có âm báo), gọi món giúp khách, xem/in hóa đơn, xác nhận đã thanh toán |
| Bếp (`/kitchen`) | Xem món cần làm, bấm "Nhận làm" và "✅ Đã lên món" |
| Admin | Tất cả + **hủy đơn**, thêm/sửa/xóa món, chi nhánh, tạo/xóa tài khoản, báo cáo, in QR |

Tài khoản mặc định (tạo ở lần chạy đầu): `admin/admin123`, `nhanvien/nv123`, `bep/bep123`.
**Vào Admin → Tài khoản để đổi mật khẩu ngay** trước khi để server công khai trên Internet.
Nhân viên/Bếp được gán 1 chi nhánh và chỉ thấy chi nhánh đó. Khóa phiên đăng nhập tự sinh trong `server/.secret_key` (hoặc đặt biến `SECRET_KEY`).

## 2. Chức năng
| Nhóm | Chức năng |
|---|---|
| Nhiều chi nhánh | Mỗi chi nhánh có thực đơn, số bàn, đơn hàng, tài khoản ngân hàng riêng; chuyển chi nhánh ở thanh menu; thêm chi nhánh mới (tự sao chép thực đơn); thống kê toàn chuỗi |
| VietQR | Tạo mã VietQR theo chuẩn NAPAS/EMVCo (đúng số tiền + nội dung "Ban x CNy"), quét bằng mọi app ngân hàng; khách bấm "Đã chuyển khoản" → bếp/thu ngân nhận thông báo |
| Đánh giá | Khi món "Đã phục vụ", khách chấm 1–5 sao + nhận xét; thực đơn hiện điểm TB; trang quản lý xem điểm từng món và nhận xét |
| App Android | Kết nối server qua API JSON: xem menu, đặt món, theo dõi đơn, hủy đơn, đánh giá, gọi nhân viên, thanh toán VietQR |
| Khác | Tìm món, giỏ hàng lưu lại, hủy đơn, gọi nhân viên, bếp có âm báo, quản lý thực đơn, in hóa đơn, doanh thu 7 ngày, món bán chạy |

**Đổi tài khoản nhận tiền:** vào "Chi nhánh" → nhập ngân hàng, số TK, tên chủ TK thật.

## 3. Chạy app Kivy
    cd android_app
    pip install -r requirements.txt
    python main.py
Nhập địa chỉ server (vd `http://192.168.1.5:5000`), chi nhánh, số bàn — hoặc dán link của mã QR bàn.
(Server in sẵn địa chỉ IP khi khởi động.)

## 4. Đóng gói APK (Linux / WSL / Google Colab)
    pip install buildozer
    cd android_app
    buildozer android debug
APK nằm trong thư mục `bin/`. Lần build đầu mất 20–40 phút (tải SDK/NDK).
Server dùng HTTP (không phải HTTPS) nên `buildozer.spec` đã bật `usesCleartextTraffic`.

## 5. Sơ đồ API (cho báo cáo)
    GET  /api/branches
    GET  /api/b/<chi_nhanh>/menu
    POST /api/order            {branch, table, items:[{id,qty}], note}
    GET  /api/order/<id>
    POST /api/order/<id>/cancel   (chỉ admin, cần đăng nhập)
    POST /api/call             {branch, table, kind: staff|pay}
    POST /api/rating           {order_id, ratings:[{name,stars}], comment}
    GET  /api/b/<chi_nhanh>/table/<ban>/pay   -> {total, payload VietQR, ...}

## Tự thêm thực đơn, nhóm món, hình ảnh
Đăng nhập → **Thực đơn**:
- **Xóa hết món mẫu** rồi thêm món của quán.
- Mỗi món: tên, giá, nhóm (gõ tên nhóm mới là tự tạo nhóm), hình (.jpg/.png/.webp, ≤ 6MB) hoặc emoji.
- Đổi hình, xóa hình, đánh dấu hết món, xóa món ngay trên từng món.
- Ảnh lưu trong `server/static/uploads/`, hiển thị ở web và app Flutter/Kivy.
- Mỗi chi nhánh có thực đơn riêng; thêm chi nhánh mới sẽ sao chép thực đơn đang chọn.
