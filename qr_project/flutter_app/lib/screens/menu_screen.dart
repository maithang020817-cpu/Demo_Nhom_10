import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart_screen.dart';
import 'item_detail_screen.dart';
import 'order_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  MenuData? _data;
  String? _error;
  String _query = '';
  String _cat = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.menu();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Không tải được thực đơn: $e');
    }
  }

  int get _count => Session.cart.values.fold(0, (a, b) => a + b);

  int get _total => _data == null
      ? 0
      : _data!.items.fold(0, (s, i) => s + i.price * (Session.cart[i.id] ?? 0));

  void _change(int id, int d) => setState(() {
        final n = (Session.cart[id] ?? 0) + d;
        if (n <= 0) {
          Session.cart.remove(id);
        } else {
          Session.cart[id] = n > 50 ? 50 : n;
        }
      });

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

  void _openOrder() {
    if (Session.orderId == null) {
      _toast('Bạn chưa có đơn nào.');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderScreen()))
        .then((_) => setState(() {}));
  }

  void _openCart() => Navigator.push(context,
          MaterialPageRoute(builder: (_) => CartScreen(data: _data!)))
      .then((_) => setState(() {}));

  void _openDetail(MenuItem i) => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ItemDetailScreen(item: i)))
      .then((_) => setState(() {}));

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final cats = data == null
        ? <String>[]
        : ['Tất cả', ...{...data.items.map((e) => e.category)}];
    final shown = data == null
        ? <MenuItem>[]
        : data.items
            .where((i) =>
                (_cat == 'Tất cả' || i.category == _cat) &&
                i.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppHeader(label: 'THỰC ĐƠN', onBell: _callStaff),
      body: _error != null
          ? Center(
              child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Thử lại')),
              ]),
            ))
          : data == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: TextField(
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search, color: C.muted),
                          hintText: 'Tìm tên món ăn...'),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  SizedBox(
                    height: 58,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      children: [
                        for (final c in cats)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: _cat == c,
                              showCheckmark: false,
                              selectedColor: C.primary,
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              labelStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _cat == c ? Colors.white : C.text),
                              onSelected: (_) => setState(() => _cat = c),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: C.primary,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                        itemCount: shown.length,
                        itemBuilder: (_, k) => _row(shown[k]),
                      ),
                    ),
                  ),
                ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
        if (Session.orderId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ActionChip(
              avatar: const Icon(Icons.receipt_long, size: 18, color: C.primary),
              label: const Text('Đơn của tôi / Hóa đơn'),
              backgroundColor: C.blueSoft,
              side: BorderSide.none,
              onPressed: _openOrder,
            ),
          ),
        if (_count > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: _openCart,
              child: Row(children: [
                const Icon(Icons.shopping_bag_outlined),
                const SizedBox(width: 10),
                Text('Xem giỏ hàng · $_count món'),
                const Spacer(),
                Text(vnd(_total)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _row(MenuItem i) {
    final qty = Session.cart[i.id] ?? 0;
    return Opacity(
      opacity: i.available ? 1 : .5,
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        onTap: () => _openDetail(i),
        child: Row(children: [
          FoodImage(i, size: 96, badge: i.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                if (i.avg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      const Icon(Icons.star_rounded,
                          size: 16, color: Color(0xFFE0A100)),
                      Text(' ${i.avg!.toStringAsFixed(1)}',
                          style: const TextStyle(
                              fontSize: 12, color: C.muted)),
                    ]),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Text(vnd(i.price),
                        style: const TextStyle(
                            color: C.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                  ),
                  if (!i.available)
                    const Pill('HẾT HÀNG', bg: Color(0xFFFFDAD6), fg: C.red)
                  else if (qty == 0)
                    InkWell(
                      onTap: () => _change(i.id, 1),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                            color: C.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    )
                  else
                    QtyStepper(
                        qty: qty,
                        onMinus: () => _change(i.id, -1),
                        onPlus: () => _change(i.id, 1)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
