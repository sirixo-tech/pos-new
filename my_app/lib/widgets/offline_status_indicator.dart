import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../services/offline/connectivity_service.dart';
import '../services/offline/order_sync_service.dart';
import '../utils/pos_user_facing_error.dart';

class OfflineStatusIndicator extends StatelessWidget {
  const OfflineStatusIndicator({super.key, this.compact = false});

  /// Icon-only chip for narrow app bars.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityService, OrderSyncService>(
      builder: (context, connectivity, syncService, _) {
        final isOffline = connectivity.isOffline;
        final pendingCount = syncService.pendingCount;
        final failedCount = syncService.failedCount;
        final isSyncing = syncService.isSyncing;

        if (!isOffline && pendingCount == 0) {
          return const SizedBox.shrink();
        }

        final l10n = context.l10n;
        final hasFailures = failedCount > 0 && !isOffline;
        final label = _buildLabel(
          l10n,
          isOffline: isOffline,
          pendingCount: pendingCount,
          failedCount: failedCount,
          isSyncing: isSyncing,
        );

        final lastError = syncService.lastError;
        final tooltip = [
          label,
          if (lastError != null && lastError.isNotEmpty)
            posUserFacingError(lastError),
        ].where((s) => s.isNotEmpty).join('\n');

        final fg = isOffline
            ? Colors.orange[800]
            : hasFailures
                ? Colors.red[800]
                : Colors.blue[800];

        return Tooltip(
          message: tooltip,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 7 : 6,
            ),
            decoration: BoxDecoration(
              color: isOffline
                  ? Colors.orange[100]
                  : hasFailures
                      ? Colors.red[100]
                      : Colors.blue[100],
              borderRadius: BorderRadius.circular(compact ? 10 : 20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    isOffline
                        ? Icons.cloud_off
                        : hasFailures
                            ? Icons.sync_problem
                            : Icons.cloud_upload,
                    size: 16,
                    color: fg,
                  ),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ] else if (pendingCount > 0 || failedCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${hasFailures ? failedCount : pendingCount}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _buildLabel(
    AppLocalizations l10n, {
    required bool isOffline,
    required int pendingCount,
    required int failedCount,
    required bool isSyncing,
  }) {
    if (isSyncing) {
      return l10n.offlineSyncing;
    }
    if (!isOffline && failedCount > 0) {
      return l10n.offlineSyncFailed(failedCount);
    }
    if (isOffline && pendingCount > 0) {
      return l10n.offlinePending(pendingCount);
    }
    if (isOffline) {
      return l10n.offlineLabel;
    }
    if (pendingCount > 0) {
      return l10n.offlinePending(pendingCount);
    }
    return '';
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityService, OrderSyncService>(
      builder: (context, connectivity, syncService, _) {
        if (!connectivity.isOffline && syncService.failedCount == 0) {
          return const SizedBox.shrink();
        }

        final l10n = context.l10n;
        final isOffline = connectivity.isOffline;
        final failed = syncService.failedCount;
        final storedError = syncService.lastError;
        final message = isOffline
            ? l10n.offlineBanner
            : storedError != null && storedError.trim().isNotEmpty
                ? '${l10n.offlineSyncFailedBanner(failed)} ${posUserFacingError(storedError)}'
                : l10n.offlineSyncFailedBanner(failed);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isOffline ? Colors.orange : Colors.red.shade700,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOffline ? Icons.cloud_off : Icons.sync_problem,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PendingOrdersBadge extends StatelessWidget {
  const PendingOrdersBadge({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderSyncService>(
      builder: (context, syncService, _) {
        final count = syncService.pendingCount;

        if (count == 0) {
          return child ?? const SizedBox.shrink();
        }

        return Badge(
          label: Text('$count'),
          backgroundColor:
              syncService.failedCount > 0 ? Colors.red : Colors.orange,
          child: child,
        );
      },
    );
  }
}
