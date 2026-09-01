import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../models/exam_models.dart';
import 'exam_result_screen.dart';

class ExamScreen extends StatefulWidget {
  final String examId;
  final String examTitle;
  final int durationMinutes;
  final int passingScore;
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
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen>
    with WidgetsBindingObserver {
  final SupabaseClient _supabase = Supabase.instance.client;

  late Future<List<ExamQuestion>> _questionsFuture;

  final Map<String, String> _selectedAnswers = <String, String>{};
  final Map<String, Future<void>> _answerSaveOperations =
      <String, Future<void>>{};

  Timer? _timer;
  Timer? _saveStateTimer;

  String? _attemptId;
  int _remainingSeconds = 0;
  int _currentQuestionIndex = 0;

  bool _isLoadingAttempt = true;
  bool _isSubmitting = false;
  bool _isInitialized = false;
  bool _lifecyclePaused = false;
  bool _lifecycleTransition = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _remainingSeconds = widget.durationMinutes * 60;
    _questionsFuture = _initializeExam();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized ||
        _attemptId == null ||
        _isSubmitting ||
        _leaving) {
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_pauseForLifecycle());
        break;
      case AppLifecycleState.resumed:
        unawaited(_resumeFromLifecycle());
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _saveStateTimer?.cancel();
    super.dispose();
  }

  Future<List<ExamQuestion>> _initializeExam() async {
    final questions = await _loadExam();

    if (questions.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingAttempt = false;
        });
      }
      return questions;
    }

    await _startOrRestoreAttempt(questionCount: questions.length);
    return questions;
  }

  Future<List<ExamQuestion>> _loadExam() async {
    final rawQuestions = await _supabase
        .from('questions')
        .select('id, exam_id, question_text, explanation, display_order')
        .eq('exam_id', widget.examId)
        .order('display_order', ascending: true);

    final questions = (rawQuestions as List).map((raw) {
      final map = Map<String, dynamic>.from(raw);
      return ExamQuestion(
        id: map['id'].toString(),
        examId: map['exam_id'].toString(),
        questionText: map['question_text']?.toString() ?? '',
        explanation: map['explanation']?.toString(),
        displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
        options: const <ExamOption>[],
      );
    }).toList();

    if (questions.isEmpty) return questions;

    final questionIds = questions.map((q) => q.id).toList();

    final rawOptions = await _supabase
        .from('question_options')
        .select('id, question_id, option_text, display_order')
        .inFilter('question_id', questionIds)
        .order('display_order', ascending: true);

    final optionsByQuestion = <String, List<ExamOption>>{};

    for (final raw in rawOptions as List) {
      final map = Map<String, dynamic>.from(raw);
      final option = ExamOption(
        id: map['id'].toString(),
        questionId: map['question_id'].toString(),
        optionText: map['option_text']?.toString() ?? '',
        displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      );
      optionsByQuestion.putIfAbsent(option.questionId, () => <ExamOption>[]).add(option);
    }

    return questions.map((question) {
      return question.copyWith(
        options: optionsByQuestion[question.id] ?? const <ExamOption>[],
      );
    }).toList();
  }

  Future<void> _startOrRestoreAttempt({required int questionCount}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Your session has expired. Please log in again.');
    }

    final raw = await _supabase.rpc(
      'start_exam',
      params: <String, dynamic>{'p_exam_id': widget.examId},
    );

    final data = _asMap(raw);
    _attemptId = _stringValue(data['attempt_id']);

    if (_attemptId == null || _attemptId!.isEmpty) {
      throw Exception('Unable to create or restore the exam attempt.');
    }

    _remainingSeconds = _clampRemaining(
      _intValue(data['remaining_seconds']),
    );
    _currentQuestionIndex = _clampQuestionIndex(
      _intValue(data['current_question_index']),
      questionCount,
    );
    _lifecyclePaused = data['is_paused'] == true;

    await _loadSavedAnswers();

    if (_lifecyclePaused) {
      await _resumeAttemptFromServer();
      _lifecyclePaused = false;
    }

    if (!mounted) return;

    setState(() {
      _isLoadingAttempt = false;
      _isInitialized = true;
    });

    if (_remainingSeconds <= 0) {
      unawaited(_finishExam(autoSubmit: true));
      return;
    }

    _startTimer();
    _startStateSaver();
  }

  Future<void> _loadSavedAnswers() async {
    final attemptId = _attemptId;
    if (attemptId == null || attemptId.isEmpty) return;

    final rawAnswers = await _supabase
        .from('exam_answers')
        .select('question_id, selected_option_id')
        .eq('attempt_id', attemptId);

    _selectedAnswers.clear();

    for (final raw in rawAnswers as List) {
      final map = Map<String, dynamic>.from(raw);
      final questionId = _stringValue(map['question_id']);
      final optionId = _stringValue(map['selected_option_id']);

      if (questionId != null &&
          questionId.isNotEmpty &&
          optionId != null &&
          optionId.isNotEmpty) {
        _selectedAnswers[questionId] = optionId;
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          !_isInitialized ||
          _isSubmitting ||
          _lifecyclePaused ||
          _lifecycleTransition) {
        return;
      }

      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        _timer?.cancel();
        _saveStateTimer?.cancel();
        unawaited(_finishExam(autoSubmit: true));
        return;
      }

      setState(() => _remainingSeconds--);
    });
  }

  void _startStateSaver() {
    _saveStateTimer?.cancel();
    _saveStateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isInitialized ||
          _isSubmitting ||
          _lifecyclePaused ||
          _lifecycleTransition) {
        return;
      }
      unawaited(_saveProgress());
    });
  }

  Future<void> _saveProgress() async {
    final attemptId = _attemptId;
    if (attemptId == null ||
        attemptId.isEmpty ||
        _isSubmitting ||
        _lifecyclePaused) {
      return;
    }

    final pendingOk = await _waitForPendingAnswers();
    if (!pendingOk || !mounted || _isSubmitting || _lifecyclePaused) {
      return;
    }

    try {
      final raw = await _supabase.rpc(
        'save_exam_progress',
        params: <String, dynamic>{
          'p_attempt_id': attemptId,
          'p_current_question_index': _currentQuestionIndex,
        },
      );

      final data = _asMap(raw);
      final serverRemaining = _clampRemaining(
        _intValue(data['remaining_seconds']),
      );

      if (serverRemaining < _remainingSeconds) {
        setState(() => _remainingSeconds = serverRemaining);
      }

      if (data['status']?.toString() == 'completed' && mounted) {
        _timer?.cancel();
        _saveStateTimer?.cancel();
        unawaited(_finishExam(autoSubmit: true));
      }
    } catch (_) {
      // The next answer/save cycle will retry. The timer remains local while active.
    }
  }

  Future<void> _onAnswerSelected(
    String questionId,
    String optionId,
  ) async {
    if (_isSubmitting ||
        _lifecyclePaused ||
        _lifecycleTransition) {
      return;
    }

    setState(() {
      _selectedAnswers[questionId] = optionId;
    });

    final future = _saveAnswer(questionId, optionId);
    _answerSaveOperations[questionId] = future;

    try {
      await future;
    } catch (e) {
      if (mounted && _selectedAnswers[questionId] == optionId) {
        setState(() => _selectedAnswers.remove(questionId));
        _showError(_cleanError(e));
      }
    } finally {
      if (identical(_answerSaveOperations[questionId], future)) {
        _answerSaveOperations.remove(questionId);
      }
    }
  }

  Future<void> _saveAnswer(String questionId, String optionId) async {
    final attemptId = _attemptId;
    if (attemptId == null || attemptId.isEmpty) {
      throw Exception('Exam attempt is not available.');
    }

    final raw = await _supabase.rpc(
      'submit_exam_answer',
      params: <String, dynamic>{
        'p_attempt_id': attemptId,
        'p_question_id': questionId,
        'p_selected_option_id': optionId,
      },
    );

    final data = _asMap(raw);
    final serverRemaining = _clampRemaining(
      _intValue(data['remaining_seconds']),
    );

    if (mounted && serverRemaining < _remainingSeconds) {
      setState(() => _remainingSeconds = serverRemaining);
    }

    if (serverRemaining <= 0) {
      _timer?.cancel();
      _saveStateTimer?.cancel();
    }
  }

  Future<bool> _waitForPendingAnswers() async {
    final pending = List<Future<void>>.from(_answerSaveOperations.values);
    if (pending.isEmpty) return true;

    var success = true;
    for (final future in pending) {
      try {
        await future;
      } catch (e) {
        final text = e.toString().toLowerCase();
        if (!text.contains('expired') && !text.contains('time has ended')) {
          success = false;
        }
      }
    }
    return success;
  }

  Future<void> _pauseForLifecycle() async {
    if (_lifecyclePaused ||
        _lifecycleTransition ||
        _isSubmitting ||
        _leaving) {
      return;
    }

    final attemptId = _attemptId;
    if (attemptId == null || attemptId.isEmpty) return;

    _lifecycleTransition = true;
    _lifecyclePaused = true;
    _timer?.cancel();
    _saveStateTimer?.cancel();

    try {
      await _waitForPendingAnswers();

      final raw = await _supabase.rpc(
        'pause_exam',
        params: <String, dynamic>{
          'p_attempt_id': attemptId,
          'p_current_question_index': _currentQuestionIndex,
        },
      );

      final data = _asMap(raw);
      final serverRemaining = _clampRemaining(
        _intValue(data['remaining_seconds']),
      );

      if (mounted) {
        setState(() {
          _remainingSeconds = serverRemaining;
          _currentQuestionIndex = _intValue(data['current_question_index']);
          _lifecyclePaused = data['status']?.toString() != 'completed';
        });
      }

      if (data['status']?.toString() == 'completed' && mounted) {
        unawaited(_finishExam(autoSubmit: true));
      }
    } catch (e) {
      if (mounted) {
        _showError(_cleanError(e));
      }
    } finally {
      _lifecycleTransition = false;
    }
  }

  Future<void> _resumeFromLifecycle() async {
    if (!_lifecyclePaused ||
        _lifecycleTransition ||
        _isSubmitting ||
        _leaving) {
      return;
    }

    final attemptId = _attemptId;
    if (attemptId == null || attemptId.isEmpty) return;

    _lifecycleTransition = true;

    try {
      await _resumeAttemptFromServer();
      if (!mounted) return;
      setState(() => _lifecyclePaused = false);
      _startTimer();
      _startStateSaver();
    } catch (e) {
      final text = e.toString().toLowerCase();
      if (text.contains('expired') || text.contains('time has expired')) {
        if (mounted) {
          setState(() {
            _remainingSeconds = 0;
            _lifecyclePaused = false;
          });
        }
        unawaited(_finishExam(autoSubmit: true));
      } else if (mounted) {
        _showError(_cleanError(e));
      }
    } finally {
      _lifecycleTransition = false;
    }
  }

  Future<void> _resumeAttemptFromServer() async {
    final attemptId = _attemptId;
    if (attemptId == null || attemptId.isEmpty) {
      throw Exception('Exam attempt is not available.');
    }

    final raw = await _supabase.rpc(
      'resume_exam',
      params: <String, dynamic>{'p_attempt_id': attemptId},
    );

    final data = _asMap(raw);
    final remaining = _clampRemaining(_intValue(data['remaining_seconds']));

    if (remaining <= 0) {
      throw Exception('Exam time has expired.');
    }

    _remainingSeconds = remaining;
    _currentQuestionIndex = _intValue(data['current_question_index']);
  }

  Future<void> _finishExam({required bool autoSubmit}) async {
    if (_isSubmitting || _attemptId == null || _leaving && !autoSubmit) {
      return;
    }

    final attemptId = _attemptId!;

    setState(() => _isSubmitting = true);
    _timer?.cancel();
    _saveStateTimer?.cancel();

    try {
      await _waitForPendingAnswers();

      final raw = await _supabase.rpc(
        'finish_exam',
        params: <String, dynamic>{'p_attempt_id': attemptId},
      );

      final data = _asMap(raw);
      final score = _intValue(data['score']);
      final correctAnswers = _intValue(data['correct_answers']);
      final totalQuestions = _intValue(data['total_questions']);
      final serverAutoSubmitted = data['auto_submitted'] == true;

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ExamResultScreen(
            examId: widget.examId,
            attemptId: attemptId,
            examTitle: widget.examTitle,
            durationMinutes: widget.durationMinutes,
            score: score,
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
            passingScore: widget.passingScore,
            passed: score >= widget.passingScore,
            autoSubmitted: serverAutoSubmitted || autoSubmit,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _showError(_cleanError(e));

      if (!_lifecyclePaused && !_leaving && _remainingSeconds > 0) {
        _startTimer();
        _startStateSaver();
      }
    }
  }

  Future<void> _confirmSubmit() async {
    if (_isSubmitting || _lifecyclePaused) return;

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Submit Exam?'),
          content: const Text(
            'Your saved answers will be submitted and the result will be calculated. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Continue'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (shouldSubmit == true) {
      await _finishExam(autoSubmit: false);
    }
  }

  Future<bool> _confirmExit() async {
    if (_isSubmitting || _attemptId == null || !_isInitialized) {
      return true;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Leave Exam?'),
          content: const Text(
            'The exam will be paused and your answers will be saved. You can continue later with the remaining time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    if (leave != true) return false;

    _leaving = true;
    await _pauseForLifecycle();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _leaving) return;
        final shouldLeave = await _confirmExit();
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        } else {
          _leaving = false;
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context),
        body: FutureBuilder<List<ExamQuestion>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                _isLoadingAttempt) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ErrorView(
                message: _cleanError(snapshot.error!),
                onRetry: () {
                  setState(() {
                    _isLoadingAttempt = true;
                    _questionsFuture = _initializeExam();
                  });
                },
              );
            }

            final questions = snapshot.data ?? const <ExamQuestion>[];
            if (questions.isEmpty) {
              return const Center(child: Text('No questions found for this exam.'));
            }

            final safeIndex = _clampQuestionIndex(
              _currentQuestionIndex,
              questions.length,
            );
            final question = questions[safeIndex];
            final selectedOptionId = _selectedAnswers[question.id];

            return Column(
              children: [
                _buildTopInfo(context, questions.length),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      Responsive.horizontalPadding(context),
                      8,
                      Responsive.horizontalPadding(context),
                      24,
                    ),
                    children: [
                      _QuestionCard(
                        index: safeIndex,
                        total: questions.length,
                        question: question,
                        selectedOptionId: selectedOptionId,
                        disabled: _isSubmitting || _lifecyclePaused,
                        onOptionSelected: (optionId) {
                          unawaited(_onAnswerSelected(question.id, optionId));
                        },
                      ),
                    ],
                  ),
                ),
                _buildBottomBar(context, questions),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      centerTitle: true,
      title: Text(
        widget.examTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: IconButton(
        tooltip: 'Leave exam',
        onPressed: _isSubmitting ? null : () async {
          final shouldLeave = await _confirmExit();
          if (shouldLeave && mounted) {
            Navigator.of(context).pop();
          } else {
            _leaving = false;
          }
        },
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: _TimerPill(
              remainingSeconds: _remainingSeconds,
              isPaused: _lifecyclePaused,
              color: scheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopInfo(BuildContext context, int totalQuestions) {
    final scheme = Theme.of(context).colorScheme;
    final answeredCount = _selectedAnswers.length;
    final progress = totalQuestions == 0 ? 0.0 : answeredCount / totalQuestions;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.horizontalPadding(context),
        14,
        Responsive.horizontalPadding(context),
        4,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$answeredCount of $totalQuestions answered',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_lifecyclePaused)
                Text(
                  'Paused',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    List<ExamQuestion> questions,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final index = _clampQuestionIndex(_currentQuestionIndex, questions.length);
    final isFirst = index == 0;
    final isLast = index == questions.length - 1;

    return SafeArea(
      top: false,
      child: Material(
        color: scheme.surface,
        elevation: 8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.horizontalPadding(context),
            10,
            Responsive.horizontalPadding(context),
            10,
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: isFirst || _isSubmitting || _lifecyclePaused
                    ? null
                    : () {
                        setState(() => _currentQuestionIndex = index - 1);
                        unawaited(_saveProgress());
                      },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Previous'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isLast
                    ? FilledButton.icon(
                        onPressed: _isSubmitting || _lifecyclePaused
                            ? null
                            : _confirmSubmit,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Submit Exam'),
                      )
                    : FilledButton.icon(
                        onPressed: _isSubmitting || _lifecyclePaused
                            ? null
                            : () {
                                setState(() => _currentQuestionIndex = index + 1);
                                unawaited(_saveProgress());
                              },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Next'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _clampRemaining(int value) {
    final max = widget.durationMinutes * 60;
    if (value < 0) return 0;
    if (value > max) return max;
    return value;
  }

  int _clampQuestionIndex(int value, int length) {
    if (length <= 0) return 0;
    if (value < 0) return 0;
    if (value >= length) return length - 1;
    return value;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw Exception('Invalid response from exam service.');
  }

  String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _cleanError(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception:')) {
      return text.substring('Exception:'.length).trim();
    }
    return text.isEmpty ? 'Unable to process the exam.' : text;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final int total;
  final ExamQuestion question;
  final String? selectedOptionId;
  final bool disabled;
  final ValueChanged<String> onOptionSelected;

  const _QuestionCard({
    required this.index,
    required this.total,
    required this.question,
    required this.selectedOptionId,
    required this.disabled,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(Responsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question ${index + 1} of $total',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              question.questionText,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            ...question.options.map((option) {
              final selected = option.id == selectedOptionId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OptionCard(
                  option: option,
                  selected: selected,
                  disabled: disabled,
                  onTap: () => onOptionSelected(option.id),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final ExamOption option;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _OptionCard({
    required this.option,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.10)
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.optionText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.45,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

class _TimerPill extends StatelessWidget {
  final int remainingSeconds;
  final bool isPaused;
  final Color color;

  const _TimerPill({
    required this.remainingSeconds,
    required this.isPaused,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final text = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaused ? Icons.pause_rounded : Icons.timer_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
