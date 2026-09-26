import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/pos_l10n.dart';
import '../../models/admin_models.dart';
import '../../providers/pos_admin_controller.dart';
import '../../theme/pos_theme.dart';
import '../../widgets/pos_ui.dart';
import 'admin_chrome.dart';

class AdminTimeSlotsScreen extends StatefulWidget {
  const AdminTimeSlotsScreen({super.key});

  @override
  State<AdminTimeSlotsScreen> createState() => _AdminTimeSlotsScreenState();
}

class _AdminTimeSlotsScreenState extends State<AdminTimeSlotsScreen> {
  static const _dayShort = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<PosAdminController>();
      if (admin.timeSlots.isEmpty) {
        admin.loadMenu();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminMenuTimeSlot> _filtered(List<AdminMenuTimeSlot> slots) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return slots;
    return slots.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.windowLabel.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<PosAdminController>();
    final canManage =
        admin.canManageMenuTimeSlots || admin.canManageMenu;
    final slots = _filtered(admin.timeSlots);
    final activeCount = admin.timeSlots.where((s) => s.isActive).length;
    final liveCount =
        admin.timeSlots.where((s) => s.isLive && s.isActive).length;

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.posText('adminTimeSlots', 'Time slots')),
        actions: [
          IconButton(
            tooltip: context.l10n.commonClose,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: admin.menuLoading && admin.timeSlots.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : admin.error != null && admin.timeSlots.isEmpty
              ? AdminErrorPane(
                  message: admin.error!,
                  onRetry: admin.loadMenu,
                )
              : Column(
                  children: [
                    AdminToolbar(
                      leading: SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: context.posText(
                              'adminTimeSlotsSearch',
                              'Search time slots',
                            ),
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: context.l10n.commonClear,
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                            isDense: true,
                            filled: true,
                            fillColor: PosTheme.surfaceMuted,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(PosTheme.radiusSm),
                              borderSide: BorderSide(color: PosTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(PosTheme.radiusSm),
                              borderSide: BorderSide(color: PosTheme.border),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      children: [
                        IconButton.filledTonal(
                          tooltip: context.l10n.commonRefresh,
                          onPressed:
                              admin.menuLoading ? null : admin.loadMenu,
                          icon: admin.menuLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 20),
                        ),
                        if (canManage)
                          FilledButton.icon(
                            onPressed: admin.mutating
                                ? null
                                : () => _edit(context, admin),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              context.posText(
                                'adminNewTimeSlot',
                                'New time slot',
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (admin.timeSlots.isNotEmpty)
                      _TimeSlotsSummaryBar(
                        total: admin.timeSlots.length,
                        activeCount: activeCount,
                        liveCount: liveCount,
                        filtered: _query.trim().isNotEmpty,
                        filteredCount: slots.length,
                      ),
                    if (admin.error != null)
                      AdminInlineError(
                        message: admin.error!,
                        onDismiss: admin.clearError,
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: admin.loadMenu,
                        child: admin.timeSlots.isEmpty
                            ? AdminEmptyPane(
                                icon: Icons.schedule_rounded,
                                title: context.posText(
                                  'adminTimeSlotsEmpty',
                                  'No time slots yet.',
                                ),
                                subtitle: context.posText(
                                  'adminTimeSlotsEmptyHint',
                                  'Define breakfast, lunch, or dinner windows.',
                                ),
                                action: canManage
                                    ? FilledButton.icon(
                                        onPressed: admin.mutating
                                            ? null
                                            : () => _edit(context, admin),
                                        icon: const Icon(Icons.add_rounded),
                                        label: Text(
                                          context.posText(
                                            'adminNewTimeSlot',
                                            'New time slot',
                                          ),
                                        ),
                                      )
                                    : null,
                              )
                            : slots.isEmpty
                                ? AdminEmptyPane(
                                    icon: Icons.search_off_rounded,
                                    title: context.posText(
                                      'adminTimeSlotsNoMatch',
                                      'No matches',
                                    ),
                                    subtitle: context.posText(
                                      'adminTimeSlotsNoMatchHint',
                                      'Try a different search term.',
                                    ),
                                  )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final columns =
                                          constraints.maxWidth >= 1100
                                              ? 3
                                              : constraints.maxWidth >= 720
                                                  ? 2
                                                  : 1;
                                      const gap = 12.0;
                                      const pad = 14.0;
                                      final usable = constraints.maxWidth -
                                          (pad * 2) -
                                          (gap * (columns - 1));
                                      final cardWidth = usable / columns;
                                      return ListView(
                                        padding: const EdgeInsets.fromLTRB(
                                          pad,
                                          12,
                                          pad,
                                          28,
                                        ),
                                        children: [
                                          Wrap(
                                            spacing: gap,
                                            runSpacing: gap,
                                            children: [
                                              for (final slot in slots)
                                                SizedBox(
                                                  width: cardWidth,
                                                  child: _TimeSlotCard(
                                                    slot: slot,
                                                    dayShort: _dayShort,
                                                    canManage: canManage,
                                                    busy: admin.mutating,
                                                    onEdit: () => _edit(
                                                      context,
                                                      admin,
                                                      slot: slot,
                                                    ),
                                                    onDelete: () => _delete(
                                                      context,
                                                      admin,
                                                      slot,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    PosAdminController admin,
    AdminMenuTimeSlot slot,
  ) async {
    final ok = await showPosConfirmDialog(
      context,
      title: context.posText('adminDeleteTimeSlot', 'Delete time slot?'),
      message: slot.name,
      destructive: true,
    );
    if (!ok) return;
    await admin.deleteTimeSlot(slot.id);
  }

  Future<void> _edit(
    BuildContext context,
    PosAdminController admin, {
    AdminMenuTimeSlot? slot,
  }) async {
    final nameCtrl = TextEditingController(text: slot?.name ?? '');
    var start = _parseTimeOfDay(slot?.startTime) ??
        const TimeOfDay(hour: 9, minute: 0);
    var end = _parseTimeOfDay(slot?.endTime) ??
        const TimeOfDay(hour: 17, minute: 0);
    var days = Set<int>.from(slot?.daysOfWeek ?? const []);
    var isActive = slot?.isActive ?? true;

    final saved = await showAdminPanel<bool>(
      context: context,
      sidePanelWidth: 460,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final accent = Theme.of(ctx).colorScheme.primary;
            return PosDialogShell(
              title: slot == null
                  ? context.posText('adminNewTimeSlot', 'New time slot')
                  : context.posText('adminEditTimeSlot', 'Edit time slot'),
              icon: Icons.schedule_rounded,
              maxWidth: 440,
              embedded: true,
              onClose: () => Navigator.pop(ctx, false),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: context.posText('adminName', 'Name'),
                      filled: true,
                      fillColor: PosTheme.surfaceMuted,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TimePickerField(
                          label: context.posText(
                            'adminStartTime',
                            'Start',
                          ),
                          value: start,
                          onPick: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: start,
                            );
                            if (picked != null) {
                              setLocal(() => start = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimePickerField(
                          label: context.posText('adminEndTime', 'End'),
                          value: end,
                          onPick: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: end,
                            );
                            if (picked != null) {
                              setLocal(() => end = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_isOvernight(start, end)) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.posText(
                        'adminOvernightHint',
                        'Ends next day (overnight)',
                      ),
                      style: TextStyle(
                        color: PosTheme.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.posText('adminActive', 'Active'),
                    ),
                    value: isActive,
                    onChanged: (v) => setLocal(() => isActive = v),
                  ),
                  Text(
                    context.posText('adminDays', 'Days'),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: PosTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.posText(
                      'adminDaysHint',
                      'Leave all off for every day.',
                    ),
                    style: TextStyle(
                      color: PosTheme.inkMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var d = 0; d < 7; d++)
                        _DayToggle(
                          label: _dayShort[d],
                          selected: days.contains(d),
                          accent: accent,
                          onTap: () {
                            setLocal(() {
                              if (days.contains(d)) {
                                days = {...days}..remove(d);
                              } else {
                                days = {...days, d};
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
              footer: posDialogActionFooter(
                context: ctx,
                confirmLabel: context.l10n.commonSave,
                onCancel: () => Navigator.pop(ctx, false),
                onConfirm: () => Navigator.pop(ctx, true),
              ),
            );
          },
        );
      },
    );

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (saved != true || name.isEmpty) return;

    final body = <String, dynamic>{
      'name': name,
      'start_time': _formatHi(start),
      'end_time': _formatHi(end),
      'days_of_week': days.toList()..sort(),
      'is_active': isActive,
    };

    if (slot == null) {
      await admin.createTimeSlot(body);
    } else {
      await admin.updateTimeSlot(slot.id, body);
    }
  }
}

class _TimeSlotsSummaryBar extends StatelessWidget {
  const _TimeSlotsSummaryBar({
    required this.total,
    required this.activeCount,
    required this.liveCount,
    required this.filtered,
    required this.filteredCount,
  });

  final int total;
  final int activeCount;
  final int liveCount;
  final bool filtered;
  final int filteredCount;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (filtered) {
      parts.add(
        context.posText(
          'adminTimeSlotsShowing',
          'Showing {n} of {total}',
          {'n': '$filteredCount', 'total': '$total'},
        ),
      );
    } else {
      parts.add(
        context.posText(
          'adminTimeSlotsCount',
          '{n} slots',
          {'n': '$total'},
        ),
      );
      parts.add(
        context.posText(
          'adminTimeSlotsActiveCount',
          '{n} active',
          {'n': '$activeCount'},
        ),
      );
      if (liveCount > 0) {
        parts.add(
          context.posText(
            'adminTimeSlotsLiveCount',
            '{n} live now',
            {'n': '$liveCount'},
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          parts.join('  ·  '),
          style: TextStyle(
            color: PosTheme.inkMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

class _TimeSlotCard extends StatelessWidget {
  const _TimeSlotCard({
    required this.slot,
    required this.dayShort,
    required this.canManage,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminMenuTimeSlot slot;
  final List<String> dayShort;
  final bool canManage;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final live = slot.isLive && slot.isActive;
    final overnight = _isOvernightHi(slot.startTime, slot.endTime);
    final allDays =
        slot.daysOfWeek.isEmpty || slot.daysOfWeek.length == 7;
    final segments = _scheduleBarSegments(slot.startTime, slot.endTime);
    final stripColor = !slot.isActive
        ? PosTheme.inkFaint
        : live
            ? const Color(0xFF059669)
            : accent;

    return Material(
      color: PosTheme.surface,
      borderRadius: BorderRadius.circular(PosTheme.radiusMd),
      child: InkWell(
        onTap: canManage && !busy ? onEdit : null,
        borderRadius: BorderRadius.circular(PosTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusMd),
            border: Border.all(
              color: live
                  ? const Color(0xFF059669).withValues(alpha: 0.35)
                  : PosTheme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: stripColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(PosTheme.radiusMd - 1),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final soft = posAccentSoft(accent);
                            return Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: live
                                ? const Color(0xFF059669)
                                : slot.isActive
                                    ? soft.bg
                                    : PosTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: live
                                ? Colors.white
                                : slot.isActive
                                    ? soft.fg
                                    : PosTheme.inkFaint,
                          ),
                        );
                          },
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      slot.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: PosTheme.ink,
                                      ),
                                    ),
                                  ),
                                  if (live) ...[
                                    const SizedBox(width: 6),
                                    _StatusPill(
                                      label: context.posText(
                                        'adminLiveNow',
                                        'Live now',
                                      ),
                                      color: const Color(0xFF059669),
                                      filled: true,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${_formatDisplayTime(slot.startTime)} – ${_formatDisplayTime(slot.endTime)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: PosTheme.ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (overnight) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      context.posText(
                                        'adminOvernight',
                                        'overnight',
                                      ),
                                      style: TextStyle(
                                        color: PosTheme.inkMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(
                          label: slot.isActive
                              ? context.posText('adminActive', 'Active')
                              : context.posText(
                                  'adminInactive',
                                  'Inactive',
                                ),
                          color: slot.isActive
                              ? const Color(0xFF059669)
                              : PosTheme.inkMuted,
                          filled: slot.isActive,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          '12 AM',
                          style: TextStyle(
                            color: PosTheme.inkFaint,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            context.posText(
                              'adminDayTimeline',
                              'Day timeline',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: PosTheme.inkFaint,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        Text(
                          '12 AM',
                          style: TextStyle(
                            color: PosTheme.inkFaint,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 10,
                            width: constraints.maxWidth,
                            child: Stack(
                              children: [
                                Container(color: PosTheme.surfaceMuted),
                                for (final seg in segments)
                                  Positioned(
                                    left: constraints.maxWidth *
                                        (seg.$1 / 100),
                                    width: constraints.maxWidth *
                                        (seg.$2 / 100),
                                    top: 0,
                                    bottom: 0,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: slot.isActive
                                            ? accent
                                            : PosTheme.inkFaint,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var d = 0; d < 7; d++)
                          _DayBadge(
                            label: dayShort[d],
                            active: allDays || slot.daysOfWeek.contains(d),
                            accent: accent,
                          ),
                        if (allDays)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Text(
                              context.posText(
                                'adminEveryDay',
                                'Every day',
                              ),
                              style: TextStyle(
                                color: PosTheme.inkMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (canManage) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _IconAction(
                            tooltip: context.posText('commonEdit', 'Edit'),
                            icon: Icons.edit_outlined,
                            color: accent,
                            onPressed: busy ? null : onEdit,
                          ),
                          const SizedBox(width: 4),
                          _IconAction(
                            tooltip:
                                context.posText('commonDelete', 'Delete'),
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFDC2626),
                            onPressed: busy ? null : onDelete,
                          ),
                        ],
                      ),
                    ],
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.filled,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? soft.bg : PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled
              ? soft.fg.withValues(alpha: 0.28)
              : PosTheme.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? soft.fg : PosTheme.inkMuted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  const _DayBadge({
    required this.label,
    required this.active,
    required this.accent,
  });

  final String label;
  final bool active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(accent);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? soft.bg : PosTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? soft.fg.withValues(alpha: 0.28)
              : PosTheme.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? soft.fg : PosTheme.inkFaint,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : PosTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : PosTheme.inkMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final TimeOfDay value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(PosTheme.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: PosTheme.surfaceMuted,
          suffixIcon: const Icon(Icons.schedule_rounded, size: 18),
        ),
        child: Text(
          value.format(context),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: PosTheme.ink,
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final soft = posAccentSoft(color);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: soft.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: soft.fg.withValues(alpha: 0.28)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 15, color: soft.fg),
          ),
        ),
      ),
    );
  }
}

TimeOfDay? _parseTimeOfDay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw.trim());
  if (match == null) return null;
  final h = int.tryParse(match.group(1)!);
  final m = int.tryParse(match.group(2)!);
  if (h == null || m == null || h > 23 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

String _formatHi(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

int _parseMinutes(String? raw) {
  final t = _parseTimeOfDay(raw);
  if (t == null) return 0;
  return t.hour * 60 + t.minute;
}

bool _isOvernight(TimeOfDay start, TimeOfDay end) {
  final s = start.hour * 60 + start.minute;
  final e = end.hour * 60 + end.minute;
  return e <= s;
}

bool _isOvernightHi(String start, String end) {
  return _parseMinutes(end) <= _parseMinutes(start);
}

String _formatDisplayTime(String raw) {
  final t = _parseTimeOfDay(raw);
  if (t == null) return raw;
  final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

/// Returns `(leftPercent, widthPercent)` segments for a 24h bar.
List<(double, double)> _scheduleBarSegments(String start, String end) {
  const dayMinutes = 24 * 60;
  final s = _parseMinutes(start);
  final e = _parseMinutes(end);
  if (e <= s) {
    return [
      ((s / dayMinutes) * 100, ((dayMinutes - s) / dayMinutes) * 100),
      (0, (e / dayMinutes) * 100),
    ];
  }
  return [((s / dayMinutes) * 100, ((e - s) / dayMinutes) * 100)];
}
