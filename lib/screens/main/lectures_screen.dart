import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/responsive/responsive.dart';
import '../../services/download_service.dart';
import '../../services/student_preferences_service.dart';
import '../../widgets/lecture_card.dart';
import 'exam_screen.dart';
import 'lecture_audio_player_screen.dart';
import 'lecture_video_player_screen.dart';

class LecturesScreen extends StatefulWidget {
  final String moduleId;
  final String moduleName;
  final VoidCallback onBack;
  final String? initialLectureId;
  const LecturesScreen({super.key, required this.moduleId, required this.moduleName, required this.onBack, this.initialLectureId});
  @override
  State<LecturesScreen> createState() => _LecturesScreenState();
}

class _LecturesScreenState extends State<LecturesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<_Lecture>> _lecturesFuture;
  String? _expandedLectureId;
  @override
  void initState() {
    super.initState();
    _expandedLectureId = widget.initialLectureId;
    _lecturesFuture = _loadLectures();
  }

  Future<List<_Lecture>> _loadLectures() async {
    final lecturesResponse = await _supabase.from('lectures').select('id,module_id,title,description,display_order,is_published,is_active').eq('module_id', widget.moduleId).eq('is_active', true).eq('is_published', true).order('display_order', ascending: true);
    final lectures = (lecturesResponse as List).map((item) => _Lecture.fromMap(Map<String, dynamic>.from(item))).toList();
    if (lectures.isEmpty) return [];
    if (widget.initialLectureId != null && lectures.any((lecture) => lecture.id == widget.initialLectureId)) _expandedLectureId = widget.initialLectureId;
    final lectureIds = lectures.map((lecture) => lecture.id).toList();
    final filesResponse = await _supabase.from('lecture_files').select('id,lecture_id,title,file_type,file_url,display_order,is_active,created_at,updated_at').inFilter('lecture_id', lectureIds).eq('is_active', true).order('display_order', ascending: true);
    final files = (filesResponse as List).map((item) => _LectureFile.fromMap(Map<String, dynamic>.from(item))).toList();
    final examsResponse = await _supabase.from('exams').select('id,lecture_id,title,description,duration_minutes,passing_score,is_active,created_at,updated_at').inFilter('lecture_id', lectureIds).eq('is_active', true);
    final exams = (examsResponse as List).map((item) => LectureExam(id: item['id'].toString(), lectureId: item['lecture_id'].toString(), title: item['title']?.toString() ?? 'Exam', description: item['description']?.toString(), durationMinutes: (item['duration_minutes'] as num?)?.toInt() ?? 0, passingScore: (item['passing_score'] as num?)?.toInt() ?? 0, isActive: item['is_active'] as bool? ?? false)).toList();
    final filesByLecture = <String, List<_LectureFile>>{};
    for (final file in files) { filesByLecture.putIfAbsent(file.lectureId, () => []).add(file); }
    final examByLecture = <String, LectureExam>{};
    for (final exam in exams) { examByLecture.putIfAbsent(exam.lectureId, () => exam); }
    return lectures.map((lecture) => lecture.copyWith(files: filesByLecture[lecture.id] ?? [], exam: examByLecture[lecture.id])).toList();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _lecturesFuture = _loadLectures());
    await _lecturesFuture;
  }

  void _toggleLecture(String lectureId) {
    if (!mounted) return;
    setState(() => _expandedLectureId = _expandedLectureId == lectureId ? null : lectureId);
  }

  Future<void> _confirmStartExam(_Lecture lecture) async {
    final exam = lecture.exam;
    if (exam == null) return;
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Start Exam?'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(exam.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (exam.description != null && exam.description!.trim().isNotEmpty) ...[const SizedBox(height: 8), Text(exam.description!.trim(), style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.65)))],
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.timer_outlined, color: theme.colorScheme.primary), const SizedBox(width: 7), Expanded(child: Text('Duration: ${exam.durationMinutes} minutes'))]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle_outline_rounded, color: theme.colorScheme.primary), const SizedBox(width: 7), Expanded(child: Text('Passing score: ${exam.passingScore}%'))]),
            const SizedBox(height: 16),
            Text('Once you start the exam, the timer will begin.', style: TextStyle(fontSize: Responsive.smallTextSize(context, base: 13, min: 11, max: 15), color: theme.colorScheme.onSurface.withValues(alpha: 0.60))),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Start Exam')),
          ],
        );
      },
    );
    if (!mounted || shouldStart != true) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamScreen(examId: exam.id, examTitle: exam.title, durationMinutes: exam.durationMinutes, passingScore: exam.passingScore, attemptId: null)));
  }

  Future<void> _openFile(_LectureFile file) async {
    final downloadsService = DownloadsService.instance;
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(duration: const Duration(seconds: 30), content: Row(children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Text('Opening ${file.title}...'))])));
      await downloadsService.openLectureFile(id: file.id, title: file.title, fileType: file.fileType, fileUrl: file.fileUrl);
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      debugPrint('Lecture file open error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text('Unable to open ${file.title}.')));
    }
  }

  Future<bool> _confirmMobileDataDownload(_LectureFile file) async {
    final downloadsService = DownloadsService.instance;
    final mobileData = await downloadsService.isMobileDataConnection();
    if (!mounted) return false;
    if (!mobileData) return true;
    final shouldWarn = await StudentPreferencesService.instance.getWifiOnlyDownloads();
    if (!shouldWarn) return true;
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogTheme = Theme.of(dialogContext);
        return AlertDialog(
          icon: Icon(Icons.signal_cellular_alt_rounded, size: 40, color: dialogTheme.colorScheme.primary),
          title: const Text('Mobile Data Download', textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('You are currently using mobile data.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text('Downloading "${file.title}" may use part of your mobile data allowance.', style: TextStyle(color: dialogTheme.colorScheme.onSurface.withValues(alpha: 0.70))),
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, size: 20), SizedBox(width: 8), Expanded(child: Text('Continue only if you are comfortable using mobile data.'))])),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Continue')),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _downloadFile(_Lecture lecture, _LectureFile file) async {
    final downloadsService = DownloadsService.instance;
    try {
      final existing = await downloadsService.findById(file.id);
      if (!mounted) return;
      if (existing != null) {
        final shouldOpen = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Already downloaded'), content: Text('"${file.title}" is already available offline.'), actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Open'))]));
        if (!mounted || shouldOpen != true) return;
        await downloadsService.open(existing);
        return;
      }
      final canContinue = await _confirmMobileDataDownload(file);
      if (!mounted || !canContinue) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(duration: const Duration(seconds: 30), content: Row(children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Text('Downloading ${file.title}...'))])));
      final downloaded = await downloadsService.download(id: file.id, lectureId: file.lectureId, lectureTitle: lecture.title, title: file.title, fileType: file.fileType, fileUrl: file.fileUrl, onProgress: (progress) { if (mounted) debugPrint('Downloading ${file.title}: ${(progress.progress * 100).round()}%'); });
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text('${downloaded.title} downloaded successfully.'), action: SnackBarAction(label: 'Open', onPressed: () => downloadsService.open(downloaded))));
    } catch (e) {
      debugPrint('Lecture file download error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text('Unable to download ${file.title}.')));
    }
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final horizontal = Responsive.horizontalPadding(context);
    return Padding(padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 4), child: Row(children: [Material(color: theme.colorScheme.onSurface.withValues(alpha: 0.06), shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: widget.onBack, child: const Padding(padding: EdgeInsets.all(9), child: Icon(Icons.arrow_back_rounded)))), const SizedBox(width: 12), Expanded(child: Text(widget.moduleName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: Responsive.titleSize(context, base: 20, min: 18, max: 28), fontWeight: FontWeight.w700))) ]));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildHeader(context),
      Expanded(child: FutureBuilder<List<_Lecture>>(future: _lecturesFuture, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) { debugPrint('Lectures error: ${snapshot.error}'); return _LectureErrorState(onRetry: _refresh); }
        final lectures = snapshot.data ?? [];
        if (lectures.isEmpty) return const _LectureEmptyState();
        final horizontalPadding = Responsive.horizontalPadding(context);
        return RefreshIndicator(
          onRefresh: _refresh,
          color: Theme.of(context).colorScheme.primary,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 24),
            itemCount: lectures.length,
            separatorBuilder: (_, __) => SizedBox(height: Responsive.spacing(context, base: 10, min: 7, max: 16)),
            itemBuilder: (context, index) {
              final lecture = lectures[index];
              final isExpanded = _expandedLectureId == lecture.id;
              return LectureCard(
                title: lecture.title,
                description: lecture.description,
                files: lecture.files.map(_toLectureFile).toList(),
                exam: lecture.exam,
                isTablet: Responsive.isTablet(context),
                expanded: isExpanded,
                onTap: () => _toggleLecture(lecture.id),
                onFileOpen: (file) {
                  final original = lecture.files.firstWhere((item) => item.id == file.path);
                  final type = original.fileType.toLowerCase().trim();
                  if (type == 'audio') { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LectureAudioPlayerScreen(lectureId: lecture.id, lectureTitle: lecture.title, fileId: original.id, fileTitle: original.title, fileUrl: original.fileUrl))); return; }
                  if (type == 'video') { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LectureVideoPlayerScreen(lectureId: lecture.id, lectureTitle: lecture.title, fileId: original.id, fileTitle: original.title, fileUrl: original.fileUrl))); return; }
                  _openFile(original);
                },
                onFileDownload: (file) { final original = lecture.files.firstWhere((item) => item.id == file.path); _downloadFile(lecture, original); },
                onStartExam: () => _confirmStartExam(lecture),
              );
            },
          ),
        );
      }))
    ]);
  }

  LectureFile _toLectureFile(_LectureFile file) {
    final type = switch (file.fileType.toLowerCase().trim()) {'pdf' => LectureFileType.pdf, 'audio' => LectureFileType.audio, 'video' => LectureFileType.video, _ => LectureFileType.pdf};
    return LectureFile(type: type, title: file.title, subtitle: _fileTypeLabel(file.fileType), path: file.id);
  }
  String _fileTypeLabel(String type) { switch (type.toLowerCase()) { case 'pdf': return 'Lecture PDF'; case 'audio': return 'Lecture Audio'; case 'video': return 'Lecture Video'; default: return 'Lecture File'; } }
}

class _Lecture {
  final String id;
  final String moduleId;
  final String title;
  final String? description;
  final int displayOrder;
  final bool isPublished;
  final bool isActive;
  final List<_LectureFile> files;
  final LectureExam? exam;
  const _Lecture({required this.id, required this.moduleId, required this.title, required this.description, required this.displayOrder, required this.isPublished, required this.isActive, this.files = const [], this.exam});
  factory _Lecture.fromMap(Map<String, dynamic> map) => _Lecture(id: map['id']?.toString() ?? '', moduleId: map['module_id']?.toString() ?? '', title: map['title']?.toString() ?? '', description: map['description']?.toString(), displayOrder: (map['display_order'] as num?)?.toInt() ?? 0, isPublished: map['is_published'] as bool? ?? false, isActive: map['is_active'] as bool? ?? true);
  _Lecture copyWith({List<_LectureFile>? files, LectureExam? exam}) => _Lecture(id: id, moduleId: moduleId, title: title, description: description, displayOrder: displayOrder, isPublished: isPublished, isActive: isActive, files: files ?? this.files, exam: exam ?? this.exam);
}

class _LectureFile {
  final String id;
  final String lectureId;
  final String title;
  final String fileType;
  final String fileUrl;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const _LectureFile({required this.id, required this.lectureId, required this.title, required this.fileType, required this.fileUrl, required this.displayOrder, required this.isActive, this.createdAt, this.updatedAt});
  factory _LectureFile.fromMap(Map<String, dynamic> map) => _LectureFile(id: map['id']?.toString() ?? '', lectureId: map['lecture_id']?.toString() ?? '', title: map['title']?.toString() ?? '', fileType: map['file_type']?.toString() ?? '', fileUrl: map['file_url']?.toString() ?? '', displayOrder: (map['display_order'] as num?)?.toInt() ?? 0, isActive: map['is_active'] as bool? ?? true, createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null, updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null);
}

class _LectureEmptyState extends StatelessWidget {
  const _LectureEmptyState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), padding: EdgeInsets.all(Responsive.cardPadding(context)), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.menu_book_outlined, size: Responsive.clamped(context, base: 65, min: 52, max: 82), color: theme.colorScheme.onSurface.withValues(alpha: 0.30)), const SizedBox(height: 16), Text('No Lectures Available', textAlign: TextAlign.center, style: TextStyle(fontSize: Responsive.titleSize(context, base: 21, min: 18, max: 28), fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Lectures will appear here when they are published.', textAlign: TextAlign.center, style: TextStyle(fontSize: Responsive.bodyTextSize(context, base: 13, min: 12, max: 16), height: 1.4, color: theme.colorScheme.onSurface.withValues(alpha: 0.60)))])));
  }
}

class _LectureErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _LectureErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(child: Padding(padding: EdgeInsets.all(Responsive.cardPadding(context)), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cloud_off_rounded, size: Responsive.clamped(context, base: 60, min: 50, max: 76), color: theme.colorScheme.error), const SizedBox(height: 16), Text('Unable to load lectures', textAlign: TextAlign.center, style: TextStyle(fontSize: Responsive.titleSize(context, base: 20, min: 17, max: 26), fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Please check your internet connection and try again.', textAlign: TextAlign.center, style: TextStyle(fontSize: Responsive.bodyTextSize(context, base: 13, min: 12, max: 16), color: theme.colorScheme.onSurface.withValues(alpha: 0.60))), const SizedBox(height: 18), SizedBox(height: Responsive.buttonHeight(context), child: ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try Again')))]))));
  }
}
