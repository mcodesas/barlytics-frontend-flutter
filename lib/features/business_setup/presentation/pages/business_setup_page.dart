import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../core/widgets/tech_background.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/business_setup_models.dart';
import '../providers/business_setup_provider.dart';

class BusinessSetupPage extends ConsumerWidget {
  const BusinessSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final statusAsync = ref.watch(businessSetupStatusProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TechBackground(
        padding: EdgeInsets.zero,
        child: statusAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: palette.secondary),
          ),
          error: (error, _) => _SetupError(
            message: _cleanError(error),
            onRetry: () => ref.invalidate(businessSetupStatusProvider),
          ),
          data: (status) => _SetupContent(status: status),
        ),
      ),
    );
  }
}

class _SetupContent extends ConsumerWidget {
  const _SetupContent({required this.status});

  final BusinessSetupStatusModel status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final horizontal = compact ? 14.0 : 28.0;
    final mandatory = status.steps.where((step) => step.mandatory).toList(growable: false);
    final optional = status.steps.where((step) => !step.mandatory).toList(growable: false);
    final pending = mandatory.where((step) => !step.complete).toList(growable: false);
    final BusinessSetupStepModel? current = status.complete || pending.isEmpty ? null : pending.first;

    return SafeArea(
      child: Column(
        children: [
          _TopBar(compact: compact),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 30),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _WelcomeAndCurrent(
                            status: status,
                            current: current,
                            compact: compact,
                            onRefresh: () => _refresh(ref),
                            onEnter: () async {
                              final complete = await ref
                                  .read(authControllerProvider.notifier)
                                  .refreshBusinessSetup();
                              if (context.mounted && complete) {
                                ref.read(businessSetupGuidedModeProvider.notifier).state = false;
                                context.go('/home');
                              }
                            },
                          ),
                          const SizedBox(height: 22),
                          _JourneySection(
                            steps: mandatory,
                            currentCode: status.nextStepCode,
                          ),
                          if (optional.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _OptionalSection(steps: optional),
                          ],
                        ],
                      ),
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

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(businessSetupStatusProvider);
    await ref.read(businessSetupStatusProvider.future);
    await ref.read(authControllerProvider.notifier).refreshBusinessSetup();
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 28, 10, compact ? 8 : 20, 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.secondary.withOpacity(.22),
                  palette.accent.withOpacity(.12),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.secondary.withOpacity(.32)),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: palette.secondary, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Puesta en marcha',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 17 : 19,
                  ),
                ),
                Text(
                  'Te acompañamos hasta tu primera operación',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: Icon(Icons.logout_rounded, color: palette.textSecondary, size: 21),
          ),
        ],
      ),
    );
  }
}

class _WelcomeAndCurrent extends ConsumerWidget {
  const _WelcomeAndCurrent({
    required this.status,
    required this.current,
    required this.compact,
    required this.onRefresh,
    required this.onEnter,
  });

  final BusinessSetupStatusModel status;
  final BusinessSetupStepModel? current;
  final bool compact;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    final welcome = _WelcomeCard(status: status, onEnter: onEnter);
    final focus = current == null
        ? const _CompletionPreview()
        : _CurrentStepCard(step: current!, onRefresh: onRefresh);

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [welcome, const SizedBox(height: 14), focus],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: welcome),
        const SizedBox(width: 16),
        Expanded(flex: 7, child: focus),
      ],
    );
  }
}

class _WelcomeCard extends ConsumerWidget {
  const _WelcomeCard({required this.status, required this.onEnter});

  final BusinessSetupStatusModel status;
  final Future<void> Function() onEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final done = status.complete;
    final progress = (status.progressPercentage.clamp(0, 100)) / 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: palette.panelDecoration(
        baseRadius: 26,
        tint: done ? palette.success : palette.secondary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SoftChip(
                icon: Icons.verified_rounded,
                label: 'Plan activo',
                color: palette.success,
              ),
              _SoftChip(
                icon: Icons.cloud_done_outlined,
                label: 'Tu avance se conserva',
                color: palette.info,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            done ? '¡Tu negocio está listo!' : 'Vamos a dejar BarLytics listo para vender',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 23,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            done
                ? 'Terminaste la puesta en marcha. Ya puedes entrar y comenzar a operar con tu configuración inicial.'
                : 'No tienes que aprender todo ahora. Te guiamos paso a paso para dejar configurado todo lo esencial antes de empezar a operar.',
            style: TextStyle(
              color: palette.textSecondary,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (done) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onEnter,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.actionColor,
                  foregroundColor: palette.onAction,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                label: const Text(
                  'Entrar a BarLytics',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  done
                      ? 'Puesta en marcha completada'
                      : '${status.completedMandatorySteps} de ${status.totalMandatorySteps} etapas listas',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${status.progressPercentage}%',
                style: TextStyle(
                  color: done ? palette.success : palette.secondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, _) => LinearProgressIndicator(
                minHeight: 8,
                value: value,
                backgroundColor: palette.cardBorder.withOpacity(.34),
                color: done ? palette.success : palette.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentStepCard extends ConsumerWidget {
  const _CurrentStepCard({required this.step, required this.onRefresh});

  final BusinessSetupStepModel step;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final icon = _stepIcon(step.code);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.secondary.withOpacity(palette.darkBackground ? .18 : .10),
            palette.surface.withOpacity(.98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(palette.radius(26)),
        border: Border.all(color: palette.secondary.withOpacity(.38), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: palette.secondary.withOpacity(.09),
            blurRadius: 26,
            offset: const Offset(0, 10),
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
                  color: palette.secondary.withOpacity(.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.secondary.withOpacity(.35)),
                ),
                child: Icon(icon, color: palette.secondary, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ahora vamos con',
                      style: TextStyle(
                        color: palette.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.title,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            _benefitFor(step.code),
            style: TextStyle(
              color: palette.textPrimary,
              height: 1.42,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _friendlyHintFor(step.code),
            style: TextStyle(color: palette.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 480;
              final primary = FilledButton.icon(
                onPressed: step.route.trim().isEmpty ? null : () => _openGuidedSetupRoute(context, ref, step.route),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.actionColor,
                  foregroundColor: palette.onAction,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                ),
                icon: Icon(_stepIcon(step.code), size: 19),
                label: Text(
                  _friendlyActionFor(step.code),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              );
              final secondary = TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Ya lo hice'),
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [primary, const SizedBox(height: 6), secondary],
                );
              }
              return Row(
                children: [primary, const SizedBox(width: 10), secondary],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CompletionPreview extends ConsumerWidget {
  const _CompletionPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: palette.panelDecoration(baseRadius: 26, tint: palette.success),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: palette.success.withOpacity(.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.celebration_rounded, color: palette.success, size: 29),
          ),
          const SizedBox(height: 15),
          Text(
            'Todo lo esencial está listo',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Ya puedes comenzar a vender. Si quieres, puedes volver a cualquiera de estos puntos y ajustar la configuración cuando lo necesites.',
            style: TextStyle(color: palette.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _JourneySection extends ConsumerWidget {
  const _JourneySection({required this.steps, required this.currentCode});

  final List<BusinessSetupStepModel> steps;
  final String? currentCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: palette.panelDecoration(baseRadius: 24, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, color: palette.secondary, size: 22),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu camino para empezar',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Puedes entrar a cada punto y volver a editarlo cuando quieras.',
                      style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < steps.length; i++)
            _JourneyRow(
              step: steps[i],
              index: i,
              last: i == steps.length - 1,
              current: !steps[i].complete && steps[i].code == currentCode,
            ),
        ],
      ),
    );
  }
}

class _JourneyRow extends ConsumerWidget {
  const _JourneyRow({
    required this.step,
    required this.index,
    required this.last,
    required this.current,
  });

  final BusinessSetupStepModel step;
  final int index;
  final bool last;
  final bool current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    final color = step.complete
        ? palette.success
        : current
            ? palette.secondary
            : palette.textSecondary.withOpacity(.45);

    Widget trailing;
    if (step.complete && step.route.trim().isNotEmpty) {
      trailing = TextButton.icon(
        onPressed: () => _openGuidedSetupRoute(context, ref, step.route),
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: const Text('Modificar'),
      );
    } else if (current) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SoftChip(
            icon: Icons.play_arrow_rounded,
            label: 'Ahora',
            color: palette.secondary,
            compact: true,
          ),
          if (step.route.trim().isNotEmpty) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Abrir',
              onPressed: () => _openGuidedSetupRoute(context, ref, step.route),
              icon: Icon(Icons.arrow_forward_rounded, color: palette.secondary, size: 20),
            ),
          ],
        ],
      );
    } else if (step.route.trim().isNotEmpty) {
      trailing = IconButton(
        tooltip: 'Abrir',
        onPressed: () => _openGuidedSetupRoute(context, ref, step.route),
        icon: Icon(Icons.arrow_forward_rounded, color: palette.textSecondary, size: 20),
      );
    } else {
      trailing = const SizedBox.shrink();
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.13),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(.46)),
                  ),
                  child: step.complete
                      ? Icon(Icons.check_rounded, color: palette.success, size: 18)
                      : Icon(_stepIcon(step.code), color: color, size: 17),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: (step.complete ? palette.success : palette.cardBorder).withOpacity(.28),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: current ? palette.secondary.withOpacity(.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                  border: current ? Border.all(color: palette.secondary.withOpacity(.20)) : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              color: step.complete || current ? palette.textPrimary : palette.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.complete
                                ? 'Listo. Puedes volver a modificarlo cuando quieras.'
                                : current
                                    ? 'Es el paso en el que estás ahora'
                                    : _previewFor(step.code),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: step.complete ? palette.success : palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionalSection extends ConsumerWidget {
  const _OptionalSection({required this.steps});

  final List<BusinessSetupStepModel> steps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      decoration: palette.panelDecoration(baseRadius: 22, elevated: false),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.accent.withOpacity(.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tips_and_updates_outlined, color: palette.accent, size: 20),
          ),
          title: Text(
            'Puedes completar después',
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            'Usuarios, mesas y permisos no bloquean el inicio. BarLytics te recordará lo importante más adelante.',
            style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
          ),
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _OptionalRow(step: steps[i]),
              if (i != steps.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionalRow extends ConsumerWidget {
  const _OptionalRow({required this.step});

  final BusinessSetupStepModel step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.background.withOpacity(.22),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.cardBorder.withOpacity(.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (step.complete ? palette.success : palette.accent).withOpacity(.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              step.complete ? Icons.check_rounded : _stepIcon(step.code),
              color: step.complete ? palette.success : palette.accent,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  _previewFor(step.code),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (step.route.trim().isNotEmpty)
            TextButton.icon(
              onPressed: () => _openGuidedSetupRoute(context, ref, step.route),
              icon: Icon(step.complete ? Icons.edit_outlined : Icons.arrow_forward_rounded, color: palette.secondary, size: 18),
              label: Text(step.complete ? 'Modificar' : 'Abrir'),
            ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({
    required this.icon,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(.11),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: compact ? 13 : 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _SetupError extends ConsumerWidget {
  const _SetupError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: palette.surface.withOpacity(.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.danger.withOpacity(.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, color: palette.danger, size: 38),
                const SizedBox(height: 12),
                Text(
                  'No pudimos cargar tu puesta en marcha',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Intentar de nuevo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _stepIcon(String code) {
  switch (code.trim().toUpperCase()) {
    case 'BUSINESS':
      return Icons.storefront_outlined;
    case 'BRANCHES':
      return Icons.location_on_outlined;
    case 'PAYMENT_METHODS':
      return Icons.account_balance_wallet_outlined;
    case 'BASE_CATALOGS':
      return Icons.category_outlined;
    case 'CATALOG':
      return Icons.local_bar_outlined;
    case 'OPERATIONS':
      return Icons.receipt_long_outlined;
    case 'TABLES':
      return Icons.table_restaurant_outlined;
    case 'TEAM':
      return Icons.groups_2_outlined;
    case 'CUSTOM_ROLES':
      return Icons.admin_panel_settings_outlined;
    default:
      return Icons.auto_awesome_outlined;
  }
}

String _benefitFor(String code) {
  switch (code.trim().toUpperCase()) {
    case 'BUSINESS':
      return 'Aquí puedes revisar o corregir la información principal de tu negocio siempre que lo necesites.';
    case 'BRANCHES':
      return 'Define desde dónde vas a operar. Cada sede tendrá sus propias ventas, inventario y configuración.';
    case 'PAYMENT_METHODS':
      return 'Elige cómo reciben dinero tus sucursales para que cada venta pueda cerrarse de forma clara.';
    case 'BASE_CATALOGS':
      return 'Define las marcas y categorías propias de tu empresa. Todas tus sucursales las comparten, pero ninguna otra empresa puede verlas o modificarlas.';
    case 'CATALOG':
      return 'Elige qué productos venderás. Puedes seleccionarlos de otra sucursal, migrar precio de compra y venta, o cargar los que no existan con la plantilla Excel de BarLytics.';
    case 'OPERATIONS':
      return 'Define el número que recibirá los pedidos de reposición para que esa función quede lista desde el primer día.';
    case 'TEAM':
      return 'Invita a las personas que trabajarán contigo para que cada una entre con su propio usuario y permisos.';
    default:
      return 'Completa esta etapa y BarLytics quedará un paso más cerca de estar listo para operar.';
  }
}

String _friendlyHintFor(String code) {
  switch (code.trim().toUpperCase()) {
    case 'BUSINESS':
      return 'Revisa que identificación, ubicación, dirección, teléfono y correo correspondan al negocio que va a operar.';
    case 'BRANCHES':
      return 'Si tienes una sola sede, basta con configurar esa primera sucursal.';
    case 'PAYMENT_METHODS':
      return 'Puedes comenzar con los medios que ya usas hoy: efectivo, transferencia, tarjeta u otros.';
    case 'BASE_CATALOGS':
      return 'BarLytics crea algunos ejemplos al registrar el negocio. Puedes conservarlos, renombrarlos, eliminarlos o agregar los tuyos.';
    case 'CATALOG':
      return 'No tienes que registrar todo uno a uno: usa la selección de productos o descarga la plantilla Excel, complétala y súbela. Luego revisa precios y cantidades.';
    case 'OPERATIONS':
      return 'El consecutivo del pedido lo genera BarLytics automáticamente; aquí solo defines el destino de los pedidos.';
    case 'TEAM':
      return 'Puedes crear primero los usuarios principales y luego seguir ampliando el equipo.';
    default:
      return 'Puedes regresar a esta guía cuando termines; tu avance se conserva.';
  }
}

String _friendlyActionFor(String code) {
  switch (code.trim().toUpperCase()) {
    case 'BUSINESS':
      return 'Revisar mi negocio';
    case 'BRANCHES':
      return 'Agregar mi primera sede';
    case 'PAYMENT_METHODS':
      return 'Elegir cómo recibo pagos';
    case 'BASE_CATALOGS':
      return 'Configurar marcas y tipos';
    case 'CATALOG':
      return 'Seleccionar o cargar productos';
    case 'OPERATIONS':
      return 'Configurar pedidos';
    case 'TEAM':
      return 'Crear usuarios';
    default:
      return 'Continuar';
  }
}

String _previewFor(String code) {
  switch (code.trim().toUpperCase()) {
    case 'BUSINESS':
      return 'Confirma o ajusta los datos principales de tu negocio.';
    case 'BRANCHES':
      return 'Define la sede desde la que comenzarás.';
    case 'PAYMENT_METHODS':
      return 'Selecciona cómo vas a recibir tus ventas.';
    case 'BASE_CATALOGS':
      return 'Revisa las marcas y los tipos de producto que utilizará tu empresa.';
    case 'CATALOG':
      return 'Selecciona lo que venderás, migra precios o carga productos desde Excel sin registrarlos uno a uno.';
    case 'OPERATIONS':
      return 'Configura el WhatsApp general que recibirá los pedidos. El número consecutivo lo genera BarLytics automáticamente.';
    case 'TEAM':
      return 'Crea los usuarios que van a usar el sistema.';
    case 'TABLES':
      return 'Organiza mesas si tu operación las utiliza.';
    case 'CUSTOM_ROLES':
      return 'Personaliza permisos si necesitas más control.';
    default:
      return 'Personaliza esta parte cuando la necesites.';
  }
}


void _openGuidedSetupRoute(BuildContext context, WidgetRef ref, String route) {
  final target = route.trim();
  if (target.isEmpty) return;
  ref.read(businessSetupGuidedModeProvider.notifier).state = true;
  context.go(target);
}

String _cleanError(Object error) {
  final text = error.toString().trim();
  return text.replaceFirst(RegExp(r'^(Exception|StateError|ApiException):\s*'), '');
}
