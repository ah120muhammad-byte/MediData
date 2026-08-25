import 'package:supabase_flutter/supabase_flutter.dart';

class ExamHistoryItem {
  final String attemptId;
  final String examId;
  final String examTitle;

  final int score;
  final int totalQuestions;
  final int correctAnswers;

  final DateTime? startedAt;
  final DateTime? completedAt;

  final String status;

  final int remainingSeconds;
  final bool isPaused;
  final int currentQuestionIndex;

  const ExamHistoryItem({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.startedAt,
    required this.completedAt,
    required this.status,
    required this.remainingSeconds,
    required this.isPaused,
    required this.currentQuestionIndex,
  });

  bool get isInProgress =>
      status == 'in_progress';

  bool get isCompleted =>
      status == 'completed';

  bool get isAbandoned =>
      status == 'abandoned';

  factory ExamHistoryItem.fromMap(
    Map<String, dynamic> map,
  ) {
    final examRaw =
        map['exams'];

    final exam =
        examRaw is Map
            ? Map<String, dynamic>.from(
                examRaw,
              )
            : <String, dynamic>{};

    return ExamHistoryItem(
      attemptId:
          map['id']?.toString() ?? '',
      examId:
          map['exam_id']?.toString() ?? '',
      examTitle:
          exam['title']?.toString() ??
              'Exam',
      score:
          (map['score'] as num?)
                  ?.toInt() ??
              0,
      totalQuestions:
          (map['total_questions']
                      as num?)
                  ?.toInt() ??
              0,
      correctAnswers:
          (map['correct_answers']
                      as num?)
                  ?.toInt() ??
              0,
      startedAt:
          DateTime.tryParse(
        map['started_at']
                ?.toString() ??
            '',
      ),
      completedAt:
          DateTime.tryParse(
        map['completed_at']
                ?.toString() ??
            '',
      ),
      status:
          map['status']?.toString() ??
              'abandoned',
      remainingSeconds:
          (map['remaining_seconds']
                      as num?)
                  ?.toInt() ??
              0,
      isPaused:
          map['is_paused'] as bool? ??
              false,
      currentQuestionIndex:
          (map['current_question_index']
                      as num?)
                  ?.toInt() ??
              0,
    );
  }
}

class ExamHistoryService {
  ExamHistoryService._();

  static final ExamHistoryService
      instance =
      ExamHistoryService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ===========================================================================
  // ALL ATTEMPTS
  // ===========================================================================

  Future<List<ExamHistoryItem>>
      getAttempts() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final response =
        await _supabase
            .from('exam_attempts')
            .select('''
              id,
              user_id,
              exam_id,
              score,
              total_questions,
              correct_answers,
              started_at,
              completed_at,
              status,
              created_at,
              remaining_seconds,
              is_paused,
              active_started_at,
              current_question_index,
              exams (
                id,
                title,
                passing_score
              )
            ''')
            .eq(
              'user_id',
              user.id,
            )
            .order(
              'created_at',
              ascending: false,
            );

    return (response as List)
        .map(
          (item) =>
              ExamHistoryItem.fromMap(
            Map<String, dynamic>.from(
              item,
            ),
          ),
        )
        .toList();
  }

  // ===========================================================================
  // ACTIVE ATTEMPT
  // ===========================================================================

  Future<ExamHistoryItem?>
      getActiveAttempt(
    String examId,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response =
        await _supabase
            .from('exam_attempts')
            .select('''
              id,
              user_id,
              exam_id,
              score,
              total_questions,
              correct_answers,
              started_at,
              completed_at,
              status,
              created_at,
              remaining_seconds,
              is_paused,
              active_started_at,
              current_question_index,
              exams (
                id,
                title,
                passing_score
              )
            ''')
            .eq(
              'user_id',
              user.id,
            )
            .eq(
              'exam_id',
              examId,
            )
            .eq(
              'status',
              'in_progress',
            )
            .order(
              'created_at',
              ascending: false,
            )
            .limit(1)
            .maybeSingle();

    if (response == null) {
      return null;
    }

    return ExamHistoryItem.fromMap(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }

  // ===========================================================================
  // ONE ATTEMPT
  // ===========================================================================

  Future<ExamHistoryItem?>
      getAttempt(
    String attemptId,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response =
        await _supabase
            .from('exam_attempts')
            .select('''
              id,
              user_id,
              exam_id,
              score,
              total_questions,
              correct_answers,
              started_at,
              completed_at,
              status,
              created_at,
              remaining_seconds,
              is_paused,
              active_started_at,
              current_question_index,
              exams (
                id,
                title,
                passing_score
              )
            ''')
            .eq(
              'id',
              attemptId,
            )
            .eq(
              'user_id',
              user.id,
            )
            .maybeSingle();

    if (response == null) {
      return null;
    }

    return ExamHistoryItem.fromMap(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }
}