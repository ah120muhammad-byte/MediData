
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

 @override
 Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final size = MediaQuery.sizeOf(context);
  final isTablet = size.shortestSide >= 600;

  final horizontalPadding = isTablet ? 32.0 : 20.0;

  return LayoutBuilder(
    builder: (context, constraints) {
      final contentWidth = isTablet
          ? 850.0
          : constraints.maxWidth;

      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: contentWidth,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isTablet ? 28 : 22,
              horizontalPadding,
              isTablet ? 130 : 115,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ======================================================
                // WHAT'S NEW
                // ======================================================

                Text(
                  "What's New",
                  style: TextStyle(
                    fontSize: isTablet ? 25 : 21,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                SizedBox(
                  height: isTablet ? 16 : 12,
                ),

                _LatestLectureCard(
                  isTablet: isTablet,
                ),

                SizedBox(
                  height: isTablet ? 34 : 28,
                ),

                // ======================================================
                // YOUR MODULE
                // ======================================================

                Text(
                  'Your Module',
                  style: TextStyle(
                    fontSize: isTablet ? 25 : 21,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                SizedBox(
                  height: isTablet ? 16 : 12,
                ),

                _YourModuleCard(
                  isTablet: isTablet,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
 }
 }



// ============================================================================
// LATEST LECTURE CARD
// ============================================================================

class _LatestLectureCard extends StatelessWidget {
  final bool isTablet;

  const _LatestLectureCard({
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isTablet ? 22 : 17,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(
          isTablet ? 24 : 20,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark
                  ? 0.20
                  : 0.07,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isTablet ? 72 : 58,
            height: isTablet ? 72 : 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(
                isTablet ? 20 : 16,
              ),
            ),
            child: Icon(
              Icons.play_lesson_outlined,
              size: isTablet ? 34 : 28,
              color: AppColors.primary,
            ),
          ),

          SizedBox(
            width: isTablet ? 18 : 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Latest Lecture',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'The latest lecture will appear here.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 12.5,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface
                .withValues(alpha: 0.45),
            size: isTablet ? 30 : 25,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// YOUR MODULE CARD
// ============================================================================

class _YourModuleCard extends StatelessWidget {
  final bool isTablet;

  const _YourModuleCard({
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isTablet ? 24 : 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(
              alpha: 0.78,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(
          isTablet ? 26 : 21,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(
              alpha: 0.22,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isTablet ? 58 : 50,
                height: isTablet ? 58 : 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.18,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: isTablet ? 30 : 26,
                ),
              ),

              SizedBox(
                width: isTablet ? 16 : 13,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Module',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.white.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      'Your College Module',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTablet ? 21 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: isTablet ? 20 : 17,
              ),
            ],
          ),

          SizedBox(
            height: isTablet ? 24 : 20,
          ),

          Text(
            'Module Progress',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(
                alpha: 0.80,
              ),
            ),
          ),

          const SizedBox(height: 9),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: 0.0,
              minHeight: isTablet ? 8 : 7,
              backgroundColor: Colors.white.withValues(
                alpha: 0.20,
              ),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Your module information will appear here.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isTablet ? 13 : 11.5,
              color: Colors.white.withValues(
                alpha: 0.75,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
