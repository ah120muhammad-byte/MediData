import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/module_card.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/level_card.dart';
import 'lectures_screen.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key});

  @override
  State<ModulesScreen> createState() => ModulesScreenState();
}

class ModulesScreenState extends State<ModulesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _pendingLectureId;

  // ==========================================================================
  // CURRENT LEVEL
  // ==========================================================================

  String? _selectedLevelId;
  String? _selectedLevelName;

  // ==========================================================================
  // CURRENT MODULE
  // ==========================================================================

  String? _selectedModuleId;
  String? _selectedModuleName;

  // ==========================================================================
  // RESET TO LEVELS
  // ==========================================================================

  void _goToLevels() {
    setState(() {
      _selectedLevelId = null;
      _selectedLevelName = null;

      _selectedModuleId = null;
      _selectedModuleName = null;
    });
  }

  // ==========================================================================
  // RESET TO MODULES
  // ==========================================================================

  void _goToModules() {
    setState(() {
      _selectedModuleId = null;
      _selectedModuleName = null;
    });
  }

  // ==========================================================================
  // OPEN LECTURE
  // =========================================================================

  Future<void> openLecture({
    required String moduleId,
    required String lectureId,
  }) async {
    try {
      final response = await _supabase
          .from('modules')
          .select('''
          id,
          name,
          academic_level_id,
          academic_levels (
            id,
            name
          )
        ''')
          .eq('id', moduleId)
          .maybeSingle();

      if (response == null) {
        return;
      }

      final module = Map<String, dynamic>.from(response);

      final levelRaw = module['academic_levels'];

      if (levelRaw is! Map) {
        return;
      }

      final level = Map<String, dynamic>.from(levelRaw);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLevelId = level['id']?.toString();

        _selectedLevelName = level['name']?.toString();

        _selectedModuleId = module['id']?.toString();

        _selectedModuleName = module['name']?.toString();
      });

      // Send lecture target to LecturesScreen
      // after the widget rebuilds.
      _pendingLectureId = lectureId;
    } catch (e) {
      debugPrint('Open lecture from home error: $e');
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------------------------------------
    // LEVELS
    // ------------------------------------------------------------------------

    if (_selectedLevelId == null) {
      return _LevelsView(
        supabase: _supabase,
        onLevelSelected: (level) {
          setState(() {
            _selectedLevelId = level.id;
            _selectedLevelName = level.name;

            _selectedModuleId = null;
            _selectedModuleName = null;
          });
        },
      );
    }

    // ------------------------------------------------------------------------
    // MODULES
    // ------------------------------------------------------------------------

    if (_selectedModuleId == null) {
      return _ModulesView(
        supabase: _supabase,
        levelId: _selectedLevelId!,
        levelName: _selectedLevelName ?? '',
        onBack: _goToLevels,
        onModuleSelected: (module) {
          setState(() {
            _selectedModuleId = module.id;
            _selectedModuleName = module.name;
          });
        },
      );
    }

    // ------------------------------------------------------------------------
    // LECTURES
    // ------------------------------------------------------------------------

    final lectureId = _pendingLectureId;

    _pendingLectureId = null;

    return LecturesScreen(
      moduleId: _selectedModuleId!,
      moduleName: _selectedModuleName ?? '',
      initialLectureId: lectureId,
      onBack: _goToModules,
    );
  }
}

// ============================================================================
// LEVELS VIEW
// ============================================================================

class _LevelsView extends StatefulWidget {
  final SupabaseClient supabase;
  final ValueChanged<_AcademicLevel> onLevelSelected;

  const _LevelsView({required this.supabase, required this.onLevelSelected});

  @override
  State<_LevelsView> createState() => _LevelsViewState();
}

class _LevelsViewState extends State<_LevelsView> {
  late Future<List<_AcademicLevel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadLevels();
  }

  // ==========================================================================
  // LOAD LEVELS
  // ==========================================================================

  Future<List<_AcademicLevel>> _loadLevels() async {
    final levelsResponse = await widget.supabase
        .from('academic_levels')
        .select('id, name, description, image_url, display_order, is_active')
        .eq('is_active', true)
        .order('display_order', ascending: true);

    final modulesResponse = await widget.supabase
        .from('modules')
        .select('id, academic_level_id')
        .eq('is_active', true);

    final Map<String, int> moduleCountByLevel = {};

    for (final module in modulesResponse) {
      final levelId = module['academic_level_id']?.toString();

      if (levelId == null) {
        continue;
      }

      moduleCountByLevel[levelId] = (moduleCountByLevel[levelId] ?? 0) + 1;
    }

    return (levelsResponse as List).map((item) {
      final map = Map<String, dynamic>.from(item);

      final id = map['id']?.toString() ?? '';

      return _AcademicLevel(
        id: id,
        name: map['name']?.toString() ?? '',
        description: map['description']?.toString(),
        imageUrl: map['image_url']?.toString(),
        moduleCount: moduleCountByLevel[id] ?? 0,
      );
    }).toList();
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    setState(() {
      _future = _loadLevels();
    });

    await _future;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;

    return FutureBuilder<List<_AcademicLevel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorState(
            message: 'Unable to load levels.',
            onRetry: _refresh,
          );
        }

        final levels = snapshot.data ?? [];

        if (levels.isEmpty) {
          return const _EmptyState(
            icon: Icons.school_outlined,
            title: 'No Levels Available',
            message: 'Academic levels will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = isTablet ? 900.0 : constraints.maxWidth;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32 : 20,
                      isTablet ? 28 : 22,
                      isTablet ? 32 : 20,
                      isTablet ? 120 : 110,
                    ),
                    itemCount: levels.length,
                    separatorBuilder: (_, _) {
                      return SizedBox(height: isTablet ? 20 : 16);
                    },
                    itemBuilder: (context, index) {
                      final level = levels[index];

                      return LevelCard(
                        name: level.name,
                        description: level.description,
                        imageUrl: level.imageUrl,
                        moduleCount: level.moduleCount,
                        onTap: () {
                          widget.onLevelSelected(level);
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================================
// MODULES VIEW
// ============================================================================

class _ModulesView extends StatefulWidget {
  final SupabaseClient supabase;
  final String levelId;
  final String levelName;
  final VoidCallback onBack;
  final ValueChanged<_Module> onModuleSelected;

  const _ModulesView({
    required this.supabase,
    required this.levelId,
    required this.levelName,
    required this.onBack,
    required this.onModuleSelected,
  });

  @override
  State<_ModulesView> createState() => _ModulesViewState();
}

class _ModulesViewState extends State<_ModulesView> {
  late Future<List<_Module>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadModules();
  }

  // ==========================================================================
  // LOAD MODULES
  // ==========================================================================

  Future<List<_Module>> _loadModules() async {
    final response = await widget.supabase
        .from('modules')
        .select('''
          id,
          academic_level_id,
          name,
          description,
          image_url,
          display_order,
          is_active
          ''')
        .eq('academic_level_id', widget.levelId)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return (response as List).map((item) {
      return _Module.fromMap(Map<String, dynamic>.from(item));
    }).toList();
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    setState(() {
      _future = _loadModules();
    });

    await _future;
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
              widget.levelName,
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
          child: FutureBuilder<List<_Module>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _ErrorState(
                  message: 'Unable to load modules.',
                  onRetry: _refresh,
                );
              }

              final modules = snapshot.data ?? [];

              if (modules.isEmpty) {
                return const _EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No Modules Available',
                  message: 'Modules will appear here.',
                );
              }

              return RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    isTablet ? 32 : 20,
                    isTablet ? 20 : 14,
                    isTablet ? 32 : 20,
                    isTablet ? 120 : 110,
                  ),
                  itemCount: modules.length,
                  separatorBuilder: (_, _) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    final module = modules[index];

                    return ModuleCard(
                      name: module.name,
                      description: module.description,
                      imageUrl: module.imageUrl,
                      onTap: () {
                        widget.onModuleSelected(module);
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
}

// ============================================================================
// MODELS
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

class _Module {
  final String id;
  final String academicLevelId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;

  const _Module({
    required this.id,
    required this.academicLevelId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.displayOrder,
    required this.isActive,
  });

  factory _Module.fromMap(Map<String, dynamic> map) {
    return _Module(
      id: map['id']?.toString() ?? '',
      academicLevelId: map['academic_level_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      imageUrl: map['image_url']?.toString(),
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
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
          height: MediaQuery.sizeOf(context).height * 0.60,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 65,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.30),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    message,
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
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
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
