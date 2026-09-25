import 'package:flutter/material.dart';

import '../../config/pos_app_info.dart';
import '../../theme/pos_theme.dart';

class PosHelpPage extends StatefulWidget {
  const PosHelpPage({super.key});

  @override
  State<PosHelpPage> createState() => _PosHelpPageState();
}

class _PosHelpPageState extends State<PosHelpPage> {
  final _search = TextEditingController();
  String _query = '';
  String _selected = _articles.first.id;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_HelpArticle> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _articles;
    return _articles.where((article) {
      final blob = '${article.title} ${article.summary} ${article.search}'.toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final selected = visible.where((article) => article.id == _selected).firstOrNull ??
        (visible.isEmpty ? null : visible.first);
    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        title: const Text('Help & guide'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          final index = _TopicIndex(
            articles: visible,
            selectedId: selected?.id,
            query: _query,
            controller: _search,
            onQuery: (value) => setState(() => _query = value),
            onSelect: (id) => setState(() => _selected = id),
          );
          if (!wide) {
            if (selected == null) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [index],
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                index,
                const SizedBox(height: 12),
                _ArticleView(article: selected),
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 320,
                  child: ListView(
                    children: [index],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListView(
                    children: [
                      if (selected == null)
                        const _EmptySearch()
                      else
                        _ArticleView(article: selected),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopicIndex extends StatelessWidget {
  const _TopicIndex({
    required this.articles,
    required this.selectedId,
    required this.query,
    required this.controller,
    required this.onQuery,
    required this.onSelect,
  });

  final List<_HelpArticle> articles;
  final String? selectedId;
  final String query;
  final TextEditingController controller;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onQuery,
          decoration: InputDecoration(
            hintText: 'Search features or a problem',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      controller.clear();
                      onQuery('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
            isDense: true,
            filled: true,
            fillColor: PosTheme.surface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${PosAppInfo.displayName} · ${PosAppInfo.versionLabel}',
          style: TextStyle(fontSize: 12, color: PosTheme.inkMuted),
        ),
        const SizedBox(height: 10),
        if (articles.isEmpty)
          const _EmptySearch()
        else
          for (final article in articles)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: article.id == selectedId
                    ? accent.withValues(alpha: 0.08)
                    : PosTheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(article.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: article.id == selectedId
                            ? accent.withValues(alpha: 0.4)
                            : PosTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(article.icon, size: 20, color: accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                article.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: PosTheme.ink,
                                ),
                              ),
                              Text(
                                article.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: PosTheme.inkMuted,
                                ),
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
      ],
    );
  }
}

class _ArticleView extends StatelessWidget {
  const _ArticleView({required this.article});

  final _HelpArticle article;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: PosTheme.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            article.summary,
            style: TextStyle(color: PosTheme.inkMuted, height: 1.4),
          ),
          for (final section in article.sections) ...[
            const SizedBox(height: 18),
            Text(
              section.title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: PosTheme.ink,
              ),
            ),
            const SizedBox(height: 8),
            for (final line in section.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line,
                        style: TextStyle(
                          height: 1.4,
                          color: PosTheme.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'No topic matches that search.',
        style: TextStyle(color: PosTheme.inkMuted),
      ),
    );
  }
}

class _HelpArticle {
  const _HelpArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.sections,
    required this.search,
  });

  final String id;
  final String title;
  final String summary;
  final IconData icon;
  final List<_HelpSection> sections;
  final String search;
}

class _HelpSection {
  const _HelpSection(this.title, this.lines);

  final String title;
  final List<String> lines;
}

const _articles = <_HelpArticle>[
  _HelpArticle(
    id: 'register',
    title: 'Register and orders',
    summary: 'Sell, hold a ticket, and find an order again.',
    icon: Icons.point_of_sale_rounded,
    search: 'cart dine in takeaway customer discount table park hold',
    sections: [
      _HelpSection('What it is for', [
        'The register is the selling screen. Tap an item to add it. Items with variants or modifiers open a choice sheet first.',
        'Dine-in and takeaway sit at the top of the cart. Add customer searches existing customers after you type, and can create one from that search.',
        'Discount is the small control on the left, above Subtotal.',
      ]),
      _HelpSection('How to use it', [
        'More → Item images chooses photos, plain color cards, or category photos with plain item cards. That choice stays on this register only.',
        'More → Refresh menu reloads categories and items from the server.',
        'More → Menu edits categories, items, and whether something is available. More → Administration opens the rest of the back office this user is allowed to see.',
      ]),
      _HelpSection('If something is wrong', [
        'An item with no photo is still sellable. Turn images back on from More → Item images if the cards should show photos again.',
        'If a variant does not appear, open the item. Variants and modifiers are different. An unchecked modifier group is not offered.',
        'If the menu looks old, use Refresh menu. If the network is down, the last loaded menu stays on screen until the connection returns.',
      ]),
    ],
  ),
  _HelpArticle(
    id: 'payments',
    title: 'Payments and UPI QR',
    summary: 'Cash, card, UPI, and a held QR for the next order.',
    icon: Icons.qr_code_2_rounded,
    search: 'upi hold pending qr cash card pay later scan',
    sections: [
      _HelpSection('What it is for', [
        'Quick pay can take cash, UPI, card, or more tenders. More → Arrange quick pay changes the order of those buttons on this register.',
        'UPI shows a QR for the customer. Hold and new order saves that QR, clears it from the customer screen, and lets you start another ticket.',
      ]),
      _HelpSection('How to use it', [
        'The saved QR appears beside Scan as Pending UPI QR. Tap it to open the same QR again. It does not create a new payment.',
        'The chip text is only a label. The saved payment, amount, and QR stay as they were.',
      ]),
      _HelpSection('If something is wrong', [
        'If Pending UPI QR is missing, the hold was not saved, it expired, or that payment already completed.',
        'If the customer screen still shows a QR after Hold, wait a moment and check that the display is the one paired to this register.',
        'A refused or expired UPI does not mark the order paid. Take another tender or reopen the held QR.',
      ]),
    ],
  ),
  _HelpArticle(
    id: 'printing',
    title: 'Printing',
    summary: 'USB, Bluetooth, LAN, and the TVS built-in printer.',
    icon: Icons.print_outlined,
    search: 'printer usb bluetooth lan network built-in tvs smartpos paper kot receipt token test print',
    sections: [
      _HelpSection('What it is for', [
        'More → Printer setup is where this register’s printer is chosen. There are four connections: USB, Bluetooth, Network / LAN, and Built-in.',
        'Built-in is the inner printer on a TVS or SmartPOS terminal. It is not a USB cable and it is not used on Windows.',
        'A paid order can print a kitchen ticket, a customer bill, and a counter token. Those are separate slips. Which ones print follows the receipt settings for this branch.',
      ]),
      _HelpSection('How to use it', [
        'Pick the connection that matches the hardware, select that printer, then use Test print. The header printer icon follows the last check of the saved printer.',
        'When a printer is selected, the app asks once whether that printer can sense the paper roll. If it can and the roll is empty, you are told the roll is finished. If it has no sensor, you are told the printer does not have that function. Printing is not blocked by a missing sensor.',
        'USB: keep the cable in the same port you selected. LAN: enter the printer IP and port. The printer and this register must be on the same network. Bluetooth: scan, select the printer once, then the app uses that saved printer.',
        'Built-in: on the Android terminal choose Built-in and test print. If the terminal was powered off, the roll was removed, or the inner printer dropped, the app tries to start it again. It waits longer between tries so it does not keep powering the mechanism.',
      ]),
      _HelpSection('If something is wrong', [
        'Nothing prints: open Printer setup and confirm the saved connection is the one in use, then Test print. More → Status shows the last printer check, not a substitute for a test page.',
        'USB works on another PC but not here: this register is saved to a different printer. Select the USB printer again.',
        'Bluetooth drops: open Printer setup, scan, and select it again. A second scan while it is already connected can steal the radio.',
        'Built-in stays offline: load paper, leave the cover closed, wait for the next reconnect, then Test print. If it is still down, restart the POS on that terminal. Do not switch it to USB unless a USB printer is actually plugged in.',
        'Two slips for one order: check whether the kitchen ticket and the customer bill are both turned on. That is two jobs on purpose. A built-in slip that may already have started is not sent again automatically.',
        'Out of paper on a printer with a sensor: load the roll. The failed job can print once the printer is ready again. A printer with no sensor will not report the roll.',
      ]),
    ],
  ),
  _HelpArticle(
    id: 'displays',
    title: 'Customer screens',
    summary: 'Second screen, DQR slides, cart display, and token display.',
    icon: Icons.tv_rounded,
    search: 'dqr customer display secondary screen token cart pairing qr slideshow images',
    sections: [
      _HelpSection('What each one is', [
        'More → Customer display is the status of a second screen on this terminal.',
        'More → QR display pairing links a phone or tablet on the same network so the guest can see the cart and QR.',
        'More → Cart display and Token display open those boards on this device or a screen you send them to.',
        'More → DQR images changes the idle slides stored on a DQR-222. Those slides are not the cart and they are not the payment QR.',
      ]),
      _HelpSection('How the DQR behaves', [
        'When the DQR is idle it plays every JPEG stored on the display, one after another, about every 5 seconds. The count is whatever is stored there. Every file in that list can be replaced or removed.',
        'Replace is a button in this POS, beside each file name. It does not appear on the customer display.',
        'A replacement must be a portrait JPEG, exactly 320 × 480 pixels, under 100 KB. Saving over the same file name changes only that slide.',
        'Adding an item still sends the cart. Starting UPI still sends the payment QR. Slides play again only after the cart is cleared or the QR closes.',
      ]),
      _HelpSection('If something is wrong', [
        'DQR images will not load if the display is unplugged, or if a payment QR is still on it. Finish the payment and keep the cable connected until the success message.',
        'A cart or QR that does not show: confirm this register is the one paired to that screen, and use More → Customer display or QR display pairing to see whether it is connected.',
        'Changing a slide never replaces the payment QR. If a QR is missing, the payment was not started, it was held, or it expired.',
      ]),
    ],
  ),
  _HelpArticle(
    id: 'kitchen',
    title: 'Kitchen and online orders',
    summary: 'Tickets on this device, and orders that arrive from outside the register.',
    icon: Icons.soup_kitchen_outlined,
    search: 'kitchen kot online swiggy zomato accept ready',
    sections: [
      _HelpSection('What it is for', [
        'The kitchen board shows tickets for this branch. Accept, start, and mark food ready from the ticket.',
        'Guest, kiosk, online, and partner orders can print a kitchen ticket on this register when auto-print is on in Printer setup.',
      ]),
      _HelpSection('If something is wrong', [
        'A new online order with no ticket: confirm auto-print is on, a printer is selected, and this device is allowed to print kitchen tickets.',
        'The same order should not print twice from the queue. A second slip is usually the bill or the token, which is a different print.',
      ]),
    ],
  ),
  _HelpArticle(
    id: 'register-care',
    title: 'This register',
    summary: 'Lock, staff, sync, updates, and where to look first.',
    icon: Icons.admin_panel_settings_outlined,
    search: 'pin lock sync offline update status sign out pairing language fullscreen',
    sections: [
      _HelpSection('What the More menu is for', [
        'Store opens or pauses online ordering when this user is allowed to.',
        'Status is the last check of internet, printer, scanner, and customer display.',
        'Lock, auto-lock, and PIN protect this register. Sign out ends the session.',
        'Sync orders sends tickets that were saved on this device while the network was down.',
        'Check for updates looks for a newer POS build. Installing one replaces this app. It does not change the menu or the printer you already selected.',
      ]),
      _HelpSection('If something is wrong', [
        'Start with More → Status, then the setup screen for the device that failed: Printer setup, Customer display, or DQR images.',
        'If only this register is wrong and another terminal is fine, the setting is saved on this device. Select the printer or display again here.',
        'After an update, open the register once and confirm the printer with Test print before service.',
      ]),
    ],
  ),
];
