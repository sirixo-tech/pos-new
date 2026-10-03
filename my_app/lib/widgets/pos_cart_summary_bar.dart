import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';

class PosCartSummaryBar extends StatelessWidget {
  const PosCartSummaryBar({
    super.key,
    required this.accent,
    required this.onTap,
  });
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = context.select((PosController p) => p.cartItemCount);
    final total = context.select((PosController p) => p.cartTotal);
    final currency = context.select((PosController p) => p.currency);
    return Material(
      color: PosTheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(Icons.shopping_cart_rounded, color: accent, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count == 1
                          ? context.l10n.cartItemCount(1)
                          : context.l10n.cartItemCountPlural(count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PosTheme.ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatMoney(total, currency),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 48),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          context.l10n.shellViewCart,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
