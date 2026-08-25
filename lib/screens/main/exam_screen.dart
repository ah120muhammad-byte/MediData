import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/exam_models.dart';
import 'exam_result_screen.dart';

class ExamScreen extends StatefulWidget {
  final String examId;
  final String examTitle;
  final int durationMinutes;
  final int passingScore;

  /// If provided, resume this exact attempt.
  ///
  /// If null, the screen first looks for the latest
  /// in-progress attempt for this exam.
  final String? attemptId;

  const ExamScreen({
    super.key,
    required this.examId,
    required this.examTitle,
    required this.durationMinutes,
    required this.passingScore,
    this.attemptId,
  });

  @override
  State<ExamScreen> createState() =>
      _ExamScreenState();
}

class _ExamScreenState
    extends State<ExamScreen>
    with WidgetsBindingObserver {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ===========================================================================
  // QUESTIONS
  // ===========================================================================

  late Future<List<ExamQuestion>>
      _questionsFuture;

  // ===========================================================================
  // ANSWERS
  // ===========================================================================

  final Map<String, String>
      _selectedAnswers = {};

  // ===========================================================================
  // ATTEMPT
  // ===========================================================================

  String? _attemptId;

  // ===========================================================================
  // TIMER
  // ===========================================================================

  Timer? _timer;

  Timer? _saveStateTimer;

  int _remainingSeconds = 0;

  // ===========================================================================
  // POSITION
  // ===========================================================================

  int _currentQuestionIndex = 0;

  // ===========================================================================
  // STATE
  // ===========================================================================

  bool _isLoadingAttempt = true;

  bool _isSubmitting = false;

  bool _isSavingState = false;

  bool _isInitialized = false;

  bool _ignoreBackOnce = false;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addObserver(this);

    _remainingSeconds =
        widget.durationMinutes * 60;

    _questionsFuture =
        _loadExamAndPrepareAttempt();
  }

  // ===========================================================================
  // APP LIFECYCLE
  // ===========================================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (_attemptId == null ||
        _isSubmitting) {
      return;
    }

    switch (state) {
      case AppLifecycleState
          .inactive:
      case AppLifecycleState
          .paused:
      case AppLifecycleState
          .hidden:
      case AppLifecycleState
          .detached:
        unawaited(
          _saveAttemptState(
            isPaused: false,
          ),
        );
        break;

      case AppLifecycleState
          .resumed:
        unawaited(
          _syncTimeFromServer(),
        );
        break;
    }
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(this);

    _timer?.cancel();

    _saveStateTimer?.cancel();

    if (_attemptId != null &&
        !_isSubmitting) {
      unawaited(
        _saveAttemptState(
          isPaused: false,
        ),
      );
    }

    super.dispose();
  }

  // ===========================================================================
  // LOAD QUESTIONS + ATTEMPT
  // ===========================================================================

  Future<List<ExamQuestion>>
      _loadExamAndPrepareAttempt() async {
    final questions =
        await _loadExam();

    if (questions.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingAttempt = false;
        });
      }

      return questions;
    }

    await _prepareAttempt(
      questions,
    );

    return questions;
  }

  // ===========================================================================
  // LOAD QUESTIONS
  // ===========================================================================

  Future<List<ExamQuestion>> _loadExam() async {
    final questionsResponse =
        await _supabase
            .from('questions')
            .select('''
              id,
              exam_id,
              question_text,
              explanation,
              display_order
            ''')
            .eq(
              'exam_id',
              widget.examId,
            )
            .order(
              'display_order',
              ascending: true,
            );

    final questions =
        (questionsResponse as List)
            .map(
              (item) {
                final map =
                    Map<String, dynamic>.from(
                  item,
                );

                return ExamQuestion(
                  id: map['id']
                      .toString(),
                  examId:
                      map['exam_id']
                          .toString(),
                  questionText:
                      map['question_text']
                              ?.toString() ??
                          '',
                  explanation:
                      map['explanation']
                          ?.toString(),
                  displayOrder:
                      (map['display_order']
                                  as num?)
                              ?.toInt() ??
                          0,
                  options:
                      const [],
                );
              },
            )
            .toList();

    if (questions.isEmpty) {
      return [];
    }

    final questionIds =
        questions
            .map(
              (question) =>
                  question.id,
            )
            .toList();

    final optionsResponse =
        await _supabase
            .from('question_options')
            .select('''
              id,
              question_id,
              option_text,
              display_order
            ''')
            .inFilter(
              'question_id',
              questionIds,
            )
            .order(
              'display_order',
              ascending: true,
            );

    final options =
        (optionsResponse as List)
            .map(
              (item) {
                final map =
                    Map<String, dynamic>.from(
                  item,
                );

                return ExamOption(
                  id: map['id']
                      .toString(),
                  questionId:
                      map['question_id']
                          .toString(),
                  optionText:
                      map['option_text']
                              ?.toString() ??
                          '',
                  displayOrder:
                      (map['display_order']
                                  as num?)
                              ?.toInt() ??
                          0,
                );
              },
            )
            .toList();

    final Map<
        String,
        List<ExamOption>>
        optionsByQuestion = {};

    for (final option in options) {
      optionsByQuestion
          .putIfAbsent(
            option.questionId,
            () => [],
          )
          .add(option);
    }

    return questions.map(
      (question) {
        return question.copyWith(
          options:
              optionsByQuestion[
                      question.id] ??
                  [],
        );
      },
    ).toList();
  }

  // ===========================================================================
  // PREPARE ATTEMPT
  // ===========================================================================

  Future<void> _prepareAttempt(
    List<ExamQuestion> questions,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingAttempt = false;
        });
      }

      return;
    }

    // -------------------------------------------------------------------------
    // EXPLICIT ATTEMPT ID
    // -------------------------------------------------------------------------

    if (widget.attemptId != null &&
        widget.attemptId!
            .trim()
            .isNotEmpty) {
      final restored =
          await _restoreSpecificAttempt(
        widget.attemptId!,
        questions,
      );

      if (restored) {
        return;
      }
    }

    // -------------------------------------------------------------------------
    // FIND LATEST ACTIVE ATTEMPT
    // -------------------------------------------------------------------------

    final existing =
        await _supabase
            .from('exam_attempts')
            .select('''
              id,
              exam_id,
              remaining_seconds,
              is_paused,
              active_started_at,
              current_question_index,
              status
            ''')
            .eq(
              'user_id',
              user.id,
            )
            .eq(
              'exam_id',
              widget.examId,
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

    if (existing != null) {
      final restored =
          await _restoreAttemptRow(
        Map<String, dynamic>.from(
          existing,
        ),
        questions,
      );

      if (restored) {
        return;
      }
    }

    // -------------------------------------------------------------------------
    // CREATE NEW ATTEMPT
    // -------------------------------------------------------------------------

    await _createNewAttempt();
  }

  // ===========================================================================
  // RESTORE SPECIFIC ATTEMPT
  // ===========================================================================

  Future<bool> _restoreSpecificAttempt(
    String attemptId,
    List<ExamQuestion> questions,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return false;
    }

    final response =
        await _supabase
            .from('exam_attempts')
            .select('''
              id,
              exam_id,
              remaining_seconds,
              is_paused,
              active_started_at,
              current_question_index,
              status
            ''')
            .eq(
              'id',
              attemptId,
            )
            .eq(
              'user_id',
              user.id,
            )
            .eq(
              'exam_id',
              widget.examId,
            )
            .maybeSingle();

    if (response == null) {
      return false;
    }

    return _restoreAttemptRow(
      Map<String, dynamic>.from(
        response,
      ),
      questions,
    );
  }

  // ===========================================================================
  // RESTORE ATTEMPT ROW
  // ===========================================================================

  Future<bool> _restoreAttemptRow(
    Map<String, dynamic> row,
    List<ExamQuestion> questions,
  ) async {
    if (row['status']?.toString() !=
        'in_progress') {
      return false;
    }

    final id =
        row['id']?.toString();

    if (id == null ||
        id.isEmpty) {
      return false;
    }

    _attemptId = id;

    // -------------------------------------------------------------------------
    // QUESTION INDEX
    // -------------------------------------------------------------------------

    final savedIndex =
        (row['current_question_index']
                    as num?)
                ?.toInt() ??
            0;

    _currentQuestionIndex =
        savedIndex.clamp(
      0,
      questions.length - 1,
    );

    // -------------------------------------------------------------------------
    // STORED TIME
    // -------------------------------------------------------------------------

    final storedSeconds =
        (row['remaining_seconds']
                    as num?)
                ?.toInt() ??
            widget.durationMinutes * 60;

    _remainingSeconds =
        storedSeconds.clamp(
      0,
      widget.durationMinutes * 60,
    );

    // -------------------------------------------------------------------------
    // CALCULATE REAL ELAPSED TIME
    // -------------------------------------------------------------------------

    final isPaused =
        row['is_paused']
                as bool? ??
            false;

    final activeStartedAt =
        DateTime.tryParse(
      row['active_started_at']
              ?.toString() ??
          '',
    );

    if (!isPaused &&
        activeStartedAt != null) {
      final elapsed =
          DateTime.now()
              .toUtc()
              .difference(
                activeStartedAt,
              )
              .inSeconds;

      if (elapsed > 0) {
        _remainingSeconds =
            (_remainingSeconds -
                    elapsed)
                .clamp(
          0,
          widget.durationMinutes * 60,
        );
      }
    }

    // -------------------------------------------------------------------------
    // LOAD ANSWERS
    // -------------------------------------------------------------------------

    await _loadSavedAnswers();

    _isInitialized = true;

    if (!mounted) {
      return true;
    }

    setState(() {
      _isLoadingAttempt = false;
    });

    _startTimer();
    _startStateSaver();

    if (_remainingSeconds <=
        0) {
      unawaited(
        _submitExam(
          autoSubmit: true,
        ),
      );
    }

    return true;
  }

  // ===========================================================================
  // CREATE NEW ATTEMPT
  // ===========================================================================

  Future<void> _createNewAttempt() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingAttempt = false;
        });
      }

      return;
    }

    final now =
        DateTime.now()
            .toUtc()
            .toIso8601String();

    final totalSeconds =
        widget.durationMinutes * 60;

    final response =
        await _supabase
            .from('exam_attempts')
            .insert({
              'user_id':
                  user.id,
              'exam_id':
                  widget.examId,
              'score':
                  0,
              'total_questions':
                  0,
              'correct_answers':
                  0,
              'started_at':
                  now,
              'completed_at':
                  null,
              'status':
                  'in_progress',
              'remaining_seconds':
                  totalSeconds,
              'is_paused':
                  false,
              'active_started_at':
                  now,
              'current_question_index':
                  0,
            })
            .select('id')
            .single();

    _attemptId =
        response['id']
            .toString();

    _remainingSeconds =
        totalSeconds;

    _currentQuestionIndex =
        0;

    _isInitialized = true;

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingAttempt = false;
    });

    _startTimer();
    _startStateSaver();
  }

  // ===========================================================================
  // LOAD SAVED ANSWERS
  // ===========================================================================

  Future<void> _loadSavedAnswers() async {
    final attemptId =
        _attemptId;

    if (attemptId == null) {
      return;
    }

    final response =
        await _supabase
            .from('exam_answers')
            .select('''
              question_id,
              selected_option_id
            ''')
            .eq(
              'attempt_id',
              attemptId,
            );

    _selectedAnswers.clear();

    for (final rawItem
        in response as List) {
      final item =
          Map<String, dynamic>.from(
        rawItem,
      );

      final questionId =
          item['question_id']
              ?.toString();

      final optionId =
          item['selected_option_id']
              ?.toString();

      if (questionId == null ||
          questionId.isEmpty ||
          optionId == null ||
          optionId.isEmpty) {
        continue;
      }

      _selectedAnswers[
              questionId] =
          optionId;
    }
  }

  // ===========================================================================
  // TIMER
  // ===========================================================================

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(
        seconds: 1,
      ),
      (_) {
        if (!mounted ||
            _isSubmitting ||
            !_isInitialized) {
          return;
        }

        if (_remainingSeconds <=
            0) {
          _timer?.cancel();

          unawaited(
            _submitExam(
              autoSubmit: true,
            ),
          );

          return;
        }

        setState(() {
          _remainingSeconds--;
        });
      },
    );
  }

  // ===========================================================================
  // PERIODIC SAVE
  // ===========================================================================

  void _startStateSaver() {
    _saveStateTimer?.cancel();

    _saveStateTimer =
        Timer.periodic(
      const Duration(
        seconds: 5,
      ),
      (_) {
        unawaited(
          _saveAttemptState(
            isPaused: false,
          ),
        );
      },
    );
  }

  // ===========================================================================
  // SAVE ATTEMPT STATE
  // ===========================================================================

  Future<void> _saveAttemptState({
    required bool isPaused,
  }) async {
    final attemptId =
        _attemptId;

    if (attemptId == null ||
        _isSavingState ||
        _isSubmitting ||
        !_isInitialized) {
      return;
    }

    _isSavingState = true;

    try {
      final now =
          DateTime.now()
              .toUtc();

      await _supabase
          .from('exam_attempts')
          .update({
            'remaining_seconds':
                _remainingSeconds
                    .clamp(
              0,
              widget.durationMinutes * 60,
            ),
            'current_question_index':
                _currentQuestionIndex,
            'is_paused':
                isPaused,
            'active_started_at':
                now.toIso8601String(),
          })
          .eq(
            'id',
            attemptId,
          );
    } catch (e) {
      debugPrint(
        'Save exam state error: $e',
      );
    } finally {
      _isSavingState = false;
    }
  }

  // ===========================================================================
  // SYNC TIME WHEN APP RETURNS
  // ===========================================================================

  Future<void> _syncTimeFromServer() async {
    final attemptId =
        _attemptId;

    if (attemptId == null ||
        _isSubmitting) {
      return;
    }

    try {
      final response =
          await _supabase
              .from('exam_attempts')
              .select('''
                remaining_seconds,
                is_paused,
                active_started_at,
                status
              ''')
              .eq(
                'id',
                attemptId,
              )
              .maybeSingle();

      if (response == null) {
        return;
      }

      final row =
          Map<String, dynamic>.from(
        response,
      );

      if (row['status']?.toString() !=
          'in_progress') {
        return;
      }

      final storedSeconds =
          (row['remaining_seconds']
                      as num?)
                  ?.toInt() ??
              _remainingSeconds;

      final isPaused =
          row['is_paused']
                  as bool? ??
              false;

      final activeStartedAt =
          DateTime.tryParse(
        row['active_started_at']
                ?.toString() ??
            '',
      );

      var remaining =
          storedSeconds;

      if (!isPaused &&
          activeStartedAt != null) {
        final elapsed =
            DateTime.now()
                .toUtc()
                .difference(
                  activeStartedAt,
                )
                .inSeconds;

        remaining =
            (storedSeconds -
                    elapsed)
                .clamp(
          0,
          widget.durationMinutes * 60,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _remainingSeconds =
            remaining;
      });

      if (_remainingSeconds <=
          0) {
        unawaited(
          _submitExam(
            autoSubmit: true,
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'Sync exam time error: $e',
      );
    }
  }

  // ===========================================================================
  // SELECT ANSWER
  // ===========================================================================

  void _selectAnswer(
    ExamQuestion question,
    ExamOption option,
  ) {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _selectedAnswers[
              question.id] =
          option.id;
    });

    unawaited(
      _saveAnswer(
        question.id,
        option.id,
      ),
    );

    unawaited(
      _saveAttemptState(
        isPaused: false,
      ),
    );
  }

  // ===========================================================================
  // SAVE ANSWER
  // ===========================================================================

  Future<void> _saveAnswer(
    String questionId,
    String optionId,
  ) async {
    final attemptId =
        _attemptId;

    if (attemptId == null) {
      return;
    }

    try {
      final existing =
          await _supabase
              .from('exam_answers')
              .select('id')
              .eq(
                'attempt_id',
                attemptId,
              )
              .eq(
                'question_id',
                questionId,
              )
              .maybeSingle();

      final now =
          DateTime.now()
              .toUtc()
              .toIso8601String();

      if (existing != null) {
        await _supabase
            .from('exam_answers')
            .update({
              'selected_option_id':
                  optionId,
              'answered_at':
                  now,
            })
            .eq(
              'id',
              existing['id'],
            );

        return;
      }

      await _supabase
          .from('exam_answers')
          .insert({
            'attempt_id':
                attemptId,
            'question_id':
                questionId,
            'selected_option_id':
                optionId,
            'answered_at':
                now,
          });
    } catch (e) {
      debugPrint(
        'Save exam answer error: $e',
      );
    }
  }

  // ===========================================================================
  // NEXT QUESTION
  // ===========================================================================

  void _nextQuestion(
    List<ExamQuestion> questions,
  ) {
    if (_currentQuestionIndex >=
        questions.length - 1) {
      unawaited(
        _showSubmitDialog(),
      );

      return;
    }

    setState(() {
      _currentQuestionIndex++;
    });

    unawaited(
      _saveAttemptState(
        isPaused: false,
      ),
    );
  }

  // ===========================================================================
  // PREVIOUS QUESTION
  // ===========================================================================

  void _previousQuestion() {
    if (_currentQuestionIndex <=
        0) {
      return;
    }

    setState(() {
      _currentQuestionIndex--;
    });

    unawaited(
      _saveAttemptState(
        isPaused: false,
      ),
    );
  }

  // ===========================================================================
  // EXIT
  // ===========================================================================

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title:
              const Text(
            'Leave Exam?',
          ),
          content:
              const Text(
            'Your answers and progress will be saved. You can resume this exam later.',
          ),
          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
                  const Text(
                'Stay',
              ),
            ),
            FilledButton(
              onPressed:
                  () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
                  const Text(
                'Leave',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleBack() async {
    if (_ignoreBackOnce ||
        _isSubmitting) {
      return;
    }

    final shouldExit =
        await _showExitDialog();

    if (shouldExit !=
        true) {
      return;
    }

    await _saveAttemptState(
      isPaused: false,
    );

    if (!mounted) {
      return;
    }

    _ignoreBackOnce = true;

    Navigator.of(context).pop();
  }

  // ===========================================================================
  // SUBMIT DIALOG
  // ===========================================================================

  Future<void> _showSubmitDialog() async {
    if (_isSubmitting) {
      return;
    }

    final shouldSubmit =
        await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'Submit Exam?',
          ),
          content:
              const Text(
            'Are you sure you want to submit your answers?',
          ),
          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed:
                  () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child:
                  const Text(
                'Submit',
              ),
            ),
          ],
        );
      },
    );

    if (shouldSubmit !=
        true) {
      return;
    }

    await _submitExam();
  }

  // ===========================================================================
  // SUBMIT
  // ===========================================================================

  Future<void> _submitExam({
    bool autoSubmit = false,
  }) async {
    if (_isSubmitting ||
        _attemptId == null) {
      return;
    }

    _isSubmitting = true;

    _timer?.cancel();

    _saveStateTimer?.cancel();

    if (mounted) {
      setState(() {});
    }

    try {
      final questions =
          await _questionsFuture;

      final questionIds =
          questions
              .map(
                (question) =>
                    question.id,
              )
              .toList();

      if (questionIds.isEmpty) {
        throw Exception(
          'No questions found.',
        );
      }

      // -----------------------------------------------------------------------
      // CORRECT ANSWERS
      // -----------------------------------------------------------------------

      final correctResponse =
          await _supabase
              .from(
                'question_correct_answers',
              )
              .select(
                'question_id, correct_option_id',
              )
              .inFilter(
                'question_id',
                questionIds,
              );

      final Map<
          String,
          String> correctAnswers =
          {};

      for (final rawItem
          in correctResponse as List) {
        final item =
            Map<String, dynamic>.from(
          rawItem,
        );

        final questionId =
            item['question_id']
                ?.toString();

        final correctOptionId =
            item['correct_option_id']
                ?.toString();

        if (questionId == null ||
            correctOptionId == null) {
          continue;
        }

        correctAnswers[
                questionId] =
            correctOptionId;
      }

      // -----------------------------------------------------------------------
      // CALCULATE RESULT
      // -----------------------------------------------------------------------

      int correctCount = 0;

      for (final question
          in questions) {
        final selected =
            _selectedAnswers[
                question.id];

        final correct =
            correctAnswers[
                question.id];

        if (selected != null &&
            correct != null &&
            selected == correct) {
          correctCount++;
        }
      }

      final totalQuestions =
          questions.length;

      final score =
          totalQuestions == 0
              ? 0
              : ((correctCount /
                              totalQuestions) *
                          100)
                      .round();

      final passed =
          score >=
              widget.passingScore;

      // -----------------------------------------------------------------------
      // SAVE CORRECTNESS
      // -----------------------------------------------------------------------

      for (final question
          in questions) {
        final selected =
            _selectedAnswers[
                question.id];

        if (selected == null) {
          continue;
        }

        final correct =
            correctAnswers[
                question.id];

        await _updateAnswerCorrectness(
          questionId:
              question.id,
          selectedOptionId:
              selected,
          isCorrect:
              correct != null &&
                  selected ==
                      correct,
        );
      }

      // -----------------------------------------------------------------------
      // UPDATE ATTEMPT
      // -----------------------------------------------------------------------

      await _supabase
          .from('exam_attempts')
          .update({
        'score':
            score,
        'total_questions':
            totalQuestions,
        'correct_answers':
            correctCount,
        'completed_at':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
        'status':
            'completed',
        'remaining_seconds':
            0,
        'is_paused':
            false,
        'current_question_index':
            _currentQuestionIndex,
      })
          .eq(
        'id',
        _attemptId!,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context)
          .pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ExamResultScreen(
            examId:
                widget.examId,
            attemptId:
                _attemptId!,
            examTitle:
                widget.examTitle,
            durationMinutes:
                widget.durationMinutes,
            score:
                score,
            correctAnswers:
                correctCount,
            totalQuestions:
                totalQuestions,
            passingScore:
                widget.passingScore,
            passed:
                passed,
            autoSubmitted:
                autoSubmit,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Submit exam error: $e',
      );

      _isSubmitting = false;

      if (!mounted) {
        return;
      }

      setState(() {});

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to submit the exam. Please try again.',
          ),
        ),
      );

      _startTimer();
      _startStateSaver();
    }
  }

  // ===========================================================================
  // UPDATE ANSWER CORRECTNESS
  // ===========================================================================

  Future<void>
      _updateAnswerCorrectness({
    required String questionId,
    required String selectedOptionId,
    required bool isCorrect,
  }) async {
    final attemptId =
        _attemptId;

    if (attemptId == null) {
      return;
    }

    final existing =
        await _supabase
            .from('exam_answers')
            .select('id')
            .eq(
              'attempt_id',
              attemptId,
            )
            .eq(
              'question_id',
              questionId,
            )
            .maybeSingle();

    final now =
        DateTime.now()
            .toUtc()
            .toIso8601String();

    if (existing == null) {
      await _supabase
          .from('exam_answers')
          .insert({
        'attempt_id':
            attemptId,
        'question_id':
            questionId,
        'selected_option_id':
            selectedOptionId,
        'is_correct':
            isCorrect,
        'answered_at':
            now,
      });

      return;
    }

    await _supabase
        .from('exam_answers')
        .update({
      'selected_option_id':
          selectedOptionId,
      'is_correct':
          isCorrect,
      'answered_at':
          now,
    })
        .eq(
      'id',
      existing['id'],
    );
  }

  // ===========================================================================
  // FORMAT TIME
  // ===========================================================================

  String _formatTime(
    int seconds,
  ) {
    final minutes =
        seconds ~/ 60;

    final remaining =
        seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (
        didPop,
        result,
      ) {
        if (didPop ||
            _ignoreBackOnce ||
            _isSubmitting) {
          return;
        }

        unawaited(
          _handleBack(),
        );
      },
      child: Scaffold(
        appBar:
            AppBar(
          title:
              Text(
            widget.examTitle,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
          ),
          leading:
              IconButton(
            onPressed:
                _handleBack,
            icon:
                const Icon(
              Icons
                  .arrow_back_rounded,
            ),
          ),
          actions: [
            Padding(
              padding:
                  const EdgeInsets.only(
                right:
                    16,
              ),
              child:
                  Center(
                child:
                    Text(
                  _formatTime(
                    _remainingSeconds,
                  ),
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.w700,
                    color:
                        _remainingSeconds <=
                                60
                            ? Theme.of(
                                context,
                              )
                                .colorScheme
                                .error
                            : null,
                  ),
                ),
              ),
            ),
          ],
        ),
        body:
            FutureBuilder<
                List<ExamQuestion>>(
          future:
              _questionsFuture,
          builder:
              (
            context,
            snapshot,
          ) {
            if (_isLoadingAttempt ||
                snapshot.connectionState ==
                    ConnectionState
                        .waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              debugPrint(
                'Exam error: ${snapshot.error}',
              );

              return const _ErrorView(
                message:
                    'Unable to load exam questions.',
              );
            }

            final questions =
                snapshot.data ??
                    [];

            if (questions.isEmpty) {
              return const _ErrorView(
                message:
                    'This exam has no questions yet.',
              );
            }

            if (_currentQuestionIndex <
                0) {
              _currentQuestionIndex =
                  0;
            }

            if (_currentQuestionIndex >=
                questions.length) {
              _currentQuestionIndex =
                  questions.length -
                      1;
            }

            final question =
                questions[
                    _currentQuestionIndex];

            return Column(
              children: [
                // =============================================================
                // PROGRESS
                // =============================================================

                Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    18,
                    16,
                    18,
                    8,
                  ),
                  child:
                      Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            'Question '
                            '${_currentQuestionIndex + 1}',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${questions.length}',
                            style:
                                TextStyle(
                              color:
                                  Theme.of(
                                context,
                              )
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
                      const SizedBox(
                        height:
                            8,
                      ),
                      LinearProgressIndicator(
                        value:
                            (_currentQuestionIndex +
                                    1) /
                                questions.length,
                      ),
                    ],
                  ),
                ),

                // =============================================================
                // QUESTION
                // =============================================================

                Expanded(
                  child:
                      SingleChildScrollView(
                    physics:
                        const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      18,
                      20,
                      18,
                      20,
                    ),
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          question
                              .questionText,
                          style:
                              const TextStyle(
                            fontSize:
                                21,
                            fontWeight:
                                FontWeight.w700,
                            height:
                                1.35,
                          ),
                        ),

                        const SizedBox(
                          height:
                              24,
                        ),

                        ...question
                            .options
                            .map(
                          (
                            option,
                          ) {
                            final selected =
                                _selectedAnswers[
                                        question
                                            .id] ==
                                    option.id;

                            return Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                bottom:
                                    12,
                              ),
                              child:
                                  InkWell(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  14,
                                ),
                                onTap:
                                    () {
                                  _selectAnswer(
                                    question,
                                    option,
                                  );
                                },
                                child:
                                    Container(
                                  width:
                                      double.infinity,
                                  padding:
                                      const EdgeInsets
                                          .all(
                                    16,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      14,
                                    ),
                                    color:
                                        selected
                                            ? Theme.of(
                                                context,
                                              )
                                                .colorScheme
                                                .primary
                                                .withValues(
                                              alpha:
                                                  0.08,
                                            )
                                            : null,
                                    border:
                                        Border.all(
                                      color:
                                          selected
                                              ? Theme.of(
                                                  context,
                                                )
                                                  .colorScheme
                                                  .primary
                                              : Theme.of(
                                                  context,
                                                )
                                                  .colorScheme
                                                  .outline
                                                  .withValues(
                                                alpha:
                                                    0.35,
                                              ),
                                      width:
                                          selected
                                              ? 2
                                              : 1,
                                    ),
                                  ),
                                  child:
                                      Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Icon(
                                        selected
                                            ? Icons
                                                .radio_button_checked
                                            : Icons
                                                .radio_button_off,
                                        color:
                                            selected
                                                ? Theme.of(
                                                    context,
                                                  )
                                                    .colorScheme
                                                    .primary
                                                : Theme.of(
                                                    context,
                                                  )
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(
                                                  alpha:
                                                      0.40,
                                                ),
                                      ),
                                      const SizedBox(
                                        width:
                                            12,
                                      ),
                                      Expanded(
                                        child:
                                            Text(
                                          option
                                              .optionText,
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                16,
                                            height:
                                                1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // =============================================================
                // NAVIGATION
                // =============================================================

                SafeArea(
                  top:
                      false,
                  child:
                      Padding(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      18,
                      8,
                      18,
                      14,
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
                                  _isSubmitting
                                      ? null
                                      : _previousQuestion,
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
                          const SizedBox(
                            width:
                                12,
                          ),

                        Expanded(
                          child:
                              FilledButton(
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () {
                                        _nextQuestion(
                                          questions,
                                        );
                                      },
                            child:
                                Text(
                              _currentQuestionIndex ==
                                      questions.length -
                                          1
                                  ? 'Submit'
                                  : 'Next',
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
      ),
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView
    extends StatelessWidget {
  final String message;

  const _ErrorView({
    required this.message,
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
            const EdgeInsets.all(
          30,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size:
                  60,
              color:
                  theme
                      .colorScheme
                      .error,
            ),
            const SizedBox(
              height:
                  16,
            ),
            Text(
              message,
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}