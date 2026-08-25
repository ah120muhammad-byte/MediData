import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../services/download_service.dart';
import '../../services/lecture_progress_service.dart';
import '../../services/study_activity_tracker.dart';

class LectureVideoPlayerScreen extends StatefulWidget {
  final String lectureId;
  final String lectureTitle;

  final String fileId;
  final String fileTitle;
  final String fileUrl;

  const LectureVideoPlayerScreen({
    super.key,
    required this.lectureId,
    required this.lectureTitle,
    required this.fileId,
    required this.fileTitle,
    required this.fileUrl,
  });

  @override
  State<LectureVideoPlayerScreen> createState() =>
      _LectureVideoPlayerScreenState();
}

class _LectureVideoPlayerScreenState extends State<LectureVideoPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;

  final LectureProgressService _progressService =
      LectureProgressService.instance;

  final StudyActivityTracker _studyTracker =
      StudyActivityTracker.instance;

  Timer? _saveTimer;

  bool _loading = true;
  bool _initializing = false;
  bool _showControls = true;
  bool _fullscreen = false;
  bool _completed = false;

  double _playbackSpeed = 1.0;

  String? _error;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeVideo();
  }

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_handleAppBackground());
    }

    if (state == AppLifecycleState.resumed) {
      _resumeStudyTrackingIfPlaying();
    }
  }

  Future<void> _handleAppBackground() async {
    await _saveProgress();
    await _studyTracker.pause();
  }

  void _resumeStudyTrackingIfPlaying() {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      _studyTracker.start();
    }
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _saveTimer?.cancel();

    unawaited(_saveProgress());
    unawaited(_studyTracker.stop());

    _controller?.removeListener(_videoListener);
    _controller?.dispose();

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    super.dispose();
  }

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<void> _initializeVideo() async {
    if (_initializing) {
      return;
    }

    _initializing = true;

    try {
      final downloaded = await DownloadsService.instance.findById(
        widget.fileId,
      );

      VideoPlayerController controller;

      // -----------------------------------------------------------------------
      // LOCAL FILE
      // -----------------------------------------------------------------------

      if (downloaded != null) {
        final localFile = File(downloaded.localPath);

        if (await localFile.exists()) {
          controller = VideoPlayerController.file(
            localFile,
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
            ),
          );
        } else {
          final signedUrl = await DownloadsService.instance
              .createSignedUrlForLectureFile(
            fileUrl: widget.fileUrl,
            fileType: 'video',
          );

          controller = VideoPlayerController.networkUrl(
            Uri.parse(signedUrl),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
            ),
          );
        }
      }

      // -----------------------------------------------------------------------
      // ONLINE
      // -----------------------------------------------------------------------

      else {
        final signedUrl = await DownloadsService.instance
            .createSignedUrlForLectureFile(
          fileUrl: widget.fileUrl,
          fileType: 'video',
        );

        controller = VideoPlayerController.networkUrl(
          Uri.parse(signedUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
          ),
        );
      }

      _controller = controller;

      await controller.initialize();

      await controller.setVolume(1.0);

      // -----------------------------------------------------------------------
      // RESUME VIDEO PROGRESS
      // -----------------------------------------------------------------------

      final progress = await _progressService.getProgress(
        widget.lectureId,
      );

      if (!progress.videoCompleted &&
          progress.videoPosition > 0) {
        final savedPosition = Duration(
          seconds: progress.videoPosition,
        );

        final duration = controller.value.duration;

        if (savedPosition >= duration) {
          await controller.seekTo(duration);
        } else {
          await controller.seekTo(savedPosition);
        }
      }

      controller.addListener(_videoListener);

      _startAutoSave();

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = null;
      });

      // -----------------------------------------------------------------------
      // START VIDEO
      // -----------------------------------------------------------------------

      await controller.play();

      // Start real study-time tracking.
      _studyTracker.start();
    } catch (e) {
      debugPrint('Video player error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to play this video.';
      });
    } finally {
      _initializing = false;
    }
  }

  // ===========================================================================
  // VIDEO LISTENER
  // ===========================================================================

  void _videoListener() {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final value = controller.value;

    if (value.position >= value.duration &&
        value.duration > Duration.zero &&
        !_completed) {
      _completed = true;

      unawaited(_handleVideoCompleted());
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ===========================================================================
  // VIDEO COMPLETED
  // ===========================================================================

  Future<void> _handleVideoCompleted() async {
    try {
      await _saveProgress();

      await _progressService.markVideoCompleted(
        widget.lectureId,
      );

      _studyTracker.markVideoCompleted();

      await _studyTracker.flush();
    } catch (e) {
      debugPrint(
        'Video completion error: $e',
      );
    }
  }

  // ===========================================================================
  // AUTO SAVE
  // ===========================================================================

  void _startAutoSave() {
    _saveTimer?.cancel();

    _saveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        unawaited(_saveProgress());
      },
    );
  }

  Future<void> _saveProgress() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    try {
      await _progressService.saveVideoPosition(
        lectureId: widget.lectureId,
        positionSeconds:
            controller.value.position.inSeconds,
      );
    } catch (e) {
      debugPrint(
        'Video progress save error: $e',
      );
    }
  }

  // ===========================================================================
  // PLAY / PAUSE
  // ===========================================================================

  Future<void> _togglePlayback() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      await _studyTracker.pause();
    } else {
      await controller.play();

      _studyTracker.start();
    }

    if (mounted) {
      setState(() {
        _showControls = true;
      });
    }
  }

  // ===========================================================================
  // SEEK
  // ===========================================================================

  Future<void> _seekRelative(
    Duration offset,
  ) async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    final current = controller.value.position;

    final duration = controller.value.duration;

    var target = current + offset;

    if (target < Duration.zero) {
      target = Duration.zero;
    }

    if (target > duration) {
      target = duration;
    }

    await controller.seekTo(target);

    await _saveProgress();
  }

  // ===========================================================================
  // SPEED
  // ===========================================================================

  Future<void> _setSpeed(
    double speed,
  ) async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    await controller.setPlaybackSpeed(speed);

    if (!mounted) {
      return;
    }

    setState(() {
      _playbackSpeed = speed;
    });
  }

  // ===========================================================================
  // FULLSCREEN
  // ===========================================================================

  Future<void> _toggleFullscreen() async {
    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations(
        const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
      );

      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );

      if (mounted) {
        setState(() {
          _fullscreen = false;
        });
      }

      return;
    }

    await SystemChrome.setPreferredOrientations(
      const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    if (mounted) {
      setState(() {
        _fullscreen = true;
      });
    }
  }

  // ===========================================================================
  // FORMAT
  // ===========================================================================

  String _formatDuration(
    Duration duration,
  ) {
    final hours = duration.inHours;

    final minutes =
        duration.inMinutes.remainder(60);

    final seconds =
        duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen
          ? null
          : AppBar(
              title: Text(
                widget.lectureTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? _buildError()
              : controller == null
                  ? _buildError()
                  : _buildVideo(controller),
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              _error ??
                  'Unable to play this video.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _initializeVideo,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VIDEO
  // ===========================================================================

  Widget _buildVideo(
    VideoPlayerController controller,
  ) {
    final value = controller.value;

    if (!value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // -------------------------------------------------------------------
          // VIDEO
          // -------------------------------------------------------------------

          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio > 0
                  ? value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),

          // -------------------------------------------------------------------
          // CONTROLS
          // -------------------------------------------------------------------

          if (_showControls)
            _buildControls(controller),
        ],
      ),
    );
  }

  // ===========================================================================
  // CONTROLS
  // ===========================================================================

  Widget _buildControls(
    VideoPlayerController controller,
  ) {
    final value = controller.value;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.black87,
          ],
          stops: [
            0,
            0.45,
            1,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ===============================================================
            // TOP BAR
            // ===============================================================

            Row(
              children: [
                if (_fullscreen)
                  IconButton(
                    onPressed: _toggleFullscreen,
                    color: Colors.white,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                    ),
                  ),

                Expanded(
                  child: Text(
                    widget.fileTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                PopupMenuButton<double>(
                  tooltip: 'Playback speed',
                  icon: const Icon(
                    Icons.speed_rounded,
                    color: Colors.white,
                  ),
                  initialValue: _playbackSpeed,
                  onSelected: _setSpeed,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 0.75,
                      child: Text('0.75x'),
                    ),
                    PopupMenuItem(
                      value: 1.0,
                      child: Text('1.0x'),
                    ),
                    PopupMenuItem(
                      value: 1.25,
                      child: Text('1.25x'),
                    ),
                    PopupMenuItem(
                      value: 1.5,
                      child: Text('1.5x'),
                    ),
                    PopupMenuItem(
                      value: 1.75,
                      child: Text('1.75x'),
                    ),
                    PopupMenuItem(
                      value: 2.0,
                      child: Text('2.0x'),
                    ),
                  ],
                ),

                IconButton(
                  onPressed: _toggleFullscreen,
                  color: Colors.white,
                  icon: Icon(
                    _fullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ===============================================================
            // CENTER CONTROLS
            // ===============================================================

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    _seekRelative(
                      const Duration(
                        seconds: -15,
                      ),
                    );
                  },
                  color: Colors.white,
                  icon: const Icon(
                    Icons.replay_10_rounded,
                    size: 34,
                  ),
                ),

                const SizedBox(width: 20),

                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _togglePlayback,
                    color: Colors.white,
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 42,
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                IconButton(
                  onPressed: () {
                    _seekRelative(
                      const Duration(
                        seconds: 15,
                      ),
                    );
                  },
                  color: Colors.white,
                  icon: const Icon(
                    Icons.forward_10_rounded,
                    size: 34,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ===============================================================
            // BOTTOM PROGRESS
            // ===============================================================

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              child: Row(
                children: [
                  Text(
                    _formatDuration(
                      value.position,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context)
                          .copyWith(
                        thumbColor: Colors.white,
                        activeTrackColor:
                            Colors.white,
                        inactiveTrackColor:
                            Colors.white30,
                        overlayColor:
                            Colors.white12,
                        trackHeight: 3,
                      ),
                      child: Slider(
                        min: 0,
                        max: value.duration
                                    .inMilliseconds
                                    .toDouble() >
                                0
                            ? value.duration
                                .inMilliseconds
                                .toDouble()
                            : 1,
                        value: value.position
                            .inMilliseconds
                            .clamp(
                              0,
                              value.duration
                                          .inMilliseconds >
                                      0
                                  ? value.duration
                                      .inMilliseconds
                                  : 0,
                            )
                            .toDouble(),
                        onChanged:
                            value.duration >
                                    Duration.zero
                                ? (position) {
                                    controller
                                        .seekTo(
                                      Duration(
                                        milliseconds:
                                            position
                                                .round(),
                                      ),
                                    );
                                  }
                                : null,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Text(
                    _formatDuration(
                      value.duration,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}