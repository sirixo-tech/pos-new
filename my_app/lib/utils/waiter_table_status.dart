import 'package:flutter/material.dart';

/// Table occupancy statuses from POS `/tables` (+ local billing overlay).
enum WaiterTableStatus {
  available,
  occupied,
  billing,
  reserved,
  cleaning,
}

WaiterTableStatus parseWaiterTableStatus(
  String? raw, {
  bool billRequested = false,
}) {
  final status = (raw ?? 'available').trim().toLowerCase();
  if (billRequested || status == 'billing') {
    return WaiterTableStatus.billing;
  }
  return switch (status) {
    'occupied' => WaiterTableStatus.occupied,
    'reserved' => WaiterTableStatus.reserved,
    'cleaning' => WaiterTableStatus.cleaning,
    _ => WaiterTableStatus.available,
  };
}

@immutable
class WaiterTableStatusStyle {
  const WaiterTableStatusStyle({
    required this.dot,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color dot;
  final Color background;
  final Color foreground;
  final Color border;
}

WaiterTableStatusStyle waiterTableStatusStyle(
  WaiterTableStatus status, {
  required bool isDark,
}) {
  // Dark: deep slate-tinted fills + bright ink for readable floor cards.
  // Light: soft pastels (unchanged hierarchy).
  return switch (status) {
    WaiterTableStatus.available => WaiterTableStatusStyle(
        dot: isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
        background:
            isDark ? const Color(0xFF0B281F) : const Color(0xFFECFDF5),
        foreground:
            isDark ? const Color(0xFFECFDF5) : const Color(0xFF047857),
        border: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
      ),
    WaiterTableStatus.occupied => WaiterTableStatusStyle(
        dot: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
        background:
            isDark ? const Color(0xFF2A1012) : const Color(0xFFFEF2F2),
        foreground:
            isDark ? const Color(0xFFFFF1F2) : const Color(0xFFB91C1C),
        border: isDark ? const Color(0xFFEF4444) : const Color(0xFFFECACA),
      ),
    WaiterTableStatus.billing || WaiterTableStatus.reserved =>
      WaiterTableStatusStyle(
        dot: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
        background:
            isDark ? const Color(0xFF271A08) : const Color(0xFFFFFBEB),
        foreground:
            isDark ? const Color(0xFFFFFBEB) : const Color(0xFFB45309),
        border: isDark ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A),
      ),
    WaiterTableStatus.cleaning => WaiterTableStatusStyle(
        dot: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
        background:
            isDark ? const Color(0xFF151B28) : const Color(0xFFF1F5F9),
        foreground:
            isDark ? const Color(0xFFF1F5F9) : const Color(0xFF475569),
        border: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
      ),
  };
}

/// Kitchen / order pipeline for waiter tracking chips.
enum WaiterLinePipeline {
  sent,
  preparing,
  ready,
  served,
}

WaiterLinePipeline mapOrderStatusToPipeline(String? status) {
  return switch ((status ?? '').trim().toLowerCase()) {
    'preparing' => WaiterLinePipeline.preparing,
    'ready' => WaiterLinePipeline.ready,
    'delivered' || 'served' || 'completed' => WaiterLinePipeline.served,
    'confirmed' || 'draft' || 'pending' || 'sent' => WaiterLinePipeline.sent,
    _ => WaiterLinePipeline.sent,
  };
}
