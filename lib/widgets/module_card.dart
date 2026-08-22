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
    final isDark = theme.brightness == Brightness.dark;

    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;

    final radius = isTablet ? 20.0 : 17.0;

    final hasImage =
        imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark ? 0.20 : 0.065,
                ),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // ==============================================================
              // IMAGE
              // ==============================================================

              SizedBox(
                width: isTablet ? 145 : 112,
                height: isTablet ? 145 : 118,
                child: hasImage
                    ? Image.network(
                        imageUrl!.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          return const _ModulePlaceholder();
                        },
                        loadingBuilder: (
                          context,
                          child,
                          loadingProgress,
                        ) {
                          if (loadingProgress == null) {
                            return child;
                          }

                          return const _ModulePlaceholder(
                            loading: true,
                          );
                        },
                      )
                    : const _ModulePlaceholder(),
              ),

              // ==============================================================
              // CONTENT
              // ==============================================================

              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 18 : 14,
                    isTablet ? 16 : 13,
                    isTablet ? 14 : 11,
                    isTablet ? 16 : 13,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ------------------------------------------------------
                      // NAME
                      // ------------------------------------------------------

                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),

                      // ------------------------------------------------------
                      // DESCRIPTION
                      // ------------------------------------------------------

                      if (description != null &&
                          description!.trim().isNotEmpty) ...[
                        SizedBox(
                          height: isTablet ? 7 : 6,
                        ),
                        Text(
                          description!.trim(),
                          maxLines: isTablet ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isTablet ? 13 : 12,
                            height: 1.35,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.56),
                          ),
                        ),
                      ],

                      SizedBox(
                        height: isTablet ? 11 : 9,
                      ),

                      // ------------------------------------------------------
                      // OPEN MODULE
                      // ------------------------------------------------------

                      Row(
                        children: [
                          Text(
                            'Open Module',
                            style: TextStyle(
                              fontSize: isTablet ? 13 : 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: isTablet ? 17 : 15,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PLACEHOLDER
// ============================================================================

class _ModulePlaceholder extends StatelessWidget {
  final bool loading;

  const _ModulePlaceholder({
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.80),
            AppColors.primary.withValues(alpha: 0.40),
          ],
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.menu_book_rounded,
                size: 42,
                color: Colors.white.withValues(alpha: 0.28),
              ),
      ),
    );
  }
}
