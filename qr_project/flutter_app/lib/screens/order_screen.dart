import 'dart:async';
import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pay_screen.dart';

/// Theo dõi đơn + hóa đơn + đánh giá (theo thiết kế BILL).
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  OrderInfo? _info;
  Timer? _timer;
  final Map<String, int> _stars = {};
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final i = await Api.order(Session.orderId!);
      if (mounted) setState(() => _info = i);
    } catch (_) {/* mất mạng tạm thời: lần sau thử lại */}
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _callStaff() async {
    try {
      await Api.call('staff');
      _toast('Đã gọi nhân viên, vui lòng đợi trong giây lát!');
    } catch (e) {
      _toast('Lỗi: $e');
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hủy đơn này?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không')),
          FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hủy đơn')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.cancel(Session.orderId!);
      _refresh();
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _sendRating() async {
    if (_stars.isEmpty) {
      _toast('Hãy chọn số sao!');
      return;
    }
    try {
      await Api.rate(Session.orderId!, _stars, _comment.text);
      _toast('Cảm ơn bạn đã đánh giá!');
      _refresh();
    } catch (e) {
      _toast('$e');
    }
  }

  Color _color(String s) => switch (s) {
        'new' => C.red,
        'cooking' => const Color(0xFFE07B00),
        'served' => C.green,
        _ => C.muted,
      };

  String _ratingLabel(int s) => switch (s) {
        5 => 'Tuyệt đỉnh hương vị',
        4 => 'Rất hài lòng!',
        3 => 'Tạm ổn',
        2 => 'Chưa hài lòng',
        1 => 'Rất tệ',
        _ => 'Chạm để chọn số sao',
      };

  @override
  Widget build(BuildContext context) {
    final o = _info;
    return Scaffold(
      appBar: AppHeader(label: 'BILL', onBell: _callStaff),
      body: o == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
              _statusCard(o),
              _itemsCard(o),
              _totalCard(o),
              if (o.status == 'served' && !o.rated) _ratingCard(o),
              if (o.rated)
                SoftCard(
                  color: const Color(0xFFE4FBEA),
                  child: const Row(children: [
                    Icon(Icons.check_circle, color: C.green),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text('Cảm ơn bạn đã đánh giá!',
                            style: TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
              const SizedBox(height: 4),
              FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PayScreen())),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Thanh toán VietQR')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Gọi thêm món')),
            ]),
    );
  }

  Widget _statusCard(OrderInfo o) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: _color(o.status), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text('Bàn ${Session.table}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            Pill(o.statusText, bg: _color(o.status).withOpacity(.14), fg: _color(o.status)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: C.blueSoft, borderRadius: BorderRadius.circular(16)),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _kv('Mã đơn', '#${Session.orderId}'),
                  _kv('Chi nhánh', Session.branchName),
                  _kv('Số món', '${o.items.fold(0, (a, b) => a + b.qty)}'),
                ]),
          ),
          const SizedBox(height: 8),
          const Text('Tự cập nhật khi bếp xử lý đơn.',
              style: TextStyle(color: C.muted, fontSize: 12)),
        ]),
      );

  Widget _kv(String k, String v) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: const TextStyle(color: C.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
          ]);

  Widget _itemsCard(OrderInfo o) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle_outline, color: C.green),
            const SizedBox(width: 8),
            const Text('Món đã gọi',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const Spacer(),
            Pill('${o.items.length} món', bg: C.greenSoft, fg: C.green),
          ]),
          const SizedBox(height: 12),
          for (final l in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                      color: C.peachSoft,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${l.qty}×',
                      style: const TextStyle(
                          color: C.primary, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(l.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15))),
                Text(vnd(l.price * l.qty),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
      );

  Widget _totalCard(OrderInfo o) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Chi tiết thanh toán',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Text('Tạm tính tiền món')),
            Text(vnd(o.total),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          const Divider(height: 28),
          Row(children: [
            const Expanded(
                child: Text('Tổng cộng',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            Text(vnd(o.total),
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: C.primary)),
          ]),
        ]),
      );

  Widget _stars5(int value, ValueChanged<int> onTap, double size) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int k = 1; k <= 5; k++)
            GestureDetector(
              onTap: () => onTap(k),
              child: Icon(value >= k ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: C.primary, size: size),
            ),
        ],
      );

  Widget _ratingCard(OrderInfo o) {
    final overall = _stars.isEmpty
        ? 0
        : (_stars.values.reduce((a, b) => a + b) / _stars.length).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [C.peach, C.blueSoft]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
                color: C.primary, shape: BoxShape.circle),
            child: const Icon(Icons.card_giftcard, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
                'QUÀ TẶNG TRI ÂN\nĐánh giá bữa ăn để nhận ưu đãi cho lần tới!',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      SoftCard(
        child: Column(children: [
          Text('Trải nghiệm tổng thể tại Bàn ${Session.table}',
              style: const TextStyle(color: C.muted)),
          const SizedBox(height: 6),
          Text(_ratingLabel(overall),
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _stars5(overall, (k) {
            setState(() {
              for (final l in o.items) {
                _stars[l.name] = k;
              }
            });
          }, 46),
        ]),
      ),
      const SectionTitle('Đánh giá món vừa dùng'),
      for (final l in o.items)
        SoftCard(
          child: Row(children: [
            Expanded(
                child: Text(l.name,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            _stars5(_stars[l.name] ?? 0,
                (k) => setState(() => _stars[l.name] = k), 28),
          ]),
        ),
      TextField(
        controller: _comment,
        decoration: const InputDecoration(hintText: 'Nhận xét (không bắt buộc)'),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: _sendRating, child: const Text('Gửi đánh giá')),
      const SizedBox(height: 14),
    ]);
  }
}
