import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'student_profile_service.dart';

class StudyActivityTracker {
  StudyActivityTracker._();

  static final StudyActivityTracker instance =
      StudyActivityTracker._();

  Timer? _flushTimer;

  bool _isPlaying = false;
  bool _isFlushing = false;
  bool _stateLoaded = false;

  DateTime? _sessionStartedAt;

  int _pendingStudySeconds = 0;
  int _pendingLecturesOpened = 0;
  int _pendingAudioCompleted = 0;
  int _pendingVideoCompleted = 0;

  Future<void>? _loadFuture;

  // ==========================================================================
  // LOCAL KEYS
  // ==========================================================================

  static const String _studySecondsKey =
      'study_pending_seconds';

  static const String _lecturesOpenedKey =
      'study_pending_lectures_opened';

  static const String _audioCompletedKey =
      'study_pending_audio_completed';

  static const String _videoCompletedKey =
      'study_pending_video_completed';

  static const String _isPlayingKey =
      'study_tracker_is_playing';

  static const String _sessionStartedKey =
      'study_tracker_session_started';

  // ==========================================================================
  // START / RESUME
  // ==========================================================================

  void start({
    bool lectureOpened = false,
  }) {
    if (lectureOpened) {
      _pendingLecturesOpened++;
      unawaited(
        _persistState(),
      );
    }

    if (_isPlaying) {
      return;
    }

    _isPlaying = true;

    _sessionStartedAt =
        DateTime.now().toUtc();

    _startFlushTimer();

    unawaited(
      _persistState(),
    );
  }

  // ==========================================================================
  // PAUSE
  // ==========================================================================

  Future<void> pause() async {
    await _ensureLoaded();

    if (!_isPlaying) {
      await flush();
      return;
    }

    _captureCurrentSession();

    _isPlaying = false;
    _sessionStartedAt = null;

    _flushTimer?.cancel();
    _flushTimer = null;

    await _persistState();

    await flush();
  }

  // ==========================================================================
  // STOP
  // ==========================================================================

  Future<void> stop() async {
    await _ensureLoaded();

    if (_isPlaying) {
      _captureCurrentSession();
    }

    _isPlaying = false;
    _sessionStartedAt = null;

    _flushTimer?.cancel();
    _flushTimer = null;

    await _persistState();

    await flush();
  }

  // ==========================================================================
  // AUDIO COMPLETED
  // ==========================================================================

  void markAudioCompleted() {
    _pendingAudioCompleted++;

    unawaited(
      _persistState(),
    );

    unawaited(
      flush(),
    );
  }

  // ==========================================================================
  // VIDEO COMPLETED
  // ==========================================================================

  void markVideoCompleted() {
    _pendingVideoCompleted++;

    unawaited(
      _persistState(),
    );

    unawaited(
      flush(),
    );
  }

  // ==========================================================================
  // CAPTURE CURRENT SESSION
  // ==========================================================================

  void _captureCurrentSession() {
    if (!_isPlaying ||
        _sessionStartedAt == null) {
      return;
    }

    final now =
        DateTime.now().toUtc();

    final elapsed =
        now.difference(
      _sessionStartedAt!,
    );

    final seconds =
        elapsed.inSeconds;

    if (seconds > 0) {
      _pendingStudySeconds +=
          seconds;
    }

    _sessionStartedAt = now;

    unawaited(
      _persistState(),
    );
  }

  // ==========================================================================
  // FLUSH TIMER
  // ==========================================================================

  void _startFlushTimer() {
    _flushTimer?.cancel();

    _flushTimer =
        Timer.periodic(
      const Duration(
        seconds: 30,
      ),
      (_) {
        if (!_isPlaying) {
          return;
        }

        _captureCurrentSession();

        unawaited(
          flush(),
        );
      },
    );
  }

  // ==========================================================================
  // ENSURE LOCAL STATE LOADED
  // ==========================================================================

  Future<void> _ensureLoaded() {
    if (_stateLoaded) {
      return Future<void>.value();
    }

    _loadFuture ??=
        _loadPersistedState();

    return _loadFuture!;
  }

  // ==========================================================================
  // LOAD LOCAL STATE
  // ==========================================================================

  Future<void> _loadPersistedState() async {
    try {
      final prefs =
          await SharedPreferences
              .getInstance();

      _pendingStudySeconds =
          prefs.getInt(
                _studySecondsKey,
              ) ??
              0;

      _pendingLecturesOpened =
          prefs.getInt(
                _lecturesOpenedKey,
              ) ??
              0;

      _pendingAudioCompleted =
          prefs.getInt(
                _audioCompletedKey,
              ) ??
              0;

      _pendingVideoCompleted =
          prefs.getInt(
                _videoCompletedKey,
              ) ??
              0;

      final wasPlaying =
          prefs.getBool(
                _isPlayingKey,
              ) ??
              false;

      final sessionStartedValue =
          prefs.getInt(
        _sessionStartedKey,
      );

      DateTime? savedStart;

      if (sessionStartedValue !=
          null) {
        savedStart =
            DateTime.fromMillisecondsSinceEpoch(
          sessionStartedValue,
          isUtc:
              true,
        );
      }

      // -----------------------------------------------------------------------
      // RECOVER A SESSION THAT WAS ACTIVE
      // WHEN THE PROCESS DIED.
      // -----------------------------------------------------------------------

      if (wasPlaying &&
          savedStart != null) {
        final now =
            DateTime.now().toUtc();

        final elapsed =
            now.difference(
          savedStart,
        );

        final recoveredSeconds =
            elapsed.inSeconds;

        if (recoveredSeconds > 0) {
          _pendingStudySeconds +=
              recoveredSeconds;
        }
      }

      // We never automatically resume
      // playback itself. We only recover
      // the study time that had already
      // happened before the process died.

      _isPlaying = false;
      _sessionStartedAt = null;

      _stateLoaded = true;

      await _persistState();
    } catch (e) {
      debugPrint(
        'Study tracker local state load error: $e',
      );

      _stateLoaded = true;
    }
  }

  // ==========================================================================
  // PERSIST LOCAL STATE
  // ==========================================================================

  Future<void> _persistState() async {
    try {
      final prefs =
          await SharedPreferences
              .getInstance();

      await prefs.setInt(
        _studySecondsKey,
        _pendingStudySeconds,
      );

      await prefs.setInt(
        _lecturesOpenedKey,
        _pendingLecturesOpened,
      );

      await prefs.setInt(
        _audioCompletedKey,
        _pendingAudioCompleted,
      );

      await prefs.setInt(
        _videoCompletedKey,
        _pendingVideoCompleted,
      );

      await prefs.setBool(
        _isPlayingKey,
        _isPlaying,
      );

      final startedAt =
          _sessionStartedAt;

      if (startedAt == null) {
        await prefs.remove(
          _sessionStartedKey,
        );
      } else {
        await prefs.setInt(
          _sessionStartedKey,
          startedAt
              .millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      debugPrint(
        'Study tracker local state save error: $e',
      );
    }
  }

  // ==========================================================================
  // FLUSH TO SUPABASE
  // ==========================================================================

  Future<void> flush() async {
    await _ensureLoaded();

    if (_isFlushing) {
      return;
    }

    if (_pendingStudySeconds <=
            0 &&
        _pendingLecturesOpened <=
            0 &&
        _pendingAudioCompleted <=
            0 &&
        _pendingVideoCompleted <=
            0) {
      return;
    }

    _isFlushing = true;

    final studySeconds =
        _pendingStudySeconds;

    final lecturesOpened =
        _pendingLecturesOpened;

    final audioCompleted =
        _pendingAudioCompleted;

    final videoCompleted =
        _pendingVideoCompleted;

    try {
      await StudentProfileService
          .instance
          .recordStudyActivity(
        seconds:
            studySeconds,
        lecturesOpened:
            lecturesOpened,
        audioCompleted:
            audioCompleted,
        videoCompleted:
            videoCompleted,
      );

      _pendingStudySeconds -=
          studySeconds;

      _pendingLecturesOpened -=
          lecturesOpened;

      _pendingAudioCompleted -=
          audioCompleted;

      _pendingVideoCompleted -=
          videoCompleted;

      if (_pendingStudySeconds <
          0) {
        _pendingStudySeconds =
            0;
      }

      if (_pendingLecturesOpened <
          0) {
        _pendingLecturesOpened =
            0;
      }

      if (_pendingAudioCompleted <
          0) {
        _pendingAudioCompleted =
            0;
      }

      if (_pendingVideoCompleted <
          0) {
        _pendingVideoCompleted =
            0;
      }

      await _persistState();
    } catch (e) {
      // Do not clear the counters.
      // They remain locally persisted
      // and will be retried later.
      debugPrint(
        'Study activity flush error: $e',
      );
    } finally {
      _isFlushing = false;
    }
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  Future<void> dispose() async {
    await stop();
  }
}