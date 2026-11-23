import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';

enum AdminSupportWorkspaceType {
  clients,
  access,
  operations,
  configuration,
  maintenance,
}

class AdminSupportWorkspacePage extends ConsumerWidget {
  const AdminSupportWorkspacePage({super.key, required this.type});

  final AdminSupportWorkspaceType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final config = _WorkspaceConfig.forType(type);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _WorkspaceHero(config: config, palette: palette),
          const SizedBox(height: 18),
          _WorkspaceSectionTitle(
            title: 'Ruta recomendada',
            subtitle:
                'Sigue estos pasos para resolver el caso con contexto y trazabilidad.',
            icon: Icons.route_rounded,
            palette: palette,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < config.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StepCard(
                index: i + 1,
                step: config.steps[i],
                color: config.color,
                palette: palette,
              ),
            ),
          const SizedBox(height: 10),
          _WorkspaceSectionTitle(
            title: 'Herramientas disponibles',
            subtitle:
                'Usa primero la función especializada y deja el explorador como respaldo técnico.',
            icon: Icons.apps_rounded,
            palette: palette,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050
                  ? 3
                  : constraints.maxWidth >= 620
                      ? 2
                      : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final action in config.actions)
                    SizedBox(
                      width: width,
                      child: _WorkspaceActionCard(
                        action: action,
                        color: config.color,
                        palette: palette,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({required this.config, required this.palette});

  final _WorkspaceConfig config;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: palette.panelDecoration(baseRadius: 25, tint: config.color),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: config.color.withOpacity(.09),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'SOPORTE GUIADO',
                  style: TextStyle(
                    color: config.color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                config.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 7),
              Text(
                config.description,
                style: TextStyle(color: palette.textSecondary, height: 1.42),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final primary in config.primaryActions)
                    FilledButton.icon(
                      onPressed: () => context.go(primary.route),
                      icon: Icon(primary.icon, size: 18),
                      label: Text(primary.title),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                      ),
                    ),
                ],
              ),
            ],
          );
          final icon = Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: config.color.withOpacity(.10),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(config.icon, color: config.color, size: 48),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [icon, const SizedBox(height: 14), content],
            );
          }
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 20),
              icon,
            ],
          );
        },
      ),
    );
  }
}

class _WorkspaceActionCard extends StatelessWidget {
  const _WorkspaceActionCard({
    required this.action,
    required this.color,
    required this.palette,
  });

  final _WorkspaceAction action;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(baseRadius: 18, tint: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(action.icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            action.description,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.go(action.route),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Abrir'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.step,
    required this.color,
    required this.palette,
  });

  final int index;
  final _WorkspaceStep step;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: step.route == null ? null : () => context.go(step.route!),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: palette.panelDecoration(baseRadius: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '$index',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.description,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (step.route != null)
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceSectionTitle extends StatelessWidget {
  const _WorkspaceSectionTitle({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: palette.primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: palette.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkspaceConfig {
  const _WorkspaceConfig({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.primaryActions,
    required this.steps,
    required this.actions,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<_WorkspaceAction> primaryActions;
  final List<_WorkspaceStep> steps;
  final List<_WorkspaceAction> actions;

  static _WorkspaceConfig forType(AdminSupportWorkspaceType type) {
    return switch (type) {
      AdminSupportWorkspaceType.clients => const _WorkspaceConfig(
          title: 'Soporte de clientes y sedes',
          description:
              'Alta, configuración y revisión completa de empresas, sucursales, parámetros y usuarios iniciales.',
          icon: Icons.business_center_rounded,
          color: Color(0xFF2563EB),
          primaryActions: [
            _WorkspaceAction(
              'Nueva empresa',
              'Crear el cliente y su información comercial.',
              Icons.add_business_rounded,
              '/empresas/nuevo',
            ),
            _WorkspaceAction(
              'Nueva sucursal',
              'Configurar una sede operativa.',
              Icons.store_mall_directory_rounded,
              '/sucursales/nuevo',
            ),
          ],
          steps: [
            _WorkspaceStep(
              'Validar la empresa',
              'Revisa identificación, ubicación, estado y logo.',
              '/empresas',
            ),
            _WorkspaceStep(
              'Configurar sucursales',
              'Asigna moneda, zona horaria, ciudad y datos operativos.',
              '/sucursales',
            ),
            _WorkspaceStep(
              'Definir parámetros',
              'Completa valores globales, empresariales y por sucursal.',
              '/parametros',
            ),
            _WorkspaceStep(
              'Crear usuarios iniciales',
              'Asigna empresa, sucursales y roles correctos.',
              '/usuarios/nuevo',
            ),
            _WorkspaceStep(
              'Verificar medios de pago',
              'Activa medios y QR por sucursal.',
              '/medios_pago',
            ),
          ],
          actions: [
            _WorkspaceAction(
              'Empresas',
              'Consulta, crea y modifica cualquier cliente.',
              Icons.business_rounded,
              '/empresas',
            ),
            _WorkspaceAction(
              'Sucursales',
              'Administra sedes y su configuración operativa.',
              Icons.store_rounded,
              '/sucursales',
            ),
            _WorkspaceAction(
              'Parámetros',
              'Valores globales, empresariales y por sede.',
              Icons.tune_rounded,
              '/parametros',
            ),
            _WorkspaceAction(
              'Ciudades y regiones',
              'Catálogos geográficos necesarios para clientes.',
              Icons.location_city_rounded,
              '/ciudades',
            ),
            _WorkspaceAction(
              'Monedas',
              'Monedas disponibles para la operación.',
              Icons.attach_money_rounded,
              '/monedas',
            ),
            _WorkspaceAction(
              'Zonas horarias',
              'Configuración temporal de cada sucursal.',
              Icons.schedule_rounded,
              '/zonas_horarias',
            ),
          ],
        ),
      AdminSupportWorkspaceType.access => const _WorkspaceConfig(
          title: 'Soporte de accesos y permisos',
          description:
              'Recupera accesos, asigna roles, revisa sucursales autorizadas y diagnostica menús o credenciales.',
          icon: Icons.security_rounded,
          color: Color(0xFF7C3AED),
          primaryActions: [
            _WorkspaceAction(
              'Crear usuario',
              'Alta completa con rol y sucursal.',
              Icons.person_add_alt_1_rounded,
              '/usuarios/nuevo',
            ),
            _WorkspaceAction(
              'Crear rol personalizado',
              'Permisos propios por empresa o sucursal.',
              Icons.admin_panel_settings_rounded,
              '/roles_personalizados',
            ),
          ],
          steps: [
            _WorkspaceStep(
              'Buscar el usuario',
              'Confirma empresa, estado, bloqueo y correo.',
              '/usuarios',
            ),
            _WorkspaceStep(
              'Revisar roles',
              'Valida perfiles predefinidos y personalizados asignados.',
              '/roles',
            ),
            _WorkspaceStep(
              'Revisar sucursales',
              'Comprueba el alcance operativo del usuario.',
              '/explorador_datos?table=usuario_sucursal',
            ),
            _WorkspaceStep(
              'Validar menús y permisos',
              'Confirma que el rol tenga las opciones correctas.',
              '/opciones_menu',
            ),
            _WorkspaceStep(
              'Consultar historial de acceso',
              'Identifica intentos fallidos o patrones de bloqueo.',
              '/explorador_datos?table=login_log',
            ),
          ],
          actions: [
            _WorkspaceAction(
              'Usuarios',
              'Crear, modificar, desbloquear y asignar accesos.',
              Icons.manage_accounts_rounded,
              '/usuarios',
            ),
            _WorkspaceAction(
              'Roles',
              'Perfiles predefinidos y estado de cada rol.',
              Icons.shield_outlined,
              '/roles',
            ),
            _WorkspaceAction(
              'Roles personalizados',
              'Permisos específicos por cliente o sede.',
              Icons.badge_rounded,
              '/roles_personalizados',
            ),
            _WorkspaceAction(
              'Menús',
              'Catálogo de funciones visibles.',
              Icons.menu_open_rounded,
              '/menus',
            ),
            _WorkspaceAction(
              'Opciones de menú',
              'Relación entre roles y funcionalidades.',
              Icons.rule_rounded,
              '/opciones_menu',
            ),
            _WorkspaceAction(
              'Historial de accesos',
              'Revisión técnica de inicios de sesión.',
              Icons.login_rounded,
              '/explorador_datos?table=login_log',
            ),
          ],
        ),
      AdminSupportWorkspaceType.operations => const _WorkspaceConfig(
          title: 'Soporte operativo y financiero',
          description:
              'Resuelve novedades de ventas, pagos, mesas, inventario, precios, movimientos y cierres de caja.',
          icon: Icons.analytics_rounded,
          color: Color(0xFF0F766E),
          primaryActions: [
            _WorkspaceAction(
              'Consultar ventas',
              'Revisar operaciones abiertas y cerradas.',
              Icons.point_of_sale_rounded,
              '/ventas',
            ),
            _WorkspaceAction(
              'Administrar pagos',
              'Registrar o consultar recaudos.',
              Icons.payments_rounded,
              '/pagos',
            ),
          ],
          steps: [
            _WorkspaceStep(
              'Identificar la sucursal',
              'Confirma la sede y el periodo de la novedad.',
              '/sucursales',
            ),
            _WorkspaceStep(
              'Revisar la operación',
              'Consulta venta, cuenta, productos y pagos.',
              '/ventas',
            ),
            _WorkspaceStep(
              'Validar inventario',
              'Compara existencias y movimientos relacionados.',
              '/inventario',
            ),
            _WorkspaceStep(
              'Revisar precios',
              'Confirma costo y precio aplicados por sucursal.',
              '/precios',
            ),
            _WorkspaceStep(
              'Ejecutar diagnóstico',
              'Descarta inconsistencias de integridad o secuencias.',
              '/diagnostico_sistema',
            ),
          ],
          actions: [
            _WorkspaceAction(
              'Ventas',
              'Operaciones abiertas, cerradas y anuladas.',
              Icons.point_of_sale_rounded,
              '/ventas',
            ),
            _WorkspaceAction(
              'Cuentas de venta',
              'Consumo, pagos y saldos por cuenta.',
              Icons.receipt_long_rounded,
              '/cuentas_venta',
            ),
            _WorkspaceAction(
              'Pagos',
              'Recaudos, referencias, cambio y pendientes.',
              Icons.payments_rounded,
              '/pagos',
            ),
            _WorkspaceAction(
              'Mesas',
              'Estado operativo y responsables.',
              Icons.table_bar_rounded,
              '/mesas',
            ),
            _WorkspaceAction(
              'Inventario',
              'Existencias, conteos y diferencias.',
              Icons.inventory_2_rounded,
              '/inventario',
            ),
            _WorkspaceAction(
              'Movimientos',
              'Entradas, salidas, ajustes y trazabilidad.',
              Icons.swap_horiz_rounded,
              '/movimientos',
            ),
            _WorkspaceAction(
              'Precios',
              'Costos y precios por sucursal.',
              Icons.price_change_rounded,
              '/precios',
            ),
            _WorkspaceAction(
              'Sincronizar catálogo',
              'Copiar productos y costos entre empresas sin inventario.',
              Icons.sync_alt_rounded,
              '/sincronizar_catalogo',
            ),
            _WorkspaceAction(
              'Cierres de caja',
              'Cruces, gastos y diferencias.',
              Icons.account_balance_wallet_rounded,
              '/explorador_datos?table=cierrecaja',
            ),
            _WorkspaceAction(
              'Diagnóstico',
              'Integridad de ventas, inventario y accesos.',
              Icons.monitor_heart_rounded,
              '/diagnostico_sistema',
            ),
          ],
        ),
      AdminSupportWorkspaceType.configuration => const _WorkspaceConfig(
          title: 'Soporte de configuración y catálogos',
          description:
              'Administra los valores maestros que hacen funcionar cada empresa y sucursal sin editar directamente la base de datos.',
          icon: Icons.tune_rounded,
          color: Color(0xFFB45309),
          primaryActions: [
            _WorkspaceAction(
              'Crear parámetro',
              'Registrar una configuración global o por cliente.',
              Icons.add_circle_outline_rounded,
              '/parametros/nuevo',
            ),
            _WorkspaceAction(
              'Crear medio de pago',
              'Agregar una forma de recaudo.',
              Icons.add_card_rounded,
              '/medios_pago',
            ),
          ],
          steps: [
            _WorkspaceStep(
              'Revisar parámetros',
              'Valida alcance global, empresarial o por sucursal.',
              '/parametros',
            ),
            _WorkspaceStep(
              'Verificar catálogos geográficos',
              'Comprueba país, región y ciudad de las sedes.',
              '/paises',
            ),
            _WorkspaceStep(
              'Revisar moneda y zona horaria',
              'Evita inconsistencias de fechas y valores.',
              '/monedas',
            ),
            _WorkspaceStep(
              'Validar medios de pago',
              'Confirma estado, asignación por sucursal y QR.',
              '/medios_pago',
            ),
            _WorkspaceStep(
              'Revisar menús y tipos maestros',
              'Comprueba las opciones disponibles para la aplicación.',
              '/menus',
            ),
          ],
          actions: [
            _WorkspaceAction(
              'Parámetros',
              'Configuración global, por empresa y por sucursal.',
              Icons.tune_rounded,
              '/parametros',
            ),
            _WorkspaceAction(
              'Medios de pago',
              'Catálogo de formas de recaudo y estado.',
              Icons.payments_rounded,
              '/medios_pago',
            ),
            _WorkspaceAction(
              'Medios por sucursal',
              'Asignaciones, QR y activación por sede.',
              Icons.qr_code_2_rounded,
              '/explorador_datos?table=sucursal_mediopago',
            ),
            _WorkspaceAction(
              'Países, regiones y ciudades',
              'Estructura geográfica usada por los clientes.',
              Icons.public_rounded,
              '/paises',
            ),
            _WorkspaceAction(
              'Monedas',
              'Monedas y símbolos de operación.',
              Icons.attach_money_rounded,
              '/monedas',
            ),
            _WorkspaceAction(
              'Zonas horarias',
              'Fechas y horas correctas por sede.',
              Icons.schedule_rounded,
              '/zonas_horarias',
            ),
            _WorkspaceAction(
              'Tipos de identificación',
              'Documentos disponibles para empresas y usuarios.',
              Icons.badge_outlined,
              '/explorador_datos?table=tipo_identificacion',
            ),
            _WorkspaceAction(
              'Tipos de autenticación',
              'Métodos permitidos para iniciar sesión.',
              Icons.lock_outline_rounded,
              '/explorador_datos?table=tipoautenticacion',
            ),
            _WorkspaceAction(
              'Menús y permisos',
              'Funciones visibles y asignaciones por rol.',
              Icons.menu_open_rounded,
              '/menus',
            ),
          ],
        ),
      AdminSupportWorkspaceType.maintenance => const _WorkspaceConfig(
          title: 'Integridad, auditoría y mantenimiento',
          description:
              'Diagnostica inconsistencias, restaura permisos, sincroniza secuencias y revisa cada intervención administrativa.',
          icon: Icons.sync_rounded,
          color: Color(0xFFBE123C),
          primaryActions: [
            _WorkspaceAction(
              'Ejecutar diagnóstico',
              'Revisar integridad y alertas del sistema.',
              Icons.monitor_heart_rounded,
              '/diagnostico_sistema',
            ),
            _WorkspaceAction(
              'Consultar auditoría',
              'Ver quién modificó qué registro y cuándo.',
              Icons.history_rounded,
              '/auditoria_soporte',
            ),
          ],
          steps: [
            _WorkspaceStep(
              'Ejecutar diagnóstico',
              'Identifica huérfanos, duplicados, bloqueos y datos incompletos.',
              '/diagnostico_sistema',
            ),
            _WorkspaceStep(
              'Abrir la función afectada',
              'Corrige desde su pantalla especializada cuando exista.',
              '/soporte_global',
            ),
            _WorkspaceStep(
              'Usar el explorador con motivo',
              'Crea o corrige registros técnicos con auditoría.',
              '/explorador_datos',
            ),
            _WorkspaceStep(
              'Reparar secuencias o permisos',
              'Aplica únicamente la acción recomendada por el diagnóstico.',
              '/diagnostico_sistema',
            ),
            _WorkspaceStep(
              'Verificar la auditoría',
              'Confirma el resultado y conserva trazabilidad del soporte.',
              '/auditoria_soporte',
            ),
          ],
          actions: [
            _WorkspaceAction(
              'Diagnóstico del sistema',
              'Validaciones de integridad, datos y seguridad.',
              Icons.monitor_heart_rounded,
              '/diagnostico_sistema',
            ),
            _WorkspaceAction(
              'Auditoría de soporte',
              'Registro de creación, edición, eliminación y reparaciones.',
              Icons.history_rounded,
              '/auditoria_soporte',
            ),
            _WorkspaceAction(
              'Moderación de cartas digitales',
              'Revisar denuncias públicas y registrar decisiones.',
              Icons.flag_outlined,
              '/moderacion_contenido',
            ),
            _WorkspaceAction(
              'Explorador de datos',
              'Consulta y corrección avanzada de registros.',
              Icons.storage_rounded,
              '/explorador_datos',
            ),
            _WorkspaceAction(
              'Usuarios bloqueados',
              'Busca, reactiva y corrige accesos.',
              Icons.lock_open_rounded,
              '/usuarios',
            ),
            _WorkspaceAction(
              'Asignaciones usuario–rol',
              'Revisa relaciones técnicas de permisos.',
              Icons.link_rounded,
              '/explorador_datos?table=usuariorol',
            ),
            _WorkspaceAction(
              'Asignaciones usuario–sucursal',
              'Corrige el alcance operativo de los usuarios.',
              Icons.account_tree_outlined,
              '/explorador_datos?table=usuario_sucursal',
            ),
          ],
        ),
    };
  }
}

class _WorkspaceAction {
  const _WorkspaceAction(this.title, this.description, this.icon, this.route);

  final String title;
  final String description;
  final IconData icon;
  final String route;
}

class _WorkspaceStep {
  const _WorkspaceStep(this.title, this.description, this.route);

  final String title;
  final String description;
  final String? route;
}
