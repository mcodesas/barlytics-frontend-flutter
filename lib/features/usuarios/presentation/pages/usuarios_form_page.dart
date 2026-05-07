import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/dynamic_crud_form_page.dart';
import '../../data/models/usuarios_response_model.dart';

class UsuariosFormPage extends StatelessWidget {
  const UsuariosFormPage({super.key, this.id});
  final String? id;

  @override
  Widget build(BuildContext context) => DynamicCrudFormPage<UsuariosResponseModel>(
        config: usuariosConfig,
        id: id,
        onSaved: id == null
            ? (context, saved) {
                final json = usuariosConfig.toJson(saved);
                final userId = json['usuaId']?.toString();
                if (userId == null || userId.isEmpty) {
                  context.go('/usuarios');
                  return;
                }
                context.go('/usuarios/$userId/roles');
              }
            : null,
      );
}
