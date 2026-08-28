class BusinessSetupStepModel {
  const BusinessSetupStepModel({
    required this.code,
    required this.title,
    required this.description,
    required this.mandatory,
    required this.complete,
    required this.route,
    required this.actionLabel,
    required this.detail,
  });

  final String code;
  final String title;
  final String description;
  final bool mandatory;
  final bool complete;
  final String route;
  final String actionLabel;
  final String detail;

  factory BusinessSetupStepModel.fromJson(Map<String, dynamic> json) => BusinessSetupStepModel(
        code: json['code']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        mandatory: json['mandatory'] == true,
        complete: json['complete'] == true,
        route: json['route']?.toString() ?? '',
        actionLabel: json['actionLabel']?.toString() ?? 'Configurar',
        detail: json['detail']?.toString() ?? '',
      );
}

class BusinessSetupStatusModel {
  const BusinessSetupStatusModel({
    this.empresaId,
    required this.required,
    required this.complete,
    required this.completedMandatorySteps,
    required this.totalMandatorySteps,
    required this.progressPercentage,
    this.nextStepCode,
    this.nextRoute,
    this.steps = const <BusinessSetupStepModel>[],
  });

  final int? empresaId;
  final bool required;
  final bool complete;
  final int completedMandatorySteps;
  final int totalMandatorySteps;
  final int progressPercentage;
  final String? nextStepCode;
  final String? nextRoute;
  final List<BusinessSetupStepModel> steps;

  factory BusinessSetupStatusModel.fromJson(Map<String, dynamic> json) => BusinessSetupStatusModel(
        empresaId: (json['empresaId'] as num?)?.toInt(),
        required: json['required'] != false,
        complete: json['complete'] == true,
        completedMandatorySteps: (json['completedMandatorySteps'] as num?)?.toInt() ?? 0,
        totalMandatorySteps: (json['totalMandatorySteps'] as num?)?.toInt() ?? 0,
        progressPercentage: (json['progressPercentage'] as num?)?.toInt() ?? 0,
        nextStepCode: json['nextStepCode']?.toString(),
        nextRoute: json['nextRoute']?.toString(),
        steps: (json['steps'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => BusinessSetupStepModel.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );
}
