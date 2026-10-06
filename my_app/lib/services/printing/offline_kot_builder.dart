import '../../models/pos_models.dart';
import '../../utils/format.dart';
import '../offline/pending_order.dart';
import 'esc_pos_builder.dart';
import 'receipt_typography.dart';

/// Offline kitchen slip using the saved token and cart snapshot.
class OfflineKotBuilder {
  OfflineKotBuilder._();

  static List<int> buildBytes({
    required PosBootstrap bootstrap,
    required PendingOrder order,
  }) {
    final snapshot = order.orderData['cart_snapshot'];
    if (snapshot is! List || snapshot.isEmpty) {
      throw StateError('Offline kitchen ticket has no items to print.');
    }
    final settings = bootstrap.receiptSettings ?? PosReceiptSettings();
    final builder = EscPosBuilder(
      typography: ReceiptTypography(
        receiptWidth: settings.receiptWidth,
        fontSize: settings.fontSize,
      ),
    );
    builder.initialize();
    builder.alignCenter();
    builder.applyBlockStyle('title');
    builder.text('KITCHEN ORDER');
    if (order.offlineToken != null) {
      builder.text('TOKEN #${order.offlineToken}');
    }
    builder.clearBlockStyle('title');
    builder.alignLeft();
    final type = order.orderData['type'] as String?;
    if (type != null && type.trim().isNotEmpty) {
      builder.alignCenter();
      builder.applyBlockStyle('title');
      builder.text(formatOrderType(type));
      builder.clearBlockStyle('title');
      builder.alignLeft();
    }
    final tableName = order.orderData['table_name'];
    final tableId = order.orderData['table_id'];
    if (tableName is String && tableName.trim().isNotEmpty) {
      builder.text(tableName.trim());
    } else if (tableId != null && '$tableId'.trim().isNotEmpty) {
      builder.text('Table $tableId');
    }
    final customer = (order.orderData['customer_name'] as String?)?.trim();
    if (customer != null && customer.isNotEmpty) {
      builder.text(customer);
    }
    builder.text('Date: ${formatReceiptDatetime(order.createdAt)}');
    builder.hr();
    builder.applyBlockStyle('bold');
    builder.text('Item');
    builder.clearBlockStyle('bold');
    builder.hr();
    for (final raw in snapshot.whereType<Map>()) {
      final line = Map<String, dynamic>.from(raw);
      final name = (line['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final qty = (line['quantity'] as num?)?.toInt() ?? 1;
      builder.applyBlockStyle('bold');
      builder.text('${qty}x $name');
      builder.clearBlockStyle('bold');
      final mods = line['modifiers'];
      if (mods is List) {
        for (final mod in mods.whereType<Map>()) {
          final modName = (mod['name'] ?? mod['option_name'])
              ?.toString()
              .trim();
          if (modName != null && modName.isNotEmpty) {
            builder.text('   + $modName');
          }
        }
      }
      final notes = (line['notes'] as String?)?.trim();
      if (notes != null && notes.isNotEmpty) {
        builder.text('   $notes');
      }
    }
    builder.hr();
    final notes = (order.orderData['notes'] as String?)?.trim();
    if (notes != null && notes.isNotEmpty) {
      builder.hr();
      builder.text(notes);
    }
    builder.feed(4);
    builder.raw(EscPosBuilder.cutSequence(feedLines: 4));
    return builder.build();
  }

}
