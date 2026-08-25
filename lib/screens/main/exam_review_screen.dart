import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExamReviewScreen extends StatefulWidget {
  final String attemptId;
  final String examId;
  final String examTitle;

  const ExamReviewScreen({
    super.key,
    required this.attemptId,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late Future<List<_ReviewQuestion>> _reviewFuture;

  int _currentQuestionIndex = 0;

  @override
  void initState() {
    super.initState();
    _reviewFuture = _loadReview();
  }

  // ===========================================================================
  // LOAD REVIEW
  // ===========================================================================

  Future<List<_ReviewQuestion>> _loadReview() async {
    final response = await _supabase.rpc(
      'get_exam_review',
      params: {
        'p_attempt_id': widget.attemptId,
      },
    );

    if (response == null) {
      return [];
    }

    final rawQuestions = response as List;

    final questions = <_ReviewQuestion>[];

    for (final rawQuestion in rawQuestions) {
      final item = Map<String, dynamic>.from(
        rawQuestion as Map,
      );

      final questionId =
          item['question_id']?.toString() ?? '';

      if (questionId.isEmpty) {
        continue;
      }

      final selectedOptionId =
          _toNullableString(
        item['selected_option_id'],
      );

      final correctOptionId =
          _toNullableString(
        item['correct_option_id'],
      );

      final rawOptions =
          item['options'] as List? ?? [];

      final options = <_ReviewOption>[];

      for (final rawOption in rawOptions) {
        final option =
            Map<String, dynamic>.from(
          rawOption as Map,
        );

        final optionId =
            option['id']?.toString() ?? '';

        if (optionId.isEmpty) {
          continue;
        }

        options.add(
          _ReviewOption(
            id: optionId,
            text:
                option['text']?.toString() ?? '',
            displayOrder:
                (option['display_order']
                            as num?)
                        ?.toInt() ??
                    0,
          ),
        );
      }

      options.sort(
        (a, b) => a.displayOrder.compareTo(
          b.displayOrder,
        ),
      );

      questions.add(
        _ReviewQuestion(
          id: questionId,
          questionText:
              item['question_text']?.toString() ?? '',
          explanation:
              item['explanation']?.toString(),
          selectedOptionId:
              selectedOptionId,
          correctOptionId:
              correctOptionId,
          options: options,
        ),
      );
    }

    return questions;
  }

  // ===========================================================================
  // NULLABLE STRING
  // ===========================================================================

  String? _toNullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty || text == 'null') {
      return null;
    }

    return text;
  }

  // ===========================================================================
  // NEXT
  // ===========================================================================

  void _nextQuestion(
    List<_ReviewQuestion> questions,
  ) {
    if (_currentQuestionIndex >=
        questions.length - 1) {
      return;
    }

    setState(() {
      _currentQuestionIndex++;
    });
  }

  // ===========================================================================
  // PREVIOUS
  // ===========================================================================

  void _previousQuestion() {
    if (_currentQuestionIndex <= 0) {
      return;
    }

    setState(() {
      _currentQuestionIndex--;
    });
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refresh() async {
    setState(() {
      _reviewFuture = _loadReview();
    });

    await _reviewFuture;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Review Answers',
        ),
      ),
      body: FutureBuilder<List<_ReviewQuestion>>(
        future: _reviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            debugPrint(
              'Exam review error: ${snapshot.error}',
            );

            return _ReviewErrorView(
              onRetry: _refresh,
            );
          }

          final questions =
              snapshot.data ?? [];

          if (questions.isEmpty) {
            return const _ReviewEmptyView();
          }

          if (_currentQuestionIndex < 0) {
            _currentQuestionIndex = 0;
          }

          if (_currentQuestionIndex >=
              questions.length) {
            _currentQuestionIndex =
                questions.length - 1;
          }

          final question =
              questions[_currentQuestionIndex];

          final isAnswered =
              question.selectedOptionId != null;

          return Column(
            children: [
              // =================================================================
              // PROGRESS
              // =================================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  8,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Question '
                          '${_currentQuestionIndex + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${questions.length}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.60),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value:
                          (_currentQuestionIndex + 1) /
                              questions.length,
                    ),
                  ],
                ),
              ),

              // =================================================================
              // CONTENT
              // =================================================================

              Expanded(
                child: SingleChildScrollView(
                  physics:
                      const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    20,
                    18,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ---------------------------------------------------------
                      // QUESTION
                      // ---------------------------------------------------------

                      Text(
                        question.questionText,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ---------------------------------------------------------
                      // NOT ANSWERED
                      // ---------------------------------------------------------

                      if (!isAnswered)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(
                            bottom: 16,
                          ),
                          padding:
                              const EdgeInsets.all(14),
                          decoration:
                              BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(14),
                            color: theme
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons
                                    .help_outline_rounded,
                                size: 21,
                                color: theme
                                    .colorScheme
                                    .onSurface
                                    .withValues(
                                  alpha: 0.60,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Not answered',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ---------------------------------------------------------
                      // OPTIONS
                      // ---------------------------------------------------------

                      ...question.options.map(
                        (option) {
                          final isSelected =
                              question.selectedOptionId ==
                                  option.id;

                          final isCorrect =
                              question.correctOptionId ==
                                  option.id;

                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: _ReviewOptionCard(
                              option: option,
                              isSelected: isSelected,
                              isCorrect: isCorrect,
                            ),
                          );
                        },
                      ),

                      // ---------------------------------------------------------
                      // EXPLANATION
                      // ---------------------------------------------------------

                      if (question.explanation != null &&
                          question.explanation!
                              .trim()
                              .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(16),
                            color: theme
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.07),
                            border: Border.all(
                              color: theme
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons
                                        .lightbulb_outline_rounded,
                                    size: 21,
                                    color: theme
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Explanation',
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.w800,
                                      color: theme
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                question.explanation!.trim(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // =================================================================
              // NAVIGATION
              // =================================================================

              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    14,
                  ),
                  child: Row(
                    children: [
                      if (_currentQuestionIndex > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _previousQuestion,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                            ),
                            label:
                                const Text('Previous'),
                          ),
                        ),

                      if (_currentQuestionIndex > 0)
                        const SizedBox(width: 12),

                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              _currentQuestionIndex <
                                      questions.length - 1
                                  ? () {
                                      _nextQuestion(
                                        questions,
                                      );
                                    }
                                  : () {
                                      Navigator.of(
                                        context,
                                      ).pop();
                                    },
                          icon: Icon(
                            _currentQuestionIndex <
                                    questions.length - 1
                                ? Icons
                                    .arrow_forward_rounded
                                : Icons.check_rounded,
                          ),
                          label: Text(
                            _currentQuestionIndex <
                                    questions.length - 1
                                ? 'Next'
                                : 'Done',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// REVIEW OPTION CARD
// ============================================================================

class _ReviewOptionCard extends StatelessWidget {
  final _ReviewOption option;
  final bool isSelected;
  final bool isCorrect;

  const _ReviewOptionCard({
    required this.option,
    required this.isSelected,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ========================================================================
    // STUDENT ANSWER IS CORRECT
    // ========================================================================

    if (isSelected && isCorrect) {
      return _HighlightedOptionCard(
        backgroundColor:
            Colors.green.withValues(alpha: 0.09),
        borderColor: Colors.green,
        icon: Icons.check_circle_rounded,
        iconColor: Colors.green,
        optionText: option.text,
        labels: const [
          'Your answer',
          'Correct answer',
        ],
        labelColor: Colors.green,
      );
    }

    // ========================================================================
    // STUDENT ANSWER IS WRONG
    // ========================================================================

    if (isSelected && !isCorrect) {
      final errorColor =
          theme.colorScheme.error;

      return _HighlightedOptionCard(
        backgroundColor:
            errorColor.withValues(alpha: 0.08),
        borderColor: errorColor,
        icon: Icons.cancel_rounded,
        iconColor: errorColor,
        optionText: option.text,
        labels: const [
          'Your answer',
        ],
        labelColor: errorColor,
      );
    }

    // ========================================================================
    // CORRECT ANSWER
    // ========================================================================

    if (!isSelected && isCorrect) {
      return _HighlightedOptionCard(
        backgroundColor:
            Colors.green.withValues(alpha: 0.09),
        borderColor: Colors.green,
        icon: Icons.check_circle_rounded,
        iconColor: Colors.green,
        optionText: option.text,
        labels: const [
          'Correct answer',
        ],
        labelColor: Colors.green,
      );
    }

    // ========================================================================
    // NORMAL OPTION
    // ========================================================================

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: theme
              .colorScheme
              .outline
              .withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.radio_button_unchecked,
            size: 22,
            color: theme
                .colorScheme
                .onSurface
                .withValues(alpha: 0.35),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              option.text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HIGHLIGHTED OPTION CARD
// ============================================================================

class _HighlightedOptionCard
    extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;

  final String optionText;
  final List<String> labels;
  final Color labelColor;

  const _HighlightedOptionCard({
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.optionText,
    required this.labels,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(14),
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 23,
            color: iconColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  optionText,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                ...labels.map(
                  (label) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 2,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w800,
                        color: labelColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// QUESTION MODEL
// ============================================================================

class _ReviewQuestion {
  final String id;
  final String questionText;
  final String? explanation;

  final String? selectedOptionId;
  final String? correctOptionId;

  final List<_ReviewOption> options;

  const _ReviewQuestion({
    required this.id,
    required this.questionText,
    required this.explanation,
    required this.selectedOptionId,
    required this.correctOptionId,
    required this.options,
  });
}

// ============================================================================
// OPTION MODEL
// ============================================================================

class _ReviewOption {
  final String id;
  final String text;
  final int displayOrder;

  const _ReviewOption({
    required this.id,
    required this.text,
    required this.displayOrder,
  });
}

// ============================================================================
// EMPTY VIEW
// ============================================================================

class _ReviewEmptyView
    extends StatelessWidget {
  const _ReviewEmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 65,
              color: theme
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            const Text(
              'No review data available.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ReviewErrorView
    extends StatelessWidget {
  final Future<void> Function()
      onRetry;

  const _ReviewErrorView({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 60,
              color:
                  theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load exam review.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}