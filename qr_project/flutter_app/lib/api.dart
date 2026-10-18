import 'dart:convert';
import 'package:http/http.dart' as http;

String vnd(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${b.toString()}đ';
}

/// Trang thai dung chung giua cac man hinh.
class Session {
  static String server = '';
  static String branchName = '';
  static int branch = 1;
  static int table = 1;
  static int? orderId;
  static final Map<int, int> cart = {};

  static void setTarget(String srv, int br, int tb) {
    if (srv != server || br != branch || tb != table) {
      cart.clear();
      orderId = null;
    }
    server = srv;
    branch = br;
    table = tb;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class MenuItem {
  final int id, price;
  final String category, name, emoji;
  final bool available;
  final double? avg;
  final String? image; // duong dan anh tren server (neu co)
  MenuItem(this.id, this.price, this.category, this.name, this.emoji,
      this.available, this.avg, this.image);

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        j['id'] as int,
        j['price'] as int,
        j['category'] as String,
        j['name'] as String,
        (j['emoji'] ?? '🍽️') as String,
        j['available'] == 1,
        (j['avg'] as num?)?.toDouble(),
        j['image'] as String?,
      );
}

class MenuData {
  final String branch;
  final List<MenuItem> items;
  MenuData(this.branch, this.items);
}

class OrderLine {
  final String name;
  final int price, qty;
  OrderLine(this.name, this.price, this.qty);
}

class OrderInfo {
  final String status, statusText;
  final int total;
  final bool rated;
  final List<OrderLine> items;
  OrderInfo(this.status, this.statusText, this.total, this.rated, this.items);

  factory OrderInfo.fromJson(Map<String, dynamic> j) => OrderInfo(
        j['status'] as String,
        j['status_text'] as String,
        j['total'] as int,
        j['rated'] as bool,
        (j['items'] as List)
            .map((e) => OrderLine(e['name'] as String, e['price'] as int,
                e['qty'] as int))
            .toList(),
      );
}

class PayInfo {
  final int total;
  final String payload, holder, bank, account;
  PayInfo(this.total, this.payload, this.holder, this.bank, this.account);
}

class Api {
  static const _timeout = Duration(seconds: 10);

  static Uri _u(String path) => Uri.parse('${Session.server}$path');

  static dynamic _decode(http.Response r) {
    final data = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) {
      throw ApiException(
          data is Map && data['error'] != null ? '${data['error']}' : 'Lỗi ${r.statusCode}');
    }
    return data;
  }

  static Future<dynamic> _get(String path) async =>
      _decode(await http.get(_u(path)).timeout(_timeout));

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async =>
      _decode(await http
          .post(_u(path),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(_timeout));

  /// Kiem tra nhanh (3s) xem server co tra loi o dia chi nay khong.
  static Future<bool> reachable(String srv, int branch) async {
    try {
      final r = await http
          .get(Uri.parse('$srv/api/b/$branch/menu'))
          .timeout(const Duration(seconds: 8));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<MenuData> menu() async {
    final d = await _get('/api/b/${Session.branch}/menu') as Map<String, dynamic>;
    Session.branchName = d['branch'] as String;
    return MenuData(
      d['branch'] as String,
      (d['items'] as List)
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<int> sendOrder(String note) async {
    final items = Session.cart.entries
        .map((e) => {'id': e.key, 'qty': e.value})
        .toList();
    final d = await _post('/api/order', {
      'branch': Session.branch,
      'table': Session.table,
      'items': items,
      'note': note,
    });
    return d['order_id'] as int;
  }

  static Future<OrderInfo> order(int id) async =>
      OrderInfo.fromJson(await _get('/api/order/$id') as Map<String, dynamic>);

  static Future<void> cancel(int id) => _post('/api/order/$id/cancel', {});

  static Future<void> call(String kind) => _post('/api/call', {
        'branch': Session.branch,
        'table': Session.table,
        'kind': kind,
      });

  static Future<void> rate(int orderId, Map<String, int> stars, String comment) =>
      _post('/api/rating', {
        'order_id': orderId,
        'ratings':
            stars.entries.map((e) => {'name': e.key, 'stars': e.value}).toList(),
        'comment': comment,
      });

  static Future<PayInfo> pay() async {
    final d = await _get('/api/b/${Session.branch}/table/${Session.table}/pay')
        as Map<String, dynamic>;
    return PayInfo(d['total'] as int, d['payload'] as String,
        d['holder'] as String, d['bank'] as String, d['account'] as String);
  }
}
