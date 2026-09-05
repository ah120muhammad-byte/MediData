import 'package:flutter/material.dart';

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

  IconData get actionIcon {
    switch (type) {
      case LectureFileType.pdf: return Icons.open_in_new_rounded;
      case LectureFileType.audio: return Icons.play_arrow_rounded;
      case LectureFileType.video: return Icons.play_arrow_rounded;
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
    final radius = isTablet ? 22.0 : 18.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(radius), boxShadow: [BoxShadow(color: theme.colorScheme.onSurface.withValues(alpha: 0.07), blurRadius: expanded ? 20 : 13, offset: const Offset(0, 6))]),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        _LectureGradientHeader(title: title, description: description, expanded: expanded, isTablet: isTablet, onTap: onTap),
        AnimatedCrossFade(duration: const Duration(milliseconds: 280), firstCurve: Curves.easeOut, secondCurve: Curves.easeOut, sizeCurve: Curves.easeOutCubic, crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst, firstChild: const SizedBox.shrink(), secondChild: _LectureContentSection(files: files, exam: exam, isTablet: isTablet, onFileOpen: onFileOpen, onFileDownload: onFileDownload, onStartExam: onStartExam)),
      ]),
    );
  }
}

class _LectureGradientHeader extends StatelessWidget {
  final String title;
  final String? description;
  final bool expanded;
  final bool isTablet;
  final VoidCallback onTap;

  const _LectureGradientHeader({required this.title, required this.description, required this.expanded, required this.isTablet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, child: Ink(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primary, secondary])), child: Padding(
      padding: EdgeInsets.fromLTRB(isTablet ? 20 : 15, isTablet ? 18 : 15, isTablet ? 20 : 15, isTablet ? 19 : 16),
      child: Row(textDirection: TextDirection.ltr, children: [
        Container(width: isTablet ? 54 : 47, height: isTablet ? 54 : 47, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(isTablet ? 16 : 14), border: Border.all(color: Colors.white.withValues(alpha: 0.22))), child: Icon(Icons.menu_book_rounded, size: isTablet ? 28 : 24, color: Colors.white)),
        SizedBox(width: isTablet ? 14 : 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left, style: TextStyle(fontSize: isTablet ? 18 : 16, fontWeight: FontWeight.w800, height: 1.2, color: Colors.white)),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(description!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left, style: TextStyle(fontSize: isTablet ? 13 : 11.5, height: 1.35, color: Colors.white.withValues(alpha: 0.82))),
          ],
        ])),
        const SizedBox(width: 9),
        AnimatedRotation(turns: expanded ? 0.5 : 0, duration: const Duration(milliseconds: 280), curve: Curves.easeOut, child: Container(width: isTablet ? 40 : 36, height: isTablet ? 40 : 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle), child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white))),
      ]),
    ))));
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
      return Padding(padding: EdgeInsets.all(isTablet ? 18 : 14), child: Center(child: Text('No content available for this lecture.', style: TextStyle(fontSize: isTablet ? 13 : 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.52))));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(isTablet ? 15 : 11, isTablet ? 14 : 11, isTablet ? 15 : 11, isTablet ? 17 : 13),
      child: Column(children: [
        if (hasFiles) ...List.generate(files.length, (index) {
          final file = files[index];
          return Padding(padding: EdgeInsets.only(bottom: index == files.length - 1 && !hasExam ? 0 : 9), child: _LectureFileTile(file: file, isTablet: isTablet, onOpen: onFileOpen == null ? null : () => onFileOpen!(file), onDownload: onFileDownload == null ? null : () => onFileDownload!(file)));
        }),
        if (hasExam) ...[
          if (hasFiles) const SizedBox(height: 2),
          _LectureExamTile(exam: exam!, isTablet: isTablet, onStartExam: onStartExam),
        ],
      ]),
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
    final primary = theme.colorScheme.primary;
    final downloads = DownloadsService.instance;

    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: downloads.progressNotifier,
      builder: (context, progressMap, _) {
        final progress = progressMap[file.path];
        final isDownloading = progress != null;
        final percent = ((progress ?? 0) * 100).round();

        return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
          child: Container(
            padding: EdgeInsets.fromLTRB(isTablet ? 11 : 9, isTablet ? 11 : 9, isTablet ? 13 : 11, isDownloading ? 9 : isTablet ? 11 : 9),
            decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(isTablet ? 16 : 14), border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.075)), boxShadow: [BoxShadow(color: theme.colorScheme.onSurface.withValues(alpha: 0.035), blurRadius: 7, offset: const Offset(0, 3))]),
            child: Column(children: [
              Row(textDirection: TextDirection.ltr, children: [
                Container(width: isTablet ? 44 : 39, height: isTablet ? 44 : 39, decoration: BoxDecoration(color: primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(isTablet ? 13 : 11)), child: Icon(file.icon, size: isTablet ? 23 : 20, color: primary)),
                SizedBox(width: isTablet ? 11 : 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(file.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left, style: TextStyle(fontSize: isTablet ? 15 : 13.5, fontWeight: FontWeight.w700, height: 1.2, color: theme.colorScheme.onSurface)), const SizedBox(height: 3), Text(isDownloading ? 'Downloading… $percent%' : file.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left, style: TextStyle(fontSize: isTablet ? 11.5 : 10.5, color: theme.colorScheme.onSurface.withValues(alpha: isDownloading ? 0.68 : 0.48)))])),
                const SizedBox(width: 8),
                if (isDownloading) SizedBox(width: isTablet ? 36 : 32, height: isTablet ? 36 : 32, child: Stack(alignment: Alignment.center, children: [SizedBox(width: isTablet ? 27 : 24, height: isTablet ? 27 : 24, child: CircularProgressIndicator(value: progress.clamp(0.0, 1.0), strokeWidth: 2.5)), Text('$percent', style: TextStyle(fontSize: isTablet ? 8 : 7, fontWeight: FontWeight.w800))])) else Icon(file.icon, size: isTablet ? 21 : 19, color: primary.withValues(alpha: 0.72)),
                const SizedBox(width: 7),
                _ActionButton(label: file.actionLabel, icon: file.actionIcon, enabled: onOpen != null, onPressed: isDownloading ? null : onOpen, isTablet: isTablet),
              ]),
              if (isDownloading) ...[const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 4))],
              if (!isDownloading && onDownload != null) ...[
                const SizedBox(height: 7),
                Align(alignment: Alignment.centerLeft, child: InkWell(onTap: onDownload, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3), child: Row(textDirection: TextDirection.ltr, mainAxisSize: MainAxisSize.min, children: [Icon(Icons.download_rounded, size: isTablet ? 17 : 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.52)), const SizedBox(width: 4), Text('Download offline', textAlign: TextAlign.left, style: TextStyle(fontSize: isTablet ? 10.5 : 9.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withValues(alpha: 0.52)))])))),
              ],
            ]),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;
  final bool isTablet;

  const _ActionButton({required this.label, required this.icon, required this.enabled, required this.onPressed, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final radius = BorderRadius.circular(isTablet ? 11 : 9);
    return Material(color: enabled ? primary : primary.withValues(alpha: 0.35), borderRadius: radius, child: InkWell(onTap: onPressed, borderRadius: radius, child: Padding(padding: EdgeInsets.symmetric(horizontal: isTablet ? 11 : 9, vertical: isTablet ? 9 : 8), child: Row(textDirection: TextDirection.ltr, mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: isTablet ? 17 : 15, color: theme.colorScheme.onPrimary), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: isTablet ? 11.5 : 10.5, fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimary))]))));
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
    final primary = theme.colorScheme.primary;
    return Container(
      padding: EdgeInsets.all(isTablet ? 13 : 11),
      decoration: BoxDecoration(color: primary.withValues(alpha: 0.055), borderRadius: BorderRadius.circular(isTablet ? 16 : 14), border: Border.all(color: primary.withValues(alpha: 0.13))),
      child: Row(textDirection: TextDirection.ltr, children: [
        Container(width: isTablet ? 45 : 40, height: isTablet ? 45 : 40, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(isTablet ? 13 : 11)), child: Icon(Icons.assignment_rounded, size: isTablet ? 23 : 20, color: theme.colorScheme.onPrimary)),
        SizedBox(width: isTablet ? 11 : 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(exam.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left, style: TextStyle(fontSize: isTablet ? 15 : 13.5, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Row(textDirection: TextDirection.ltr, children: [Icon(Icons.timer_outlined, size: isTablet ? 15 : 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.52)), const SizedBox(width: 4), Text('${exam.durationMinutes} min', style: TextStyle(fontSize: isTablet ? 11 : 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.52))), const SizedBox(width: 9), Icon(Icons.check_circle_outline_rounded, size: isTablet ? 15 : 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.52)), const SizedBox(width: 4), Text('Pass ${exam.passingScore}%', style: TextStyle(fontSize: isTablet ? 11 : 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.52)))],),
        ])),
        const SizedBox(width: 8),
        _ActionButton(label: 'Start', icon: Icons.play_arrow_rounded, enabled: onStartExam != null, onPressed: onStartExam, isTablet: isTablet),
      ]),
    );
  }
}
