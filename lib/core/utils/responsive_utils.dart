import 'package:flutter/widgets.dart';

/// Breakpoints oficiales. El dispositivo adapta layout, no permisos.
class AppBreakpoints {
  static const mobile = 600.0;
  static const tablet = 1024.0;
}

enum DeviceSize { mobile, tablet, desktop }

class ResponsiveUtils {
  static DeviceSize sizeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppBreakpoints.mobile) return DeviceSize.mobile;
    if (width < AppBreakpoints.tablet) return DeviceSize.tablet;
    return DeviceSize.desktop;
  }

  static bool isDesktop(BuildContext context) => sizeOf(context) == DeviceSize.desktop;
  static bool isTablet(BuildContext context) => sizeOf(context) == DeviceSize.tablet;
  static bool isMobile(BuildContext context) => sizeOf(context) == DeviceSize.mobile;
}
