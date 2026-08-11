import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/subscription_models.dart';
import '../providers/subscription_provider.dart';

class SubscriptionActivationPage extends ConsumerStatefulWidget {
  const SubscriptionActivationPage({super.key});

  @override
  ConsumerState<SubscriptionActivationPage> createState() => _SubscriptionActivationPageState();
}

class _SubscriptionActivationPageState extends ConsumerState<SubscriptionActivationPage> {
  SubscriptionModel? _subscription;
  List<SubscriptionPlanModel> _plans = const <SubscriptionPlanModel>[];
  bool _loading = true;
  bool _paying = false;
  bool _changingPlan = false;
  String _paymentMethod = 'CARD_RECURRING';
  String? _message;

  AppPalette get _palette => appPalettes.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAndSyncReturn());
  }

  Future<void> _loadAndSyncReturn() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final params = _returnParameters();
      final paymentId = params['payment_id'] ?? params['paymentId'];
      final preapprovalId = params['preapproval_id'] ?? params['preapprovalId'];
      final remote = ref.read(subscriptionRemoteDataSourceProvider);
      final returnedFromPayment = (paymentId != null && paymentId.isNotEmpty) ||
          (preapprovalId != null && preapprovalId.isNotEmpty);
      final subscriptionFuture = returnedFromPayment
          ? remote.sync(paymentId: paymentId, preapprovalId: preapprovalId)
          : remote.current();
      final results = await Future.wait<Object>([
        subscriptionFuture,
        remote.plans(),
      ]);
      final subscription = results[0] as SubscriptionModel;
      final plans = results[1] as List<SubscriptionPlanModel>;
      if (mounted) setState(() => _plans = plans);
      await _applySubscription(subscription, navigateIfActivated: returnedFromPayment);
    } catch (error) {
      if (mounted) setState(() => _message = _cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, String> _returnParameters() {
    final result = <String, String>{...Uri.base.queryParameters};
    final fragment = Uri.base.fragment;
    final fragmentUri = Uri.tryParse(fragment.startsWith('/') ? fragment : '/$fragment');
    if (fragmentUri != null) result.addAll(fragmentUri.queryParameters);
    return result;
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
      await _applySubscription(subscription);
      if (!mounted) return;
      final effective = subscription.scheduledPlanEffectiveAt;
      setState(() {
        _message = subscription.scheduledPlanCode == null
            ? 'Plan ${subscription.planName ?? plan.name} seleccionado correctamente.'
            : 'El cambio a ${subscription.scheduledPlanName ?? plan.name} quedó programado para ${_formatDate(effective)}.';
      });
    } catch (error) {
      if (mounted) setState(() => _message = _cleanError(error));
    } finally {
      if (mounted) setState(() => _changingPlan = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'el próximo ciclo';
    return DateFormat('dd/MM/yyyy', 'es_CO').format(date.toLocal());
  }

  Future<void> _startPayment() async {
    setState(() {
      _paying = true;
      _message = null;
    });
    try {
      final checkout = await ref.read(subscriptionRemoteDataSourceProvider).checkout(_paymentMethod);
      final uri = Uri.tryParse(checkout.checkoutUrl);
      if (uri == null || checkout.checkoutUrl.isEmpty) {
        throw StateError('Mercado Pago no devolvió una URL válida.');
      }
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
      if (!opened) throw StateError('No fue posible abrir Mercado Pago.');
      if (mounted) {
        setState(() => _message = 'Completa el pago en Mercado Pago y luego presiona “Verificar pago”.');
      }
    } catch (error) {
      if (mounted) setState(() => _message = _cleanError(error));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Theme(
      data: AppTheme.buildFromPalette(palette),
      child: Scaffold(
        backgroundColor: palette.background,
        body: Stack(
          children: [
            Positioned.fill(child: _PremiumActivationBackdrop(palette: palette)),
            SafeArea(
              child: Column(
                children: [
                  _header(palette),
                  Expanded(
                    child: _loading
                        ? _ActivationLoading(palette: palette)
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 42),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1160),
                                child: _body(palette),
                              ),
                            ),
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

  Widget _header(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [palette.primary, palette.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withOpacity(.22),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(Icons.local_bar_rounded, color: palette.onPrimary, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BarLytics',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -.25,
                          ),
                        ),
                        if (!compact)
                          Text(
                            'Último paso para activar tu negocio',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (!compact)
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: palette.info.withOpacity(.08),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: palette.info.withOpacity(.14)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, color: palette.info),
                            const SizedBox(width: 5),
                            Text(
                              'Pago seguro',
                              style: TextStyle(
                                color: palette.info,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () async => ref.read(authControllerProvider.notifier).logout(),
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: Text(compact ? 'Salir' : 'Cerrar sesión'),
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

  Widget _body(AppPalette palette) {
    final subscription = _subscription;
    final price = subscription?.price ?? 70000;
    final currency = subscription?.currency ?? 'COP';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(.68),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: palette.translucentBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.primary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.primary.withOpacity(.18)),
                    ),
                    child: Icon(Icons.verified_user_outlined, color: palette.primary, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription?.active == true ? 'Tu suscripción está activa' : 'Tu cuenta ya está creada',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subscription?.active == true
                              ? 'Puedes consultar o cambiar tu plan cuando lo necesites.'
                              : 'Activa la suscripción para desbloquear BarLytics.',
                          style: TextStyle(color: palette.textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ActivationProgress(palette: palette),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_plans.isNotEmpty) ...[
          _planSelector(palette),
          const SizedBox(height: 20),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;
            final status = _statusPanel(palette, subscription);
            final payment = subscription != null && subscription.active
                ? _activeSubscriptionPanel(palette, subscription)
                : _paymentPanel(palette, price, currency);
            if (compact) {
              return Column(
                children: [
                  payment,
                  const SizedBox(height: 18),
                  status,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: status),
                const SizedBox(width: 22),
                Expanded(flex: 6, child: payment),
              ],
            );
          },
        ),
      ],
    );
  }

  SubscriptionPlanModel? _currentPlan() {
    for (final plan in _plans) {
      if (plan.current) return plan;
    }
    final code = _subscription?.planCode;
    if (code != null) {
      for (final plan in _plans) {
        if (plan.code == code) return plan;
      }
    }
    return _plans.isEmpty ? null : _plans.first;
  }

  SubscriptionPlanModel? _scheduledPlan() {
    for (final plan in _plans) {
      if (plan.scheduled) return plan;
    }
    final code = _subscription?.scheduledPlanCode;
    if (code != null) {
      for (final plan in _plans) {
        if (plan.code == code) return plan;
      }
    }
    return null;
  }

  Widget _planSelector(AppPalette palette) {
    final subscription = _subscription;
    final currentPlan = _currentPlan();
    final scheduledPlan = _scheduledPlan();
    final formatter = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);

    if (currentPlan == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(.78),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.translucentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.primary.withOpacity(.11),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: palette.primary.withOpacity(.18)),
                ),
                child: Icon(Icons.workspace_premium_outlined, color: palette.primary, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription?.active == true ? 'Tu plan actual' : 'Plan seleccionado',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subscription?.active == true
                          ? 'Puedes revisar tu plan y escoger otro cuando lo necesites.'
                          : 'Este es el plan que se usará al continuar con el pago.',
                      style: TextStyle(color: palette.textSecondary, height: 1.45),
                    ),
                  ],
                ),
              ),
              if (_changingPlan)
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 4),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(.28),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.primary.withOpacity(.24)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              currentPlan.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(
                            palette: palette,
                            label: subscription?.active == true ? 'ACTUAL' : 'SELECCIONADO',
                            color: subscription?.active == true ? palette.success : palette.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${formatter.format(currentPlan.price)} ${currentPlan.currency} / mes',
                        style: TextStyle(color: palette.primary, fontWeight: FontWeight.w900, fontSize: 20),
                      ),
                      if (currentPlan.description != null && currentPlan.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          currentPlan.description!,
                          style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.tonalIcon(
                  onPressed: _changingPlan ? null : () => _openPlanPicker(palette),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 19),
                  label: Text(subscription?.active == true ? 'Escoger otro plan' : 'Ver otros planes'),
                ),
              ],
            ),
          ),
          if (scheduledPlan != null || subscription?.scheduledPlanCode != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.info.withOpacity(.08),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: palette.info.withOpacity(.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.schedule_rounded, color: palette.info, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Próximo plan: ${scheduledPlan?.name ?? subscription?.scheduledPlanName ?? subscription?.scheduledPlanCode} '
                      'desde ${_formatDate(scheduledPlan?.effectiveAt ?? subscription?.scheduledPlanEffectiveAt)}. '
                      'Si cambias de opinión, usa “Escoger otro plan” y selecciona nuevamente tu plan actual.',
                      style: TextStyle(color: palette.textPrimary, fontSize: 12, height: 1.45),
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

  Future<void> _openPlanPicker(AppPalette palette) async {
    final subscription = _subscription;
    final currentPlan = _currentPlan();
    SubscriptionPlanModel? selectedPlan = _scheduledPlan() ?? currentPlan;
    final formatter = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);

    final chosen = await showModalBottomSheet<SubscriptionPlanModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedIsCurrent = selectedPlan?.code == currentPlan?.code;
            final hasScheduledChange = subscription?.scheduledPlanCode != null;
            final canConfirm = selectedPlan != null && (!selectedIsCurrent || hasScheduledChange);

            return FractionallySizedBox(
              heightFactor: .90,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border.all(color: palette.translucentBorder),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: palette.textSecondary.withOpacity(.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Escoger otro plan',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              subscription?.active == true
                                  ? 'Compara los planes. Nada cambiará hasta que confirmes tu selección.'
                                  : 'Elige el plan que quieres usar antes de continuar con el pago.',
                              style: TextStyle(color: palette.textSecondary, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = constraints.maxWidth < 760
                              ? constraints.maxWidth - 40
                              : (constraints.maxWidth - 54) / 2;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: _plans.map((plan) {
                                final selected = selectedPlan?.code == plan.code;
                                final isCurrent = plan.code == currentPlan?.code;
                                final isScheduled = plan.scheduled || plan.code == subscription?.scheduledPlanCode;
                                return SizedBox(
                                  width: cardWidth,
                                  child: InkWell(
                                    onTap: () => setSheetState(() => selectedPlan = plan),
                                    borderRadius: BorderRadius.circular(22),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.all(19),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? palette.primary.withOpacity(.10)
                                            : palette.background.withOpacity(.24),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: selected ? palette.primary.withOpacity(.65) : palette.translucentBorder,
                                          width: selected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  plan.name,
                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                                                ),
                                              ),
                                              if (isCurrent)
                                                _StatusBadge(palette: palette, label: 'ACTUAL', color: palette.success),
                                              if (isScheduled) ...[
                                                const SizedBox(width: 6),
                                                _StatusBadge(palette: palette, label: 'PRÓXIMO', color: palette.primary),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 9),
                                          Text(
                                            '${formatter.format(plan.price)} ${plan.currency} / mes',
                                            style: TextStyle(
                                              color: palette.primary,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 20,
                                            ),
                                          ),
                                          if (plan.description != null && plan.description!.trim().isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              plan.description!,
                                              style: TextStyle(color: palette.textSecondary, height: 1.4, fontSize: 12),
                                            ),
                                          ],
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              Icon(
                                                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                                color: selected ? palette.primary : palette.textSecondary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                selected ? 'Seleccionado' : 'Seleccionar',
                                                style: TextStyle(
                                                  color: selected ? palette.primary : palette.textSecondary,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        border: Border(top: BorderSide(color: palette.translucentBorder)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: canConfirm
                                  ? () => Navigator.of(sheetContext).pop(selectedPlan)
                                  : null,
                              icon: const Icon(Icons.check_rounded),
                              label: Text(
                                selectedIsCurrent && hasScheduledChange
                                    ? 'Mantener plan actual'
                                    : subscription?.active == true
                                        ? 'Programar cambio'
                                        : 'Elegir este plan',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (chosen != null && mounted) {
      await _changePlan(chosen);
    }
  }

  Widget _activeSubscriptionPanel(AppPalette palette, SubscriptionModel subscription) {
    final formatter = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.surface.withOpacity(.96), palette.surface.withOpacity(.86)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.success.withOpacity(.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: palette.success.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.check_circle_outline_rounded, color: palette.success),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Suscripción activa', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    Text(subscription.planName ?? 'BarLytics', style: TextStyle(color: palette.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _StatusRow(
            palette: palette,
            icon: Icons.payments_outlined,
            title: 'Valor actual',
            value: '${formatter.format(subscription.price ?? 0)} ${subscription.currency}',
            valueColor: palette.primary,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            palette: palette,
            icon: Icons.event_repeat_rounded,
            title: 'Próximo ciclo',
            value: _formatDate(subscription.currentPeriodEnd ?? subscription.nextChargeAt),
            valueColor: palette.textPrimary,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            palette: palette,
            icon: Icons.autorenew_rounded,
            title: 'Renovación',
            value: subscription.automaticRenewal ? 'Automática' : 'Manual',
            valueColor: subscription.automaticRenewal ? palette.success : palette.warning,
          ),
          if (subscription.scheduledPlanCode != null) ...[
            const SizedBox(height: 18),
            Text(
              'Tu plan actual continúa hasta finalizar el periodo pagado. El nuevo plan se aplicará en la fecha indicada arriba.',
              style: TextStyle(color: palette.textSecondary, height: 1.45, fontSize: 12),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Volver a BarLytics'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPanel(AppPalette palette, SubscriptionModel? subscription) {
    final active = subscription?.active == true;
    final statusColor = active ? palette.success : palette.warning;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surface.withOpacity(.82),
            palette.surface.withOpacity(.66),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.translucentBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.14),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: statusColor.withOpacity(.18)),
                ),
                child: Icon(active ? Icons.verified_outlined : Icons.lock_clock_outlined, color: statusColor, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado de tu cuenta',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    _StatusBadge(
                      palette: palette,
                      label: _statusLabel(subscription?.status),
                      color: statusColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            active
                ? 'Tu cuenta está habilitada. Desde aquí puedes revisar el plan actual y programar un cambio para el siguiente ciclo.'
                : 'El usuario GERENTE ya está creado. Al aprobarse el pago, el acceso operativo se habilita automáticamente.',
            style: TextStyle(color: palette.textSecondary, height: 1.5, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.background.withOpacity(.24),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.translucentBorder.withOpacity(.78)),
            ),
            child: Column(
              children: [
                _StatusRow(
                  palette: palette,
                  icon: Icons.person_outline_rounded,
                  title: 'Usuario',
                  value: 'Creado',
                  valueColor: palette.success,
                ),
                const SizedBox(height: 11),
                _StatusRow(
                  palette: palette,
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Rol inicial',
                  value: 'GERENTE',
                  valueColor: palette.primary,
                ),
                const SizedBox(height: 11),
                _StatusRow(
                  palette: palette,
                  icon: Icons.credit_card_off_outlined,
                  title: 'Suscripción',
                  value: _statusLabel(subscription?.status),
                  valueColor: statusColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            active ? 'Incluido en tu acceso' : 'Se desbloquea con tu suscripción',
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LockedModule(palette: palette, icon: Icons.point_of_sale_outlined, label: 'Ventas'),
              _LockedModule(palette: palette, icon: Icons.inventory_2_outlined, label: 'Inventario'),
              _LockedModule(palette: palette, icon: Icons.analytics_outlined, label: 'Reportes'),
              _LockedModule(palette: palette, icon: Icons.table_restaurant_outlined, label: 'Mesas'),
              _LockedModule(palette: palette, icon: Icons.people_outline_rounded, label: 'Usuarios'),
              _LockedModule(palette: palette, icon: Icons.settings_outlined, label: 'Configuración'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: palette.info, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  active
                      ? 'Los cambios de plan quedan registrados en la suscripción de tu empresa.'
                      : 'El bloqueo también se valida en el backend, por lo que no puede omitirse manipulando la app.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentPanel(AppPalette palette, double price, String currency) {
    final formatter = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
    final formattedPrice = formatter.format(price);

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surface.withOpacity(.96),
            palette.surface.withOpacity(.86),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.primary.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.24),
            blurRadius: 38,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: palette.primary.withOpacity(.055),
            blurRadius: 42,
            spreadRadius: 2,
          ),
        ],
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
                    Text(
                      'Activa tu BarLytics',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Un último paso y tendrás acceso completo a tu negocio.',
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              _StatusBadge(palette: palette, label: 'BARLYTICS PRO', color: palette.primary),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.primary.withOpacity(.13),
                  palette.secondary.withOpacity(.07),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.primary.withOpacity(.20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan mensual', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '$formattedPrice $currency',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text('por mes', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Icon(Icons.workspace_premium_outlined, size: 38, color: palette.primary),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '¿Cómo quieres pagar?',
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 10),
          _PaymentOption(
            palette: palette,
            selected: _paymentMethod == 'CARD_RECURRING',
            icon: Icons.credit_card_rounded,
            title: 'Tarjeta crédito o débito',
            subtitle: 'Renovación automática mensual. No tendrás que pagar manualmente cada mes.',
            badge: 'RECOMENDADO',
            onTap: () => setState(() => _paymentMethod = 'CARD_RECURRING'),
          ),
          const SizedBox(height: 10),
          _PaymentOption(
            palette: palette,
            selected: _paymentMethod == 'PSE',
            icon: Icons.account_balance_rounded,
            title: 'PSE',
            subtitle: 'Paga desde tu banco. Nequi y Daviplata pueden aparecer dentro del flujo PSE.',
            badge: 'PAGO MANUAL',
            onTap: () => setState(() => _paymentMethod = 'PSE'),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.surface.withOpacity(.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.translucentBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.info.withOpacity(.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.verified_user_outlined, color: palette.info, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pago seguro', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        'El pago es procesado por Mercado Pago. BarLytics no almacena los datos de tu tarjeta.',
                        style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: palette.info.withOpacity(.08),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: palette.info.withOpacity(.16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: palette.info, size: 19),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _message!,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _paying ? null : _startPayment,
              icon: _paying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.lock_open_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(_paying ? 'Abriendo Mercado Pago...' : 'Continuar con Mercado Pago'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _loadAndSyncReturn,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Ya pagué · verificar estado'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'El acceso se habilita automáticamente cuando Mercado Pago confirme la aprobación.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'ACTIVE':
      case 'LEGACY_ACTIVE':
        return 'Activa';
      case 'PAST_DUE':
        return 'Pago pendiente';
      case 'SUSPENDED':
        return 'Suspendida';
      case 'CANCELED':
        return 'Cancelada';
      default:
        return 'Pendiente de pago';
    }
  }
}

class _PremiumActivationBackdrop extends StatelessWidget {
  const _PremiumActivationBackdrop({required this.palette});
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
                Color.lerp(palette.background, palette.primary, .12)!,
                Color.lerp(palette.background, palette.secondary, .065)!,
                palette.background,
              ],
              stops: const [0, .34, .70, 1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -190,
          left: -130,
          child: _ActivationGlow(size: 450, color: palette.primary, opacity: .13),
        ),
        Positioned(
          top: 140,
          right: -180,
          child: _ActivationGlow(size: 470, color: palette.secondary, opacity: .09),
        ),
        Positioned(
          bottom: -230,
          left: 300,
          child: _ActivationGlow(size: 540, color: palette.accent, opacity: .05),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _ActivationGridPainter(
              lineColor: palette.textPrimary.withOpacity(.017),
              dotColor: palette.primary.withOpacity(.03),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivationGlow extends StatelessWidget {
  const _ActivationGlow({required this.size, required this.color, required this.opacity});
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
        ),
      ),
    );
  }
}

class _ActivationGridPainter extends CustomPainter {
  const _ActivationGridPainter({required this.lineColor, required this.dotColor});
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
        canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActivationGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.dotColor != dotColor;
}

class _ActivationProgress extends StatelessWidget {
  const _ActivationProgress({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: palette.panelDecoration(baseRadius: 22, tint: palette.primary, elevated: false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          if (compact) {
            return Row(
              children: [
                _StepCircle(palette: palette, number: '1', completed: true),
                _Connector(palette: palette),
                _StepCircle(palette: palette, number: '2', active: true),
                _Connector(palette: palette),
                _StepCircle(palette: palette, number: '3'),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paso 2 de 3 · Activa tu suscripción',
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: _ProgressItem(
                  palette: palette,
                  number: '1',
                  title: 'Cuenta creada',
                  subtitle: 'Empresa y gerente listos',
                  completed: true,
                ),
              ),
              _Connector(palette: palette, wide: true),
              Expanded(
                child: _ProgressItem(
                  palette: palette,
                  number: '2',
                  title: 'Activar suscripción',
                  subtitle: 'Selecciona tu medio de pago',
                  active: true,
                ),
              ),
              _Connector(palette: palette, wide: true),
              Expanded(
                child: _ProgressItem(
                  palette: palette,
                  number: '3',
                  title: 'Acceso completo',
                  subtitle: 'Módulos habilitados',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({
    required this.palette,
    required this.number,
    required this.title,
    required this.subtitle,
    this.completed = false,
    this.active = false,
  });

  final AppPalette palette;
  final String number;
  final String title;
  final String subtitle;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepCircle(palette: palette, number: number, completed: completed, active: active),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 10.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.palette,
    required this.number,
    this.completed = false,
    this.active = false,
  });

  final AppPalette palette;
  final String number;
  final bool completed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final highlighted = completed || active;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlighted ? palette.primary : palette.primary.withOpacity(.07),
        shape: BoxShape.circle,
        border: Border.all(color: palette.primary.withOpacity(highlighted ? 1 : .22)),
      ),
      child: completed
          ? Icon(Icons.check_rounded, size: 17, color: palette.onPrimary)
          : Text(
              number,
              style: TextStyle(
                color: highlighted ? palette.onPrimary : palette.primary,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.palette, this.wide = false});
  final AppPalette palette;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 34 : 18,
      height: 1.5,
      margin: EdgeInsets.symmetric(horizontal: wide ? 10 : 5),
      color: palette.primary.withOpacity(.22),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.palette,
    required this.icon,
    required this.title,
    required this.value,
    required this.valueColor,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: palette.textSecondary),
        const SizedBox(width: 9),
        Expanded(child: Text(title, style: TextStyle(color: palette.textSecondary, fontSize: 12))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(.09),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w900, fontSize: 10.5)),
        ),
      ],
    );
  }
}

class _LockedModule extends StatelessWidget {
  const _LockedModule({required this.palette, required this.icon, required this.label});
  final AppPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(.40),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.translucentBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: palette.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Icon(Icons.lock_rounded, size: 12, color: palette.warning),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.palette,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? palette.primary.withOpacity(.10) : palette.surface.withOpacity(.48),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: selected ? palette.primary.withOpacity(.70) : palette.translucentBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? palette.primary.withOpacity(.13) : palette.surface.withOpacity(.65),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 22, color: selected ? palette.primary : palette.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
                      if (selected) Icon(Icons.check_circle_rounded, color: palette.primary, size: 19),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.4)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? palette.primary.withOpacity(.10) : palette.secondary.withOpacity(.08),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: selected ? palette.primary : palette.secondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 9.5,
                      ),
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
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.palette, required this.label, required this.color});
  final AppPalette palette;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 9.5, letterSpacing: .2),
      ),
    );
  }
}

class _ActivationLoading extends StatelessWidget {
  const _ActivationLoading({required this.palette});
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
            const Text('Verificando tu suscripción...', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
