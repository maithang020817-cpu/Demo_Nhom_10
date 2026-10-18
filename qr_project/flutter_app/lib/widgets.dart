import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';

/// Thanh đầu trang: logo · Chi nhánh · [Bàn] + nhãn màn hình + nút chuông.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String label;
  final VoidCallback? onBell;
  const AppHeader({super.key, required this.label, this.onBell});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Material(
      color: C.bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(canPop ? 4 : 16, 8, 16, 8),
          child: Row(children: [
            if (canPop)
              IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => Navigator.maybePop(context)),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: C.peach, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.ramen_dining, color: C.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                            Session.branchName.isEmpty
                                ? 'Savor Dine'
                                : Session.branchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      const SizedBox(width: 8),
                      Pill('Bàn ${Session.table}'),
                    ]),
                    Text(label,
                        style: const TextStyle(
                            color: C.muted,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
            if (onBell != null)
              Material(
                color: C.blueSoft,
                shape: const CircleBorder(),
                child: IconButton(
                    tooltip: 'Gọi nhân viên',
                    icon: const Icon(Icons.notifications_active_outlined,
                        color: C.primary),
                    onPressed: onBell),
              ),
          ]),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const Pill(this.text,
      {super.key, this.bg = C.peach, this.fg = C.primary});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style:
                TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  const SoftCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.color = Colors.white,
      this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: Color(0x14A33A00), blurRadius: 14, offset: Offset(0, 4))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: Padding(padding: padding, child: child)),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? badge;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.badge, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
        child: Row(children: [
          Container(
              width: 9,
              height: 9,
              decoration:
                  const BoxDecoration(color: C.primary, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Pill(badge!, bg: C.blueSoft, fg: C.blueText),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}

class QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;
  const QtyStepper(
      {super.key, required this.qty, this.onMinus, required this.onPlus});

  Widget _btn(IconData i, VoidCallback? f, bool filled) => InkWell(
        customBorder: const CircleBorder(),
        onTap: f,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: filled ? C.primary : Colors.white, shape: BoxShape.circle),
          child: Icon(i,
              size: 18, color: filled ? Colors.white : C.muted),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: C.blueSoft, borderRadius: BorderRadius.circular(22)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btn(Icons.remove, onMinus, false),
          SizedBox(
              width: 30,
              child: Center(
                  child: Text('$qty',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)))),
          _btn(Icons.add, onPlus, true),
        ]),
      );
}

class FoodImage extends StatelessWidget {
  final MenuItem item;
  final double size;
  final String? badge;
  const FoodImage(this.item, {super.key, this.size = 92, this.badge});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
        width: size,
        height: size,
        color: C.peach,
        alignment: Alignment.center,
        child: Text(item.emoji, style: TextStyle(fontSize: size * .45)));
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: item.image == null
            ? placeholder
            : Image.network('${Session.server}${item.image}',
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder),
      ),
      if (badge != null)
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: C.primary.withOpacity(.92),
                borderRadius: BorderRadius.circular(8)),
            child: Text(badge!.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }
}
