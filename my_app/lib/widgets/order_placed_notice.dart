import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pos_controller.dart';

/// Compact success chip after a cashier places an order.
class OrderPlacedNoticeHost extends StatelessWidget {
  const OrderPlacedNoticeHost({super.key});

  @override
  Widget build(BuildContext context) {
    final notice = context.select((PosController p) => p.cashierPlacedNotice);
    if (notice == null) return const SizedBox.shrink();

    return Positioned(
      top: 12,
      right: 16,
      child: SafeArea(
        child: IgnorePointer(
          child: Material(
            color: const Color(0xFF059669),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      notice,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: -0.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
