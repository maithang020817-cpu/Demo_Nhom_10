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
  final _linkCtl =
  TextEditingController(text: 'http://10.0.2.2:5000/b/1/table/1');

  @override
  void dispose() {
    _linkCtl.dispose();
    super.dispose();
  }

  void _manual() {
    if (_parseLink(_linkCtl.text)) {
      _connect();
    } else {
      setState(() => _error =
      'Link không đúng dạng. Ví dụ: http://10.0.2.2:5000/b/1/table/1');
    }
  }

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
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ===== Banner =====
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, top + 48, 24, 64),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF333333), Color(0xFF161616)],
                ),
                borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(.4), width: 2),
                    ),
                    child: const Icon(Icons.ramen_dining,
                        color: C.primary, size: 44),
                  ),
                  const SizedBox(height: 18),
                  const Text('Savor Dine',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5)),
                  const SizedBox(height: 6),
                  const Text('Gọi món nhanh ngay tại bàn',
                      style: TextStyle(color: Colors.white70, fontSize: 15)),
                ],
              ),
            ),

            // ===== The noi =====
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text('Chào mừng bạn!',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      const Text('Quét mã QR trên bàn để xem thực đơn',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: C.muted)),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _loading ? null : _scan,
                        icon: const Icon(Icons.qr_code_scanner, size: 24),
                        label: const Text('Quét mã QR trên bàn'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _linkCtl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          hintText: 'Dán link bàn vào đây',
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _manual,
                        icon: const Icon(Icons.login),
                        label: const Text('Kết nối bằng link'),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          _Step(icon: Icons.qr_code_2, label: 'Quét QR'),
                          _Arrow(),
                          _Step(icon: Icons.restaurant_menu, label: 'Chọn món'),
                          _Arrow(),
                          _Step(icon: Icons.send_rounded, label: 'Gửi bếp'),
                        ],
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 22),
                          child: CircularProgressIndicator(),
                        ),
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: C.red.withOpacity(.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: C.red.withOpacity(.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: C.red, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: C.red, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ===== Dang nhap nhan vien =====
            TextButton.icon(
              onPressed: _loading
                  ? null
                  : () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: const Text('Đăng nhập (Admin · Nhân viên · Bếp)'),
              style: TextButton.styleFrom(foregroundColor: C.muted),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Step({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
              color: C.peachSoft, shape: BoxShape.circle),
          child: Icon(icon, color: C.primary, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Icon(Icons.chevron_right, color: C.muted, size: 20),
    );
  }
}