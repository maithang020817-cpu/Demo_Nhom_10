import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../theme.dart';
import 'staff_web_screen.dart';

/// Dang nhap cho Admin / Nhan vien / Bep.
/// Dang nhap bang server (POST /login) roi mo trang quan ly tuong ung trong WebView.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _srv = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServer();
  }

  @override
  void dispose() {
    _srv.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _loadServer() async {
    var s = Session.server;
    if (s.isEmpty) {
      final p = await SharedPreferences.getInstance();
      s = p.getString('login_server') ?? '';
    }
    if (mounted) setState(() => _srv.text = s);
  }

  String _normServer(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      final isLan = RegExp(r'^(localhost|[\d.]+)(:\d+)?(/|$)').hasMatch(s);
      s = (isLan ? 'http://' : 'https://') + s;
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  String _roleTitle(String path) {
    if (path.startsWith('/admin')) return 'Quản trị';
    if (path.startsWith('/kitchen')) return 'Bếp';
    if (path.startsWith('/staff')) return 'Nhân viên';
    return 'Quản lý';
  }

  Future<void> _login() async {
    final srv = _normServer(_srv.text);
    if (srv.isEmpty || _user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Nhập đủ địa chỉ server, tên đăng nhập và mật khẩu.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = http.Client();
    try {
      final req = http.Request('POST', Uri.parse('$srv/login'))
        ..followRedirects = false
        ..bodyFields = {
          'username': _user.text.trim(),
          'password': _pass.text,
        };
      final res = await client.send(req).timeout(const Duration(seconds: 12));
      final ok = res.statusCode >= 300 && res.statusCode < 400;
      if (!ok) {
        setState(() => _error = 'Sai tên đăng nhập hoặc mật khẩu.');
        return;
      }
      final cm = RegExp(r'^\s*([^=;\s]+)=([^;]*)')
          .firstMatch(res.headers['set-cookie'] ?? '');
      if (cm == null) {
        setState(() => _error = 'Server không trả về phiên đăng nhập.');
        return;
      }
      final target = Uri.parse(srv).resolve(res.headers['location'] ?? '/');
      final p = await SharedPreferences.getInstance();
      await p.setString('login_server', srv);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffWebScreen(
            url: target.toString(),
            host: Uri.parse(srv).host,
            cookieName: cm.group(1)!,
            cookieValue: cm.group(2)!,
            title: _roleTitle(target.path),
          ),
        ),
      );
      if (mounted) _pass.clear();
    } catch (e) {
      setState(() => _error =
          'Không kết nối được tới $srv\nKiểm tra server đang chạy và cùng WiFi/Internet.');
    } finally {
      client.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập nhân viên')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.badge_outlined, size: 56, color: C.primary),
                const SizedBox(height: 8),
                const Text('Admin · Nhân viên · Bếp',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(
                  controller: _srv,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ server',
                    hintText: 'http://192.168.1.5:5000',
                    prefixIcon: Icon(Icons.dns_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _user,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: 'Tên đăng nhập',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  onSubmitted: (_) => _loading ? null : _login(),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Đăng nhập'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: C.red)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
