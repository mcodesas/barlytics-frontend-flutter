import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_control_metrics.dart';
import '../../../../app/theme/app_palette.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/input_constraints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/tech_background.dart';

/// Centro de registro y consulta de pagos para GERENTE.
class PagosListPage extends ConsumerStatefulWidget {
  const PagosListPage({super.key, this.openCreateOnStart = false, this.initialPaymentId});

  final bool openCreateOnStart;
  final int? initialPaymentId;

  @override
  ConsumerState<PagosListPage> createState() => _PagosListPageState();
}

class _PagosListPageState extends ConsumerState<PagosListPage> {
  final _searchController = TextEditingController();
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: r'$', decimalDigits: 0);
  final _dateTime = DateFormat('dd/MM/yyyy · hh:mm a', 'es_CO');

  List<_PaymentAdmin> _payments = const [];
  List<_PendingAccount> _pendingAccounts = const [];
  List<_PaymentMethod> _methods = const [];

  DateTime _start = DateTime.now();
  DateTime _endExclusive = DateTime.now().add(const Duration(days: 1));
  String _periodLabel = 'Hoy';
  String _search = '';
  int? _methodId;
  bool _loading = true;
  bool _refreshing = false;
  bool _autoRefresh = true;
  String? _error;
  Timer? _timer;
  int _page = 0;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    if (widget.initialPaymentId == null) {
      _setToday(notify: false);
    } else {
      final now = DateTime.now();
      _start = DateTime(2000, 1, 1);
      _endExclusive = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      _periodLabel = 'Histórico';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
      if (!mounted) return;
      if (widget.initialPaymentId != null) {
        for (final payment in _payments) {
          if (payment.id == widget.initialPaymentId) {
            await _showPaymentDetail(payment);
            return;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El pago solicitado no está dentro del periodo actual.')),
        );
      }
      if (widget.openCreateOnStart && _pendingAccounts.isNotEmpty && _methods.isNotEmpty) {
        await _showRegisterSheet();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_autoRefresh && mounted) _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    final branchId = ref.read(branchScopeProvider).activeBranchId;
    if (branchId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
          _error = 'Selecciona una sucursal para consultar los pagos.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        if (!silent) _loading = _payments.isEmpty;
        _refreshing = silent || _payments.isNotEmpty;
        _error = null;
      });
    }

    try {
      final client = ref.read(apiClientProvider);
      final paymentsResponse = await client.get<List<_PaymentAdmin>>(
        '${ApiPaths.pagos}/administracion',
        (json) => (json as List? ?? const [])
            .whereType<Map>()
            .map((item) => _PaymentAdmin.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        queryParameters: {
          'sucursalId': branchId,
          'inicio': _start.toIso8601String(),
          'fin': _endExclusive.toIso8601String(),
          'limite': 2000,
        },
      );
      final accountsResponse = await client.get<List<_PendingAccount>>(
        '${ApiPaths.pagos}/cuentas-pendientes',
        (json) => (json as List? ?? const [])
            .whereType<Map>()
            .map((item) => _PendingAccount.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        queryParameters: {'sucursalId': branchId, 'limite': 500},
      );
      final methodsResponse = await client.get<List<_PaymentMethod>>(
        '${ApiPaths.mediospago}/sucursal/$branchId',
        (json) => (json as List? ?? const [])
            .whereType<Map>()
            .map((item) => _PaymentMethod.fromJson(Map<String, dynamic>.from(item)))
            .where((item) => item.id != null && item.active)
            .toList(growable: false),
      );

      if (!mounted) return;
      setState(() {
        _payments = paymentsResponse.data ?? const [];
        _pendingAccounts = accountsResponse.data ?? const [];
        _methods = methodsResponse.data ?? const [];
        if (_methodId != null && !_methods.any((item) => item.id == _methodId)) _methodId = null;
        _page = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ErrorMapper.map(error).message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  List<_PaymentAdmin> get _filtered {
    final query = _search.trim().toLowerCase();
    return _payments.where((payment) {
      if (_methodId != null && payment.methodId != _methodId) return false;
      if (query.isEmpty) return true;
      return [
        payment.id,
        payment.accountId,
        payment.accountNumber,
        payment.saleId,
        payment.tableNumber,
        payment.methodName,
        payment.registeredBy,
        payment.accountDescription,
        payment.observation,
      ].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
  }

  List<_PaymentAdmin> get _visiblePage {
    final items = _filtered;
    final maxPage = items.isEmpty ? 0 : (items.length - 1) ~/ _pageSize;
    final safePage = _page.clamp(0, maxPage).toInt();
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int?>(
      branchScopeProvider.select((state) => state.activeBranchId),
      (previous, next) {
        if (previous != next) _loadData();
      },
    );

    final palette = ref.watch(selectedAppPaletteProvider);
    final branch = ref.watch(branchScopeProvider).activeBranch;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          if (_loading)
            const Positioned.fill(child: AppLoader())
          else
            RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(palette, branch?.sucuNombre ?? 'Sucursal'),
                          const SizedBox(height: 10),
                          if (_error != null) _errorPanel(palette) else ...[
                            _summary(palette),
                            const SizedBox(height: 10),
                            _toolbar(palette),
                            const SizedBox(height: 10),
                            _paymentContent(palette),
                            if (_filtered.length > _pageSize) ...[
                              const SizedBox(height: 10),
                              _pagination(palette),
                            ],
                          ],
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

  Widget _header(AppPalette palette, String branchName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _panelDecoration(palette, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final title = Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.secondary.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.payments_rounded, color: palette.secondary, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Administración de pagos', style: TextStyle(color: palette.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text('$branchName · Registro y consulta de recaudos', style: TextStyle(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (_refreshing) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          );
          final actions = Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: _showPeriodSheet,
                icon: const Icon(Icons.date_range_rounded, size: 17),
                label: Text(_periodLabel),
              ),
              AppButton(
                label: 'Registrar pago',
                icon: Icons.add_card_rounded,
                compact: true,
                onPressed: _pendingAccounts.isEmpty || _methods.isEmpty ? null : _showRegisterSheet,
              ),
            ],
          );
          if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [title, const SizedBox(height: 10), actions]);
          return Row(children: [Expanded(child: title), actions]);
        },
      ),
    );
  }

  Widget _summary(AppPalette palette) {
    final total = _payments.fold<double>(0, (sum, item) => sum + item.amount);
    final cash = _payments.where((item) => item.isCash).fold<double>(0, (sum, item) => sum + item.amount);
    final digital = total - cash;
    final average = _payments.isEmpty ? 0 : total / _payments.length;
    final metrics = [
      _PaymentMetric(Icons.account_balance_wallet_rounded, 'Recaudado', _currency.format(total), '${_payments.length} pagos'),
      _PaymentMetric(Icons.payments_outlined, 'Efectivo', _currency.format(cash), 'valor aplicado'),
      _PaymentMetric(Icons.qr_code_2_rounded, 'Otros medios', _currency.format(digital), 'transferencias y tarjetas'),
      _PaymentMetric(Icons.receipt_long_rounded, 'Promedio', _currency.format(average), 'por registro'),
      _PaymentMetric(Icons.pending_actions_rounded, 'Cuentas pendientes', '${_pendingAccounts.length}', 'disponibles para cobrar'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 680 ? constraints.maxWidth : (constraints.maxWidth - 32) / 5;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: metrics.map((metric) => SizedBox(width: width, child: _metricCard(metric, palette))).toList(growable: false),
        );
      },
    );
  }

  Widget _metricCard(_PaymentMetric metric, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: _panelDecoration(palette, 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: palette.secondary.withOpacity(0.11), borderRadius: BorderRadius.circular(11)),
            child: Icon(metric.icon, color: palette.secondary, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metric.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w800)),
                Text(metric.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
                Text(metric.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _panelDecoration(palette, 17),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final search = TextField(
            maxLength: 120,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            controller: _searchController,
            onChanged: (value) => setState(() {
              _search = value;
              _page = 0;
            }),
            decoration: InputDecoration(
              hintText: 'Buscar venta directa, mesa, cuenta, responsable o referencia',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _search = '';
                          _page = 0;
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ).compactFilter(),
          );
          final method = DropdownButtonFormField<int>(
            value: _methodId ?? -1,
            isExpanded: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.credit_card_rounded), labelText: 'Medio').compactFilter(),
            items: [
              const DropdownMenuItem<int>(value: -1, child: Text('Todos')),
              ..._methods.where((item) => item.id != null).map((item) => DropdownMenuItem<int>(value: item.id!, child: Text(item.name, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (value) => setState(() {
              _methodId = value == -1 ? null : value;
              _page = 0;
            }),
          );
          final toggles = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                onPressed: () => setState(() => _autoRefresh = !_autoRefresh),
                tooltip: _autoRefresh ? 'Pausar actualización' : 'Reanudar actualización',
                icon: Icon(_autoRefresh ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(onPressed: _refreshing ? null : _loadData, tooltip: 'Actualizar', icon: const Icon(Icons.refresh_rounded)),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [search, const SizedBox(height: 8), Row(children: [Expanded(child: method), const SizedBox(width: 8), toggles])],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 8),
              SizedBox(width: 190, child: method),
              const SizedBox(width: 8),
              toggles,
            ],
          );
        },
      ),
    );
  }

  Widget _paymentContent(AppPalette palette) {
    if (_filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: _panelDecoration(palette, 20),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, color: palette.textSecondary, size: 44),
            const SizedBox(height: 10),
            Text('No hay pagos para mostrar', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Ajusta el periodo o los filtros. También puedes registrar un pago sobre una cuenta pendiente.', textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(children: _visiblePage.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _paymentCard(item, palette))).toList(growable: false));
        }
        return _paymentTable(palette);
      },
    );
  }

  Widget _paymentTable(AppPalette palette) {
    return Container(
      decoration: _panelDecoration(palette, 18),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Mesa / cuenta')),
            DataColumn(label: Text('Medio')),
            DataColumn(label: Text('Valor'), numeric: true),
            DataColumn(label: Text('Recibido'), numeric: true),
            DataColumn(label: Text('Cambio'), numeric: true),
            DataColumn(label: Text('Registrado por')),
            DataColumn(label: Text('')),
          ],
          rows: _visiblePage.map((item) {
            return DataRow(
              onSelectChanged: (_) => _showPaymentDetail(item),
              cells: [
                DataCell(Text(_formatDate(item.date))),
                DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.originLabel, style: const TextStyle(fontWeight: FontWeight.w900)), Text('Cuenta ${item.accountNumber ?? '-'} · Venta ${item.saleId ?? '-'}', style: TextStyle(color: palette.textSecondary, fontSize: 11))])),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [Icon(_methodIcon(item.methodName), size: 17, color: palette.secondary), const SizedBox(width: 6), Text(item.methodName)])),
                DataCell(Text(_currency.format(item.amount), style: const TextStyle(fontWeight: FontWeight.w900))),
                DataCell(Text(item.valueReceived == null ? '-' : _currency.format(item.valueReceived))),
                DataCell(Text(item.change == null ? '-' : _currency.format(item.change))),
                DataCell(SizedBox(width: 150, child: Text(item.registeredBy.isEmpty ? '-' : item.registeredBy, maxLines: 1, overflow: TextOverflow.ellipsis))),
                DataCell(IconButton(onPressed: () => _showPaymentDetail(item), tooltip: 'Ver detalle', icon: const Icon(Icons.visibility_rounded, size: 19))),
              ],
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  Widget _paymentCard(_PaymentAdmin item, AppPalette palette) {
    return Material(
      color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: palette.cardBorder)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showPaymentDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(11)), child: Icon(_methodIcon(item.methodName), color: palette.secondary, size: 19)),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.methodName, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)), Text(_formatDate(item.date), style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))])),
                  Text(_currency.format(item.amount), style: TextStyle(color: palette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: _miniInfo('Origen', item.originLabel, palette)), Expanded(child: _miniInfo('Cuenta', '${item.accountNumber ?? '-'}', palette)), Expanded(child: _miniInfo('Saldo', _currency.format(item.accountBalance), palette))]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String value, AppPalette palette) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.w900))]);
  }

  Widget _pagination(AppPalette palette) {
    final total = _filtered.length;
    final pages = (total / _pageSize).ceil();
    final current = _page.clamp(0, pages - 1).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _panelDecoration(palette, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('${current * _pageSize + 1}-${((current + 1) * _pageSize).clamp(0, total)} de $total', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 8),
          IconButton(onPressed: current == 0 ? null : () => setState(() => _page = current - 1), icon: const Icon(Icons.chevron_left_rounded)),
          Text('${current + 1}/$pages', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 12)),
          IconButton(onPressed: current >= pages - 1 ? null : () => setState(() => _page = current + 1), icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }

  Widget _errorPanel(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(palette, 20),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 44),
          const SizedBox(height: 10),
          Text('No fue posible cargar los pagos', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 5),
          Text(_error ?? '', textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
        ],
      ),
    );
  }

  Future<void> _showRegisterSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (sheetContext) => _PaymentFormSheet(
        accounts: _pendingAccounts,
        methods: _methods,
        currency: _currency,
        onSubmit: (body) async {
          await ref.read(apiClientProvider).post<Map<String, dynamic>>(
                ApiPaths.pagos,
                body,
                (json) => Map<String, dynamic>.from(json as Map),
              );
        },
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago registrado correctamente')));
      await _loadData();
    }
  }

  Future<void> _showPaymentDetail(_PaymentAdmin payment) async {
    final palette = ref.read(selectedAppPaletteProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 18 + MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(_methodIcon(payment.methodName), color: palette.secondary, size: 21)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Pago #${payment.id}', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)), Text(_formatDate(payment.date), style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12))])),
                    IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                _detailAmount(payment, palette),
                const SizedBox(height: 10),
                _detailSection('Operación', Icons.table_restaurant_rounded, palette, [
                  _DetailItem('Origen', payment.originLabel),
                  _DetailItem('Cuenta', '${payment.accountNumber ?? '-'}'),
                  _DetailItem('Venta', '#${payment.saleId ?? '-'}'),
                  _DetailItem('Estado venta', payment.saleState.isEmpty ? '-' : payment.saleState),
                ]),
                const SizedBox(height: 10),
                _detailSection('Pago', Icons.receipt_long_rounded, palette, [
                  _DetailItem('Medio', payment.methodName),
                  _DetailItem('Monto aplicado', _currency.format(payment.amount)),
                  _DetailItem('Valor recibido', payment.valueReceived == null ? '-' : _currency.format(payment.valueReceived)),
                  _DetailItem('Cambio', payment.change == null ? '-' : _currency.format(payment.change)),
                  _DetailItem('Referencia', payment.observation?.toStringAsFixed(0) ?? '-'),
                  _DetailItem('Registrado por', payment.registeredBy.isEmpty ? '-' : payment.registeredBy),
                ]),
                const SizedBox(height: 10),
                _detailSection('Estado de la cuenta', Icons.account_balance_wallet_outlined, palette, [
                  _DetailItem('Total cuenta', _currency.format(payment.accountTotal)),
                  _DetailItem('Total pagado', _currency.format(payment.accountPaid)),
                  _DetailItem('Saldo pendiente', _currency.format(payment.accountBalance)),
                  _DetailItem('Propina incluida', _currency.format(payment.accountTip)),
                ]),
                if (payment.saleState.trim().toUpperCase() == 'FINALIZADA' && payment.id != null) ...[
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Future.microtask(() => _showEditPaymentDistribution(payment));
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Modificar importe o dividir pagos'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Corrige el medio, edita los importes o divide esta cuenta entre varios medios. El total cobrado, los productos y la propina no cambian. La modificación queda auditada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditPaymentDistribution(_PaymentAdmin payment) async {
    final accountId = payment.accountId;
    if (accountId == null || !mounted) return;
    try {
      final response = await ref.read(apiClientProvider).get<List<Map<String, dynamic>>>(
        '${ApiPaths.pagos}/cuentas/$accountId/distribucion',
        (json) => (json as List? ?? const [])
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList(growable: false),
      );
      if (!mounted) return;
      final lines = response.data ?? const <Map<String, dynamic>>[];
      if (lines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La cuenta no tiene pagos para corregir.')),
        );
        return;
      }
      final decision = await showDialog<_PaymentSplitDecision>(
        context: context,
        builder: (_) => _PaymentSplitDialog(
          accountId: accountId,
          total: payment.accountTotal,
          methods: _methods,
          existing: lines,
        ),
      );
      if (decision == null || !mounted) return;
      await ref.read(apiClientProvider).put<Map<String, dynamic>>(
        '${ApiPaths.pagos}/cuentas/$accountId/distribucion',
        {
          'pagos': decision.payments,
          'justificacion': decision.reason,
        },
        (json) => Map<String, dynamic>.from(json as Map),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Distribución actualizada: '
            '${decision.payments.length} pagos. '
            'Verifica nuevamente el cierre de caja de ese día.')),
      );
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'No se pudo actualizar el pago: ${ErrorMapper.map(error).message}')),
      );
    }
  }

  Future<void> _showCorrectPaymentMethod(_PaymentAdmin payment) async {
    final paymentId = payment.id;
    if (paymentId == null) return;
    final methods = _methods.where((method) => method.id != null && method.id != payment.methodId).toList(growable: false);
    if (methods.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay otro medio de pago activo disponible para realizar la corrección.')),
        );
      }
      return;
    }

    final selected = await showModalBottomSheet<_PaymentMethod>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (sheetContext) {
        final palette = ref.read(selectedAppPaletteProvider);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: palette.secondary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.swap_horiz_rounded, color: palette.secondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Corregir medio de pago', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
                        Text(
                          'Actual: ${payment.methodName} · ${_currency.format(payment.amount)}',
                          style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: Column(
                    children: methods
                        .map(
                          (method) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: palette.background.withOpacity(palette.darkBackground ? 0.50 : 0.70),
                              borderRadius: BorderRadius.circular(14),
                              child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                leading: Icon(_methodIcon(method.name), color: palette.secondary),
                                title: Text(method.name, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900)),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => Navigator.pop(sheetContext, method),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'La corrección queda auditada. Si esta venta ya fue incluida en un cierre de caja, el sistema no permitirá modificarla.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
    if (selected?.id == null || !mounted) return;

    try {
      await ref.read(apiClientProvider).put<Map<String, dynamic>>(
            ApiPaths.pagoCambiarMedioPago(paymentId),
            {'medioPagoId': selected!.id},
            (json) => Map<String, dynamic>.from(json as Map),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Medio de pago cambiado de ${payment.methodName} a ${selected.name}.')),
      );
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMapper.map(error).message)));
    }
  }

  Widget _detailAmount(_PaymentAdmin payment, AppPalette palette) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: palette.secondary.withOpacity(0.09), borderRadius: BorderRadius.circular(17), border: Border.all(color: palette.secondary.withOpacity(0.20))),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Valor aplicado', style: TextStyle(color: palette.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)), Text(_currency.format(payment.amount), style: TextStyle(color: palette.textPrimary, fontSize: 24, fontWeight: FontWeight.w900))])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(999)), child: Text(payment.methodName, style: TextStyle(color: palette.secondary, fontWeight: FontWeight.w900, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _detailSection(String title, IconData icon, AppPalette palette, List<_DetailItem> items) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: palette.background.withOpacity(0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Icon(icon, color: palette.secondary, size: 19), const SizedBox(width: 7), Text(title, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 14))]),
          const SizedBox(height: 9),
          ...items.map((item) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 128, child: Text(item.label, style: TextStyle(color: palette.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700))), Expanded(child: Text(item.value, style: TextStyle(color: palette.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800)))]))),
        ],
      ),
    );
  }

  Future<void> _showPeriodSheet() async {
    final result = await showModalBottomSheet<_PeriodResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (sheetContext) => _PeriodSheet(start: _start, endExclusive: _endExclusive, currentLabel: _periodLabel),
    );
    if (result == null || !mounted) return;
    setState(() {
      _start = result.start;
      _endExclusive = result.endExclusive;
      _periodLabel = result.label;
      _page = 0;
    });
    await _loadData();
  }

  void _setToday({bool notify = true}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    if (notify) {
      setState(() {
        _start = start;
        _endExclusive = start.add(const Duration(days: 1));
        _periodLabel = 'Hoy';
      });
    } else {
      _start = start;
      _endExclusive = start.add(const Duration(days: 1));
      _periodLabel = 'Hoy';
    }
  }

  BoxDecoration _panelDecoration(AppPalette palette, double radius) => BoxDecoration(
        color: palette.surface.withOpacity(palette.darkBackground ? 0.95 : 0.99),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [BoxShadow(color: palette.cardShadow.withOpacity(0.7), blurRadius: 12, offset: const Offset(0, 5))],
      );

  String _formatDate(DateTime? value) => value == null ? '-' : _dateTime.format(value.toLocal());

  IconData _methodIcon(String name) {
    final normalized = name.toUpperCase();
    if (normalized.contains('EFECTIVO') || normalized.contains('CASH')) return Icons.payments_outlined;
    if (normalized.contains('NEQUI') || normalized.contains('DAVIPLATA') || normalized.contains('QR')) return Icons.qr_code_2_rounded;
    if (normalized.contains('TARJETA') || normalized.contains('CARD')) return Icons.credit_card_rounded;
    if (normalized.contains('TRANSFER')) return Icons.account_balance_rounded;
    return Icons.account_balance_wallet_outlined;
  }
}

class _PaymentFormSheet extends StatefulWidget {
  const _PaymentFormSheet({required this.accounts, required this.methods, required this.currency, required this.onSubmit});

  final List<_PendingAccount> accounts;
  final List<_PaymentMethod> methods;
  final NumberFormat currency;
  final Future<void> Function(Map<String, dynamic> body) onSubmit;

  @override
  State<_PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends State<_PaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _received = TextEditingController();
  final _reference = TextEditingController();
  int? _accountId;
  int? _methodId;
  bool _saving = false;
  String? _error;

  _PendingAccount? get _account {
    for (final item in widget.accounts) {
      if (item.id == _accountId) return item;
    }
    return null;
  }

  _PaymentMethod? get _method {
    for (final item in widget.methods) {
      if (item.id == _methodId) return item;
    }
    return null;
  }

  bool get _isCash => _method?.isCash ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.length == 1) {
      final account = widget.accounts.first;
      _accountId = account.id;
      _amount.text = account.balance.toStringAsFixed(0);
      _received.text = account.balance.toStringAsFixed(0);
    }
    if (widget.methods.length == 1) {
      _methodId = widget.methods.first.id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _received.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final account = _account;
    final amount = _parseMoney(_amount.text);
    final received = _parseMoney(_received.text);
    final change = _isCash ? (received - amount).clamp(0, double.infinity) : 0.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: palette.secondaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.add_card_rounded, color: palette.secondary, size: 21)),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Registrar pago', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), Text('Selecciona una cuenta pendiente y el medio utilizado.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))])),
                  IconButton(onPressed: _saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                value: _accountId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Cuenta pendiente', prefixIcon: Icon(Icons.table_restaurant_rounded)),
                items: widget.accounts.map((item) => DropdownMenuItem<int>(value: item.id, child: Text('${item.originLabel} · Cuenta ${item.accountNumber} · ${widget.currency.format(item.balance)}', overflow: TextOverflow.ellipsis))).toList(growable: false),
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _accountId = value;
                          final selected = _account;
                          if (selected != null) {
                            _amount.text = selected.balance.toStringAsFixed(0);
                            _received.text = selected.balance.toStringAsFixed(0);
                          }
                        });
                      },
                validator: (value) => value == null ? 'Selecciona la cuenta' : null,
              ),
              if (account != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: palette.secondaryContainer.withOpacity(0.55), borderRadius: BorderRadius.circular(15)),
                  child: Row(children: [Expanded(child: _sheetMetric('Total', widget.currency.format(account.total))), Expanded(child: _sheetMetric('Pagado', widget.currency.format(account.paid))), Expanded(child: _sheetMetric('Saldo', widget.currency.format(account.balance), strong: true))]),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _methodId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Medio de pago', prefixIcon: Icon(Icons.credit_card_rounded)),
                items: widget.methods.map((item) => DropdownMenuItem<int>(value: item.id, child: Text(item.name, overflow: TextOverflow.ellipsis))).toList(growable: false),
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                          _methodId = value;
                          if (_isCash) {
                            if (_received.text.trim().isEmpty) _received.text = _amount.text;
                          } else {
                            _received.clear();
                          }
                        }),
                validator: (value) => value == null ? 'Selecciona el medio de pago' : null,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack = constraints.maxWidth < 520;
                  final amountField = TextFormField(
                    controller: _amount,
                    enabled: !_saving,
                    inputFormatters: InputConstraints.decimalFormatters(integerDigits: 20, fractionDigits: 0),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Valor aplicado', prefixText: r'$ ', prefixIcon: Icon(Icons.attach_money_rounded)),
                    validator: (_) {
                      final value = _parseMoney(_amount.text);
                      if (value <= 0) return 'Ingresa un valor válido';
                      if (account != null && value > account.balance + 0.01) return 'Supera el saldo pendiente';
                      return null;
                    },
                  );
                  final referenceField = TextFormField(
                    controller: _reference,
                    enabled: !_saving,
                    maxLength: 30,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    inputFormatters: InputConstraints.digitsFormatters(30),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Número de referencia (opcional)', prefixIcon: Icon(Icons.numbers_rounded)),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isNotEmpty && double.tryParse(text) == null) return 'Ingresa una referencia numérica';
                      return null;
                    },
                  );
                  if (stack) return Column(children: [amountField, const SizedBox(height: 10), referenceField]);
                  return Row(children: [Expanded(child: amountField), const SizedBox(width: 10), Expanded(child: referenceField)]);
                },
              ),
              if (_isCash) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _received,
                  enabled: !_saving,
                  inputFormatters: InputConstraints.decimalFormatters(integerDigits: 18, fractionDigits: 2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: 'Valor recibido', prefixText: r'$ ', prefixIcon: const Icon(Icons.payments_rounded), suffixText: 'Cambio ${widget.currency.format(change)}'),
                  validator: (_) {
                    final value = _parseMoney(_received.text);
                    if (value < _parseMoney(_amount.text)) return 'El valor recibido no puede ser menor';
                    return null;
                  },
                ),
              ],
              if (account != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    ActionChip(label: const Text('Saldo completo'), onPressed: _saving ? null : () => _setAmount(account.balance)),
                    ActionChip(label: const Text('50 %'), onPressed: _saving ? null : () => _setAmount(account.balance / 2)),
                    ActionChip(label: const Text(r'$20.000'), onPressed: _saving ? null : () => _setAmount(20000 > account.balance ? account.balance : 20000)),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(14)), child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800))),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cancel = OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar'));
                  final save = AppButton(label: 'Registrar pago', icon: Icons.check_rounded, compact: true, loading: _saving, onPressed: _save);
                  if (constraints.maxWidth < 480) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [cancel, const SizedBox(height: 8), save]);
                  return Row(mainAxisAlignment: MainAxisAlignment.end, children: [SizedBox(width: 120, child: cancel), const SizedBox(width: 8), SizedBox(width: 165, child: save)]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetMetric(String label, String value, {bool strong = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: strong ? 15 : 13, fontWeight: FontWeight.w900))]);
  }

  void _setAmount(double value) {
    setState(() {
      _amount.text = value.toStringAsFixed(0);
      if (_isCash) _received.text = value.toStringAsFixed(0);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final amount = _parseMoney(_amount.text);
      final body = <String, dynamic>{
        'cuveId': _accountId,
        'mepaId': _methodId,
        'pacvMonto': amount,
        'pacvObservacion': _reference.text.trim().isEmpty ? null : double.tryParse(_reference.text.trim()),
        if (_isCash) 'pacvValorRecibido': _parseMoney(_received.text),
      };
      await widget.onSubmit(body);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = ErrorMapper.map(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double _parseMoney(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9,.-]'), '').replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }
}

class _PeriodSheet extends StatefulWidget {
  const _PeriodSheet({required this.start, required this.endExclusive, required this.currentLabel});
  final DateTime start;
  final DateTime endExclusive;
  final String currentLabel;

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late DateTime _start;
  late DateTime _end;
  late String _label;

  @override
  void initState() {
    super.initState();
    _start = widget.start;
    _end = widget.endExclusive.subtract(const Duration(days: 1));
    _label = widget.currentLabel;
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy', 'es_CO');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [const Expanded(child: Text('Periodo de consulta', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _quick('Hoy', 0),
              _quick('Ayer', -1),
              _quick('Últimos 7 días', -6),
              _quick('Últimos 30 días', -29),
              ActionChip(label: const Text('Este mes'), onPressed: _thisMonth),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _dateTile('Desde', date.format(_start), () => _pickDate(true))),
              const SizedBox(width: 8),
              Expanded(child: _dateTile('Hasta', date.format(_end), () => _pickDate(false))),
            ],
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [SizedBox(width: 120, child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))), const SizedBox(width: 8), SizedBox(width: 150, child: FilledButton.icon(onPressed: _apply, icon: const Icon(Icons.check_rounded), label: const Text('Aplicar')))]),
        ],
      ),
    );
  }

  Widget _quick(String label, int startOffset) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        final today = DateTime.now();
        final base = DateTime(today.year, today.month, today.day);
        setState(() {
          if (startOffset == -1) {
            _start = base.subtract(const Duration(days: 1));
            _end = _start;
          } else {
            _start = base.add(Duration(days: startOffset));
            _end = base;
          }
          _label = label;
        });
      },
    );
  }

  void _thisMonth() {
    final now = DateTime.now();
    setState(() {
      _start = DateTime(now.year, now.month, 1);
      _end = DateTime(now.year, now.month, now.day);
      _label = 'Este mes';
    });
  }

  Widget _dateTile(String label, String value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today_rounded)), child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
    );
  }

  Future<void> _pickDate(bool start) async {
    final selected = await showDatePicker(context: context, initialDate: start ? _start : _end, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (selected == null) return;
    setState(() {
      if (start) {
        _start = selected;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = selected;
        if (_end.isBefore(_start)) _start = _end;
      }
      _label = 'Personalizado';
    });
  }

  void _apply() {
    Navigator.pop(context, _PeriodResult(_start, _end.add(const Duration(days: 1)), _label));
  }
}

class _PaymentSplitDecision {
  const _PaymentSplitDecision(this.payments, this.reason);
  final List<Map<String, dynamic>> payments;
  final String reason;
}

class _PaymentSplitEntry {
  _PaymentSplitEntry(this.methodId, double value)
      : controller = TextEditingController(text: value.toStringAsFixed(0));
  int? methodId;
  final TextEditingController controller;
  void dispose() => controller.dispose();
}

class _PaymentSplitDialog extends StatefulWidget {
  const _PaymentSplitDialog({
    required this.accountId,
    required this.total,
    required this.methods,
    required this.existing,
  });
  final int accountId;
  final double total;
  final List<_PaymentMethod> methods;
  final List<Map<String, dynamic>> existing;

  @override
  State<_PaymentSplitDialog> createState() => _PaymentSplitDialogState();
}

class _PaymentSplitDialogState extends State<_PaymentSplitDialog> {
  final TextEditingController _reason = TextEditingController();
  final List<_PaymentSplitEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    for (final raw in widget.existing) {
      final amount = (raw['valor'] as num?)?.toDouble() ?? 0;
      _entries.add(_PaymentSplitEntry((raw['medioPagoId'] as num?)?.toInt(), amount));
    }
    if (_entries.isEmpty) _entries.add(_PaymentSplitEntry(null, widget.total));
  }

  @override
  void dispose() {
    _reason.dispose();
    for (final row in _entries) {
      row.dispose();
    }
    super.dispose();
  }

  double _parse(String raw) {
    String normalized = raw.trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (normalized.contains(',')) {
      normalized = normalized.replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(normalized)) {
      normalized = normalized.replaceAll('.', '');
    }
    return double.tryParse(normalized) ?? double.nan;
  }

  void _confirm() {
    if (_reason.text.trim().isEmpty || _reason.text.trim().length > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indica una justificación de máximo 300 caracteres.')));
      return;
    }
    final payments = <Map<String, dynamic>>[];
    var totalCents = 0;
    for (final entry in _entries) {
      final amount = _parse(entry.controller.text);
      if (entry.methodId == null || !amount.isFinite || amount <= 0 ||
          (amount * 100 - (amount * 100).round()).abs() > 0.001) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos los pagos deben tener medio e importe válido.')),
        );
        return;
      }
      totalCents += (amount * 100).round();
      payments.add({
        'medioPagoId': entry.methodId,
        'valor': double.parse(amount.toStringAsFixed(2)),
      });
    }
    if (totalCents != (widget.total * 100).round()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('La suma debe ser igual a la cuenta: '
            '${widget.total.toStringAsFixed(2)}. '
            'Suma ingresada: ${(totalCents / 100).toStringAsFixed(2)}.'),
      ));
      return;
    }
    Navigator.of(context).pop(_PaymentSplitDecision(payments, _reason.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final amount = _entries.fold<double>(0, (sum, row) {
      final value = _parse(row.controller.text);
      return sum + (value.isFinite ? value : 0);
    });
    final matched = (amount - widget.total).abs() < .005;
    return AlertDialog(
      title: Text('Editar pagos · Cuenta #${widget.accountId}'),
      content: SizedBox(
        width: 540,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.65,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Puedes modificar el medio, cambiar la cantidad '
                    'de cada abono o dividir el pago entre Nequi, DaviPlata, '
                    'efectivo, tarjeta o transferencia.'),
                const SizedBox(height: 8),
                const Text('Se conserva el valor total de la venta y la propina. '
                    'Se registra un historial de cambios y se recalcula el cierre '
                    'si esta venta ya estaba incluida en uno.'),
                const SizedBox(height: 14),
                for (var i = 0; i < _entries.length; i++) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: widget.methods.any((m) => m.id == _entries[i].methodId)
                              ? _entries[i].methodId : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Medio de pago'),
                          items: [
                            for (final method in widget.methods)
                              if (method.id != null)
                                DropdownMenuItem(value: method.id, child: Text(method.name)),
                          ],
                          onChanged: (value) => setState(() => _entries[i].methodId = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _entries[i].controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Valor',
                            prefixText: r'$ ',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Eliminar esta división',
                        onPressed: _entries.length > 1 ? () => setState(() {
                          _entries.removeAt(i).dispose();
                        }) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: _entries.length >= 20 ? null : () => setState(() {
                    _entries.add(_PaymentSplitEntry(null, 0));
                  }),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar otro medio de pago'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Suma: ${amount.toStringAsFixed(2)} / '
                  '${widget.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: matched ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reason,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo obligatorio de la corrección',
                    hintText: 'Ejemplo: el cliente pagó una parte por Nequi y otra en efectivo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: matched ? _confirm : null,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Guardar distribución'),
        ),
      ],
    );
  }
}

class _PaymentAdmin {
  const _PaymentAdmin({required this.id, required this.accountId, required this.accountNumber, required this.accountDescription, required this.saleId, required this.saleState, required this.saleType, required this.tableNumber, required this.methodId, required this.methodName, required this.amount, required this.valueReceived, required this.change, required this.observation, required this.registeredBy, required this.date, required this.accountTotal, required this.accountTip, required this.accountPaid, required this.accountBalance});

  final int? id;
  final int? accountId;
  final int? accountNumber;
  final String accountDescription;
  final int? saleId;
  final String saleState;
  final String saleType;
  final int? tableNumber;
  final int? methodId;
  final String methodName;
  final double amount;
  final double? valueReceived;
  final double? change;
  final double? observation;
  final String registeredBy;
  final DateTime? date;
  final double accountTotal;
  final double accountTip;
  final double accountPaid;
  final double accountBalance;

  bool get isCash {
    final value = methodName.toUpperCase();
    return value.contains('EFECTIVO') || value.contains('CASH');
  }

  bool get isDirectSale => saleType.toUpperCase() == 'DIRECTA' || tableNumber == null;
  String get originLabel => isDirectSale ? 'Venta directa' : 'Mesa ${tableNumber ?? '-'}';

  factory _PaymentAdmin.fromJson(Map<String, dynamic> json) => _PaymentAdmin(
        id: (json['pacvId'] as num?)?.toInt(),
        accountId: (json['cuveId'] as num?)?.toInt(),
        accountNumber: (json['cuentaNumero'] as num?)?.toInt(),
        accountDescription: json['cuentaDescripcion']?.toString() ?? '',
        saleId: (json['ventId'] as num?)?.toInt(),
        saleState: json['ventaEstado']?.toString() ?? '',
        saleType: json['tipoVenta']?.toString() ?? '',
        tableNumber: (json['mesaNumero'] as num?)?.toInt(),
        methodId: (json['mepaId'] as num?)?.toInt(),
        methodName: json['medioPagoNombre']?.toString() ?? 'Medio de pago',
        amount: (json['monto'] as num?)?.toDouble() ?? 0,
        valueReceived: (json['valorRecibido'] as num?)?.toDouble(),
        change: (json['cambio'] as num?)?.toDouble(),
        observation: (json['observacion'] as num?)?.toDouble(),
        registeredBy: json['registradoPor']?.toString() ?? '',
        date: DateTime.tryParse(json['fecha']?.toString() ?? ''),
        accountTotal: (json['cuentaTotal'] as num?)?.toDouble() ?? 0,
        accountTip: (json['cuentaPropina'] as num?)?.toDouble() ?? 0,
        accountPaid: (json['cuentaPagado'] as num?)?.toDouble() ?? 0,
        accountBalance: (json['cuentaSaldo'] as num?)?.toDouble() ?? 0,
      );
}

class _PendingAccount {
  const _PendingAccount({required this.id, required this.saleId, required this.saleType, required this.tableNumber, required this.accountNumber, required this.description, required this.total, required this.paid, required this.balance, required this.responsible, required this.saleDate});
  final int? id;
  final int? saleId;
  final String saleType;
  final int? tableNumber;
  final int? accountNumber;
  final String description;
  final double total;
  final double paid;
  final double balance;
  final String responsible;
  final DateTime? saleDate;

  bool get isDirectSale => saleType.toUpperCase() == 'DIRECTA' || tableNumber == null;
  String get originLabel => isDirectSale ? 'Venta directa' : 'Mesa ${tableNumber ?? '-'}';

  factory _PendingAccount.fromJson(Map<String, dynamic> json) => _PendingAccount(
        id: (json['cuveId'] as num?)?.toInt(),
        saleId: (json['ventId'] as num?)?.toInt(),
        saleType: json['tipoVenta']?.toString() ?? '',
        tableNumber: (json['mesaNumero'] as num?)?.toInt(),
        accountNumber: (json['cuentaNumero'] as num?)?.toInt(),
        description: json['cuentaDescripcion']?.toString() ?? '',
        total: (json['cuentaTotal'] as num?)?.toDouble() ?? 0,
        paid: (json['totalPagado'] as num?)?.toDouble() ?? 0,
        balance: (json['saldoPendiente'] as num?)?.toDouble() ?? 0,
        responsible: json['responsable']?.toString() ?? '',
        saleDate: DateTime.tryParse(json['ventaFecha']?.toString() ?? ''),
      );
}

class _PaymentMethod {
  const _PaymentMethod(this.id, this.name, this.active);
  final int? id;
  final String name;
  final bool active;

  bool get isCash {
    final value = name.toUpperCase();
    return value.contains('EFECTIVO') || value.contains('CASH');
  }

  factory _PaymentMethod.fromJson(Map<String, dynamic> json) => _PaymentMethod(
        (json['mepaId'] as num?)?.toInt(),
        json['mepaNombre']?.toString() ?? 'Medio de pago',
        (json['mepaEstado'] as num?)?.toInt() != 0,
      );
}

class _PaymentMetric {
  const _PaymentMetric(this.icon, this.label, this.value, this.caption);
  final IconData icon;
  final String label;
  final String value;
  final String caption;
}

class _DetailItem {
  const _DetailItem(this.label, this.value);
  final String label;
  final String value;
}

class _PeriodResult {
  const _PeriodResult(this.start, this.endExclusive, this.label);
  final DateTime start;
  final DateTime endExclusive;
  final String label;
}
