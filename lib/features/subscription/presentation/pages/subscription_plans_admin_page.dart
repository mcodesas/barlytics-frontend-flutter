import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../widgets/apple_subscription_admin_tab.dart';

class SubscriptionPlansAdminPage extends ConsumerStatefulWidget {
  const SubscriptionPlansAdminPage({super.key});

  @override
  ConsumerState<SubscriptionPlansAdminPage> createState() => _SubscriptionPlansAdminPageState();
}

class _SubscriptionPlansAdminPageState extends ConsumerState<SubscriptionPlansAdminPage>
    with SingleTickerProviderStateMixin {
  static const _basePath = '/api/v1/subscriptions/admin/plans';

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String? _providerError;
  String _search = '';
  _PlanStatusFilter _statusFilter = _PlanStatusFilter.todos;
  List<_AdminPlan> _plans = const [];
  List<_ProviderPlan> _providerPlans = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _providerError = null;
      });
    }

    final api = ref.read(apiClientProvider);
    try {
      final localResponse = await api.get<List<_AdminPlan>>(
        _basePath,
        (json) => (json as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => _AdminPlan.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );
      _plans = localResponse.data ?? const [];
    } catch (e) {
      _error = e.toString();
    }

    try {
      final providerResponse = await api.get<List<_ProviderPlan>>(
        '$_basePath/provider',
        (json) => (json as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => _ProviderPlan.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
      );
      _providerPlans = providerResponse.data ?? const [];
    } catch (e) {
      _providerError = e.toString();
    }

    if (mounted) setState(() => _loading = false);
  }

  List<_AdminPlan> get _filteredPlans {
    final query = _search.trim().toLowerCase();
    final result = _plans.where((plan) {
      if (_statusFilter == _PlanStatusFilter.activos && !plan.active) return false;
      if (_statusFilter == _PlanStatusFilter.inactivos && plan.active) return false;
      if (_statusFilter == _PlanStatusFilter.promocion && !plan.promotionActive) return false;
      if (query.isEmpty) return true;
      return <String>[
        plan.name,
        plan.code,
        plan.description ?? '',
        plan.badge ?? '',
        plan.promotionText ?? '',
        ...plan.items.map((item) => item.text),
      ].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);

    return result
      ..sort((a, b) {
        final order = a.displayOrder.compareTo(b.displayOrder);
        if (order != 0) return order;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  Future<void> _openEditor([_AdminPlan? plan]) async {
    final palette = ref.read(selectedAppPaletteProvider);
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        final media = MediaQuery.of(context);
        final availableHeight = math.max(
          420.0,
          media.size.height - media.padding.top - media.viewInsets.bottom,
        ).toDouble();
        final height = math.min(availableHeight, math.max(620.0, availableHeight * .95)).toDouble();
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: math.min(media.size.width, 1180.0).toDouble(),
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 28, offset: Offset(0, -10)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: _PlanEditorSheet(plan: plan),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (payload == null) return;

    try {
      final api = ref.read(apiClientProvider);
      if (plan == null) {
        await api.post<Object?>(_basePath, payload, (_) => null);
      } else {
        await api.put<Object?>('$_basePath/${plan.id}', payload, (_) => null);
      }
      if (!mounted) return;
      _snack(plan == null ? 'Plan creado correctamente.' : 'Plan actualizado correctamente.');
      await _load();
    } catch (e) {
      if (mounted) _snack('No fue posible guardar el plan: $e', error: true);
    }
  }

  Future<void> _syncProvider(_AdminPlan plan) async {
    try {
      await ref.read(apiClientProvider).post<Object?>(
            '$_basePath/${plan.id}/sync-provider',
            null,
            (_) => null,
          );
      if (!mounted) return;
      _snack('“${plan.name}” quedó sincronizado con Mercado Pago.');
      await _load();
    } catch (e) {
      if (mounted) _snack('No fue posible sincronizar: $e', error: true);
    }
  }

  Future<void> _deletePlan(_AdminPlan plan) async {
    final confirmed = await _confirm(
      icon: Icons.delete_outline_rounded,
      title: 'Inactivar plan',
      message: '“${plan.name}” dejará de mostrarse como plan disponible. El histórico se conservará y, si tiene un plan activo en Mercado Pago, también será cancelado.',
      actionLabel: 'Inactivar',
      danger: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(apiClientProvider).delete<Object?>('$_basePath/${plan.id}', (_) => null);
      if (!mounted) return;
      _snack('Plan inactivado correctamente.');
      await _load();
    } catch (e) {
      if (mounted) _snack('No fue posible inactivar el plan: $e', error: true);
    }
  }

  Future<void> _cancelProvider(_ProviderPlan plan) async {
    final confirmed = await _confirm(
      icon: Icons.block_rounded,
      title: 'Cancelar en Mercado Pago',
      message: 'Se cancelará “${plan.reason}” en Mercado Pago. Esta acción se realiza únicamente sobre este plan.',
      actionLabel: 'Cancelar plan',
      danger: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(apiClientProvider).delete<Object?>('$_basePath/provider/${plan.id}', (_) => null);
      if (!mounted) return;
      _snack('Plan cancelado en Mercado Pago.');
      await _load();
    } catch (e) {
      if (mounted) _snack('No fue posible cancelar el plan: $e', error: true);
    }
  }

  Future<bool> _confirm({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    bool danger = false,
  }) async {
    final palette = ref.read(selectedAppPaletteProvider);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
        scrollable: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            icon: CircleAvatar(
              radius: 24,
              backgroundColor: (danger ? palette.danger : palette.primary).withOpacity(.12),
              child: Icon(icon, color: danger ? palette.danger : palette.primary),
            ),
            title: Text(title, textAlign: TextAlign.center),
            content: Text(message, textAlign: TextAlign.center),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: danger ? palette.danger : palette.actionColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String message, {bool error = false}) {
    final palette = ref.read(selectedAppPaletteProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? palette.danger : palette.actionColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final active = _plans.where((plan) => plan.active).length;
    final public = _plans.where((plan) => plan.active && plan.publicVisible).length;
    final promos = _plans.where((plan) => plan.active && plan.promotionActive).length;
    final linked = _plans.where((plan) => plan.active && (plan.providerPlanId?.isNotEmpty ?? false)).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: !_loading && _error == null
          ? FloatingActionButton.extended(
              heroTag: 'subscription-plans-create-fab',
              backgroundColor: palette.actionColor,
              foregroundColor: palette.onAction,
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo plan'),
            )
          : null,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          if (_loading)
            const Positioned.fill(child: AppLoader())
          else
            RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: _Header(palette: palette, onRefresh: _load),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: _Metrics(
                            palette: palette,
                            total: _plans.length,
                            active: active,
                            publicCount: public,
                            promotions: promos,
                            linked: linked,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: DecoratedBox(
                            decoration: palette.panelDecoration(baseRadius: 24, elevated: false),
                            child: Column(
                              children: [
                                _Tabs(palette: palette, controller: _tabController),
                                Divider(height: 1, color: palette.cardBorder),
                                SizedBox(
                                  height: math.max(520.0, MediaQuery.sizeOf(context).height - 335).toDouble(),
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildLocalPlans(palette),
                                      _buildProviderPlans(palette),
                                      const AppleSubscriptionAdminTab(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocalPlans(AppPalette palette) {
    if (_error != null) return _errorState(palette, _error!);
    final visible = _filteredPlans;
    return Column(
      children: [
        _PlanFilters(
          palette: palette,
          controller: _searchController,
          status: _statusFilter,
          onSearch: (value) => setState(() => _search = value),
          onStatus: (value) => setState(() => _statusFilter = value),
        ),
        Expanded(
          child: visible.isEmpty
              ? _emptyState(
                  palette,
                  icon: Icons.workspace_premium_outlined,
                  title: _plans.isEmpty ? 'Aún no hay planes' : 'No encontramos planes',
                  subtitle: _plans.isEmpty
                      ? 'Crea tu primer plan y define precio, beneficios y promociones.'
                      : 'Prueba cambiando la búsqueda o los filtros.',
                  action: _plans.isEmpty ? () => _openEditor() : null,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 1020 ? 3 : width >= 680 ? 2 : 1;
                    const spacing = 12.0;
                    final cardWidth = (width - 32 - spacing * (columns - 1)) / columns;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                      child: Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final plan in visible)
                            SizedBox(
                              width: columns == 1 ? width - 32 : cardWidth,
                              child: _planCard(palette, plan),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _planCard(AppPalette palette, _AdminPlan plan) {
    final effectiveChanged = plan.effectivePrice != plan.regularPrice;
    final visibleItems = plan.items.where((item) => item.active).take(5).toList(growable: false);
    final extraItems = plan.items.where((item) => item.active).length - visibleItems.length;
    final tint = plan.recommended ? palette.primary : palette.secondary;

    return DecoratedBox(
      decoration: palette.panelDecoration(baseRadius: 20, tint: tint, elevated: true),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tint.withOpacity(.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    plan.recommended ? Icons.workspace_premium_rounded : Icons.sell_outlined,
                    color: tint,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                _CompactMenu(
                  palette: palette,
                  plan: plan,
                  onEdit: () => _openEditor(plan),
                  onSync: () => _syncProvider(plan),
                  onDelete: () => _deletePlan(plan),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SoftPill(
                  palette: palette,
                  icon: plan.active ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                  text: plan.active ? 'Activo' : 'Inactivo',
                  color: plan.active ? palette.success : palette.textSecondary,
                ),
                if (plan.recommended)
                  _SoftPill(palette: palette, icon: Icons.star_rounded, text: 'Destacado', color: palette.primary),
                if (plan.promotionActive)
                  _SoftPill(
                    palette: palette,
                    icon: Icons.local_offer_outlined,
                    text: '-${_percent(plan.discountPercentage)}%',
                    color: palette.success,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (effectiveChanged)
                        Text(
                          '${_currency(plan.currency)}${_money(plan.regularPrice)}',
                          style: TextStyle(
                            color: palette.textSecondary,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(
                        '${_currency(plan.currency)}${_money(plan.effectivePrice)}',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 28,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '/ ${_shortFrequency(plan.frequency, plan.frequencyType)}',
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            if (plan.promotionText?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                plan.promotionText!.trim(),
                style: TextStyle(color: palette.success, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              plan.description?.trim().isNotEmpty == true
                  ? plan.description!.trim()
                  : 'Sin descripción comercial configurada.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: palette.cardBorder),
            const SizedBox(height: 12),
            Text(
              'Incluye',
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (visibleItems.isEmpty)
              Text('Sin beneficios configurados.', style: TextStyle(color: palette.textSecondary, fontSize: 12))
            else
              ...visibleItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: palette.success),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textPrimary, fontSize: 12.5, height: 1.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (extraItems > 0)
              Text(
                '+ $extraItems beneficio${extraItems == 1 ? '' : 's'} más',
                style: TextStyle(color: palette.primary, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.cardBorder),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FooterState(
                    palette: palette,
                    icon: plan.publicVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    text: plan.publicVisible ? 'En portada' : 'Oculto',
                  ),
                ),
                Expanded(
                  child: _FooterState(
                    palette: palette,
                    icon: plan.providerPlanId?.isNotEmpty == true ? Icons.link_rounded : Icons.link_off_rounded,
                    text: plan.providerPlanId?.isNotEmpty == true ? 'Mercado Pago' : 'Sin vincular',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditor(plan),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                ),
                if (plan.active && !plan.quoteRequired) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.actionColor,
                        foregroundColor: palette.onAction,
                      ),
                      onPressed: () => _syncProvider(plan),
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Sincronizar'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderPlans(AppPalette palette) {
    if (_providerError != null) {
      return _errorState(
        palette,
        'Los planes de BarLytics están disponibles, pero no fue posible consultar Mercado Pago.\n\n$_providerError',
      );
    }
    if (_providerPlans.isEmpty) {
      return _emptyState(
        palette,
        icon: Icons.account_balance_wallet_outlined,
        title: 'Sin planes en Mercado Pago',
        subtitle: 'Cuando sincronices un plan de BarLytics aparecerá aquí.',
      );
    }

    final ordered = [..._providerPlans]
      ..sort((a, b) {
        final activeA = a.status.toLowerCase() == 'active' ? 0 : 1;
        final activeB = b.status.toLowerCase() == 'active' ? 0 : 1;
        final byStatus = activeA.compareTo(activeB);
        return byStatus != 0 ? byStatus : a.reason.toLowerCase().compareTo(b.reason.toLowerCase());
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: _InfoBanner(
            palette: palette,
            icon: Icons.info_outline_rounded,
            text: 'Aquí ves los planes reales creados en Mercado Pago. Los planes antiguos o duplicados se cancelan de forma individual.',
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 840 ? 2 : 1;
              const spacing = 12.0;
              final cardWidth = (constraints.maxWidth - 32 - spacing * (columns - 1)) / columns;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final plan in ordered)
                      SizedBox(
                        width: columns == 1 ? constraints.maxWidth - 32 : cardWidth,
                        child: _providerCard(palette, plan),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _providerCard(AppPalette palette, _ProviderPlan plan) {
    final active = plan.status.toLowerCase() == 'active';
    final linked = plan.localPlanCode?.trim().isNotEmpty == true;
    return DecoratedBox(
      decoration: palette.panelDecoration(
        baseRadius: 18,
        tint: active ? palette.info : palette.textSecondary,
        elevated: false,
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: (active ? palette.info : palette.textSecondary).withOpacity(.12),
                  child: Icon(
                    active ? Icons.account_balance_wallet_rounded : Icons.block_rounded,
                    color: active ? palette.info : palette.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        active ? 'Activo en Mercado Pago' : 'Estado: ${plan.status}',
                        style: TextStyle(
                          color: active ? palette.success : palette.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active)
                  IconButton(
                    tooltip: 'Cancelar este plan',
                    onPressed: () => _cancelProvider(plan),
                    icon: Icon(Icons.delete_outline_rounded, color: palette.danger),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: palette.background.withOpacity(.54),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.cardBorder),
              ),
              child: SelectableText(
                plan.id,
                style: TextStyle(color: palette.textSecondary, fontFamily: 'monospace', fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _ProviderMetric(palette: palette, label: 'Monto', value: '${_currency(plan.currency)}${_money(plan.amount)}'),
                _ProviderMetric(palette: palette, label: 'Frecuencia', value: _shortFrequency(plan.frequency ?? 1, plan.frequencyType)),
                _ProviderMetric(palette: palette, label: 'Prueba', value: '${plan.trialDays ?? 0} días'),
                _ProviderMetric(palette: palette, label: 'Suscritos', value: '${plan.subscribed ?? 0}'),
              ],
            ),
            const SizedBox(height: 12),
            _SoftPill(
              palette: palette,
              icon: linked ? Icons.link_rounded : Icons.link_off_rounded,
              text: linked ? 'Vinculado a ${plan.localPlanCode}' : 'Sin vínculo con plan local',
              color: linked ? palette.success : palette.warning,
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(AppPalette palette, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: palette.danger.withOpacity(.12),
                  child: Icon(Icons.error_outline_rounded, color: palette.danger, size: 30),
                ),
                const SizedBox(height: 14),
                Text('No pudimos cargar la información', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: palette.actionColor, foregroundColor: palette.onAction),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _emptyState(
    AppPalette palette, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? action,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: palette.primary.withOpacity(.10),
                child: Icon(icon, size: 32, color: palette.primary),
              ),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 19)),
              const SizedBox(height: 6),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary)),
              if (action != null) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: palette.actionColor, foregroundColor: palette.onAction),
                  onPressed: action,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear plan'),
                ),
              ],
            ],
          ),
        ),
      );

  String _money(num? value) {
    final raw = (value ?? 0).round().toString();
    final reversed = raw.split('').reversed.toList();
    final chunks = <String>[];
    for (var i = 0; i < reversed.length; i += 3) {
      chunks.add(reversed.skip(i).take(3).toList().reversed.join());
    }
    return chunks.reversed.join('.');
  }

  String _percent(num value) => value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  String _currency(String? code) => (code ?? 'COP').toUpperCase() == 'COP' ? r'$' : '${code ?? ''} ';
  String _shortFrequency(int frequency, String? type) {
    final normalized = (type ?? '').toLowerCase();
    if (normalized == 'months') return frequency == 1 ? 'mes' : '$frequency meses';
    if (normalized == 'days') return frequency == 1 ? 'día' : '$frequency días';
    if (normalized == 'weeks') return frequency == 1 ? 'semana' : '$frequency semanas';
    if (normalized == 'years') return frequency == 1 ? 'año' : '$frequency años';
    return '$frequency ${type ?? ''}'.trim();
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.palette, required this.onRefresh});

  final AppPalette palette;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: palette.panelDecoration(baseRadius: 24, tint: palette.primary),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: palette.mainGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.workspace_premium_rounded, color: palette.onPrimary, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planes de suscripción',
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Precios, promociones, beneficios y sincronización con Mercado Pago.',
                      style: TextStyle(color: palette.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Actualizar',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
      );
}

class _Metrics extends StatelessWidget {
  const _Metrics({
    required this.palette,
    required this.total,
    required this.active,
    required this.publicCount,
    required this.promotions,
    required this.linked,
  });

  final AppPalette palette;
  final int total;
  final int active;
  final int publicCount;
  final int promotions;
  final int linked;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final cards = <Widget>[
            _MetricCard(palette: palette, icon: Icons.layers_outlined, label: 'Planes', value: '$total', helper: '$active activos'),
            _MetricCard(palette: palette, icon: Icons.visibility_outlined, label: 'En portada', value: '$publicCount', helper: 'visibles al cliente'),
            _MetricCard(palette: palette, icon: Icons.local_offer_outlined, label: 'Promociones', value: '$promotions', helper: 'vigentes ahora'),
            _MetricCard(palette: palette, icon: Icons.link_rounded, label: 'Mercado Pago', value: '$linked', helper: 'planes vinculados'),
          ];
          if (compact) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cards.map((card) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: card)).toList(),
            );
          }
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cards[i]),
              ],
            ],
          );
        },
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
  });

  final AppPalette palette;
  final IconData icon;
  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: palette.panelDecoration(baseRadius: 18, elevated: false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: palette.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(helper, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 10.5)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.palette, required this.controller});

  final AppPalette palette;
  final TabController controller;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TabBar(
            controller: controller,
            isScrollable: true,
            dividerColor: Colors.transparent,
            indicator: BoxDecoration(
              color: palette.primary.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.primary.withOpacity(.18)),
            ),
            labelColor: palette.primary,
            unselectedLabelColor: palette.textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900),
            tabs: const [
              Tab(icon: Icon(Icons.view_agenda_outlined, size: 19), text: 'Planes BarLytics'),
              Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 19), text: 'Mercado Pago'),
              Tab(icon: Icon(Icons.apple, size: 19), text: 'App Store'),
            ],
          ),
        ),
      );
}

enum _PlanStatusFilter { todos, activos, inactivos, promocion }

class _PlanFilters extends StatelessWidget {
  const _PlanFilters({
    required this.palette,
    required this.controller,
    required this.status,
    required this.onSearch,
    required this.onStatus,
  });

  final AppPalette palette;
  final TextEditingController controller;
  final _PlanStatusFilter status;
  final ValueChanged<String> onSearch;
  final ValueChanged<_PlanStatusFilter> onStatus;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              maxLength: 120,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              controller: controller,
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Buscar plan o beneficio…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        onPressed: () {
                          controller.clear();
                          onSearch('');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                filled: true,
                fillColor: palette.background.withOpacity(.52),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.cardBorder)),
              ),
            );
            final filter = DropdownButtonFormField<_PlanStatusFilter>(
              initialValue: status,
              decoration: InputDecoration(
                labelText: 'Mostrar',
                prefixIcon: const Icon(Icons.filter_alt_outlined, size: 19),
                filled: true,
                fillColor: palette.background.withOpacity(.52),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.cardBorder)),
              ),
              items: const [
                DropdownMenuItem(value: _PlanStatusFilter.todos, child: Text('Todos')),
                DropdownMenuItem(value: _PlanStatusFilter.activos, child: Text('Activos')),
                DropdownMenuItem(value: _PlanStatusFilter.inactivos, child: Text('Inactivos')),
                DropdownMenuItem(value: _PlanStatusFilter.promocion, child: Text('Con promoción')),
              ],
              onChanged: (value) {
                if (value != null) onStatus(value);
              },
            );
            if (constraints.maxWidth < 620) {
              return Column(children: [search, const SizedBox(height: 8), filter]);
            }
            return Row(children: [Expanded(child: search), const SizedBox(width: 10), SizedBox(width: 190, child: filter)]);
          },
        ),
      );
}

class _CompactMenu extends StatelessWidget {
  const _CompactMenu({
    required this.palette,
    required this.plan,
    required this.onEdit,
    required this.onSync,
    required this.onDelete,
  });

  final AppPalette palette;
  final _AdminPlan plan;
  final VoidCallback onEdit;
  final VoidCallback onSync;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Más acciones',
        icon: Icon(Icons.more_horiz_rounded, color: palette.textSecondary),
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'sync') onSync();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 19), SizedBox(width: 9), Text('Editar plan')])),
          if (plan.active && !plan.quoteRequired)
            const PopupMenuItem(value: 'sync', child: Row(children: [Icon(Icons.sync_rounded, size: 19), SizedBox(width: 9), Text('Sincronizar')])),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [Icon(Icons.delete_outline_rounded, size: 19, color: palette.danger), const SizedBox(width: 9), Text('Inactivar', style: TextStyle(color: palette.danger))]),
          ),
        ],
      );
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({required this.palette, required this.icon, required this.text, required this.color});

  final AppPalette palette;
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10.5))),
          ],
        ),
      );
}

class _FooterState extends StatelessWidget {
  const _FooterState({required this.palette, required this.icon, required this.text});
  final AppPalette palette;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.textSecondary),
          const SizedBox(width: 5),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 11))),
        ],
      );
}

class _ProviderMetric extends StatelessWidget {
  const _ProviderMetric({required this.palette, required this.label, required this.value});
  final AppPalette palette;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5)),
        ],
      );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.palette, required this.icon, required this.text});
  final AppPalette palette;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.info.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.info.withOpacity(.14)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: palette.info),
            const SizedBox(width: 9),
            Expanded(child: Text(text, style: TextStyle(color: palette.textSecondary, fontSize: 12, height: 1.3))),
          ],
        ),
      );
}

class _PlanEditorSheet extends ConsumerStatefulWidget {
  const _PlanEditorSheet({this.plan});
  final _AdminPlan? plan;

  @override
  ConsumerState<_PlanEditorSheet> createState() => _PlanEditorSheetState();
}

class _PlanEditorSheetState extends ConsumerState<_PlanEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _frequency;
  late final TextEditingController _trialDays;
  late final TextEditingController _order;
  late final TextEditingController _badge;
  late final TextEditingController _buttonText;
  late final TextEditingController _discount;
  late final TextEditingController _promoText;
  late final TextEditingController _maxUsers;
  late final TextEditingController _maxBranches;

  late String _currency;
  late String _frequencyType;
  late String _buttonAction;
  late bool _recommended;
  late bool _publicVisible;
  late bool _quoteRequired;
  late bool _active;
  bool _syncProvider = true;
  bool _codeAuto = true;
  DateTime? _promoFrom;
  DateTime? _promoUntil;
  late List<_EditableItem> _items;
  late Map<String, bool> _planFeatures;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _code = TextEditingController(text: p?.code ?? '');
    _codeAuto = p == null;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(text: p == null ? '' : _plainNumber(p.regularPrice));
    _frequency = TextEditingController(text: '${p?.frequency ?? 1}');
    _trialDays = TextEditingController(text: '${p?.trialDays ?? 0}');
    _order = TextEditingController(text: '${p?.displayOrder ?? 100}');
    _badge = TextEditingController(text: p?.badge ?? '');
    _buttonText = TextEditingController(text: p?.buttonText ?? 'Empezar con este plan');
    _discount = TextEditingController(text: p == null ? '0' : _plainNumber(p.discountPercentage));
    _promoText = TextEditingController(text: p?.promotionText ?? '');
    _maxUsers = TextEditingController(text: p?.capabilities['MAX_USUARIOS'] ?? '5');
    _maxBranches = TextEditingController(text: p?.capabilities['MAX_SUCURSALES'] ?? '1');
    _planFeatures = {
      'REPORTES_OPERATIVOS': p?.capabilities['REPORTES_OPERATIVOS'] != 'false',
      'INVENTARIO': p?.capabilities['INVENTARIO'] != 'false',
      'MOVIMIENTOS_INVENTARIO': p?.capabilities['MOVIMIENTOS_INVENTARIO'] != 'false',
      'GESTION_PRECIOS': p?.capabilities['GESTION_PRECIOS'] != 'false',
      'PEDIDOS': p?.capabilities['PEDIDOS'] != 'false',
    };
    _currency = p?.currency ?? 'COP';
    _frequencyType = p?.frequencyType ?? 'months';
    _buttonAction = p?.buttonAction ?? 'REGISTER';
    _recommended = p?.recommended ?? false;
    _publicVisible = p?.publicVisible ?? true;
    _quoteRequired = p?.quoteRequired ?? false;
    _active = p?.active ?? true;
    _promoFrom = p?.promotionFrom;
    _promoUntil = p?.promotionUntil;
    _items = (p?.items ?? const <_AdminItem>[])
        .map((item) => _EditableItem(text: item.text, active: item.active))
        .toList(growable: true);
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _description, _price, _frequency, _trialDays, _order, _badge, _buttonText, _discount, _promoText, _maxUsers, _maxBranches]) {
      c.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final editing = widget.plan != null;
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        children: [
          _sheetHeader(palette, editing),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _section(
                          palette,
                          icon: Icons.storefront_outlined,
                          title: 'Información comercial',
                          subtitle: 'Así verá el cliente este plan en la portada y durante el registro.',
                          child: Column(
                            children: [
                              _twoColumns(
                                _field(
                                  controller: _name,
                                  label: 'Nombre del plan',
                                  maxLength: 100,
                                  hint: 'Ej. BarLytics Pro',
                                  icon: Icons.workspace_premium_outlined,
                                  validator: _required,
                                  onChanged: (value) {
                                    if (!editing && _codeAuto) {
                                      final code = _suggestCode(value);
                                      _code.value = TextEditingValue(text: code, selection: TextSelection.collapsed(offset: code.length));
                                    }
                                  },
                                ),
                                _field(
                                  controller: _code,
                                  label: 'Código interno',
                                  maxLength: 60,
                                  hint: 'BARLYTICS_PRO_MENSUAL',
                                  icon: Icons.code_rounded,
                                  validator: _required,
                                  onChanged: (_) => _codeAuto = false,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _field(
                                controller: _description,
                                label: 'Descripción',
                                hint: 'Explica en una frase para quién es este plan y qué valor ofrece.',
                                icon: Icons.notes_rounded,
                                maxLines: 3,
                                maxLength: 500,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _section(
                          palette,
                          icon: Icons.tune_rounded,
                          title: 'Capacidades y límites',
                          subtitle: 'Estas reglas se aplican realmente en el backend para cada empresa.',
                          child: Column(
                            children: [
                              _twoColumns(
                                _field(controller: _maxUsers, label: 'Usuarios activos', hint: '5 o -1 para ilimitado', icon: Icons.people_outline, maxLength: 10, inputFormatters: InputConstraints.integerFormatters(minValue: -1, maxValue: 2147483647), validator: _planLimit),
                                _field(controller: _maxBranches, label: 'Sucursales activas', hint: '1 o -1 para ilimitado', icon: Icons.store_outlined, maxLength: 10, inputFormatters: InputConstraints.integerFormatters(minValue: -1, maxValue: 2147483647), validator: _planLimit),
                              ),
                              const SizedBox(height: 12),
                              for (final entry in const {
                                'REPORTES_OPERATIVOS': 'Reportes operativos',
                                'INVENTARIO': 'Inventario',
                                'MOVIMIENTOS_INVENTARIO': 'Movimientos de inventario',
                                'GESTION_PRECIOS': 'Gestión de precios',
                                'PEDIDOS': 'Pedidos',
                              }.entries)
                                SwitchListTile.adaptive(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.value),
                                  subtitle: Text(entry.key),
                                  value: _planFeatures[entry.key] ?? false,
                                  onChanged: (value) => setState(() => _planFeatures[entry.key] = value),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _section(
                          palette,
                          icon: Icons.payments_outlined,
                          title: 'Precio y renovación',
                          subtitle: 'Define cuánto se cobra y cada cuánto se renueva la suscripción.',
                          child: Column(
                            children: [
                              _twoColumns(
                                _field(
                                  controller: _price,
                                  label: 'Precio de lista',
                                  inputFormatters: InputConstraints.decimalFormatters(integerDigits: 13, fractionDigits: 2),
                                  hint: _currency == 'COP' ? 'Ej. 50000 para mostrar \$50.000' : 'Ej. 50',
                                  icon: Icons.attach_money_rounded,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: _nonNegativeNumber,
                                ),
                                _dropdown<String>(
                                  palette,
                                  value: _currency,
                                  label: 'Moneda',
                                  icon: Icons.currency_exchange_rounded,
                                  items: const [
                                    DropdownMenuItem(value: 'COP', child: Text('COP · Peso colombiano')),
                                    DropdownMenuItem(value: 'USD', child: Text('USD · Dólar')),
                                  ],
                                  onChanged: (value) => setState(() => _currency = value ?? 'COP'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _twoColumns(
                                _field(
                                  controller: _frequency,
                                  maxLength: 5,
                                  inputFormatters: InputConstraints.digitsFormatters(5),
                                  label: 'Cada',
                                  icon: Icons.repeat_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: _positiveInt,
                                ),
                                _dropdown<String>(
                                  palette,
                                  value: _frequencyType,
                                  label: 'Periodo',
                                  icon: Icons.calendar_month_outlined,
                                  items: const [
                                    DropdownMenuItem(value: 'days', child: Text('Días')),
                                    DropdownMenuItem(value: 'weeks', child: Text('Semanas')),
                                    DropdownMenuItem(value: 'months', child: Text('Meses')),
                                    DropdownMenuItem(value: 'years', child: Text('Años')),
                                  ],
                                  onChanged: (value) => setState(() => _frequencyType = value ?? 'months'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _twoColumns(
                                _field(
                                  controller: _trialDays,
                                  maxLength: 5,
                                  inputFormatters: InputConstraints.digitsFormatters(5),
                                  label: 'Días de prueba',
                                  icon: Icons.hourglass_empty_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: _nonNegativeInt,
                                ),
                                _field(
                                  controller: _order,
                                  maxLength: 5,
                                  inputFormatters: InputConstraints.digitsFormatters(5),
                                  label: 'Orden en la portada',
                                  icon: Icons.sort_rounded,
                                  keyboardType: TextInputType.number,
                                  validator: _nonNegativeInt,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _section(
                          palette,
                          icon: Icons.local_offer_outlined,
                          title: 'Promoción',
                          subtitle: 'Opcional. El precio promocional se calcula a partir del porcentaje de descuento.',
                          child: Column(
                            children: [
                              _twoColumns(
                                _field(
                                  controller: _discount,
                                  label: 'Descuento',
                                  inputFormatters: InputConstraints.decimalFormatters(integerDigits: 3, fractionDigits: 2),
                                  hint: '0',
                                  suffixText: '%',
                                  icon: Icons.percent_rounded,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: _percentage,
                                ),
                                _field(
                                  controller: _promoText,
                                  label: 'Mensaje promocional',
                                  hint: 'Ej. Solo por este mes',
                                  icon: Icons.campaign_outlined,
                                  maxLength: 200,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _twoColumns(
                                _dateField(palette, 'Inicio de promoción', _promoFrom, (value) => setState(() => _promoFrom = value)),
                                _dateField(palette, 'Fin de promoción', _promoUntil, (value) => setState(() => _promoUntil = value)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _section(
                          palette,
                          icon: Icons.auto_awesome_outlined,
                          title: 'Presentación',
                          subtitle: 'Controla cómo se destaca el plan y qué acción realiza el botón principal.',
                          child: Column(
                            children: [
                              _twoColumns(
                                _field(
                                  controller: _badge,
                                  label: 'Etiqueta',
                                  hint: 'Ej. MÁS ELEGIDO',
                                  icon: Icons.label_outline_rounded,
                                  maxLength: 50,
                                ),
                                _field(
                                  controller: _buttonText,
                                  label: 'Texto del botón',
                                  hint: 'Empezar con este plan',
                                  icon: Icons.smart_button_outlined,
                                  maxLength: 80,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _dropdown<String>(
                                palette,
                                value: _buttonAction,
                                label: 'Acción del botón',
                                icon: Icons.touch_app_outlined,
                                items: const [
                                  DropdownMenuItem(value: 'REGISTER', child: Text('Registro y compra')),
                                  DropdownMenuItem(value: 'WHATSAPP', child: Text('Abrir WhatsApp / cotización')),
                                  DropdownMenuItem(value: 'NONE', child: Text('Sin acción')),
                                ],
                                onChanged: (value) => setState(() => _buttonAction = value ?? 'REGISTER'),
                              ),
                              const SizedBox(height: 14),
                              _optionGrid(palette),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _section(
                          palette,
                          icon: Icons.checklist_rounded,
                          title: 'Beneficios incluidos',
                          subtitle: 'Estos son los ítems que el cliente verá debajo del precio del plan.',
                          trailing: TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Agregar beneficio'),
                          ),
                          child: _items.isEmpty
                              ? _emptyItems(palette)
                              : Column(children: [for (var i = 0; i < _items.length; i++) _itemEditor(palette, i)]),
                        ),
                        const SizedBox(height: 12),
                        _section(
                          palette,
                          icon: Icons.sync_alt_rounded,
                          title: 'Mercado Pago',
                          subtitle: 'Mantén el plan externo alineado con el precio y la frecuencia configurados en BarLytics.',
                          child: _OptionTile(
                            palette: palette,
                            icon: Icons.cloud_sync_outlined,
                            title: 'Sincronizar al guardar',
                            subtitle: 'Si precio, frecuencia o prueba cambiaron, se actualizará el vínculo con Mercado Pago.',
                            value: _syncProvider,
                            onChanged: (value) => setState(() => _syncProvider = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _sheetActions(palette, media),
        ],
      ),
    );
  }

  Widget _sheetHeader(AppPalette palette, bool editing) => Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(bottom: BorderSide(color: palette.cardBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(gradient: palette.mainGradient, borderRadius: BorderRadius.circular(14)),
              child: Icon(editing ? Icons.edit_rounded : Icons.add_rounded, color: palette.onPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    editing ? 'Editar plan' : 'Crear nuevo plan',
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text('Todo queda parametrizado en base de datos.', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            IconButton(tooltip: 'Cerrar', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ],
        ),
      );

  Widget _sheetActions(AppPalette palette, MediaQueryData media) => Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.cardBorder)),
          boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(.18), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        padding: EdgeInsets.fromLTRB(18, 10, 18, math.max(10.0, media.padding.bottom + 6).toDouble()),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            const SizedBox(width: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: palette.actionColor, foregroundColor: palette.onAction),
              onPressed: _submit,
              icon: const Icon(Icons.save_outlined, size: 19),
              label: const Text('Guardar plan'),
            ),
          ],
        ),
      );

  Widget _section(
    AppPalette palette, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) =>
      DecoratedBox(
        decoration: palette.panelDecoration(baseRadius: 20, elevated: false),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(11)),
                    child: Icon(icon, color: palette.primary, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15.5)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, height: 1.3)),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? suffixText,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        inputFormatters: inputFormatters ?? (maxLength == null ? null : <TextInputFormatter>[LengthLimitingTextInputFormatter(maxLength)]),
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: suffixText,
          prefixIcon: Icon(icon, size: 19),
          filled: true,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        ),
      );

  Widget _dropdown<T>(
    AppPalette palette, {
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) =>
      DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 19),
          filled: true,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        ),
        items: items,
        onChanged: onChanged,
      );

  Widget _twoColumns(Widget left, Widget right) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 660) {
            return Column(children: [left, const SizedBox(height: 12), right]);
          }
          return Row(children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)]);
        },
      );

  Widget _dateField(AppPalette palette, String label, DateTime? value, ValueChanged<DateTime?> onChanged) => InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2024),
            lastDate: DateTime(2038),
          );
          if (picked != null) onChanged(DateTime(picked.year, picked.month, picked.day));
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            suffixIcon: value == null
                ? const Icon(Icons.keyboard_arrow_down_rounded)
                : IconButton(
                    tooltip: 'Quitar fecha',
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
            filled: true,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
          ),
          child: Text(
            value == null ? 'Sin límite' : _date(value),
            style: TextStyle(color: value == null ? palette.textSecondary : palette.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
      );

  Widget _optionGrid(AppPalette palette) => LayoutBuilder(
        builder: (context, constraints) {
          final items = [
            _OptionTile(
              palette: palette,
              icon: Icons.toggle_on_outlined,
              title: 'Plan activo',
              subtitle: 'Permite usar este plan en nuevos registros.',
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            _OptionTile(
              palette: palette,
              icon: Icons.visibility_outlined,
              title: 'Visible en portada',
              subtitle: 'Aparece automáticamente en Planes y precios.',
              value: _publicVisible,
              onChanged: (value) => setState(() => _publicVisible = value),
            ),
            _OptionTile(
              palette: palette,
              icon: Icons.star_outline_rounded,
              title: 'Plan destacado',
              subtitle: 'Recibe mayor énfasis visual frente a los demás.',
              value: _recommended,
              onChanged: (value) => setState(() => _recommended = value),
            ),
            _OptionTile(
              palette: palette,
              icon: Icons.request_quote_outlined,
              title: 'Requiere cotización',
              subtitle: 'No inicia compra directa; usa el flujo comercial.',
              value: _quoteRequired,
              onChanged: (value) => setState(() => _quoteRequired = value),
            ),
          ];
          if (constraints.maxWidth < 690) {
            return Column(children: [for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 8), items[i]]]);
          }
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: item)).toList(),
          );
        },
      );

  Widget _emptyItems(AppPalette palette) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: palette.background.withOpacity(.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.playlist_add_rounded, color: palette.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text('Aún no hay beneficios. Agrega los puntos que incluye este plan.', style: TextStyle(color: palette.textSecondary))),
          ],
        ),
      );

  Widget _itemEditor(AppPalette palette, int index) {
    final item = _items[index];
    return Container(
      margin: EdgeInsets.only(bottom: index == _items.length - 1 ? 0 : 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: palette.primary.withOpacity(.10), borderRadius: BorderRadius.circular(9)),
            child: Text('${index + 1}', style: TextStyle(color: palette.primary, fontWeight: FontWeight.w900, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: item.controller,
              maxLength: 220,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(220)],
              validator: _required,
              decoration: const InputDecoration(
                hintText: 'Ej. Inventario y control de stock',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Tooltip(
            message: item.active ? 'Visible' : 'Oculto',
            child: Switch.adaptive(value: item.active, onChanged: (value) => setState(() => item.active = value)),
          ),
          IconButton(
            tooltip: 'Subir',
            visualDensity: VisualDensity.compact,
            onPressed: index == 0 ? null : () => _moveItem(index, index - 1),
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Bajar',
            visualDensity: VisualDensity.compact,
            onPressed: index == _items.length - 1 ? null : () => _moveItem(index, index + 1),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Quitar',
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeItem(index),
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: palette.danger),
          ),
        ],
      ),
    );
  }

  void _addItem() => setState(() => _items.add(_EditableItem(text: '', active: true)));

  void _removeItem(int index) {
    final item = _items.removeAt(index);
    item.dispose();
    setState(() {});
  }

  void _moveItem(int from, int to) {
    final item = _items.removeAt(from);
    _items.insert(to, item);
    setState(() {});
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_promoFrom != null && _promoUntil != null && _promoUntil!.isBefore(_promoFrom!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha final de la promoción no puede ser anterior a la fecha inicial.')),
      );
      return;
    }

    Navigator.pop(context, <String, dynamic>{
      'code': _code.text.trim().toUpperCase().replaceAll(' ', '_'),
      'name': _name.text.trim(),
      'description': _nullable(_description.text),
      'price': _double(_price.text),
      'currency': _currency,
      'frequency': int.parse(_frequency.text),
      'frequencyType': _frequencyType,
      'trialDays': int.parse(_trialDays.text),
      'displayOrder': int.parse(_order.text),
      'recommended': _recommended,
      'publicVisible': _publicVisible,
      'quoteRequired': _quoteRequired,
      'badge': _nullable(_badge.text),
      'buttonText': _nullable(_buttonText.text),
      'buttonAction': _buttonAction,
      'discountPercentage': _double(_discount.text),
      'promotionFrom': _promoFrom?.toIso8601String(),
      'promotionUntil': _promoUntil == null
          ? null
          : DateTime(_promoUntil!.year, _promoUntil!.month, _promoUntil!.day, 23, 59, 59).toIso8601String(),
      'promotionText': _nullable(_promoText.text),
      'active': _active,
      'syncProvider': _syncProvider,
      'capabilities': [
        {'code': 'MAX_USUARIOS', 'value': _maxUsers.text.trim()},
        {'code': 'MAX_SUCURSALES', 'value': _maxBranches.text.trim()},
        for (final entry in _planFeatures.entries) {'code': entry.key, 'value': entry.value.toString()},
      ],
      'items': [
        for (var i = 0; i < _items.length; i++)
          {
            'text': _items[i].controller.text.trim(),
            'order': (i + 1) * 10,
            'active': _items[i].active,
          },
      ],
    });
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;
  String? _positiveInt(String? value) => (int.tryParse(value ?? '') ?? 0) < 1 ? 'Debe ser mayor a 0' : null;
  String? _nonNegativeInt(String? value) => (int.tryParse(value ?? '') ?? -1) < 0 ? 'Debe ser 0 o mayor' : null;
  String? _planLimit(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed == null || parsed < -1 ? 'Usa -1 (ilimitado), 0 o un valor mayor' : null;
  }
  String? _nonNegativeNumber(String? value) {
    final n = _doubleOrNull(value);
    if (n == null || n < 0) return 'Número inválido';
    if (_syncProvider && !_quoteRequired && _currency == 'COP' && n > 0 && n < 1600) {
      return 'Mercado Pago exige mínimo \$1.600 COP. Para \$50.000 escribe 50000.';
    }
    return null;
  }
  String? _percentage(String? value) {
    final n = _doubleOrNull(value);
    return n == null || n < 0 || n > 100 ? 'Usa un valor entre 0 y 100' : null;
  }

  static String _plainNumber(num value) => value % 1 == 0 ? value.toInt().toString() : value.toString();
  static double? _doubleOrNull(String? value) => double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  static double _double(String value) => _doubleOrNull(value) ?? 0;
  static String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
  static String _suggestCode(String name) {
    final normalized = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? '' : 'BARLYTICS_${normalized}_MENSUAL';
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final AppPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: value ? palette.primary.withOpacity(.07) : palette.background.withOpacity(.36),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: value ? palette.primary.withOpacity(.22) : palette.cardBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: value ? palette.primary : palette.textSecondary, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, height: 1.25)),
                  ],
                ),
              ),
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
        ),
      );
}

class _EditableItem {
  _EditableItem({required String text, required this.active}) : controller = TextEditingController(text: text);
  final TextEditingController controller;
  bool active;
  void dispose() => controller.dispose();
}

class _AdminPlan {
  const _AdminPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.regularPrice,
    required this.effectivePrice,
    required this.discountPercentage,
    required this.promotionActive,
    required this.currency,
    required this.frequency,
    required this.frequencyType,
    required this.trialDays,
    required this.displayOrder,
    required this.recommended,
    required this.publicVisible,
    required this.quoteRequired,
    required this.buttonAction,
    required this.active,
    required this.items,
    required this.capabilities,
    this.description,
    this.promotionText,
    this.promotionFrom,
    this.promotionUntil,
    this.badge,
    this.buttonText,
    this.providerPlanId,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final double regularPrice;
  final double effectivePrice;
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
  final String? providerPlanId;
  final bool active;
  final List<_AdminItem> items;
  final Map<String, String> capabilities;

  factory _AdminPlan.fromJson(Map<String, dynamic> json) => _AdminPlan(
        id: (json['id'] as num?)?.toInt() ?? 0,
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        regularPrice: (json['regularPrice'] as num?)?.toDouble() ?? 0,
        effectivePrice: (json['effectivePrice'] as num?)?.toDouble() ?? 0,
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
        publicVisible: json['publicVisible'] == true,
        quoteRequired: json['quoteRequired'] == true,
        badge: json['badge']?.toString(),
        buttonText: json['buttonText']?.toString(),
        buttonAction: json['buttonAction']?.toString() ?? 'REGISTER',
        providerPlanId: json['providerPlanId']?.toString(),
        active: json['active'] == true,
        items: (json['items'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => _AdminItem.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        capabilities: (json['capabilities'] as Map? ?? const <dynamic, dynamic>{})
            .map((key, value) => MapEntry(key.toString(), value.toString())),
      );
}

class _AdminItem {
  const _AdminItem({required this.text, required this.order, required this.active});
  final String text;
  final int order;
  final bool active;

  factory _AdminItem.fromJson(Map<String, dynamic> json) => _AdminItem(
        text: json['text']?.toString() ?? '',
        order: (json['order'] as num?)?.toInt() ?? 100,
        active: json['active'] == true,
      );
}

class _ProviderPlan {
  const _ProviderPlan({
    required this.id,
    required this.reason,
    required this.status,
    this.amount,
    this.currency,
    this.frequency,
    this.frequencyType,
    this.trialDays,
    this.subscribed,
    this.localPlanCode,
  });

  final String id;
  final String reason;
  final String status;
  final double? amount;
  final String? currency;
  final int? frequency;
  final String? frequencyType;
  final int? trialDays;
  final int? subscribed;
  final String? localPlanCode;

  factory _ProviderPlan.fromJson(Map<String, dynamic> json) => _ProviderPlan(
        id: json['id']?.toString() ?? '',
        reason: json['reason']?.toString() ?? 'Plan Mercado Pago',
        status: json['status']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble(),
        currency: json['currency']?.toString(),
        frequency: (json['frequency'] as num?)?.toInt(),
        frequencyType: json['frequencyType']?.toString(),
        trialDays: (json['trialDays'] as num?)?.toInt(),
        subscribed: (json['subscribed'] as num?)?.toInt(),
        localPlanCode: json['localPlanCode']?.toString(),
      );
}
