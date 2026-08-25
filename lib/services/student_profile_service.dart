import 'package:supabase_flutter/supabase_flutter.dart';

class StudentProfile {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? profileImageUrl;

  const StudentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.profileImageUrl,
  });

  factory StudentProfile.fromMap(
    Map<String, dynamic> map,
  ) {
    return StudentProfile(
      id:
          map['id']?.toString() ?? '',
      fullName:
          map['full_name']?.toString() ??
              'Student',
      email:
          map['email']?.toString() ??
              '',
      phone:
          map['phone']?.toString(),
      profileImageUrl:
          map['profile_image_url']
              ?.toString(),
    );
  }
}

// =============================================================================
// EXAM ATTEMPT
// =============================================================================

class StudentExamAttempt {
  final String id;
  final String examId;
  final String examTitle;

  final int score;
  final int totalQuestions;
  final int correctAnswers;

  final DateTime? startedAt;
  final DateTime? completedAt;

  final String status;

  final int remainingSeconds;

  const StudentExamAttempt({
    required this.id,
    required this.examId,
    required this.examTitle,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.startedAt,
    required this.completedAt,
    required this.status,
    required this.remainingSeconds,
  });

  bool get isCompleted =>
      status == 'completed';

  bool get isInProgress =>
      status == 'in_progress';

  bool get isAbandoned =>
      status == 'abandoned';

  bool get passed {
    if (!isCompleted) {
      return false;
    }

    return score >= 50;
  }

  factory StudentExamAttempt.fromMap(
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

    return StudentExamAttempt(
      id:
          map['id']?.toString() ?? '',
      examId:
          map['exam_id']?.toString() ??
              '',
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
    );
  }
}

// =============================================================================
// LECTURE ACTIVITY
// =============================================================================

class StudentLectureActivity {
  final String lectureId;
  final String lectureTitle;
  final String moduleId;
  final String moduleName;

  final int audioPosition;
  final int videoPosition;

  final bool audioCompleted;
  final bool videoCompleted;

  final DateTime? lastOpenedAt;

  const StudentLectureActivity({
    required this.lectureId,
    required this.lectureTitle,
    required this.moduleId,
    required this.moduleName,
    required this.audioPosition,
    required this.videoPosition,
    required this.audioCompleted,
    required this.videoCompleted,
    required this.lastOpenedAt,
  });

  int get progressPercent {
    if (audioCompleted ||
        videoCompleted) {
      return 100;
    }

    if (audioPosition > 0 ||
        videoPosition > 0) {
      return 50;
    }

    return 0;
  }

  factory StudentLectureActivity.fromMap(
    Map<String, dynamic> map,
  ) {
    final lectureRaw =
        map['lectures'];

    final lecture =
        lectureRaw is Map
            ? Map<String, dynamic>.from(
                lectureRaw,
              )
            : <String, dynamic>{};

    final moduleRaw =
        lecture['modules'];

    final module =
        moduleRaw is Map
            ? Map<String, dynamic>.from(
                moduleRaw,
              )
            : <String, dynamic>{};

    return StudentLectureActivity(
      lectureId:
          map['lecture_id']
                  ?.toString() ??
              '',
      lectureTitle:
          lecture['title']
                  ?.toString() ??
              'Lecture',
      moduleId:
          lecture['module_id']
                  ?.toString() ??
              '',
      moduleName:
          module['name']
                  ?.toString() ??
              'Module',
      audioPosition:
          (map['audio_position']
                      as num?)
                  ?.toInt() ??
              0,
      videoPosition:
          (map['video_position']
                      as num?)
                  ?.toInt() ??
              0,
      audioCompleted:
          map['audio_completed']
                  as bool? ??
              false,
      videoCompleted:
          map['video_completed']
                  as bool? ??
              false,
      lastOpenedAt:
          DateTime.tryParse(
        map['last_opened_at']
                ?.toString() ??
            '',
      ),
    );
  }
}

// =============================================================================
// DAILY STUDY ACTIVITY
// =============================================================================

class DailyStudyActivity {
  final DateTime day;

  final int studySeconds;

  final int lecturesOpened;

  final int completedMedia;

  final int examAttempts;

  const DailyStudyActivity({
    required this.day,
    required this.studySeconds,
    required this.lecturesOpened,
    required this.completedMedia,
    required this.examAttempts,
  });

  double get studyMinutes =>
      studySeconds / 60.0;

  double get studyHours =>
      studySeconds / 3600.0;
}

// =============================================================================
// PROFILE ANALYTICS
// =============================================================================

class StudentProfileAnalytics {
  final int lecturesOpened;
  final int audioCompleted;
  final int videoCompleted;

  final int examAttempts;
  final int completedExams;
  final int passedExams;

  final double averageScore;
  final double bestScore;

  final int totalStudySeconds;

  final List<StudentExamAttempt>
      attempts;

  final List<StudentLectureActivity>
      lectureActivities;

  final List<DailyStudyActivity>
      dailyActivity;

  const StudentProfileAnalytics({
    required this.lecturesOpened,
    required this.audioCompleted,
    required this.videoCompleted,
    required this.examAttempts,
    required this.completedExams,
    required this.passedExams,
    required this.averageScore,
    required this.bestScore,
    required this.totalStudySeconds,
    required this.attempts,
    required this.lectureActivities,
    required this.dailyActivity,
  });

  double get successRate {
    if (completedExams == 0) {
      return 0;
    }

    return passedExams /
        completedExams *
        100;
  }

  double get mediaCompletion {
    final total =
        audioCompleted +
            videoCompleted;

    if (total == 0 ||
        lecturesOpened == 0) {
      return 0;
    }

    return total /
        (lecturesOpened * 2)
        .clamp(
          1,
          double.infinity,
        );
  }

  Duration get totalStudyDuration =>
      Duration(
        seconds:
            totalStudySeconds,
      );

  String get formattedStudyTime {
    final duration =
        totalStudyDuration;

    final hours =
        duration.inHours;

    final minutes =
        duration.inMinutes
            .remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
  }
}

// =============================================================================
// PROFILE SERVICE
// =============================================================================

class StudentProfileService {
  StudentProfileService._();

  static final StudentProfileService
      instance =
      StudentProfileService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ===========================================================================
  // PROFILE
  // ===========================================================================

  Future<StudentProfile>
      getProfile() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'No authenticated user.',
      );
    }

    final response =
        await _supabase
            .from('profiles')
            .select('''
              id,
              full_name,
              email,
              phone,
              profile_image_url
            ''')
            .eq(
              'id',
              user.id,
            )
            .maybeSingle();

    if (response == null) {
      throw Exception(
        'Student profile not found.',
      );
    }

    return StudentProfile.fromMap(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }

  // ===========================================================================
  // ANALYTICS
  // ===========================================================================

  Future<StudentProfileAnalytics>
      getAnalytics() async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'No authenticated user.',
      );
    }

    // -------------------------------------------------------------------------
    // LECTURE PROGRESS
    // -------------------------------------------------------------------------

    final lectureResponse =
        await _supabase
            .from('lecture_progress')
            .select('''
              lecture_id,
              audio_position,
              video_position,
              audio_completed,
              video_completed,
              last_opened_at,
              lectures (
                id,
                title,
                module_id,
                modules (
                  id,
                  name
                )
              )
            ''')
            .eq(
              'user_id',
              user.id,
            )
            .order(
              'last_opened_at',
              ascending: false,
            );

    final lectureActivities =
        (lectureResponse as List)
            .map(
              (item) =>
                  StudentLectureActivity
                      .fromMap(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            )
            .toList();

    // -------------------------------------------------------------------------
    // EXAM ATTEMPTS
    // -------------------------------------------------------------------------

    final attemptsResponse =
        await _supabase
            .from('exam_attempts')
            .select('''
              id,
              exam_id,
              score,
              total_questions,
              correct_answers,
              started_at,
              completed_at,
              status,
              remaining_seconds,
              exams (
                id,
                title
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

    final attempts =
        (attemptsResponse as List)
            .map(
              (item) =>
                  StudentExamAttempt
                      .fromMap(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            )
            .toList();

    final completed =
        attempts
            .where(
              (item) =>
                  item.isCompleted,
            )
            .toList();

    final passed =
        completed
            .where(
              (item) =>
                  item.passed,
            )
            .length;

    final averageScore =
        completed.isEmpty
            ? 0.0
            : completed
                    .map(
                      (item) =>
                          item.score,
                    )
                    .reduce(
                      (a, b) =>
                          a + b,
                    ) /
                completed.length;

    final bestScore =
        completed.isEmpty
            ? 0.0
            : completed
                    .map(
                      (item) =>
                          item.score,
                    )
                    .reduce(
                      (a, b) =>
                          a > b ? a : b,
                    )
                    .toDouble();

    // -------------------------------------------------------------------------
    // REAL STUDY ACTIVITY
    // -------------------------------------------------------------------------

    final studyResponse =
        await _supabase
            .from(
              'student_study_activity',
            )
            .select('''
              activity_date,
              study_seconds,
              lectures_opened,
              audio_completed,
              video_completed
            ''')
            .eq(
              'user_id',
              user.id,
            )
            .order(
              'activity_date',
              ascending: true,
            );

    final studyRows =
        (studyResponse as List)
            .map(
              (item) =>
                  Map<String, dynamic>.from(
                item,
              ),
            )
            .toList();

    final studyByDate =
        <DateTime,
            Map<String, dynamic>>{};

    int totalStudySeconds = 0;

    for (final row in studyRows) {
      final rawDate =
          row['activity_date']
              ?.toString();

      final date =
          DateTime.tryParse(
        rawDate ?? '',
      );

      if (date == null) {
        continue;
      }

      final normalized =
          DateTime(
        date.year,
        date.month,
        date.day,
      );

      studyByDate[
              normalized] =
          row;

      totalStudySeconds +=
          (row['study_seconds']
                      as num?)
                  ?.toInt() ??
              0;
    }

    // -------------------------------------------------------------------------
    // LAST 7 DAYS
    // -------------------------------------------------------------------------

    final now =
        DateTime.now();

    final daily =
        List.generate(
      7,
      (index) {
        final day =
            DateTime(
          now.year,
          now.month,
          now.day -
              (6 - index),
        );

        final row =
            studyByDate[day];

        final lecturesOpened =
            (row?['lectures_opened']
                        as num?)
                    ?.toInt() ??
                0;

        final studySeconds =
            (row?['study_seconds']
                        as num?)
                    ?.toInt() ??
                0;

        final audioCompleted =
            (row?['audio_completed']
                        as num?)
                    ?.toInt() ??
                0;

        final videoCompleted =
            (row?['video_completed']
                        as num?)
                    ?.toInt() ??
                0;

        // Existing lecture history is still
        // used as a fallback for days that
        // happened before the new tracking
        // table existed.
        final fallbackLectures =
            lectureActivities
                .where(
                  (item) {
                    final date =
                        item.lastOpenedAt;

                    if (date == null) {
                      return false;
                    }

                    return date.year ==
                            day.year &&
                        date.month ==
                            day.month &&
                        date.day ==
                            day.day;
                  },
                )
                .length;

        final fallbackCompleted =
            lectureActivities
                .where(
                  (item) {
                    final date =
                        item.lastOpenedAt;

                    if (date == null) {
                      return false;
                    }

                    final sameDay =
                        date.year ==
                                day.year &&
                            date.month ==
                                day.month &&
                            date.day ==
                                day.day;

                    return sameDay &&
                        (item.audioCompleted ||
                            item
                                .videoCompleted);
                  },
                )
                .length;

        return DailyStudyActivity(
          day:
              day,
          studySeconds:
              studySeconds,
          lecturesOpened:
              lecturesOpened >
                      0
                  ? lecturesOpened
                  : fallbackLectures,
          completedMedia:
              audioCompleted +
                  videoCompleted >
                      0
                  ? audioCompleted +
                      videoCompleted
                  : fallbackCompleted,
          examAttempts:
              attempts
                  .where(
                    (item) {
                      final date =
                          item.startedAt;

                      if (date == null) {
                        return false;
                      }

                      return date.year ==
                              day.year &&
                          date.month ==
                              day.month &&
                          date.day ==
                              day.day;
                    },
                  )
                  .length,
        );
      },
    );

    return StudentProfileAnalytics(
      lecturesOpened:
          lectureActivities.length,
      audioCompleted:
          lectureActivities
              .where(
                (item) =>
                    item.audioCompleted,
              )
              .length,
      videoCompleted:
          lectureActivities
              .where(
                (item) =>
                    item.videoCompleted,
              )
              .length,
      examAttempts:
          attempts.length,
      completedExams:
          completed.length,
      passedExams:
          passed,
      averageScore:
          averageScore,
      bestScore:
          bestScore,
      totalStudySeconds:
          totalStudySeconds,
      attempts:
          attempts,
      lectureActivities:
          lectureActivities,
      dailyActivity:
          daily,
    );
  }

  // ===========================================================================
  // RECORD STUDY TIME
  // ===========================================================================

  Future<void> recordStudyActivity({
    required int seconds,
    int lecturesOpened = 0,
    int audioCompleted = 0,
    int videoCompleted = 0,
  }) async {
    if (seconds <= 0 &&
        lecturesOpened <= 0 &&
        audioCompleted <= 0 &&
        videoCompleted <= 0) {
      return;
    }

    await _supabase.rpc(
      'record_student_study_activity',
      params: {
        'p_seconds':
            seconds,
        'p_lectures_opened':
            lecturesOpened,
        'p_audio_completed':
            audioCompleted,
        'p_video_completed':
            videoCompleted,
      },
    );
  }

  // ===========================================================================
  // UPDATE PROFILE
  // ===========================================================================

  Future<void> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'No authenticated user.',
      );
    }

    await _supabase
        .from('profiles')
        .update({
          'full_name':
              fullName.trim(),
          'phone':
              phone?.trim(),
          'updated_at':
              DateTime.now()
                  .toUtc()
                  .toIso8601String(),
        })
        .eq(
          'id',
          user.id,
        );
  }

  // ===========================================================================
  // PASSWORD
  // ===========================================================================

  Future<void> updatePassword(
    String password,
  ) async {
    await _supabase.auth.updateUser(
      UserAttributes(
        password:
            password,
      ),
    );
  }

  // ===========================================================================
  // SIGN OUT
  // ===========================================================================

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}