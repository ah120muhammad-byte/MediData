import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';

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
  State<ExamReviewScreen> createState() =>
      _ExamReviewScreenState();
}

class _ExamReviewScreenState
    extends State<ExamReviewScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  late Future<List<_ReviewQuestion>>
      _reviewFuture;

  int _currentQuestionIndex = 0;

  @override
  void initState() {
    super.initState();

    _reviewFuture =
        _loadReview();
  }

  // ==========================================================================
  // LOAD REVIEW
  // ==========================================================================

  Future<List<_ReviewQuestion>>
      _loadReview() async {
    final response =
        await _supabase.rpc(
      'get_exam_review',
      params: {
        'p_attempt_id':
            widget.attemptId,
      },
    );

    if (response == null) {
      return [];
    }

    if (response is! List) {
      throw Exception(
        'Invalid exam review response.',
      );
    }

    final rawQuestions =
        response;

    final questions =
        <_ReviewQuestion>[];

    for (final rawQuestion
        in rawQuestions) {
      if (rawQuestion is! Map) {
        continue;
      }

      final item =
          Map<String, dynamic>.from(
        rawQuestion,
      );

      final questionId =
          item['question_id']
                  ?.toString() ??
              '';

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
          item['options'] is List
              ? item['options'] as List
              : const [];

      final options =
          <_ReviewOption>[];

      for (final rawOption
          in rawOptions) {
        if (rawOption is! Map) {
          continue;
        }

        final option =
            Map<String, dynamic>.from(
          rawOption,
        );

        final optionId =
            option['id']
                    ?.toString() ??
                '';

        if (optionId.isEmpty) {
          continue;
        }

        options.add(
          _ReviewOption(
            id:
                optionId,
            text:
                option['text']
                        ?.toString() ??
                    '',
            displayOrder:
                (option[
                            'display_order']
                        as num?)
                    ?.toInt() ??
                0,
          ),
        );
      }

      options.sort(
        (
          a,
          b,
        ) =>
            a.displayOrder.compareTo(
          b.displayOrder,
        ),
      );

      questions.add(
        _ReviewQuestion(
          id:
              questionId,
          questionText:
              item['question_text']
                      ?.toString() ??
                  '',
          explanation:
              item['explanation']
                  ?.toString(),
          selectedOptionId:
              selectedOptionId,
          correctOptionId:
              correctOptionId,
          options:
              options,
        ),
      );
    }

    return questions;
  }

  // ==========================================================================
  // NULLABLE STRING
  // ==========================================================================

  String? _toNullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty ||
        text == 'null') {
      return null;
    }

    return text;
  }

  // ==========================================================================
  // NEXT
  // ==========================================================================

  void _nextQuestion(
    List<_ReviewQuestion>
        questions,
  ) {
    if (_currentQuestionIndex >=
        questions.length - 1) {
      return;
    }

    setState(() {
      _currentQuestionIndex++;
    });
  }

  // ==========================================================================
  // PREVIOUS
  // ==========================================================================

  void _previousQuestion() {
    if (_currentQuestionIndex <=
        0) {
      return;
    }

    setState(() {
      _currentQuestionIndex--;
    });
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> _refresh() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _reviewFuture =
          _loadReview();
    });

    await _reviewFuture;
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
          'Review Answers',
        ),
      ),
      body:
          FutureBuilder<
              List<_ReviewQuestion>>(
        future:
            _reviewFuture,
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
            debugPrint(
              'Exam review error: ${snapshot.error}',
            );

            return _ReviewErrorView(
              onRetry:
                  _refresh,
            );
          }

          final questions =
              snapshot.data ??
                  [];

          if (questions.isEmpty) {
            return const _ReviewEmptyView();
          }

          if (_currentQuestionIndex <
              0) {
            _currentQuestionIndex =
                0;
          }

          if (_currentQuestionIndex >=
              questions.length) {
            _currentQuestionIndex =
                questions.length - 1;
          }

          final question =
              questions[
                  _currentQuestionIndex];

          final isAnswered =
              question
                      .selectedOptionId !=
                  null;

          final horizontalPadding =
              Responsive.horizontalPadding(
            context,
          );

          final contentMaxWidth =
              Responsive.width(
                    context,
                  ) >=
                  900
              ? 900.0
              : 760.0;

          return Column(
            children: [
              // =================================================================
              // PROGRESS HEADER
              // =================================================================

              Center(
                child:
                    ConstrainedBox(
                  constraints:
                      BoxConstraints(
                    maxWidth:
                        contentMaxWidth,
                  ),
                  child:
                      Padding(
                    padding:
                        EdgeInsets.fromLTRB(
                      horizontalPadding,
                      Responsive.spacing(
                        context,
                        base:
                            16,
                        min:
                            10,
                        max:
                            24,
                      ),
                      horizontalPadding,
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
                    child:
                        Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child:
                                  Text(
                                'Question ${_currentQuestionIndex + 1}',
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
                                        18,
                                  ),
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${questions.length}',
                              style:
                                  TextStyle(
                                fontSize:
                                    Responsive.bodyTextSize(
                                  context,
                                  base:
                                      14,
                                  min:
                                      12,
                                  max:
                                      17,
                                ),
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
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                          child:
                              LinearProgressIndicator(
                            value:
                                (_currentQuestionIndex +
                                        1) /
                                    questions.length,
                            minHeight:
                                Responsive.clamped(
                              context,
                              base:
                                  7,
                              min:
                                  5,
                              max:
                                  10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // =================================================================
              // CONTENT
              // =================================================================

              Expanded(
                child:
                    SingleChildScrollView(
                  physics:
                      const BouncingScrollPhysics(),
                  padding:
                      EdgeInsets.fromLTRB(
                    horizontalPadding,
                    Responsive.spacing(
                      context,
                      base:
                          20,
                      min:
                          14,
                      max:
                          30,
                    ),
                    horizontalPadding,
                    Responsive.spacing(
                      context,
                      base:
                          24,
                      min:
                          18,
                      max:
                          32,
                    ),
                  ),
                  child:
                      Center(
                    child:
                        ConstrainedBox(
                      constraints:
                          BoxConstraints(
                        maxWidth:
                            contentMaxWidth,
                      ),
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          // ======================================================
                          // EXAM TITLE
                          // ======================================================

                          Text(
                            widget.examTitle,
                            maxLines:
                                2,
                            overflow:
                                TextOverflow.ellipsis,
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
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  theme
                                      .colorScheme
                                      .primary,
                            ),
                          ),

                          SizedBox(
                            height:
                                Responsive.spacing(
                              context,
                              base:
                                  10,
                              min:
                                  7,
                              max:
                                  14,
                            ),
                          ),

                          // ======================================================
                          // QUESTION
                          // ======================================================

                          Text(
                            question.questionText,
                            style:
                                TextStyle(
                              fontSize:
                                  Responsive.clamped(
                                context,
                                base:
                                    21,
                                min:
                                    18,
                                max:
                                    30,
                              ),
                              fontWeight:
                                  FontWeight.w700,
                              height:
                                  1.35,
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
                                  26,
                            ),
                          ),

                          // ======================================================
                          // NOT ANSWERED
                          // ======================================================

                          if (!isAnswered)
                            Padding(
                              padding:
                                  EdgeInsets.only(
                                bottom:
                                    Responsive.spacing(
                                  context,
                                  base:
                                      16,
                                  min:
                                      10,
                                  max:
                                      20,
                                ),
                              ),
                              child:
                                  _NotAnsweredCard(),
                            ),

                          // ======================================================
                          // OPTIONS
                          // ======================================================

                          ...question.options.map(
                            (
                              option,
                            ) {
                              final isSelected =
                                  question
                                          .selectedOptionId ==
                                      option.id;

                              final isCorrect =
                                  question
                                          .correctOptionId ==
                                      option.id;

                              return Padding(
                                padding:
                                    EdgeInsets.only(
                                  bottom:
                                      Responsive.spacing(
                                    context,
                                    base:
                                        12,
                                    min:
                                        8,
                                    max:
                                        16,
                                  ),
                                ),
                                child:
                                    _ReviewOptionCard(
                                  option:
                                      option,
                                  isSelected:
                                      isSelected,
                                  isCorrect:
                                      isCorrect,
                                ),
                              );
                            },
                          ),

                          // ======================================================
                          // EXPLANATION
                          // ======================================================

                          if (question.explanation !=
                                  null &&
                              question
                                  .explanation!
                                  .trim()
                                  .isNotEmpty) ...[
                            SizedBox(
                              height:
                                  Responsive.spacing(
                                context,
                                base:
                                    8,
                                min:
                                    5,
                                max:
                                    12,
                              ),
                            ),
                            _ExplanationCard(
                              explanation:
                                  question
                                      .explanation!
                                      .trim(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // =================================================================
              // NAVIGATION
              // =================================================================

              SafeArea(
                top:
                    false,
                child:
                    Center(
                  child:
                      ConstrainedBox(
                    constraints:
                        BoxConstraints(
                      maxWidth:
                          contentMaxWidth,
                    ),
                    child:
                        Padding(
                      padding:
                          EdgeInsets.fromLTRB(
                        horizontalPadding,
                        Responsive.spacing(
                          context,
                          base:
                              8,
                          min:
                              6,
                          max:
                              12,
                        ),
                        horizontalPadding,
                        Responsive.spacing(
                          context,
                          base:
                              14,
                          min:
                              10,
                          max:
                              20,
                        ),
                      ),
                      child:
                          Row(
                        children: [
                          if (_currentQuestionIndex >
                              0)
                            Expanded(
                              child:
                                  OutlinedButton.icon(
                                onPressed:
                                    _previousQuestion,
                                icon:
                                    const Icon(
                                  Icons
                                      .arrow_back_rounded,
                                ),
                                label:
                                    const Text(
                                  'Previous',
                                ),
                              ),
                            ),

                          if (_currentQuestionIndex >
                              0)
                            SizedBox(
                              width:
                                  Responsive.spacing(
                                context,
                                base:
                                    12,
                                min:
                                    8,
                                max:
                                    16,
                              ),
                            ),

                          Expanded(
                            child:
                                FilledButton.icon(
                              onPressed:
                                  _currentQuestionIndex <
                                          questions.length -
                                              1
                                      ? () =>
                                          _nextQuestion(
                                            questions,
                                          )
                                      : () =>
                                          Navigator.of(
                                            context,
                                          ).pop(),
                              icon:
                                  Icon(
                                _currentQuestionIndex <
                                        questions.length -
                                            1
                                    ? Icons
                                        .arrow_forward_rounded
                                    : Icons
                                        .check_rounded,
                              ),
                              label:
                                  Text(
                                _currentQuestionIndex <
                                        questions.length -
                                            1
                                    ? 'Next'
                                    : 'Done',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
// NOT ANSWERED
// ============================================================================

class _NotAnsweredCard
    extends StatelessWidget {
  const _NotAnsweredCard();

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Container(
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
        borderRadius:
            BorderRadius.circular(
          Responsive.smallRadius(
            context,
          ),
        ),
        color:
            theme
                .colorScheme
                .surfaceContainerHighest,
      ),
      child:
          Row(
        children: [
          Icon(
            Icons
                .help_outline_rounded,
            size:
                Responsive.iconSize(
              context,
              base:
                  21,
              min:
                  19,
              max:
                  27,
            ),
            color:
                theme
                    .colorScheme
                    .onSurface
                    .withValues(
              alpha:
                  0.60,
            ),
          ),
          SizedBox(
            width:
                Responsive.spacing(
              context,
              base:
                  10,
              min:
                  7,
              max:
                  14,
            ),
          ),
          const Text(
            'Not answered',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// REVIEW OPTION
// ============================================================================

class _ReviewOptionCard
    extends StatelessWidget {
  final _ReviewOption option;
  final bool isSelected;
  final bool isCorrect;

  const _ReviewOptionCard({
    required this.option,
    required this.isSelected,
    required this.isCorrect,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    // -------------------------------------------------------------------------
    // STUDENT ANSWER CORRECT
    // -------------------------------------------------------------------------

    if (isSelected &&
        isCorrect) {
      return _HighlightedOptionCard(
        backgroundColor:
            Colors.green
                .withValues(
          alpha:
              0.09,
        ),
        borderColor:
            Colors.green,
        icon:
            Icons
                .check_circle_rounded,
        iconColor:
            Colors.green,
        optionText:
            option.text,
        labels:
            const [
          'Your answer',
          'Correct answer',
        ],
        labelColor:
            Colors.green,
      );
    }

    // -------------------------------------------------------------------------
    // STUDENT ANSWER WRONG
    // -------------------------------------------------------------------------

    if (isSelected &&
        !isCorrect) {
      final errorColor =
          theme
              .colorScheme
              .error;

      return _HighlightedOptionCard(
        backgroundColor:
            errorColor
                .withValues(
          alpha:
              0.08,
        ),
        borderColor:
            errorColor,
        icon:
            Icons.cancel_rounded,
        iconColor:
            errorColor,
        optionText:
            option.text,
        labels:
            const [
          'Your answer',
        ],
        labelColor:
            errorColor,
      );
    }

    // -------------------------------------------------------------------------
    // CORRECT ANSWER
    // -------------------------------------------------------------------------

    if (!isSelected &&
        isCorrect) {
      return _HighlightedOptionCard(
        backgroundColor:
            Colors.green
                .withValues(
          alpha:
              0.09,
        ),
        borderColor:
            Colors.green,
        icon:
            Icons
                .check_circle_rounded,
        iconColor:
            Colors.green,
        optionText:
            option.text,
        labels:
            const [
          'Correct answer',
        ],
        labelColor:
            Colors.green,
      );
    }

    // -------------------------------------------------------------------------
    // NORMAL
    // -------------------------------------------------------------------------

    return Container(
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
        borderRadius:
            BorderRadius.circular(
          Responsive.smallRadius(
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
                0.30,
          ),
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Icon(
            Icons
                .radio_button_unchecked,
            size:
                Responsive.iconSize(
              context,
              base:
                  22,
              min:
                  19,
              max:
                  28,
            ),
            color:
                theme
                    .colorScheme
                    .onSurface
                    .withValues(
              alpha:
                  0.35,
            ),
          ),
          SizedBox(
            width:
                Responsive.spacing(
              context,
              base:
                  12,
              min:
                  8,
              max:
                  16,
            ),
          ),
          Expanded(
            child:
                Text(
              option.text,
              style:
                  TextStyle(
                fontSize:
                    Responsive.bodyTextSize(
                  context,
                  base:
                      16,
                  min:
                      14,
                  max:
                      20,
                ),
                height:
                    1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HIGHLIGHTED OPTION
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
  Widget build(
    BuildContext context,
  ) {
    return Container(
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
        borderRadius:
            BorderRadius.circular(
          Responsive.smallRadius(
            context,
          ),
        ),
        color:
            backgroundColor,
        border:
            Border.all(
          color:
              borderColor,
          width:
              2,
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Icon(
            icon,
            size:
                Responsive.iconSize(
              context,
              base:
                  22,
              min:
                  19,
              max:
                  28,
            ),
            color:
                iconColor,
          ),

          SizedBox(
            width:
                Responsive.spacing(
              context,
              base:
                  12,
              min:
                  8,
              max:
                  16,
            ),
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  optionText,
                  style:
                      TextStyle(
                    fontSize:
                        Responsive.bodyTextSize(
                      context,
                      base:
                          16,
                      min:
                          14,
                      max:
                          20,
                    ),
                    height:
                        1.35,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                SizedBox(
                  height:
                      Responsive.spacing(
                    context,
                    base:
                        8,
                    min:
                        5,
                    max:
                        12,
                  ),
                ),

                Wrap(
                  spacing:
                      Responsive.spacing(
                    context,
                    base:
                        8,
                    min:
                        5,
                    max:
                        12,
                  ),
                  runSpacing:
                      5,
                  children:
                      labels.map(
                    (
                      label,
                    ) {
                      return Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal:
                              8,
                          vertical:
                              4,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              labelColor.withValues(
                            alpha:
                                0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),
                        child:
                            Text(
                          label,
                          style:
                              TextStyle(
                            fontSize:
                                Responsive.smallTextSize(
                              context,
                              base:
                                  10,
                              min:
                                  9,
                              max:
                                  13,
                            ),
                            fontWeight:
                                FontWeight.w700,
                            color:
                                labelColor,
                          ),
                        ),
                      );
                    },
                  ).toList(),
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
// EXPLANATION
// ============================================================================

class _ExplanationCard
    extends StatelessWidget {
  final String explanation;

  const _ExplanationCard({
    required this.explanation,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Container(
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
        borderRadius:
            BorderRadius.circular(
          Responsive.smallRadius(
            context,
          ),
        ),
        color:
            theme
                .colorScheme
                .primary
                .withValues(
          alpha:
              0.07,
        ),
        border:
            Border.all(
          color:
              theme
                  .colorScheme
                  .primary
                  .withValues(
            alpha:
                0.15,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .lightbulb_outline_rounded,
                size:
                    Responsive.iconSize(
                  context,
                  base:
                      21,
                  min:
                      19,
                  max:
                      27,
                ),
                color:
                    theme
                        .colorScheme
                        .primary,
              ),

              SizedBox(
                width:
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
                'Explanation',
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
                        18,
                  ),
                  fontWeight:
                      FontWeight.w800,
                  color:
                      theme
                          .colorScheme
                          .primary,
                ),
              ),
            ],
          ),

          SizedBox(
            height:
                Responsive.spacing(
              context,
              base:
                  10,
              min:
                  7,
              max:
                  14,
            ),
          ),

          Text(
            explanation,
            style:
                TextStyle(
              fontSize:
                  Responsive.bodyTextSize(
                context,
                base:
                    14,
                min:
                    12,
                max:
                    18,
              ),
              height:
                  1.5,
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

class _ReviewEmptyView
    extends StatelessWidget {
  const _ReviewEmptyView();

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

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
                        .fact_check_outlined,
                    size:
                        Responsive.clamped(
                      context,
                      base:
                          64,
                      min:
                          52,
                      max:
                          84,
                    ),
                    color:
                        theme
                            .colorScheme
                            .onSurface
                            .withValues(
                      alpha:
                          0.25,
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
                    'No Review Available',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          Responsive.titleSize(
                        context,
                        base:
                            21,
                        min:
                            18,
                        max:
                            28,
                      ),
                      fontWeight:
                          FontWeight.w800,
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
                    'There are no saved answers available for this attempt.',
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
// ERROR
// ============================================================================

class _ReviewErrorView
    extends StatelessWidget {
  final Future<void>
      Function()
      onRetry;

  const _ReviewErrorView({
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

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
                    Responsive.clamped(
                  context,
                  base:
                      60,
                  min:
                      50,
                  max:
                      76,
                ),
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
                'Unable to load exam review',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize:
                      Responsive.titleSize(
                    context,
                    base:
                        20,
                    min:
                        17,
                    max:
                        26,
                  ),
                  fontWeight:
                      FontWeight.w800,
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
                'Please check your connection and try again.',
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
                    Responsive.buttonHeight(
                  context,
                ),
                child:
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODELS
// ============================================================================

class _ReviewQuestion {
  final String id;
  final String questionText;
  final String? explanation;

  final String? selectedOptionId;
  final String? correctOptionId;

  final List<_ReviewOption>
      options;

  const _ReviewQuestion({
    required this.id,
    required this.questionText,
    required this.explanation,
    required this.selectedOptionId,
    required this.correctOptionId,
    required this.options,
  });
}

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