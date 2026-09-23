import 'package:flutter/material.dart';

import 'app_localizations.dart';
import 'pos_translation_store.dart';

export 'app_localizations.dart';
export 'pos_locales.dart';
export 'pos_translation_store.dart';

/// Convenience access: `context.l10n.cartPay`
extension PosL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Catalog-only lookup with English fallback (for rare ad-hoc keys).
  String posText(
    String key,
    String fallback, [
    Map<String, Object> replacements = const {},
  ]) {
    // Prefer MaterialApp locale; fall back to the store's active locale so
    // strings still resolve if a subtree briefly lacks Localizations.
    String localeCode;
    try {
      localeCode = Localizations.localeOf(this).languageCode;
    } catch (_) {
      localeCode = PosTranslationStore.instance.activeLocaleCode;
    }
    return PosTranslationStore.instance.text(
      key,
      fallback,
      localeCode: localeCode,
      replacements: replacements,
    );
  }
}
