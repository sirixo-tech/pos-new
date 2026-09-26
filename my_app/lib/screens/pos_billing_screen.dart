import 'package:flutter/material.dart';
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
        title: Text(l10n.billingTitle),
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  if (_error != null) ...[
                    _Notice(text: _error!, danger: true),
                    const SizedBox(height: 16),
                  ],
                  if (catalog == null)
                    Text(
                      l10n.billingNoPlans,
                      style: TextStyle(color: PosTheme.inkMuted),
                    )
                  else ...[
                    _BillingIntro(catalog: catalog),
                    const SizedBox(height: 18),
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
                        const SizedBox(height: 18),
                      ],
                      _IntervalToggle(
                        value: _interval,
                        onChanged: (next) => setState(() => _interval = next),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        catalog.paymentGatewayEnabled
                            ? l10n.billingPayWith(
                                catalog.paymentGatewayName ??
                                    l10n.billingPaymentProvider,
                              )
                            : l10n.billingPaymentOff,
                        style: TextStyle(
                          color: PosTheme.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (catalog.planGroups.isEmpty)
                        Text(
                          l10n.billingNoPlans,
                          style: TextStyle(color: PosTheme.inkMuted),
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
    final bg = danger ? const Color(0xFFFFE4E6) : const Color(0xFFFFF7ED);
    final fg = danger ? const Color(0xFF9F1239) : const Color(0xFF9A3412);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: fg, height: 1.4)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            catalog.hasExpiredTrial
                ? l10n.subscriptionTrialEndedTitle
                : l10n.billingUpgradePlan,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            catalog.hasExpiredTrial
                ? l10n.billingUpgradeBody
                : l10n.billingChoosePlan,
            style: TextStyle(color: PosTheme.inkMuted, height: 1.4),
          ),
          if (plan != null && plan.name.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${l10n.billingCurrentPlan}: ${plan.name}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
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
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'monthly', label: Text(l10n.billingMonthly)),
        ButtonSegment(value: 'yearly', label: Text(l10n.billingYearly)),
      ],
      selected: {value},
      onSelectionChanged: (next) {
        if (next.isNotEmpty) onChanged(next.first);
      },
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
    final priceLabel = selected.isFree
        ? l10n.billingFree
        : '${formatMoney(selected.price, currency)} / ${selected.interval == 'yearly' ? l10n.billingPerYear : l10n.billingPerMonth}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? Theme.of(context).colorScheme.primary
              : PosTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (isCurrent)
                Text(
                  l10n.billingCurrentPlan,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            priceLabel,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (group.features.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...group.features
                .take(6)
                .map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: PosTheme.inkMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 12),
          PosPrimaryButton(
            label: selected.isFree
                ? l10n.billingActivateFree
                : l10n.billingSubscribe,
            loading: submittingPlanId == selected.id,
            onPressed: isCurrent || (!gatewayEnabled && !selected.isFree)
                ? null
                : () => onSubscribe(selected),
          ),
        ],
      ),
    );
  }
}
