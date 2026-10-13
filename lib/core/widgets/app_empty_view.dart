import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_palette.dart';

class AppEmptyView extends ConsumerWidget {
  const AppEmptyView({super.key, this.message = 'No hay registros para mostrar'});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight =
            constraints.hasBoundedHeight ? constraints.maxHeight : double.infinity;
        final compact = availableHeight < 320;
        final veryCompact = availableHeight < 190;

        final outerPadding = compact ? 8.0 : 24.0;
        final horizontalPadding = compact ? 16.0 : 28.0;
        final verticalPadding = veryCompact
            ? 8.0
            : compact
                ? 12.0
                : 28.0;
        final iconBoxSize = veryCompact
            ? 36.0
            : compact
                ? 48.0
                : 76.0;
        final iconSize = veryCompact
            ? 18.0
            : compact
                ? 24.0
                : 36.0;

        return Center(
          child: Padding(
            padding: EdgeInsets.all(outerPadding),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(
                color: palette.surface.withOpacity(
                  palette.darkBackground ? 0.95 : 0.99,
                ),
                borderRadius: BorderRadius.circular(compact ? 22 : 30),
                border: Border.all(color: palette.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: palette.cardShadow,
                    blurRadius: compact ? 14 : 24,
                    offset: Offset(0, compact ? 8 : 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [palette.primary, palette.secondary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inbox_rounded,
                      size: iconSize,
                      color: palette.onPrimary,
                    ),
                  ),
                  SizedBox(height: veryCompact ? 6 : compact ? 10 : 16),
                  Text(
                    'Sin información',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (compact
                            ? Theme.of(context).textTheme.titleMedium
                            : Theme.of(context).textTheme.titleLarge)
                        ?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: palette.textPrimary,
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 8),
                  Text(
                    message,
                    maxLines: veryCompact ? 1 : compact ? 2 : 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 13 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
