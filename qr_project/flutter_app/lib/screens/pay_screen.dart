import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

/// Hiện mã VietQR (chuỗi payload do server tạo, vẽ QR ngay trên máy).
class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  PayInfo? _info;
  String? _error;

  @override
  void initState() {
    super.initState();
    Api.pay().then((v) {
      if (mounted) setState(() => _info = v);
    }).catchError((e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _paid() async {
    try {
      await Api.call('pay');
      if (mounted) _toast('Đã báo nhân viên, vui lòng đợi xác nhận!');
    } catch (e) {
      if (mounted) _toast('Lỗi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _info;
    return Scaffold(
      appBar: const AppHeader(label: 'THANH TOÁN'),
      body: _error != null
          ? Center(child: Text(_error!))
          : p == null
              ? const Center(child: CircularProgressIndicator())
              : p.total == 0
                  ? const Center(child: Text('Bàn chưa có khoản cần thanh toán.'))
                  : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [C.primary, C.primaryDark]),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(children: [
                          const Text('Số tiền cần thanh toán',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(vnd(p.total),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          const Text('Mở app ngân hàng → quét mã VietQR',
                              style: TextStyle(color: Colors.white70)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      SoftCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(children: [
                          QrImageView(
                              data: p.payload,
                              size: 250,
                              backgroundColor: Colors.white),
                          const SizedBox(height: 12),
                          Text('${p.bank} · ${p.account}',
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(p.holder,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)),
                        ]),
                      ),
                      FilledButton.icon(
                          onPressed: _paid,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Tôi đã chuyển khoản')),
                      const SizedBox(height: 10),
                      const Center(
                          child: Text('Hoặc gọi nhân viên để trả tiền mặt.',
                              style: TextStyle(color: C.muted))),
                    ]),
    );
  }
}
