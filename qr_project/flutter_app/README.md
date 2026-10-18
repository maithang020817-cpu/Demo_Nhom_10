# App Flutter — Gọi món QR

Kết nối với server Flask (thư mục `../server`). Chức năng: **quét QR camera** để vào đúng chi nhánh/bàn, xem thực đơn (tìm kiếm, lọc nhóm), đặt món + ghi chú, theo dõi đơn tự cập nhật, hủy đơn, đánh giá sao, gọi nhân viên, thanh toán **VietQR**.

## Cài đặt (cần Flutter SDK + Android Studio)
    cd flutter_app
    flutter create .            # sinh thư mục android/ (giữ nguyên lib/ và pubspec.yaml)
    python setup_android.py     # bật quyền Internet, Camera, HTTP
    flutter pub get
    flutter run                 # chọn điện thoại hoặc emulator

Đóng gói APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`

## Lưu ý
- Server phải đang chạy (`python app.py` trong `../server`), điện thoại **cùng WiFi**.
- Emulator Android dùng địa chỉ `http://10.0.2.2:5000`; điện thoại thật dùng IP máy tính.
- Quét QR cần điện thoại thật (emulator không có camera thật).

## Cấu trúc code
- `lib/theme.dart` — màu/phông theo thiết kế Stitch (nâu gạch, kem đào, xanh nhạt)
- `lib/widgets.dart` — header, thẻ, bộ chỉnh số lượng dùng chung
- `lib/screens/cart_screen.dart` — giỏ hàng "Gửi trực tiếp đến bếp"
- `lib/screens/item_detail_screen.dart` — chi tiết món
- `lib/main.dart` — khởi động
- `lib/api.dart` — model + gọi REST API (http)
- `lib/screens/connect_screen.dart` — kết nối / quét QR, lưu địa chỉ (shared_preferences)
- `lib/screens/scan_screen.dart` — camera quét QR (mobile_scanner)
- `lib/screens/menu_screen.dart` — thực đơn, giỏ hàng, gửi đơn
- `lib/screens/order_screen.dart` — trạng thái đơn (Timer polling), hủy, đánh giá
- `lib/screens/pay_screen.dart` — vẽ mã VietQR (qr_flutter)
