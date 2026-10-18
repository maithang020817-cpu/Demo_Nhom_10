import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'order_screen.dart';

/// Giỏ hàng: "Gửi trực tiếp đến bếp".
class CartScreen extends StatefulWidget {
  final MenuData data;
  const CartScreen({super.key, required this.data});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<MenuItem> get _lines =>
      widget.data.items.where((i) => Session.cart.containsKey(i.id)).toList();

  int get _total =>
      _lines.fold(0, (s, i) => s + i.price * (Session.cart[i.id] ?? 0));

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _change(int id, int d) => setState(() {
        final n = (Session.cart[id] ?? 0) + d;
        if (n <= 0) {
          Session.cart.remove(id);
        } else {
          Session.cart[id] = n > 50 ? 50 : n;
        }
      });

  Future<void> _callStaff() async {
    try {
      await Api.call('staff');
      _toast('Đã gọi nhân viên, vui lòng đợi trong giây lát!');
    } catch (e) {
      _toast('Lỗi: $e');
    }
  }

  Future<void> _send() async {
    if (Session.cart.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final id = await Api.sendOrder(_note.text);
      Session.orderId = id;
      Session.cart.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const OrderScreen()));
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      _toast('Không gửi được đơn: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final suggest = widget.data.items
        .where((i) => i.available && !Session.cart.containsKey(i.id))
        .take(6)
        .toList();
    return Scaffold(
      appBar: AppHeader(label: 'GIỎ HÀNG', onBell: _callStaff),
      body: lines.isEmpty
          ? const Center(
              child: Text('Giỏ hàng trống', style: TextStyle(color: C.muted)))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [C.peach, C.peachSoft]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                        color: C.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.soup_kitchen, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gửi trực tiếp đến bếp',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 18)),
                          SizedBox(height: 2),
                          Text(
                              'Các món trong giỏ sẽ được chuyển ngay vào màn hình bếp của đầu bếp sau khi bấm xác nhận.',
                              style: TextStyle(color: C.muted, fontSize: 13)),
                        ]),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              SectionTitle('Món chờ gửi bếp',
                  badge: '${lines.length} món',
                  trailing: TextButton.icon(
                    onPressed: () => setState(Session.cart.clear),
                    icon: const Icon(Icons.delete_sweep_outlined,
                        size: 18, color: C.red),
                    label: const Text('Xóa tất cả',
                        style: TextStyle(
                            color: C.red, fontWeight: FontWeight.w700)),
                  )),
              for (final i in lines) _line(i),
              if (suggest.isNotEmpty) ...[
                const SectionTitle('Thường được gọi kèm'),
                SizedBox(
                  height: 130,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [for (final i in suggest) _suggest(i)],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const SectionTitle('Ghi chú cho cả đợt gọi này'),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                    hintText: 'Ít cay, không hành, mang ra cùng lúc...'),
              ),
            ]),
      bottomNavigationBar: lines.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                color: C.bg,
                child: FilledButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Row(children: [
                          const Icon(Icons.send_rounded),
                          const SizedBox(width: 10),
                          const Text('Xác nhận gửi bếp'),
                          const Spacer(),
                          Text(vnd(_total)),
                        ]),
                ),
              ),
            ),
    );
  }

  Widget _line(MenuItem i) {
    final q = Session.cart[i.id] ?? 0;
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FoodImage(i, size: 92, badge: i.category),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(i.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              InkWell(
                onTap: () => setState(() => Session.cart.remove(i.id)),
                child: const Icon(Icons.close, size: 20, color: C.muted),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vnd(i.price * q),
                          style: const TextStyle(
                              color: C.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 17)),
                      if (q > 1)
                        Text('${vnd(i.price)} / phần',
                            style:
                                const TextStyle(color: C.muted, fontSize: 12)),
                    ]),
              ),
              QtyStepper(
                  qty: q,
                  onMinus: () => _change(i.id, -1),
                  onPlus: () => _change(i.id, 1)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _suggest(MenuItem i) => Container(
        width: 250,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          FoodImage(i, size: 70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(vnd(i.price),
                      style: const TextStyle(
                          color: C.primary, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _change(i.id, 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: C.peach,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text('+ Thêm nhanh',
                          style: TextStyle(
                              color: C.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                  ),
                ]),
          ),
        ]),
      );
}
