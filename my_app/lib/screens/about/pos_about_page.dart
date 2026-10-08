import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/pos_app_info.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_overlay.dart';
import 'pos_legal_copy.dart';

Future<void> showPosAboutSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => const PosKeyboardSheetHost(child: _AboutSheet()),
  );
}

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final accent = Theme.of(context).colorScheme.primary;
    return _PosSheetFrame(
      accent: accent,
      icon: Icons.info_outline_rounded,
      title: 'About',
      subtitle: 'Version ${PosAppInfo.versionLabel}',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PosTheme.logoPlate,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PosTheme.logoPlateBorder),
                  ),
                  child: Image.asset(
                    PosAppInfo.emblemAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.point_of_sale_rounded,
                      color: PosTheme.ink,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                PosAppInfo.displayName,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: PosTheme.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version ${PosAppInfo.versionLabel}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PosTheme.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The register for orders, payments, kitchen tickets, and the menu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.4, color: PosTheme.inkMuted),
              ),
              const SizedBox(height: 28),
              _AboutLink(
                icon: Icons.article_outlined,
                title: 'Terms & conditions',
                subtitle: 'How this register is meant to be used',
                onTap: () => showPosLegalSheet(
                  context,
                  title: 'Terms & conditions',
                  subtitle: 'Updated $posLegalUpdated',
                  icon: Icons.article_outlined,
                  intro: posTermsIntro,
                  sections: posTermsSections,
                ),
              ),
              const SizedBox(height: 10),
              _AboutLink(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy policy',
                subtitle: 'What the register stores and sends',
                onTap: () => showPosLegalSheet(
                  context,
                  title: 'Privacy policy',
                  subtitle: 'Updated $posLegalUpdated',
                  icon: Icons.privacy_tip_outlined,
                  intro: posPrivacyIntro,
                  sections: posPrivacySections,
                ),
              ),
            ],
          ),
    );
  }
}

Future<void> showPosLegalSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required List<PosLegalSection> sections,
  String? intro,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => PosKeyboardSheetHost(
      child: _LegalSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        intro: intro,
        sections: sections,
      ),
    ),
  );
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PosTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PosTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: PosTheme.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: PosTheme.inkMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: PosTheme.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalSheet extends StatelessWidget {
  const _LegalSheet({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.sections,
    this.intro,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<PosLegalSection> sections;
  final String? intro;

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    return _PosSheetFrame(
      accent: accent,
      icon: icon,
      title: title,
      subtitle: subtitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [soft.bg, PosTheme.surface],
                  ),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: PosTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: PosTheme.border),
                      ),
                      child: Text(
                        'Updated $posLegalUpdated',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: soft.fg,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.1,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      posLegalProduct,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PosTheme.ink,
                      ),
                    ),
                    Text(
                      posLegalEntity,
                      style: TextStyle(fontSize: 13, height: 1.4, color: PosTheme.inkMuted),
                    ),
                    if (intro != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        intro!,
                        style: TextStyle(fontSize: 14, height: 1.5, color: PosTheme.ink),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < sections.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LegalCard(index: i + 1, section: sections[i], accent: accent),
                ),
              const _LegalContactCard(),
            ],
          ),
    );
  }
}

class _PosSheetFrame extends StatelessWidget {
  const _PosSheetFrame({
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    final size = MediaQuery.sizeOf(context);
    final maxHeight = posMobileSheetHeight(context);
    final sheetMaxWidth = size.width >= 900 ? 720.0 : size.width;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: sheetMaxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: PosTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(PosTheme.radiusXl)),
            border: size.width >= 900 ? Border.all(color: PosTheme.border) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: soft.bg,
                        borderRadius: BorderRadius.circular(PosTheme.radiusSm),
                        border: Border.all(color: accent.withValues(alpha: 0.2)),
                      ),
                      child: Icon(icon, color: soft.fg, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              letterSpacing: -0.2,
                              color: PosTheme.ink,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: PosTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: PosTheme.border),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({
    required this.index,
    required this.section,
    required this.accent,
  });

  final int index;
  final PosLegalSection section;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: posAccentSoft(accent).bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: posAccentSoft(accent).fg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title.replaceFirst(RegExp(r'^\d+\.\s*'), ''),
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: PosTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final paragraph in section.paragraphs)
            paragraph.startsWith('• ')
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(top: 7, right: 8),
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            paragraph.substring(2),
                            style: TextStyle(fontSize: 14, height: 1.45, color: PosTheme.ink),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      paragraph,
                      style: TextStyle(fontSize: 14, height: 1.5, color: PosTheme.ink),
                    ),
                  ),
        ],
      ),
    );
  }
}

class _LegalContactCard extends StatelessWidget {
  const _LegalContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            posLegalEntity,
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          _contactLine('Privacy', posPrivacyEmail),
          _contactLine('General', posLegalEmail),
          _contactLine('Phone', posLegalPhone),
          _contactLine('Web', posLegalWeb),
        ],
      ),
    );
  }

  Widget _contactLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
