class SubscriptionModel {
  const SubscriptionModel({
    required this.status,
    required this.active,
    this.planCode,
    this.planName,
    this.planDescription,
    this.price,
    this.regularPrice,
    this.discountPercentage = 0,
    this.promotionActive = false,
    this.promotionText,
    this.promotionFrom,
    this.promotionUntil,
    this.planFeatures = const <String>[],
    this.currency = 'COP',
    this.frequency = 1,
    this.frequencyType = 'months',
    this.trialDays = 0,
    this.paymentMethod,
    this.automaticRenewal = false,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.nextChargeAt,
    this.cancellationScheduled = false,
    this.cancellationRequestedAt,
    this.cancellationEffectiveAt,
    this.scheduledPlanCode,
    this.scheduledPlanName,
    this.scheduledPlanPrice,
    this.scheduledPlanRegularPrice,
    this.scheduledPlanEffectiveAt,
  });

  final String status;
  final bool active;
  final String? planCode;
  final String? planName;
  final String? planDescription;
  final double? price;
  final double? regularPrice;
  final double discountPercentage;
  final bool promotionActive;
  final String? promotionText;
  final DateTime? promotionFrom;
  final DateTime? promotionUntil;
  final List<String> planFeatures;
  final String currency;
  final int frequency;
  final String frequencyType;
  final int trialDays;
  final String? paymentMethod;
  final bool automaticRenewal;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? nextChargeAt;
  final bool cancellationScheduled;
  final DateTime? cancellationRequestedAt;
  final DateTime? cancellationEffectiveAt;
  final String? scheduledPlanCode;
  final String? scheduledPlanName;
  final double? scheduledPlanPrice;
  final double? scheduledPlanRegularPrice;
  final DateTime? scheduledPlanEffectiveAt;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) => SubscriptionModel(
        status: json['status']?.toString() ?? 'PENDING_PAYMENT',
        active: json['active'] == true,
        planCode: json['planCode']?.toString(),
        planName: json['planName']?.toString(),
        planDescription: json['planDescription']?.toString(),
        price: (json['price'] as num?)?.toDouble(),
        regularPrice: (json['regularPrice'] as num?)?.toDouble(),
        discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0,
        promotionActive: json['promotionActive'] == true,
        promotionText: json['promotionText']?.toString(),
        promotionFrom: DateTime.tryParse(json['promotionFrom']?.toString() ?? ''),
        promotionUntil: DateTime.tryParse(json['promotionUntil']?.toString() ?? ''),
        planFeatures: (json['planFeatures'] as List? ?? const <dynamic>[])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false),
        currency: json['currency']?.toString() ?? 'COP',
        frequency: (json['frequency'] as num?)?.toInt() ?? 1,
        frequencyType: json['frequencyType']?.toString() ?? 'months',
        trialDays: (json['trialDays'] as num?)?.toInt() ?? 0,
        paymentMethod: json['paymentMethod']?.toString(),
        automaticRenewal: json['automaticRenewal'] == true,
        currentPeriodStart: DateTime.tryParse(json['currentPeriodStart']?.toString() ?? ''),
        currentPeriodEnd: DateTime.tryParse(json['currentPeriodEnd']?.toString() ?? ''),
        nextChargeAt: DateTime.tryParse(json['nextChargeAt']?.toString() ?? ''),
        cancellationScheduled: json['cancellationScheduled'] == true,
        cancellationRequestedAt: DateTime.tryParse(json['cancellationRequestedAt']?.toString() ?? ''),
        cancellationEffectiveAt: DateTime.tryParse(json['cancellationEffectiveAt']?.toString() ?? ''),
        scheduledPlanCode: json['scheduledPlanCode']?.toString(),
        scheduledPlanName: json['scheduledPlanName']?.toString(),
        scheduledPlanPrice: (json['scheduledPlanPrice'] as num?)?.toDouble(),
        scheduledPlanRegularPrice: (json['scheduledPlanRegularPrice'] as num?)?.toDouble(),
        scheduledPlanEffectiveAt: DateTime.tryParse(json['scheduledPlanEffectiveAt']?.toString() ?? ''),
      );
}

class SubscriptionPlanModel {
  const SubscriptionPlanModel({
    required this.id,
    required this.code,
    required this.name,
    required this.price,
    required this.currency,
    this.regularPrice = 0,
    this.discountPercentage = 0,
    this.promotionActive = false,
    this.promotionText,
    this.promotionFrom,
    this.promotionUntil,
    this.description,
    this.frequency = 1,
    this.frequencyType = 'months',
    this.trialDays = 0,
    this.displayOrder = 100,
    this.recommended = false,
    this.publicVisible = true,
    this.quoteRequired = false,
    this.badge,
    this.buttonText,
    this.buttonAction = 'REGISTER',
    this.features = const <String>[],
    this.capabilities = const <String, String>{},
    this.current = false,
    this.scheduled = false,
    this.effectiveAt,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final double price;
  final double regularPrice;
  final double discountPercentage;
  final bool promotionActive;
  final String? promotionText;
  final DateTime? promotionFrom;
  final DateTime? promotionUntil;
  final String currency;
  final int frequency;
  final String frequencyType;
  final int trialDays;
  final int displayOrder;
  final bool recommended;
  final bool publicVisible;
  final bool quoteRequired;
  final String? badge;
  final String? buttonText;
  final String buttonAction;
  final List<String> features;
  final Map<String, String> capabilities;
  final bool current;
  final bool scheduled;
  final DateTime? effectiveAt;

  bool get hasDiscount => promotionActive && discountPercentage > 0 && regularPrice > price;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) => SubscriptionPlanModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        price: (json['price'] as num?)?.toDouble() ?? 0,
        regularPrice: (json['regularPrice'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0,
        discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0,
        promotionActive: json['promotionActive'] == true,
        promotionText: json['promotionText']?.toString(),
        promotionFrom: DateTime.tryParse(json['promotionFrom']?.toString() ?? ''),
        promotionUntil: DateTime.tryParse(json['promotionUntil']?.toString() ?? ''),
        currency: json['currency']?.toString() ?? 'COP',
        frequency: (json['frequency'] as num?)?.toInt() ?? 1,
        frequencyType: json['frequencyType']?.toString() ?? 'months',
        trialDays: (json['trialDays'] as num?)?.toInt() ?? 0,
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 100,
        recommended: json['recommended'] == true,
        publicVisible: json['publicVisible'] != false,
        quoteRequired: json['quoteRequired'] == true,
        badge: json['badge']?.toString(),
        buttonText: json['buttonText']?.toString(),
        buttonAction: json['buttonAction']?.toString() ?? 'REGISTER',
        features: (json['features'] as List? ?? const <dynamic>[])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false),
        capabilities: (json['capabilities'] as Map? ?? const <dynamic, dynamic>{})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
        current: json['current'] == true,
        scheduled: json['scheduled'] == true,
        effectiveAt: DateTime.tryParse(json['effectiveAt']?.toString() ?? ''),
      );
}

class PlanCapabilitiesModel {
  const PlanCapabilitiesModel({required this.planName, required this.limits, required this.features});
  final String planName;
  final Map<String, PlanLimitUsageModel> limits;
  final Map<String, bool> features;

  bool includes(String code) => features[code] == true;
  bool reached(String code) {
    final item = limits[code];
    return item != null && item.limit != -1 && item.used >= item.limit;
  }

  factory PlanCapabilitiesModel.fromJson(Map<String, dynamic> json) => PlanCapabilitiesModel(
        planName: (json['plan'] as Map?)?['name']?.toString() ?? '',
        limits: (json['limits'] as Map? ?? const <dynamic, dynamic>{}).map((key, value) => MapEntry(
              key.toString(),
              PlanLimitUsageModel.fromJson(Map<String, dynamic>.from(value as Map)),
            )),
        features: (json['features'] as Map? ?? const <dynamic, dynamic>{})
            .map((key, value) => MapEntry(key.toString(), value == true)),
      );
}

class PlanLimitUsageModel {
  const PlanLimitUsageModel({required this.limit, required this.used, required this.remaining, required this.exceeded});
  final int limit;
  final int used;
  final int remaining;
  final bool exceeded;
  factory PlanLimitUsageModel.fromJson(Map<String, dynamic> json) => PlanLimitUsageModel(
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        used: (json['used'] as num?)?.toInt() ?? 0,
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
        exceeded: json['exceeded'] == true,
      );
}

class SubscriptionPrepaidOptionModel {
  const SubscriptionPrepaidOptionModel({required this.periods, required this.amount});

  final int periods;
  final double amount;

  factory SubscriptionPrepaidOptionModel.fromJson(Map<String, dynamic> json) => SubscriptionPrepaidOptionModel(
        periods: (json['periods'] as num?)?.toInt() ?? 1,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );
}

class SubscriptionPseBankModel {
  const SubscriptionPseBankModel({required this.id, required this.description});

  final String id;
  final String description;

  factory SubscriptionPseBankModel.fromJson(Map<String, dynamic> json) => SubscriptionPseBankModel(
        id: json['id']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
      );
}

class SubscriptionPaymentConfigModel {
  const SubscriptionPaymentConfigModel({
    required this.enabled,
    required this.recurringEnabled,
    required this.oneTimeEnabled,
    required this.provider,
    required this.publicKey,
    required this.amount,
    required this.regularAmount,
    required this.discountPercentage,
    required this.promotionActive,
    required this.currency,
    required this.payerEmail,
    required this.trialDays,
    required this.frequency,
    required this.frequencyType,
    required this.localSubscriptionId,
    required this.localPlanId,
    required this.providerPlanId,
    required this.providerSubscriptionId,
    required this.prepaidOptions,
  });

  final bool enabled;
  final bool recurringEnabled;
  final bool oneTimeEnabled;
  final String provider;
  final String publicKey;
  final double amount;
  final double regularAmount;
  final double discountPercentage;
  final bool promotionActive;
  final String currency;
  final String payerEmail;
  final int trialDays;
  final int frequency;
  final String frequencyType;
  final int localSubscriptionId;
  final int localPlanId;
  final String? providerPlanId;
  final String? providerSubscriptionId;
  final List<SubscriptionPrepaidOptionModel> prepaidOptions;

  double amountForPeriods(int periods) {
    for (final option in prepaidOptions) {
      if (option.periods == periods) return option.amount;
    }
    return amount;
  }

  factory SubscriptionPaymentConfigModel.fromJson(Map<String, dynamic> json) => SubscriptionPaymentConfigModel(
        enabled: json['enabled'] == true,
        recurringEnabled: json['recurringEnabled'] == true,
        oneTimeEnabled: json['oneTimeEnabled'] != false,
        provider: json['provider']?.toString() ?? 'MERCADOPAGO',
        publicKey: json['publicKey']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        regularAmount: (json['regularAmount'] as num?)?.toDouble() ?? (json['amount'] as num?)?.toDouble() ?? 0,
        discountPercentage: (json['discountPercentage'] as num?)?.toDouble() ?? 0,
        promotionActive: json['promotionActive'] == true,
        currency: json['currency']?.toString() ?? 'COP',
        payerEmail: json['payerEmail']?.toString() ?? '',
        trialDays: (json['trialDays'] as num?)?.toInt() ?? 0,
        frequency: (json['frequency'] as num?)?.toInt() ?? 1,
        frequencyType: json['frequencyType']?.toString() ?? 'months',
        localSubscriptionId: (json['localSubscriptionId'] as num?)?.toInt() ?? 0,
        localPlanId: (json['localPlanId'] as num?)?.toInt() ?? 0,
        providerPlanId: json['providerPlanId']?.toString(),
        providerSubscriptionId: json['providerSubscriptionId']?.toString(),
        prepaidOptions: (json['prepaidOptions'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => SubscriptionPrepaidOptionModel.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.periods >= 1 && item.periods <= 12)
            .toList(growable: false),
      );
}

class SubscriptionCheckoutModel {
  const SubscriptionCheckoutModel({
    required this.provider,
    required this.checkoutType,
    required this.checkoutUrl,
    required this.externalReference,
    required this.localSubscriptionId,
    required this.localPlanId,
    required this.providerPlanId,
    required this.providerSubscriptionId,
    required this.preferenceId,
    required this.amount,
    required this.currency,
    required this.automaticRenewal,
    required this.prepaidPeriods,
    required this.trialDaysApplied,
    required this.estimatedCoverageUntil,
  });

  final String provider;
  final String checkoutType;
  final String checkoutUrl;
  final String? externalReference;
  final int localSubscriptionId;
  final int localPlanId;
  final String? providerPlanId;
  final String? providerSubscriptionId;
  final String? preferenceId;
  final double amount;
  final String currency;
  final bool automaticRenewal;
  final int prepaidPeriods;
  final int trialDaysApplied;
  final DateTime? estimatedCoverageUntil;

  factory SubscriptionCheckoutModel.fromJson(Map<String, dynamic> json) => SubscriptionCheckoutModel(
        provider: json['provider']?.toString() ?? 'MERCADOPAGO',
        checkoutType: json['checkoutType']?.toString() ?? '',
        checkoutUrl: json['checkoutUrl']?.toString() ?? '',
        externalReference: json['externalReference']?.toString(),
        localSubscriptionId: (json['localSubscriptionId'] as num?)?.toInt() ?? 0,
        localPlanId: (json['localPlanId'] as num?)?.toInt() ?? 0,
        providerPlanId: json['providerPlanId']?.toString(),
        providerSubscriptionId: json['providerSubscriptionId']?.toString(),
        preferenceId: json['preferenceId']?.toString(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency']?.toString() ?? 'COP',
        automaticRenewal: json['automaticRenewal'] == true,
        prepaidPeriods: (json['prepaidPeriods'] as num?)?.toInt() ?? 1,
        trialDaysApplied: (json['trialDaysApplied'] as num?)?.toInt() ?? 0,
        estimatedCoverageUntil: DateTime.tryParse(json['estimatedCoverageUntil']?.toString() ?? ''),
      );
}
