import 'package:flutter/material.dart';

import '../utils/responsive_utils.dart';

/// Renderiza diferentes layouts según ancho, sin restringir funcionalidades.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return switch (ResponsiveUtils.sizeOf(context)) {
      DeviceSize.mobile => mobile,
      DeviceSize.tablet => tablet ?? mobile,
      DeviceSize.desktop => desktop ?? tablet ?? mobile,
    };
  }
}
