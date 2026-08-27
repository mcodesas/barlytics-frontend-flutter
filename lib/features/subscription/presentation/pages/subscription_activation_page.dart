import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/widgets/barlytics_brand.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/subscription_models.dart';
import '../providers/subscription_provider.dart';
import '../widgets/mercado_pago_recurring_brick.dart';

class SubscriptionActivationPage extends ConsumerStatefulWidget {
  const SubscriptionActivationPage({super.key});

  @override
  ConsumerState<SubscriptionActivationPage> createState() => _SubscriptionActivationPageState();
}

class _SubscriptionActivationPageState extends ConsumerState<SubscriptionActivationPage> {
  SubscriptionModel? _subscription;
  List<SubscriptionPlanModel> _plans = const <SubscriptionPlanModel>[];
  SubscriptionPaymentConfigModel? _paymentConfig;
  String? _authToken;
  String? _paymentConfigError;
  bool _automaticRenewalCheckout = true;
  int _prepaidPeriods = 1;
  bool _startingCheckout = false;
  String? _message;
  bool _loading = true;
  bool _changingPlan = false;
  bool _profileLoading = false;
  bool _savingProfile = false;
  bool _savingCompany = false;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _company;
  String? _profileError;
  String? _companyError;

  AppPalette get _palette => appPalettes.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }

    try {
      final params = _returnParameters();
      final paymentId = _cleanReturnParameter(params['payment_id'] ?? params['paymentId']);
      final preapprovalId = _cleanReturnParameter(params['preapproval_id'] ?? params['preapprovalId']);
      final externalReference = _cleanReturnParameter(params['external_reference'] ?? params['externalReference']);
      final preferenceId = _cleanReturnParameter(params['preference_id'] ?? params['preferenceId']);
      final mpReturn = _cleanReturnParameter(params['mp_return']);
      final collectionStatus = _cleanReturnParameter(params['collection_status']);
      final status = _cleanReturnParameter(params['status']);
      final returnedFromPayment = paymentId != null ||
          preapprovalId != null ||
          externalReference != null ||
          preferenceId != null ||
          mpReturn != null ||
          collectionStatus != null ||
          status != null;
      final remote = ref.read(subscriptionRemoteDataSourceProvider);

      final results = await Future.wait<Object>([
        returnedFromPayment
            ? remote.sync(
                paymentId: paymentId,
                preapprovalId: preapprovalId,
                externalReference: externalReference,
                preferenceId: preferenceId,
              )
            : remote.current(),
        remote.plans(),
      ]);

      if (!mounted) return;
      _plans = results[1] as List<SubscriptionPlanModel>;
      await _loadProfileSummary();
      await _refreshPaymentConfig();
      await _applySubscription(
        results[0] as SubscriptionModel,
        navigateIfActivated: returnedFromPayment,
      );
    } catch (error) {
      if (mounted) setState(() => _message = _cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _loadProfileSummary() async {
    if (!mounted) return;
    setState(() {
      _profileLoading = true;
      _profileError = null;
      _companyError = null;
    });
    try {
      final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
            ApiPaths.profile,
            (json) => Map<String, dynamic>.from(json as Map),
          );
      if (!mounted) return;
      final profile = response.data ?? <String, dynamic>{};
      Map<String, dynamic>? company;
      String? companyError;
      final companyId = int.tryParse(profile['empresaId']?.toString() ?? '');
      if (companyId != null) {
        try {
          final companyResponse = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
                '${ApiPaths.profile}/company',
                (json) => Map<String, dynamic>.from(json as Map),
              );
          company = companyResponse.data;
        } catch (error) {
          companyError = _cleanError(error);
        }
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _company = company;
        _companyError = companyError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _profileError = _cleanError(error));
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  String _profileText(String key, {String fallback = 'No registrado'}) {
    final value = _profile?[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  String get _profileName {
    final parts = <String>[
      _profileText('primerNombre', fallback: ''),
      _profileText('segundoNombre', fallback: ''),
      _profileText('primerApellido', fallback: ''),
      _profileText('segundoApellido', fallback: ''),
    ].where((value) => value.isNotEmpty).toList();
    return parts.isEmpty ? 'Usuario BarLytics' : parts.join(' ');
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null || _savingProfile) return;

    final firstName = TextEditingController(text: profile['primerNombre']?.toString() ?? '');
    final secondName = TextEditingController(text: profile['segundoNombre']?.toString() ?? '');
    final firstLastName = TextEditingController(text: profile['primerApellido']?.toString() ?? '');
    final secondLastName = TextEditingController(text: profile['segundoApellido']?.toString() ?? '');
    final email = TextEditingController(text: profile['email']?.toString() ?? '');
    final phone = TextEditingController(text: profile['telefonoPrincipal']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: _palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        final phoneLayout = MediaQuery.sizeOf(sheetContext).width < 640;
        Widget field(TextEditingController controller, String label, {bool required = true, TextInputType? keyboardType, bool enabled = true}) {
          return TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            decoration: InputDecoration(labelText: label),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (required && text.isEmpty) return 'Campo obligatorio';
              if (label == 'Correo' && text.isNotEmpty && (!text.contains('@') || !text.contains('.'))) {
                return 'Correo no válido';
              }
              return null;
            },
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + bottom),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Editar tus datos',
                          style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Revisa que estos datos sean correctos antes de continuar con el pago.',
                    style: TextStyle(color: _palette.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  if (phoneLayout) ...[
                    field(firstName, 'Primer nombre'),
                    const SizedBox(height: 12),
                    field(secondName, 'Segundo nombre', required: false),
                    const SizedBox(height: 12),
                    field(firstLastName, 'Primer apellido'),
                    const SizedBox(height: 12),
                    field(secondLastName, 'Segundo apellido'),
                  ] else ...[
                    Row(children: [Expanded(child: field(firstName, 'Primer nombre')), const SizedBox(width: 12), Expanded(child: field(secondName, 'Segundo nombre', required: false))]),
                    const SizedBox(height: 12),
                    Row(children: [Expanded(child: field(firstLastName, 'Primer apellido')), const SizedBox(width: 12), Expanded(child: field(secondLastName, 'Segundo apellido'))]),
                  ],
                  const SizedBox(height: 12),
                  field(email, 'Correo de acceso', keyboardType: TextInputType.emailAddress, enabled: false),
                  const SizedBox(height: 12),
                  field(phone, 'Teléfono', required: false, keyboardType: TextInputType.phone),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.of(sheetContext).pop(true);
                      }
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar cambios'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (saved != true || !mounted) {
      firstName.dispose();
      secondName.dispose();
      firstLastName.dispose();
      secondLastName.dispose();
      email.dispose();
      phone.dispose();
      return;
    }

    setState(() => _savingProfile = true);
    try {
      int? number(dynamic value) => int.tryParse(value?.toString() ?? '');
      await ref.read(apiClientProvider).put(
        ApiPaths.profile,
        <String, dynamic>{
          'paisId': number(profile['paisId']),
          'regiId': number(profile['regionId'] ?? profile['regiId']),
          'ciudId': number(profile['ciudadId'] ?? profile['ciudId']),
          'primerNombre': firstName.text.trim(),
          'segundoNombre': secondName.text.trim().isEmpty ? null : secondName.text.trim(),
          'primerApellido': firstLastName.text.trim(),
          'segundoApellido': secondLastName.text.trim(),
          'email': profile['email']?.toString() ?? email.text.trim(),
          'fechaNacimiento': profile['fechaNacimiento'],
          'direccion': profile['direccion'],
          'telefonoPrincipal': phone.text.trim().isEmpty ? null : phone.text.trim(),
          'telefonoSecundario': profile['telefonoSecundario'],
          'foto': profile['foto'] ?? profile['usuaFoto'],
        },
        (json) => json,
      );
      await _loadProfileSummary();
      if (mounted) {
        setState(() => _message = 'Tus datos fueron actualizados correctamente.');
      }
    } catch (error) {
      if (mounted) setState(() => _message = _cleanError(error));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
      firstName.dispose();
      secondName.dispose();
      firstLastName.dispose();
      secondLastName.dispose();
      email.dispose();
      phone.dispose();
    }
  }

  Future<void> _editCompany() async {
    final company = _company;
    if (company == null || _savingCompany) return;

    final commercialName = TextEditingController(text: company['empreNombreComercial']?.toString() ?? '');
    final legalName = TextEditingController(text: company['emprRazonSocial']?.toString() ?? '');
    final identification = TextEditingController(text: company['emprIdentificacion']?.toString() ?? '');
    final address = TextEditingController(text: company['emprDireccion']?.toString() ?? '');
    final phone = TextEditingController(text: company['emprTelefono']?.toString() ?? '');
    final companyEmail = TextEditingController(text: company['emprCorreoElectronico']?.toString() ?? '');
    final website = TextEditingController(text: company['emprSitioWeb']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: _palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottom = MediaQuery.viewInsetsOf(sheetContext).bottom;
        Widget field(TextEditingController controller, String label, {bool required = true, TextInputType? keyboardType}) {
          return TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(labelText: label),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (required && text.isEmpty) return 'Campo obligatorio';
              if (label.contains('Correo') && text.isNotEmpty && (!text.contains('@') || !text.contains('.'))) {
                return 'Correo no válido';
              }
              return null;
            },
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + bottom),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Editar datos del negocio',
                          style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Estos son los datos de la empresa que registraste antes de llegar al pago.',
                    style: TextStyle(color: _palette.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  field(commercialName, 'Nombre comercial'),
                  const SizedBox(height: 12),
                  field(legalName, 'Razón social'),
                  const SizedBox(height: 12),
                  field(identification, 'Identificación'),
                  const SizedBox(height: 12),
                  field(address, 'Dirección'),
                  const SizedBox(height: 12),
                  field(phone, 'Teléfono', keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  field(companyEmail, 'Correo de la empresa', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  field(website, 'Sitio web', required: false, keyboardType: TextInputType.url),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.of(sheetContext).pop(true);
                      }
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar cambios'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (saved != true || !mounted) {
      for (final controller in [commercialName, legalName, identification, address, phone, companyEmail, website]) {
        controller.dispose();
      }
      return;
    }

    setState(() => _savingCompany = true);
    try {
      int? number(dynamic value) => int.tryParse(value?.toString() ?? '');
      final companyId = number(company['emprId']) ?? number(_profile?['empresaId']);
      if (companyId == null) throw StateError('No fue posible identificar la empresa.');
      await ref.read(apiClientProvider).put(
        '${ApiPaths.profile}/company',
        <String, dynamic>{
          'tiidId': number(company['tiidId']),
          'paisIdtelefono': number(company['paisIdtelefono']),
          'ciudId': number(company['ciudId']),
          'zohoId': number(company['zohoId']),
          'empreNombreComercial': commercialName.text.trim(),
          'emprRazonSocial': legalName.text.trim(),
          'emprIdentificacion': identification.text.trim(),
          'emprDireccion': address.text.trim(),
          'emprCodigoPostal': company['emprCodigoPostal'],
          'emprTelefono': phone.text.trim(),
          'emprCorreoElectronico': companyEmail.text.trim(),
          'emprSitioWeb': website.text.trim().isEmpty ? null : website.text.trim(),
          'emprLogo': company['emprLogo'],
          'emprEstado': number(company['emprEstado']) ?? 1,
        },
        (json) => json,
      );
      await _loadProfileSummary();
      if (mounted) setState(() => _message = 'Los datos del negocio fueron actualizados correctamente.');
    } catch (error) {
      if (mounted) setState(() => _message = _cleanError(error));
    } finally {
      if (mounted) setState(() => _savingCompany = false);
      for (final controller in [commercialName, legalName, identification, address, phone, companyEmail, website]) {
        controller.dispose();
      }
    }
  }

  Future<void> _refreshPaymentConfig() async {
    try {
      final remote = ref.read(subscriptionRemoteDataSourceProvider);
      final results = await Future.wait<Object?>([
        remote.paymentConfig(),
        ref.read(secureStorageProvider).read(StorageKeys.authToken),
      ]);
      if (!mounted) return;
      final config = results[0] as SubscriptionPaymentConfigModel;
      final validPeriods = config.prepaidOptions.map((item) => item.periods).toSet();
      setState(() {
        _paymentConfig = config;
        _authToken = results[1]?.toString();
        if (!validPeriods.contains(_prepaidPeriods)) _prepaidPeriods = 1;
        _paymentConfigError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _paymentConfig = null;
        _authToken = null;
        _paymentConfigError = _cleanError(error);
      });
    }
  }

  Future<void> _startMercadoPagoCheckout() async {
    final config = _paymentConfig;
    if (config == null || _startingCheckout || _automaticRenewalCheckout) return;
    setState(() {
      _startingCheckout = true;
      _message = null;
    });
    try {
      final checkout = await ref.read(subscriptionRemoteDataSourceProvider).oneTimeCheckout(_prepaidPeriods);
      final uri = Uri.tryParse(checkout.checkoutUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw StateError('Mercado Pago no devolvió una URL de checkout válida.');
      }
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
      if (!opened) throw StateError('No fue posible abrir Mercado Pago.');
    } catch (error) {
      if (mounted) setState(() => _message = _cleanError(error));
    } finally {
      if (mounted) setState(() => _startingCheckout = false);
    }
  }

  Future<void> _applySubscription(
    SubscriptionModel subscription, {
    bool navigateIfActivated = false,
  }) async {
    if (!mounted) return;
    final wasActive = _subscription?.active ?? ref.read(authControllerProvider).subscriptionActive;
    setState(() => _subscription = subscription);
    await ref.read(authControllerProvider.notifier).updateSubscription(
          status: subscription.status,
          active: subscription.active,
        );
    if (navigateIfActivated && !wasActive && subscription.active && mounted) {
      context.go('/home');
    }
  }

  Future<void> _changePlan(SubscriptionPlanModel plan) async {
    if (_changingPlan || plan.code.isEmpty) return;
    setState(() {
      _changingPlan = true;
      _message = null;
    });
    try {
      final remote = ref.read(subscriptionRemoteDataSourceProvider);
      final subscription = await remote.changePlan(plan.code);
      final plans = await remote.plans();
      if (!mounted) return;
      setState(() => _plans = plans);
      await _refreshPaymentConfig();
      await _applySubscription(subscription);
      if (mounted) {
        setState(() {
          _message = subscription.scheduledPlanCode == null
              ? 'Plan ${subscription.planName ?? plan.name} seleccionado.'
              : 'El cambio a ${subscription.scheduledPlanName ?? plan.name} quedó programado para ${_formatDate(subscription.scheduledPlanEffectiveAt)}.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = _cleanError(error));
    } finally {
      if (mounted) setState(() => _changingPlan = false);
    }
  }

  Map<String, String> _returnParameters() {
    final result = <String, String>{...Uri.base.queryParameters};
    final fragment = Uri.base.fragment;
    final fragmentUri = Uri.tryParse(fragment.startsWith('/') ? fragment : '/$fragment');
    if (fragmentUri != null) result.addAll(fragmentUri.queryParameters);
    return result;
  }

  String? _cleanReturnParameter(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return null;
    }
    return normalized;
  }

  String get _frontendReturnUrl => '${Uri.base.scheme}://${Uri.base.authority}/#/activar-suscripcion';

  String _formatDate(DateTime? date) {
    if (date == null) return 'el próximo ciclo';
    return DateFormat('dd/MM/yyyy', 'es_CO').format(date.toLocal());
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');

  String _money(double value) =>
      NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0).format(value);

  String _discountLabel(double value) {
    final rounded = value.roundToDouble();
    return value == rounded ? value.toInt().toString() : value.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _billingPeriod(int frequency, String frequencyType, {bool withPreposition = false}) {
    final safeFrequency = frequency < 1 ? 1 : frequency;
    final type = frequencyType.trim().toLowerCase();
    String unit;
    if (type.startsWith('day')) {
      unit = safeFrequency == 1 ? 'día' : '$safeFrequency días';
    } else if (type.startsWith('week')) {
      unit = safeFrequency == 1 ? 'semana' : '$safeFrequency semanas';
    } else if (type.startsWith('year')) {
      unit = safeFrequency == 1 ? 'año' : '$safeFrequency años';
    } else {
      unit = safeFrequency == 1 ? 'mes' : '$safeFrequency meses';
    }
    return withPreposition ? 'cada $unit' : unit;
  }

  SubscriptionPlanModel? _currentPlan() {
    for (final plan in _plans) {
      if (plan.current) return plan;
    }
    final code = _subscription?.planCode;
    for (final plan in _plans) {
      if (plan.code == code) return plan;
    }
    return _plans.isEmpty ? null : _plans.first;
  }

  Future<void> _showPlanPicker() async {
    if (_plans.isEmpty) return;
    final palette = _palette;
    final current = _currentPlan();
    final selected = await showModalBottomSheet<SubscriptionPlanModel>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        final phone = MediaQuery.sizeOf(context).width < 600;
        return FractionallySizedBox(
          heightFactor: phone ? .78 : .64,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cambiar plan',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                  itemCount: _plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final plan = _plans[index];
                    final isCurrent = plan.code == current?.code;
                    return Material(
                      color: isCurrent ? palette.primary.withOpacity(.08) : palette.background.withOpacity(.35),
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        title: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (plan.quoteRequired)
                                Text(
                                  'Requiere cotización',
                                  style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900),
                                )
                              else ...[
                                if (plan.hasDiscount)
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        _money(plan.regularPrice),
                                        style: TextStyle(
                                          color: palette.textSecondary,
                                          fontWeight: FontWeight.w700,
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: palette.success.withOpacity(.12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '-${_discountLabel(plan.discountPercentage)}%',
                                          style: TextStyle(color: palette.success, fontWeight: FontWeight.w900, fontSize: 10.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                Text(
                                  '${_money(plan.price)} ${plan.currency} / ${_billingPeriod(plan.frequency, plan.frequencyType)}',
                                  style: TextStyle(
                                    color: palette.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (plan.promotionActive && (plan.promotionText?.trim().isNotEmpty ?? false)) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    plan.promotionText!.trim(),
                                    style: TextStyle(color: palette.primary, fontSize: 11.5, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ],
                              if (plan.description != null && plan.description!.trim().isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  plan.description!.trim(),
                                  maxLines: phone ? 4 : 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if (plan.features.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                for (final feature in plan.features.take(phone ? 4 : 6))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.check_rounded, size: 14, color: palette.success),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            feature,
                                            style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              if (plan.trialDays > 0) ...[
                                const SizedBox(height: 5),
                                Text(
                                  '${plan.trialDays} días de prueba',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: isCurrent
                            ? Icon(Icons.check_circle_rounded, color: palette.success)
                            : plan.quoteRequired
                                ? Icon(Icons.request_quote_outlined, color: palette.textSecondary)
                                : const Icon(Icons.chevron_right_rounded),
                        onTap: plan.quoteRequired ? null : () => Navigator.of(context).pop(plan),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected.code != current?.code) await _changePlan(selected);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Theme(
      data: AppTheme.buildFromPalette(palette),
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Column(
            children: [
              _header(palette),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: palette.primary))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            MediaQuery.sizeOf(context).width < 600 ? 10 : 22,
                            MediaQuery.sizeOf(context).width < 600 ? 10 : 22,
                            MediaQuery.sizeOf(context).width < 600 ? 10 : 22,
                            30,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1080),
                              child: _content(palette),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppPalette palette) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    return Container(
      height: phone ? 56 : 66,
      padding: EdgeInsets.symmetric(horizontal: phone ? 12 : 22),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.translucentBorder)),
      ),
      child: Row(
        children: [
          BarLyticsBrandLockup(
            width: phone ? 128 : 156,
            height: phone ? 34 : 42,
            darkBackground: palette.darkBackground,
            showTagline: false,
            alignment: Alignment.centerLeft,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  Widget _content(AppPalette palette) {
    final subscription = _subscription;
    if (subscription == null) {
      return _notice(palette, 'No fue posible cargar la suscripción.', error: true);
    }

    final currentPlan = _currentPlan();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _progressCard(palette, active: subscription.active ? 4 : 2),
        const SizedBox(height: 14),
        if (_message != null) ...[
          _notice(palette, _message!),
          const SizedBox(height: 12),
        ],
        if (subscription.active)
          _activePanel(palette, subscription)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 920;
              final review = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _personCard(palette),
                  const SizedBox(height: 12),
                  _planCard(palette, subscription, currentPlan),
                  const SizedBox(height: 12),
                  _accessPreviewCard(palette),
                ],
              );
              final payment = _paymentPanel(palette);
              if (!desktop) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    review,
                    const SizedBox(height: 14),
                    payment,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 350, child: review),
                  const SizedBox(width: 18),
                  Expanded(child: payment),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _progressCard(AppPalette palette, {required int active}) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    final steps = <({IconData icon, String title, String subtitle})>[
      (icon: Icons.person_outline_rounded, title: 'Cuenta y datos', subtitle: 'Revisa tu información'),
      (icon: Icons.workspace_premium_outlined, title: 'Plan', subtitle: 'Confirma o cámbialo'),
      (icon: Icons.lock_outline_rounded, title: 'Pago', subtitle: 'Mercado Pago'),
    ];

    if (phone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.translucentBorder),
        ),
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: i + 1 <= active ? palette.primary.withOpacity(.55) : palette.translucentBorder,
                  ),
                ),
              _CompactStep(
                palette: palette,
                number: i + 1,
                icon: steps[i].icon,
                completed: i + 1 < active,
                active: i + 1 == active,
              ),
            ],
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Text(
                active > 3 ? 'Proceso completado' : active == 3 ? 'Paso 3 de 3 · Pago' : 'Paso 2 de 3 · Revisa y paga',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.translucentBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: _ProgressSummaryStep(
                palette: palette,
                number: i + 1,
                icon: steps[i].icon,
                title: steps[i].title,
                subtitle: steps[i].subtitle,
                completed: i + 1 < active,
                active: i + 1 == active,
              ),
            ),
            if (i < steps.length - 1)
              Container(
                width: 34,
                height: 2,
                color: i + 2 <= active ? palette.primary.withOpacity(.55) : palette.translucentBorder,
              ),
          ],
        ],
      ),
    );
  }

  Widget _personCard(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.translucentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.primary.withOpacity(.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_outline_rounded, color: palette.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tus datos', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    SizedBox(height: 2),
                    Text('Confirma la información antes de pagar', style: TextStyle(fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_profileLoading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_profileError != null)
            _notice(palette, 'No fue posible cargar tus datos: $_profileError', error: true)
          else ...[
            _reviewRow(palette, Icons.badge_outlined, 'Titular', _profileName),
            _reviewRow(palette, Icons.alternate_email_rounded, 'Correo', _profileText('email')),
            _reviewRow(palette, Icons.phone_outlined, 'Teléfono', _profileText('telefonoPrincipal')),
            _reviewRow(
              palette,
              Icons.storefront_outlined,
              'Empresa',
              _profileText('empresaNombreComercial', fallback: _profileText('empresaRazonSocial')),
            ),
            _reviewRow(
              palette,
              Icons.apartment_outlined,
              'Razón social',
              _profileText('empresaRazonSocial'),
            ),
            _reviewRow(
              palette,
              Icons.confirmation_number_outlined,
              'Identificación',
              _profileText('empresaIdentificacion'),
            ),
            _reviewRow(
              palette,
              Icons.admin_panel_settings_outlined,
              'Rol',
              ((_profile?['roles'] is List)
                      ? (_profile!['roles'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).join(', ')
                      : _profileText('tipoUsuarioNombre', fallback: 'GERENTE'))
                  .trim(),
              last: true,
            ),
          ],
          if (_companyError != null) ...[
            const SizedBox(height: 10),
            Text(
              'No fue posible cargar la edición del negocio: $_companyError',
              style: TextStyle(color: palette.textSecondary, fontSize: 10.8),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 320;
              final personButton = OutlinedButton.icon(
                onPressed: _profileLoading || _savingProfile || _profile == null ? null : _editProfile,
                icon: _savingProfile
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.edit_outlined, size: 18),
                label: Text(_savingProfile ? 'Guardando…' : 'Editar persona'),
              );
              final companyButton = OutlinedButton.icon(
                onPressed: _savingCompany || _company == null ? null : _editCompany,
                icon: _savingCompany
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.storefront_outlined, size: 18),
                label: Text(_savingCompany ? 'Guardando…' : 'Editar negocio'),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    personButton,
                    const SizedBox(height: 8),
                    companyButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: personButton),
                  const SizedBox(width: 8),
                  Expanded(child: companyButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _accessPreviewCard(AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.translucentBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(Icons.lock_open_outlined, color: palette.primary, size: 20),
          title: const Text(
            'Qué se habilita después del pago',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
          subtitle: Text(
            'Tu usuario GERENTE ya está creado',
            style: TextStyle(color: palette.textSecondary, fontSize: 10.8),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: const [
                  _FeatureChip(icon: Icons.point_of_sale_outlined, label: 'Ventas'),
                  _FeatureChip(icon: Icons.inventory_2_outlined, label: 'Inventario'),
                  _FeatureChip(icon: Icons.analytics_outlined, label: 'Reportes'),
                  _FeatureChip(icon: Icons.table_restaurant_outlined, label: 'Mesas'),
                  _FeatureChip(icon: Icons.people_outline_rounded, label: 'Usuarios'),
                  _FeatureChip(icon: Icons.settings_outlined, label: 'Configuración'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(
    AppPalette palette,
    IconData icon,
    String label,
    String value, {
    bool last = false,
  }) {
    final safeValue = value.trim().isEmpty ? 'No registrado' : value.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: palette.textSecondary),
          const SizedBox(width: 9),
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 11.5)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              safeValue,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.8, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(
    AppPalette palette,
    SubscriptionModel subscription,
    SubscriptionPlanModel? plan,
  ) {
    final price = plan?.price ?? subscription.price ?? 0;
    final regularPrice = plan?.regularPrice ?? subscription.regularPrice ?? price;
    final discountPercentage = plan?.discountPercentage ?? subscription.discountPercentage;
    final promotionActive = plan?.promotionActive ?? subscription.promotionActive;
    final promotionText = plan?.promotionText ?? subscription.promotionText;
    final planFeatures = plan?.features ?? subscription.planFeatures;
    final trialDays = plan?.trialDays ?? subscription.trialDays;
    final frequency = plan?.frequency ?? subscription.frequency;
    final frequencyType = plan?.frequencyType ?? subscription.frequencyType;
    final period = _billingPeriod(frequency, frequencyType);
    final recurringPeriod = _billingPeriod(frequency, frequencyType, withPreposition: true);
    final selectedPlanDescription = plan?.description?.trim();
    final subscriptionPlanDescription = subscription.planDescription?.trim();
    final planDescription = (selectedPlanDescription?.isNotEmpty ?? false)
        ? selectedPlanDescription!
        : ((subscriptionPlanDescription?.isNotEmpty ?? false)
            ? subscriptionPlanDescription!
            : null);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.translucentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu plan',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            plan?.name ?? subscription.planName ?? 'BarLytics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (planDescription != null) ...[
            const SizedBox(height: 7),
            Text(
              planDescription,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (promotionActive && regularPrice > price) ...[
            Wrap(
              spacing: 8,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _money(regularPrice),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.lineThrough,
                    decorationThickness: 2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: palette.success.withOpacity(.12), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '-${_discountLabel(discountPercentage)}%',
                    style: TextStyle(color: palette.success, fontWeight: FontWeight.w900, fontSize: 10.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ],
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 6,
            children: [
              Text(
                _money(price),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: palette.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('/ $period', style: TextStyle(color: palette.textSecondary)),
              ),
            ],
          ),
          if (promotionActive && (promotionText?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_offer_outlined, size: 16, color: palette.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    promotionText!.trim(),
                    style: TextStyle(color: palette.primary, fontWeight: FontWeight.w900, fontSize: 11.8),
                  ),
                ),
              ],
            ),
          ],
          if (planFeatures.isNotEmpty) ...[
            const SizedBox(height: 13),
            for (final feature in planFeatures)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 16, color: palette.success),
                    const SizedBox(width: 7),
                    Expanded(child: Text(feature, style: TextStyle(color: palette.textSecondary, fontSize: 11.8, height: 1.35))),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.primary.withOpacity(.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.primary.withOpacity(.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.credit_card_rounded, size: 18, color: palette.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Crédito: suscripción con renovación automática',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  trialDays > 0
                      ? 'Con tarjeta de crédito tienes $trialDays días de prueba. Después se cobrará ${_money(price)} $recurringPeriod hasta que canceles.'
                      : 'Con tarjeta de crédito se cobrará ${_money(price)} $recurringPeriod hasta que canceles.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.2,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: palette.translucentBorder),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.payments_outlined, size: 18, color: palette.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Débito, prepago o PSE: pago único por $period',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Se cobra ${_money(price)} una sola vez y tu plan queda activo por $period. No hay renovación automática; al terminar puedes volver a pagar o cambiar a crédito.',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.2,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 17, color: palette.primary),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Si eliges crédito, puedes cancelar la renovación en cualquier momento para evitar futuros cobros.',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.2,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _changingPlan ? null : _showPlanPicker,
              child: Text(_changingPlan ? 'Cambiando…' : 'Cambiar plan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentPanel(AppPalette palette) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    final currentPlan = _currentPlan();
    final frequency = currentPlan?.frequency ?? _subscription?.frequency ?? 1;
    final frequencyType = currentPlan?.frequencyType ?? _subscription?.frequencyType ?? 'months';
    final period = _billingPeriod(frequency, frequencyType);
    return Container(
      padding: EdgeInsets.fromLTRB(phone ? 10 : 18, 18, phone ? 10 : 18, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.translucentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: phone ? 2 : 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elige cómo pagar',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Mercado Pago oficial: renovación automática o pago único con PSE / débito',
                        style: TextStyle(color: palette.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.lock_outline_rounded, size: 20, color: palette.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.primary.withOpacity(.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.primary.withOpacity(.14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.autorenew_rounded, size: 18, color: palette.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tarjeta de crédito: renovación automática por $period. Débito, prepago o PSE: pago único y puedes adelantar de 1 a 12 meses, sin cobros automáticos posteriores.',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _officialMercadoPagoCheckout(palette),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Actualizar estado'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _officialMercadoPagoCheckout(AppPalette palette) {
    final error = _paymentConfigError;
    final config = _paymentConfig;
    final token = _authToken?.trim() ?? '';

    if (error != null && error.isNotEmpty) return _notice(palette, error, error: true);
    if (config == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!config.enabled || (config.providerPlanId?.trim().isEmpty ?? true)) {
      return _notice(palette, 'Mercado Pago no está configurado o el plan aún no pudo sincronizarse.', error: true);
    }

    final periodOptions = config.prepaidOptions;
    final oneTimeAmount = config.amountForPeriods(_prepaidPeriods);
    final period = _billingPeriod(config.frequency, config.frequencyType);

    Widget option({
      required bool selected,
      required IconData icon,
      required String title,
      required String description,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: _startingCheckout ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? palette.primary.withOpacity(.08) : palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? palette.primary.withOpacity(.55) : palette.textSecondary.withOpacity(.15),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (selected ? palette.primary : palette.info).withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: selected ? palette.primary : palette.info, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    const SizedBox(height: 3),
                    Text(description, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? palette.primary : palette.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.success.withOpacity(.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.success.withOpacity(.18)),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_rounded, color: palette.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plan sincronizado con Mercado Pago · BarLytics #${config.localPlanId}',
                  style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        option(
          selected: _automaticRenewalCheckout,
          icon: Icons.autorenew_rounded,
          title: 'Renovación automática',
          description: config.trialDays > 0
              ? '${config.trialDays} días gratis y luego ${_money(config.amount)} por $period. Los datos de la tarjeta se capturan en el Payment Brick oficial de Mercado Pago.'
              : '${_money(config.amount)} por $period. Los datos de la tarjeta se capturan en el Payment Brick oficial de Mercado Pago.',
          onTap: () => setState(() => _automaticRenewalCheckout = true),
        ),
        const SizedBox(height: 10),
        option(
          selected: !_automaticRenewalCheckout,
          icon: Icons.account_balance_wallet_outlined,
          title: 'Pago único',
          description: 'Paga por adelantado sin renovación automática. Mercado Pago abrirá su checkout oficial y mostrará PSE, débito y demás medios disponibles.',
          onTap: () => setState(() => _automaticRenewalCheckout = false),
        ),
        const SizedBox(height: 14),
        if (_automaticRenewalCheckout) ...[
          if (!config.recurringEnabled || config.publicKey.trim().isEmpty)
            _notice(palette, 'La renovación automática requiere credenciales productivas y Public Key de Mercado Pago.', error: true)
          else if (token.isEmpty)
            _notice(palette, 'Tu sesión expiró. Inicia sesión nuevamente para pagar.', error: true)
          else
            MercadoPagoRecurringBrick(
              key: ValueKey('${config.providerPlanId}-${config.amount}-${config.payerEmail}'),
              publicKey: config.publicKey,
              amount: config.amount,
              payerEmail: config.payerEmail,
              apiBaseUrl: AppConfig.apiBaseUrl,
              authToken: token,
              returnUrl: _frontendReturnUrl,
            ),
        ] else ...[
          DropdownButtonFormField<int>(
            value: _prepaidPeriods,
            decoration: const InputDecoration(
              labelText: 'Periodos a pagar',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: periodOptions
                .map((option) => DropdownMenuItem<int>(
                      value: option.periods,
                      child: Text('${option.periods} ${option.periods == 1 ? 'mes' : 'meses'} · ${_money(option.amount)}'),
                    ))
                .toList(growable: false),
            onChanged: _startingCheckout
                ? null
                : (value) {
                    if (value != null) setState(() => _prepaidPeriods = value);
                  },
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.primary.withOpacity(.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Total a pagar', style: TextStyle(color: palette.textSecondary, fontSize: 12))),
                Text(_money(oneTimeAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _startingCheckout || !config.oneTimeEnabled ? null : _startMercadoPagoCheckout,
            icon: _startingCheckout
                ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.open_in_new_rounded),
            label: Text(_startingCheckout ? 'Abriendo Mercado Pago…' : 'Continuar con Mercado Pago'),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _automaticRenewalCheckout
              ? 'Mercado Pago tokeniza la tarjeta dentro de su componente oficial. BarLytics recibe únicamente el token y lo asocia al plan sincronizado.'
              : 'PSE, débito y credenciales bancarias se procesan completamente en el checkout oficial de Mercado Pago.',
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textSecondary, fontSize: 10.8, height: 1.35),
        ),
      ],
    );
  }

  Widget _activePanel(AppPalette palette, SubscriptionModel subscription) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.success.withOpacity(.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: palette.success, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Suscripción activa',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          if (subscription.nextChargeAt != null) ...[
            const SizedBox(height: 14),
            Text(
              'Próximo cobro: ${_formatDate(subscription.nextChargeAt)}',
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
          if (subscription.scheduledPlanName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Próximo plan: ${subscription.scheduledPlanName} · ${_formatDate(subscription.scheduledPlanEffectiveAt)}',
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Entrar a BarLytics'),
          ),
        ],
      ),
    );
  }

  Widget _notice(AppPalette palette, String message, {bool error = false}) {
    final color = error ? palette.danger : palette.info;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(error ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12, height: 1.4))),
        ],
      ),
    );
  }
}

class _CompactStep extends StatelessWidget {
  const _CompactStep({
    required this.palette,
    required this.number,
    required this.icon,
    required this.completed,
    required this.active,
  });

  final AppPalette palette;
  final int number;
  final IconData icon;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = completed || active ? palette.primary : palette.textSecondary;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: completed ? palette.primary : color.withOpacity(active ? .10 : .04),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(active || completed ? .55 : .22)),
      ),
      alignment: Alignment.center,
      child: completed
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : Icon(icon, size: 15, color: color),
    );
  }
}

class _ProgressSummaryStep extends StatelessWidget {
  const _ProgressSummaryStep({
    required this.palette,
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.active,
  });

  final AppPalette palette;
  final int number;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = completed || active ? palette.primary : palette.textSecondary;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: completed ? palette.primary : color.withOpacity(active ? .10 : .04),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(active || completed ? .55 : .20)),
          ),
          alignment: Alignment.center,
          child: completed
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 10.8)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

