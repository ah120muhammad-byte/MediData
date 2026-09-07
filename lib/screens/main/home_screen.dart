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
      (latestResponse as List).map((item) => Map<String, dynamic>.from(item)),
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
        publishedAt: DateTime.tryParse(row['published_at']?.toString() ?? ''),
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
        final lectureRaw = progressRows.first['lectures'];
        if (lectureRaw is Map) {
          final lecture = Map<String, dynamic>.from(lectureRaw);
          final moduleRaw = lecture['modules'];
          if (moduleRaw is Map) {
            final module = Map<String, dynamic>.from(moduleRaw);
            currentModule = _ModuleHomeData(
              id: module['id']?.toString() ??
                  lecture['module_id']?.toString() ??
                  '',
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
          .select('id, title')
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
            .where((id) => id.isNotEmpty)
            .toList();

        final filesResponse = await _supabase
            .from('lecture_files')
            .select('id, lecture_id, file_type, is_active')
            .inFilter('lecture_id', lectureIds)
            .eq('is_active', true);

        final files = List<Map<String, dynamic>>.from(
          (filesResponse as List).map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );

        final trackableLectureIds = <String>{};
        for (final file in files) {
          final type = file['file_type']?.toString().toLowerCase().trim() ?? '';
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
              .select('lecture_id, audio_completed, video_completed')
              .eq('user_id', user.id)
              .inFilter('lecture_id', trackableLectureIds.toList());

          final completedLectureIds = <String>{};
          for (final item in (progressResponse as List)) {
            final map = Map<String, dynamic>.from(item);
            final lectureId = map['lecture_id']?.toString();
            final audioCompleted = map['audio_completed'] as bool? ?? false;
            final videoCompleted = map['video_completed'] as bool? ?? false;

            if (lectureId != null &&
                lectureId.isNotEmpty &&
                (audioCompleted || videoCompleted)) {
              completedLectureIds.add(lectureId);
            }
          }

          completedLectures = completedLectureIds.length;
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
    final future = _loadHomeData();
    setState(() => _homeFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth >= 900 ? 900.0 : constraints.maxWidth;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: FutureBuilder<_HomeData>(
              future: _homeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _HomeLoadingState();
                }

                if (snapshot.hasError) {
                  debugPrint('Home error: ${snapshot.error}');
                  return _HomeErrorState(onRetry: _refresh);
                }

                final data = snapshot.data ?? const _HomeData();
                final horizontalPadding = Responsive.horizontalPadding(context);

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          16,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _SectionTitle(title: "What's New", icon: Icons.auto_awesome_rounded),
                            const SizedBox(height: 10),
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
                            const SizedBox(height: 22),
                            _SectionTitle(title: 'Your Module', icon: Icons.menu_book_rounded),
                            const SizedBox(height: 10),
                            _YourModuleCard(
                              module: data.currentModule,
                              progress: data.moduleProgress,
                              completedLectures: data.completedLectures,
                              totalTrackableLectures: data.totalTrackableLectures,
                            ),
                          ]),
                        ),
                      ),
                    ],
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
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: Responsive.titleSize(context, base: 21, min: 19, max: 27),
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _LatestLectureCard extends StatelessWidget {
  final _LectureHomeData? lecture;
  final VoidCallback? onTap;

  const _LatestLectureCard({required this.lecture, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = Responsive.cardRadius(context);

    if (lecture == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No new lectures available yet.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gold, AppColors.goldDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'LATEST LECTURE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                lecture!.moduleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                lecture!.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((lecture!.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  lecture!.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 17),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Open lecture',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
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
    final scheme = theme.colorScheme;
    final radius = Responsive.cardRadius(context);

    if (module == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.school_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open a lecture to start tracking your module progress.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final safeProgress = progress.clamp(0.0, 1.0);
    final percentage = (safeProgress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  module!.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if ((module!.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              module!.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ],
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: safeProgress,
              minHeight: 9,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 17,
                color: scheme.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  totalTrackableLectures > 0
                      ? '$completedLectures of $totalTrackableLectures lectures completed'
                      : 'No trackable lectures yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: scheme.primary,
        ),
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
              style: theme.textTheme.bodyMedium,
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
