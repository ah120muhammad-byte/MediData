import 'package:supabase_flutter/supabase_flutter.dart';

class LectureProgress {
  final String lectureId;

  final int audioPosition;
  final int videoPosition;

  final bool audioCompleted;
  final bool videoCompleted;

  const LectureProgress({
    required this.lectureId,
    required this.audioPosition,
    required this.videoPosition,
    required this.audioCompleted,
    required this.videoCompleted,
  });

  const LectureProgress.empty({
    required this.lectureId,
  })  : audioPosition = 0,
        videoPosition = 0,
        audioCompleted = false,
        videoCompleted = false;

  factory LectureProgress.fromMap(
    Map<String, dynamic> map,
  ) {
    return LectureProgress(
      lectureId:
          map['lecture_id']?.toString() ?? '',
      audioPosition:
          (map['audio_position'] as num?)
                  ?.toInt() ??
              0,
      videoPosition:
          (map['video_position'] as num?)
                  ?.toInt() ??
              0,
      audioCompleted:
          map['audio_completed'] as bool? ??
              false,
      videoCompleted:
          map['video_completed'] as bool? ??
              false,
    );
  }
}

class LectureProgressService {
  LectureProgressService._();

  static final LectureProgressService instance =
      LectureProgressService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ===========================================================================
  // GET PROGRESS
  // ===========================================================================

  Future<LectureProgress> getProgress(
    String lectureId,
  ) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return LectureProgress.empty(
        lectureId: lectureId,
      );
    }

    final response = await _supabase
        .from('lecture_progress')
        .select('''
          lecture_id,
          audio_position,
          video_position,
          audio_completed,
          video_completed
        ''')
        .eq(
          'user_id',
          user.id,
        )
        .eq(
          'lecture_id',
          lectureId,
        )
        .maybeSingle();

    if (response == null) {
      return LectureProgress.empty(
        lectureId: lectureId,
      );
    }

    return LectureProgress.fromMap(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }

  // ===========================================================================
  // SAVE AUDIO POSITION
  // ===========================================================================

  Future<void> saveAudioPosition({
    required String lectureId,
    required int positionSeconds,
  }) async {
    final safePosition =
        positionSeconds < 0
            ? 0
            : positionSeconds;

    await _upsert(
      lectureId: lectureId,
      audioPosition:
          safePosition,
    );
  }

  // ===========================================================================
  // SAVE VIDEO POSITION
  // ===========================================================================

  Future<void> saveVideoPosition({
    required String lectureId,
    required int positionSeconds,
  }) async {
    final safePosition =
        positionSeconds < 0
            ? 0
            : positionSeconds;

    await _upsert(
      lectureId: lectureId,
      videoPosition:
          safePosition,
    );
  }

  // ===========================================================================
  // MARK AUDIO COMPLETED
  // ===========================================================================

  Future<void> markAudioCompleted(
    String lectureId,
  ) async {
    await _upsert(
      lectureId: lectureId,
      audioCompleted: true,
    );
  }

  // ===========================================================================
  // MARK VIDEO COMPLETED
  // ===========================================================================

  Future<void> markVideoCompleted(
    String lectureId,
  ) async {
    await _upsert(
      lectureId: lectureId,
      videoCompleted: true,
    );
  }

  // ===========================================================================
  // UPSERT
  // ===========================================================================

  Future<void> _upsert({
    required String lectureId,
    int? audioPosition,
    int? videoPosition,
    bool? audioCompleted,
    bool? videoCompleted,
  }) async {
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final data =
        <String, dynamic>{
      'user_id': user.id,
      'lecture_id': lectureId,
      'updated_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
      'last_opened_at':
          DateTime.now()
              .toUtc()
              .toIso8601String(),
    };

    if (audioPosition != null) {
      data['audio_position'] =
          audioPosition;
    }

    if (videoPosition != null) {
      data['video_position'] =
          videoPosition;
    }

    if (audioCompleted != null) {
      data['audio_completed'] =
          audioCompleted;
    }

    if (videoCompleted != null) {
      data['video_completed'] =
          videoCompleted;
    }

    await _supabase
        .from('lecture_progress')
        .upsert(
          data,
          onConflict:
              'user_id,lecture_id',
        );
  }
}