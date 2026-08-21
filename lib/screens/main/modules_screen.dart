import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/main/lectures_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/level_card.dart';


class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late Future<List<_AcademicLevel>> _levelsFuture;

  @override
  void initState() {
    super.initState();
    _levelsFuture = _loadLevels();
  }

  // ==========================================================================
  // LOAD ACADEMIC LEVELS
  // ==========================================================================

  Future<List<_AcademicLevel>> _loadLevels() async {
    final levelsResponse = await _supabase
        .from('academic_levels')
        .select(
          'id, name, description, image_url, display_order, is_active',
        )
        .eq('is_active', true)
        .order('display_order', ascending: true);

    final modulesResponse = await _supabase
        .from('modules')
        .select('id, academic_level_id')
        .eq('is_active', true);

    final Map<String, int> moduleCountByLevel = {};

    for (final module in modulesResponse) {
      final academicLevelId = module['academic_level_id'];

      if (academicLevelId == null) {
        continue;
      }

      final levelId = academicLevelId.toString();

      moduleCountByLevel[levelId] =
          (moduleCountByLevel[levelId] ?? 0) + 1;
    }

    return levelsResponse.map<_AcademicLevel>((level) {
      final levelId = level['id'].toString();

      return _AcademicLevel(
        id: levelId,
        name: level['name']?.toString() ?? '',
        description: level['description']?.toString(),
        imageUrl: level['image_url']?.toString(),
        moduleCount: moduleCountByLevel[levelId] ?? 0,
      );
    }).toList();
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    setState(() {
      _levelsFuture = _loadLevels();
    });

    await _levelsFuture;
  }

  // ==========================================================================
  // OPEN LEVEL
  // ==========================================================================

  void _openLevel(_AcademicLevel level) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LevelModulesScreen(
          levelId: level.id,
          levelName: level.name,
        ),
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

    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: FutureBuilder<List<_AcademicLevel>>(
        future: _levelsFuture,
        builder: (context, snapshot) {
          // ------------------------------------------------------------------
          // LOADING
          // ------------------------------------------------------------------

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ------------------------------------------------------------------
          // ERROR
          // ------------------------------------------------------------------

          if (snapshot.hasError) {
            return _ErrorState(
              onRetry: _refresh,
            );
          }

          // ------------------------------------------------------------------
          // DATA
          // ------------------------------------------------------------------

          final levels = snapshot.data ?? [];

          // ------------------------------------------------------------------
          // EMPTY
          // ------------------------------------------------------------------

          if (levels.isEmpty) {
            return const _EmptyState();
          }

          // ------------------------------------------------------------------
          // LEVEL CARDS
          // ------------------------------------------------------------------

          return LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = isTablet
                  ? 900.0
                  : constraints.maxWidth;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: contentWidth,
                  ),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      isTablet ? 28 : 22,
                      horizontalPadding,
                      isTablet ? 130 : 115,
                    ),
                    itemCount: levels.length,
                    separatorBuilder: (_, _) {
                      return SizedBox(
                        height: isTablet ? 20 : 16,
                      );
                    },
                    itemBuilder: (context, index) {
                      final level = levels[index];

                      return LevelCard(
                        name: level.name,
                        description: level.description,
                        imageUrl: level.imageUrl,
                        moduleCount: level.moduleCount,
                        onTap: () => _openLevel(level),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// ACADEMIC LEVEL MODEL
// ============================================================================

class _AcademicLevel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int moduleCount;

  const _AcademicLevel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.moduleCount,
  });
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 65,
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: 0.30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Levels Available',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Academic levels will appear here when they are added from the admin dashboard.',
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

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Center(
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
                    'Unable to load Levels',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
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
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.60,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(
                      Icons.refresh_rounded,
                    ),
                    label: const Text('Try Again'),
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
// LEVEL MODULES SCREEN
// ============================================================================

class LevelModulesScreen extends StatefulWidget {
  final String levelId;
  final String levelName;

  const LevelModulesScreen({
    super.key,
    required this.levelId,
    required this.levelName,
  });

  @override
  State<LevelModulesScreen> createState() =>
      _LevelModulesScreenState();
}

class _LevelModulesScreenState
    extends State<LevelModulesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _modulesFuture;

  @override
  void initState() {
    super.initState();
    _modulesFuture = _loadModules();
  }

  // ==========================================================================
  // LOAD MODULES
  // ==========================================================================

  Future<List<Map<String, dynamic>>> _loadModules() async {
    final response = await _supabase
        .from('modules')
        .select(
          'id, academic_level_id, name, description, image_url, display_order, is_active',
        )
        .eq('academic_level_id', widget.levelId)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==========================================================================
  // REFRESH MODULES
  // ==========================================================================

  Future<void> _refresh() async {
    setState(() {
      _modulesFuture = _loadModules();
    });

    await _modulesFuture;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;

    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.levelName),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _modulesFuture,
        builder: (context, snapshot) {
          // ------------------------------------------------------------------
          // LOADING
          // ------------------------------------------------------------------

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ------------------------------------------------------------------
          // ERROR
          // ------------------------------------------------------------------

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 55,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Unable to load modules.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(
                        Icons.refresh_rounded,
                      ),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          // ------------------------------------------------------------------
          // DATA
          // ------------------------------------------------------------------

          final modules = snapshot.data ?? [];

          // ------------------------------------------------------------------
          // EMPTY
          // ------------------------------------------------------------------

          if (modules.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.primary,
              child: ListView(
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
                              size: 60,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.30),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Modules Available',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Modules will appear here when they are added from the admin dashboard.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.60),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // ------------------------------------------------------------------
          // MODULE LIST
          // ------------------------------------------------------------------

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isTablet ? 24 : 18,
                horizontalPadding,
                isTablet ? 110 : 95,
              ),
              itemCount: modules.length,
              separatorBuilder: (_, _) {
                return const SizedBox(height: 12);
              },
              itemBuilder: (context, index) {
                final module = modules[index];

                return _ModuleCard(
                  module: module,
                  isTablet: isTablet,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// MODULE CARD
// ============================================================================

class _ModuleCard extends StatelessWidget {
  final Map<String, dynamic> module;
  final bool isTablet;

  const _ModuleCard({
    required this.module,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final name = module['name']?.toString() ?? '';
    final description = module['description']?.toString();
    final imageUrl = module['image_url']?.toString();

    final hasImage =
        imageUrl != null && imageUrl.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(
        isTablet ? 22 : 18,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LecturesScreen(
                // moduleId: module['id'].toString(),
                // moduleName: name,
              ),
            ),
          );
        },
        child: Container(
          height: isTablet ? 150 : 125,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(
              isTablet ? 22 : 18,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark
                      ? 0.22
                      : 0.07,
                ),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // ==============================================================
              // IMAGE
              // ==============================================================

              SizedBox(
                width: isTablet ? 145 : 110,
                height: double.infinity,
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return const _ModulePlaceholder();
                        },
                      )
                    : const _ModulePlaceholder(),
              ),

              // ==============================================================
              // CONTENT
              // ==============================================================

              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(
                    isTablet ? 18 : 14,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),

                      if (description != null &&
                          description.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isTablet ? 13 : 12,
                            height: 1.35,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.60),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODULE PLACEHOLDER
// ============================================================================

class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(
        alpha: 0.10,
      ),
      child: Icon(
        Icons.menu_book_rounded,
        color: AppColors.primary,
        size: 34,
      ),
    );
  }
}