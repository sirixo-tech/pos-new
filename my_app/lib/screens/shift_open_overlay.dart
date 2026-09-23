import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/pos_l10n.dart';
import '../providers/pos_controller.dart';
import '../theme/pos_theme.dart';
import '../utils/pos_animations.dart';
import '../widgets/pos_ui.dart';

class ShiftOpenOverlay extends StatefulWidget {
  const ShiftOpenOverlay({super.key});

  @override
  State<ShiftOpenOverlay> createState() => _ShiftOpenOverlayState();
}

class _ShiftOpenOverlayState extends State<ShiftOpenOverlay> {
  final _floatController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _floatFocus = FocusNode();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _floatFocus.requestFocus();
      _floatController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _floatController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _notesController.dispose();
    _floatFocus.dispose();
    super.dispose();
  }

  Future<void> _openShift() async {
    final value = double.tryParse(_floatController.text.trim()) ?? 0;
    setState(() => _loading = true);
    try {
      await context.read<PosController>().openShift(
            value,
            notes: _notesController.text.trim(),
          );
      if (mounted) showPosSnackBar(context, context.l10n.shiftOpenedSnack);
    } catch (e) {
      if (mounted) showPosErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pos = context.watch<PosController>();
    final accent = Theme.of(context).colorScheme.primary;
    final soft = posAccentSoft(accent);
    final branchName = pos.bootstrap?.branch.name ?? l10n.shiftThisBranch;
    final currency = pos.currency;

    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PosSlideFade(
              child: Material(
                color: PosTheme.surface,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      decoration: BoxDecoration(
                        gradient: PosTheme.modalHeaderGradient(
                          tone: PosModalHeaderTone.success,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.16),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.lock_open_rounded,
                              color: PosTheme.modalHeaderIconColor(
                                tone: PosModalHeaderTone.success,
                              ),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.shiftOpenRequiredTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.shiftRequiredSubtitle,
                                  style: const TextStyle(
                                    color: Color(0xD9FFFFFF),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: soft.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storefront_outlined,
                                  size: 18,
                                  color: soft.fg,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.shiftOpeningFloatFor(branchName),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: soft.fg,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            l10n.shiftOpeningFloat,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: PosTheme.ink.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _floatController,
                            focusNode: _floatFocus,
                            enabled: !_loading,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: PosTheme.canvas,
                              prefixIcon: Padding(
                                padding:
                                    const EdgeInsets.only(left: 14, right: 6),
                                child: Text(
                                  currency,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: soft.fg,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                              hintText: '0.00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: PosTheme.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: PosTheme.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: accent, width: 1.6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                            ),
                            onSubmitted: (_) => _openShift(),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.shiftOpeningFloatHelp,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: PosTheme.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.shiftNotes,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: PosTheme.ink.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            enabled: !_loading,
                            maxLines: 2,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: PosTheme.canvas,
                              hintText: l10n.shiftOpenNotesHint,
                              hintStyle: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: PosTheme.inkFaint,
                              ),
                              prefixIcon: Icon(
                                Icons.notes_rounded,
                                size: 20,
                                color: PosTheme.inkMuted,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: PosTheme.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: PosTheme.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: accent, width: 1.6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          PosPrimaryButton(
                            label: _loading
                                ? l10n.shiftOpening
                                : l10n.opsOpenShift,
                            icon: Icons.play_arrow_rounded,
                            loading: _loading,
                            color: const Color(0xFF16A34A),
                            onPressed: _openShift,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
