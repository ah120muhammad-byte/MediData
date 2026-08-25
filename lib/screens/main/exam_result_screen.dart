import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);

    final incorrectAnswers =
        totalQuestions - correctAnswers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Result'),
        automaticallyImplyLeading: false,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            30,
          ),
          child: Column(
            children: [
              // ===============================================================
              // RESULT ICON
              // ===============================================================

              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: passed
                      ? Colors.green.withValues(alpha: 0.12)
                      : theme.colorScheme.error.withValues(alpha: 0.12),
                ),
                child: Icon(
                  passed
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 76,
                  color: passed
                      ? Colors.green
                      : theme.colorScheme.error,
                ),
              ),

              const SizedBox(height: 22),

              // ===============================================================
              // TITLE
              // ===============================================================

              Text(
                passed
                    ? 'Congratulations!'
                    : 'Exam Failed',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                examTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.65),
                ),
              ),

              // ===============================================================
              // AUTO SUBMIT MESSAGE
              // ===============================================================

              if (autoSubmitted) ...[
                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: theme.colorScheme.error
                        .withValues(alpha: 0.08),
                    border: Border.all(
                      color: theme.colorScheme.error
                          .withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.timer_off_rounded,
                        size: 21,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The exam was submitted automatically because the time ended.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // ===============================================================
              // SCORE CARD
              // ===============================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: theme
                      .colorScheme
                      .surfaceContainerHighest,
                ),
                child: Column(
                  children: [
                    Text(
                      '$score%',
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.w900,
                        color: passed
                            ? Colors.green
                            : theme.colorScheme.error,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Your Score',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.60),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: _ResultItem(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'Correct',
                            value: '$correctAnswers',
                          ),
                        ),

                        Expanded(
                          child: _ResultItem(
                            icon: Icons.cancel_outlined,
                            label: 'Incorrect',
                            value: '$incorrectAnswers',
                          ),
                        ),

                        Expanded(
                          child: _ResultItem(
                            icon: Icons.quiz_outlined,
                            label: 'Questions',
                            value: '$totalQuestions',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    Divider(
                      color: theme.colorScheme.outline
                          .withValues(alpha: 0.20),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 19,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Passing score: $passingScore%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ===============================================================
              // REVIEW ANSWERS
              // ===============================================================

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExamReviewScreen(
                          attemptId: attemptId,
                          examId: examId,
                          examTitle: examTitle,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.fact_check_outlined,
                  ),
                  label: const Text(
                    'Review Answers',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ===============================================================
              // RETAKE
              // ===============================================================

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ExamScreen(
                          examId: examId,
                          examTitle: examTitle,
                          durationMinutes: durationMinutes,
                          passingScore: passingScore,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label: const Text(
                    'Retake Exam',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ===============================================================
              // BACK TO LECTURES
              // ===============================================================

              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).popUntil(
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text(
                    'Back to Lectures',
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
// RESULT ITEM
// ============================================================================

class _ResultItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResultItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: theme.colorScheme.primary,
        ),

        const SizedBox(height: 7),

        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface
                .withValues(alpha: 0.60),
          ),
        ),
      ],
    );
  }
}