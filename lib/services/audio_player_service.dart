import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'lecture_progress_service.dart';
import 'study_activity_tracker.dart';

class AudioPlayerService {
  AudioPlayerService._();

  static final AudioPlayerService instance =
      AudioPlayerService._();

  AudioHandler? _handler;

  bool _initialized = false;

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _handler = await AudioService.init(
      builder: () =>
          _LectureAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.medidata.dataapp.audio',
        androidNotificationChannelName:
            'Lecture Audio',
        androidNotificationChannelDescription:
            'Lecture audio playback',
        androidStopForegroundOnPause:
            false,
        fastForwardInterval:
            Duration(
          seconds: 15,
        ),
        rewindInterval:
            Duration(
          seconds: 15,
        ),
      ),
    );

    _initialized = true;
  }

  // ===========================================================================
  // HANDLER
  // ===========================================================================

  _LectureAudioHandler get _audioHandler {
    final handler = _handler;

    if (handler == null) {
      throw StateError(
        'AudioPlayerService has not been initialized.',
      );
    }

    return handler
        as _LectureAudioHandler;
  }

  // ===========================================================================
  // STREAMS
  // ===========================================================================

  Stream<Duration>
      get positionStream =>
          _audioHandler.positionStream;

  Stream<Duration?>
      get durationStream =>
          _audioHandler.durationStream;

  Stream<bool>
      get playingStream =>
          _audioHandler.playingStream;

  Stream<ProcessingState>
      get processingStateStream =>
          _audioHandler
              .processingStateStream;

  // ===========================================================================
  // CURRENT STATE
  // ===========================================================================

  Duration get position =>
      _audioHandler.position;

  Duration? get duration =>
      _audioHandler.duration;

  bool get isPlaying =>
      _audioHandler.playing;

  double get speed =>
      _audioHandler.speed;

  MediaItem? get currentMediaItem =>
      _audioHandler
          .mediaItem
          .valueOrNull;

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<void> load({
    required String source,
    required String lectureId,
    required String title,
    required String lectureTitle,
    required bool isLocalFile,
    String? artUri,
  }) async {
    await initialize();

    await _audioHandler.loadLecture(
      source:
          source,
      lectureId:
          lectureId,
      title:
          title,
      lectureTitle:
          lectureTitle,
      isLocalFile:
          isLocalFile,
      artUri:
          artUri,
    );
  }

  // ===========================================================================
  // PLAY
  // ===========================================================================

  Future<void> play() async {
    await initialize();

    await _audioHandler.play();
  }

  // ===========================================================================
  // PAUSE
  // ===========================================================================

  Future<void> pause() async {
    await initialize();

    await _audioHandler.pause();
  }

  // ===========================================================================
  // STOP
  // ===========================================================================

  Future<void> stop() async {
    await initialize();

    await _audioHandler.stop();
  }

  // ===========================================================================
  // SEEK
  // ===========================================================================

  Future<void> seek(
    Duration position,
  ) async {
    await initialize();

    await _audioHandler.seek(
      position,
    );
  }

  // ===========================================================================
  // FORWARD
  // ===========================================================================

  Future<void> skipForward({
    Duration amount =
        const Duration(
      seconds: 15,
    ),
  }) async {
    await initialize();

    await _audioHandler
        .skipForward(
      amount,
    );
  }

  // ===========================================================================
  // BACKWARD
  // ===========================================================================

  Future<void> skipBackward({
    Duration amount =
        const Duration(
      seconds: 15,
    ),
  }) async {
    await initialize();

    await _audioHandler
        .skipBackward(
      amount,
    );
  }

  // ===========================================================================
  // SPEED
  // ===========================================================================

  Future<void> setSpeed(
    double speed,
  ) async {
    await initialize();

    await _audioHandler.setSpeed(
      speed,
    );
  }

  // ===========================================================================
  // VOLUME
  // ===========================================================================

  Future<void> setVolume(
    double volume,
  ) async {
    await initialize();

    await _audioHandler.setVolume(
      volume.clamp(
        0.0,
        1.0,
      ),
    );
  }
}

// ============================================================================
// AUDIO HANDLER
// ============================================================================

class _LectureAudioHandler
    extends BaseAudioHandler
    with SeekHandler {
  final AudioPlayer _player =
      AudioPlayer();

  final LectureProgressService
      _progressService =
      LectureProgressService.instance;

  final StudyActivityTracker
      _studyTracker =
      StudyActivityTracker
          .instance;

  StreamSubscription<
          PlaybackEvent>?
      _playbackEventSubscription;

  StreamSubscription<
          SequenceState?>?
      _sequenceSubscription;

  StreamSubscription<
          Duration>?
      _positionSubscription;

  StreamSubscription<
          AudioInterruptionEvent>?
      _interruptionSubscription;

  StreamSubscription<void>?
      _becomingNoisySubscription;

  StreamSubscription<
          PlayerState>?
      _playerStateSubscription;

  Timer? _saveTimer;

  String? _lectureId;

  bool _savingProgress = false;

  bool _studySessionOpened =
      false;

  // ===========================================================================
  // CONSTRUCTOR
  // ===========================================================================

  _LectureAudioHandler() {
    _initialize();
  }

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  Stream<Duration>
      get positionStream =>
          _player.positionStream;

  Stream<Duration?>
      get durationStream =>
          _player.durationStream;

  Stream<bool>
      get playingStream =>
          _player.playingStream;

  Stream<ProcessingState>
      get processingStateStream =>
          _player
              .processingStateStream;

  Duration get position =>
      _player.position;

  Duration? get duration =>
      _player.duration;

  bool get playing =>
      _player.playing;

  double get speed =>
      _player.speed;

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<void> _initialize() async {
    _playbackEventSubscription =
        _player
            .playbackEventStream
            .listen(
      _broadcastState,
    );

    _sequenceSubscription =
        _player
            .sequenceStateStream
            .listen(
      (_) {
        _broadcastMediaItem();
      },
    );

    _positionSubscription =
        _player
            .positionStream
            .listen(
      (_) {
        _broadcastState(
          _player
              .playbackEvent,
        );
      },
    );

    _playerStateSubscription =
        _player
            .playerStateStream
            .listen(
      _handlePlayerState,
    );

    final session =
        await AudioSession
            .instance;

    await session.configure(
      const AudioSessionConfiguration
          .speech(),
    );

    _becomingNoisySubscription =
        session
            .becomingNoisyEventStream
            .listen(
      (_) async {
        await _player.pause();

        await _studyTracker
            .pause();

        await _saveProgress();
      },
    );

    _interruptionSubscription =
        session
            .interruptionEventStream
            .listen(
      _handleInterruption,
    );
  }

  // ===========================================================================
  // PLAYER STATE
  // ===========================================================================

  Future<void> _handlePlayerState(
    PlayerState state,
  ) async {
    if (state.processingState ==
        ProcessingState.completed) {
      await _studyTracker.stop();

      await _saveProgress();

      await _markCompleted();

      _studyTracker
          .markAudioCompleted();
    }
  }

  // ===========================================================================
  // AUDIO INTERRUPTION
  // ===========================================================================

  Future<void> _handleInterruption(
    AudioInterruptionEvent event,
  ) async {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType
            .duck:
          await _player.setVolume(
            0.25,
          );
          break;

        case AudioInterruptionType
            .pause:
        case AudioInterruptionType
            .unknown:
          await _studyTracker
              .pause();

          await _saveProgress();

          if (_player.playing) {
            await _player.pause();
          }

          break;
      }

      return;
    }

    if (event.type ==
        AudioInterruptionType
            .duck) {
      await _player.setVolume(
        1.0,
      );
    }
  }

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<void> loadLecture({
    required String source,
    required String lectureId,
    required String title,
    required String lectureTitle,
    required bool isLocalFile,
    String? artUri,
  }) async {
    // -------------------------------------------------------------------------
    // Save previous lecture before replacing it.
    // -------------------------------------------------------------------------

    await _studyTracker.stop();

    await _saveProgress();

    _saveTimer?.cancel();

    _lectureId =
        lectureId;

    _studySessionOpened =
        false;

    // -------------------------------------------------------------------------
    // MEDIA ITEM
    // -------------------------------------------------------------------------

    final mediaItem =
        MediaItem(
      id:
          lectureId,
      title:
          title,
      album:
          lectureTitle,
      artUri:
          artUri == null
              ? null
              : Uri.tryParse(
                  artUri,
                ),
    );

    this.mediaItem.add(
      mediaItem,
    );

    // -------------------------------------------------------------------------
    // AUDIO SOURCE
    // -------------------------------------------------------------------------

    final AudioSource audioSource;

    if (isLocalFile) {
      audioSource =
          AudioSource.file(
        source,
        tag:
            mediaItem,
      );
    } else {
      audioSource =
          AudioSource.uri(
        Uri.parse(
          source,
        ),
        tag:
            mediaItem,
      );
    }

    await _player.setAudioSource(
      audioSource,
    );

    // -------------------------------------------------------------------------
    // LOAD SAVED PROGRESS
    // -------------------------------------------------------------------------

    final progress =
        await _progressService
            .getProgress(
      lectureId,
    );

    if (!progress.audioCompleted &&
        progress.audioPosition > 0) {
      final savedPosition =
          Duration(
        seconds:
            progress
                .audioPosition,
      );

      final duration =
          _player.duration;

      if (duration != null &&
          savedPosition >=
              duration) {
        await _player.seek(
          duration,
        );
      } else {
        await _player.seek(
          savedPosition,
        );
      }
    }

    _startAutoSave();

    _broadcastMediaItem();

    _broadcastState(
      _player.playbackEvent,
    );
  }

  // ===========================================================================
  // AUTO SAVE
  // ===========================================================================

  void _startAutoSave() {
    _saveTimer?.cancel();

    _saveTimer =
        Timer.periodic(
      const Duration(
        seconds: 5,
      ),
      (_) {
        unawaited(
          _saveProgress(),
        );
      },
    );
  }

  // ===========================================================================
  // SAVE PROGRESS
  // ===========================================================================

  Future<void> _saveProgress() async {
    final lectureId =
        _lectureId;

    if (lectureId == null ||
        _savingProgress) {
      return;
    }

    if (_player.processingState ==
        ProcessingState.idle) {
      return;
    }

    _savingProgress =
        true;

    try {
      await _progressService
          .saveAudioPosition(
        lectureId:
            lectureId,
        positionSeconds:
            _player.position
                .inSeconds,
      );
    } catch (_) {
      // Never interrupt playback
      // because saving progress failed.
    } finally {
      _savingProgress =
          false;
    }
  }

  // ===========================================================================
  // COMPLETED
  // ===========================================================================

  Future<void> _markCompleted() async {
    final lectureId =
        _lectureId;

    if (lectureId == null) {
      return;
    }

    try {
      await _progressService
          .markAudioCompleted(
        lectureId,
      );
    } catch (_) {
      // Completion tracking failure
      // should not stop playback.
    }
  }

  // ===========================================================================
  // PLAY
  // ===========================================================================

  @override
  Future<void> play() async {
    await _player.play();

    if (!_studySessionOpened) {
      _studySessionOpened =
          true;

      _studyTracker.start(
        lectureOpened:
            true,
      );
    } else {
      _studyTracker.start();
    }
  }

  // ===========================================================================
  // PAUSE
  // ===========================================================================

  @override
  Future<void> pause() async {
    await _player.pause();

    await _studyTracker.pause();

    await _saveProgress();
  }

  // ===========================================================================
  // STOP
  // ===========================================================================

  @override
  Future<void> stop() async {
    await _studyTracker.stop();

    await _saveProgress();

    await _player.stop();

    await _player.seek(
      Duration.zero,
    );

    _saveTimer?.cancel();

    _studySessionOpened =
        false;

    await super.stop();
  }

  // ===========================================================================
  // SEEK
  // ===========================================================================

  @override
  Future<void> seek(
    Duration position,
  ) async {
    await _player.seek(
      position,
    );

    unawaited(
      _saveProgress(),
    );
  }

  // ===========================================================================
  // FORWARD
  // ===========================================================================

  Future<void> skipForward(
    Duration amount,
  ) async {
    final current =
        _player.position;

    final target =
        current + amount;

    final duration =
        _player.duration;

    if (duration != null &&
        target >= duration) {
      await _player.seek(
        duration,
      );
    } else {
      await _player.seek(
        target,
      );
    }

    unawaited(
      _saveProgress(),
    );
  }

  // ===========================================================================
  // BACKWARD
  // ===========================================================================

  Future<void> skipBackward(
    Duration amount,
  ) async {
    final current =
        _player.position;

    final target =
        current - amount;

    await _player.seek(
      target <= Duration.zero
          ? Duration.zero
          : target,
    );

    unawaited(
      _saveProgress(),
    );
  }

  // ===========================================================================
  // SPEED
  // ===========================================================================

  @override
  Future<void> setSpeed(
    double speed,
  ) async {
    await _player.setSpeed(
      speed,
    );
  }

  // ===========================================================================
  // VOLUME
  // ===========================================================================

  Future<void> setVolume(
    double volume,
  ) async {
    await _player.setVolume(
      volume.clamp(
        0.0,
        1.0,
      ),
    );
  }

  // ===========================================================================
  // MEDIA ITEM
  // ===========================================================================

  void _broadcastMediaItem() {
    final sequence =
        _player.sequenceState
            .effectiveSequence;

    if (sequence.isEmpty) {
      return;
    }

    final currentIndex =
        _player.currentIndex;

    if (currentIndex ==
            null ||
        currentIndex < 0 ||
        currentIndex >=
            sequence.length) {
      return;
    }

    final source =
        sequence[currentIndex];

    final tag =
        source.tag;

    if (tag is MediaItem) {
      mediaItem.add(tag);
    }
  }

  // ===========================================================================
  // PLAYBACK STATE
  // ===========================================================================

  void _broadcastState(
    PlaybackEvent event,
  ) {
    final processingState =
        switch (
            _player
                .processingState) {
      ProcessingState.idle =>
        AudioProcessingState.idle,
      ProcessingState.loading =>
        AudioProcessingState
            .loading,
      ProcessingState.buffering =>
        AudioProcessingState
            .buffering,
      ProcessingState.ready =>
        AudioProcessingState
            .ready,
      ProcessingState.completed =>
        AudioProcessingState
            .completed,
    };

    playbackState.add(
      PlaybackState(
        controls: const [
          MediaControl.rewind,
          MediaControl.play,
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions:
            const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setSpeed,
        },
        androidCompactActionIndices:
            const [
          0,
          1,
          2,
        ],
        processingState:
            processingState,
        playing:
            _player.playing,
        updatePosition:
            _player.position,
        bufferedPosition:
            _player
                .bufferedPosition,
        speed:
            _player.speed,
        queueIndex:
            event.currentIndex,
      ),
    );
  }

  // ===========================================================================
  // SYSTEM CONTROLS
  // ===========================================================================

  @override
  Future<void> fastForward() async {
    await skipForward(
      const Duration(
        seconds: 15,
      ),
    );
  }

  @override
  Future<void> rewind() async {
    await skipBackward(
      const Duration(
        seconds: 15,
      ),
    );
  }

  // ===========================================================================
  // TASK REMOVED
  // ===========================================================================

  @override
  Future<void> onTaskRemoved() async {
    await _studyTracker.stop();

    await _saveProgress();
  }

  // ===========================================================================
  // NOTIFICATION DELETED
  // ===========================================================================

  @override
  Future<void>
      onNotificationDeleted() async {
    await _studyTracker.stop();

    await _saveProgress();
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  Future<void> disposeHandler() async {
    await _studyTracker.stop();

    _saveTimer?.cancel();

    await _playbackEventSubscription
        ?.cancel();

    await _sequenceSubscription
        ?.cancel();

    await _positionSubscription
        ?.cancel();

    await _interruptionSubscription
        ?.cancel();

    await _becomingNoisySubscription
        ?.cancel();

    await _playerStateSubscription
        ?.cancel();

    await _player.dispose();
  }
}