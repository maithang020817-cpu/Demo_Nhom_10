import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';

/// Chi tiết món: ảnh lớn, giá, điểm đánh giá, chọn số lượng.
class ItemDetailScreen extends StatefulWidget {
  final MenuItem item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late int _qty = Session.cart[widget.item.id] ?? 1;

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return Scaffold(
      appBar: const AppHeader(label: 'CHI TIẾT MÓN'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 120), children: [
        AspectRatio(
          aspectRatio: 1.25,
          child: LayoutBuilder(
            builder: (_, c) => FoodImage(i, size: c.maxWidth, badge: i.category),
          ),
        ),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(i.name,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
          ),
          const SizedBox(width: 12),
          Text(vnd(i.price),
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: C.primary)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill(i.category, bg: C.blueSoft, fg: C.blueText),
          if (i.avg != null)
            Pill('★ ${i.avg!.toStringAsFixed(1)} / 5',
                bg: const Color(0xFFFFF0C2), fg: const Color(0xFF7A5400)),
          Pill(i.available ? 'Còn món' : 'Hết món',
              bg: i.available ? C.greenSoft : const Color(0xFFFFDAD6),
              fg: i.available ? C.green : C.red),
        ]),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          color: C.bg,
          child: Row(children: [
            QtyStepper(
              qty: _qty,
              onMinus: _qty > 1 ? () => setState(() => _qty--) : null,
              onPlus: () => setState(() => _qty = _qty >= 50 ? 50 : _qty + 1),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FilledButton(
                onPressed: i.available
                    ? () {
                        Session.cart[i.id] = _qty;
                        Navigator.pop(context);
                      }
                    : null,
                child: Text('Thêm vào giỏ · ${vnd(i.price * _qty)}'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
