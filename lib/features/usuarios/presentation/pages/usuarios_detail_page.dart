import 'package:flutter/material.dart';
import 'usuarios_form_page.dart';

class UsuariosDetailPage extends StatelessWidget {
  const UsuariosDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => UsuariosFormPage(id: id, readOnly: true);
}
