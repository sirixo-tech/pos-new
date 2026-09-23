import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'pos_translation_store.dart';

/// Supported staff-facing locales for the POS.
abstract final class PosLocales {
  static const en = Locale('en');
  static const es = Locale('es');
  static const hi = Locale('hi');
  static const te = Locale('te');
  static const kn = Locale('kn');

  static const all = <Locale>[en, es, hi, te, kn];

  static List<LocalizationsDelegate<dynamic>> delegatesFor(int catalogGeneration) {
    return [
      PosLocalizationsDelegate(catalogGeneration),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
  }

  static Locale resolve(Locale? locale, Iterable<Locale> supported) {
    if (locale == null) return en;
    for (final supportedLocale in supported) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }
    return supported.isNotEmpty ? supported.first : en;
  }

  static String displayName(Locale locale) {
    return nativeNameForCode(locale.languageCode);
  }

  static String nativeNameForCode(String code) {
    switch (code.trim().toLowerCase()) {
      case 'es':
        return 'Español';
      case 'hi':
        return 'हिन्दी';
      case 'te':
        return 'తెలుగు';
      case 'kn':
        return 'ಕನ್ನಡ';
      case 'en':
      default:
        return 'English';
    }
  }
}
