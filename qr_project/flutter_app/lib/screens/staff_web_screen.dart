import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Mo trang quan ly (admin / nhan vien / bep) cua server bang WebView,
/// da dang nhap san bang cookie phien.
class StaffWebScreen extends StatefulWidget {
  final String url, host, cookieName, cookieValue, title;
  const StaffWebScreen({
    super.key,
    required this.url,
    required this.host,
    required this.cookieName,
    required this.cookieValue,
    required this.title,
  });

  @override
  State<StaffWebScreen> createState() => _StaffWebScreenState();
}

class _StaffWebScreenState extends State<StaffWebScreen> {
  final _cookies = WebViewCookieManager();
  WebViewController? _c;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _cookies.clearCookies();
    await _cookies.setCookie(WebViewCookie(
      name: widget.cookieName,
      value: widget.cookieValue,
      domain: widget.host,
      path: '/',
    ));
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
    if (mounted) setState(() => _c = c);
  }

  @override
  void dispose() {
    _cookies.clearCookies(); // roi man hinh = dang xuat
    super.dispose();
  }

  Future<void> _logout() async {
    await _cookies.clearCookies();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (c != null && await c.canGoBack()) {
          await c.goBack();
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              icon: const Icon(Icons.refresh),
              onPressed: () => c?.reload(),
            ),
            IconButton(
              tooltip: 'Đăng xuất',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
        ),
        body: c == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(child: WebViewWidget(controller: c)),
      ),
    );
  }
}
