import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class ModuleCard extends StatelessWidget {
  final String name;
  final String? description;
  final String? imageUrl;
  final VoidCallback onTap;

  const ModuleCard({
    super.key,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;
    final radius = isTablet ? 24.0 : 20.0;
    final height = isTablet ? 235.0 : 205.0;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Semantics(
      button: true,
      label: 'Open $name module',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.10),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The image now occupies the entire card instead of a small
                // left-side thumbnail.
                hasImage
                    ? Image.network(
                        imageUrl!.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const _ModulePlaceholder(),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const _ModulePlaceholder(loading: true);
                        },
                      )
                    : const _ModulePlaceholder(),

                // Dark gradient keeps the text readable while preserving the
                // image underneath.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.42, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                ),

                // Module badge.
                Positioned(
                  top: isTablet ? 14 : 12,
                  left: isTablet ? 14 : 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 11 : 9,
                      vertical: isTablet ? 7 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: isTablet ? 17 : 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'MODULE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isTablet ? 10.5 : 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Open arrow.
                Positioned(
                  top: isTablet ? 14 : 12,
                  right: isTablet ? 14 : 12,
                  child: Container(
                    width: isTablet ? 40 : 36,
                    height: isTablet ? 40 : 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: isTablet ? 21 : 19,
                    ),
                  ),
                ),

                // Text sits directly on the image at the bottom.
                Positioned(
                  left: isTablet ? 18 : 15,
                  right: isTablet ? 18 : 15,
                  bottom: isTablet ? 17 : 15,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 21 : 18,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          letterSpacing: -0.2,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      if (description != null &&
                          description!.trim().isNotEmpty) ...[
                        SizedBox(height: isTablet ? 7 : 5),
                        Text(
                          description!.trim(),
                          maxLines: isTablet ? 2 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontSize: isTablet ? 13.5 : 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 7,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: isTablet ? 10 : 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Open Module',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTablet ? 12.5 : 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: isTablet ? 16 : 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModulePlaceholder extends StatelessWidget {
  final bool loading;

  const _ModulePlaceholder({this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.82),
            AppColors.primary.withValues(alpha: 0.40),
          ],
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.menu_book_rounded,
                size: 50,
                color: Colors.white.withValues(alpha: 0.30),
              ),
      ),
    );
  }
}
