import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/pos_app_info.dart';

/// Broadcasts the resolved light/dark mode so screens that paint with
/// [PosTheme] static colors rebuild when appearance changes.
class PosThemeBrightness extends InheritedWidget {
  const PosThemeBrightness({
    super.key,
    required this.brightness,
    required super.child,
  });

  final Brightness brightness;

  static Brightness? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PosThemeBrightness>()
        ?.brightness;
  }

  @override
  bool updateShouldNotify(PosThemeBrightness oldWidget) =>
      brightness != oldWidget.brightness;
}

/// POS-native visual language: cool slate surfaces + build-branded action accent.
///
/// Accent comes from `branding.yaml` → [PosAppInfo.primaryColor] (synced).
/// Intentionally does **not** follow per-restaurant `primary_color` — registers
/// need a consistent UI across tenants. Semantic colors resolve from
/// [brightness], which [ServeAiPosApp] keeps in sync with the active [ThemeData].
class PosTheme {
  static Brightness _brightness = Brightness.light;

  /// Active palette brightness (light/dark). Updated from [MaterialApp.builder].
  static Brightness get brightness => _brightness;

  static bool get isDark => _brightness == Brightness.dark;

  /// Call from [MaterialApp.builder] whenever the resolved theme changes.
  static void applyBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  /// Header chrome scale (icons, padding, Open/Shift chips).
  static const headerScale = 1.02;

  static double headerPx(double value) =>
      double.parse((value * headerScale).toStringAsFixed(1));

  /// Depend on appearance so this [BuildContext] rebuilds on light/dark changes.
  ///
  /// Call once at the top of any [State.build] that reads [PosTheme] colors.
  /// Without this, [ThemeData] can flip while static [PosTheme] paints stay stale.
  static Brightness bind(BuildContext context) {
    final resolved =
        PosThemeBrightness.maybeOf(context) ?? Theme.of(context).brightness;
    applyBrightness(resolved);
    return resolved;
  }

  // —— Light palette ——
  static const Color canvasLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color hairlineLight = Color(0x1A0F172A);
  static const Color inkLight = Color(0xFF0F172A);
  static const Color inkMutedLight = Color(0xFF64748B);
  static const Color inkFaintLight = Color(0xFF94A3B8);

  // —— Dark palette (slate) ——
  static const Color canvasDark = Color(0xFF0B1220);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color surfaceMutedDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color hairlineDark = Color(0x33F8FAFC);
  static const Color inkDark = Color(0xFFF8FAFC);
  static const Color inkMutedDark = Color(0xFF94A3B8);
  static const Color inkFaintDark = Color(0xFF64748B);

  // —— Semantic getters (brightness-aware) ——
  static Color get canvas => isDark ? canvasDark : canvasLight;
  static Color get surface => isDark ? surfaceDark : surfaceLight;
  static Color get surfaceMuted => isDark ? surfaceMutedDark : surfaceMutedLight;
  static Color get opsBarBg => canvas;
  static Color get searchFill => surfaceMuted;
  static Color get border => isDark ? borderDark : borderLight;
  static Color get hairline => isDark ? hairlineDark : hairlineLight;
  static Color get ink => isDark ? inkDark : inkLight;
  static Color get inkMuted => isDark ? inkMutedDark : inkMutedLight;
  static Color get inkFaint => isDark ? inkFaintDark : inkFaintLight;
  static Color get categoryActive => ink;

  /// Always-light plate behind restaurant logos so dark wordmarks stay visible.
  static const Color logoPlate = Color(0xFFFFFFFF);
  static const Color logoPlateBorder = Color(0xFFE2E8F0);

  static const Color holdAmber = Color(0xFFF59E0B);
  static const Color holdAmberDark = Color(0xFFD97706);

  /// Build-branded action accent — selection, focus, chrome. Not restaurant-branded.
  static const Color accent = Color(PosAppInfo.primaryColorArgb);

  /// Alias used by older call sites; always [accent].
  static const Color defaultAccent = accent;

  /// Stronger CTA for “charge / pay” moments (darkened brand accent).
  static Color get payAccent => Color.lerp(accent, const Color(0xFF000000), 0.18)!;

  static const double cartPanelWidth = 472;

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;

  static const double compactWidthBreakpoint = 700;
  static const double shortHeightBreakpoint = 720;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactWidthBreakpoint;

  static bool isShort(BuildContext context) =>
      MediaQuery.sizeOf(context).height < shortHeightBreakpoint;

  /// Restaurant hex accents are ignored — POS uses build [accent] only.
  static Color parseAccent(String? hex) => accent;

  static ThemeData build({
    @Deprecated('POS ignores restaurant seed colors; always uses PosTheme.accent')
    Color? seedColor,
    Brightness brightness = Brightness.light,
  }) {
    final dark = brightness == Brightness.dark;
    final canvasColor = dark ? canvasDark : canvasLight;
    final surfaceColor = dark ? surfaceDark : surfaceLight;
    final muted = dark ? surfaceMutedDark : surfaceMutedLight;
    final borderColor = dark ? borderDark : borderLight;
    final inkColor = dark ? inkDark : inkLight;
    final inkMutedColor = dark ? inkMutedDark : inkMutedLight;
    final inkFaintColor = dark ? inkFaintDark : inkFaintLight;
    final pay = payAccent;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: surfaceColor,
      primary: accent,
      secondary: pay,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvasColor,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: inkColor,
      displayColor: inkColor,
    ).copyWith(
      displaySmall: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        color: inkColor,
        fontSize: 32,
        letterSpacing: -0.8,
        height: 1.1,
      ),
      headlineSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w800,
        color: inkColor,
        fontSize: 24,
        letterSpacing: -0.4,
      ),
      titleLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        color: inkColor,
        fontSize: 18,
      ),
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        color: inkColor,
        fontSize: 15,
      ),
      bodyLarge: GoogleFonts.inter(color: inkColor, height: 1.45, fontSize: 15),
      bodyMedium:
          GoogleFonts.inter(color: inkMutedColor, height: 1.45, fontSize: 13),
      bodySmall:
          GoogleFonts.inter(color: inkFaintColor, height: 1.35, fontSize: 12),
      labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surfaceColor,
        foregroundColor: inkColor,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: inkColor),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: borderColor),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor.withValues(alpha: 0.95)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? surfaceMutedDark : inkLight,
        contentTextStyle: TextStyle(
          color: dark ? inkDark : surfaceLight,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: borderColor,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: borderColor),
        ),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return dark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1);
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          final disabled = states.contains(WidgetState.disabled);
          if (selected) {
            return accent.withValues(alpha: disabled ? 0.35 : 1);
          }
          return disabled
              ? muted.withValues(alpha: 0.55)
              : (dark ? const Color(0xFF475569) : const Color(0xFFCBD5E1));
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return Colors.transparent;
        }),
      ),
    );
  }

  static List<BoxShadow> cardShadow([Color? tint]) {
    final baseAlpha = isDark ? 0.35 : 0.05;
    final softAlpha = isDark ? 0.2 : 0.03;
    return [
      BoxShadow(
        color: (tint ?? Colors.black)
            .withValues(alpha: tint == null ? baseAlpha : (isDark ? 0.4 : 0.12)),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: softAlpha),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> buttonShadow(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: isDark ? 0.4 : 0.28),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> elevatedBarShadow() => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, -8),
        ),
      ];

  static LinearGradient brandGradient(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(accent, const Color(0xFF0F172A), 0.35)!,
          accent,
          Color.lerp(accent, Colors.white, isDark ? 0.08 : 0.18)!,
        ],
        stops: const [0, 0.55, 1],
      );

  static LinearGradient softCanvasGradient(Color accent) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(canvas, accent, isDark ? 0.12 : 0.06)!,
          canvas,
          surfaceMuted,
        ],
        stops: const [0, 0.45, 1],
      );

  static LinearGradient ctaGradient(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(accent, Colors.white, isDark ? 0.06 : 0.12)!,
          accent,
          Color.lerp(accent, const Color(0xFF0F172A), 0.18)!,
        ],
      );

  /// Modal / dialog title bar gradient — deeper blues in dark mode so headers
  /// sit cleanly on slate surfaces instead of neon bright blue.
  static LinearGradient modalHeaderGradient({
    Color? seed,
    PosModalHeaderTone tone = PosModalHeaderTone.accent,
  }) {
    final colors = switch (tone) {
      PosModalHeaderTone.accent => isDark
          ? const [Color(0xFF1E3A8A), Color(0xFF1D4ED8)]
          : [
              seed ?? accent,
              Color.lerp(seed ?? accent, const Color(0xFF0F172A), 0.22)!,
            ],
      PosModalHeaderTone.success => isDark
          ? const [Color(0xFF064E3B), Color(0xFF047857)]
          : const [Color(0xFF059669), Color(0xFF047857)],
      PosModalHeaderTone.danger => isDark
          ? const [Color(0xFF881337), Color(0xFFBE123C)]
          : const [Color(0xFFE11D48), Color(0xFFBE123C)],
      PosModalHeaderTone.warning => isDark
          ? const [Color(0xFF78350F), Color(0xFFB45309)]
          : const [Color(0xFFF59E0B), Color(0xFFD97706)],
    };

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  /// Icon color for the white badge on [modalHeaderGradient] headers.
  static Color modalHeaderIconColor({
    PosModalHeaderTone tone = PosModalHeaderTone.accent,
  }) {
    return switch (tone) {
      PosModalHeaderTone.accent => isDark ? payAccent : accent,
      PosModalHeaderTone.success => const Color(0xFF047857),
      PosModalHeaderTone.danger => const Color(0xFFBE123C),
      PosModalHeaderTone.warning => const Color(0xFFB45309),
    };
  }
}

enum PosModalHeaderTone { accent, success, danger, warning }

Color posAccent(BuildContext context, {String? primaryColorHex}) {
  // Restaurant primary colors are ignored; keep a stable POS accent.
  return Theme.of(context).colorScheme.primary;
}

({Color bg, Color fg}) posAccentSoft(Color accent) {
  if (PosTheme.isDark) {
    return (
      bg: Color.lerp(PosTheme.surfaceMutedDark, accent, 0.32)!,
      fg: Color.lerp(accent, Colors.white, 0.62)!,
    );
  }
  return (
    bg: Color.lerp(Colors.white, accent, 0.12)!,
    fg: Color.lerp(accent, PosTheme.inkLight, 0.35)!,
  );
}

/// Text/icon color that stays readable on a filled [color] chip.
Color posOnColor(Color color) =>
    color.computeLuminance() > 0.55 ? PosTheme.inkLight : Colors.white;

/// Selected / idle chip tones that work in light and dark.
({Color bg, Color border, Color fg}) posTintedChip(
  Color color, {
  required bool selected,
}) {
  if (selected) {
    final fg = posOnColor(color);
    return (bg: color, border: color, fg: fg);
  }
  if (PosTheme.isDark) {
    final soft = posAccentSoft(color);
    return (
      bg: soft.bg,
      border: soft.fg.withValues(alpha: 0.38),
      fg: soft.fg,
    );
  }
  return (
    bg: color.withValues(alpha: 0.12),
    border: color.withValues(alpha: 0.35),
    fg: color,
  );
}

({Color bg, Color fg}) posStatusColors(String? status, {Color? accent}) {
  final brand = accent != null ? posAccentSoft(accent) : null;
  final dark = PosTheme.isDark;
  switch ((status ?? '').toLowerCase()) {
    case 'pending':
    case 'draft':
    case 'confirmed':
      return brand ??
          (dark
              ? (bg: const Color(0xFF422006), fg: const Color(0xFFFDE68A))
              : (bg: const Color(0xFFFEF3C7), fg: const Color(0xFF92400E)));
    case 'preparing':
      return brand ??
          (dark
              ? (bg: const Color(0xFF431407), fg: const Color(0xFFFDBA74))
              : (bg: const Color(0xFFFFEDD5), fg: const Color(0xFF9A3412)));
    case 'ready':
    case 'completed':
    case 'delivered':
    case 'paid':
      return dark
          ? (bg: const Color(0xFF052E16), fg: const Color(0xFF86EFAC))
          : (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF166534));
    case 'cancelled':
    case 'failed':
      return dark
          ? (bg: const Color(0xFF4C0519), fg: const Color(0xFFFAA2B0))
          : (bg: const Color(0xFFFFE4E6), fg: const Color(0xFFBE123C));
    case 'abandoned':
    case 'cleaning':
      return dark
          ? (bg: const Color(0xFF1E293B), fg: const Color(0xFFCBD5E1))
          : (bg: const Color(0xFFF1F5F9), fg: const Color(0xFF475569));
    default:
      return (bg: PosTheme.surfaceMuted, fg: PosTheme.inkMuted);
  }
}
