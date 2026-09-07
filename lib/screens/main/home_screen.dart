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
        (lecturesResponse as List).map((item) => Map<String, dynamic>.from(item)),
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
          (filesResponse as List).map((item) => Map<String, dynamic>.from(item)),
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

    setState(() {
      _homeFuture = _loadHomeData();
    });

    await _homeFuture;
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
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  debugPrint('Home error: ${snapshot.error}');
                  return _HomeErrorState(onRetry: _refresh);
                }

                final data = snapshot.data ?? const _HomeData();
                final horizontalPadding = Responsive.horizontalPadding(context);

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    // Clamping prevents the page from visually stretching into
                    // a large empty area while keeping normal scrolling/refresh.
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(title: "What's New"),
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
                        const SizedBox(height: 24),
                        const _SectionTitle(title: 'Your Module'),
                        const SizedBox(height: 10),
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
      style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: Responsive.titleSize(context, base: 22, min: 19, max: 28),
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ) ??
          TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
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
    final scheme = theme.colorScheme;
    final radius = Responsive.cardRadius(context);
    final accent = AppColors.gold;
    final accentOn = scheme.onSecondary;

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
          padding: EdgeInsets.all(
            Responsive.spacing(context, base: 20, min: 16, max: 24),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent,
                Color.lerp(accent, scheme.surface, 0.22) ?? accent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentOn.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accentOn.withValues(alpha: 0.12)),
                ),
                child: Text(
                  lecture!.moduleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentOn.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                lecture!.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accentOn,
                  fontSize: Responsive.titleSize(context, base: 24, min: 21, max: 30),
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              if ((lecture!.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  lecture!.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentOn.withValues(alpha: 0.76),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentOn.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: accentOn,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Open lecture',
                    style: TextStyle(
                      color: accentOn,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: accentOn),
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
    final safeProgress = progress.clamp(0.0, 1.0);
    final percentage = (safeProgress * 100).round();

    if (module == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.menu_book_rounded, color: scheme.primary),
              ),
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(
          Responsive.spacing(context, base: 20, min: 16, max: 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.school_rounded, color: scheme.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT MODULE',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        module!.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if ((module!.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                module!.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Progress',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '$percentage%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: safeProgress,
                minHeight: 9,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.secondary),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    totalTrackableLectures > 0
                        ? '$completedLectures of $totalTrackableLectures lectures completed'
                        : 'No trackable lectures yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: scheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong while loading Home.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
