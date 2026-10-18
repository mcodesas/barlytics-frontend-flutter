import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../providers/business_setup_provider.dart';

/// Marco mínimo para las pantallas que se abren desde la puesta en marcha.
///
/// El contenido conserva la pantalla real del módulo y únicamente agrega una
/// referencia discreta al paso actual. No muestra navegación operativa, logo,
/// tarjetas externas ni marcos que hagan sentir que hay una página dentro de
/// otra página.
class BusinessSetupFlowShell extends ConsumerWidget {
  const BusinessSetupFlowShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final info = _sectionFor(location);
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            _MinimalSetupHeader(info: info, compact: compact),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _MinimalSetupHeader extends ConsumerWidget {
  const _MinimalSetupHeader({
    required this.info,
    required this.compact,
  });

  final _SetupSectionInfo info;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    final stepLabel = info.requiredStep
        ? Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 15,
              vertical: compact ? 8 : 9,
            ),
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: compact ? 16 : 17,
                  color: palette.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Paso ${info.stepNumber}',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'de 5',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                _MiniStepProgress(currentStep: info.stepNumber),
              ],
            ),
          )
        : Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 15,
              vertical: compact ? 8 : 9,
            ),
            decoration: BoxDecoration(
              color: palette.secondary.withOpacity(.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Puesta en marcha',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: compact ? 14 : 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          );

    final backButton = TextButton.icon(
      onPressed: () {
        // Cualquier pantalla del flujo guiado puede haber cambiado datos que
        // afectan la puesta en marcha. Invalidamos el estado antes de volver
        // para que el asistente consulte nuevamente el backend y no muestre
        // información anterior (por ejemplo, productos recién creados).
        ref.invalidate(businessSetupStatusProvider);
        ref.read(businessSetupGuidedModeProvider.notifier).state = false;
        context.go('/configurar-negocio');
      },
      style: TextButton.styleFrom(
        foregroundColor: palette.secondary,
        backgroundColor: palette.secondary.withOpacity(.08),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 15,
          vertical: compact ? 9 : 10,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: const StadiumBorder(),
      ),
      icon: Icon(
        Icons.arrow_back_rounded,
        size: compact ? 17 : 18,
      ),
      label: Text(
        compact ? 'Volver' : 'Volver a la puesta en marcha',
        style: TextStyle(
          fontSize: compact ? 12.5 : 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 22,
        compact ? 10 : 12,
        compact ? 12 : 22,
        compact ? 8 : 10,
      ),
      child: Row(
        children: [
          stepLabel,
          const Spacer(),
          backButton,
        ],
      ),
    );
  }
}

class _MiniStepProgress extends ConsumerWidget {
  const _MiniStepProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final step = index + 1;
        final active = step <= currentStep;
        return Container(
          width: step == currentStep ? 14 : 6,
          height: 6,
          margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
          decoration: BoxDecoration(
            color: active
                ? palette.secondary.withOpacity(step == currentStep ? .95 : .48)
                : palette.textSecondary.withOpacity(.18),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _SetupSectionInfo {
  const _SetupSectionInfo({
    this.stepNumber = 0,
    this.requiredStep = false,
  });

  final int stepNumber;
  final bool requiredStep;
}

_SetupSectionInfo _sectionFor(String location) {
  // Paso 1: datos generales del negocio.
  if (_startsWithAny(location, const [
    '/profile',
    '/empresas',
    '/tipos_identificacion',
  ])) {
    return const _SetupSectionInfo(stepNumber: 1, requiredStep: true);
  }

  // Paso 2: sucursales y catálogos auxiliares usados por la sede.
  if (_startsWithAny(location, const [
    '/sucursales',
    '/paises',
    '/regiones',
    '/ciudades',
    '/zonas_horarias',
    '/monedas',
  ])) {
    return const _SetupSectionInfo(stepNumber: 2, requiredStep: true);
  }

  // Paso 3: medios de pago.
  if (location.startsWith('/medios_pago')) {
    return const _SetupSectionInfo(stepNumber: 3, requiredStep: true);
  }

  // Paso 4: Administración de productos y pantallas relacionadas.
  if (_startsWithAny(location, const [
    '/productos',
    '/precios',
    '/marcas',
    '/tipos_producto',
  ])) {
    return const _SetupSectionInfo(stepNumber: 4, requiredStep: true);
  }

  // Paso 5: parámetros operativos de pedidos.
  if (_startsWithAny(location, const [
    '/parametros-operativos',
    '/parametros',
  ])) {
    return const _SetupSectionInfo(stepNumber: 5, requiredStep: true);
  }

  // Las funciones se definen antes de crear cuentas para el equipo.
  if (location.startsWith('/roles_personalizados')) {
    return const _SetupSectionInfo(stepNumber: 6, requiredStep: true);
  }

  // Los usuarios se crean después de definir sus permisos.
  if (location.startsWith('/usuarios')) {
    return const _SetupSectionInfo(requiredStep: false);
  }

  return const _SetupSectionInfo();
}

bool _startsWithAny(String value, List<String> prefixes) {
  for (final prefix in prefixes) {
    if (value.startsWith(prefix)) return true;
  }
  return false;
}
