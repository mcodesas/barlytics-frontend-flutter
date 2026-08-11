class SubscriptionModel {
  const SubscriptionModel({
    required this.status,
    required this.active,
    this.planCode,
    this.planName,
    this.planDescription,
    this.price,
    this.currency = 'COP',
    this.paymentMethod,
    this.automaticRenewal = false,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.nextChargeAt,
    this.scheduledPlanCode,
    this.scheduledPlanName,
    this.scheduledPlanPrice,
    this.scheduledPlanEffectiveAt,
  });

  final String status;
  final bool active;
  final String? planCode;
  final String? planName;
  final String? planDescription;
  final double? price;
  final String currency;
  final String? paymentMethod;
  final bool automaticRenewal;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? nextChargeAt;
  final String? scheduledPlanCode;
  final String? scheduledPlanName;
  final double? scheduledPlanPrice;
  final DateTime? scheduledPlanEffectiveAt;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) => SubscriptionModel(
        status: json['status']?.toString() ?? 'PENDING_PAYMENT',
        active: json['active'] == true,
        planCode: json['planCode']?.toString(),
        planName: json['planName']?.toString(),
        planDescription: json['planDescription']?.toString(),
        price: (json['price'] as num?)?.toDouble(),
        currency: json['currency']?.toString() ?? 'COP',
        paymentMethod: json['paymentMethod']?.toString(),
        automaticRenewal: json['automaticRenewal'] == true,
        currentPeriodStart: DateTime.tryParse(json['currentPeriodStart']?.toString() ?? ''),
        currentPeriodEnd: DateTime.tryParse(json['currentPeriodEnd']?.toString() ?? ''),
        nextChargeAt: DateTime.tryParse(json['nextChargeAt']?.toString() ?? ''),
        scheduledPlanCode: json['scheduledPlanCode']?.toString(),
        scheduledPlanName: json['scheduledPlanName']?.toString(),
        scheduledPlanPrice: (json['scheduledPlanPrice'] as num?)?.toDouble(),
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
    this.description,
    this.frequency = 1,
    this.frequencyType = 'months',
    this.trialDays = 0,
    this.current = false,
    this.scheduled = false,
    this.effectiveAt,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final int frequency;
  final String frequencyType;
  final int trialDays;
  final bool current;
  final bool scheduled;
  final DateTime? effectiveAt;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) => SubscriptionPlanModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        price: (json['price'] as num?)?.toDouble() ?? 0,
        currency: json['currency']?.toString() ?? 'COP',
        frequency: (json['frequency'] as num?)?.toInt() ?? 1,
        frequencyType: json['frequencyType']?.toString() ?? 'months',
        trialDays: (json['trialDays'] as num?)?.toInt() ?? 0,
        current: json['current'] == true,
        scheduled: json['scheduled'] == true,
        effectiveAt: DateTime.tryParse(json['effectiveAt']?.toString() ?? ''),
      );
}

class SubscriptionCheckoutModel {
  const SubscriptionCheckoutModel({required this.checkoutUrl, required this.paymentMethod, required this.automaticRenewal});
  final String checkoutUrl;
  final String paymentMethod;
  final bool automaticRenewal;

  factory SubscriptionCheckoutModel.fromJson(Map<String, dynamic> json) => SubscriptionCheckoutModel(
        checkoutUrl: json['checkoutUrl']?.toString() ?? '',
        paymentMethod: json['paymentMethod']?.toString() ?? '',
        automaticRenewal: json['automaticRenewal'] == true,
      );
}
