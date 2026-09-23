import 'pos_channel_print_policy.dart';
import 'print_object_executor.dart';

enum PosPrintDocumentKind { kot, token, receipt, unknown }

/// Drops customer/counter segments when those backend flags are off.
class PosPrintPayloadFilter {
  PosPrintPayloadFilter._();

  static const _cutTypes = {
    'cut',
    'fullcutpaper',
    'halfcutpaper',
    'partialcutpaper',
  };

  static Map<String, dynamic>? forKot(
    Map<String, dynamic> payload,
    PosChannelPrintPolicy policy,
  ) {
    return _filter(
      payload,
      keepKot: true,
      keepToken: policy.counterReceipt,
      keepReceipt: policy.customerReceipt,
      fallback: PosPrintDocumentKind.kot,
    );
  }

  static Map<String, dynamic>? forReceipt(
    Map<String, dynamic> payload,
    PosChannelPrintPolicy policy,
  ) {
    if (!policy.printsAnyReceiptJob) return null;
    return _filter(
      payload,
      keepKot: false,
      keepToken: policy.counterReceipt,
      keepReceipt: policy.customerReceipt,
      fallback: policy.customerReceipt
          ? PosPrintDocumentKind.receipt
          : PosPrintDocumentKind.token,
    );
  }

  static Map<String, dynamic>? _filter(
    Map<String, dynamic> payload, {
    required bool keepKot,
    required bool keepToken,
    required bool keepReceipt,
    required PosPrintDocumentKind fallback,
  }) {
    final commands = PrintObjectExecutor.commandsFromPayload(payload);
    if (commands.isEmpty) return null;

    final wholeKind = inferKind(payload, commands);
    final segments = _splitByCut(commands);
    final kept = <Map<String, dynamic>>[];

    if (segments.length <= 1) {
      if (!_allows(
        wholeKind == PosPrintDocumentKind.unknown ? fallback : wholeKind,
        keepKot: keepKot,
        keepToken: keepToken,
        keepReceipt: keepReceipt,
      )) {
        return null;
      }
      return _withCommands(payload, commands);
    }

    final sawKot = segments.any(
      (segment) =>
          inferKind(payload, segment, usePayloadType: false) ==
          PosPrintDocumentKind.kot,
    );
    for (final segment in segments) {
      final kind = inferKind(payload, segment, usePayloadType: false);
      final resolved = kind == PosPrintDocumentKind.unknown
          ? (sawKot ? PosPrintDocumentKind.token : fallback)
          : kind;
      if (!_allows(
        resolved,
        keepKot: keepKot,
        keepToken: keepToken,
        keepReceipt: keepReceipt,
      )) {
        continue;
      }
      kept.addAll(segment);
    }

    if (kept.isEmpty) return null;
    if (!_endsWithCut(kept)) {
      kept.add({'type': 'cut', 'mode': 'full'});
    }
    return _withCommands(payload, kept);
  }

  static bool _allows(
    PosPrintDocumentKind kind, {
    required bool keepKot,
    required bool keepToken,
    required bool keepReceipt,
  }) {
    return switch (kind) {
      PosPrintDocumentKind.kot => keepKot,
      PosPrintDocumentKind.token => keepToken,
      PosPrintDocumentKind.receipt => keepReceipt,
      PosPrintDocumentKind.unknown => keepKot || keepToken || keepReceipt,
    };
  }

  static PosPrintDocumentKind inferKind(
    Map<String, dynamic> payload,
    List<dynamic> commands, {
    bool usePayloadType = true,
  }) {
    if (usePayloadType) {
      final typed = _kindFromLabel(
        '${payload['document_type'] ?? payload['print_type'] ?? payload['template_type'] ?? payload['type'] ?? ''}',
      );
      if (typed != PosPrintDocumentKind.unknown) return typed;
    }

    final blob = _commandBlob(commands);
    if (blob.contains('kitchen order') ||
        blob.contains('kitchen ticket') ||
        blob.contains('kitchen kot') ||
        RegExp(r'\bkot\b').hasMatch(blob)) {
      return PosPrintDocumentKind.kot;
    }
    if (blob.contains('subtotal') ||
        blob.contains('grand total') ||
        blob.contains('tax invoice') ||
        blob.contains('cgst') ||
        blob.contains('sgst') ||
        blob.contains('igst') ||
        blob.contains('gstin')) {
      return PosPrintDocumentKind.receipt;
    }
    if (blob.contains('token #') ||
        blob.contains('token no') ||
        blob.contains('amount')) {
      return PosPrintDocumentKind.token;
    }
    return PosPrintDocumentKind.unknown;
  }

  static PosPrintDocumentKind _kindFromLabel(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('token') || value.contains('counter')) {
      return PosPrintDocumentKind.token;
    }
    if (value.contains('kot') || value.contains('kitchen')) {
      return PosPrintDocumentKind.kot;
    }
    if (value.contains('receipt') || value.contains('bill')) {
      return PosPrintDocumentKind.receipt;
    }
    return PosPrintDocumentKind.unknown;
  }

  static String _commandBlob(List<dynamic> commands) {
    final out = StringBuffer();
    for (final entry in commands) {
      if (entry is! Map) continue;
      for (final key in const ['text', 'left', 'right', 'label', 'value']) {
        final value = entry[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          out.write(value.toLowerCase());
          out.write(' ');
        }
      }
    }
    return out.toString();
  }

  static List<List<Map<String, dynamic>>> _splitByCut(List<dynamic> commands) {
    final segments = <List<Map<String, dynamic>>>[];
    var current = <Map<String, dynamic>>[];
    for (final entry in commands) {
      if (entry is! Map) continue;
      final command = Map<String, dynamic>.from(entry);
      current.add(command);
      final type = command['type']?.toString().toLowerCase() ?? '';
      if (_cutTypes.contains(type)) {
        segments.add(current);
        current = <Map<String, dynamic>>[];
      }
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }

  static bool _endsWithCut(List<Map<String, dynamic>> commands) {
    if (commands.isEmpty) return false;
    final type = commands.last['type']?.toString().toLowerCase() ?? '';
    return _cutTypes.contains(type);
  }

  static Map<String, dynamic> _withCommands(
    Map<String, dynamic> payload,
    List<dynamic> commands,
  ) {
    final next = Map<String, dynamic>.from(payload);
    final printObject = next['print_object'];
    if (printObject is Map) {
      final nested = Map<String, dynamic>.from(printObject);
      if (nested['print_object'] is List) {
        nested['print_object'] = commands;
      } else if (nested['commands'] is List) {
        nested['commands'] = commands;
      } else {
        nested['print_object'] = commands;
      }
      next['print_object'] = nested;
    } else {
      next['print_object'] = commands;
    }
    return next;
  }
}
