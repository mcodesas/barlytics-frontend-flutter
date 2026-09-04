import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_router.dart';
import '../providers/core_providers.dart';
import 'app_update_model.dart';
import 'app_update_service.dart';

/// Comprueba al iniciar y periódicamente si existe una versión nueva de BarLytics.
/// No se monta en Flutter Web y no interfiere con la navegación/autenticación.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  Timer? _periodicTimer;
  bool _checking = false;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), _checkForUpdates);
    });
    _periodicTimer = Timer.periodic(
      const Duration(hours: 4),
      (_) => _checkForUpdates(),
    );
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    if (_checking || _dialogVisible || !mounted || kIsWeb) return;
    _checking = true;

    final service = AppUpdateService(ref.read(apiClientProvider));
    try {
      final candidate = await service.checkForUpdate();
      if (!mounted || candidate == null) return;

      BuildContext? dialogContext;
      for (var attempt = 0; attempt < 5 && mounted; attempt++) {
        dialogContext = appNavigatorKey.currentState?.overlay?.context;
        if (dialogContext != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted || dialogContext == null) return;

      _dialogVisible = true;
      try {
        await showDialog<void>(
          context: dialogContext,
          barrierDismissible: !candidate.release.mandatory,
          builder: (_) => _AppUpdateDialog(
            candidate: candidate,
            service: service,
          ),
        );
      } finally {
        _dialogVisible = false;
      }
    } catch (error, stackTrace) {
      // Una comprobación de versión nunca debe impedir abrir BarLytics.
      debugPrint('BarLytics updater: no fue posible comprobar actualizaciones: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({
    required this.candidate,
    required this.service,
  });

  final AppUpdateCandidate candidate;
  final AppUpdateService service;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _updating = false;
  double? _progress;
  String? _error;

  Future<void> _later() async {
    await widget.service.snooze(widget.candidate);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _updateNow() async {
    if (_updating) return;
    setState(() {
      _updating = true;
      _progress = widget.candidate.platform.isDesktop ? 0 : null;
      _error = null;
    });

    try {
      await widget.service.performUpdate(
        widget.candidate,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value);
        },
      );

      // Windows termina el proceso para permitir que Inno Setup reemplace los
      // binarios. En macOS/Linux se abre el instalador; en móvil se abre tienda.
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _updating = false;
        _progress = null;
        _error = _friendlyMessage(error);
      });
    }
  }

  String _friendlyMessage(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '').replaceFirst('StateError: ', '');
    return text.isEmpty ? 'No fue posible iniciar la actualización.' : text;
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    final release = candidate.release;
    final theme = Theme.of(context);
    final desktop = candidate.platform.isDesktop;

    return PopScope(
      canPop: !release.mandatory && !_updating,
      child: AlertDialog(
        constraints: const BoxConstraints(maxWidth: 520),
        icon: const Icon(Icons.system_update_alt_rounded, size: 42),
        title: const Text('Nueva versión disponible'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'BarLytics ${release.displayVersion} está disponible para ${candidate.platform.label}.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _VersionValue(
                        label: 'Instalada',
                        value: '${candidate.currentVersion}+${candidate.currentBuild}',
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                    Expanded(
                      child: _VersionValue(
                        label: 'Nueva',
                        value: release.displayVersion,
                      ),
                    ),
                  ],
                ),
              ),
              if (release.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  release.releaseNotes,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                desktop
                    ? candidate.platform == AppUpdatePlatform.windows
                        ? 'Al actualizar, BarLytics descargará el instalador, cerrará esta ventana, instalará la nueva versión y volverá a abrir la aplicación.'
                        : 'BarLytics descargará y abrirá el instalador de la nueva versión.'
                    : 'La actualización se realizará desde la tienda oficial de tu dispositivo.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (_updating && desktop) ...[
                const SizedBox(height: 18),
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(
                  _progress == null
                      ? 'Preparando actualización…'
                      : 'Descargando ${(_progress! * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!release.mandatory)
            TextButton(
              onPressed: _updating ? null : _later,
              child: const Text('Más tarde'),
            ),
          FilledButton.icon(
            onPressed: _updating ? null : _updateNow,
            icon: Icon(desktop ? Icons.download_rounded : Icons.open_in_new_rounded),
            label: Text(desktop ? 'Actualizar ahora' : 'Ir a la tienda'),
          ),
        ],
      ),
    );
  }
}

class _VersionValue extends StatelessWidget {
  const _VersionValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: theme.textTheme.titleSmall),
        ),
      ],
    );
  }
}
