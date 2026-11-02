import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_palette.dart';
import '../widgets/sports_agenda_widget.dart';

/// Pantalla completa integrada con la identidad visual de BarLytics.
class AgendaDeportivaPage extends ConsumerWidget {
  const AgendaDeportivaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1250),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16 * palette.spacingScale),
            children: const [
              SportsAgendaWidget(),
              SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
