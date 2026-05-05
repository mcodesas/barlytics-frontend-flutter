import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/module_registry.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/responsive_layout.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Scaffold(
        appBar: AppBar(title: const Text('Inicio')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ResponsiveLayout(
            mobile: _Grid(columns: 1),
            tablet: _Grid(columns: 2),
            desktop: _Grid(columns: 3),
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.columns});
  final int columns;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: columns,
        childAspectRatio: columns == 1 ? 4.2 : 2.8,
        children: [
          for (final module in moduleRegistry)
            Card(
              child: ListTile(
                leading: const Icon(Icons.apps),
                title: Text(module.title),
                subtitle: Text(module.basePath),
                onTap: () => context.go('/${module.key}'),
              ),
            ),
        ],
      );
}
