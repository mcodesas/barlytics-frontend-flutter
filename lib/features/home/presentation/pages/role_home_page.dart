import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/module_visuals.dart';
import '../../../../core/branch/branch_scope_provider.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../navigation/data/models/user_menu_item.dart';
import '../../../navigation/presentation/providers/user_menu_provider.dart';
import '../../../profile/presentation/providers/profile_header_provider.dart';
import '../../../sucursales/data/models/sucursales_response_model.dart';

class RoleHomePage extends ConsumerStatefulWidget {
  const RoleHomePage({
    super.key,
    required this.items,
    required this.roles,
  });

  final List<UserMenuItem> items;
  final List<String> roles;

  @override
  ConsumerState<RoleHomePage> createState() => _RoleHomePageState();
}

class _RoleHomePageState extends ConsumerState<RoleHomePage> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final branchState = ref.watch(branchScopeProvider);
    final profileAsync = ref.watch(profileHeaderProvider);
    final profile = _RoleHomeProfile.resolve(widget.roles);
    final availableItems = _buildAvailableItems(profile, widget.items);
    final featuredItems = _featuredItems(profile, availableItems);
    final workflow = _workflowFor(profile, availableItems);
    final displayName = profileAsync.maybeWhen(
      data: (value) => value.displayName,
      orElse: () => null,
    );
    final branchName = branchState.activeBranch?.sucuNombre?.trim();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppPageBackground()),
          RefreshIndicator(
            color: palette.secondary,
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _CenteredContent(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _RoleHero(
                        profile: profile,
                        displayName: displayName,
                        branchName: branchName,
                        now: _now,
                        palette: palette,
                        branches: branchState.branches,
                        activeBranchId: branchState.activeBranchId,
                        onSelectBranch: (id) =>
                            ref.read(branchScopeProvider.notifier).select(id),
                        onPrimaryAction: featuredItems.isEmpty
                            ? null
                            : () => context.go(featuredItems.first.path),
                        primaryActionLabel: featuredItems.isEmpty
                            ? null
                            : featuredItems.first.title,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CenteredContent(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _RoleSummaryGrid(
                        palette: palette,
                        roleLabel: profile.label,
                        modulesCount: availableItems.length,
                        branchName: branchName,
                        rolesCount: widget.roles.length,
                      ),
                    ),
                  ),
                ),
                if (workflow.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _CenteredContent(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _RoleSection(
                          title: 'Flujo principal',
                          subtitle: profile.workflowSubtitle,
                          icon: Icons.route_rounded,
                          palette: palette,
                          child: _WorkflowGrid(
                            steps: workflow,
                            palette: palette,
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _CenteredContent(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _RoleSection(
                        title: 'Accesos rápidos',
                        subtitle:
                            'Las funciones más importantes para ${profile.label.toLowerCase()}.',
                        icon: Icons.bolt_rounded,
                        palette: palette,
                        child: featuredItems.isEmpty
                            ? _EmptyModulesCard(palette: palette)
                            : _FeaturedGrid(
                                items: featuredItems,
                                palette: palette,
                              ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _CenteredContent(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 26),
                      child: _RoleSection(
                        title: 'Herramientas autorizadas',
                        subtitle:
                            'Solo se muestran los módulos habilitados para tu usuario.',
                        icon: Icons.dashboard_customize_rounded,
                        palette: palette,
                        child: availableItems.isEmpty
                            ? _EmptyModulesCard(palette: palette)
                            : _AllModulesGrid(
                                items: availableItems,
                                palette: palette,
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

  Future<void> _refresh() async {
    ref.invalidate(userMenuProvider);
    ref.invalidate(profileHeaderProvider);
    await ref.read(branchScopeProvider.notifier).load();
    if (mounted) setState(() => _now = DateTime.now());
  }
}

class _CenteredContent extends StatelessWidget {
  const _CenteredContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: child,
      ),
    );
  }
}

class _RoleHero extends StatelessWidget {
  const _RoleHero({
    required this.profile,
    required this.displayName,
    required this.branchName,
    required this.now,
    required this.palette,
    required this.branches,
    required this.activeBranchId,
    required this.onSelectBranch,
    required this.onPrimaryAction,
    required this.primaryActionLabel,
  });

  final _RoleHomeProfile profile;
  final String? displayName;
  final String? branchName;
  final DateTime now;
  final AppPalette palette;
  final List<SucursalesResponseModel> branches;
  final int? activeBranchId;
  final ValueChanged<int> onSelectBranch;
  final VoidCallback? onPrimaryAction;
  final String? primaryActionLabel;

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingFor(now.hour);
    final name = displayName?.trim();
    final date = DateFormat("EEEE, d 'de' MMMM", 'es').format(now);
    final time = DateFormat('h:mm a', 'es').format(now);
    final accent = Color.lerp(profile.color, palette.secondary, 0.48) ??
        palette.secondary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20 * palette.spacingScale),
      decoration: palette.panelDecoration(
        baseRadius: 30,
        tint: accent,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SoftBadge(
                    icon: profile.icon,
                    label: profile.label,
                    color: accent,
                    palette: palette,
                  ),
                  _SoftBadge(
                    icon: Icons.calendar_today_rounded,
                    label: '${_capitalize(date)} · $time',
                    color: palette.textSecondary,
                    palette: palette,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                name == null || name.isEmpty
                    ? '$greeting, bienvenido'
                    : '$greeting, ${_firstName(name)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.35,
                    ),
              ),
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  profile.subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.42,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (branches.length > 1)
                    PopupMenuButton<int>(
                      initialValue: activeBranchId,
                      tooltip: 'Cambiar sucursal',
                      onSelected: onSelectBranch,
                      itemBuilder: (context) => [
                        for (final branch in branches)
                          if (branch.sucuId != null)
                            PopupMenuItem<int>(
                              value: branch.sucuId!,
                              child: Text(
                                (branch.sucuNombre?.toString().trim().isNotEmpty ??
                                        false)
                                    ? branch.sucuNombre.toString()
                                    : 'Sucursal ${branch.sucuId}',
                              ),
                            ),
                      ],
                      child: _CompactAction(
                        icon: Icons.location_on_rounded,
                        label: branchName?.isNotEmpty == true
                            ? branchName!
                            : 'Seleccionar sucursal',
                        palette: palette,
                        color: accent,
                      ),
                    )
                  else
                    _CompactAction(
                      icon: Icons.location_on_rounded,
                      label: branchName?.isNotEmpty == true
                          ? branchName!
                          : 'Sin sucursal activa',
                      palette: palette,
                      color: accent,
                    ),
                  if (onPrimaryAction != null && primaryActionLabel != null)
                    FilledButton.icon(
                      onPressed: onPrimaryAction,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                      label: Text(primaryActionLabel!),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        backgroundColor: palette.actionColor,
                        foregroundColor: palette.onAction,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );

          final illustration = Container(
            width: compact ? 78 : 112,
            height: compact ? 78 : 112,
            decoration: BoxDecoration(
              color: accent.withOpacity(
                palette.darkBackground ? 0.22 : 0.12,
              ),
              borderRadius: BorderRadius.circular(
                palette.radius(compact ? 24 : 34),
              ),
              border: Border.all(color: accent.withOpacity(0.22)),
            ),
            child: Icon(
              profile.icon,
              color: accent,
              size: compact ? 38 : 54,
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 18),
                illustration,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 28),
              illustration,
            ],
          );
        },
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(palette.darkBackground ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.icon,
    required this.label,
    required this.palette,
    required this.color,
  });

  final IconData icon;
  final String label;
  final AppPalette palette;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(
          palette.darkBackground ? 0.36 : 0.72,
        ),
        borderRadius: BorderRadius.circular(palette.radius(14)),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          if (branchesCanOpen(label)) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              color: palette.textSecondary,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }

  bool branchesCanOpen(String value) => value != 'Sin sucursal activa';
}

class _RoleSummaryGrid extends StatelessWidget {
  const _RoleSummaryGrid({
    required this.palette,
    required this.roleLabel,
    required this.modulesCount,
    required this.branchName,
    required this.rolesCount,
  });

  final AppPalette palette;
  final String roleLabel;
  final int modulesCount;
  final String? branchName;
  final int rolesCount;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _SummaryData(
        title: 'Perfil activo',
        value: roleLabel,
        icon: Icons.badge_rounded,
        color: palette.secondary,
      ),
      _SummaryData(
        title: 'Herramientas',
        value: '$modulesCount disponibles',
        icon: Icons.apps_rounded,
        color: palette.primary,
      ),
      _SummaryData(
        title: 'Sucursal',
        value: branchName?.isNotEmpty == true ? branchName! : 'Sin asignar',
        icon: Icons.store_mall_directory_rounded,
        color: palette.accent,
      ),
      _SummaryData(
        title: 'Acceso',
        value: rolesCount > 1 ? '$rolesCount roles activos' : 'Permisos vigentes',
        icon: Icons.verified_user_rounded,
        color: palette.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560
            ? 2
            : constraints.maxWidth < 980
                ? 2
                : 4;
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _SummaryCard(data: card, palette: palette),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.palette});

  final _SummaryData data;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(14),
      decoration: palette.panelDecoration(
        baseRadius: 20,
        tint: data.color,
        elevated: false,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.color.withOpacity(
                palette.darkBackground ? 0.22 : 0.12,
              ),
              borderRadius: BorderRadius.circular(palette.radius(14)),
            ),
            child: Icon(data.icon, color: data.color, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
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

class _RoleSection extends StatelessWidget {
  const _RoleSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final AppPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(
                  palette.darkBackground ? 0.20 : 0.11,
                ),
                borderRadius: BorderRadius.circular(palette.radius(13)),
              ),
              child: Icon(icon, color: palette.secondary, size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        child,
      ],
    );
  }
}

class _WorkflowStep {
  const _WorkflowStep({
    required this.number,
    required this.title,
    required this.description,
    required this.item,
  });

  final int number;
  final String title;
  final String description;
  final UserMenuItem item;
}

class _WorkflowGrid extends StatelessWidget {
  const _WorkflowGrid({required this.steps, required this.palette});

  final List<_WorkflowStep> steps;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 700 ? 1 : steps.length.clamp(1, 3);
        final gap = 11.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final step in steps)
              SizedBox(
                width: width,
                child: _WorkflowCard(step: step, palette: palette),
              ),
          ],
        );
      },
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({required this.step, required this.palette});

  final _WorkflowStep step;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(step.item.keyName);
    final accent = Color.lerp(visual.color, palette.secondary, 0.45) ??
        palette.secondary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(palette.radius(21)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(step.item.path),
        child: Container(
          constraints: const BoxConstraints(minHeight: 142),
          padding: const EdgeInsets.all(15),
          decoration: palette.panelDecoration(
            baseRadius: 21,
            tint: accent,
            elevated: false,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${step.number}',
                      style: TextStyle(
                        color: ThemeData.estimateBrightnessForColor(accent) ==
                                Brightness.dark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded, color: accent, size: 19),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                step.title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                step.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedGrid extends StatelessWidget {
  const _FeaturedGrid({required this.items, required this.palette});

  final List<UserMenuItem> items;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560
            ? 1
            : constraints.maxWidth < 960
                ? 2
                : 4;
        final gap = 11.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items.take(4))
              SizedBox(
                width: width,
                child: _FeaturedCard(item: item, palette: palette),
              ),
          ],
        );
      },
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.item, required this.palette});

  final UserMenuItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(item.keyName);
    final accent = Color.lerp(visual.color, palette.secondary, 0.48) ??
        palette.secondary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(palette.radius(22)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(item.path),
        child: Container(
          constraints: const BoxConstraints(minHeight: 154),
          padding: const EdgeInsets.all(16),
          decoration: palette.panelDecoration(
            baseRadius: 22,
            tint: accent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(
                        palette.darkBackground ? 0.24 : 0.13,
                      ),
                      borderRadius: BorderRadius.circular(palette.radius(15)),
                    ),
                    child: Icon(visual.icon, color: accent, size: 24),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: accent, size: 20),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.description ?? visual.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.28,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllModulesGrid extends StatelessWidget {
  const _AllModulesGrid({required this.items, required this.palette});

  final List<UserMenuItem> items;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520
            ? 2
            : constraints.maxWidth < 850
                ? 3
                : constraints.maxWidth < 1220
                    ? 4
                    : 5;
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _ModuleTile(item: item, palette: palette),
              ),
          ],
        );
      },
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.item, required this.palette});

  final UserMenuItem item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final visual = ModuleVisuals.byKey(item.keyName);
    final accent = Color.lerp(visual.color, palette.secondary, 0.50) ??
        palette.secondary;
    return Material(
      color: palette.surface.withOpacity(palette.darkBackground ? 0.90 : 0.98),
      borderRadius: BorderRadius.circular(palette.radius(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(item.path),
        child: Container(
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(palette.radius(18)),
            border: Border.all(color: accent.withOpacity(0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(
                    palette.darkBackground ? 0.22 : 0.11,
                  ),
                  borderRadius: BorderRadius.circular(palette.radius(13)),
                ),
                child: Icon(visual.icon, color: accent, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyModulesCard extends StatelessWidget {
  const _EmptyModulesCard({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: palette.panelDecoration(
        baseRadius: 22,
        tint: palette.warning,
        elevated: false,
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: palette.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tu usuario aún no tiene módulos habilitados. Solicita al administrador que revise los permisos del rol.',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _RoleHomeType {
  cashier,
  waiter,
  inventory,
  prices,
  movements,
  admin,
  custom,
}

class _RoleHomeProfile {
  const _RoleHomeProfile({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.workflowSubtitle,
    required this.icon,
    required this.color,
    required this.priority,
  });

  final _RoleHomeType type;
  final String label;
  final String subtitle;
  final String workflowSubtitle;
  final IconData icon;
  final Color color;
  final List<String> priority;

  static _RoleHomeProfile resolve(List<String> roles) {
    final normalized = roles.map(_normalizeRole).toList(growable: false);
    final hasInventory = normalized.any((role) =>
        role.contains('INVENTARIO') ||
        role.contains('INVENTORY') ||
        role.contains('BODEGA') ||
        role.contains('ALMACEN'));

    if (normalized.any((role) {
      final clean = role.replaceFirst('ROLE_', '');
      return clean == 'ADMIN' ||
          clean == 'ADMINISTRADOR' ||
          clean == 'SUPERADMIN' ||
          clean == 'SUPER_ADMIN';
    })) {
      return const _RoleHomeProfile(
        type: _RoleHomeType.admin,
        label: 'Administración',
        subtitle:
            'Gestiona usuarios, empresas, sucursales y configuración desde un inicio limpio y organizado.',
        workflowSubtitle:
            'Revisa primero la estructura del negocio y luego administra sus accesos.',
        icon: Icons.admin_panel_settings_rounded,
        color: Color(0xFF7C3AED),
        priority: [
          'usuarios',
          'empresas',
          'sucursales',
          'roles_personalizados',
          'reportes',
          'ventas',
          'pagos',
          'inventario',
          'productos',
        ],
      );
    }

    if (!hasInventory && normalized.any((role) =>
        role.contains('CAJER') ||
        role.contains('CAJA') ||
        role.contains('CASHIER'))) {
      return const _RoleHomeProfile(
        type: _RoleHomeType.cashier,
        label: 'Caja',
        subtitle:
            'Controla mesas, pagos, historial y cierre de caja con accesos rápidos para la operación diaria.',
        workflowSubtitle:
            'Abre la operación, registra los pagos y termina con el cierre de caja.',
        icon: Icons.point_of_sale_rounded,
        color: Color(0xFF059669),
        priority: [
          'mesas',
          'productos',
          'resumen',
          'ventas',
          'cierres_caja',
          'pagos',
        ],
      );
    }

    if (!hasInventory && normalized.any((role) =>
        role.contains('MESER') ||
        role.contains('VENDEDOR') ||
        role.contains('VENTA') ||
        role.contains('SELLER'))) {
      return const _RoleHomeProfile(
        type: _RoleHomeType.waiter,
        label: 'Mesero',
        subtitle:
            'Atiende mesas, agrega productos y consulta el estado de tus cuentas sin información innecesaria.',
        workflowSubtitle:
            'Selecciona una mesa, registra el pedido y controla el estado de la cuenta.',
        icon: Icons.room_service_rounded,
        color: Color(0xFFF59E0B),
        priority: ['mesas', 'productos', 'resumen', 'ventas'],
      );
    }

    if (normalized.any((role) =>
        role.contains('INVENTARIO') ||
        role.contains('INVENTORY') ||
        role.contains('BODEGA') ||
        role.contains('ALMACEN'))) {
      return const _RoleHomeProfile(
        type: _RoleHomeType.inventory,
        label: 'Inventario',
        subtitle:
            'Supervisa existencias, movimientos, precios y reposición desde un centro de trabajo compacto.',
        workflowSubtitle:
            'Consulta el stock, registra el movimiento y revisa la reposición sugerida.',
        icon: Icons.inventory_2_rounded,
        color: Color(0xFF0D9488),
        priority: [
          'inventario',
          'productos',
          'movimientos',
          'proximo_pedido',
          'sincronizar_catalogo',
          'precios',
          'reportes',
          'ganancias',
        ],
      );
    }

    if (normalized.any((role) => role.contains('PRECIO'))) {
      return const _RoleHomeProfile(
        type: _RoleHomeType.prices,
        label: 'Precios',
        subtitle:
            'Administra los precios vigentes y consulta los productos relacionados de forma rápida.',
        workflowSubtitle:
            'Busca el producto, actualiza su precio y revisa los resultados.',
        icon: Icons.sell_rounded,
        color: Color(0xFF0284C7),
        priority: ['precios', 'productos', 'reportes', 'ganancias'],
      );
    }

    if (normalized.any((role) => role.contains('MOVIMIENTO'))) {
      return const _RoleHomeProfile(
        type: _RoleHomeType.movements,
        label: 'Movimientos',
        subtitle:
            'Registra entradas, salidas, préstamos y ajustes con acceso directo al inventario.',
        workflowSubtitle:
            'Selecciona el movimiento, registra los productos y verifica el inventario.',
        icon: Icons.swap_horiz_rounded,
        color: Color(0xFF2563EB),
        priority: ['movimientos', 'inventario', 'productos', 'reportes'],
      );
    }

    final label = normalized.isEmpty
        ? 'Mi espacio'
        : _humanizeRole(normalized.first.replaceFirst('ROLE_', ''));
    return _RoleHomeProfile(
      type: _RoleHomeType.custom,
      label: label,
      subtitle:
          'Accede a las funciones configuradas específicamente para tu rol.',
      workflowSubtitle:
          'Usa los accesos autorizados en el orden que requiera tu operación.',
      icon: Icons.dashboard_customize_rounded,
      color: const Color(0xFF6366F1),
      priority: const [],
    );
  }
}

List<UserMenuItem> _buildAvailableItems(
  _RoleHomeProfile profile,
  List<UserMenuItem> databaseItems,
) {
  final result = <UserMenuItem>[];
  final seenPaths = <String>{};

  void add(UserMenuItem item) {
    final path = item.path.trim();
    if (path.isEmpty || path == '/home' || !seenPaths.add(path)) return;
    result.add(item);
  }

  for (final item in _systemItemsFor(profile.type)) {
    add(item);
  }
  for (final item in databaseItems) {
    add(item);
  }

  result.sort((a, b) {
    final aPriority = _priorityIndex(profile.priority, a.keyName);
    final bPriority = _priorityIndex(profile.priority, b.keyName);
    final byPriority = aPriority.compareTo(bPriority);
    if (byPriority != 0) return byPriority;
    return a.title.compareTo(b.title);
  });
  return result;
}

List<UserMenuItem> _featuredItems(
  _RoleHomeProfile profile,
  List<UserMenuItem> items,
) {
  if (items.length <= 4) return items;
  final ordered = List<UserMenuItem>.of(items)
    ..sort((a, b) {
      final byPriority = _priorityIndex(profile.priority, a.keyName)
          .compareTo(_priorityIndex(profile.priority, b.keyName));
      if (byPriority != 0) return byPriority;
      return a.title.compareTo(b.title);
    });
  return ordered.take(4).toList(growable: false);
}

List<_WorkflowStep> _workflowFor(
  _RoleHomeProfile profile,
  List<UserMenuItem> items,
) {
  final definitions = switch (profile.type) {
    _RoleHomeType.waiter => const [
        ('mesas', 'Selecciona la mesa', 'Abre o continúa una venta activa.'),
        ('productos', 'Registra el pedido', 'Agrega productos y cantidades.'),
        ('resumen', 'Revisa la cuenta', 'Consulta consumos y valores pendientes.'),
      ],
    _RoleHomeType.cashier => const [
        ('mesas', 'Revisa la operación', 'Consulta mesas y cuentas abiertas.'),
        ('ventas', 'Verifica el recaudo', 'Consulta ventas y pagos registrados.'),
        ('cierres_caja', 'Cierra la caja', 'Valida totales al terminar la jornada.'),
      ],
    _RoleHomeType.inventory => const [
        ('inventario', 'Consulta existencias', 'Identifica faltantes y diferencias.'),
        ('movimientos', 'Registra movimientos', 'Aplica entradas, salidas o ajustes.'),
        ('sincronizar_catalogo', 'Comparte el catálogo', 'Copia productos y costos hacia otra sucursal autorizada.'),
        ('proximo_pedido', 'Prepara el pedido', 'Revisa la reposición sugerida.'),
      ],
    _RoleHomeType.prices => const [
        ('productos', 'Busca el producto', 'Identifica la presentación correcta.'),
        ('precios', 'Actualiza el precio', 'Registra el valor de compra o venta.'),
        ('reportes', 'Valida el resultado', 'Revisa márgenes y comportamiento.'),
      ],
    _RoleHomeType.movements => const [
        ('movimientos', 'Selecciona el tipo', 'Define si suma, resta o ajusta stock.'),
        ('productos', 'Registra productos', 'Indica cantidades y presentaciones.'),
        ('inventario', 'Verifica el stock', 'Confirma el resultado del movimiento.'),
      ],
    _RoleHomeType.admin => const [
        ('empresas', 'Configura la empresa', 'Mantén actualizada su información.'),
        ('sucursales', 'Organiza sucursales', 'Define los puntos de operación.'),
        ('usuarios', 'Administra accesos', 'Asigna roles y sucursales autorizadas.'),
      ],
    _RoleHomeType.custom => const <(String, String, String)>[],
  };

  final result = <_WorkflowStep>[];
  for (final definition in definitions) {
    final item = _findByKey(items, definition.$1);
    if (item == null) continue;
    result.add(
      _WorkflowStep(
        number: result.length + 1,
        title: definition.$2,
        description: definition.$3,
        item: item,
      ),
    );
  }

  if (result.isEmpty && items.isNotEmpty) {
    for (final item in items.take(3)) {
      result.add(
        _WorkflowStep(
          number: result.length + 1,
          title: item.title,
          description:
              item.description ?? ModuleVisuals.byKey(item.keyName).description,
          item: item,
        ),
      );
    }
  }
  return result;
}

List<UserMenuItem> _systemItemsFor(_RoleHomeType type) {
  const mesas = UserMenuItem(
    keyName: 'mesas',
    title: 'Mesas',
    path: '/mesero',
    description: 'Abrir ventas y operar cuentas por mesa.',
    system: true,
  );
  const productosMesero = UserMenuItem(
    keyName: 'productos',
    title: 'Productos',
    path: '/mesero/productos',
    description: 'Buscar y agregar productos a la cuenta.',
    system: true,
  );
  const resumen = UserMenuItem(
    keyName: 'resumen',
    title: 'Resumen',
    path: '/mesero/resumen',
    description: 'Consultar mesas abiertas y saldos pendientes.',
    system: true,
  );
  const historial = UserMenuItem(
    keyName: 'ventas',
    title: 'Historial',
    path: '/mesero/historial',
    description: 'Revisar ventas y pagos registrados.',
    system: true,
  );
  const cierre = UserMenuItem(
    keyName: 'cierres_caja',
    title: 'Cierre de caja',
    path: '/mesero/cierre-caja',
    description: 'Validar y cerrar la operación de caja.',
    system: true,
  );


  return switch (type) {
    _RoleHomeType.waiter => const [mesas, productosMesero, resumen],
    _RoleHomeType.cashier =>
      const [mesas, productosMesero, resumen, historial, cierre],
    _RoleHomeType.inventory => const [
        UserMenuItem(
          keyName: 'inventario',
          title: 'Inventario',
          path: '/inventario',
          description: 'Consultar existencias por sucursal.',
          system: true,
        ),
        UserMenuItem(
          keyName: 'productos',
          title: 'Productos',
          path: '/productos',
          description: 'Administrar el catálogo de productos.',
          system: true,
        ),
        UserMenuItem(
          keyName: 'movimientos',
          title: 'Movimientos',
          path: '/movimientos',
          description: 'Registrar entradas, salidas y ajustes.',
          system: true,
        ),
        UserMenuItem(
          keyName: 'proximo_pedido',
          title: 'Próximo pedido',
          path: '/proximo_pedido',
          description: 'Consultar reposición sugerida.',
          system: true,
        ),
        UserMenuItem(
          keyName: 'precios',
          title: 'Precios',
          path: '/precios',
          description: 'Consultar y actualizar precios.',
          system: true,
        ),
        UserMenuItem(
          keyName: 'reportes',
          title: 'Reportes',
          path: '/reportes',
          description: 'Revisar indicadores de inventario.',
          system: true,
        ),
      ],
    _RoleHomeType.prices => const [
        UserMenuItem(
          keyName: 'precios',
          title: 'Precios',
          path: '/precios',
          description: 'Actualizar precios vigentes.',
          system: true,
        ),
        UserMenuItem(
          keyName: 'productos',
          title: 'Productos',
          path: '/productos',
          description: 'Consultar productos y presentaciones.',
          system: true,
        ),
      ],
    _RoleHomeType.movements => const [
        UserMenuItem(
          keyName: 'movimientos',
          title: 'Movimientos',
          path: '/movimientos',
          description: 'Registrar entradas, salidas y ajustes.',
          system: true,
        ),
        UserMenuItem(
          keyName: 'inventario',
          title: 'Inventario',
          path: '/inventario',
          description: 'Verificar existencias actuales.',
          system: true,
        ),
        UserMenuItem(
          keyName: 'productos',
          title: 'Productos',
          path: '/productos',
          description: 'Consultar productos y presentaciones.',
          system: true,
        ),
      ],
    _RoleHomeType.admin => const [],
    _RoleHomeType.custom => const [],
  };
}

UserMenuItem? _findByKey(List<UserMenuItem> items, String key) {
  for (final item in items) {
    if (item.keyName == key) return item;
  }
  return null;
}

int _priorityIndex(List<String> priority, String key) {
  final index = priority.indexOf(key);
  return index < 0 ? 999 : index;
}

String _normalizeRole(String value) => value
    .toUpperCase()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceAll(RegExp(r'[^A-Z0-9]+'), '_');

String _humanizeRole(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part.substring(0, 1)}${part.substring(1).toLowerCase()}')
    .join(' ');

String _greetingFor(int hour) {
  if (hour < 12) return 'Buenos días';
  if (hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

String _firstName(String value) => value.trim().split(RegExp(r'\s+')).first;

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
}
