import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../services/student_profile_service.dart';

class ExamHistoryScreen extends StatefulWidget {
  final void Function(
    StudentExamAttempt attempt,
  )?
  onAttemptTap;

  const ExamHistoryScreen({
    super.key,
    this.onAttemptTap,
  });

  @override
  State<ExamHistoryScreen> createState() =>
      _ExamHistoryScreenState();
}

class _ExamHistoryScreenState
    extends State<ExamHistoryScreen> {
  final StudentProfileService _service =
      StudentProfileService.instance;

  late Future<List<StudentExamAttempt>>
      _future;

  String _filter = 'all';

  @override
  void initState() {
    super.initState();

    _future = _loadHistory();
  }

  // ==========================================================================
  // LOAD ALL ATTEMPTS
  // ==========================================================================

  Future<List<StudentExamAttempt>>
      _loadHistory() async {
    final analytics =
        await _service.getAnalytics();

    return analytics.attempts;
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _future = _loadHistory();
    });

    await _future;
  }

  // ==========================================================================
  // FILTER
  // ==========================================================================

  List<StudentExamAttempt> _applyFilter(
    List<StudentExamAttempt> attempts,
  ) {
    switch (_filter) {
      case 'passed':
        return attempts
            .where(
              (attempt) =>
                  attempt.isCompleted &&
                  attempt.passed,
            )
            .toList();

      case 'failed':
        return attempts
            .where(
              (attempt) =>
                  attempt.isCompleted &&
                  !attempt.passed,
            )
            .toList();

      case 'in_progress':
        return attempts
            .where(
              (attempt) =>
                  attempt.isInProgress,
            )
            .toList();

      default:
        return attempts;
    }
  }

  // ==========================================================================
  // GROUP BY MODULE -> LECTURE
  // ==========================================================================

  Map<String,
      Map<String, List<StudentExamAttempt>>>
      _groupAttempts(
    List<StudentExamAttempt> attempts,
  ) {
    final grouped =
        <String,
            Map<String,
                List<StudentExamAttempt>>>{};

    for (final attempt in attempts) {
      final moduleId =
          attempt.moduleId.trim();

      final lectureId =
          attempt.lectureId.trim();

      final moduleKey =
          moduleId.isNotEmpty
              ? moduleId
              : 'unknown_module';

      final lectureKey =
          lectureId.isNotEmpty
              ? lectureId
              : 'unknown_lecture';

      grouped
          .putIfAbsent(
            moduleKey,
            () => <String,
                List<StudentExamAttempt>>{},
          )
          .putIfAbsent(
            lectureKey,
            () => <StudentExamAttempt>[],
          )
          .add(
            attempt,
          );
    }

    // ------------------------------------------------------------------------
    // SORT EACH LECTURE:
    // NEWEST FIRST
    // ------------------------------------------------------------------------

    for (final module
        in grouped.values) {
      for (final lectureAttempts
          in module.values) {
        lectureAttempts.sort(
          (
            a,
            b,
          ) {
            final aDate =
                a.startedAt ??
                    DateTime.fromMillisecondsSinceEpoch(
                      0,
                    );

            final bDate =
                b.startedAt ??
                    DateTime.fromMillisecondsSinceEpoch(
                      0,
                    );

            return bDate.compareTo(
              aDate,
            );
          },
        );
      }
    }

    return grouped;
  }

  // ==========================================================================
  // FORMAT DATE
  // ==========================================================================

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Unknown date';
    }

    final local =
        date.toLocal();

    final day =
        local.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final month =
        local.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final year =
        local.year.toString();

    final hour =
        local.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final minute =
        local.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/$year • '
        '$hour:$minute';
  }

  // ==========================================================================
  // STATUS COLOR
  // ==========================================================================

  Color _statusColor(
    BuildContext context,
    StudentExamAttempt attempt,
  ) {
    final theme =
        Theme.of(context);

    if (attempt.isInProgress) {
      return theme
          .colorScheme
          .primary;
    }

    if (attempt.isCompleted) {
      return attempt.passed
          ? Colors.green
          : theme
              .colorScheme
              .error;
    }

    return Colors.orange;
  }

  // ==========================================================================
  // STATUS LABEL
  // ==========================================================================

  String _statusLabel(
    StudentExamAttempt attempt,
  ) {
    if (attempt.isInProgress) {
      return 'In Progress';
    }

    if (attempt.isCompleted) {
      return attempt.passed
          ? 'Passed'
          : 'Failed';
    }

    return 'Abandoned';
  }

  // ==========================================================================
  // STATUS ICON
  // ==========================================================================

  IconData _statusIcon(
    StudentExamAttempt attempt,
  ) {
    if (attempt.isInProgress) {
      return Icons.play_arrow_rounded;
    }

    if (attempt.isCompleted) {
      return attempt.passed
          ? Icons.check_rounded
          : Icons.close_rounded;
    }

    return Icons.warning_amber_rounded;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'Exam History',
        ),
      ),
      body:
          RefreshIndicator(
        onRefresh:
            _refresh,
        color:
            theme
                .colorScheme
                .primary,
        child:
            FutureBuilder<
                List<StudentExamAttempt>>(
          future:
              _future,
          builder:
              (
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
              debugPrint(
                'Exam history error: '
                '${snapshot.error}',
              );

              return _ErrorState(
                onRetry:
                    _refresh,
              );
            }

            final attempts =
                snapshot.data ??
                    [];

            final filtered =
                _applyFilter(
              attempts,
            );

            if (filtered.isEmpty) {
              return _EmptyState(
                filter:
                    _filter,
              );
            }

            final grouped =
                _groupAttempts(
              filtered,
            );

            final moduleEntries =
                grouped.entries.toList();

            return LayoutBuilder(
              builder:
                  (
                context,
                constraints,
              ) {
                final horizontalPadding =
                    Responsive.horizontalPadding(
                  context,
                );

                final maxWidth =
                    constraints.maxWidth >
                            1000
                        ? 1000.0
                        : constraints
                            .maxWidth;

                return ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(
                    parent:
                        BouncingScrollPhysics(),
                  ),
                  padding:
                      EdgeInsets.fromLTRB(
                    horizontalPadding,
                    Responsive.spacing(
                      context,
                      base:
                          14,
                      min:
                          10,
                      max:
                          24,
                    ),
                    horizontalPadding,
                    Responsive.scrollBottomPadding(
                      context,
                      base:
                          30,
                    ),
                  ),
                  children: [
                    Center(
                      child:
                          ConstrainedBox(
                        constraints:
                            BoxConstraints(
                          maxWidth:
                              maxWidth,
                        ),
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .stretch,
                          children: [
                            // =================================================
                            // FILTER
                            // =================================================

                            _FilterBar(
                              selected:
                                  _filter,
                              onChanged:
                                  (
                                value,
                              ) {
                                setState(
                                  () {
                                    _filter =
                                        value;
                                  },
                                );
                              },
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

                            // =================================================
                            // TOTAL
                            // =================================================

                            Row(
                              children: [
                                Expanded(
                                  child:
                                      Text(
                                    '${filtered.length} exam attempt${filtered.length == 1 ? '' : 's'}',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          Responsive.smallTextSize(
                                        context,
                                        base:
                                            12,
                                        min:
                                            10,
                                        max:
                                            15,
                                      ),
                                      color:
                                          theme
                                              .colorScheme
                                              .onSurface
                                              .withValues(
                                        alpha:
                                            0.55,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${moduleEntries.length} module${moduleEntries.length == 1 ? '' : 's'}',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        Responsive.smallTextSize(
                                      context,
                                      base:
                                          12,
                                      min:
                                          10,
                                      max:
                                          15,
                                    ),
                                    color:
                                        theme
                                            .colorScheme
                                            .onSurface
                                            .withValues(
                                      alpha:
                                          0.55,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height:
                                  12,
                            ),

                            // =================================================
                            // MODULES
                            // =================================================

                            ...moduleEntries.map(
                              (
                                moduleEntry,
                              ) {
                                final lectureGroups =
                                    moduleEntry.value;

                                final allModuleAttempts =
                                    <StudentExamAttempt>[];

                                for (final lectureAttempts
                                    in lectureGroups
                                        .values) {
                                  allModuleAttempts
                                      .addAll(
                                    lectureAttempts,
                                  );
                                }

                                final moduleName =
                                    _resolveModuleName(
                                  moduleEntry.key,
                                  allModuleAttempts,
                                );

                                return Padding(
                                  padding:
                                      EdgeInsets.only(
                                    bottom:
                                        Responsive.spacing(
                                      context,
                                      base:
                                          18,
                                      min:
                                          14,
                                      max:
                                          26,
                                    ),
                                  ),
                                  child:
                                      _ModuleSection(
                                    moduleName:
                                        moduleName,
                                    lectures:
                                        lectureGroups,
                                    statusColor:
                                        _statusColor,
                                    statusLabel:
                                        _statusLabel,
                                    statusIcon:
                                        _statusIcon,
                                    formatDate:
                                        _formatDate,
                                    onAttemptTap:
                                        widget
                                            .onAttemptTap,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // RESOLVE MODULE NAME
  // ==========================================================================

  String _resolveModuleName(
    String moduleId,
    List<StudentExamAttempt> attempts,
  ) {
    for (final attempt in attempts) {
      if (attempt.moduleId ==
          moduleId) {
        final name =
            attempt.moduleName
                .trim();

        if (name.isNotEmpty) {
          return name;
        }
      }
    }

    return 'Module';
  }
}

// ============================================================================
// MODULE SECTION
// ============================================================================

class _ModuleSection
    extends StatelessWidget {
  final String moduleName;

  final Map<String,
      List<StudentExamAttempt>>
      lectures;

  final Color Function(
    BuildContext,
    StudentExamAttempt,
  ) statusColor;

  final String Function(
    StudentExamAttempt,
  ) statusLabel;

  final IconData Function(
    StudentExamAttempt,
  ) statusIcon;

  final String Function(
    DateTime?,
  ) formatDate;

  final void Function(
    StudentExamAttempt,
  )?
  onAttemptTap;

  const _ModuleSection({
    required this.moduleName,
    required this.lectures,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    required this.formatDate,
    required this.onAttemptTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final moduleAttempts =
        lectures.values
            .expand(
              (
                attempts,
              ) =>
                  attempts,
            )
            .toList();

    final completedAttempts =
        moduleAttempts
            .where(
              (
                attempt,
              ) =>
                  attempt.isCompleted,
            )
            .toList();

    final passedAttempts =
        completedAttempts
            .where(
              (
                attempt,
              ) =>
                  attempt.passed,
            )
            .toList();

    final bestScore =
        completedAttempts.isEmpty
            ? 0
            : completedAttempts
                .map(
                  (
                    attempt,
                  ) =>
                      attempt.score,
                )
                .reduce(
                  (
                    a,
                    b,
                  ) =>
                      a > b ? a : b,
                );

    final lectureEntries =
        lectures.entries.toList();

    return Container(
      width:
          double.infinity,
      decoration:
          BoxDecoration(
        color:
            theme
                .colorScheme
                .surface,
        borderRadius:
            BorderRadius.circular(
          Responsive.cardRadius(
            context,
          ),
        ),
        border:
            Border.all(
          color:
              theme
                  .colorScheme
                  .outline
                  .withValues(
            alpha:
                0.16,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ===================================================================
          // MODULE HEADER
          // ===================================================================

          Container(
            width:
                double.infinity,
            padding:
                EdgeInsets.all(
              Responsive.cardPadding(
                context,
              ),
            ),
            decoration:
                BoxDecoration(
              color:
                  theme
                      .colorScheme
                      .primary
                      .withValues(
                alpha:
                    0.07,
              ),
              borderRadius:
                  BorderRadius.only(
                topLeft:
                    Radius.circular(
                  Responsive.cardRadius(
                    context,
                  ),
                ),
                topRight:
                    Radius.circular(
                  Responsive.cardRadius(
                    context,
                  ),
                ),
              ),
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width:
                          Responsive.clamped(
                        context,
                        base:
                            44,
                        min:
                            38,
                        max:
                            52,
                      ),
                      height:
                          Responsive.clamped(
                        context,
                        base:
                            44,
                        min:
                            38,
                        max:
                            52,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            theme
                                .colorScheme
                                .primary
                                .withValues(
                          alpha:
                              0.12,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child:
                          Icon(
                        Icons.folder_rounded,
                        color:
                            theme
                                .colorScheme
                                .primary,
                      ),
                    ),
                    const SizedBox(
                      width:
                          12,
                    ),
                    Expanded(
                      child:
                          Text(
                        moduleName,
                        maxLines:
                            2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            TextStyle(
                          fontSize:
                              Responsive.titleSize(
                            context,
                            base:
                                18,
                            min:
                                16,
                            max:
                                24,
                          ),
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                      14,
                ),

                // =============================================================
                // MODULE SUMMARY
                // =============================================================

                Wrap(
                  spacing:
                      8,
                  runSpacing:
                      8,
                  children: [
                    _SummaryChip(
                      icon:
                          Icons
                              .play_lesson_outlined,
                      label:
                          '${lectureEntries.length} lecture${lectureEntries.length == 1 ? '' : 's'}',
                      color:
                          theme
                              .colorScheme
                              .primary,
                    ),
                    _SummaryChip(
                      icon:
                          Icons.quiz_outlined,
                      label:
                          '${moduleAttempts.length} attempt${moduleAttempts.length == 1 ? '' : 's'}',
                      color:
                          Colors.indigo,
                    ),
                    _SummaryChip(
                      icon:
                          Icons.check_circle_outline_rounded,
                      label:
                          '${passedAttempts.length} passed',
                      color:
                          Colors.green,
                    ),
                    if (completedAttempts.isNotEmpty)
                      _SummaryChip(
                        icon:
                            Icons
                                .emoji_events_outlined,
                        label:
                            'Best $bestScore%',
                        color:
                            Colors.amber.shade800,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ===================================================================
          // LECTURES
          // ===================================================================

          ...lectureEntries.map(
            (
              lectureEntry,
            ) {
              final attempts =
                  lectureEntry.value;

              return Padding(
                padding:
                    EdgeInsets.fromLTRB(
                  Responsive.cardPadding(
                    context,
                  ),
                  Responsive.cardPadding(
                    context,
                  ),
                  Responsive.cardPadding(
                    context,
                  ),
                  0,
                ),
                child:
                    _LectureSection(
                  lectureName:
                      _resolveLectureName(
                    attempts,
                  ),
                  attempts:
                      attempts,
                  statusColor:
                      statusColor,
                  statusLabel:
                      statusLabel,
                  statusIcon:
                      statusIcon,
                  formatDate:
                      formatDate,
                  onAttemptTap:
                      onAttemptTap,
                ),
              );
            },
          ),

          SizedBox(
            height:
                Responsive.cardPadding(
              context,
            ),
          ),
        ],
      ),
    );
  }

  String _resolveLectureName(
    List<StudentExamAttempt> attempts,
  ) {
    for (final attempt in attempts) {
      final name =
          attempt.lectureTitle
              .trim();

      if (name.isNotEmpty) {
        return name;
      }
    }

    return 'Lecture';
  }
}

// ============================================================================
// LECTURE SECTION
// ============================================================================

class _LectureSection
    extends StatelessWidget {
  final String lectureName;

  final List<StudentExamAttempt>
      attempts;

  final Color Function(
    BuildContext,
    StudentExamAttempt,
  ) statusColor;

  final String Function(
    StudentExamAttempt,
  ) statusLabel;

  final IconData Function(
    StudentExamAttempt,
  ) statusIcon;

  final String Function(
    DateTime?,
  ) formatDate;

  final void Function(
    StudentExamAttempt,
  )?
  onAttemptTap;

  const _LectureSection({
    required this.lectureName,
    required this.attempts,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    required this.formatDate,
    required this.onAttemptTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final completed =
        attempts
            .where(
              (
                attempt,
              ) =>
                  attempt.isCompleted,
            )
            .toList();

    final passed =
        completed
            .where(
              (
                attempt,
              ) =>
                  attempt.passed,
            )
            .toList();

    final bestScore =
        completed.isEmpty
            ? 0
            : completed
                .map(
                  (
                    attempt,
                  ) =>
                      attempt.score,
                )
                .reduce(
                  (
                    a,
                    b,
                  ) =>
                      a > b ? a : b,
                );

    final latest =
        attempts.isEmpty
            ? null
            : attempts.first;

    final latestLabel =
        latest == null
            ? 'No attempts'
            : statusLabel(
                latest,
              );

    final latestColor =
        latest == null
            ? theme
                .colorScheme
                .onSurface
                .withValues(
                  alpha:
                      0.50,
                )
            : statusColor(
                context,
                latest,
              );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // =====================================================================
        // LECTURE HEADER
        // =====================================================================

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width:
                  Responsive.clamped(
                context,
                base:
                    40,
                min:
                    36,
                max:
                    48,
              ),
              height:
                  Responsive.clamped(
                context,
                base:
                    40,
                min:
                    36,
                max:
                    48,
              ),
              decoration:
                  BoxDecoration(
                color:
                    theme
                        .colorScheme
                        .primary
                        .withValues(
                  alpha:
                      0.08,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child:
                  Icon(
                Icons
                    .play_lesson_outlined,
                size:
                    Responsive.iconSize(
                  context,
                  base:
                      21,
                  min:
                      18,
                  max:
                      26,
                ),
                color:
                    theme
                        .colorScheme
                        .primary,
              ),
            ),

            const SizedBox(
              width:
                  10,
            ),

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    lectureName,
                    maxLines:
                        2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        TextStyle(
                      fontSize:
                          Responsive.bodyTextSize(
                        context,
                        base:
                            15,
                        min:
                            13,
                        max:
                            19,
                      ),
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height:
                        5,
                  ),

                  // ==========================================================
                  // LECTURE SUMMARY
                  // ==========================================================

                  Wrap(
                    spacing:
                        7,
                    runSpacing:
                        6,
                    children: [
                      _SummaryChip(
                        icon:
                            Icons.quiz_outlined,
                        label:
                            '${attempts.length} attempt${attempts.length == 1 ? '' : 's'}',
                        color:
                            theme
                                .colorScheme
                                .primary,
                      ),

                      if (completed
                          .isNotEmpty)
                        _SummaryChip(
                          icon:
                              Icons
                                  .emoji_events_outlined,
                          label:
                              'Best $bestScore%',
                          color:
                              Colors.amber.shade800,
                        ),

                      if (passed
                          .isNotEmpty)
                        _SummaryChip(
                          icon:
                              Icons
                                  .check_circle_outline_rounded,
                          label:
                              '${passed.length} passed',
                          color:
                              Colors.green,
                        ),

                      _SummaryChip(
                        icon:
                            latest?.isInProgress ==
                                    true
                                ? Icons
                                    .play_circle_outline_rounded
                                : Icons
                                    .update_rounded,
                        label:
                            'Last: $latestLabel',
                        color:
                            latestColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(
          height:
              12,
        ),

        // =====================================================================
        // ALL ATTEMPTS
        // =====================================================================

        ...attempts.map(
          (
            attempt,
          ) {
            return Padding(
              padding:
                  const EdgeInsets.only(
                bottom:
                    8,
              ),
              child:
                  _AttemptCard(
                attempt:
                    attempt,
                date:
                    formatDate(
                  attempt.isCompleted
                      ? attempt.completedAt
                      : attempt.startedAt,
                ),
                statusColor:
                    statusColor(
                  context,
                  attempt,
                ),
                statusLabel:
                    statusLabel(
                  attempt,
                ),
                statusIcon:
                    statusIcon(
                  attempt,
                ),
                onTap:
                    onAttemptTap == null
                        ? null
                        : () =>
                            onAttemptTap!(
                              attempt,
                            ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// SUMMARY CHIP
// ============================================================================

class _SummaryChip
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            8,
        vertical:
            5,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha:
              0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size:
                14,
            color:
                color,
          ),
          const SizedBox(
            width:
                4,
          ),
          Text(
            label,
            style:
                TextStyle(
              fontSize:
                  10,
              fontWeight:
                  FontWeight.w700,
              color:
                  color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FILTER BAR
// ============================================================================

class _FilterBar
    extends StatelessWidget {
  final String selected;
  final ValueChanged<String>
      onChanged;

  const _FilterBar({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    const filters = [
      (
        value:
            'all',
        label:
            'All',
      ),
      (
        value:
            'passed',
        label:
            'Passed',
      ),
      (
        value:
            'failed',
        label:
            'Failed',
      ),
      (
        value:
            'in_progress',
        label:
            'In Progress',
      ),
    ];

    return Align(
      alignment:
          Alignment.centerLeft,
      child:
          SingleChildScrollView(
        scrollDirection:
            Axis.horizontal,
        child:
            Row(
          children:
              filters.map(
            (
              filter,
            ) {
              final isSelected =
                  selected ==
                      filter.value;

              return Padding(
                padding:
                    const EdgeInsets.only(
                  right:
                      8,
                ),
                child:
                    ChoiceChip(
                  label:
                      Text(
                    filter.label,
                  ),
                  selected:
                      isSelected,
                  onSelected:
                      (_) {
                    onChanged(
                      filter.value,
                    );
                  },
                  selectedColor:
                      theme
                          .colorScheme
                          .primary
                          .withValues(
                    alpha:
                        0.12,
                  ),
                  labelStyle:
                      TextStyle(
                    fontWeight:
                        isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                    color:
                        isSelected
                            ? theme
                                .colorScheme
                                .primary
                            : theme
                                .colorScheme
                                .onSurface,
                  ),
                  side:
                      BorderSide(
                    color:
                        isSelected
                            ? theme
                                .colorScheme
                                .primary
                            : theme
                                .colorScheme
                                .outline
                                .withValues(
                                alpha:
                                    0.25,
                              ),
                  ),
                ),
              );
            },
          ).toList(),
        ),
      ),
    );
  }
}

// ============================================================================
// ATTEMPT CARD
// ============================================================================

class _AttemptCard
    extends StatelessWidget {
  final StudentExamAttempt attempt;

  final String date;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;

  final VoidCallback? onTap;

  const _AttemptCard({
    required this.attempt,
    required this.date,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Card(
      elevation:
          0,
      margin:
          EdgeInsets.zero,
      child:
          InkWell(
        borderRadius:
            BorderRadius.circular(
          Responsive.smallRadius(
            context,
          ),
        ),
        onTap:
            onTap,
        child:
            Padding(
          padding:
              EdgeInsets.all(
            Responsive.cardPadding(
              context,
            ),
          ),
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Container(
                    width:
                        Responsive.clamped(
                      context,
                      base:
                          44,
                      min:
                          38,
                      max:
                          52,
                    ),
                    height:
                        Responsive.clamped(
                      context,
                      base:
                          44,
                      min:
                          38,
                      max:
                          52,
                    ),
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          statusColor
                              .withValues(
                        alpha:
                            0.10,
                      ),
                    ),
                    child:
                        Icon(
                      statusIcon,
                      color:
                          statusColor,
                    ),
                  ),

                  const SizedBox(
                    width:
                        10,
                  ),

                  Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          attempt
                              .examTitle,
                          maxLines:
                              2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              TextStyle(
                            fontSize:
                                Responsive.bodyTextSize(
                              context,
                              base:
                                  15,
                              min:
                                  13,
                              max:
                                  19,
                            ),
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                        const SizedBox(
                          height:
                              4,
                        ),
                        Text(
                          date,
                          style:
                              TextStyle(
                            fontSize:
                                Responsive.smallTextSize(
                              context,
                              base:
                                  11,
                              min:
                                  10,
                              max:
                                  14,
                            ),
                            color:
                                theme
                                    .colorScheme
                                    .onSurface
                                    .withValues(
                              alpha:
                                  0.52,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (onTap != null)
                    const Icon(
                      Icons
                          .chevron_right_rounded,
                    ),
                ],
              ),

              const SizedBox(
                height:
                    10,
              ),

              Wrap(
                spacing:
                    8,
                runSpacing:
                    7,
                children: [
                  _InfoChip(
                    icon:
                        Icons.flag_outlined,
                    label:
                        statusLabel,
                    color:
                        statusColor,
                  ),

                  if (attempt.isCompleted)
                    _InfoChip(
                      icon:
                          Icons.percent_rounded,
                      label:
                          '${attempt.score}%',
                      color:
                          theme
                              .colorScheme
                              .primary,
                    ),

                  if (attempt.totalQuestions >
                      0)
                    _InfoChip(
                      icon:
                          Icons
                              .check_circle_outline_rounded,
                      label:
                          '${attempt.correctAnswers}/${attempt.totalQuestions}',
                      color:
                          Colors.green,
                    ),

                  if (attempt.isCompleted)
                    _InfoChip(
                      icon:
                          Icons
                              .flag_circle_outlined,
                      label:
                          'Pass ${attempt.passingScore}%',
                      color:
                          Colors.deepOrange,
                    ),

                  if (attempt.isInProgress)
                    _InfoChip(
                      icon:
                          Icons
                              .timer_outlined,
                      label:
                          _formatRemaining(
                        attempt
                            .remainingSeconds,
                      ),
                      color:
                          theme
                              .colorScheme
                              .primary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatRemaining(
    int seconds,
  ) {
    final safeSeconds =
        seconds < 0
            ? 0
            : seconds;

    final minutes =
        safeSeconds ~/ 60;

    final remaining =
        safeSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// INFO CHIP
// ============================================================================

class _InfoChip
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            9,
        vertical:
            5,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(
          alpha:
              0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size:
                15,
            color:
                color,
          ),
          const SizedBox(
            width:
                5,
          ),
          Text(
            label,
            style:
                TextStyle(
              fontSize:
                  10.5,
              fontWeight:
                  FontWeight.w700,
              color:
                  color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// EMPTY
// ============================================================================

class _EmptyState
    extends StatelessWidget {
  final String filter;

  const _EmptyState({
    required this.filter,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final String message;

    switch (_filterValue(filter)) {
      case 'passed':
        message =
            'No passed exams yet.';
        break;

      case 'failed':
        message =
            'No failed exams yet.';
        break;

      case 'in_progress':
        message =
            'No exams are currently in progress.';
        break;

      default:
        message =
            'Your exam attempts will appear here.';
    }

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
                  EdgeInsets.all(
                Responsive.cardPadding(
                  context,
                ),
              ),
              child:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .history_rounded,
                    size:
                        64,
                    color:
                        theme
                            .colorScheme
                            .onSurface
                            .withValues(
                      alpha:
                          0.22,
                    ),
                  ),
                  const SizedBox(
                    height:
                        14,
                  ),
                  Text(
                    message,
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      fontSize:
                          18,
                      fontWeight:
                          FontWeight.w700,
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

  static String _filterValue(
    String value,
  ) =>
      value;
}

// ============================================================================
// ERROR
// ============================================================================

class _ErrorState
    extends StatelessWidget {
  final Future<void>
      Function()
      onRetry;

  const _ErrorState({
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
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
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .cloud_off_rounded,
              size:
                  58,
            ),
            const SizedBox(
              height:
                  14,
            ),
            const Text(
              'Unable to load exam history.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    17,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(
              height:
                  16,
            ),
            FilledButton.icon(
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
          ],
        ),
      ),
    );
  }
}
