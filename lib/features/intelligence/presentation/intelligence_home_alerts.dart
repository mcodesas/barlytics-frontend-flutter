import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../deportes/presentation/widgets/sports_agenda_widget.dart';
import 'intelligence_alerts_card.dart';

/// Unified home section. The parent checks the active menu; the alerts API
/// independently verifies branch, user and per-rule permissions.
class IntelligenceHomeAlerts extends ConsumerWidget {
  const IntelligenceHomeAlerts({
    super.key,
    required this.branch,
    required this.showBusiness,
    required this.showSports,
  });

  final int branch;
  final bool showBusiness;
  final bool showSports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    if (!showBusiness && !showSports) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: palette.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alertas inteligentes', style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
                    Text('MCode Intelligence · Información y recomendaciones', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (showBusiness) ...[
            const SizedBox(height: 8),
            IntelligenceAlertsCard(key: ValueKey('alerts-$branch'), branch: branch, initiallyExpanded: true),
          ],
          if (showSports) ...[
            const SizedBox(height: 8),
            const SportsAgendaWidget(compact: true),
          ],
        ],
      ),
    );
  }
}
