import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  final void Function({
    required String moduleId,
    required String moduleName,
    required String lectureId,
  }) onOpenLecture;

  const HomeScreen({
    super.key,
    required this.onOpenLecture,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<_HomeData> _homeFuture;

  @override
  void initState() {
    super.initState();
    _homeFuture = _loadHomeData();
  }

  Future<_HomeData> _loadHomeData() async {
    final user = _supabase.auth.currentUser;
    _LectureHomeData? latestLecture;

    final latestResponse = await _supabase
        .from('lectures')
        .select('''
          id,
          module_id,
          title,
          description,
          published_at,
          is_published,
          is_active,
          modules (
            id,
            name
          )
        ''')
        .eq('is_active', true)
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .limit(1);

    final latestRows = List<Map<String, dynamic>>.from(
      (latestResponse as List).map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );

    if (latestRows.isNotEmpty) {
      final row = latestRows.first;
      final moduleRaw = row['modules'];
      latestLecture = _LectureHomeData(
        id: row['id']?.toString() ?? '',
        moduleId: row['module_id']?.toString() ?? '',
        title: row['title']?.toString() ?? '',
        description: row['description']?.toString(),
        moduleName: moduleRaw is Map
            ? moduleRaw['name']?.toString() ?? 'Module'
            : 'Module',
        publishedAt: DateTime.tryParse(
          row['published_at']?.toString() ?? '',
        ),
      );
    }

    _ModuleHomeData? currentModule;
    if (user != null) {
      final latestProgressResponse = await _supabase
          .from('lecture_progress')
          .select('''
            lecture_id,
            last_opened_at,
            lectures (
              id,
              module_id,
              modules (
                id,
                name,
                description
              )
            )
          ''')
          .eq('user_id', user.id)
          .order('last_opened_at', ascending: false)
          .limit(1);

      final progressRows = List<Map<String, dynamic>>.from(
        (latestProgressResponse as List).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );

      if (progressRows.isNotEmpty) {
        final row = progressRows.first;
        final lectureRaw = row['lectures'];

        if (lectureRaw is Map) {
          final lecture = Map<String, dynamic>.from(lectureRaw);
          final moduleRaw = lecture['modules'];

          if (moduleRaw is Map) {
            final module = Map<String, dynamic>.from(moduleRaw);
            currentModule = _ModuleHomeData(
              id: module['id']?.toString() ??
                  lecture['module_id']?.toString() ?? '',
              name: module['name']?.toString() ?? 'Current Module',
              description: module['description']?.toString(),
            );
          }
        }
      }
    }

    int totalTrackableLectures = 0;
    int completedLectures = 0;
    double moduleProgress = 0.0;

    if (currentModule != null && user != null) {
      final lecturesResponse = await _supabase
          .from('lectures')
          .select('''
            id,
            title
          ''')
          .eq('module_id', currentModule.id)
          .eq('is_active', true)
          .eq('is_published', true)
          .order('display_order', ascending: true);

      final lectures = List<Map<String, dynamic>>.from(
        (lecturesResponse as List).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );

      if (lectures.isNotEmpty) {
        final lectureIds = lectures
            .map((lecture) => lecture['id'].toString())
            .toList();

        final filesResponse = await _supabase
            .from('lecture_files')
            .select('''
              id,
              lecture_id,
              file_type,
              is_active
            ''')
            .inFilter('lecture_id', lectureIds)
            .eq('is_active', true);

        final files = List<Map<String, dynamic>>.from(
          (filesResponse as List).map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );

        final trackableLectureIds = <String>{};
        for (final file in files) {
          final type = file['file_type']
                  ?.toString()
                  .toLowerCase()
                  .trim() ??
              '';

          if (type == 'audio' || type == 'video') {
            final lectureId = file['lecture_id']?.toString();
            if (lectureId != null && lectureId.isNotEmpty) {
              trackableLectureIds.add(lectureId);
            }
          }
        }

        totalTrackableLectures = trackableLectureIds.length;

        if (trackableLectureIds.isNotEmpty) {
          final progressResponse = await _supabase
              .from('lecture_progress')
              .select('''
                lecture_id,
                audio_completed,
                video_completed
              ''')
              .eq('user_id', user.id)
              .inFilter('lecture_id', trackableLectureIds.toList());

          for (final item in (progressResponse as List)) {
            final map = Map<String, dynamic>.from(item);
            final audioCompleted = map['audio_completed'] as bool? ?? false;
            final videoCompleted = map['video_completed'] as bool? ?? false;

            if (audioCompleted || videoCompleted) {
              completedLectures++;
            }
          }

          if (completedLectures > totalTrackableLectures) {
            completedLectures = totalTrackableLectures;
          }
        }
      }

      if (totalTrackableLectures > 0) {
        moduleProgress = completedLectures / totalTrackableLectures;
      }
    }

    return _HomeData(
      latestLecture: latestLecture,
      currentModule: currentModule,
      completedLectures: completedLectures,
      totalTrackableLectures: totalTrackableLectures,
      moduleProgress: moduleProgress,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {
      _homeFuture = _loadHomeData();
    });

    await _homeFuture;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentMaxWidth = constraints.maxWidth >= 900
            ? 900.0
            : constraints.maxWidth;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: FutureBuilder<_HomeData>(
              future: _homeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('Home error: ${snapshot.error}');
                  return _HomeErrorState(onRetry: _refresh);
                }

                final data = snapshot.data ?? const _HomeData();
                final horizontalPadding = Responsive.horizontalPadding(context);
                final topPadding = Responsive.spacing(
                  context,
                  base: 24,
                  min: 16,
                  max: 36,
                );

                // Keep only a small safe area below the last card.
                // The previous 115px value made the page scroll far past
                // the actual content and left a large empty area.
                const bottomPadding = 24.0;

                final sectionGap = Responsive.spacing(
                  context,
                  base: 28,
                  min: 20,
                  max: 40,
                );
                final titleGap = Responsive.spacing(
                  context,
                  base: 12,
                  min: 8,
                  max: 18,
                );

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(title: "What's New"),
                        SizedBox(height: titleGap),
                        _LatestLectureCard(
                          lecture: data.latestLecture,
                          onTap: data.latestLecture == null
                              ? null
                              : () {
                                  final lecture = data.latestLecture!;
                                  widget.onOpenLecture(
                                    moduleId: lecture.moduleId,
                                    moduleName: lecture.moduleName,
                                    lectureId: lecture.id,
                                  );
                                },
                        ),
                        SizedBox(height: sectionGap),
                        _SectionTitle(title: 'Your Module'),
                        SizedBox(height: titleGap),
                        _YourModuleCard(
                          module: data.currentModule,
                          progress: data.moduleProgress,
                          completedLectures: data.completedLectures,
                          totalTrackableLectures: data.totalTrackableLectures,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _HomeData {
  final _LectureHomeData? latestLecture;
  final _ModuleHomeData? currentModule;
  final int completedLectures;
  final int totalTrackableLectures;
  final double moduleProgress;

  const _HomeData({
    this.latestLecture,
    this.currentModule,
    this.completedLectures = 0,
    this.totalTrackableLectures = 0,
    this.moduleProgress = 0.0,
  });
}

class _LectureHomeData {
  final String id;
  final String moduleId;
  final String title;
  final String? description;
  final String moduleName;
  final DateTime? publishedAt;

  const _LectureHomeData({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.description,
    required this.moduleName,
    required this.publishedAt,
  });
}

class _ModuleHomeData {
  final String id;
  final String name;
  final String? description;

  const _ModuleHomeData({
    required this.id,
    required this.name,
    required this.description,
  });
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: Responsive.titleSize(
          context,
          base: 22,
          min: 19,
          max: 30,
        ),
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

class _LatestLectureCard extends StatelessWidget {
  final _LectureHomeData? lecture;
  final VoidCallback? onTap;

  const _LatestLectureCard({
    required this.lecture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = Responsive.cardRadius(context);

    if (lecture == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Text(
          'No new lectures available yet.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.all(
            Responsive.spacing(context, base: 20, min: 16, max: 26),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.gold.withValues(alpha: 0.95),
                AppColors.gold.withValues(alpha: 0.72),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lecture!.moduleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lecture!.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if ((lecture!.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  lecture!.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.black.withValues(alpha: 0.72),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.play_circle_fill_rounded, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Open lecture',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YourModuleCard extends StatelessWidget {
  final _ModuleHomeData? module;
  final double progress;
  final int completedLectures;
  final int totalTrackableLectures;

  const _YourModuleCard({
    required this.module,
    required this.progress,
    required this.completedLectures,
    required this.totalTrackableLectures,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = Responsive.cardRadius(context);

    if (module == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
        child: Text(
          'Open a lecture to start tracking your module progress.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final percentage = (progress.clamp(0.0, 1.0) * 100).round();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        Responsive.spacing(context, base: 20, min: 16, max: 26),
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            module!.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if ((module!.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              module!.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 9,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percentage%',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            totalTrackableLectures > 0
                ? '$completedLectures of $totalTrackableLectures lectures completed'
                : 'No trackable lectures yet',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _HomeErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong while loading Home.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
