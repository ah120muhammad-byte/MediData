import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';
import 'exam_review_screen.dart';
import 'exam_screen.dart';

class ExamResultScreen extends StatelessWidget {
  final String examId;
  final String attemptId;
  final String examTitle;

  final int durationMinutes;
  final int score;
  final int correctAnswers;
  final int totalQuestions;
  final int passingScore;

  final bool passed;
  final bool autoSubmitted;

  const ExamResultScreen({
    super.key,
    required this.examId,
    required this.attemptId,
    required this.examTitle,
    required this.durationMinutes,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.passingScore,
    required this.passed,
    required this.autoSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final incorrectAnswers =
        (totalQuestions -
                correctAnswers)
            .clamp(
      0,
      totalQuestions,
    );

    final maxContentWidth =
        Responsive.width(
              context,
            ) >=
            900
        ? 760.0
        : 680.0;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Exam Result',
        ),
        automaticallyImplyLeading:
            false,
      ),
      body:
          SafeArea(
        child:
            SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),
          padding:
              EdgeInsets.fromLTRB(
            Responsive.horizontalPadding(
              context,
            ),
            Responsive.spacing(
              context,
              base:
                  24,
              min:
                  16,
              max:
                  36,
            ),
            Responsive.horizontalPadding(
              context,
            ),
            Responsive.scrollBottomPadding(
              context,
              base:
                  30,
            ),
          ),
          child:
              Center(
            child:
                ConstrainedBox(
              constraints:
                  BoxConstraints(
                maxWidth:
                    maxContentWidth,
              ),
              child:
                  Column(
                children: [
                  // ===========================================================
                  // RESULT ICON
                  // ===========================================================

                  _ResultStatusIcon(
                    passed:
                        passed,
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          22,
                      min:
                          16,
                      max:
                          30,
                    ),
                  ),

                  // ===========================================================
                  // TITLE
                  // ===========================================================

                  Text(
                    passed
                        ? 'Congratulations!'
                        : 'Exam Failed',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          Responsive.titleSize(
                        context,
                        base:
                            28,
                        min:
                            23,
                        max:
                            36,
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
                    examTitle,
                    textAlign:
                        TextAlign.center,
                    maxLines:
                        3,
                    overflow:
                        TextOverflow.ellipsis,
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
                      color:
                          theme
                              .colorScheme
                              .onSurface
                              .withValues(
                        alpha:
                            0.65,
                      ),
                    ),
                  ),

                  // ===========================================================
                  // AUTO SUBMIT
                  // ===========================================================

                  if (autoSubmitted) ...[
                    SizedBox(
                      height:
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
                    _AutoSubmitMessage(),
                  ],

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          28,
                      min:
                          20,
                      max:
                          38,
                    ),
                  ),

                  // ===========================================================
                  // SCORE CARD
                  // ===========================================================

                  _ScoreCard(
                    score:
                        score,
                    correctAnswers:
                        correctAnswers,
                    incorrectAnswers:
                        incorrectAnswers,
                    totalQuestions:
                        totalQuestions,
                    passingScore:
                        passingScore,
                    passed:
                        passed,
                  ),

                  SizedBox(
                    height:
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

                  // ===========================================================
                  // REVIEW
                  // ===========================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height:
                        Responsive.buttonHeight(
                      context,
                    ),
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          () {
                        Navigator.of(
                          context,
                        ).push(
                          MaterialPageRoute(
                            builder:
                                (_) =>
                                    ExamReviewScreen(
                              attemptId:
                                  attemptId,
                              examId:
                                  examId,
                              examTitle:
                                  examTitle,
                            ),
                          ),
                        );
                      },
                      icon:
                          const Icon(
                        Icons
                            .fact_check_outlined,
                      ),
                      label:
                          const Text(
                        'Review Answers',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          12,
                      min:
                          8,
                      max:
                          18,
                    ),
                  ),

                  // ===========================================================
                  // RETAKE
                  // ===========================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height:
                        Responsive.buttonHeight(
                      context,
                    ),
                    child:
                        FilledButton.icon(
                      onPressed:
                          () {
                        Navigator.of(
                          context,
                        ).pushReplacement(
                          MaterialPageRoute(
                            builder:
                                (_) =>
                                    ExamScreen(
                              examId:
                                  examId,
                              examTitle:
                                  examTitle,
                              durationMinutes:
                                  durationMinutes,
                              passingScore:
                                  passingScore,
                            ),
                          ),
                        );
                      },
                      icon:
                          const Icon(
                        Icons
                            .refresh_rounded,
                      ),
                      label:
                          const Text(
                        'Retake Exam',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          12,
                      min:
                          8,
                      max:
                          18,
                    ),
                  ),

                  // ===========================================================
                  // BACK
                  // ===========================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height:
                        Responsive.buttonHeight(
                      context,
                    ),
                    child:
                        TextButton(
                      onPressed:
                          () {
                        Navigator.of(
                          context,
                        ).popUntil(
                          (
                            route,
                          ) =>
                              route.isFirst,
                        );
                      },
                      child:
                          const Text(
                        'Back to Lectures',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// RESULT STATUS ICON
// ============================================================================

class _ResultStatusIcon
    extends StatelessWidget {
  final bool passed;

  const _ResultStatusIcon({
    required this.passed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final size =
        Responsive.clamped(
      context,
      base:
          110,
      min:
          88,
      max:
          140,
    );

    final iconSize =
        size *
            0.69;

    final backgroundColor =
        passed
            ? Colors.green.withValues(
                alpha:
                    0.12,
              )
            : theme
                .colorScheme
                .error
                .withValues(
              alpha:
                  0.12,
            );

    final foregroundColor =
        passed
            ? Colors.green
            : theme
                .colorScheme
                .error;

    return Container(
      width:
          size,
      height:
          size,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        color:
            backgroundColor,
      ),
      child:
          Icon(
        passed
            ? Icons
                .check_circle_rounded
            : Icons
                .cancel_rounded,
        size:
            iconSize,
        color:
            foregroundColor,
      ),
    );
  }
}

// ============================================================================
// AUTO SUBMIT MESSAGE
// ============================================================================

class _AutoSubmitMessage
    extends StatelessWidget {
  const _AutoSubmitMessage();

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
                .error
                .withValues(
          alpha:
              0.08,
        ),
        border:
            Border.all(
          color:
              theme
                  .colorScheme
                  .error
                  .withValues(
            alpha:
                0.20,
          ),
        ),
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .timer_off_rounded,
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
                    .error,
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
          Expanded(
            child:
                Text(
              'The exam was submitted automatically because the time ended.',
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
                        .error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SCORE CARD
// ============================================================================

class _ScoreCard
    extends StatelessWidget {
  final int score;
  final int correctAnswers;
  final int incorrectAnswers;
  final int totalQuestions;
  final int passingScore;
  final bool passed;

  const _ScoreCard({
    required this.score,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.totalQuestions,
    required this.passingScore,
    required this.passed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final radius =
        Responsive.cardRadius(
      context,
    );

    final padding =
        Responsive.cardPadding(
      context,
    );

    final scoreSize =
        Responsive.clamped(
      context,
      base:
          54,
      min:
          44,
      max:
          72,
    );

    final scoreColor =
        passed
            ? Colors.green
            : theme
                .colorScheme
                .error;

    return Container(
      width:
          double.infinity,
      padding:
          EdgeInsets.all(
        padding,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          radius,
        ),
        color:
            theme
                .colorScheme
                .surfaceContainerHighest,
      ),
      child:
          Column(
        children: [
          Text(
            '$score%',
            style:
                TextStyle(
              fontSize:
                  scoreSize,
              fontWeight:
                  FontWeight.w900,
              color:
                  scoreColor,
            ),
          ),

          SizedBox(
            height:
                Responsive.spacing(
              context,
              base:
                  5,
              min:
                  3,
              max:
                  8,
            ),
          ),

          Text(
            'Your Score',
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

          SizedBox(
            height:
                Responsive.spacing(
              context,
              base:
                  24,
              min:
                  18,
              max:
                  30,
            ),
          ),

          LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final compact =
                  constraints.maxWidth <
                      420;

              if (compact) {
                return Wrap(
                  alignment:
                      WrapAlignment.center,
                  spacing:
                      Responsive.spacing(
                    context,
                    base:
                        28,
                    min:
                        18,
                    max:
                        38,
                  ),
                  runSpacing:
                      Responsive.spacing(
                    context,
                    base:
                        18,
                    min:
                        12,
                    max:
                        24,
                  ),
                  children: [
                    _ResultItem(
                      icon:
                          Icons
                              .check_circle_outline_rounded,
                      label:
                          'Correct',
                      value:
                          '$correctAnswers',
                    ),
                    _ResultItem(
                      icon:
                          Icons
                              .cancel_outlined,
                      label:
                          'Incorrect',
                      value:
                          '$incorrectAnswers',
                    ),
                    _ResultItem(
                      icon:
                          Icons
                              .quiz_outlined,
                      label:
                          'Questions',
                      value:
                          '$totalQuestions',
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child:
                        _ResultItem(
                      icon:
                          Icons
                              .check_circle_outline_rounded,
                      label:
                          'Correct',
                      value:
                          '$correctAnswers',
                    ),
                  ),
                  Expanded(
                    child:
                        _ResultItem(
                      icon:
                          Icons
                              .cancel_outlined,
                      label:
                          'Incorrect',
                      value:
                          '$incorrectAnswers',
                    ),
                  ),
                  Expanded(
                    child:
                        _ResultItem(
                      icon:
                          Icons
                              .quiz_outlined,
                      label:
                          'Questions',
                      value:
                          '$totalQuestions',
                    ),
                  ),
                ],
              );
            },
          ),

          SizedBox(
            height:
                Responsive.spacing(
              context,
              base:
                  22,
              min:
                  16,
              max:
                  28,
            ),
          ),

          Divider(
            color:
                theme
                    .colorScheme
                    .outline
                    .withValues(
              alpha:
                  0.20,
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

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                Icons
                    .flag_outlined,
                size:
                    Responsive.iconSize(
                  context,
                  base:
                      19,
                  min:
                      17,
                  max:
                      24,
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
                      7,
                  min:
                      5,
                  max:
                      10,
                ),
              ),
              Flexible(
                child:
                    Text(
                  'Passing score: $passingScore%',
                  textAlign:
                      TextAlign.center,
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
                    fontWeight:
                        FontWeight.w600,
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

// ============================================================================
// RESULT ITEM
// ============================================================================

class _ResultItem
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResultItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size:
              Responsive.iconSize(
            context,
            base:
                22,
            min:
                20,
            max:
                28,
          ),
          color:
              theme
                  .colorScheme
                  .primary,
        ),

        SizedBox(
          height:
              Responsive.spacing(
            context,
            base:
                7,
            min:
                5,
            max:
                10,
          ),
        ),

        Text(
          value,
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
                4,
            min:
                3,
            max:
                6,
          ),
        ),

        Text(
          label,
          textAlign:
              TextAlign.center,
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
                  0.60,
            ),
          ),
        ),
      ],
    );
  }
}