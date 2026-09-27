import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/kitchen_models.dart';
import '../../providers/pos_controller.dart';
import '../../services/pos_api.dart';
import '../../services/printing/pos_receipt_printer.dart';
import '../../services/printing/print_job_coordinator.dart';
import '../../widgets/pos_ui.dart';

/// Print kitchen KOT slips for a board order on the local POS printer.
Future<void> printKitchenKot(
  BuildContext context,
  KitchenBoardOrder order,
) async {
  final session = context.read<PosController>().session;
  if (session == null) return;

  final orderNumber = order.orderNumber.trim();
  if (orderNumber.isEmpty) {
    showPosSnackBar(context, context.l10n.ordersNumberMissing, error: true);
    return;
  }

  if (!PosReceiptPrinter.isSupported) {
    showPosSnackBar(
      context,
      PosReceiptPrinter.unsupportedMessage,
      error: true,
    );
    return;
  }

  final jobs = context.read<PrintJobCoordinator>();
  try {
    await PosReceiptPrinter.printKotByOrderNumber(
      session: session,
      orderNumber: orderNumber,
    );
    if (!context.mounted) return;
    await jobs.completeHandPrinted(
      kind: PrintJobKind.kot,
      orderNumber: orderNumber,
      orderId: order.id,
    );
    if (!context.mounted) return;
    showPosSnackBar(context, context.l10n.printKotPrinted(orderNumber));
  } on PosApiException catch (e) {
    if (!context.mounted) return;
    if (e.statusCode == 404) {
      showPosSnackBar(
        context,
        context.l10n.printOrderNotFound(orderNumber),
        error: true,
      );
    } else {
      showPosErrorSnackBar(context, e);
    }
  } catch (e) {
    if (!context.mounted) return;
    showPosErrorSnackBar(context, e);
  }
}

bool kitchenOrderCanPrintKot(KitchenBoardOrder order) =>
    PosReceiptPrinter.isSupported && order.orderNumber.trim().isNotEmpty;
