import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../deportes/presentation/widgets/sports_agenda_widget.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../navigation/data/models/user_menu_item.dart';
import '../../../business_setup/data/models/business_setup_models.dart';
import '../../../business_setup/presentation/providers/business_setup_provider.dart';

class ManagerHomePage extends ConsumerStatefulWidget {
  const ManagerHomePage({
    required this.items,
    required this.rolesCount,
  });

  final List<UserMenuItem> items;
  final int rolesCount;

  @override
  ConsumerState<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends ConsumerState<ManagerHomePage> {
  static const _liveInterval = Duration(seconds: 15);

  Timer? _liveTimer;
  Map<String, dynamic> _today = const <String, dynamic>{};
  Map<String, dynamic> _yesterday = const <String, dynamic>{};
  Map<String, dynamic> _week = const <String, dynamic>{};
  List<_ManagerLiveSale> _liveSales = const <_ManagerLiveSale>[];
  int? _loadedBranchId;
  bool _loading = false;
  bool _refreshingLive = false;
  bool _autoRefresh = true;
  String? _error;
  String? _liveError;
  DateTime? _updatedAt;
  bool _hideTeamSetupAlert = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
    _liveTimer = Timer.periodic(_liveInterval, (_) {
      if (_autoRefresh && mounted) _refreshLive();
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final setupStatus = ref.watch(businessSetupStatusProvider).asData?.value;
    final teamStep = _findSetupStep(setupStatus, 'TEAM');
    final showTeamSetupAlert = !_hideTeamSetupAlert && teamStep != null && !teamStep.complete;
    final branchState = ref.watch(branchScopeProvider);
    final branchId = branchState.activeBranchId;

    if (branchId != null && branchId != _loadedBranchId && !_loading && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
    }

    if (branchState.loading && branchId == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: AppLoader(message: 'Preparando sucursales autorizadas...'),
      );
    }

    if (branchId == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AppErrorView(
          message: branchState.failure?.message ?? 'El gerente no tiene una sucursal activa para consultar el negocio.',
          onRetry: () => ref.read(branchScopeProvider.notifier).load(),
        ),
      );
    }

    if (_error != null && _today.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AppErrorView(message: _error!, onRetry: _loadAll),
      );
    }

    if ((_loading || _loadedBranchId == null) && _today.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: AppLoader(message: 'Construyendo el panorama del negocio...'),
      );
    }

    final branchName = branchState.activeBranch?.sucuNombre?.trim();
    final safeBranchName = branchName == null || branchName.isEmpty ? 'Sucursal activa' : branchName;
    final todaySales = _managerNumber(_today, 'total_vendido');
    final yesterdaySales = _managerNumber(_yesterday, 'total_vendido');
    final todayCount = _managerInt(_today['numero_ventas']);
    final ticket = _managerNumber(_today, 'ticket_promedio');
    final units = _managerNumber(_today, 'unidades_vendidas');
    final lowStock = _managerInt(_today['productos_stock_bajo']) +
        _managerInt(_today['productos_agotados']) +
        _managerInt(_today['productos_stock_negativo']);
    final liveTotal = _liveSales.fold<double>(0, (total, sale) => total + sale.total);
    final liveBalance = _liveSales.fold<double>(0, (total, sale) => total + sale.balance);
    final salesVariation = _managerVariation(todaySales, yesterdaySales);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            onRefresh: _loadAll,
            color: palette.secondary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: _ManagerHero(
                          branchName: safeBranchName,
                          updatedAt: _updatedAt,
                          autoRefresh: _autoRefresh,
                          refreshing: _loading || _refreshingLive,
                          palette: palette,
                          onRefresh: _loadAll,
                          onToggleAutoRefresh: () => setState(() => _autoRefresh = !_autoRefresh),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.event_available_outlined,
                              color: Color(0xff009da9),
                            ),
                            title: const Text(
                              'Eventos y reservas',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text(
                              'Crea eventos con fecha y hora, comparte el enlace y administra las mesas y los pagos',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/eventos'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.account_balance_wallet_outlined),
                            title: const Text('Tesorería · Saldos por medio',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Saldo inicial, recaudo, gastos, retiros, transferencias y conciliaciones por sucursal'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/tesoreria'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        child: SportsAgendaWidget(),
                      ),
                    ),
                  ),
                ),
                if (showTeamSetupAlert)
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          child: _ManagerSetupRecommendationAlert(
                            palette: palette,
                            onOpen: () => context.go('/usuarios'),
                            onDismiss: () => setState(() => _hideTeamSetupAlert = true),
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: _ManagerKpiGrid(
                          cards: [
                            _ManagerKpiData(
                              title: 'Ventas de hoy',
                              value: CurrencyUtils.format(todaySales),
                              supporting: '$todayCount ventas finalizadas',
                              icon: Icons.payments_rounded,
                              color: palette.secondary,
                              variation: salesVariation,
                            ),
                            _ManagerKpiData(
                              title: 'Operación abierta',
                              value: CurrencyUtils.format(liveTotal),
                              supporting: '${_liveSales.length} mesas con venta activa',
                              icon: Icons.table_bar_rounded,
                              color: AppColors.info,
                            ),
                            _ManagerKpiData(
                              title: 'Saldo por recaudar',
                              value: CurrencyUtils.format(liveBalance),
                              supporting: liveBalance <= 0 ? 'Operación al día' : 'Pendiente en cuentas abiertas',
                              icon: Icons.account_balance_wallet_rounded,
                              color: liveBalance > 0 ? AppColors.warning : AppColors.success,
                            ),
                            _ManagerKpiData(
                              title: 'Ticket promedio',
                              value: CurrencyUtils.format(ticket),
                              supporting: '${_managerCompactNumber(units)} unidades vendidas',
                              icon: Icons.receipt_long_rounded,
                              color: palette.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: _ManagerFinancePulse(summary: _today, palette: palette),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: _ManagerOverviewLayout(
                          salesCard: _ManagerSalesPulseCard(
                            summary: _week,
                            palette: palette,
                            onOpen: () => _goToModule('ventas', fallback: '/ventas'),
                          ),
                          statusCard: _ManagerBusinessStatusCard(
                            openTables: _liveSales.length,
                            openAmount: liveTotal,
                            pendingAmount: liveBalance,
                            lowStock: lowStock,
                            rolesCount: widget.rolesCount,
                            modulesCount: widget.items.length,
                            palette: palette,
                            onOpenTables: () => _goToModule('mesas', fallback: '/mesas'),
                            onOpenInventory: () => _goToModule('inventario', fallback: '/inventario'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: _ManagerOverviewLayout(
                          leftFlex: 7,
                          rightFlex: 5,
                          salesCard: _ManagerLiveOperationsCard(
                            sales: _liveSales,
                            palette: palette,
                            refreshing: _refreshingLive,
                            autoRefresh: _autoRefresh,
                            error: _liveError,
                            onRefresh: _refreshLive,
                            onOpenAll: () => _goToModule('mesas', fallback: '/mesas'),
                          ),
                          statusCard: _ManagerInventoryAndProductsCard(
                            summary: _week,
                            palette: palette,
                            onOpenInventory: () => _goToModule('inventario', fallback: '/inventario'),
                            onOpenReports: () => _goToModule('reportes', fallback: '/reportes'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: _ManagerSectionHeader(
                          title: 'Accesos de gestión',
                          subtitle: 'Las áreas más usadas del negocio, sin botones sobredimensionados.',
                          icon: Icons.bolt_rounded,
                          palette: palette,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _ManagerQuickAccessGrid(
                          items: _managerPrimaryItems(widget.items),
                          palette: palette,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                        child: _ManagerSectionHeader(
                          title: 'Todos los módulos',
                          subtitle: '${widget.items.length} opciones autorizadas para tu rol.',
                          icon: Icons.apps_rounded,
                          palette: palette,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 34),
                        child: _ManagerCompactModuleGrid(items: widget.items, palette: palette),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading && _today.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: palette.secondary,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadAll() async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 6));
    final api = ref.read(apiClientProvider);

    try {
      final responses = await Future.wait([
        api.get<Map<String, dynamic>>(
          '${ApiPaths.reportes}/resumen',
          _managerParseMap,
          queryParameters: _managerDateParams(today, today, branchId),
        ),
        api.get<Map<String, dynamic>>(
          '${ApiPaths.reportes}/resumen',
          _managerParseMap,
          queryParameters: _managerDateParams(yesterday, yesterday, branchId),
        ),
        api.get<Map<String, dynamic>>(
          '${ApiPaths.reportes}/resumen',
          _managerParseMap,
          queryParameters: _managerDateParams(weekStart, today, branchId),
        ),
        api.get<List<Map<String, dynamic>>>(
          '${ApiPaths.reportes}/ventas/tiempo-real',
          _managerParseMapList,
          queryParameters: {'sucursalId': branchId},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _today = responses[0].data as Map<String, dynamic>? ?? const <String, dynamic>{};
        _yesterday = responses[1].data as Map<String, dynamic>? ?? const <String, dynamic>{};
        _week = responses[2].data as Map<String, dynamic>? ?? const <String, dynamic>{};
        final live = responses[3].data as List<Map<String, dynamic>>? ?? const <Map<String, dynamic>>[];
        _liveSales = live.map(_ManagerLiveSale.fromJson).toList(growable: false)
          ..sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
        _loadedBranchId = branchId;
        _updatedAt = DateTime.now();
        _loading = false;
        _refreshingLive = false;
        _error = null;
        _liveError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshingLive = false;
        _error = ErrorMapper.map(error).message;
      });
    }
  }

  Future<void> _refreshLive() async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null || _refreshingLive || _loading) return;
    setState(() {
      _refreshingLive = true;
      _liveError = null;
    });
    try {
      final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
            '${ApiPaths.reportes}/ventas/tiempo-real',
            _managerParseMapList,
            queryParameters: {'sucursalId': branchId},
          );
      if (!mounted) return;
      final rows = response.data ?? const <Map<String, dynamic>>[];
      setState(() {
        _liveSales = rows.map(_ManagerLiveSale.fromJson).toList(growable: false)
          ..sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
        _updatedAt = DateTime.now();
        _refreshingLive = false;
        _liveError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _refreshingLive = false;
        _liveError = ErrorMapper.map(error).message;
      });
    }
  }

  void _goToModule(String key, {required String fallback}) {
    final normalized = key.trim().toLowerCase();
    for (final item in widget.items) {
      if (item.keyName.trim().toLowerCase() == normalized) {
        context.go(item.path);
        return;
      }
    }
    context.go(fallback);
  }
}

class _ManagerHero extends StatelessWidget {
  const _ManagerHero({
    required this.branchName,
    required this.updatedAt,
    required this.autoRefresh,
    required this.refreshing,
    required this.palette,
    required this.onRefresh,
    required this.onToggleAutoRefresh,
  });

  final String branchName;
  final DateTime? updatedAt;
  final bool autoRefresh;
  final bool refreshing;
  final AppPalette palette;
  final VoidCallback onRefresh;
  final VoidCallback onToggleAutoRefresh;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Buenos días'
        : now.hour < 18
            ? 'Buenas tardes'
            : 'Buenas noches';
    final dateLabel = DateFormat("EEEE, d 'de' MMMM", 'es_CO').format(now);
    final updateLabel = updatedAt == null ? 'Sin actualizar' : 'Actualizado ${DateFormat('HH:mm').format(updatedAt!)}';

    final heroStart = Color.lerp(
          palette.surface,
          palette.primary,
          palette.darkBackground ? 0.14 : 0.055,
        ) ??
        palette.surface;
    final heroEnd = Color.lerp(
          palette.surface,
          palette.secondary,
          palette.darkBackground ? 0.10 : 0.035,
        ) ??
        palette.surface;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [heroStart, palette.surface, heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(palette.radius(28)),
        border: Border.all(color: palette.secondary.withOpacity(palette.darkBackground ? 0.18 : 0.11)),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withOpacity(palette.darkBackground ? 0.14 : 0.075),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -72,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.secondary.withOpacity(palette.darkBackground ? 0.09 : 0.055),
              ),
            ),
          ),
          Positioned(
            right: 130,
            bottom: -80,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.secondary.withOpacity(palette.darkBackground ? 0.08 : 0.045), width: 18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ManagerHeroChip(
                          icon: Icons.storefront_rounded,
                          label: branchName,
                          palette: palette,
                        ),
                        _ManagerHeroChip(
                          icon: autoRefresh ? Icons.wifi_tethering_rounded : Icons.pause_circle_outline_rounded,
                          label: autoRefresh ? 'En vivo' : 'Actualización pausada',
                          palette: palette,
                          accent: autoRefresh ? AppColors.success : AppColors.warning,
                          onTap: onToggleAutoRefresh,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '$greeting, aquí está tu negocio',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.55,
                          ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Ventas, mesas, recaudo e inventario reunidos en una sola vista de control.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 15, color: palette.textSecondary),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '${_managerCapitalize(dateLabel)} · $updateLabel',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                final action = SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: refreshing ? null : onRefresh,
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary.withOpacity(palette.darkBackground ? 0.28 : 0.10),
                      foregroundColor: palette.primary,
                      disabledBackgroundColor: palette.primary.withOpacity(0.06),
                      disabledForegroundColor: palette.primary.withOpacity(0.45),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                    icon: refreshing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary),
                          )
                        : const Icon(Icons.refresh_rounded, size: 19),
                    label: const Text('Actualizar', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 18), action],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [Expanded(child: title), const SizedBox(width: 20), action],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerHeroChip extends StatelessWidget {
  const _ManagerHeroChip({
    required this.icon,
    required this.label,
    required this.palette,
    this.accent,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final AppPalette palette;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? palette.secondary;
    final child = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(palette.darkBackground ? 0.16 : 0.075),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(palette.darkBackground ? 0.24 : 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: child),
    );
  }
}

/// Información financiera del día, derivada del resumen oficial del backend.
/// No equiparar recaudo con saldo bancario: las transferencias, retiros y
/// desembolsos por medio de pago requieren un libro auxiliar propio.
class _ManagerFinancePulse extends StatelessWidget {
  const _ManagerFinancePulse({required this.summary, required this.palette});
  final Map<String, dynamic> summary;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final revenue = _managerNumber(summary, 'ingresos_periodo');
    final cost = _managerNumber(summary, 'costo_ventas_periodo');
    final gross = _managerNumber(summary, 'ganancia_bruta_periodo');
    final operating = _managerNumber(summary, 'gastos_operativos_periodo');
    final net = _managerNumber(summary, 'ganancia_neta_estimada_periodo');
    final margin = _managerNumber(summary, 'margen_neto_porcentaje');
    final paymentRaw = summary['medios_pago'];
    final paymentRows = paymentRaw is List
        ? paymentRaw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    final expenseRaw = summary['desglose_gastos_periodo'];
    final expenseRows = expenseRaw is List
        ? expenseRaw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    expenseRows.sort((a, b) =>
        _managerDouble(b['valor']).compareTo(_managerDouble(a['valor'])));
    final cashFlowRaw = summary['flujo_dinero_por_medio'];
    final cashFlowRows = cashFlowRaw is List
        ? cashFlowRaw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];

    Widget line(String label, double amount, {bool prominent = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: prominent ? palette.textPrimary : palette.textSecondary,
              fontWeight: prominent ? FontWeight.w900 : FontWeight.w600,
            ))),
        const SizedBox(width: 8),
        Text(CurrencyUtils.format(amount),
          style: TextStyle(
            color: prominent ? palette.secondary : palette.textPrimary,
            fontWeight: FontWeight.w800,
          )),
      ]),
    );

    Widget section(String title, String description, Widget child) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.secondary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(color: palette.textSecondary, fontSize: 11)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: palette.panelDecoration(baseRadius: 24, tint: palette.secondary, elevated: false),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.account_balance_wallet_outlined, color: palette.secondary, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Text('Radiografía financiera de hoy',
            style: TextStyle(fontSize: 18, color: palette.textPrimary, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 5),
        Text('Ingresos, costos, gastos y recaudos del día por sucursal.',
          style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final cards = [
            section('Rentabilidad estimada', 'Diferencia entre venta, costo y gastos.',
              Column(children: [
                line('Ingresos por ventas', revenue),
                line('Costo de mercancía vendida', cost),
                line('Ganancia bruta', gross),
                line('Gastos operativos', operating),
                const Divider(),
                line('Ganancia neta estimada', net, prominent: true),
                Align(alignment: Alignment.centerLeft,
                  child: Text('Margen neto: ' + margin.toStringAsFixed(1) + '%',
                    style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w800))),
              ]),
            ),
            section('Ingresos según medio de pago', 'Recaudo de ventas finalizadas. No equivale al saldo disponible en cada cuenta.',
              paymentRows.isEmpty
                ? Text('Sin pagos registrados en ventas finalizadas.', style: TextStyle(color: palette.textSecondary))
                : Column(children: [
                    for (final row in paymentRows)
                      line(_managerText(row['medio_pago'], 'Medio de pago'), _managerDouble(row['total'])),
                  ]),
            ),
            section('¿En qué se gastó hoy?', 'Gastos presupuestados del día y gastos registrados durante el turno.',
              expenseRows.isEmpty
                ? Text('Sin desglose de gastos registrado para este día.', style: TextStyle(color: palette.textSecondary))
                : Column(children: [
                    for (final row in expenseRows.take(8))
                      line(_managerText(row['concepto'], _managerText(row['categoria'], 'Gasto')),
                          _managerDouble(row['valor'])),
                    if (expenseRows.length > 8)
                      Text('Otros gastos en Reportes → Resumen ejecutivo.',
                        style: TextStyle(color: palette.textSecondary, fontSize: 10)),
                  ]),
            ),
            section('Flujo monetario del día', 'Recaudos menos pagos efectivos registrados; no representa el saldo de la cuenta.',
              cashFlowRows.isEmpty
                  ? Text('No hay movimientos de dinero asignables al día.',
                      style: TextStyle(color: palette.textSecondary))
                  : Column(children: [
                      for (final row in cashFlowRows) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _managerText(row['medio_pago'], 'Sin medio'),
                            style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900),
                          ),
                        ),
                        line('  Ingresos', _managerDouble(row['ingresos'])),
                        line('  Egresos', _managerDouble(row['egresos'])),
                        line('  Neto del periodo', _managerDouble(row['flujo_neto']), prominent: true),
                        const SizedBox(height: 6),
                      ],
                    ]),
            ),
          ];
          if (compact) return Column(children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              cards[i],
            ],
          ]);
          return Wrap(
            spacing: 11, runSpacing: 11,
            children: [
              for (final card in cards)
                SizedBox(width: (constraints.maxWidth - 11) / 2, child: card),
            ],
          );
        }),
        const SizedBox(height: 9),
        Text('Nota: los gastos configurados son estimaciones por periodo; un egreso real debe registrarse en caja para conciliar dinero por medio de pago.',
            style: TextStyle(color: palette.textSecondary, fontSize: 10.5)),
      ]),
    );
  }
}

class _ManagerKpiData {
  const _ManagerKpiData({
    required this.title,
    required this.value,
    required this.supporting,
    required this.icon,
    required this.color,
    this.variation,
  });

  final String title;
  final String value;
  final String supporting;
  final IconData icon;
  final Color color;
  final double? variation;
}

class _ManagerKpiGrid extends StatelessWidget {
  const _ManagerKpiGrid({required this.cards});

  final List<_ManagerKpiData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 580
            ? 1
            : constraints.maxWidth < 1020
                ? 2
                : 4;
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: _ManagerKpiCard(data: card)),
          ],
        );
      },
    );
  }
}

class _ManagerKpiCard extends ConsumerWidget {
  const _ManagerKpiCard({required this.data});

  final _ManagerKpiData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final variation = data.variation;
    final positive = variation != null && variation >= 0;
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(16),
      decoration: palette.panelDecoration(baseRadius: 22, tint: data.color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(data.icon, color: data.color, size: 21),
              ),
              const Spacer(),
              if (variation != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: (positive ? AppColors.success : AppColors.danger).withOpacity(0.11),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 14,
                        color: positive ? AppColors.success : AppColors.danger,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${variation.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: positive ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
          ),
          const SizedBox(height: 3),
          Text(data.title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text(
            data.supporting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _ManagerOverviewLayout extends StatelessWidget {
  const _ManagerOverviewLayout({
    required this.salesCard,
    required this.statusCard,
    this.leftFlex = 8,
    this.rightFlex = 4,
  });

  final Widget salesCard;
  final Widget statusCard;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(children: [salesCard, const SizedBox(height: 12), statusCard]);
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: leftFlex, child: salesCard),
              const SizedBox(width: 12),
              Expanded(flex: rightFlex, child: statusCard),
            ],
          ),
        );
      },
    );
  }
}

class _ManagerSalesPulseCard extends StatelessWidget {
  const _ManagerSalesPulseCard({
    required this.summary,
    required this.palette,
    required this.onOpen,
  });

  final Map<String, dynamic> summary;
  final AppPalette palette;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = _managerMapList(summary['ventas_por_fecha']);
    final series = _managerSevenDaySeries(rows);
    final total = _managerNumber(summary, 'total_vendido');
    final ticket = _managerNumber(summary, 'ticket_promedio');
    final units = _managerNumber(summary, 'unidades_vendidas');
    final maxValue = series.fold<double>(0, (max, item) => item.value > max ? item.value : max);

    return _ManagerPanel(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManagerPanelHeader(
            icon: Icons.show_chart_rounded,
            title: 'Pulso de ventas',
            subtitle: 'Comportamiento de los últimos 7 días',
            palette: palette,
            actionLabel: 'Ver ventas',
            onAction: onOpen,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _ManagerInlineMetric(label: 'Total semanal', value: CurrencyUtils.format(total), palette: palette),
              _ManagerInlineMetric(label: 'Ticket promedio', value: CurrencyUtils.format(ticket), palette: palette),
              _ManagerInlineMetric(label: 'Unidades', value: _managerCompactNumber(units), palette: palette),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in series)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            point.value <= 0 ? '-' : _managerShortCurrency(point.value),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(color: palette.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: maxValue <= 0 ? 0.04 : (point.value / maxValue).clamp(0.04, 1.0).toDouble(),
                                widthFactor: 0.72,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [palette.secondary, palette.primary],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(9), bottom: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            point.label,
                            style: TextStyle(color: point.isToday ? palette.secondary : palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w900),
                          ),
                        ],
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
}

class _ManagerBusinessStatusCard extends StatelessWidget {
  const _ManagerBusinessStatusCard({
    required this.openTables,
    required this.openAmount,
    required this.pendingAmount,
    required this.lowStock,
    required this.rolesCount,
    required this.modulesCount,
    required this.palette,
    required this.onOpenTables,
    required this.onOpenInventory,
  });

  final int openTables;
  final double openAmount;
  final double pendingAmount;
  final int lowStock;
  final int rolesCount;
  final int modulesCount;
  final AppPalette palette;
  final VoidCallback onOpenTables;
  final VoidCallback onOpenInventory;

  @override
  Widget build(BuildContext context) {
    final healthy = pendingAmount <= 0 && lowStock == 0;
    return _ManagerPanel(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManagerPanelHeader(
            icon: Icons.monitor_heart_rounded,
            title: 'Estado del negocio',
            subtitle: healthy ? 'La operación está bajo control' : 'Hay puntos que requieren seguimiento',
            palette: palette,
          ),
          const SizedBox(height: 15),
          _ManagerStatusRow(
            icon: Icons.table_bar_rounded,
            title: '$openTables mesas activas',
            subtitle: '${CurrencyUtils.format(openAmount)} en operación',
            color: openTables > 0 ? AppColors.info : AppColors.success,
            palette: palette,
            onTap: onOpenTables,
          ),
          const SizedBox(height: 9),
          _ManagerStatusRow(
            icon: Icons.payments_outlined,
            title: CurrencyUtils.format(pendingAmount),
            subtitle: pendingAmount > 0 ? 'Saldo pendiente por recaudar' : 'Sin saldo pendiente',
            color: pendingAmount > 0 ? AppColors.warning : AppColors.success,
            palette: palette,
            onTap: onOpenTables,
          ),
          const SizedBox(height: 9),
          _ManagerStatusRow(
            icon: Icons.inventory_2_outlined,
            title: '$lowStock alertas de inventario',
            subtitle: lowStock > 0 ? 'Agotados, negativos o stock bajo' : 'Inventario sin alertas críticas',
            color: lowStock > 0 ? AppColors.danger : AppColors.success,
            palette: palette,
            onTap: onOpenInventory,
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.secondary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded, color: palette.secondary, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$modulesCount módulos · $rolesCount roles activos',
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerLiveOperationsCard extends StatelessWidget {
  const _ManagerLiveOperationsCard({
    required this.sales,
    required this.palette,
    required this.refreshing,
    required this.autoRefresh,
    required this.error,
    required this.onRefresh,
    required this.onOpenAll,
  });

  final List<_ManagerLiveSale> sales;
  final AppPalette palette;
  final bool refreshing;
  final bool autoRefresh;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return _ManagerPanel(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManagerPanelHeader(
            icon: Icons.sync_rounded,
            title: 'Mesas en vivo',
            subtitle: autoRefresh ? 'Actualización automática cada 15 segundos' : 'Actualización automática pausada',
            palette: palette,
            actionLabel: 'Ver salón',
            onAction: onOpenAll,
          ),
          if (refreshing) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(minHeight: 2, color: palette.secondary, backgroundColor: palette.secondary.withOpacity(0.08)),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Material(
              color: AppColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onRefresh,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(error!, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 12))),
                      const Icon(Icons.refresh_rounded, color: AppColors.danger, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (sales.isEmpty)
            _ManagerEmptyState(
              icon: Icons.table_restaurant_rounded,
              title: 'No hay mesas ocupadas',
              subtitle: 'La operación abierta aparecerá aquí en tiempo real.',
              palette: palette,
            )
          else
            _ManagerVisibleSalesList(
              sales: sales,
              palette: palette,
              onOpenAll: onOpenAll,
            ),
        ],
      ),
    );
  }
}

class _ManagerVisibleSalesList extends StatelessWidget {
  const _ManagerVisibleSalesList({
    required this.sales,
    required this.palette,
    required this.onOpenAll,
  });

  final List<_ManagerLiveSale> sales;
  final AppPalette palette;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final visibleCount = sales.length > 5 ? 5 : sales.length;
    return Column(
      children: [
        for (var index = 0; index < visibleCount; index++) ...[
          _ManagerLiveSaleRow(sale: sales[index], palette: palette, onTap: onOpenAll),
          if (index + 1 < visibleCount)
            Divider(height: 1, color: palette.cardBorder.withOpacity(0.55)),
        ],
      ],
    );
  }
}

class _ManagerLiveSaleRow extends StatelessWidget {
  const _ManagerLiveSaleRow({required this.sale, required this.palette, required this.onTap});

  final _ManagerLiveSale sale;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgent = sale.durationMinutes >= 90 || sale.balance >= 100000;
    final progress = sale.total <= 0 ? 0.0 : (sale.paid / sale.total).clamp(0.0, 1.0).toDouble();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (urgent ? AppColors.warning : palette.secondary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${sale.tableNumber}',
                    style: TextStyle(color: urgent ? AppColors.warning : palette.secondary, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            sale.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5),
                          ),
                        ),
                        if (urgent) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 15),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${sale.responsible} · ${_managerDuration(sale.durationMinutes)} · ${sale.accounts} cuenta${sale.accounts == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 10.8),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: palette.cardBorder.withOpacity(0.42),
                        valueColor: AlwaysStoppedAnimation(progress >= 1 ? AppColors.success : palette.secondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(CurrencyUtils.format(sale.total), style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5)),
                    const SizedBox(height: 3),
                    Text(
                      sale.balance > 0 ? 'Saldo ${CurrencyUtils.format(sale.balance)}' : 'Pagada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sale.balance > 0 ? AppColors.warning : AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerInventoryAndProductsCard extends StatelessWidget {
  const _ManagerInventoryAndProductsCard({
    required this.summary,
    required this.palette,
    required this.onOpenInventory,
    required this.onOpenReports,
  });

  final Map<String, dynamic> summary;
  final AppPalette palette;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    final alerts = _managerMapList(summary['alertas_inventario']).take(3).toList(growable: false);
    final products = _managerMapList(summary['productos_mas_vendidos']).take(4).toList(growable: false);
    return _ManagerPanel(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ManagerPanelHeader(
            icon: Icons.inventory_rounded,
            title: 'Inventario y productos',
            subtitle: 'Alertas y productos con mayor movimiento',
            palette: palette,
          ),
          const SizedBox(height: 14),
          if (alerts.isEmpty)
            _ManagerStatusRow(
              icon: Icons.check_circle_rounded,
              title: 'Sin alertas críticas',
              subtitle: 'No hay productos negativos o agotados con rotación.',
              color: AppColors.success,
              palette: palette,
              onTap: onOpenInventory,
            )
          else ...[
            for (final alert in alerts) ...[
              _ManagerInventoryAlertRow(data: alert, palette: palette, onTap: onOpenInventory),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 8),
          Divider(color: palette.cardBorder.withOpacity(0.58)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Más vendidos · 7 días', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5))),
              TextButton(onPressed: onOpenReports, child: const Text('Ver reporte')),
            ],
          ),
          if (products.isEmpty)
            Text('Todavía no hay ventas finalizadas en el periodo.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12))
          else
            for (var index = 0; index < products.length; index++)
              _ManagerTopProductRow(index: index, data: products[index], palette: palette),
        ],
      ),
    );
  }
}

class _ManagerInventoryAlertRow extends StatelessWidget {
  const _ManagerInventoryAlertRow({required this.data, required this.palette, required this.onTap});

  final Map<String, dynamic> data;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _managerText(data['estado'], 'ALERTA');
    final stock = _managerDouble(data['stock_actual']);
    final color = status.contains('NEGATIVO') ? AppColors.danger : AppColors.warning;
    return Material(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _managerText(data['producto'], 'Producto'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 11.8),
                    ),
                    Text(
                      _managerHumanize(status),
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Text(
                '${_managerCompactNumber(stock)} und.',
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerTopProductRow extends StatelessWidget {
  const _ManagerTopProductRow({required this.index, required this.data, required this.palette});

  final int index;
  final Map<String, dynamic> data;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final quantity = _managerDouble(data['cantidad']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: (index == 0 ? AppColors.warning : palette.secondary).withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text('${index + 1}', style: TextStyle(color: index == 0 ? AppColors.warning : palette.secondary, fontWeight: FontWeight.w900, fontSize: 10.5)),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _managerText(data['producto'], 'Producto'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 11.5),
            ),
          ),
          Text('${_managerCompactNumber(quantity)} und.', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800, fontSize: 10.8)),
        ],
      ),
    );
  }
}

class _ManagerPanel extends StatelessWidget {
  const _ManagerPanel({required this.palette, required this.child});

  final AppPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: palette.panelDecoration(baseRadius: 23, tint: palette.secondary),
      child: child,
    );
  }
}

class _ManagerPanelHeader extends StatelessWidget {
  const _ManagerPanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.palette,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppPalette palette;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: palette.secondary, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 1),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)),
            ],
          ),
        ),
        if (onAction != null && actionLabel != null)
          SizedBox(
            height: 36,
            child: TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
            ),
          ),
      ],
    );
  }
}

class _ManagerInlineMetric extends StatelessWidget {
  const _ManagerInlineMetric({required this.label, required this.value, required this.palette});

  final String label;
  final String value;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
        Text(label, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 10.5)),
      ],
    );
  }
}

class _ManagerStatusRow extends StatelessWidget {
  const _ManagerStatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 10.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerEmptyState extends StatelessWidget {
  const _ManagerEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.palette,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(palette.darkBackground ? 0.28 : 0.52),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.cardBorder.withOpacity(0.58)),
      ),
      child: Column(
        children: [
          Icon(icon, color: palette.secondary, size: 34),
          const SizedBox(height: 9),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _ManagerSectionHeader extends StatelessWidget {
  const _ManagerSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [palette.primary, palette.secondary]),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: palette.onPrimary, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w900)),
              Text(subtitle, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ManagerQuickAccessGrid extends StatelessWidget {
  const _ManagerQuickAccessGrid({required this.items, required this.palette});

  final List<UserMenuItem> items;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560
            ? 1
            : constraints.maxWidth < 960
                ? 2
                : 3;
        const spacing = 10.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _ManagerQuickAccessCard(item: item, palette: palette)),
          ],
        );
      },
    );
  }
}

class _ManagerQuickAccessCard extends StatelessWidget {
  const _ManagerQuickAccessCard({required this.item, required this.palette});

  final UserMenuItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(item.keyName);
    final accent = Color.lerp(visual.color, palette.secondary, 0.45) ?? palette.secondary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(palette.radius(18)),
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(palette.radius(18)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.all(13),
          decoration: palette.panelDecoration(baseRadius: 18, tint: accent),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: accent.withOpacity(0.13), borderRadius: BorderRadius.circular(13)),
                child: Icon(visual.icon, color: accent, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12.5)),
                    const SizedBox(height: 3),
                    Text(
                      item.description ?? visual.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 10.8),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerCompactModuleGrid extends StatelessWidget {
  const _ManagerCompactModuleGrid({required this.items, required this.palette});

  final List<UserMenuItem> items;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 540
            ? 2
            : constraints.maxWidth < 900
                ? 3
                : constraints.maxWidth < 1250
                    ? 4
                    : 5;
        const spacing = 10.0;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _ManagerCompactModuleCard(item: item, palette: palette)),
          ],
        );
      },
    );
  }
}

class _ManagerCompactModuleCard extends StatelessWidget {
  const _ManagerCompactModuleCard({required this.item, required this.palette});

  final UserMenuItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(item.keyName);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(palette.radius(16)),
      child: InkWell(
        onTap: () => context.go(item.path),
        borderRadius: BorderRadius.circular(palette.radius(16)),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: palette.surface.withOpacity(palette.darkBackground ? 0.76 : 0.93),
            borderRadius: BorderRadius.circular(palette.radius(16)),
            border: Border.all(color: palette.cardBorder.withOpacity(0.66)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: palette.secondary.withOpacity(0.10), borderRadius: BorderRadius.circular(11)),
                child: Icon(visual.icon, color: palette.secondary, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800, fontSize: 11.5, height: 1.12),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagerLiveSale {
  const _ManagerLiveSale({
    required this.id,
    required this.tableNumber,
    required this.tableDescription,
    required this.responsible,
    required this.total,
    required this.paid,
    required this.balance,
    required this.durationMinutes,
    required this.accounts,
  });

  final int id;
  final int tableNumber;
  final String tableDescription;
  final String responsible;
  final double total;
  final double paid;
  final double balance;
  final double durationMinutes;
  final int accounts;

  factory _ManagerLiveSale.fromJson(Map<String, dynamic> json) {
    final accountRows = _managerMapList(json['cuentas']);
    return _ManagerLiveSale(
      id: _managerInt(json['venta_id']),
      tableNumber: _managerInt(json['mesa_numero']),
      tableDescription: _managerText(json['mesa_descripcion'], ''),
      responsible: _managerText(json['responsable'], 'Sin responsable'),
      total: _managerDouble(json['total']),
      paid: _managerDouble(json['total_pagado']),
      balance: _managerDouble(json['saldo_pendiente']),
      durationMinutes: _managerDouble(json['duracion_minutos']),
      accounts: accountRows.length,
    );
  }

  String get title {
    final table = tableNumber > 0 ? 'Mesa $tableNumber' : 'Venta #$id';
    return tableDescription.isEmpty ? table : '$table · $tableDescription';
  }
}

class _ManagerSeriesPoint {
  const _ManagerSeriesPoint({required this.label, required this.value, required this.isToday});

  final String label;
  final double value;
  final bool isToday;
}

List<UserMenuItem> _managerPrimaryItems(List<UserMenuItem> items) {
  const priority = <String>['ventas', 'mesas', 'pagos', 'inventario', 'reportes', 'usuarios'];
  final selected = <UserMenuItem>[];
  for (final key in priority) {
    for (final item in items) {
      if (item.keyName.trim().toLowerCase() == key && !selected.contains(item)) {
        selected.add(item);
        break;
      }
    }
  }
  for (final item in items) {
    if (selected.length >= 6) break;
    if (!selected.contains(item)) selected.add(item);
  }
  return selected.take(6).toList(growable: false);
}

Map<String, dynamic> _managerParseMap(Object? json) {
  if (json is Map) return Map<String, dynamic>.from(json);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _managerParseMapList(Object? json) => _managerMapList(json);

List<Map<String, dynamic>> _managerMapList(Object? value) {
  return (value as List? ?? const <Object?>[])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Map<String, dynamic> _managerDateParams(DateTime start, DateTime end, int branchId) => {
      'inicio': DateFormat('yyyy-MM-dd').format(start),
      'fin': DateFormat('yyyy-MM-dd').format(end),
      'sucursalId': branchId,
    };

List<_ManagerSeriesPoint> _managerSevenDaySeries(List<Map<String, dynamic>> rows) {
  final byDate = <String, double>{};
  for (final row in rows) {
    final date = DateTime.tryParse(row['fecha']?.toString() ?? '');
    if (date == null) continue;
    byDate[DateFormat('yyyy-MM-dd').format(date)] = _managerDouble(row['total']);
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return List.generate(7, (index) {
    final date = today.subtract(Duration(days: 6 - index));
    final key = DateFormat('yyyy-MM-dd').format(date);
    final label = DateFormat('EEE', 'es_CO').format(date).replaceAll('.', '');
    return _ManagerSeriesPoint(
      label: _managerCapitalize(label),
      value: byDate[key] ?? 0,
      isToday: index == 6,
    );
  }, growable: false);
}

double _managerNumber(Map<String, dynamic> map, String key) => _managerDouble(map[key]);

double _managerDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _managerInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _managerText(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double? _managerVariation(double current, double previous) {
  if (previous == 0) return current == 0 ? 0 : null;
  return ((current - previous) / previous) * 100;
}

String _managerCompactNumber(num value) {
  final number = value.toDouble();
  if (number == number.roundToDouble()) return number.toInt().toString();
  return number.toStringAsFixed(1);
}

String _managerShortCurrency(double value) {
  final absolute = value.abs();
  if (absolute >= 1000000) return r'$' + '${(value / 1000000).toStringAsFixed(1)}M';
  if (absolute >= 1000) return r'$' + '${(value / 1000).toStringAsFixed(0)}k';
  return CurrencyUtils.format(value);
}

String _managerDuration(double minutes) {
  final total = minutes.round().clamp(0, 1000000);
  if (total < 60) return '$total min';
  final hours = total ~/ 60;
  final remaining = total % 60;
  return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}m';
}

String _managerHumanize(String value) {
  final text = value.toLowerCase().replaceAll('_', ' ');
  return _managerCapitalize(text);
}

String _managerCapitalize(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

BusinessSetupStepModel? _findSetupStep(BusinessSetupStatusModel? status, String code) {
  if (status == null) return null;
  for (final step in status.steps) {
    if (step.code.trim().toUpperCase() == code.trim().toUpperCase()) return step;
  }
  return null;
}

class _ManagerSetupRecommendationAlert extends StatelessWidget {
  const _ManagerSetupRecommendationAlert({
    required this.palette,
    required this.onOpen,
    required this.onDismiss,
  });

  final AppPalette palette;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: palette.accent.withOpacity(.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.group_add_outlined, color: palette.accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Vas a trabajar con más personas?',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Puedes crear usuarios y asignarles rol y sucursal. No bloquea el uso de BarLytics, pero es recomendable antes de entregar accesos al equipo.',
                style: TextStyle(
                  color: palette.textSecondary,
                  height: 1.4,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('Más tarde'),
        ),
        const SizedBox(width: 6),
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.arrow_forward_rounded, size: 17),
          label: const Text('Configurar usuarios'),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.accent.withOpacity(.18)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content, const SizedBox(height: 10), Align(alignment: Alignment.centerRight, child: actions)],
            )
          : Row(
              children: [Expanded(child: content), const SizedBox(width: 14), actions],
            ),
    );
  }
}

