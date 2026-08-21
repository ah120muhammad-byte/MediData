import 'package:flutter/material.dart';

import 'responsive.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget? large;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.large,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isPhone(context)) {
      return phone;
    }

    if (Responsive.isTablet(context)) {
      return tablet ?? phone;
    }

    return large ?? tablet ?? phone;
  }
}