import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController(text: 'admin@barlytics.com');
  final _password = TextEditingController(text: 'Admin123*');

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (previous, next) {
      if (next.authenticated) context.go('/home');
      if (next.failure != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.failure!.message)));
      }
    });
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('BarLytics', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('Inicia sesión para continuar'),
                    const SizedBox(height: 24),
                    AppTextField(controller: _identifier, label: 'Correo o identificador', validator: Validators.required),
                    const SizedBox(height: 16),
                    AppTextField(controller: _password, label: 'Contraseña', obscureText: true, validator: Validators.required),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Ingresar',
                      loading: state.loading,
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        await ref.read(authControllerProvider.notifier).login(_identifier.text.trim(), _password.text);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
