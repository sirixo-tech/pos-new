import 'package:flutter/material.dart';

import '../../theme/pos_theme.dart';

/// First-run menu guidance. Preview rows are illustrations, not saved items.
class AdminMenuSetupGuide extends StatelessWidget {
  const AdminMenuSetupGuide({super.key, this.onGetStarted});

  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 650
            ? 2
            : 1;
        final width =
            (constraints.maxWidth -
                (columns == 4 ? 32 : 40) -
                (columns - 1) * 20) /
            columns;
        final desktop = columns == 4;
        final content = Padding(
          padding: EdgeInsets.all(desktop ? 16 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                'Set up your menu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: PosTheme.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Follow these simple steps to build your menu and start taking orders.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: PosTheme.inkMuted),
              ),
              SizedBox(height: desktop ? 16 : 28),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (var i = 0; i < 4; i++)
                    SizedBox(
                      key: ValueKey('menu-setup-step-$i'),
                      width: width,
                      height:
                          (desktop && width >= 300 ? 450 : 510) *
                          MediaQuery.textScalerOf(context).scale(1),
                      child: _StepCard(
                        step: i,
                        compact: desktop && width >= 300,
                      ),
                    ),
                ],
              ),
              SizedBox(height: desktop ? 16 : 28),
              FilledButton.icon(
                onPressed: onGetStarted,
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text(
                  'Get started',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6900),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(210, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (onGetStarted == null) ...[
                const SizedBox(height: 10),
                Text(
                  'Ask your manager to set up the menu.',
                  style: TextStyle(color: PosTheme.inkMuted),
                ),
              ],
            ],
          ),
        );
        if (desktop && constraints.hasBoundedHeight) {
          return SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(width: constraints.maxWidth, child: content),
            ),
          );
        }
        return SingleChildScrollView(child: content);
      },
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, this.compact = false});
  final int step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFFFF6EF),
      Color(0xFFF0F7FF),
      Color(0xFFF0FBF4),
      Color(0xFFF7F2FF),
    ];
    const badges = [
      Color(0xFFFFD2AF),
      Color(0xFFCCE6FF),
      Color(0xFFC5EFCE),
      Color(0xFFE3CCFF),
    ];
    const titles = [
      'Add category',
      'Add menu item',
      'Add variations (optional)',
      'Set availability',
    ];
    const descriptions = [
      'Create categories to organize your items.',
      'Add items under each category.',
      'Add sizes, flavors or other options.',
      'Control when items are visible.',
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors[step],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height:
                (compact ? 100 : 160) *
                MediaQuery.textScalerOf(context).scale(1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: badges[step],
                  radius: 20,
                  child: Text(
                    '${step + 1}',
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titles[step],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: PosTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        descriptions[step],
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: PosTheme.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              key: ValueKey('menu-setup-preview-$step'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            'Categories',
                            'Beverages',
                            'Item variations',
                            'Coffee',
                          ][step],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF172033),
                          ),
                        ),
                      ),
                      if (step < 2)
                        const Icon(
                          Icons.add_circle,
                          color: Color(0xFFFF6900),
                          size: 26,
                        ),
                      if (step == 2)
                        const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFF65758B),
                        ),
                      if (step == 3)
                        const Icon(
                          Icons.toggle_on,
                          size: 32,
                          color: Color(0xFFFF6900),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < (step == 0 ? 4 : 3); i++)
                    _PreviewRow(step: step, index: i),
                  if (step == 2)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 16,
                            color: Color(0xFFFF6900),
                          ),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Add variation',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFF6900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.step, required this.index});
  final int step;
  final int index;

  @override
  Widget build(BuildContext context) {
    const labels = [
      ['Beverages', 'Snacks', 'Main Course', 'Desserts'],
      ['Tea', 'Coffee', 'Juice'],
      ['Small', 'Medium', 'Large'],
      ['Available all day', 'Set time range', 'Set days'],
    ];
    final highlighted = step == 0 && index == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFEFE3) : const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (step != 2) ...[
            Icon(
              step == 0
                  ? [
                      Icons.local_cafe_outlined,
                      Icons.lunch_dining_outlined,
                      Icons.ramen_dining_outlined,
                      Icons.icecream_outlined,
                    ][index]
                  : step == 1
                  ? Icons.local_cafe_outlined
                  : index == 2
                  ? Icons.calendar_month_outlined
                  : Icons.schedule,
              size: 20,
              color: highlighted
                  ? const Color(0xFFFF6900)
                  : const Color(0xFF65758B),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              labels[step][index],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: highlighted
                    ? const Color(0xFFBE4D0D)
                    : const Color(0xFF172033),
              ),
            ),
          ),
          if (step == 1 || step == 2)
            Text(
              '₹${20 + index * 10}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF6900),
              ),
            ),
          if (step == 0)
            const Icon(Icons.chevron_right, size: 17, color: Color(0xFF65758B)),
          if (step == 3)
            Icon(
              index == 0
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 17,
              color: index == 0
                  ? const Color(0xFFFF6900)
                  : const Color(0xFFCBD5E1),
            ),
        ],
      ),
    );
  }
}
