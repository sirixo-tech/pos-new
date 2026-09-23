int _asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

class PosBillingInterval {
  const PosBillingInterval({
    required this.id,
    required this.price,
    required this.interval,
  });

  final int id;
  final double price;
  final String interval;

  bool get isFree => price <= 0;

  factory PosBillingInterval.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PosBillingInterval(id: 0, price: 0, interval: 'monthly');
    }
    return PosBillingInterval(
      id: _asInt(json['id']),
      price: _asDouble(json['price']),
      interval: '${json['interval'] ?? 'monthly'}',
    );
  }
}

class PosBillingPlanGroup {
  const PosBillingPlanGroup({
    required this.name,
    required this.planGroup,
    this.trialDays = 0,
    this.maxBranches = 1,
    this.maxStaff = 1,
    this.aiCredits = 0,
    this.features = const [],
    this.monthly,
    this.yearly,
  });

  final String name;
  final String planGroup;
  final int trialDays;
  final int maxBranches;
  final int maxStaff;
  final int aiCredits;
  final List<String> features;
  final PosBillingInterval? monthly;
  final PosBillingInterval? yearly;

  PosBillingInterval? interval(String key) =>
      key == 'yearly' ? yearly : monthly;

  factory PosBillingPlanGroup.fromJson(Map<String, dynamic> json) {
    final featuresRaw = json['features'];
    final features = <String>[];
    if (featuresRaw is List) {
      for (final row in featuresRaw) {
        if (row is Map && row['name'] != null) {
          features.add('${row['name']}');
        } else if (row != null) {
          features.add('$row');
        }
      }
    }
    PosBillingInterval? parseInterval(String key) {
      final raw = json[key];
      if (raw is Map) {
        final parsed = PosBillingInterval.fromJson(
          Map<String, dynamic>.from(raw),
        );
        return parsed.id > 0 ? parsed : null;
      }
      return null;
    }

    return PosBillingPlanGroup(
      name: '${json['name'] ?? json['plan_group'] ?? 'Plan'}',
      planGroup: '${json['plan_group'] ?? json['slug'] ?? ''}',
      trialDays: _asInt(json['trial_days']),
      maxBranches: _asInt(json['max_branches'], 1),
      maxStaff: _asInt(json['max_staff'], 1),
      aiCredits: _asInt(json['ai_credits']),
      features: features,
      monthly: parseInterval('monthly'),
      yearly: parseInterval('yearly'),
    );
  }
}

class PosBillingPlan {
  const PosBillingPlan({
    required this.id,
    required this.name,
    this.price = 0,
    this.interval = 'monthly',
  });

  final int id;
  final String name;
  final double price;
  final String interval;

  factory PosBillingPlan.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PosBillingPlan(id: 0, name: '');
    }
    return PosBillingPlan(
      id: _asInt(json['id']),
      name: '${json['name'] ?? ''}',
      price: _asDouble(json['price']),
      interval: '${json['interval'] ?? 'monthly'}',
    );
  }
}

class PosBillingCatalog {
  const PosBillingCatalog({
    required this.coveredByOrganization,
    required this.billingSelfServe,
    required this.isOrganizationOwner,
    required this.scope,
    this.organizationName,
    this.currentPlan,
    this.planGroups = const [],
    this.paymentGatewayEnabled = false,
    this.paymentGatewayName,
    this.defaultCurrency = 'USD',
    this.hasExpiredTrial = false,
    this.hasActiveSubscription = true,
  });

  final bool coveredByOrganization;
  final bool billingSelfServe;
  final bool isOrganizationOwner;
  final String scope;
  final String? organizationName;
  final PosBillingPlan? currentPlan;
  final List<PosBillingPlanGroup> planGroups;
  final bool paymentGatewayEnabled;
  final String? paymentGatewayName;
  final String defaultCurrency;
  final bool hasExpiredTrial;
  final bool hasActiveSubscription;

  bool get canCheckout =>
      billingSelfServe || (coveredByOrganization && isOrganizationOwner);

  factory PosBillingCatalog.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'];
    final organization = json['organization'];
    final scope = '${json['scope'] ?? 'restaurant'}';
    Map<String, dynamic>? planJson;
    if (scope == 'organization' && organization is Map) {
      final plan = organization['plan'];
      if (plan is Map) planJson = Map<String, dynamic>.from(plan);
    } else if (restaurant is Map) {
      final plan = restaurant['plan'];
      if (plan is Map) planJson = Map<String, dynamic>.from(plan);
    }

    return PosBillingCatalog(
      coveredByOrganization: json['covered_by_organization'] == true,
      billingSelfServe: json['billing_self_serve'] == true,
      isOrganizationOwner: json['is_organization_owner'] == true,
      scope: scope,
      organizationName: organization is Map
          ? organization['name']?.toString()
          : null,
      currentPlan: planJson == null ? null : PosBillingPlan.fromJson(planJson),
      planGroups: [
        for (final row
            in (json['plan_groups'] as List? ?? const []).whereType<Map>())
          PosBillingPlanGroup.fromJson(Map<String, dynamic>.from(row)),
      ],
      paymentGatewayEnabled: json['payment_gateway_enabled'] == true,
      paymentGatewayName: json['payment_gateway_name']?.toString(),
      defaultCurrency: '${json['default_currency'] ?? 'USD'}',
      hasExpiredTrial: json['has_expired_trial'] == true,
      hasActiveSubscription: json['has_active_subscription'] == true,
    );
  }
}

class PosBillingCheckoutResult {
  const PosBillingCheckoutResult({this.activated = false, this.checkoutUrl});

  final bool activated;
  final String? checkoutUrl;
}
