import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  // ==========================================================================
  // SCREEN SIZE
  // ==========================================================================

  static double width(
    BuildContext context,
  ) {
    return MediaQuery.sizeOf(context).width;
  }

  static double height(
    BuildContext context,
  ) {
    return MediaQuery.sizeOf(context).height;
  }

  static Size size(
    BuildContext context,
  ) {
    return MediaQuery.sizeOf(context);
  }

  // ==========================================================================
  // DEVICE TYPE
  // ==========================================================================

  static bool isPhone(
    BuildContext context,
  ) {
    return width(context) < 600;
  }

  static bool isTablet(
    BuildContext context,
  ) {
    final currentWidth = width(context);

    return currentWidth >= 600 &&
        currentWidth < 1024;
  }

  static bool isLargeScreen(
    BuildContext context,
  ) {
    return width(context) >= 1024;
  }

  // ==========================================================================
  // ORIENTATION
  // ==========================================================================

  static bool isPortrait(
    BuildContext context,
  ) {
    return MediaQuery.orientationOf(context) ==
        Orientation.portrait;
  }

  static bool isLandscape(
    BuildContext context,
  ) {
    return MediaQuery.orientationOf(context) ==
        Orientation.landscape;
  }

  // ==========================================================================
  // SCALE
  // ==========================================================================

  static double scale(
    BuildContext context, {
    double referenceWidth = 390,
    double min = 0.85,
    double max = 1.25,
  }) {
    final currentWidth =
        width(context);

    final raw =
        currentWidth /
        referenceWidth;

    if (raw < min) {
      return min;
    }

    if (raw > max) {
      return max;
    }

    return raw;
  }

  // ==========================================================================
  // SCALE VALUE
  // ==========================================================================

  static double scaleValue(
    BuildContext context,
    double base, {
    double referenceWidth = 390,
    double minScale = 0.85,
    double maxScale = 1.25,
  }) {
    return base *
        scale(
          context,
          referenceWidth:
              referenceWidth,
          min:
              minScale,
          max:
              maxScale,
        );
  }

  // ==========================================================================
  // CLAMPED VALUE
  // ==========================================================================

  static double clamped(
    BuildContext context, {
    required double base,
    double referenceWidth = 390,
    double min = 0,
    double max = double.infinity,
  }) {
    final result =
        scaleValue(
      context,
      base,
      referenceWidth:
          referenceWidth,
      minScale:
          0.85,
      maxScale:
          1.25,
    );

    if (result < min) {
      return min;
    }

    if (result > max) {
      return max;
    }

    return result;
  }

  // ==========================================================================
  // CLAMPED OFFSET
  // ==========================================================================

  static Offset clampedOffset(
    BuildContext context, {
    required Offset base,
    double referenceWidth = 390,
    double minScale = 0.85,
    double maxScale = 1.25,
  }) {
    final currentScale =
        scale(
      context,
      referenceWidth:
          referenceWidth,
      min:
          minScale,
      max:
          maxScale,
    );

    return Offset(
      base.dx * currentScale,
      base.dy * currentScale,
    );
  }

  // ==========================================================================
  // RESPONSIVE VALUE
  // ==========================================================================
  //
  // Compatibility helper for existing screens.
  //
  // ==========================================================================

  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? large,
  }) {
    final currentWidth =
        width(context);

    if (currentWidth < 600) {
      return phone;
    }

    if (currentWidth < 1024) {
      return tablet ??
          phone;
    }

    return large ??
        tablet ??
        phone;
  }

  // ==========================================================================
  // WIDTH PERCENT
  // ==========================================================================

  static double widthPercent(
    BuildContext context,
    double percent,
  ) {
    return width(context) *
        percent;
  }

  // ==========================================================================
  // HEIGHT PERCENT
  // ==========================================================================

  static double heightPercent(
    BuildContext context,
    double percent,
  ) {
    return height(context) *
        percent;
  }

  // ==========================================================================
  // HORIZONTAL PADDING
  // ==========================================================================

  static double horizontalPadding(
    BuildContext context,
  ) {
    final currentWidth =
        width(context);

    final calculated =
        currentWidth * 0.05;

    if (calculated < 16) {
      return 16;
    }

    if (calculated > 48) {
      return 48;
    }

    return calculated;
  }

  // ==========================================================================
  // VERTICAL PADDING
  // ==========================================================================

  static double verticalPadding(
    BuildContext context,
  ) {
    final currentHeight =
        height(context);

    final calculated =
        currentHeight * 0.025;

    if (calculated < 12) {
      return 12;
    }

    if (calculated > 32) {
      return 32;
    }

    return calculated;
  }

  // ==========================================================================
  // CONTENT WIDTH
  // ==========================================================================

  static double contentWidth(
    BuildContext context,
  ) {
    final currentWidth =
        width(context);

    final horizontal =
        horizontalPadding(
      context,
    );

    final available =
        currentWidth -
        (horizontal * 2);

    if (available <= 0) {
      return currentWidth;
    }

    final maxContent =
        currentWidth *
        0.92;

    if (maxContent < 280) {
      return available.clamp(
        0,
        280,
      );
    }

    if (maxContent > 1200) {
      return 1200;
    }

    return maxContent;
  }

  // ==========================================================================
  // FORM WIDTH
  // ==========================================================================

  static double formWidth(
    BuildContext context,
  ) {
    final currentWidth =
        width(context);

    final horizontal =
        horizontalPadding(
      context,
    );

    final available =
        currentWidth -
        (horizontal * 2);

    final desired =
        currentWidth * 0.72;

    if (desired < 280) {
      return available;
    }

    if (desired > available) {
      return available;
    }

    return desired;
  }

  // ==========================================================================
  // CARD PADDING
  // ==========================================================================

  static double cardPadding(
    BuildContext context,
  ) {
    return clamped(
      context,
      base:
          18,
      min:
          14,
      max:
          32,
    );
  }

  // ==========================================================================
  // FIELD HEIGHT
  // ==========================================================================

  static double fieldHeight(
    BuildContext context,
  ) {
    return clamped(
      context,
      base:
          50,
      min:
          48,
      max:
          60,
    );
  }

  // ==========================================================================
  // BUTTON HEIGHT
  // ==========================================================================

  static double buttonHeight(
    BuildContext context,
  ) {
    return clamped(
      context,
      base:
          52,
      min:
          48,
      max:
          62,
    );
  }

  // ==========================================================================
  // ICON SIZE
  // ==========================================================================

  static double iconSize(
    BuildContext context, {
    double base = 24,
    double min = 20,
    double max = 34,
  }) {
    return clamped(
      context,
      base:
          base,
      min:
          min,
      max:
          max,
    );
  }

  // ==========================================================================
  // TITLE SIZE
  // ==========================================================================

  static double titleSize(
    BuildContext context, {
    double base = 22,
    double min = 18,
    double max = 32,
  }) {
    return clamped(
      context,
      base:
          base,
      min:
          min,
      max:
          max,
    );
  }

  // ==========================================================================
  // BODY TEXT
  // ==========================================================================

  static double bodyTextSize(
    BuildContext context, {
    double base = 14,
    double min = 12,
    double max = 18,
  }) {
    return clamped(
      context,
      base:
          base,
      min:
          min,
      max:
          max,
    );
  }

  // ==========================================================================
  // SMALL TEXT
  // ==========================================================================

  static double smallTextSize(
    BuildContext context, {
    double base = 12,
    double min = 10,
    double max = 15,
  }) {
    return clamped(
      context,
      base:
          base,
      min:
          min,
      max:
          max,
    );
  }

  // ==========================================================================
  // LOGO SIZE
  // ==========================================================================

  static double logoSize(
    BuildContext context,
  ) {
    return clamped(
      context,
      base:
          64,
      min:
          54,
      max:
          96,
    );
  }

  // ==========================================================================
  // AVATAR SIZE
  // ==========================================================================

  static double avatarSize(
    BuildContext context, {
    double base = 68,
  }) {
    return clamped(
      context,
      base:
          base,
      min:
          48,
      max:
          88,
    );
  }

  // ==========================================================================
  // CARD RADIUS
  // ==========================================================================

  static double cardRadius(
    BuildContext context,
  ) {
    return clamped(
      context,
      base:
          24,
      min:
          16,
      max:
          32,
    );
  }

  // ==========================================================================
  // SMALL RADIUS
  // ==========================================================================

  static double smallRadius(
    BuildContext context,
  ) {
    return clamped(
      context,
      base:
          14,
      min:
          10,
      max:
          20,
    );
  }

  // ==========================================================================
  // GRID COLUMNS
  // ==========================================================================

  static int gridColumns(
    BuildContext context, {
    double minItemWidth = 280,
    int minColumns = 1,
    int maxColumns = 4,
  }) {
    final currentWidth =
        width(context);

    final horizontal =
        horizontalPadding(
          context,
        ) *
        2;

    final available =
        currentWidth -
        horizontal;

    if (available <= 0) {
      return minColumns;
    }

    final calculated =
        (available /
                minItemWidth)
            .floor();

    if (calculated < minColumns) {
      return minColumns;
    }

    if (calculated > maxColumns) {
      return maxColumns;
    }

    return calculated;
  }

  // ==========================================================================
  // LIST ITEM HEIGHT
  // ==========================================================================

  static double listItemHeight(
    BuildContext context, {
    double base = 72,
    double min = 60,
    double max = 96,
  }) {
    return clamped(
      context,
      base:
          base,
      min:
          min,
      max:
          max,
    );
  }

  // ==========================================================================
  // SPACING
  // ==========================================================================

  static double spacing(
    BuildContext context, {
    double base = 16,
    double min = 8,
    double max = 32,
  }) {
    return clamped(
      context,
      base:
          base,
      min:
          min,
      max:
          max,
    );
  }

  // ==========================================================================
  // MEDIA HEIGHT
  // ==========================================================================

  static double mediaHeight(
    BuildContext context, {
    double aspectRatio = 16 / 9,
    double min = 160,
    double max = 520,
  }) {
    final currentWidth =
        contentWidth(
      context,
    );

    final calculated =
        currentWidth /
        aspectRatio;

    if (calculated < min) {
      return min;
    }

    if (calculated > max) {
      return max;
    }

    return calculated;
  }

  // ==========================================================================
  // KEYBOARD
  // ==========================================================================

  static bool keyboardIsOpen(
    BuildContext context,
  ) {
    return MediaQuery
            .viewInsetsOf(context)
            .bottom >
        0;
  }

  // ==========================================================================
  // SAFE BOTTOM INSET
  // ==========================================================================

  static double bottomInset(
    BuildContext context,
  ) {
    return MediaQuery
        .paddingOf(context)
        .bottom;
  }

  // ==========================================================================
  // SAFE TOP INSET
  // ==========================================================================

  static double topInset(
    BuildContext context,
  ) {
    return MediaQuery
        .paddingOf(context)
        .top;
  }

  // ==========================================================================
  // SCROLL BOTTOM PADDING
  // ==========================================================================

  static double scrollBottomPadding(
    BuildContext context, {
    double base = 96,
  }) {
    final safeArea =
        bottomInset(
      context,
    );

    final calculated =
        base *
        scale(
          context,
          referenceWidth:
              390,
          min:
              0.90,
          max:
              1.15,
        );

    return calculated +
        safeArea;
  }

  // ==========================================================================
  // CONSTRAINED CONTENT
  // ==========================================================================

  static Widget constrained(
    BuildContext context, {
    required Widget child,
    double maxWidth = 1200,
    double minWidth = 0,
  }) {
    final horizontal =
        horizontalPadding(
      context,
    );

    final available =
        width(context) -
        (horizontal * 2);

    double finalWidth =
        available;

    if (finalWidth >
        maxWidth) {
      finalWidth =
          maxWidth;
    }

    if (finalWidth <
        minWidth) {
      finalWidth =
          minWidth;
    }

    return SizedBox(
      width:
          finalWidth,
      child:
          child,
    );
  }
}