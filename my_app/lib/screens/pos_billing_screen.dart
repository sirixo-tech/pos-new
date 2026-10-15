import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/pos_l10n.dart';
import '../models/billing_models.dart';
import '../providers/pos_controller.dart';
import '../services/pos_api.dart';
import '../theme/pos_theme.dart';
import '../utils/format.dart';
import '../utils/pos_user_facing_error.dart';
import '../widgets/pos_ui.dart';

class PosBillingScreen extends StatefulWidget {
  const PosBillingScreen({super.key, this.fromSubscriptionBlock = false});

  final bool fromSubscriptionBlock;

  @override
  State<PosBillingScreen> createState() => _PosBillingScreenState();
}

class _PosBillingScreenState extends State<PosBillingScreen> {
  PosBillingCatalog? _catalog;
  String? _error;
  bool _loading = true;
  bool _submitting = false;
  int? _submittingPlanId;
  String _interval = 'monthly';
  bool _awaitingPayment = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) {
      setState(() {
        _loading = false;
        _error = context.l10n.authNotSignedIn;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final catalog = await context.read<PosApi>().fetchBilling(session);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loading = false;
        _interval = catalog.currentPlan?.interval == 'yearly'
            ? 'yearly'
            : 'monthly';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = posUserFacingError(e);
      });
    }
  }

  Future<void> _subscribe(PosBillingInterval plan) async {
    if (_submitting || plan.id < 1) return;
    final pos = context.read<PosController>();
    final session = pos.session;
    if (session == null) return;

    setState(() {
      _submitting = true;
      _submittingPlanId = plan.id;
      _error = null;
    });

    try {
      final result = await context.read<PosApi>().checkoutBilling(
        session,
        planId: plan.id,
      );
      if (!mounted) return;

      if (result.activated) {
        if (widget.fromSubscriptionBlock) {
          await _restoreAfterBilling();
        } else if (mounted) {
          showPosSnackBar(context, context.l10n.billingActivated);
          Navigator.of(context).maybePop();
        }
        return;
      }

      final url = result.checkoutUrl;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (!mounted) return;
        setState(() => _awaitingPayment = true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = posUserFacingError(e));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submittingPlanId = null;
        });
      }
    }
  }

  Future<void> _confirmPaid() async {
    setState(() => _submitting = true);
    await _restoreAfterBilling();
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  Future<void> _restoreAfterBilling() async {
    await context.read<PosController>().initialize();
    if (!mounted) return;
    final pos = context.read<PosController>();
    if (pos.subscriptionBlocked) {
      showPosSnackBar(context, context.l10n.billingPaymentPending, error: true);
      return;
    }
    if (widget.fromSubscriptionBlock) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      showPosSnackBar(context, context.l10n.billingActivated);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    PosTheme.bind(context);
    final l10n = context.l10n;
    final catalog = _catalog;

    return Scaffold(
      backgroundColor: PosTheme.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: PosTheme.surface,
        title: Text(
          l10n.billingTitle,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                children: [
                  if (_error != null) ...[
                    _Notice(text: _error!, danger: true),
                    const SizedBox(height: 16),
                  ],
                  if (catalog == null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.billingNoPlans,
                          style: TextStyle(color: PosTheme.inkMuted),
                        ),
                      ),
                    )
                  else ...[
                    _BillingIntro(catalog: catalog),
                    const SizedBox(height: 20),
                    if (!catalog.canCheckout)
                      _Notice(
                        text: l10n.billingCoveredBody(
                          catalog.organizationName ?? l10n.billingOrganization,
                        ),
                      )
                    else ...[
                      if (_awaitingPayment) ...[
                        _Notice(text: l10n.billingReturnFromCheckout),
                        const SizedBox(height: 12),
                        PosPrimaryButton(
                          label: l10n.billingIvePaid,
                          icon: Icons.check_circle_outline_rounded,
                          loading: _submitting,
                          onPressed: _submitting ? null : _confirmPaid,
                        ),
                        const SizedBox(height: 20),
                      ],
                      _IntervalToggle(
                        value: _interval,
                        onChanged: (next) => setState(() => _interval = next),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          catalog.paymentGatewayEnabled
                              ? l10n.billingPayWith(
                                  catalog.paymentGatewayName ??
                                      l10n.billingPaymentProvider,
                                )
                              : l10n.billingPaymentOff,
                          style: TextStyle(
                            color: PosTheme.inkMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (catalog.planGroups.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              l10n.billingNoPlans,
                              style: TextStyle(color: PosTheme.inkMuted),
                            ),
                          ),
                        )
                      else
                        ...catalog.planGroups.map(
                          (group) => _PlanCard(
                            group: group,
                            interval: _interval,
                            currency: catalog.defaultCurrency,
                            currentPlanId: catalog.currentPlan?.id,
                            submittingPlanId: _submittingPlanId,
                            gatewayEnabled: catalog.paymentGatewayEnabled,
                            onSubscribe: _subscribe,
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final border = danger ? const Color(0xFFFECACA) : const Color(0xFFFDE68A);
    final fg = danger ? const Color(0xFF991B1B) : const Color(0xFF92400E);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            danger
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            size: 20,
            color: fg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingIntro extends StatelessWidget {
  const _BillingIntro({required this.catalog});

  final PosBillingCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = catalog.currentPlan;
    final planName = plan != null && plan.name.isNotEmpty
        ? plan.name
        : 'Business Growth Plan';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111319),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF232736), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF251C0F),
                  border: Border.all(
                    color: const Color(0xFFD97706).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEMBERSHIP & SUBSCRIPTION',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      planName,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF34D399),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ACTIVE',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD1FAE5),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            catalog.hasExpiredTrial
                ? l10n.billingUpgradeBody
                : l10n.billingChoosePlan,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntervalToggle extends StatelessWidget {
  const _IntervalToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isYearly = value == 'yearly';

    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: PosTheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: PosTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTab(
              label: l10n.billingMonthly,
              selected: !isYearly,
              onTap: () => onChanged('monthly'),
            ),
            _buildTab(
              label: l10n.billingYearly,
              selected: isYearly,
              badge: 'Save 20%',
              onTap: () => onChanged('yearly'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Material(
      color: selected ? const Color(0xFF13151D) : Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : PosTheme.inkMuted,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.group,
    required this.interval,
    required this.currency,
    required this.currentPlanId,
    required this.submittingPlanId,
    required this.gatewayEnabled,
    required this.onSubscribe,
  });

  final PosBillingPlanGroup group;
  final String interval;
  final String currency;
  final int? currentPlanId;
  final int? submittingPlanId;
  final bool gatewayEnabled;
  final ValueChanged<PosBillingInterval> onSubscribe;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = group.interval(interval) ?? group.monthly ?? group.yearly;
    if (selected == null) return const SizedBox.shrink();
    final isCurrent = currentPlanId != null && currentPlanId == selected.id;
    final isYearly = selected.interval == 'yearly';
    final priceLabel = selected.isFree
        ? l10n.billingFree
        : formatMoney(selected.price, currency);

    final intervalLabel = isYearly ? l10n.billingPerYear : l10n.billingPerMonth;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFF59E0B)
              : PosTheme.border,
          width: isCurrent ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isCurrent ? 0.08 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                      color: PosTheme.ink,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.billingCurrentPlan,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFB45309),
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  priceLabel,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: PosTheme.ink,
                  ),
                ),
                if (!selected.isFree) ...[
                  const SizedBox(width: 6),
                  Text(
                    '/ $intervalLabel',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: PosTheme.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
            if (group.features.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: PosTheme.border.withValues(alpha: 0.7)),
              const SizedBox(height: 14),
              ...group.features.take(6).map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.35,
                                color: PosTheme.ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: isCurrent
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        l10n.billingCurrentPlan,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: PosTheme.border),
                      ),
                    )
                  : FilledButton(
                      onPressed: (!gatewayEnabled && !selected.isFree)
                          ? null
                          : () => onSubscribe(selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF13151D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      child: submittingPlanId == selected.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              selected.isFree
                                  ? l10n.billingActivateFree
                                  : l10n.billingSubscribe,
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
