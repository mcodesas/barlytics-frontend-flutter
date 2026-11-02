import 'package:flutter/material.dart';

import '../widgets/sports_agenda_widget.dart';

/// Módulo navegable desde MENUS/OPCIONMENU, independiente de la tarjeta Inicio.
class AgendaDeportivaPage extends StatelessWidget {
  const AgendaDeportivaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Agenda deportiva y noticias',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          SizedBox(height: 12),
          SportsAgendaWidget(),
        ],
      ),
    );
  }
}
