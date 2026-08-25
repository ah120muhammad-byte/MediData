class ExamQuestion {
  final String id;
  final String examId;
  final String questionText;
  final String? explanation;
  final int displayOrder;
  final List<ExamOption> options;

  const ExamQuestion({
    required this.id,
    required this.examId,
    required this.questionText,
    this.explanation,
    required this.displayOrder,
    required this.options,
  });

  ExamQuestion copyWith({
    List<ExamOption>? options,
  }) {
    return ExamQuestion(
      id: id,
      examId: examId,
      questionText: questionText,
      explanation: explanation,
      displayOrder: displayOrder,
      options: options ?? this.options,
    );
  }
}

class ExamOption {
  final String id;
  final String questionId;
  final String optionText;
  final int displayOrder;

  const ExamOption({
    required this.id,
    required this.questionId,
    required this.optionText,
    required this.displayOrder,
  });
}

class ExamCorrectAnswer {
  final String questionId;
  final String correctOptionId;

  const ExamCorrectAnswer({
    required this.questionId,
    required this.correctOptionId,
  });
}