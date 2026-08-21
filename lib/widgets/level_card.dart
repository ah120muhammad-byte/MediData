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

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isTablet ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(
          isTablet ? 24 : 18,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.22 : 0.07,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ================================================================
          // IMAGE
          // ================================================================

          ClipRRect(
            borderRadius: BorderRadius.circular(
              isTablet ? 18 : 15,
            ),
            child: AspectRatio(
              aspectRatio: 16 / 8.8,
              child: _LevelImage(
                imageUrl: imageUrl,
                isDark: isDark,
              ),
            ),
          ),

          SizedBox(
            height: isTablet ? 18 : 14,
          ),

          // ================================================================
          // LEVEL NAME
          // ================================================================

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 6 : 4,
            ),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: isTablet ? 23 : 19,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          SizedBox(
            height: isTablet ? 10 : 8,
          ),

          // ================================================================
          // MODULE COUNT
          // ================================================================

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 6 : 4,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: isTablet ? 18 : 16,
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: 0.55,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$moduleCount '
                  '${moduleCount == 1 ? 'Module' : 'Modules'}',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12.5,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: 0.58,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ================================================================
          // DESCRIPTION
          // ================================================================

          if (description != null &&
              description!.trim().isNotEmpty) ...[
            SizedBox(
              height: isTablet ? 8 : 6,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 6 : 4,
              ),
              child: Text(
                description!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isTablet ? 14 : 12.5,
                  height: 1.45,
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: 0.58,
                  ),
                ),
              ),
            ),
          ],

          SizedBox(
            height: isTablet ? 18 : 15,
          ),

          // ================================================================
          // ENTER BUTTON
          // ================================================================

          SizedBox(
            height: isTablet ? 58 : 52,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary,
                  width: 1.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    isTablet ? 17 : 14,
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 22 : 18,
                ),
              ),
              child: Text(
                'Open Level',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
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
      return _PlaceholderImage(
        isDark: isDark,
      );
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
// PLACEHOLDER IMAGE
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
            AppColors.primary.withValues(
              alpha: 0.85,
            ),
            AppColors.primary.withValues(
              alpha: 0.45,
            ),
          ],
        ),
      ),
      child: Center(
        child: showLoading
            ? SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(
                    alpha: 0.9,
                  ),
                ),
              )
            : Icon(
                Icons.school_rounded,
                size: 60,
                color: Colors.white.withValues(
                  alpha: 0.25,
                ),
              ),
      ),
    );
  }
}

