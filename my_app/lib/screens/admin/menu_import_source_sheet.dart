import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/pos_theme.dart';
import '../../widgets/pos_overlay.dart';

enum MenuImportSource { photo, voice, zomato }

enum MenuFilePick { camera, photo, pdf }

Future<MenuFilePick?> showMenuImportFileSheet(BuildContext context) {
  return showModalBottomSheet<MenuFilePick>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => const PosKeyboardSheetHost(child: _FilePickSheet()),
  );
}

Future<MenuImportSource?> showMenuImportSourceSheet(
  BuildContext context, {
  required bool enableVoice,
}) {
  return showModalBottomSheet<MenuImportSource>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => PosKeyboardSheetHost(
      child: _SourceSheet(enableVoice: enableVoice),
    ),
  );
}

class MenuImportSourcePage extends StatelessWidget {
  const MenuImportSourcePage({super.key, required this.enableVoice, required this.onSelect});
  final bool enableVoice;
  final ValueChanged<MenuImportSource> onSelect;

  @override
  Widget build(BuildContext context) => _SourceSheet(
    enableVoice: enableVoice, fullPage: true, onSelect: onSelect,
  );
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.enableVoice, this.fullPage = false, this.onSelect});

  final bool enableVoice;
  final bool fullPage;
  final ValueChanged<MenuImportSource>? onSelect;

  void _select(BuildContext context, MenuImportSource source) {
    if (onSelect != null) {
      onSelect!(source);
    } else {
      Navigator.pop(context, source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final choices = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MenuMark(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Menu Upload',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.3,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pick one way. You confirm every price before it is saved.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: PosTheme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SourceTile(
          mark: const _FileMark(),
          title: 'Photo or PDF',
          subtitle: 'A photo of the printed menu, a PDF, or a spreadsheet.',
          detail: 'Best when the menu is already on paper or in a file.',
          onTap: () => _select(context, MenuImportSource.photo),
        ),
        if (enableVoice) ...[
          const SizedBox(height: 10),
          _SourceTile(
            mark: const _VoiceMark(),
            title: 'Voice',
            subtitle: 'Say each item, then its price.',
            detail: 'Best for a short list you can read aloud.',
            onTap: () => _select(context, MenuImportSource.voice),
          ),
        ],
        const SizedBox(height: 10),
        _SourceTile(
          mark: const ZomatoMark(size: 48),
          title: 'Zomato',
          subtitle: 'Paste the outlet share link from the partner app.',
          detail: 'Best when this menu is already live on Zomato.',
          onTap: () => _select(context, MenuImportSource.zomato),
        ),
      ],
    );
    if (fullPage) return choices;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: fullPage ? double.infinity : posMobileSheetHeight(context, factor: 0.86),
          maxWidth: fullPage ? double.infinity : (size.width >= 900 ? 560 : size.width),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: PosTheme.surface,
            borderRadius: fullPage ? BorderRadius.zero : const BorderRadius.vertical(
              top: Radius.circular(PosTheme.radiusXl),
            ),
            border: size.width >= 900
                ? Border.all(color: PosTheme.border)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PosTheme.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    choices,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilePickSheet extends StatelessWidget {
  const _FilePickSheet();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: PosTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(PosTheme.radiusXl)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: PosTheme.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add a photo or PDF',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: PosTheme.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'The phone will ask for camera or photo access if it needs it.',
                                style: TextStyle(fontSize: 13, height: 1.35, color: PosTheme.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _FileChoice(
                    icon: Icons.photo_camera_rounded,
                    color: accent,
                    title: 'Camera',
                    subtitle: 'Photograph the menu',
                    onTap: () => Navigator.pop(context, MenuFilePick.camera),
                  ),
                  _FileChoice(
                    icon: Icons.photo_rounded,
                    color: const Color(0xFF1D4ED8),
                    title: 'Photo',
                    subtitle: 'Choose a picture already on this phone',
                    onTap: () => Navigator.pop(context, MenuFilePick.photo),
                  ),
                  _FileChoice(
                    icon: Icons.picture_as_pdf_rounded,
                    color: const Color(0xFFB91C1C),
                    title: 'PDF',
                    subtitle: 'Choose a PDF of the menu',
                    onTap: () => Navigator.pop(context, MenuFilePick.pdf),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileChoice extends StatelessWidget {
  const _FileChoice({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(subtitle, style: TextStyle(fontSize: 12.5, color: PosTheme.inkMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: PosTheme.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ZomatoMark extends StatelessWidget {
  const ZomatoMark({super.key, this.size = 44});

  final double size;

  static const red = Color(0xFFE23744);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: size * 0.08),
      decoration: BoxDecoration(
        color: red,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: FittedBox(
        child: Text(
          'zomato',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.8,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _MenuMark extends StatelessWidget {
  const _MenuMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Icon(Icons.menu_book_rounded, color: Color(0xFF1E293B), size: 22),
    );
  }
}

class _FileMark extends StatelessWidget {
  const _FileMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.description_outlined, color: Color(0xFF1D4ED8), size: 24),
    );
  }
}

class _VoiceMark extends StatelessWidget {
  const _VoiceMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.mic_none_rounded, color: Color(0xFFC2410C), size: 24),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.mark,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.onTap,
  });

  final Widget mark;
  final String title;
  final String subtitle;
  final String detail;
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
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PosTheme.border),
          ),
          child: Row(
            children: [
              mark,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        letterSpacing: -0.2,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: PosTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: PosTheme.inkMuted,
                      ),
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

class ZomatoMenuPanel extends StatefulWidget {
  const ZomatoMenuPanel({
    super.key,
    required this.busy,
    required this.onFetch,
    required this.onBack,
  });

  final bool busy;
  final Future<void> Function(String input) onFetch;
  final VoidCallback onBack;

  @override
  State<ZomatoMenuPanel> createState() => _ZomatoMenuPanelState();
}

class _ZomatoMenuPanelState extends State<ZomatoMenuPanel> {
  final _link = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _openPartnerApp() async {
    final android = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.application.services.partner',
    );
    final apple = Uri.parse(
      'https://apps.apple.com/search?term=Zomato%20Restaurant%20Partner',
    );
    final platform = Theme.of(context).platform;
    final uri = platform == TargetPlatform.iOS ? apple : android;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _localError = 'The Zomato Partner app link could not be opened.');
    }
  }

  Future<void> _fetch() async {
    setState(() => _localError = null);
    try {
      await widget.onFetch(_link.text);
    } catch (error) {
      if (!mounted) return;
      setState(() => _localError = '$error'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: widget.busy ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const ZomatoMark(size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Zomato menu',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.3,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _link,
            enabled: !widget.busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _fetch(),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              labelText: 'Outlet link or restaurant ID',
              hintText: 'https://www.zomato.com/…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.busy ? null : _fetch,
            style: FilledButton.styleFrom(
              backgroundColor: ZomatoMark.red,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: widget.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Fetch menu'),
          ),
          if (_localError != null) ...[
            const SizedBox(height: 10),
            Text(
              _localError!,
              style: const TextStyle(color: Color(0xFFB42318), fontSize: 13, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'In the Zomato Partner app, open Manage outlet, tap share, and paste the link. A restaurant ID works too.',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.busy ? null : _openPartnerApp,
            icon: const Icon(Icons.open_in_new_rounded, size: 18, color: ZomatoMark.red),
            label: const Text('Open Zomato Partner app'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ZomatoMark.red,
              minimumSize: const Size(0, 46),
              side: const BorderSide(color: Color(0xFFF3C1C4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

