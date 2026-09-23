import '../../models/pos_models.dart';
import '../offline/pending_order.dart';
import 'pos_local_print_builder.dart';

/// Builds ESC/POS bytes for orders saved locally while offline.
///
/// Uses bootstrap receipt/token templates (same model as online / kiosk).
class OfflineReceiptBuilder {
  OfflineReceiptBuilder._();

  static Future<List<int>> buildBytes({
    required PosBootstrap bootstrap,
    required PendingOrder order,
  }) {
    return buildPosReceiptBytesLocally(
      bootstrap: bootstrap,
      order: order,
    );
  }
}
