import '../../models/pos_models.dart';
import '../../providers/pos_register_preferences.dart';
import '../offline/pending_order.dart';
import 'esc_pos_builder.dart';
import 'offline_print_adapter.dart';
import 'pos_channel_print_policy.dart';
import 'receipt_template_renderer.dart';
import 'token_template_renderer.dart';

/// Builds receipt + item token slips locally from POS bootstrap templates
/// (mirrors kiosk local fallback / `KioskPrintObjectBuilder` for channel `pos`).
Future<List<int>> buildPosReceiptBytesLocally({
  required PosBootstrap bootstrap,
  required PendingOrder order,
  bool duplicateCopy = false,
}) async {
  final baseSettings = bootstrap.receiptSettings ?? PosReceiptSettings();
  final localFormat = PosRegisterPreferences.instance.offlineFormat;
  final settings = localFormat == null
      ? baseSettings
      : localFormat.applyTo(baseSettings);
  final tokenSettings = settings.token;
  final venue = OfflinePrintAdapter.venueFromBootstrap(bootstrap);
  final printOrder = OfflinePrintAdapter.orderFromPending(
    bootstrap: bootstrap,
    order: order,
  );

  if (printOrder.items.isEmpty) {
    throw StateError('Offline receipt has no line items to print.');
  }

  final policy = PosChannelPrintPolicy.fromBootstrap(bootstrap);
  final bytes = <int>[];
  // A saved cashier format prints the customer slip even when the web
  // receipt switch is off. Online printing does not read this format.
  final printReceipt = localFormat != null || policy.customerReceipt;
  final printTokens = policy.counterReceipt && printOrder.items.isNotEmpty;
  final cutMode = _normalizeCutMode(tokenSettings.cutMode);

  if (printReceipt) {
    bytes.addAll(
      await ReceiptTemplateRenderer(
        venue: venue,
        order: printOrder,
        settings: settings,
        template: localFormat == null
            ? settings.template
            : localFormat.toCodeTemplate(),
        isDuplicateCopy: duplicateCopy,
        respectTaxToggle: localFormat != null,
      ).buildBytes(cutAtEnd: false),
    );

    bytes.addAll(
      EscPosBuilder.cutSequence(
        mode: _cutModeForSlip(cutMode, isLastSlip: !printTokens),
      ),
    );
  }

  if (printTokens) {
    final items = expandTokenPrintItems(printOrder, tokenSettings);
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final isLast = index == items.length - 1;
      final cutAfterEach = tokenSettings.cutAfterEach;

      bytes.addAll(
        await TokenTemplateRenderer(
          venue: venue,
          order: printOrder,
          receiptSettings: settings,
          tokenSettings: tokenSettings,
          template: tokenSettings.template,
          item: item,
        ).buildBytes(cutAtEnd: false),
      );

      if (cutAfterEach || isLast) {
        bytes.addAll(
          EscPosBuilder.cutSequence(
            mode: _cutModeForSlip(cutMode, isLastSlip: isLast),
          ),
        );
      }
    }
  }

  if (bytes.isEmpty) {
    throw StateError(
      'Nothing to print for this channel (receipt/tokens disabled for POS).',
    );
  }

  return bytes;
}

String _normalizeCutMode(String? mode) {
  switch (mode) {
    case 'full':
    case 'partial_then_full':
    case 'partial':
      return mode!;
    default:
      return 'partial';
  }
}

String _cutModeForSlip(String cutMode, {required bool isLastSlip}) {
  switch (_normalizeCutMode(cutMode)) {
    case 'full':
      return 'full';
    case 'partial_then_full':
      return isLastSlip ? 'full' : 'partial';
    default:
      return 'partial';
  }
}
