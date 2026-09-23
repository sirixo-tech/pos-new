import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/pos_models.dart';
import '../theme/pos_theme.dart';

/// Mirrors backend `MarketplaceProviderRegistry::PROVIDERS`.
const marketplaceKnownProviders = <String>{'zomato', 'swiggy'};

bool isMarketplaceOrderSource(String? source) {
  final key = (source ?? '').toLowerCase().trim();
  if (key.isEmpty) return false;
  return marketplaceKnownProviders.contains(key);
}

Color marketplaceBrandColor(String provider) {
  return switch (provider.toLowerCase()) {
    'zomato' => const Color(0xFFE23744),
    'swiggy' => const Color(0xFFFC8019),
    _ => PosTheme.inkMuted,
  };
}

Color marketplaceBrandBg(String provider) {
  return switch (provider.toLowerCase()) {
    'zomato' => const Color(0xFFFFF1F2),
    'swiggy' => const Color(0xFFFFF7ED),
    _ => PosTheme.surfaceMuted,
  };
}

String marketplacePlatformLetter(String provider) {
  final key = provider.trim();
  if (key.isEmpty) return '?';
  return key[0].toUpperCase();
}

String marketplaceSourceDisplayLabel(AppLocalizations l10n, String? source) {
  return switch ((source ?? '').toLowerCase().trim()) {
    'zomato' => l10n.ordersFilterZomato,
    'swiggy' => l10n.ordersFilterSwiggy,
    final key when key.isNotEmpty => key[0].toUpperCase() + key.substring(1),
    _ => l10n.ordersFilterPartners,
  };
}

String marketplacePlatformDisplayLabel(
  AppLocalizations l10n,
  MarketplacePlatformInfo platform,
) {
  return switch (platform.provider) {
    'zomato' => l10n.ordersFilterZomato,
    'swiggy' => l10n.ordersFilterSwiggy,
    _ => platform.label.isNotEmpty ? platform.label : platform.provider,
  };
}

String marketplaceEmptySubtitle(
  AppLocalizations l10n,
  MarketplacePlatformInfo? platform,
  String provider,
) {
  final label = platform != null
      ? marketplacePlatformDisplayLabel(l10n, platform)
      : provider;
  return switch (provider) {
    'zomato' => l10n.ordersEmptyZomato,
    'swiggy' => l10n.ordersEmptySwiggy,
    _ => 'No $label orders today.',
  };
}
