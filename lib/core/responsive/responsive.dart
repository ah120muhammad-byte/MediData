import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  // ==========================================================================
  // BREAKPOINTS
  // ==========================================================================

  /// Phone
  static const double phoneBreakpoint = 600;

  /// Tablet
  static const double tabletBreakpoint = 900;

  /// Large screen
  static const double largeBreakpoint = 1200;

  // ==========================================================================
  // DEVICE TYPE
  // ==========================================================================

  static bool isPhone(BuildContext context) {
    return MediaQuery.sizeOf(context).width < phoneBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return width >= phoneBreakpoint &&
        width < tabletBreakpoint;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.sizeOf(context).width >=
        tabletBreakpoint;
  }

  // ==========================================================================
  // ORIENTATION
  // ==========================================================================

  static bool isPortrait(BuildContext context) {
    return MediaQuery.orientationOf(context) ==
        Orientation.portrait;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) ==
        Orientation.landscape;
  }

  // ==========================================================================
  // SCREEN SIZE
  // ==========================================================================

  static double width(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }

  static double height(BuildContext context) {
    return MediaQuery.sizeOf(context).height;
  }

  // ==========================================================================
  // RESPONSIVE VALUE
  // ==========================================================================

  /// Returns a different value depending on the available screen width.
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? large,
  }) {
    final screenWidth =
        MediaQuery.sizeOf(context).width;

    if (screenWidth < phoneBreakpoint) {
      return phone;
    }

    if (screenWidth < tabletBreakpoint) {
      return tablet ?? phone;
    }

    return large ?? tablet ?? phone;
  }

  // ==========================================================================
  // RESPONSIVE WIDTH
  // ==========================================================================

  /// Returns a percentage of the available width.
  static double widthPercent(
    BuildContext context,
    double percent,
  ) {
    return width(context) * percent;
  }

  // ==========================================================================
  // RESPONSIVE HEIGHT
  // ==========================================================================

  /// Returns a percentage of the available height.
  static double heightPercent(
    BuildContext context,
    double percent,
  ) {
    return height(context) * percent;
  }

  // ==========================================================================
  // CONTENT WIDTH
  // ==========================================================================

  /// Calculates a sensible maximum content width.
  ///
  /// Phone:
  ///     Full available width.
  ///
  /// Tablet:
  ///     Maximum 520.
  ///
  /// Large screen:
  ///     Maximum 560.
  static double contentWidth(
    BuildContext context,
  ) {
    final screenWidth =
        MediaQuery.sizeOf(context).width;

    if (screenWidth < phoneBreakpoint) {
      return screenWidth;
    }

    if (screenWidth < tabletBreakpoint) {
      return 520;
    }

    return 560;
  }

  // ==========================================================================
  // HORIZONTAL PADDING
  // ==========================================================================

  static double horizontalPadding(
    BuildContext context,
  ) {
    return value<double>(
      context,
      phone: 20,
      tablet: 32,
      large: 40,
    );
  }

  // ==========================================================================
  // CARD PADDING
  // ==========================================================================

  static double cardPadding(
    BuildContext context,
  ) {
    return value<double>(
      context,
      phone: 18,
      tablet: 24,
      large: 28,
    );
  }

  // ==========================================================================
  // FIELD HEIGHT
  // ==========================================================================

  static double fieldHeight(
    BuildContext context,
  ) {
    return value<double>(
      context,
      phone: 50,
      tablet: 54,
      large: 56,
    );
  }

  // ==========================================================================
  // BUTTON HEIGHT
  // ==========================================================================

  static double buttonHeight(
    BuildContext context,
  ) {
    return value<double>(
      context,
      phone: 52,
      tablet: 56,
      large: 58,
    );
  }

  // ==========================================================================
  // LOGO SIZE
  // ==========================================================================

  static double logoSize(
    BuildContext context,
  ) {
    return value<double>(
      context,
      phone: 64,
      tablet: 76,
      large: 84,
    );
  }

  // ==========================================================================
  // CARD RADIUS
  // ==========================================================================

  static double cardRadius(
    BuildContext context,
  ) {
    return value<double>(
      context,
      phone: 24,
      tablet: 28,
      large: 30,
    );
  }

  // ==========================================================================
  // KEYBOARD
  // ==========================================================================

  static bool keyboardIsOpen(
    BuildContext context,
  ) {
    return MediaQuery.viewInsetsOf(context).bottom >
        0;
  }
}