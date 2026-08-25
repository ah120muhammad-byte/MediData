import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/lecture_card.dart';
import 'exam_screen.dart';
import '../../services/download_service.dart';
import 'lecture_audio_player_screen.dart';
import 'lecture_video_player_screen.dart';

class LecturesScreen extends StatefulWidget {
  final String moduleId;
  final String moduleName;
  final VoidCallback onBack;
  final String? initialLectureId;

  const LecturesScreen({
    super.key,
    required this.moduleId,
    required this.moduleName,
    required this.onBack,
    this.initialLectureId,
  });

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

  // ==========================================================================
  // LOAD LECTURES
  // ==========================================================================

  Future<List<_Lecture>> _loadLectures() async {
    final lecturesResponse = await _supabase
        .from('lectures')
        .select('''
          id,
          module_id,
          title,
          description,
          display_order,
          is_published,
          is_active
          ''')
        .eq('module_id', widget.moduleId)
        .eq('is_active', true)
        .eq('is_published', true)
        .order('display_order', ascending: true);

    final lectures = (lecturesResponse as List)
        .map((item) => _Lecture.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    if (lectures.isEmpty) {
      return [];
    }
    if (widget.initialLectureId != null &&
        lectures.any((lecture) => lecture.id == widget.initialLectureId)) {
      _expandedLectureId = widget.initialLectureId;
    }

    final lectureIds = lectures.map((lecture) => lecture.id).toList();

    // =========================================================================
    // FILES
    // =========================================================================

    final filesResponse = await _supabase
        .from('lecture_files')
        .select('''
          id,
          lecture_id,
          title,
          file_type,
          file_url,
          display_order,
          is_active,
          created_at,
          updated_at
          ''')
        .inFilter('lecture_id', lectureIds)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    final files = (filesResponse as List)
        .map((item) => _LectureFile.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    // =========================================================================
    // EXAMS
    // =========================================================================

    final examsResponse = await _supabase
        .from('exams')
        .select('''
          id,
          lecture_id,
          title,
          description,
          duration_minutes,
          passing_score,
          is_active,
          created_at,
          updated_at
          ''')
        .inFilter('lecture_id', lectureIds)
        .eq('is_active', true);

    final exams = (examsResponse as List)
        .map(
          (item) => LectureExam(
            id: item['id'].toString(),
            lectureId: item['lecture_id'].toString(),
            title: item['title']?.toString() ?? 'Exam',
            description: item['description']?.toString(),
            durationMinutes: (item['duration_minutes'] as num?)?.toInt() ?? 0,
            passingScore: (item['passing_score'] as num?)?.toInt() ?? 0,
            isActive: item['is_active'] as bool? ?? false,
          ),
        )
        .toList();

    // =========================================================================
    // GROUP FILES
    // =========================================================================

    final Map<String, List<_LectureFile>> filesByLecture = {};

    for (final file in files) {
      filesByLecture.putIfAbsent(file.lectureId, () => []);

      filesByLecture[file.lectureId]!.add(file);
    }

    // =========================================================================
    // GROUP EXAMS
    //
    // حاليا امتحان واحد فقط لكل Lecture.
    // لو عندنا مستقبلا أكثر من امتحان، نقدر نغيرها بسهولة.
    // =========================================================================

    final Map<String, LectureExam> examByLecture = {};

    for (final exam in exams) {
      examByLecture.putIfAbsent(exam.lectureId, () => exam);
    }

    // =========================================================================
    // ATTACH CONTENT
    // =========================================================================

    return lectures.map((lecture) {
      return lecture.copyWith(
        files: filesByLecture[lecture.id] ?? [],
        exam: examByLecture[lecture.id],
      );
    }).toList();
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    setState(() {
      _lecturesFuture = _loadLectures();
    });

    await _lecturesFuture;
  }

  // ==========================================================================
  // TOGGLE
  // ==========================================================================

  void _toggleLecture(String lectureId) {
    setState(() {
      if (_expandedLectureId == lectureId) {
        _expandedLectureId = null;
      } else {
        _expandedLectureId = lectureId;
      }
    });
  }

  // ==========================================================================
  // START EXAM
  // ==========================================================================

  Future<void> _confirmStartExam(_Lecture lecture) async {
    final exam = lecture.exam;

    if (exam == null) {
      return;
    }

    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          title: const Text('Start Exam?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exam.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),

              if (exam.description != null &&
                  exam.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  exam.description!.trim(),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Text('Duration: ${exam.durationMinutes} minutes'),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Text('Passing score: ${exam.passingScore}%'),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                'Once you start the exam, the timer will begin.',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Start Exam'),
            ),
          ],
        );
      },
    );

    if (shouldStart != true || !mounted) {
      return;
    }

    // ========================================================================
    // NEXT STEP
    //
    // هنا هنفتح ExamScreen في المرحلة القادمة.
    // ========================================================================

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamScreen(
          examId: exam.id,
          examTitle: exam.title,
          durationMinutes: exam.durationMinutes,
          passingScore: exam.passingScore,
          attemptId: null,
        ),
      ),
    );
  }

  // ==========================================================================
  // OPEN
  // ==========================================================================

  Future<void> _openFile(BuildContext context, _LectureFile file) async {
    final downloadsService = DownloadsService.instance;

    try {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 30),
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Opening ${file.title}...')),
              ],
            ),
          ),
        );

      await downloadsService.openLectureFile(
        id: file.id,
        title: file.title,
        fileType: file.fileType,
        fileUrl: file.fileUrl,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      debugPrint('Lecture file open error: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Unable to open ${file.title}.')),
        );
    }
  }

  // ==========================================================================
  // DOWNLOAD
  // ==========================================================================

  Future<void> _downloadFile(
    BuildContext context,
    _Lecture lecture,
    _LectureFile file,
  ) async {
    final downloadsService = DownloadsService.instance;

    try {
      final existing = await downloadsService.findById(file.id);

      if (existing != null) {
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Already downloaded'),
              content: Text('"${file.title}" is already available offline.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Open'),
                ),
              ],
            );
          },
        );

        if (shouldOpen == true) {
          await downloadsService.open(existing);
        }

        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 30),
            content: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Downloading ${file.title}...')),
              ],
            ),
          ),
        );

      final downloaded = await downloadsService.download(
        id: file.id,
        lectureId: file.lectureId,
        lectureTitle: lecture.title,
        title: file.title,
        fileType: file.fileType,
        fileUrl: file.fileUrl,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }

          final percent = (progress.progress * 100).round();

          // optional snackbar progress
          // DownloadsScreen itself now receives
          // the same live progress automatically.
          debugPrint('Downloading ${file.title}: $percent%');
        },
      );
      (progress) {
        if (!mounted) {
          return;
        }

        final percent = (progress.progress * 100).round();

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 30),
              content: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Downloading ${file.title} • $percent%'),
                  ),
                ],
              ),
            ),
          );
      };

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${downloaded.title} downloaded successfully.'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                downloadsService.open(downloaded);
              },
            ),
          ),
        );
    } catch (e) {
      debugPrint('Lecture file download error: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Unable to download ${file.title}.')),
        );
    }
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader(BuildContext context, bool isTablet) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24 : 16,
        isTablet ? 18 : 12,
        isTablet ? 24 : 16,
        4,
      ),
      child: Row(
        children: [
          Material(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onBack,
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 11 : 9),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: isTablet ? 27 : 23,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),

          SizedBox(width: isTablet ? 16 : 12),

          Expanded(
            child: Text(
              widget.moduleName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isTablet ? 22 : 19,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final isTablet = size.shortestSide >= 600;

    return Column(
      children: [
        _buildHeader(context, isTablet),

        Expanded(
          child: FutureBuilder<List<_Lecture>>(
            future: _lecturesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugPrint('Lectures error: ${snapshot.error}');

                return _LectureErrorState(onRetry: _refresh);
              }

              final lectures = snapshot.data ?? [];

              if (lectures.isEmpty) {
                return const _LectureEmptyState();
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 32 : 18,
                    isTablet ? 20 : 14,
                    isTablet ? 32 : 18,
                    isTablet ? 120 : 110,
                  ),
                  itemCount: lectures.length,
                  separatorBuilder: (_, _) {
                    return SizedBox(height: isTablet ? 14 : 10);
                  },
                  itemBuilder: (context, index) {
                    final lecture = lectures[index];

                    final isExpanded = _expandedLectureId == lecture.id;

                    return LectureCard(
                      title: lecture.title,
                      description: lecture.description,
                      files: lecture.files.map(_toLectureFile).toList(),
                      exam: lecture.exam,
                      isTablet: isTablet,
                      expanded: isExpanded,
                      onTap: () {
                        _toggleLecture(lecture.id);
                      },
                      onFileOpen: (file) {
                        final original = lecture.files.firstWhere(
                          (item) => item.id == file.path,
                        );

                        final type = original.fileType.toLowerCase().trim();

                        if (type == 'audio') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LectureAudioPlayerScreen(
                                lectureId: lecture.id,
                                lectureTitle: lecture.title,
                                fileId: original.id,
                                fileTitle: original.title,
                                fileUrl: original.fileUrl,
                              ),
                            ),
                          );

                          return;
                        }

                        if (type == 'video') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LectureVideoPlayerScreen(
                                lectureId: lecture.id,
                                lectureTitle: lecture.title,
                                fileId: original.id,
                                fileTitle: original.title,
                                fileUrl: original.fileUrl,
                              ),
                            ),
                          );

                          return;
                        }

                        _openFile(context, original);
                      },
                      onFileDownload: (file) {
                        final original = lecture.files.firstWhere(
                          (item) => item.id == file.path,
                        );

                        _downloadFile(context, lecture, original);
                      },
                      onStartExam: () {
                        _confirmStartExam(lecture);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // FILE ADAPTER
  // ==========================================================================

  LectureFile _toLectureFile(_LectureFile file) {
    final type = switch (file.fileType.toLowerCase().trim()) {
      'pdf' => LectureFileType.pdf,
      'audio' => LectureFileType.audio,
      'video' => LectureFileType.video,
      _ => LectureFileType.pdf,
    };

    return LectureFile(
      type: type,
      title: file.title,
      subtitle: _fileTypeLabel(file.fileType),
      path: file.id,
    );
  }

  String _fileTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'Lecture PDF';
      case 'audio':
        return 'Lecture Audio';
      case 'video':
        return 'Lecture Video';
      default:
        return 'Lecture File';
    }
  }
}

// ============================================================================
// LECTURE MODEL
// ============================================================================

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

  const _Lecture({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.displayOrder,
    required this.isPublished,
    required this.isActive,
    this.files = const [],
    this.exam,
  });

  factory _Lecture.fromMap(Map<String, dynamic> map) {
    return _Lecture(
      id: map['id']?.toString() ?? '',
      moduleId: map['module_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isPublished: map['is_published'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  _Lecture copyWith({List<_LectureFile>? files, LectureExam? exam}) {
    return _Lecture(
      id: id,
      moduleId: moduleId,
      title: title,
      description: description,
      displayOrder: displayOrder,
      isPublished: isPublished,
      isActive: isActive,
      files: files ?? this.files,
      exam: exam ?? this.exam,
    );
  }
}

// ============================================================================
// LECTURE FILE MODEL
// ============================================================================

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

  const _LectureFile({
    required this.id,
    required this.lectureId,
    required this.title,
    required this.fileType,
    required this.fileUrl,
    required this.displayOrder,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory _LectureFile.fromMap(Map<String, dynamic> map) {
    return _LectureFile(
      id: map['id']?.toString() ?? '',
      lectureId: map['lecture_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      fileType: map['file_type']?.toString() ?? '',
      fileUrl: map['file_url']?.toString() ?? '',
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _LectureEmptyState extends StatelessWidget {
  const _LectureEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.60,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 65,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Lectures Available',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lectures will appear here when they are published.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.60,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================

class _LectureErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _LectureErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 60,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load lectures',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
