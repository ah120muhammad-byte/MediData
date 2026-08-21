import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/lecture_files_service.dart';
import '../../services/lectures_service.dart';

// ============================================================================
// LECTURE FILE TILE
// ============================================================================
//
// One row inside an expanded LectureCard:
// [ pill action button ]   title   [ type icon ]

class LectureFileTile extends StatelessWidget {
  final LectureFile file;
  final VoidCallback onTap;
  final bool isTablet;

  const LectureFileTile({
    super.key,
    required this.file,
    required this.onTap,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 14 : 10,
        vertical: 5,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 14 : 12,
        vertical: isTablet ? 11 : 9,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          // ====================================================
          // TYPE ICON
          // ====================================================
          Container(
            width: isTablet ? 38 : 34,
            height: isTablet ? 38 : 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              file.icon,
              size: isTablet ? 19 : 17,
              color: AppColors.primary,
            ),
          ),

          SizedBox(width: isTablet ? 12 : 10),

          // ====================================================
          // TITLE
          // ====================================================
          Expanded(
            child: Text(
              file.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isTablet ? 14.5 : 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          SizedBox(width: isTablet ? 10 : 8),

          // ====================================================
          // ACTION BUTTON
          // ====================================================
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 13,
                vertical: isTablet ? 10 : 8,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isTablet ? 10 : 9),
              ),
            ),
            child: Text(
              file.actionLabel,
              style: TextStyle(
                fontSize: isTablet ? 12.5 : 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
