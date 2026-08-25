import 'dart:async';
import 'package:flutter/foundation.dart';
import 'student_profile_service.dart';

class StudyActivityTracker {
  StudyActivityTracker._();

  static final StudyActivityTracker instance = StudyActivityTracker._();

  Timer? _flushTimer;

  bool _isPlaying = false;
  bool _isFlushing = false;

  DateTime? _sessionStartedAt;

  int _pendingStudySeconds = 0;
  int _pendingLecturesOpened = 0;
  int _pendingAudioCompleted = 0;
  int _pendingVideoCompleted = 0;

  // ===========================================================================
  // START / RESUME
  // ===========================================================================

  void start({bool lectureOpened = false}) {
    if (lectureOpened) {
      _pendingLecturesOpened++;
    }

    if (_isPlaying) {
      return;
    }

    _isPlaying = true;
    _sessionStartedAt = DateTime.now().toUtc();

    _startFlushTimer();
  }

  // ===========================================================================
  // PAUSE
  // ===========================================================================

  Future<void> pause() async {
    if (!_isPlaying) {
      await flush();
      return;
    }

    _captureCurrentSession();

    _isPlaying = false;
    _sessionStartedAt = null;

    _flushTimer?.cancel();
    _flushTimer = null;

    await flush();
  }

  // ===========================================================================
  // STOP
  // ===========================================================================

  Future<void> stop() async {
    if (_isPlaying) {
      _captureCurrentSession();
    }

    _isPlaying = false;
    _sessionStartedAt = null;

    _flushTimer?.cancel();
    _flushTimer = null;

    await flush();
  }

  // ===========================================================================
  // AUDIO COMPLETED
  // ===========================================================================

  void markAudioCompleted() {
    _pendingAudioCompleted++;

    unawaited(flush());
  }

  // ===========================================================================
  // VIDEO COMPLETED
  // ===========================================================================

  void markVideoCompleted() {
    _pendingVideoCompleted++;

    unawaited(flush());
  }

  // ===========================================================================
  // CAPTURE CURRENT SESSION
  // ===========================================================================

  void _captureCurrentSession() {
    if (!_isPlaying || _sessionStartedAt == null) {
      return;
    }

    final now = DateTime.now().toUtc();

    final elapsed = now.difference(_sessionStartedAt!);

    final seconds = elapsed.inSeconds;

    if (seconds > 0) {
      _pendingStudySeconds += seconds;
    }

    _sessionStartedAt = now;
  }

  // ===========================================================================
  // PERIODIC FLUSH
  // ===========================================================================

  void _startFlushTimer() {
    _flushTimer?.cancel();

    _flushTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!_isPlaying) {
          return;
        }

        _captureCurrentSession();

        unawaited(flush());
      },
    );
  }

  // ===========================================================================
  // FLUSH TO SUPABASE
  // ===========================================================================

  Future<void> flush() async {
    if (_isFlushing) {
      return;
    }

    if (_pendingStudySeconds <= 0 &&
        _pendingLecturesOpened <= 0 &&
        _pendingAudioCompleted <= 0 &&
        _pendingVideoCompleted <= 0) {
      return;
    }

    _isFlushing = true;

    final studySeconds = _pendingStudySeconds;
    final lecturesOpened = _pendingLecturesOpened;
    final audioCompleted = _pendingAudioCompleted;
    final videoCompleted = _pendingVideoCompleted;

    try {
      await StudentProfileService.instance.recordStudyActivity(
        seconds: studySeconds,
        lecturesOpened: lecturesOpened,
        audioCompleted: audioCompleted,
        videoCompleted: videoCompleted,
      );

      _pendingStudySeconds -= studySeconds;
      _pendingLecturesOpened -= lecturesOpened;
      _pendingAudioCompleted -= audioCompleted;
      _pendingVideoCompleted -= videoCompleted;

      // Safety against accidental negative counters.
      if (_pendingStudySeconds < 0) {
        _pendingStudySeconds = 0;
      }

      if (_pendingLecturesOpened < 0) {
        _pendingLecturesOpened = 0;
      }

      if (_pendingAudioCompleted < 0) {
        _pendingAudioCompleted = 0;
      }

      if (_pendingVideoCompleted < 0) {
        _pendingVideoCompleted = 0;
      }
    } catch (e) {
      // Keep pending values in memory.
      //
      // They will be retried by the next flush.
      //
      // Do not rethrow because analytics must never crash
      // the video/audio/PDF experience.
      debugPrint(
        'Study activity flush error: $e',
      );
    } finally {
      _isFlushing = false;
    }
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  Future<void> dispose() async {
    await stop();
  }
}