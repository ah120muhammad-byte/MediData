import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/download_service.dart';

enum LectureFileType { pdf, audio, video }

class LectureFile {
  final LectureFileType type;
  final String title;
  final String subtitle;
  final String path;

  const LectureFile({required this.type, required this.title, required this.subtitle, required this.path});

  IconData get icon {
    switch (type) {
      case LectureFileType.pdf: return Icons.picture_as_pdf_rounded;
      case LectureFileType.audio: return Icons.headphones_rounded;
      case LectureFileType.video: return Icons.play_circle_fill_rounded;
    }
  }

  String get actionLabel {
    switch (type) {
      case LectureFileType.pdf: return 'Open';
      case LectureFileType.audio: return 'Play';
      case LectureFileType.video: return 'Watch';
    }
  }
}

class LectureExam {
  final String id;
  final String lectureId;
  final String title;
  final String? description;
  final int durationMinutes;
  final int passingScore;
  final bool isActive;

  const LectureExam({required this.id, required this.lectureId, required this.title, this.description, required this.durationMinutes, required this.passingScore, required this.isActive});
}

class LectureCard extends StatelessWidget {
  final String title;
  final String? description;
  final List<LectureFile> files;
  final LectureExam? exam;
  final bool expanded;
  final bool isTablet;
  final VoidCallback onTap;
  final ValueChanged<LectureFile>? onFileOpen;
  final ValueChanged<LectureFile>? onFileDownload;
  final VoidCallback? onStartExam;

  const LectureCard({super.key, required this.title, required this.description, required this.files, required this.expanded, required this.isTablet, required this.onTap, this.exam, this.onFileOpen, this.onFileDownload, this.onStartExam});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = isTablet ? 21.0 : 17.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: expanded ? AppColors.primary.withValues(alpha: 0.30) : theme.colorScheme.onSurface.withValues(alpha: 0.05), width: expanded ? 1.2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.055), blurRadius: expanded ? 16 : 12, offset: const Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _LectureHeader(title: title, description: description, expanded: expanded, isTablet: isTablet, onTap: onTap),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeOut,
            sizeCurve: Curves.easeOut,
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _LectureContentSection(files: files, exam: exam, isTablet: isTablet, onFileOpen: onFileOpen, onFileDownload: onFileDownload, onStartExam: onStartExam),
          ),
        ],
      ),
    );
  }
}

class _LectureHeader extends StatelessWidget {
  final String title;
  final String? description;
  final bool expanded;
  final bool isTablet;
  final VoidCallback onTap;

  const _LectureHeader({required this.title, required this.description, required this.expanded, required this.isTablet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 18 : 14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isTablet ? 58 : 50,
                height: isTablet ? 58 : 50,
                decoration: BoxDecoration(color: expanded ? AppColors.primary : AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(isTablet ? 17 : 14)),
                child: Icon(Icons.play_lesson_rounded, size: isTablet ? 30 : 26, color: expanded ? Colors.white : AppColors.primary),
              ),
              SizedBox(width: isTablet ? 15 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isTablet ? 18 : 16, fontWeight: FontWeight.w800, height: 1.15, color: theme.colorScheme.onSurface)),
                    if (description != null && description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(description!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isTablet ? 13 : 12, height: 1.35, color: theme.colorScheme.onSurface.withValues(alpha: 0.56))),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(turns: expanded ? 0.5 : 0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut, child: Icon(Icons.keyboard_arrow_down_rounded, size: isTablet ? 30 : 26, color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
            ],
          ),
        ),
      ),
    );
  }
}

class _LectureContentSection extends StatelessWidget {
  final List<LectureFile> files;
  final LectureExam? exam;
  final bool isTablet;
  final ValueChanged<LectureFile>? onFileOpen;
  final ValueChanged<LectureFile>? onFileDownload;
  final VoidCallback? onStartExam;

  const _LectureContentSection({required this.files, required this.exam, required this.isTablet, this.onFileOpen, this.onFileDownload, this.onStartExam});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFiles = files.isNotEmpty;
    final hasExam = exam != null && exam!.isActive;

    if (!hasFiles && !hasExam) {
      return Padding(
        padding: EdgeInsets.fromLTRB(isTablet ? 18 : 14, 0, isTablet ? 18 : 14, isTablet ? 18 : 14),
        child: Column(children: [Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.06)), const SizedBox(height: 14), Text('No content available for this lecture.', style: TextStyle(fontSize: isTablet ? 13 : 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.52)))],),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(isTablet ? 18 : 14, 0, isTablet ? 18 : 14, isTablet ? 18 : 14),
      child: Column(
        children: [
          Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
          if (hasFiles) ...[
            const SizedBox(height: 10),
            ...List.generate(files.length, (index) {
              final file = files[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == files.length - 1 ? 10 : 8),
                child: _LectureFileTile(file: file, isTablet: isTablet, onOpen: onFileOpen == null ? null : () => onFileOpen!(file), onDownload: onFileDownload == null ? null : () => onFileDownload!(file)),
              );
            }),
          ],
          if (hasExam) _LectureExamTile(exam: exam!, isTablet: isTablet, onStartExam: onStartExam),
        ],
      ),
    );
  }
}

class _LectureFileTile extends StatelessWidget {
  final LectureFile file;
  final bool isTablet;
  final VoidCallback? onOpen;
  final VoidCallback? onDownload;

  const _LectureFileTile({required this.file, required this.isTablet, required this.onOpen, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloads = DownloadsService.instance;

    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: downloads.progressNotifier,
      builder: (context, progressMap, _) {
        final progress = progressMap[file.path];
        final isDownloading = progress != null;
        final percent = ((progress ?? 0) * 100).round();

        return Container(
          padding: EdgeInsets.fromLTRB(isTablet ? 13 : 10, isTablet ? 13 : 10, isTablet ? 13 : 10, isDownloading ? 9 : isTablet ? 13 : 10),
          decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.035), borderRadius: BorderRadius.circular(isTablet ? 15 : 13)),
          child: Column(
            children: [
              Row(
                children: [
                  Container(width: isTablet ? 48 : 43, height: isTablet ? 48 : 43, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(isTablet ? 13 : 11)), child: Icon(file.icon, size: isTablet ? 25 : 22, color: AppColors.primary)),
                  SizedBox(width: isTablet ? 12 : 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(file.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isTablet ? 15 : 13.5, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)), const SizedBox(height: 3), Text(isDownloading ? 'Downloading… $percent%' : file.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isTablet ? 12 : 11, color: theme.colorScheme.onSurface.withValues(alpha: isDownloading ? 0.70 : 0.48)))],)),
                  const SizedBox(width: 6),
                  Material(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(isTablet ? 12 : 10), child: InkWell(onTap: isDownloading ? null : onOpen, borderRadius: BorderRadius.circular(isTablet ? 12 : 10), child: Padding(padding: EdgeInsets.symmetric(horizontal: isTablet ? 11 : 9, vertical: isTablet ? 9 : 8), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(_actionIcon(file.type), size: isTablet ? 18 : 16, color: AppColors.primary), const SizedBox(width: 4), Text(file.actionLabel, style: TextStyle(fontSize: isTablet ? 12 : 10.5, fontWeight: FontWeight.w700, color: AppColors.primary))])))),
                  const SizedBox(width: 4),
                  isDownloading
                      ? SizedBox(width: isTablet ? 38 : 34, height: isTablet ? 38 : 34, child: Stack(alignment: Alignment.center, children: [SizedBox(width: isTablet ? 27 : 24, height: isTablet ? 27 : 24, child: CircularProgressIndicator(value: progress.clamp(0.0, 1.0), strokeWidth: 2.7)), Text('$percent', style: TextStyle(fontSize: isTablet ? 8 : 7.5, fontWeight: FontWeight.w800))]))
                      : IconButton(tooltip: 'Download', onPressed: onDownload, visualDensity: VisualDensity.compact, icon: Icon(Icons.download_rounded, size: isTablet ? 23 : 21, color: theme.colorScheme.onSurface.withValues(alpha: 0.58))),
                ],
              ),
              if (isDownloading) ...[
                const SizedBox(height: 7),
                ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 4)),
              ],
            ],
          ),
        );
      },
    );
  }

  IconData _actionIcon(LectureFileType type) {
    switch (type) {
      case LectureFileType.pdf: return Icons.open_in_new_rounded;
      case LectureFileType.audio: return Icons.play_arrow_rounded;
      case LectureFileType.video: return Icons.play_arrow_rounded;
    }
  }
}

class _LectureExamTile extends StatelessWidget {
  final LectureExam exam;
  final bool isTablet;
  final VoidCallback? onStartExam;

  const _LectureExamTile({required this.exam, required this.isTablet, required this.onStartExam});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(isTablet ? 14 : 11),
      decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(isTablet ? 16 : 14), border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.14))),
      child: Row(
        children: [
          Container(width: isTablet ? 48 : 43, height: isTablet ? 48 : 43, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(isTablet ? 14 : 12)), child: Icon(Icons.assignment_rounded, size: isTablet ? 25 : 22, color: theme.colorScheme.onPrimary)),
          SizedBox(width: isTablet ? 13 : 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(exam.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isTablet ? 15 : 14, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)), const SizedBox(height: 4), Row(children: [Icon(Icons.timer_outlined, size: isTablet ? 16 : 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)), const SizedBox(width: 4), Text('${exam.durationMinutes} min', style: TextStyle(fontSize: isTablet ? 12 : 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.55))), const SizedBox(width: 10), Icon(Icons.check_circle_outline_rounded, size: isTablet ? 16 : 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)), const SizedBox(width: 4), Text('Pass ${exam.passingScore}%', style: TextStyle(fontSize: isTablet ? 12 : 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.55)))])])),
          const SizedBox(width: 8),
          FilledButton(onPressed: onStartExam, style: FilledButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: isTablet ? 14 : 11, vertical: isTablet ? 11 : 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTablet ? 12 : 10))), child: Text('Start Exam', style: TextStyle(fontSize: isTablet ? 12 : 11, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
