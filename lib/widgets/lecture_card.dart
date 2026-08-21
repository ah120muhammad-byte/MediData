import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/lecture_files_service.dart';
import '../../services/lectures_service.dart';
import 'lecture_file_tile.dart';

// ============================================================================
// LECTURE CARD
// ============================================================================
//
// Expandable card: gradient header (title + subtitle) + the lecture's
// files listed inline underneath. Mirrors the "الدروس" reference design,
// reskinned with AppColors.primary and the app's existing card language
// (see level_card.dart / home_screen.dart _YourModuleCard).

class LectureCard extends StatefulWidget {
  final Lecture lecture;
  final void Function(LectureFile file) onOpenFile;
  final bool initiallyExpanded;

  const LectureCard({
    super.key,
    required this.lecture,
    required this.onOpenFile,
    this.initiallyExpanded = false,
  });

  @override
  State<LectureCard> createState() => _LectureCardState();
}

class _LectureCardState extends State<LectureCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(isTablet ? 22 : 18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ====================================================
          // HEADER (tap to expand/collapse)
          // ====================================================
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 18 : 15,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.80),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.lecture.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (widget.lecture.subtitle != null &&
                              widget.lecture.subtitle!.trim().isNotEmpty) ...[
                            SizedBox(height: isTablet ? 6 : 4),
                            Text(
                              widget.lecture.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isTablet ? 13 : 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: isTablet ? 12 : 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ====================================================
          // FILES (inline, no extra screen hop)
          // ====================================================
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeInOut,
            secondCurve: Curves.easeInOut,
            sizeCurve: Curves.easeInOut,
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: widget.lecture.files.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    child: Text(
                      'No content added for this lecture yet.',
                      style: TextStyle(
                        fontSize: isTablet ? 13 : 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isTablet ? 10 : 8,
                    ),
                    child: Column(
                      children: widget.lecture.files
                          .map(
                            (file) => LectureFileTile(
                              file: file,
                              isTablet: isTablet,
                              onTap: () => widget.onOpenFile(file),
                            ),
                          )
                          .toList(),
                    ),
                  ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
