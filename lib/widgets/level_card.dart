import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class LevelCard extends StatelessWidget {
  final String name;
  final String? description;
  final String? imageUrl;
  final int moduleCount;
  final VoidCallback onTap;

  const LevelCard({
    super.key,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.moduleCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;

    final radius = isTablet ? 22.0 : 18.0;

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
                  alpha: isDark ? 0.22 : 0.07,
                ),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==============================================================
              // IMAGE
              // ==============================================================

              AspectRatio(
                aspectRatio: isTablet ? 2.15 : 1.85,
                child: _LevelImage(
                  imageUrl: imageUrl,
                  isDark: isDark,
                ),
              ),

              // ==============================================================
              // CONTENT
              // ==============================================================

              Padding(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 20 : 16,
                  isTablet ? 18 : 15,
                  isTablet ? 20 : 16,
                  isTablet ? 18 : 15,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --------------------------------------------------------
                    // NAME
                    // --------------------------------------------------------

                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTablet ? 22 : 19,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),

                    SizedBox(
                      height: isTablet ? 9 : 7,
                    ),

                    // --------------------------------------------------------
                    // MODULE COUNT
                    // --------------------------------------------------------

                    Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: isTablet ? 18 : 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '$moduleCount '
                          '${moduleCount == 1 ? 'Module' : 'Modules'}',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.58,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // --------------------------------------------------------
                    // DESCRIPTION
                    // --------------------------------------------------------

                    if (description != null &&
                        description!.trim().isNotEmpty) ...[
                      SizedBox(
                        height: isTablet ? 9 : 7,
                      ),
                      Text(
                        description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12.5,
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.56,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(
                      height: isTablet ? 16 : 13,
                    ),

                    // --------------------------------------------------------
                    // OPEN LEVEL
                    // --------------------------------------------------------

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: isTablet ? 52 : 46,
                            child: FilledButton(
                              onPressed: onTap,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    isTablet ? 15 : 13,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Open Level',
                                style: TextStyle(
                                  fontSize: isTablet ? 15 : 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // ------------------------------------------------------
                        // ARROW
                        // ------------------------------------------------------

                        Container(
                          width: isTablet ? 52 : 46,
                          height: isTablet ? 52 : 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(
                              isTablet ? 15 : 13,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: isTablet ? 24 : 21,
                            color: AppColors.primary,
                          ),
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
    );
  }
}

// ============================================================================
// LEVEL IMAGE
// ============================================================================

class _LevelImage extends StatelessWidget {
  final String? imageUrl;
  final bool isDark;

  const _LevelImage({
    required this.imageUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl?.trim();

    if (cleanUrl == null || cleanUrl.isEmpty) {
      return _PlaceholderImage(isDark: isDark);
    }

    return Image.network(
      cleanUrl,
      fit: BoxFit.cover,
      loadingBuilder: (
        context,
        child,
        loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }

        return _PlaceholderImage(
          isDark: isDark,
          showLoading: true,
        );
      },
      errorBuilder: (
        context,
        error,
        stackTrace,
      ) {
        return _PlaceholderImage(
          isDark: isDark,
        );
      },
    );
  }
}

// ============================================================================
// PLACEHOLDER
// ============================================================================

class _PlaceholderImage extends StatelessWidget {
  final bool isDark;
  final bool showLoading;

  const _PlaceholderImage({
    required this.isDark,
    this.showLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.85),
            AppColors.primary.withValues(alpha: 0.45),
          ],
        ),
      ),
      child: Center(
        child: showLoading
            ? const SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.school_rounded,
                size: 60,
                color: Colors.white.withValues(alpha: 0.25),
              ),
      ),
    );
  }
}