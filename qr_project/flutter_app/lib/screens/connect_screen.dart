import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import 'menu_screen.dart';
import 'login_screen.dart';
import 'scan_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  String _srv = '';
  int _branchNo = 1;
  int _tableNo = 1;
  bool _loading = false;
  String? _error;

  /// Nhan link dang http://ip:5000/b/1/table/3
  bool _parseLink(String text) {
    final m = RegExp(r'(https?://[^/\s]+)/b/(\d+)/table/(\d+)').firstMatch(text);
    if (m == null) return false;
    _srv = m.group(1)!;
    _branchNo = int.parse(m.group(2)!);
    _tableNo = int.parse(m.group(3)!);
    return true;
  }

  Future<void> _scan() async {
    final result = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (result == null || !mounted) return;
    if (_parseLink(result)) {
      _connect();
    } else {
      setState(() => _error = 'Mã QR này không phải mã của quán.');
    }
  }

  Future<void> _connect() async {
    var srv = _srv.trim();
    while (srv.endsWith('/')) {
      srv = srv.substring(0, srv.length - 1);
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await Api.reachable(srv, _branchNo)) {
        setState(() => _error =
            'Không kết nối được tới $srv\nKiểm tra mạng, hoặc nhờ nhân viên in lại mã QR mới.');
        return;
      }
      Session.setTarget(srv, _branchNo, _tableNo);
      await Api.menu(); // tai thuc don
      if (!mounted) return;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const MenuScreen()));
    } catch (e) {
      setState(() => _error = 'Lỗi khi tải thực đơn: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [C.primary, C.primaryDark]),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.18),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.ramen_dining,
                      color: Colors.white, size: 34),
                ),
                const SizedBox(height: 14),
                const Text('Savor Dine',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Quét mã QR trên bàn để gọi món',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: C.primary),
                  onPressed: _loading ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Quét mã QR trên bàn'),
                ),
                const SizedBox(height: 14),
                const Row(children: [
                  Expanded(child: Divider(color: Colors.white38)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('hoặc',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: Colors.white38)),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70)),
                    onPressed: _loading
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen())),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Đăng nhập (Admin · Nhân viên · Bếp)'),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 22),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: const TextStyle(color: C.red)),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
