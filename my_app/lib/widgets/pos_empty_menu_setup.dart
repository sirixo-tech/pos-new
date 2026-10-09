import 'package:flutter/material.dart';

import '../theme/pos_theme.dart';
import '../utils/pos_layout.dart';

class PosEmptyMenuSetup extends StatelessWidget {
  const PosEmptyMenuSetup({
    super.key,
    required this.onAdd,
    required this.onImport,
    required this.onAi,
    required this.onZomato,
  });
  final VoidCallback? onAdd, onImport, onAi, onZomato;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final phonePane = constraints.maxWidth < 420;
      final outerPadding = phonePane ? 8.0 : 16.0;
      final compactPane =
          constraints.maxWidth >= 420 && constraints.maxWidth < 650;
      final columns = constraints.maxWidth >= 680
          ? 3
          : constraints.maxWidth >= 420
          ? 2
          : 1;
      final width =
          (constraints.maxWidth - outerPadding * 2 - (columns - 1) * 12) /
          columns;
      final actions = [
        (
          'Add Menu Items',
          'Create categories and items',
          Icons.add_box_outlined,
          const Color(0xFFFF6900),
          const Color(0xFFFFF3E9),
          onAdd,
        ),
        (
          'Import Menu',
          'Download a sample or attach a file',
          Icons.cloud_upload_outlined,
          const Color(0xFF526BFF),
          const Color(0xFFEEF2FF),
          onImport,
        ),
        (
          'AI Setup',
          'Create menu with AI',
          Icons.auto_awesome_outlined,
          const Color(0xFFF53291),
          const Color(0xFFFFEDF6),
          onAi,
        ),
        (
          'Import from ZOMATO',
          'Sync your Zomato menu',
          Icons.restaurant_menu,
          const Color(0xFFE91C3A),
          const Color(0xFFFFEEF2),
          onZomato,
        ),
      ];
      return SingleChildScrollView(
        padding: EdgeInsets.all(outerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(
                phonePane
                    ? 12
                    : constraints.maxWidth < 650
                    ? 16
                    : 24,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF8F1), Color(0xFFFFEFE0)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: LayoutBuilder(
                builder: (context, bannerConstraints) {
                  final content = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WELCOME TO SELFX POS',
                        style: TextStyle(
                          color: Color(0xFFFF6900),
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Let's set up your menu",
                        style: TextStyle(
                          fontSize: constraints.maxWidth < 650 ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: PosTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add items, import from online platforms and get started quickly.',
                        style: TextStyle(
                          fontSize: 13,
                          color: PosTheme.inkMuted,
                        ),
                      ),
                    ],
                  );
                  final features = Wrap(
                    spacing: 24,
                    runSpacing: 14,
                    children: [
                      for (final feature in [
                        (Icons.bolt, 'Quick setup', 'Get started in minutes'),
                        (
                          Icons.cloud_outlined,
                          'Works offline',
                          'Run without internet',
                        ),
                        (
                          Icons.bar_chart,
                          'All-in-one POS',
                          'Menu, orders and more',
                        ),
                      ])
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: compactPane ? 16 : 20,
                              backgroundColor: const Color(0xFFFFE7D2),
                              child: Icon(
                                feature.$1,
                                color: const Color(0xFFFF6900),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              feature.$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: PosTheme.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              feature.$3,
                              style: TextStyle(
                                fontSize: 10,
                                color: PosTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                  final wide = bannerConstraints.maxWidth >= 380;
                  final compact = bannerConstraints.maxWidth < 600;
                  if (usePosHandheldLayout(context)) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        content,
                        if (!phonePane) ...[
                          const SizedBox(height: 16),
                          features,
                        ],
                      ],
                    );
                  }
                  final illustration = Image.asset(
                    'assets/images/menu_setup_food.png',
                    key: const ValueKey('menu-setup-food'),
                    width: wide ? (compact ? 110 : 170) : 80,
                    height: wide ? (compact ? 120 : 160) : 80,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  );
                  if (wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: content),
                            const SizedBox(width: 12),
                            illustration,
                          ],
                        ),
                        const SizedBox(height: 16),
                        features,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: illustration,
                      ),
                      if (!phonePane) ...[const SizedBox(height: 16), features],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final action in actions)
                  SizedBox(
                    width: width,
                    child: Material(
                      color: action.$5,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: action.$6,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: EdgeInsets.all(
                            phonePane
                                ? 10
                                : compactPane
                                ? 12
                                : 16,
                          ),
                          child: phonePane
                              ? Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: action.$4,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        action.$3,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            action.$1,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: PosTheme.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            action.$2,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: PosTheme.inkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: action.$4,
                                      size: 18,
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(
                                            compactPane ? 8 : 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: action.$4,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            action.$3,
                                            color: Colors.white,
                                            size: compactPane ? 20 : 24,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          Icons.chevron_right,
                                          color: action.$4,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      action.$1,
                                      maxLines: compactPane ? 1 : null,
                                      overflow: compactPane
                                          ? TextOverflow.ellipsis
                                          : null,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: PosTheme.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      action.$2,
                                      maxLines: compactPane ? 1 : null,
                                      overflow: compactPane
                                          ? TextOverflow.ellipsis
                                          : null,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: PosTheme.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (onAdd == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Ask your manager to set up the menu.',
                  style: TextStyle(color: PosTheme.inkMuted),
                ),
              ),
          ],
        ),
      );
    },
  );
}
