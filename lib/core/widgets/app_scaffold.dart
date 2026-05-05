import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/module_registry.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../utils/responsive_utils.dart';

/// Scaffold principal con navegación adaptable.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final items = moduleRegistry;
    final drawer = Drawer(
      child: ListView(
        children: [
          const DrawerHeader(child: Text('BarLytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          for (final module in items)
            ListTile(
              title: Text(module.title),
              leading: const Icon(Icons.folder_outlined),
              onTap: () => context.go('/${module.key}'),
            ),
          ListTile(
            title: const Text('Reportes'),
            leading: const Icon(Icons.bar_chart),
            onTap: () => context.go('/reportes'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [SizedBox(width: 280, child: drawer), const VerticalDivider(width: 1), Expanded(child: child)],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('BarLytics')),
      drawer: drawer,
      body: child,
    );
  }
}
