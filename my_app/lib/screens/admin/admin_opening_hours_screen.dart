import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/opening_hours_models.dart';
import '../../providers/pos_controller.dart';
import '../../services/pos_api.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_ui.dart';
import 'admin_chrome.dart';

class AdminOpeningHoursScreen extends StatefulWidget {
  const AdminOpeningHoursScreen({super.key});

  @override
  State<AdminOpeningHoursScreen> createState() =>
      _AdminOpeningHoursScreenState();
}

class _AdminOpeningHoursScreenState extends State<AdminOpeningHoursScreen> {
  static const _dayLabels = {
    'mon': 'Mon',
    'tue': 'Tue',
    'wed': 'Wed',
    'thu': 'Thu',
    'fri': 'Fri',
    'sat': 'Sat',
    'sun': 'Sun',
  };

  bool _loading = true;
  bool _saving = false;
  String? _error;
  PosGuestOrdering _guest = const PosGuestOrdering();
  bool _acceptOnline = true;
  bool _scheduleEnabled = false;
  String _timezone = 'UTC';
  List<String> _timezones = const [];
  final _closedMessageCtrl = TextEditingController();
  Map<String, List<_ShiftDraft>> _schedule = {
    for (final day in PosOpeningHours.days) day: <_ShiftDraft>[],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _closedMessageCtrl.dispose();
    for (final shifts in _schedule.values) {
      for (final shift in shifts) {
        shift.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payload = await context.read<PosApi>().fetchOpeningHours(session);
      _applyPayload(payload);
      pos.applyOpeningHoursPayload(payload);
    } on PosApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = context.l10n.commonSomethingWentWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyPayload(PosOpeningHoursPayload payload) {
    for (final shifts in _schedule.values) {
      for (final shift in shifts) {
        shift.dispose();
      }
    }
    _guest = payload.guestOrdering;
    _acceptOnline = payload.acceptOnlineOrders;
    _scheduleEnabled = payload.openingHours.enabled;
    _timezone = payload.openingHours.timezone;
    _timezones = payload.timezones;
    _closedMessageCtrl.text = payload.openingHours.closedMessage;
    _schedule = {
      for (final day in PosOpeningHours.days)
        day: [
          for (final range in payload.openingHours.schedule[day] ?? const [])
            _ShiftDraft.fromRange(range),
        ],
    };
  }

  Future<void> _save() async {
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;

    setState(() => _saving = true);
    try {
      final schedule = <String, List<String>>{};
      for (final day in PosOpeningHours.days) {
        schedule[day] = [
          for (final shift in _schedule[day] ?? const <_ShiftDraft>[])
            if (shift.isValid) shift.asRange,
        ];
      }

      final payload = await context.read<PosApi>().updateOpeningHours(
            session,
            acceptOnlineOrders: _acceptOnline,
            openingHoursEnabled: _scheduleEnabled,
            timezone: _timezone,
            schedule: schedule,
            closedMessage: _closedMessageCtrl.text.trim(),
          );
      if (!mounted) return;
      _applyPayload(payload);
      pos.applyOpeningHoursPayload(payload);
      showPosSnackBar(context, context.l10n.storeHoursSaved);
      setState(() {});
    } on PosApiException catch (e) {
      if (mounted) showPosSnackBar(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showPosSnackBar(
          context,
          context.l10n.commonSomethingWentWrong,
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _copyMondayToWeekdays() {
    final mondayRanges = [
      for (final shift in _schedule['mon'] ?? const <_ShiftDraft>[])
        (start: shift.start, end: shift.end),
    ];
    setState(() {
      for (final day in const ['tue', 'wed', 'thu', 'fri']) {
        for (final old in _schedule[day] ?? const <_ShiftDraft>[]) {
          old.dispose();
        }
        _schedule[day] = [
          for (final range in mondayRanges)
            _ShiftDraft(start: range.start, end: range.end),
        ];
      }
    });
  }

  Future<void> _pickTime(_ShiftDraft shift, {required bool isStart}) async {
    final initial = isStart ? shift.startTod : shift.endTod;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        shift.start = _formatTod(picked);
      } else {
        shift.end = _formatTod(picked);
      }
    });
  }

  String _formatTod(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _statusTitle(PosGuestOrdering guest) {
    final l10n = context.l10n;
    if (guest.open) return l10n.storeGuestStatusOpen;
    if (guest.isPaused || !guest.acceptOnlineOrders) {
      return l10n.storeGuestStatusPaused;
    }
    if (guest.isOutsideHours) return l10n.storeGuestStatusOutsideHours;
    return l10n.storeGuestStatusOther;
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final accent = Theme.of(context).colorScheme.primary;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.adminHours),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AdminEmptyPane(
                  icon: Icons.error_outline_rounded,
                  title: _error!,
                  subtitle: l10n.commonTryAgain,
                  action: TextButton(
                    onPressed: _load,
                    child: Text(l10n.commonRetry),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          _StatusBanner(
                            guest: _guest,
                            title: _statusTitle(_guest),
                            opensLabel: _guest.nextOpensLabel,
                          ),
                          const SizedBox(height: 16),
                          AdminEntityCard(
                            icon: Icons.storefront_rounded,
                            title: l10n.storeAcceptOnlineOrders,
                            subtitle: l10n.storeAcceptOnlineOrdersHelp,
                            trailing: Switch(
                              value: _acceptOnline,
                              onChanged: (v) =>
                                  setState(() => _acceptOnline = v),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AdminEntityCard(
                            icon: Icons.schedule_rounded,
                            title: l10n.storeScheduleEnabled,
                            subtitle: l10n.storeScheduleEnabledHelp,
                            trailing: Switch(
                              value: _scheduleEnabled,
                              onChanged: (v) =>
                                  setState(() => _scheduleEnabled = v),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.storeTimezone,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: PosTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _timezones.contains(_timezone)
                                ? _timezone
                                : (_timezones.isNotEmpty
                                    ? _timezones.first
                                    : null),
                            items: [
                              for (final tz in (_timezones.isEmpty
                                  ? [_timezone]
                                  : _timezones))
                                DropdownMenuItem(value: tz, child: Text(tz)),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _timezone = v);
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: PosTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _closedMessageCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: l10n.storeClosedMessage,
                              hintText: l10n.storeClosedMessageHint,
                              filled: true,
                              fillColor: PosTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.storeScheduleTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed:
                                    _scheduleEnabled ? _copyMondayToWeekdays : null,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: Text(l10n.storeCopyWeekdays),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.storePosNote,
                            style: TextStyle(
                              color: PosTheme.inkMuted,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final day in PosOpeningHours.days) ...[
                            _DayCard(
                              label: _dayLabels[day] ?? day,
                              enabled: _scheduleEnabled,
                              shifts: _schedule[day]!,
                              onAdd: () {
                                if ((_schedule[day]!.length) >= 4) return;
                                setState(() {
                                  _schedule[day]!.add(
                                    _ShiftDraft(start: '09:00', end: '17:00'),
                                  );
                                });
                              },
                              onRemove: (index) {
                                setState(() {
                                  _schedule[day]![index].dispose();
                                  _schedule[day]!.removeAt(index);
                                });
                              },
                              onPickStart: (index) =>
                                  _pickTime(_schedule[day]![index], isStart: true),
                              onPickEnd: (index) =>
                                  _pickTime(_schedule[day]![index], isStart: false),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        decoration: BoxDecoration(
                          color: PosTheme.surface,
                          border: Border(
                            top: BorderSide(color: PosTheme.border),
                          ),
                        ),
                        child: PosPrimaryButton(
                          label: l10n.commonSave,
                          icon: Icons.check_rounded,
                          loading: _saving,
                          color: accent,
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.guest,
    required this.title,
    this.opensLabel,
  });

  final PosGuestOrdering guest;
  final String title;
  final String? opensLabel;

  @override
  Widget build(BuildContext context) {
    final open = guest.open;
    final tone = posStatusColors(
      open ? 'ready' : (guest.isPaused ? 'cancelled' : 'pending'),
    );
    final color = tone.fg;
    final bg = tone.bg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                open
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (opensLabel != null && opensLabel!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.storeOpensAt(opensLabel!),
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.label,
    required this.enabled,
    required this.shifts,
    required this.onAdd,
    required this.onRemove,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String label;
  final bool enabled;
  final List<_ShiftDraft> shifts;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onPickStart;
  final ValueChanged<int> onPickEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final closed = shifts.isEmpty;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PosTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PosTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  child: Text(
                    closed ? l10n.storeDayClosed : '${shifts.length} shift(s)',
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: enabled && shifts.length < 4 ? onAdd : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.storeAddShift),
                ),
              ],
            ),
            for (var i = 0; i < shifts.length; i++) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: enabled ? () => onPickStart(i) : null,
                      child: Text(shifts[i].start),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, size: 16),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: enabled ? () => onPickEnd(i) : null,
                      child: Text(shifts[i].end),
                    ),
                  ),
                  IconButton(
                    onPressed: enabled ? () => onRemove(i) : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: const Color(0xFFB91C1C),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShiftDraft {
  _ShiftDraft({required this.start, required this.end});

  factory _ShiftDraft.fromRange(String range) {
    final parts = range.split('-');
    final start = parts.isNotEmpty ? parts[0].trim() : '09:00';
    final end = parts.length > 1 ? parts[1].trim() : '17:00';
    return _ShiftDraft(
      start: _normalize(start),
      end: _normalize(end),
    );
  }

  String start;
  String end;

  bool get isValid =>
      RegExp(r'^\d{2}:\d{2}$').hasMatch(start) &&
      RegExp(r'^\d{2}:\d{2}$').hasMatch(end);

  String get asRange => '$start-$end';

  TimeOfDay get startTod => _parse(start);
  TimeOfDay get endTod => _parse(end);

  static String _normalize(String value) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return '09:00';
    final h = int.parse(match.group(1)!).clamp(0, 23);
    final m = int.parse(match.group(2)!).clamp(0, 59);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static TimeOfDay _parse(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  void dispose() {}
}
