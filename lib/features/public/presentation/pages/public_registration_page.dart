import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/barlytics_brand.dart';
import '../../../../core/auth/google_sign_in_button.dart';
import '../../../auth/data/models/google_auth_models.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../onboarding/data/models/onboarding_models.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../subscription/data/models/subscription_models.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';

class PublicRegistrationPage extends ConsumerStatefulWidget {
  const PublicRegistrationPage({super.key, this.planCode});

  final String? planCode;

  @override
  ConsumerState<PublicRegistrationPage> createState() => _PublicRegistrationPageState();
}

class _PublicRegistrationPageState extends ConsumerState<PublicRegistrationPage> {
  final _gerenteFormKey = GlobalKey<FormState>();
  final _negocioFormKey = GlobalKey<FormState>();
  final _primerNombre = TextEditingController();
  final _segundoNombre = TextEditingController();
  final _primerApellido = TextEditingController();
  final _segundoApellido = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _nombreComercial = TextEditingController();
  final _razonSocial = TextEditingController();
  final _identificacion = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();

  int? _tipoIdentificacionId;
  int? _ciudadId;
  bool _aceptaTerminos = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;
  bool _googleLoading = false;
  String? _googleIdToken;
  GoogleIdentityModel? _googleIdentity;
  int _currentStep = 0;
  String? _selectedPlanCode;
  String? _selectedPlanName;
  bool _recommendedPlan = false;
  bool _planLoading = false;

  AppPalette get _palette => appPalettes.first;

  @override
  void initState() {
    super.initState();
    final requestedPlan = widget.planCode?.trim();
    if (requestedPlan != null && requestedPlan.isNotEmpty) {
      _selectedPlanCode = requestedPlan;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveRegistrationPlan());
  }

  Future<void> _resolveRegistrationPlan() async {
    if (_planLoading) return;
    setState(() => _planLoading = true);
    try {
      final plans = await ref.read(subscriptionRemoteDataSourceProvider).publicPlans();
      if (!mounted) return;

      final requested = widget.planCode?.trim();
      SubscriptionPlanModel? selected;
      if (requested != null && requested.isNotEmpty) {
        for (final plan in plans) {
          if (plan.code.trim().toLowerCase() == requested.toLowerCase()) {
            selected = plan;
            break;
          }
        }
      }

      if (selected == null && (requested == null || requested.isEmpty)) {
        for (final plan in plans) {
          final action = plan.buttonAction.trim().toUpperCase();
          if (plan.recommended &&
              plan.publicVisible &&
              !plan.quoteRequired &&
              action != 'NONE' &&
              action != 'WHATSAPP') {
            selected = plan;
            break;
          }
        }
      }

      if (selected == null && (requested == null || requested.isEmpty)) {
        for (final plan in plans) {
          final action = plan.buttonAction.trim().toUpperCase();
          if (plan.publicVisible &&
              !plan.quoteRequired &&
              action != 'NONE' &&
              action != 'WHATSAPP') {
            selected = plan;
            break;
          }
        }
      }

      setState(() {
        if (selected != null) {
          _selectedPlanCode = selected!.code.trim();
          _selectedPlanName = selected!.name.trim();
          _recommendedPlan = selected!.recommended;
        } else {
          _selectedPlanCode = requested != null && requested.isNotEmpty ? requested : null;
          _selectedPlanName = null;
          _recommendedPlan = false;
        }
      });
    } catch (_) {
      // Si el usuario llegó desde un plan concreto conservamos su código.
      // Para una entrada directa, el backend aplicará sus validaciones si no
      // fue posible consultar temporalmente los planes públicos.
    } finally {
      if (mounted) setState(() => _planLoading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _primerNombre,
      _segundoNombre,
      _primerApellido,
      _segundoApellido,
      _email,
      _password,
      _confirmPassword,
      _nombreComercial,
      _razonSocial,
      _identificacion,
      _direccion,
      _telefono,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleGoogleIdToken(String idToken) async {
    if (_googleLoading) return;
    setState(() {
      _googleLoading = true;
      _googleIdToken = idToken;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      final identity = await repository.googleIdentity(idToken);
      if (!identity.emailVerified) {
        throw StateError('Google no confirmó que el correo esté verificado.');
      }

      if (identity.accountExists) {
        final loggedIn = await ref.read(authControllerProvider.notifier).googleLogin(idToken);
        if (!mounted) return;
        if (!loggedIn) {
          final failure = ref.read(authControllerProvider).failure;
          throw StateError(failure?.message ?? 'No fue posible iniciar sesión con Google.');
        }
        final auth = ref.read(authControllerProvider);
        context.go(auth.subscriptionActive ? '/home' : '/activar-suscripcion');
        return;
      }

      _applyGoogleIdentity(identity);
      if (!mounted) return;
      setState(() {
        _googleIdentity = identity;
        _currentStep = 1;
      });
      _showMessage('Google verificó tu correo. Completa ahora los datos de tu negocio.');
    } catch (error) {
      if (mounted) {
        setState(() {
          _googleIdToken = null;
          _googleIdentity = null;
        });
        _showMessage(error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _applyGoogleIdentity(GoogleIdentityModel identity) {
    final given = (identity.givenName ?? identity.displayName ?? '').trim().split(RegExp(r'\s+'));
    final family = (identity.familyName ?? '').trim().split(RegExp(r'\s+'));
    _primerNombre.text = given.isNotEmpty ? given.first : '';
    _segundoNombre.text = given.length > 1 ? given.skip(1).join(' ') : '';
    _primerApellido.text = family.isNotEmpty && family.first.isNotEmpty ? family.first : '';
    _segundoApellido.text = family.length > 1 ? family.skip(1).join(' ') : '';
    _email.text = identity.email;
    _password.clear();
    _confirmPassword.clear();
  }

  void _clearGoogleIdentity() {
    _primerNombre.clear();
    _segundoNombre.clear();
    _primerApellido.clear();
    _segundoApellido.clear();
    _email.clear();
    setState(() {
      _googleIdToken = null;
      _googleIdentity = null;
      _currentStep = 0;
    });
  }

  void _continueFromGerente() {
    FocusScope.of(context).unfocus();
    if (_googleIdToken != null && _googleIdentity != null) {
      setState(() => _currentStep = 1);
      return;
    }
    if (!(_gerenteFormKey.currentState?.validate() ?? false)) return;
    setState(() => _currentStep = 1);
  }

  void _continueFromNegocio() {
    FocusScope.of(context).unfocus();
    if (!(_negocioFormKey.currentState?.validate() ?? false)) return;
    if (_tipoIdentificacionId == null || _ciudadId == null) {
      _showMessage('Selecciona el tipo de identificación y la ciudad.');
      return;
    }
    setState(() => _currentStep = 2);
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    if (_planLoading) {
      _showMessage('Estamos seleccionando el plan recomendado. Intenta nuevamente en un momento.');
      return;
    }
    if (_selectedPlanCode == null || _selectedPlanCode!.trim().isEmpty) {
      await _resolveRegistrationPlan();
      if (!mounted) return;
      if (_selectedPlanCode == null || _selectedPlanCode!.trim().isEmpty) {
        _showMessage('No fue posible seleccionar el plan recomendado. Intenta nuevamente.');
        return;
      }
    }
    if (!_aceptaTerminos) {
      _showMessage('Debes aceptar los términos y la política de privacidad.');
      return;
    }
    if (_tipoIdentificacionId == null || _ciudadId == null) {
      _showMessage('Selecciona el tipo de identificación y la ciudad.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final onboarding = ref.read(onboardingRemoteDataSourceProvider);
      final businessPayload = <String, dynamic>{
        'nombreComercial': _nombreComercial.text.trim(),
        'razonSocial': _razonSocial.text.trim(),
        'tipoIdentificacionId': _tipoIdentificacionId,
        'identificacion': _identificacion.text.trim(),
        'ciudadId': _ciudadId,
        'direccion': _direccion.text.trim(),
        'telefono': _telefono.text.trim(),
        if (_selectedPlanCode != null && _selectedPlanCode!.trim().isNotEmpty)
          'planCode': _selectedPlanCode!.trim(),
        'aceptaTerminos': true,
      };
      final registration = _googleIdToken != null
          ? await onboarding.registerGoogle(<String, dynamic>{
              'idToken': _googleIdToken,
              ...businessPayload,
            })
          : await onboarding.register(<String, dynamic>{
              'primerNombre': _primerNombre.text.trim(),
              'segundoNombre': _segundoNombre.text.trim(),
              'primerApellido': _primerApellido.text.trim(),
              'segundoApellido': _segundoApellido.text.trim(),
              'email': _email.text.trim(),
              'password': _password.text,
              ...businessPayload,
            });

      await ref.read(authControllerProvider.notifier).completeRegistration(registration.session);
      if (!mounted) return;
      context.go('/activar-suscripcion');
    } catch (error) {
      if (mounted) _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openLegalPage(String path) async {
    final uri = Uri.parse('https://www.barlytics.com.co$path');
    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened && mounted) {
      _showMessage('No fue posible abrir el documento. Visita www.barlytics.com.co$path');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final catalogs = ref.watch(onboardingCatalogsProvider);
    return Theme(
      data: AppTheme.buildFromPalette(palette),
      child: Scaffold(
        backgroundColor: palette.background,
        body: Stack(
          children: [
            Positioned.fill(child: _PremiumRegistrationBackdrop(palette: palette)),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(palette: palette),
                  Expanded(
                    child: catalogs.when(
                      loading: () => _RegistrationLoading(palette: palette),
                      error: (error, _) => _LoadError(
                        message: error.toString(),
                        onRetry: () => ref.invalidate(onboardingCatalogsProvider),
                      ),
                      data: (data) => _buildContent(palette, data),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppPalette palette, PublicOnboardingCatalogsModel catalogs) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 42),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 980;
                  final intro = _IntroPanel(palette: palette, compact: compact);
                  final form = _formPanel(palette, catalogs);
                  if (compact) {
                    return Column(
                      children: [
                        intro,
                        const SizedBox(height: 18),
                        form,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 390, child: intro),
                      const SizedBox(width: 28),
                      Expanded(child: form),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              _buildLegalFooter(palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalFooter(AppPalette palette) {
    final linkStyle = TextButton.styleFrom(
      foregroundColor: palette.primary,
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 3,
      runSpacing: 3,
      children: [
        Text(
          '© BarLytics',
          style: TextStyle(color: palette.textSecondary, fontSize: 12),
        ),
        Text('·', style: TextStyle(color: palette.textSecondary)),
        TextButton(
          onPressed: () => _openLegalPage('/terminos/'),
          style: linkStyle,
          child: const Text('Términos y condiciones'),
        ),
        Text('·', style: TextStyle(color: palette.textSecondary)),
        TextButton(
          onPressed: () => _openLegalPage('/privacidad/'),
          style: linkStyle,
          child: const Text('Política de privacidad'),
        ),
      ],
    );
  }

  Widget _formPanel(AppPalette palette, PublicOnboardingCatalogsModel catalogs) {
    final titles = <String>['Crea tu usuario', 'Configura tu negocio', 'Confirma tus datos'];
    final subtitles = <String>[
      'Este será tu acceso principal como gerente de la cuenta.',
      'Con estos datos crearemos la empresa y la primera sucursal.',
      'Revisa la información antes de continuar a la activación.',
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surface.withOpacity(.96),
            palette.surface.withOpacity(.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.primary.withOpacity(.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.24),
            blurRadius: 38,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: palette.primary.withOpacity(.06),
            blurRadius: 44,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.primary.withOpacity(.10),
                  palette.secondary.withOpacity(.045),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(bottom: BorderSide(color: palette.translucentBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SoftBadge(
                            icon: Icons.rocket_launch_outlined,
                            label: 'PASO ${_currentStep + 1} DE 3',
                            color: palette.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            titles[_currentStep],
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.4,
                                  height: 1.08,
                                ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            subtitles[_currentStep],
                            style: TextStyle(color: palette.textSecondary, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            palette.primary.withOpacity(.22),
                            palette.secondary.withOpacity(.10),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.primary.withOpacity(.24)),
                      ),
                      child: Icon(
                        _currentStep == 0
                            ? Icons.person_outline_rounded
                            : _currentStep == 1
                                ? Icons.storefront_outlined
                                : Icons.fact_check_outlined,
                        color: palette.primary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _WizardProgress(palette: palette, currentStep: _currentStep),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 10),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(.025, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_currentStep),
                child: _buildWizardStep(palette, catalogs),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: palette.translucentBorder.withOpacity(.72))),
            ),
            child: _buildWizardActions(palette),
          ),
        ],
      ),
    );
  }

  Widget _googleRegistrationOption(AppPalette palette) {
    final config = ref.watch(googleAuthConfigProvider);
    return config.when(
      loading: () => const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (google) {
        if (!google.enabled) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BarLyticsGoogleSignInButton(
              webClientId: google.webClientId,
              iosClientId: google.iosClientId,
              desktopClientId: google.desktopClientId,
              desktopClientSecret: google.desktopClientSecret,
              loading: _googleLoading,
              onIdToken: _handleGoogleIdToken,
              onError: (error) => _showMessage(
                error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', ''),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Solo solicitamos tu identidad básica: nombre, correo y foto de perfil. No accedemos a Gmail, Drive ni contactos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 10.5, height: 1.4),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWizardStep(AppPalette palette, PublicOnboardingCatalogsModel catalogs) {
    switch (_currentStep) {
      case 0:
        return Form(
          key: _gerenteFormKey,
          child: _RegistrationSection(
            palette: palette,
            icon: Icons.person_outline_rounded,
            title: 'Datos del gerente',
            subtitle: 'Este será el primer usuario del negocio y tendrá el rol GERENTE.',
            child: Column(
              children: [
                _googleRegistrationOption(palette),
                const SizedBox(height: 20),
                _OrDivider(palette: palette, label: 'o crea tu acceso con correo'),
                const SizedBox(height: 20),
                _responsiveFields([
                  _field(_primerNombre, 'Primer nombre', icon: Icons.badge_outlined, maxLength: 20),
                  _field(_segundoNombre, 'Segundo nombre', isRequired: false, icon: Icons.badge_outlined, maxLength: 20),
                  _field(_primerApellido, 'Primer apellido', icon: Icons.badge_outlined, maxLength: 20),
                  _field(_segundoApellido, 'Segundo apellido', isRequired: false, icon: Icons.badge_outlined, maxLength: 20),
                ]),
                const SizedBox(height: 12),
                _responsiveFields([
                  _field(
                    _email,
                    'Correo',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: _emailValidator,
                    maxLength: 100,
                  ),
                  _passwordField(
                    'Contraseña',
                    _password,
                    obscure: _obscurePassword,
                    onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  _passwordField(
                    'Confirmar contraseña',
                    _confirmPassword,
                    obscure: _obscureConfirmPassword,
                    confirm: true,
                    onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ]),
              ],
            ),
          ),
        );
      case 1:
        return Form(
          key: _negocioFormKey,
          child: _RegistrationSection(
            palette: palette,
            icon: Icons.storefront_outlined,
            title: 'Datos del negocio',
            subtitle: 'BarLytics creará con esta información la empresa y su primera sucursal.',
            child: Column(
              children: [
                if (_googleIdentity != null) ...[
                  _GoogleIdentityCard(
                    palette: palette,
                    identity: _googleIdentity!,
                    onChangeAccount: _clearGoogleIdentity,
                  ),
                  const SizedBox(height: 18),
                ],
                _responsiveFields([
                  _field(_nombreComercial, 'Nombre comercial', icon: Icons.store_mall_directory_outlined, maxLength: 100),
                  _field(_razonSocial, 'Razón social', isRequired: false, icon: Icons.business_outlined, maxLength: 300),
                ]),
                const SizedBox(height: 12),
                _responsiveFields([
                  DropdownButtonFormField<int>(
                    value: _tipoIdentificacionId,
                    isExpanded: true,
                    decoration: _inputDecoration('Tipo de identificación', Icons.assignment_ind_outlined),
                    items: catalogs.identificationTypes
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item.id,
                            child: Text(item.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _tipoIdentificacionId = value),
                    validator: (value) => value == null ? 'Campo obligatorio' : null,
                  ),
                  _field(_identificacion, 'NIT / identificación', icon: Icons.numbers_rounded, maxLength: 20),
                ]),
                const SizedBox(height: 12),
                _responsiveFields([
                  DropdownButtonFormField<int>(
                    value: _ciudadId,
                    isExpanded: true,
                    decoration: _inputDecoration('Ciudad', Icons.location_city_outlined),
                    items: catalogs.cities
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item.id,
                            child: Text(item.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _ciudadId = value),
                    validator: (value) => value == null ? 'Campo obligatorio' : null,
                  ),
                  _field(_direccion, 'Dirección', icon: Icons.location_on_outlined, maxLength: 100),
                  _field(
                    _telefono,
                    'Teléfono',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: 13,
                  ),
                ]),
              ],
            ),
          ),
        );
      default:
        return _confirmationStep(palette, catalogs);
    }
  }

  Widget _confirmationStep(AppPalette palette, PublicOnboardingCatalogsModel catalogs) {
    String identificationType = 'No seleccionado';
    for (final item in catalogs.identificationTypes) {
      if (item.id == _tipoIdentificacionId) {
        identificationType = item.name;
        break;
      }
    }
    String city = 'No seleccionada';
    for (final item in catalogs.cities) {
      if (item.id == _ciudadId) {
        city = item.name;
        break;
      }
    }

    final managerName = [
      _primerNombre.text.trim(),
      _segundoNombre.text.trim(),
      _primerApellido.text.trim(),
      _segundoApellido.text.trim(),
    ].where((value) => value.isNotEmpty).join(' ');

    return Column(
      children: [
        _RegistrationSection(
          palette: palette,
          icon: Icons.fact_check_outlined,
          title: 'Revisa antes de continuar',
          subtitle: 'Podrás volver a los pasos anteriores si necesitas corregir algún dato.',
          child: Column(
            children: [
              _SummaryGroup(
                palette: palette,
                title: 'GERENTE',
                icon: Icons.person_outline_rounded,
                items: [
                  _SummaryItem(label: 'Nombre', value: managerName),
                  _SummaryItem(label: 'Correo', value: _email.text.trim()),
                ],
              ),
              const SizedBox(height: 12),
              _SummaryGroup(
                palette: palette,
                title: 'NEGOCIO',
                icon: Icons.storefront_outlined,
                items: [
                  _SummaryItem(label: 'Nombre comercial', value: _nombreComercial.text.trim()),
                  _SummaryItem(
                    label: 'Identificación',
                    value: '$identificationType · ${_identificacion.text.trim()}',
                  ),
                  _SummaryItem(label: 'Ciudad', value: city),
                  _SummaryItem(label: 'Dirección', value: _direccion.text.trim()),
                  _SummaryItem(label: 'Teléfono', value: _telefono.text.trim()),
                ],
              ),
              if (_selectedPlanCode != null && _selectedPlanCode!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SummaryGroup(
                  palette: palette,
                  title: 'PLAN',
                  icon: Icons.workspace_premium_outlined,
                  items: [
                    _SummaryItem(
                      label: _recommendedPlan ? 'Plan recomendado' : 'Plan seleccionado',
                      value: (_selectedPlanName != null && _selectedPlanName!.isNotEmpty)
                          ? _selectedPlanName!
                          : _selectedPlanCode!,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _aceptaTerminos ? palette.primary.withOpacity(.08) : palette.surface.withOpacity(.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _aceptaTerminos ? palette.primary.withOpacity(.45) : palette.translucentBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _aceptaTerminos,
                onChanged: (value) => setState(() => _aceptaTerminos = value ?? false),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _aceptaTerminos = !_aceptaTerminos),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            'Acepto los Términos y condiciones y la Política de privacidad',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        runSpacing: 0,
                        children: [
                          TextButton(
                            onPressed: () => _openLegalPage('/terminos/'),
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Términos y condiciones'),
                          ),
                          Text('y', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                          TextButton(
                            onPressed: () => _openLegalPage('/privacidad/'),
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Política de privacidad'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'La cuenta se crea sin cobro. Después pasarás a Mercado Pago para activar la suscripción.',
                        style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWizardActions(AppPalette palette) {
    if (_currentStep == 0) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final next = FilledButton.icon(
            onPressed: _continueFromGerente,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Continuar'),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: double.infinity, child: next),
                const SizedBox(height: 9),
                Text(
                  'Tus datos se guardan solo cuando finalizas el registro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textSecondary, fontSize: 10.5, height: 1.35),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Text(
                  'Tus datos se guardan solo cuando finalizas el registro.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.35),
                ),
              ),
              const SizedBox(width: 14),
              next,
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final busy = _submitting || (_currentStep == 2 && _planLoading);
        final back = OutlinedButton.icon(
          onPressed: busy ? null : _goBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Atrás'),
        );
        final canContinue = _currentStep != 2 || _aceptaTerminos;
        final next = FilledButton.icon(
          onPressed: busy || !canContinue
              ? null
              : (_currentStep == 1 ? _continueFromNegocio : _submit),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _currentStep == 1 ? Icons.arrow_forward_rounded : Icons.lock_open_rounded,
                  size: 18,
                ),
          label: Text(
            _submitting
                ? 'Creando cuenta...'
                : (_currentStep == 2 && _planLoading
                    ? 'Seleccionando plan...'
                    : (_currentStep == 1 ? 'Continuar' : 'Crear cuenta y pasar al pago')),
          ),
        );
        final requiresLegalAcceptance = _currentStep == 2 && !_aceptaTerminos;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: double.infinity, child: next),
              if (requiresLegalAcceptance) ...[
                const SizedBox(height: 7),
                Text(
                  'Marca “Acepto los Términos y condiciones y la Política de privacidad” para crear la cuenta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textSecondary, fontSize: 11, height: 1.35),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: back),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            back,
            const Spacer(),
            if (requiresLegalAcceptance) ...[
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 3),
                  child: Text(
                    'Acepta los Términos y condiciones y la Política de privacidad para continuar.',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: palette.textSecondary, fontSize: 11, height: 1.3),
                  ),
                ),
              ),
            ],
            next,
          ],
        );
      },
    );
  }

  Widget _responsiveFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 690) {
          return Column(
            children: children
                .expand((child) => <Widget>[child, const SizedBox(height: 12)])
                .toList()
              ..removeLast(),
          );
        }
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children.map((child) => SizedBox(width: width, child: child)).toList(),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: '$label *',
      prefixIcon: Icon(icon, size: 20),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool isRequired = true,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: keyboardType == TextInputType.phone
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')),
              if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
            ]
          : null,
      decoration: InputDecoration(
        labelText: '$label${isRequired ? ' *' : ''}',
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        counterText: maxLength == null ? null : '',
      ),
      validator: validator ??
          (isRequired
              ? (value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null
              : null),
    );
  }

  Widget _passwordField(
    String label,
    TextEditingController controller, {
    required bool obscure,
    required VoidCallback onToggle,
    bool confirm = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      maxLength: 72,
      decoration: InputDecoration(
        labelText: '$label *',
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
        counterText: '',
        suffixIcon: IconButton(
          tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
          onPressed: onToggle,
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        ),
      ),
      validator: (value) {
        if (value == null || value.length < 8) return 'Mínimo 8 caracteres';
        if (value.length > 72) return 'Máximo 72 caracteres';
        if (confirm && value != _password.text) return 'Las contraseñas no coinciden';
        return null;
      },
    );
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Campo obligatorio';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Correo inválido';
    return null;
  }
}

class _PremiumRegistrationBackdrop extends StatelessWidget {
  const _PremiumRegistrationBackdrop({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette.background,
                Color.lerp(palette.background, palette.primary, .13)!,
                Color.lerp(palette.background, palette.secondary, .07)!,
                palette.background,
              ],
              stops: const [0, .34, .70, 1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -180,
          left: -120,
          child: _GlowOrb(
            size: 430,
            color: palette.primary,
            opacity: .14,
          ),
        ),
        Positioned(
          top: 110,
          right: -170,
          child: _GlowOrb(
            size: 440,
            color: palette.secondary,
            opacity: .10,
          ),
        ),
        Positioned(
          bottom: -220,
          left: 260,
          child: _GlowOrb(
            size: 520,
            color: palette.accent,
            opacity: .055,
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _RegistrationGridPainter(
              lineColor: palette.textPrimary.withOpacity(.018),
              dotColor: palette.primary.withOpacity(.035),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color, required this.opacity});

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
          stops: const [.0, 1],
        ),
      ),
    );
  }
}

class _RegistrationGridPainter extends CustomPainter {
  const _RegistrationGridPainter({required this.lineColor, required this.dotColor});

  final Color lineColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 42.0;
    final linePaint = Paint()..color = lineColor..strokeWidth = .7;
    final dotPaint = Paint()..color = dotColor;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    for (double x = gap; x < size.width; x += gap * 2) {
      for (double y = gap; y < size.height; y += gap * 2) {
        canvas.drawCircle(Offset(x, y), 1.15, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RegistrationGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.dotColor != dotColor;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: palette.surface.withOpacity(.74),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.translucentBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.12),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                return Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BarLyticsBrandLockup(
                          width: compact ? 154 : 190,
                          height: compact ? 44 : 55,
                          darkBackground: palette.darkBackground,
                          showTagline: false,
                          alignment: Alignment.centerLeft,
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Tecnología para operar mejor tu negocio',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    if (!compact)
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: palette.success.withOpacity(.08),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: palette.success.withOpacity(.14)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 14, color: palette.success),
                            const SizedBox(width: 5),
                            Text(
                              'Registro seguro',
                              style: TextStyle(
                                color: palette.success,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.login_rounded, size: 17),
                      label: Text(compact ? 'Entrar' : 'Ya tengo cuenta'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({required this.palette, required this.compact});
  final AppPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 22 : 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surface.withOpacity(.74),
            palette.surface.withOpacity(.52),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.translucentBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette.primary, palette.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(19),
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withOpacity(.23),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Icon(Icons.auto_graph_rounded, color: palette.onPrimary, size: 28),
          ),
          const SizedBox(height: 22),
          _SoftBadge(
            icon: Icons.auto_awesome_rounded,
            label: 'EMPIEZA EN MINUTOS',
            color: palette.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'Pon tu negocio\nen modo BarLytics',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.03,
                  letterSpacing: -.7,
                ),
          ),
          const SizedBox(height: 13),
          Text(
            'Un registro guiado, claro y sin configuraciones técnicas. Crea tu gerente, configura el negocio y activa tu suscripción.',
            style: TextStyle(color: palette.textSecondary, height: 1.55, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _OnboardingMiniStep(
            palette: palette,
            icon: Icons.person_add_alt_1_outlined,
            title: 'Crea tu acceso',
            detail: 'Tu primer usuario nace como GERENTE.',
            active: true,
          ),
          _OnboardingMiniStep(
            palette: palette,
            icon: Icons.storefront_outlined,
            title: 'Registra tu negocio',
            detail: 'Creamos empresa y primera sucursal.',
          ),
          _OnboardingMiniStep(
            palette: palette,
            icon: Icons.lock_open_rounded,
            title: 'Activa y empieza',
            detail: 'Paga con Mercado Pago y se habilita todo.',
            last: true,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.primary.withOpacity(.055),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.primary.withOpacity(.10)),
            ),
            child: Row(
              children: [
                _MiniStat(
                  palette: palette,
                  icon: Icons.point_of_sale_rounded,
                  label: 'Ventas',
                ),
                _MiniDivider(palette: palette),
                _MiniStat(
                  palette: palette,
                  icon: Icons.inventory_2_outlined,
                  label: 'Stock',
                ),
                _MiniDivider(palette: palette),
                _MiniStat(
                  palette: palette,
                  icon: Icons.analytics_outlined,
                  label: 'Datos',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: palette.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El pago se realiza de forma segura con Mercado Pago. BarLytics no almacena información bancaria.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnboardingMiniStep extends StatelessWidget {
  const _OnboardingMiniStep({
    required this.palette,
    required this.icon,
    required this.title,
    required this.detail,
    this.active = false,
    this.last = false,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String detail;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active ? palette.primary.withOpacity(.15) : palette.surface.withOpacity(.55),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? palette.primary.withOpacity(.35) : palette.translucentBorder,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: active ? palette.primary : palette.textSecondary,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.4,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: palette.translucentBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                  const SizedBox(height: 3),
                  Text(detail, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.35)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.palette, required this.icon, required this.label});
  final AppPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: palette.primary, size: 18),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MiniDivider extends StatelessWidget {
  const _MiniDivider({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: palette.translucentBorder);
  }
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.palette, required this.currentStep});

  final AppPalette palette;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['Tu usuario', 'Tu negocio', 'Confirmar'];
    const icons = <IconData>[
      Icons.person_outline_rounded,
      Icons.storefront_outlined,
      Icons.fact_check_outlined,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return Row(
          children: List.generate(labels.length, (index) {
            final done = index < currentStep;
            final active = index == currentStep;
            final statusColor = done ? palette.success : palette.primary;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? palette.primary.withOpacity(.09)
                            : done
                                ? palette.success.withOpacity(.055)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: active
                              ? palette.primary.withOpacity(.18)
                              : done
                                  ? palette.success.withOpacity(.12)
                                  : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 29,
                            height: 29,
                            decoration: BoxDecoration(
                              color: done
                                  ? palette.success.withOpacity(.13)
                                  : active
                                      ? palette.primary.withOpacity(.14)
                                      : palette.surface.withOpacity(.55),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: done || active
                                    ? statusColor.withOpacity(.32)
                                    : palette.translucentBorder,
                              ),
                            ),
                            child: Icon(
                              done ? Icons.check_rounded : icons[index],
                              size: 15,
                              color: done || active ? statusColor : palette.textSecondary.withOpacity(.70),
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                labels[index],
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: done
                                      ? palette.success
                                      : active
                                          ? palette.textPrimary
                                          : palette.textSecondary.withOpacity(.72),
                                  fontWeight: active || done ? FontWeight.w900 : FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (index < labels.length - 1)
                    Container(
                      width: compact ? 8 : 14,
                      height: 1.4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: index < currentStep
                          ? palette.success.withOpacity(.42)
                          : palette.translucentBorder,
                    ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class _SummaryItem {
  const _SummaryItem({required this.label, required this.value});
  final String label;
  final String value;
}

class _SummaryGroup extends StatelessWidget {
  const _SummaryGroup({
    required this.palette,
    required this.title,
    required this.icon,
    required this.items,
  });

  final AppPalette palette;
  final String title;
  final IconData icon;
  final List<_SummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surface.withOpacity(.70),
            palette.primary.withOpacity(.035),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.primary.withOpacity(.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: palette.primary),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(color: palette.primary, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.where((item) => item.value.trim().isNotEmpty).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 118,
                        child: Text(
                          item.label,
                          style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.value,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
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

class _RegistrationSection extends StatelessWidget {
  const _RegistrationSection({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.primary.withOpacity(.16),
                    palette.secondary.withOpacity(.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.primary.withOpacity(.16)),
              ),
              child: Icon(icon, color: palette.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.background.withOpacity(.24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.translucentBorder.withOpacity(.78)),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.palette,
    required this.number,
    required this.title,
    required this.detail,
    this.active = false,
    this.last = false,
  });

  final AppPalette palette;
  final String number;
  final String title;
  final String detail;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? palette.primary : palette.primary.withOpacity(.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.primary.withOpacity(active ? 1 : .25)),
                  ),
                  child: Text(
                    number,
                    style: TextStyle(
                      color: active ? palette.onPrimary : palette.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: palette.primary.withOpacity(.18),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(detail, style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.35)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.palette, required this.icon, required this.label});
  final AppPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.primary.withOpacity(.07),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: palette.primary.withOpacity(.13)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
        ],
      ),
    );
  }
}

class _RegistrationLoading extends StatelessWidget {
  const _RegistrationLoading({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: palette.panelDecoration(baseRadius: 20, tint: palette.primary, elevated: true),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2)),
            const SizedBox(width: 12),
            const Text('Preparando el registro...', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42),
              const SizedBox(height: 12),
              const Text(
                'No fue posible cargar los datos de registro.',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.palette, required this.label});
  final AppPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: palette.translucentBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        Expanded(child: Divider(color: palette.translucentBorder)),
      ],
    );
  }
}

class _GoogleIdentityCard extends StatelessWidget {
  const _GoogleIdentityCard({
    required this.palette,
    required this.identity,
    required this.onChangeAccount,
  });

  final AppPalette palette;
  final GoogleIdentityModel identity;
  final VoidCallback onChangeAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.success.withOpacity(.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.success.withOpacity(.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white,
            backgroundImage: identity.pictureUrl == null || identity.pictureUrl!.isEmpty
                ? null
                : NetworkImage(identity.pictureUrl!),
            child: identity.pictureUrl == null || identity.pictureUrl!.isEmpty
                ? const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        identity.displayName ?? identity.email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.verified_rounded, color: palette.success, size: 17),
                  ],
                ),
                const SizedBox(height: 2),
                Text(identity.email, style: TextStyle(color: palette.textSecondary, fontSize: 11.5)),
              ],
            ),
          ),
          TextButton(onPressed: onChangeAccount, child: const Text('Cambiar')),
        ],
      ),
    );
  }
}
