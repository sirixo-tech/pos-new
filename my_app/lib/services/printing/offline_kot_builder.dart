import '../../models/pos_models.dart';
import '../../providers/pos_register_preferences.dart';
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
    OfflineKotFormat? format,
  }) {
    final snapshot = order.orderData['cart_snapshot'];
    if (snapshot is! List || snapshot.isEmpty) {
      throw StateError('Offline kitchen ticket has no items to print.');
    }
    final saved = format ?? PosRegisterPreferences.instance.offlineKotFormat;
    final settings = bootstrap.receiptSettings ?? PosReceiptSettings();
    final slip = saved ?? OfflineKotFormat.codeDefault;
    final builder = EscPosBuilder(
      typography: ReceiptTypography(
        receiptWidth: saved?.paper ?? settings.receiptWidth,
        fontSize: saved?.fontSize ?? settings.fontSize,
      ),
    );
    builder.initialize();
    builder.alignCenter();
    final title = slip.title.trim();
    final showTitle = slip.showTitle && title.isNotEmpty;
    final token = order.offlineToken;
    final showToken = slip.showToken && token != null;
    if (showTitle || showToken) {
      builder.applyBlockStyle('title');
      if (showTitle) builder.text(title);
      if (showToken) {
        builder.text('${_slipText(slip.tokenLabel, 'TOKEN #')}$token');
      }
      builder.clearBlockStyle('title');
    }
    builder.alignLeft();
    final type = order.orderData['type'] as String?;
    if (slip.showOrderType && type != null && type.trim().isNotEmpty) {
      builder.alignCenter();
      builder.applyBlockStyle('title');
      builder.text(formatOrderType(type));
      builder.clearBlockStyle('title');
      builder.alignLeft();
    }
    if (slip.showTable) {
      final tableName = order.orderData['table_name'];
      final tableId = order.orderData['table_id'];
      if (tableName is String && tableName.trim().isNotEmpty) {
        builder.text(tableName.trim());
      } else if (tableId != null && '$tableId'.trim().isNotEmpty) {
        builder.text('Table $tableId');
      }
    }
    if (slip.showCustomer) {
      final customer = (order.orderData['customer_name'] as String?)?.trim();
      if (customer != null && customer.isNotEmpty) {
        builder.text(customer);
      }
    }
    if (slip.showDate) {
      builder.text(
        '${_slipText(slip.dateLabel, 'Date: ')}${formatReceiptDatetime(order.createdAt)}',
      );
    }
    builder.hr();
    if (slip.showItemHeader) {
      builder.applyBlockStyle('bold');
      builder.text(_slipText(slip.itemHeader, 'Item'));
      builder.clearBlockStyle('bold');
      builder.hr();
    }
    for (final raw in snapshot.whereType<Map>()) {
      final line = Map<String, dynamic>.from(raw);
      final name = (line['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final qty = (line['quantity'] as num?)?.toInt() ?? 1;
      builder.applyBlockStyle('bold');
      builder.text('${qty}x $name');
      builder.clearBlockStyle('bold');
      if (slip.showModifiers) {
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
      }
      if (slip.showLineNotes) {
        final notes = (line['notes'] as String?)?.trim();
        if (notes != null && notes.isNotEmpty) {
          builder.text('   $notes');
        }
      }
    }
    builder.hr();
    if (slip.showOrderNotes) {
      final notes = (order.orderData['notes'] as String?)?.trim();
      if (notes != null && notes.isNotEmpty) {
        builder.hr();
        builder.text(notes);
      }
    }
    builder.feed(4);
    builder.raw(EscPosBuilder.cutSequence(feedLines: 4));
    return builder.build();
  }

}

/// Keep a trailing space in labels such as "Date: ". Trim only decides
/// whether the cashier left the field blank.
String _slipText(String value, String fallback) {
  return value.trim().isEmpty ? fallback : value;
}
