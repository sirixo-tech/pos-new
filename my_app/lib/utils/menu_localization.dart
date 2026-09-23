import 'package:flutter/widgets.dart';

/// Resolve menu name/description from admin `translations` JSON.
///
/// Keys may be locale codes (`te`) and/or English language names (`Telugu`),
/// matching what the API normalizes in [KioskMenuSerializer].
abstract final class MenuLocalization {
  static String name(
    BuildContext context, {
    required String fallback,
    Map<String, Map<String, String>>? translations,
  }) {
    return field(
      translations,
      Localizations.localeOf(context).languageCode,
      'name',
      fallback,
    );
  }

  static String? description(
    BuildContext context, {
    String? fallback,
    Map<String, Map<String, String>>? translations,
  }) {
    final resolved = field(
      translations,
      Localizations.localeOf(context).languageCode,
      'description',
      fallback ?? '',
    );
    return resolved.isEmpty ? null : resolved;
  }

  static String field(
    Map<String, Map<String, String>>? translations,
    String languageCode,
    String fieldName,
    String fallback,
  ) {
    if (translations == null || translations.isEmpty) {
      return fallback;
    }

    for (final key in lookupKeys(languageCode)) {
      final value = translations[key]?[fieldName];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return fallback;
  }

  /// Candidate translation map keys for a BCP-47 language code.
  static List<String> lookupKeys(String languageCode) {
    final code = languageCode.trim().toLowerCase();
    switch (code) {
      case 'es':
        return const ['es', 'Spanish', 'Español'];
      case 'hi':
        return const ['hi', 'Hindi', 'हिन्दी'];
      case 'te':
        return const ['te', 'Telugu', 'తెలుగు'];
      case 'kn':
        return const ['kn', 'Kannada', 'ಕನ್ನಡ'];
      case 'ar':
        return const ['ar', 'Arabic', 'العربية'];
      case 'fr':
        return const ['fr', 'French', 'Français'];
      case 'en':
        return const ['en', 'English'];
      default:
        return code.isEmpty ? const <String>[] : <String>[code];
    }
  }
}

Map<String, Map<String, String>> parseMenuTranslations(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, Map<String, String>>{};
  raw.forEach((key, value) {
    if (key == null || value is! Map) return;
    final code = key.toString().trim();
    if (code.isEmpty) return;
    final fields = <String, String>{};
    value.forEach((fieldKey, fieldValue) {
      if (fieldKey == null || fieldValue == null) return;
      final text = fieldValue.toString().trim();
      if (text.isEmpty) return;
      fields[fieldKey.toString()] = text;
    });
    if (fields.isNotEmpty) {
      out[code] = fields;
    }
  });
  return out;
}
