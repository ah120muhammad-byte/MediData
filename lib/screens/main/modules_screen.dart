import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/level_card.dart';
import '../../widgets/module_card.dart';
import 'lectures_screen.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({
    super.key,
  });

  @override
  State<ModulesScreen> createState() =>
      ModulesScreenState();
}

class ModulesScreenState
    extends State<ModulesScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

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
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedLevelId = null;
      _selectedLevelName = null;

      _selectedModuleId = null;
      _selectedModuleName = null;

      _pendingLectureId = null;
    });
  }

  // ==========================================================================
  // RESET TO MODULES
  // ==========================================================================

  void _goToModules() {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedModuleId = null;
      _selectedModuleName = null;

      _pendingLectureId = null;
    });
  }

  // ==========================================================================
  // OPEN LECTURE
  // ==========================================================================

  Future<void> openLecture({
    required String moduleId,
    required String lectureId,
  }) async {
    final normalizedModuleId =
        moduleId.trim();

    final normalizedLectureId =
        lectureId.trim();

    if (normalizedModuleId.isEmpty ||
        normalizedLectureId.isEmpty) {
      return;
    }

    try {
      final response =
          await _supabase
              .from('modules')
              .select(
                '''
                id,
                name,
                academic_level_id,
                academic_levels (
                  id,
                  name
                )
                ''',
              )
              .eq(
                'id',
                normalizedModuleId,
              )
              .maybeSingle();

      if (response == null ||
          !mounted) {
        return;
      }

      final module =
          Map<String, dynamic>.from(
        response,
      );

      final levelRaw =
          module['academic_levels'];

      if (levelRaw is! Map) {
        return;
      }

      final level =
          Map<String, dynamic>.from(
        levelRaw,
      );

      setState(() {
        _selectedLevelId =
            level['id']?.toString();

        _selectedLevelName =
            level['name']?.toString();

        _selectedModuleId =
            module['id']?.toString();

        _selectedModuleName =
            module['name']?.toString();

        _pendingLectureId =
            normalizedLectureId;
      });
    } catch (e) {
      debugPrint(
        'Open lecture from module error: $e',
      );
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    // ------------------------------------------------------------------------
    // LEVELS
    // ------------------------------------------------------------------------

    if (_selectedLevelId == null) {
      return _LevelsView(
        supabase:
            _supabase,
        onLevelSelected:
            (level) {
          if (!mounted) {
            return;
          }

          setState(() {
            _selectedLevelId =
                level.id;
            _selectedLevelName =
                level.name;

            _selectedModuleId = null;
            _selectedModuleName =
                null;
            _pendingLectureId =
                null;
          });
        },
      );
    }

    // ------------------------------------------------------------------------
    // MODULES
    // ------------------------------------------------------------------------

    if (_selectedModuleId == null) {
      return _ModulesView(
        supabase:
            _supabase,
        levelId:
            _selectedLevelId!,
        levelName:
            _selectedLevelName ??
                '',
        onBack:
            _goToLevels,
        onModuleSelected:
            (module) {
          if (!mounted) {
            return;
          }

          setState(() {
            _selectedModuleId =
                module.id;
            _selectedModuleName =
                module.name;
            _pendingLectureId =
                null;
          });
        },
      );
    }

    // ------------------------------------------------------------------------
    // LECTURES
    // ------------------------------------------------------------------------

    final lectureId =
        _pendingLectureId;

    _pendingLectureId = null;

    return LecturesScreen(
      moduleId:
          _selectedModuleId!,
      moduleName:
          _selectedModuleName ??
              '',
      initialLectureId:
          lectureId,
      onBack:
          _goToModules,
    );
  }
}

// ============================================================================
// LEVELS VIEW
// ============================================================================

class _LevelsView
    extends StatefulWidget {
  final SupabaseClient supabase;

  final ValueChanged<
          _AcademicLevel>
      onLevelSelected;

  const _LevelsView({
    required this.supabase,
    required this.onLevelSelected,
  });

  @override
  State<_LevelsView> createState() =>
      _LevelsViewState();
}

class _LevelsViewState
    extends State<_LevelsView> {
  late Future<
      List<_AcademicLevel>>
      _future;

  @override
  void initState() {
    super.initState();

    _future =
        _loadLevels();
  }

  // ==========================================================================
  // LOAD LEVELS
  // ==========================================================================

  Future<List<_AcademicLevel>>
      _loadLevels() async {
    final levelsResponse =
        await widget.supabase
            .from(
              'academic_levels',
            )
            .select(
              'id, name, description, image_url, display_order, is_active',
            )
            .eq(
              'is_active',
              true,
            )
            .order(
              'display_order',
              ascending:
                  true,
            );

    final modulesResponse =
        await widget.supabase
            .from(
              'modules',
            )
            .select(
              'id, academic_level_id',
            )
            .eq(
              'is_active',
              true,
            );

    final Map<
        String,
        int>
        moduleCountByLevel =
        {};

    for (final module
        in modulesResponse) {
      final levelId =
          module[
                  'academic_level_id']
              ?.toString();

      if (levelId ==
          null) {
        continue;
      }

      moduleCountByLevel[
              levelId] =
          (moduleCountByLevel[
                      levelId] ??
                  0) +
              1;
    }

    return (levelsResponse
            as List)
        .map(
          (item) {
            final map =
                Map<String,
                    dynamic>.from(
              item,
            );

            final id =
                map['id']
                        ?.toString() ??
                    '';

            return _AcademicLevel(
              id:
                  id,
              name:
                  map['name']
                          ?.toString() ??
                      '',
              description:
                  map['description']
                      ?.toString(),
              imageUrl:
                  map['image_url']
                      ?.toString(),
              moduleCount:
                  moduleCountByLevel[
                          id] ??
                      0,
            );
          },
        )
        .toList();
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _future =
          _loadLevels();
    });

    await _future;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder<
        List<_AcademicLevel>>(
      future:
          _future,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _ErrorState(
            message:
                'Unable to load levels.',
            onRetry:
                _refresh,
          );
        }

        final levels =
            snapshot.data ??
                [];

        if (levels.isEmpty) {
          return const _EmptyState(
            icon:
                Icons.school_outlined,
            title:
                'No Levels Available',
            message:
                'Academic levels will appear here.',
          );
        }

        final horizontalPadding =
            Responsive.horizontalPadding(
          context,
        );

        final topPadding =
            Responsive.spacing(
          context,
          base:
              22,
          min:
              14,
          max:
              32,
        );

        final bottomPadding =
            Responsive.scrollBottomPadding(
          context,
          base:
              110,
        );

        final separator =
            Responsive.spacing(
          context,
          base:
              16,
          min:
              10,
          max:
              24,
        );

        return RefreshIndicator(
          onRefresh:
              _refresh,
          color:
              AppColors.primary,
          child:
              LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final contentWidth =
                  constraints.maxWidth >
                          1100
                      ? 1100.0
                      : constraints
                          .maxWidth;

              return Center(
                child:
                    ConstrainedBox(
                  constraints:
                      BoxConstraints(
                    maxWidth:
                        contentWidth,
                  ),
                  child:
                      ListView.separated(
                    physics:
                        const AlwaysScrollableScrollPhysics(
                      parent:
                          BouncingScrollPhysics(),
                    ),
                    padding:
                        EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    itemCount:
                        levels.length,
                    separatorBuilder:
                        (
                      _,
                      _,
                    ) {
                      return SizedBox(
                        height:
                            separator,
                      );
                    },
                    itemBuilder:
                        (
                      context,
                      index,
                    ) {
                      final level =
                          levels[
                              index];

                      return LevelCard(
                        name:
                            level.name,
                        description:
                            level.description,
                        imageUrl:
                            level.imageUrl,
                        moduleCount:
                            level.moduleCount,
                        onTap:
                            () {
                          widget
                              .onLevelSelected(
                            level,
                          );
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

class _ModulesView
    extends StatefulWidget {
  final SupabaseClient supabase;

  final String levelId;
  final String levelName;

  final VoidCallback onBack;

  final ValueChanged<_Module>
      onModuleSelected;

  const _ModulesView({
    required this.supabase,
    required this.levelId,
    required this.levelName,
    required this.onBack,
    required this.onModuleSelected,
  });

  @override
  State<_ModulesView> createState() =>
      _ModulesViewState();
}

class _ModulesViewState
    extends State<_ModulesView> {
  late Future<
      List<_Module>>
      _future;

  @override
  void initState() {
    super.initState();

    _future =
        _loadModules();
  }

  // ==========================================================================
  // LOAD MODULES
  // ==========================================================================

  Future<List<_Module>>
      _loadModules() async {
    final response =
        await widget.supabase
            .from('modules')
            .select(
              '''
              id,
              academic_level_id,
              name,
              description,
              image_url,
              display_order,
              is_active
              ''',
            )
            .eq(
              'academic_level_id',
              widget.levelId,
            )
            .eq(
              'is_active',
              true,
            )
            .order(
              'display_order',
              ascending:
                  true,
            );

    return (response as List)
        .map(
          (item) =>
              _Module.fromMap(
            Map<String,
                dynamic>.from(
              item,
            ),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _future =
          _loadModules();
    });

    await _future;
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final headerPadding =
        Responsive.spacing(
      context,
      base:
          16,
      min:
          10,
      max:
          28,
    );

    final backButtonPadding =
        Responsive.spacing(
      context,
      base:
          9,
      min:
          7,
      max:
          12,
    );

    final iconSize =
        Responsive.iconSize(
      context,
      base:
          23,
      min:
          20,
      max:
          28,
    );

    final titleSize =
        Responsive.titleSize(
      context,
      base:
          20,
      min:
          18,
      max:
          28,
    );

    final gap =
        Responsive.spacing(
      context,
      base:
          12,
      min:
          8,
      max:
          18,
    );

    return Padding(
      padding:
          EdgeInsets.fromLTRB(
        headerPadding,
        headerPadding,
        headerPadding,
        Responsive.spacing(
          context,
          base:
              4,
          min:
              2,
          max:
              8,
        ),
      ),
      child:
          Row(
        children: [
          Material(
            color: theme
                .colorScheme
                .onSurface
                .withValues(
              alpha:
                  0.06,
            ),
            shape:
                const CircleBorder(),
            child:
                InkWell(
              customBorder:
                  const CircleBorder(),
              onTap:
                  widget.onBack,
              child:
                  Padding(
                padding:
                    EdgeInsets.all(
                  backButtonPadding,
                ),
                child:
                    Icon(
                  Icons
                      .arrow_back_rounded,
                  size:
                      iconSize,
                  color:
                      theme
                          .colorScheme
                          .onSurface,
                ),
              ),
            ),
          ),

          SizedBox(
            width:
                gap,
          ),

          Expanded(
            child:
                Text(
              widget.levelName,
              maxLines:
                  1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  TextStyle(
                fontSize:
                    titleSize,
                fontWeight:
                    FontWeight.w700,
                color:
                    theme
                        .colorScheme
                        .onSurface,
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
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        _buildHeader(
          context,
        ),

        Expanded(
          child:
              FutureBuilder<
                  List<_Module>>(
            future:
                _future,
            builder: (
              context,
              snapshot,
            ) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return _ErrorState(
                  message:
                      'Unable to load modules.',
                  onRetry:
                      _refresh,
                );
              }

              final modules =
                  snapshot.data ??
                      [];

              if (modules.isEmpty) {
                return const _EmptyState(
                  icon:
                      Icons
                          .menu_book_outlined,
                  title:
                      'No Modules Available',
                  message:
                      'Modules will appear here.',
                );
              }

              final horizontalPadding =
                  Responsive.horizontalPadding(
                context,
              );

              final topPadding =
                  Responsive.spacing(
                context,
                base:
                    14,
                min:
                    10,
                max:
                    24,
              );

              final bottomPadding =
                  Responsive.scrollBottomPadding(
                context,
                base:
                    110,
              );

              final separator =
                  Responsive.spacing(
                context,
                base:
                    12,
                min:
                    8,
                max:
                    18,
              );

              return RefreshIndicator(
                onRefresh:
                    _refresh,
                color:
                    AppColors.primary,
                child:
                    LayoutBuilder(
                  builder: (
                    context,
                    constraints,
                  ) {
                    final contentWidth =
                        constraints
                                .maxWidth >
                            1100
                        ? 1100.0
                        : constraints
                            .maxWidth;

                    return Center(
                      child:
                          ConstrainedBox(
                        constraints:
                            BoxConstraints(
                          maxWidth:
                              contentWidth,
                        ),
                        child:
                            ListView.separated(
                          physics:
                              const AlwaysScrollableScrollPhysics(
                            parent:
                                BouncingScrollPhysics(),
                          ),
                          padding:
                              EdgeInsets.fromLTRB(
                            horizontalPadding,
                            topPadding,
                            horizontalPadding,
                            bottomPadding,
                          ),
                          itemCount:
                              modules.length,
                          separatorBuilder:
                              (
                            _,
                            _,
                          ) {
                            return SizedBox(
                              height:
                                  separator,
                            );
                          },
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final module =
                                modules[
                                    index];

                            return ModuleCard(
                              name:
                                  module.name,
                              description:
                                  module.description,
                              imageUrl:
                                  module.imageUrl,
                              onTap:
                                  () {
                                widget
                                    .onModuleSelected(
                                  module,
                                );
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

  factory _Module.fromMap(
    Map<String, dynamic> map,
  ) {
    return _Module(
      id:
          map['id']
                  ?.toString() ??
              '',
      academicLevelId:
          map['academic_level_id']
                  ?.toString() ??
              '',
      name:
          map['name']
                  ?.toString() ??
              '',
      description:
          map['description']
              ?.toString(),
      imageUrl:
          map['image_url']
              ?.toString(),
      displayOrder:
          (map['display_order']
                      as num?)
                  ?.toInt() ??
              0,
      isActive:
          map['is_active']
                  as bool? ??
              true,
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final iconSize =
        Responsive.clamped(
      context,
      base:
          65,
      min:
          52,
      max:
          82,
    );

    final titleSize =
        Responsive.titleSize(
      context,
      base:
          21,
      min:
          18,
      max:
          28,
    );

    final horizontalPadding =
        Responsive.horizontalPadding(
      context,
    );

    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(
        parent:
            BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height:
              MediaQuery.sizeOf(
                    context,
                  ).height *
                  0.60,
          child:
              Center(
            child:
                Padding(
              padding:
                  EdgeInsets.symmetric(
                horizontal:
                    horizontalPadding,
                vertical:
                    30,
              ),
              child:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size:
                        iconSize,
                    color:
                        theme
                            .colorScheme
                            .onSurface
                            .withValues(
                      alpha:
                          0.30,
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          16,
                      min:
                          10,
                      max:
                          22,
                    ),
                  ),

                  Text(
                    title,
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          titleSize,
                      fontWeight:
                          FontWeight
                              .bold,
                      color:
                          theme
                              .colorScheme
                              .onSurface,
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          8,
                      min:
                          6,
                      max:
                          12,
                    ),
                  ),

                  Text(
                    message,
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          Responsive.bodyTextSize(
                        context,
                        base:
                            13,
                        min:
                            12,
                        max:
                            16,
                      ),
                      height:
                          1.4,
                      color:
                          theme
                              .colorScheme
                              .onSurface
                              .withValues(
                        alpha:
                            0.60,
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

class _ErrorState
    extends StatelessWidget {
  final String message;
  final Future<void>
      Function()
      onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final iconSize =
        Responsive.clamped(
      context,
      base:
          60,
      min:
          50,
      max:
          76,
    );

    final titleSize =
        Responsive.titleSize(
      context,
      base:
          18,
      min:
          16,
      max:
          24,
    );

    final buttonHeight =
        Responsive.buttonHeight(
      context,
    );

    return Center(
      child:
          Padding(
        padding:
            EdgeInsets.all(
          Responsive.cardPadding(
            context,
          ),
        ),
        child:
            ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth:
                560,
          ),
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons
                    .cloud_off_rounded,
                size:
                    iconSize,
                color:
                    theme
                        .colorScheme
                        .error,
              ),

              SizedBox(
                height:
                    Responsive.spacing(
                  context,
                  base:
                      16,
                  min:
                      10,
                  max:
                      22,
                ),
              ),

              Text(
                message,
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize:
                      titleSize,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      theme
                          .colorScheme
                          .onSurface,
                ),
              ),

              SizedBox(
                height:
                    Responsive.spacing(
                  context,
                  base:
                      18,
                  min:
                      12,
                  max:
                      24,
                ),
              ),

              SizedBox(
                height:
                    buttonHeight,
                child:
                    ElevatedButton
                        .icon(
                  onPressed:
                      onRetry,
                  icon:
                      const Icon(
                    Icons
                        .refresh_rounded,
                  ),
                  label:
                      const Text(
                    'Try Again',
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