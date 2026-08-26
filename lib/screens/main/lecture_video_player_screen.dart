import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/responsive/responsive.dart';
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

  final StudyActivityTracker _studyTracker = StudyActivityTracker.instance;

  Timer? _saveTimer;

  bool _loading = true;
  bool _initializing = false;
  bool _showControls = true;
  bool _fullscreen = false;
  bool _completed = false;

  double _playbackSpeed = 1.0;

  String? _error;

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeVideo();
  }

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_handleAppBackground());
    }

    if (state == AppLifecycleState.resumed) {
      _resumeStudyTrackingIfPlaying();

      if (_controller != null && _controller!.value.isInitialized) {
        unawaited(_saveProgress());
      }
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

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

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

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  // ==========================================================================
  // INITIALIZE
  // ==========================================================================

  Future<void> _initializeVideo() async {
    if (_initializing) {
      return;
    }

    _initializing = true;

    try {
      final downloaded = await DownloadsService.instance.findById(
        widget.fileId,
      );

      late final VideoPlayerController controller;

      // -----------------------------------------------------------------------
      // LOCAL FILE
      // -----------------------------------------------------------------------

      if (downloaded != null) {
        final localFile = File(downloaded.localPath);

        if (await localFile.exists()) {
          controller = VideoPlayerController.file(
            localFile,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          );
        } else {
          final signedUrl = await DownloadsService.instance
              .createSignedUrlForLectureFile(
                fileUrl: widget.fileUrl,
                fileType: 'video',
              );

          controller = VideoPlayerController.networkUrl(
            Uri.parse(signedUrl),
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
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
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      }

      _controller = controller;

      await controller.initialize();

      await controller.setVolume(1.0);

      // -----------------------------------------------------------------------
      // RESUME VIDEO PROGRESS
      // -----------------------------------------------------------------------

      final progress = await _progressService.getProgress(widget.lectureId);

      if (!progress.videoCompleted && progress.videoPosition > 0) {
        final savedPosition = Duration(seconds: progress.videoPosition);

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

  // ==========================================================================
  // VIDEO LISTENER
  // ==========================================================================

  void _videoListener() {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
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

  // ==========================================================================
  // VIDEO COMPLETED
  // ==========================================================================

  Future<void> _handleVideoCompleted() async {
    try {
      await _saveProgress();

      await _progressService.markVideoCompleted(widget.lectureId);

      _studyTracker.markVideoCompleted();

      await _studyTracker.flush();
    } catch (e) {
      debugPrint('Video completion error: $e');
    }
  }

  // ==========================================================================
  // AUTO SAVE
  // ==========================================================================

  void _startAutoSave() {
    _saveTimer?.cancel();

    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_saveProgress());
    });
  }

  Future<void> _saveProgress() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      await _progressService.saveVideoPosition(
        lectureId: widget.lectureId,
        positionSeconds: controller.value.position.inSeconds,
      );
    } catch (e) {
      debugPrint('Video progress save error: $e');
    }
  }

  // ==========================================================================
  // PLAY / PAUSE
  // ==========================================================================

  Future<void> _togglePlayback() async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
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

  // ==========================================================================
  // SEEK
  // ==========================================================================

  Future<void> _seekRelative(Duration offset) async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
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

  // ==========================================================================
  // SPEED
  // ==========================================================================

  Future<void> _setSpeed(double speed) async {
    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
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

  // ==========================================================================
  // FULLSCREEN
  // ==========================================================================

  Future<void> _toggleFullscreen() async {
    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      if (mounted) {
        setState(() {
          _fullscreen = false;
          _showControls = true;
        });
      }

      return;
    }

    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (mounted) {
      setState(() {
        _fullscreen = true;
        _showControls = true;
      });
    }
  }

  // ==========================================================================
  // FORMAT
  // ==========================================================================

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;

    final minutes = duration.inMinutes.remainder(60);

    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(context)
          : controller == null
          ? _buildError(context)
          : _buildVideo(context, controller),
    );
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.cardPadding(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: Responsive.clamped(context, base: 64, min: 52, max: 82),
                color: Colors.white,
              ),

              SizedBox(
                height: Responsive.spacing(context, base: 16, min: 10, max: 22),
              ),

              Text(
                _error ?? 'Unable to play this video.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Responsive.bodyTextSize(
                    context,
                    base: 15,
                    min: 13,
                    max: 19,
                  ),
                  height: 1.4,
                ),
              ),

              SizedBox(
                height: Responsive.spacing(context, base: 18, min: 12, max: 24),
              ),

              SizedBox(
                height: Responsive.buttonHeight(context),
                child: FilledButton.icon(
                  onPressed: _initializeVideo,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ),

              if (theme.brightness == Brightness.dark)
                const SizedBox(height: 1),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // VIDEO
  // ==========================================================================

  Widget _buildVideo(BuildContext context, VideoPlayerController controller) {
    final value = controller.value;

    if (!value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!mounted) {
          return;
        }

        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ===================================================================
          // VIDEO
          // ===================================================================
          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),

          // ===================================================================
          // CONTROLS
          // ===================================================================
          if (_showControls) _buildControls(context, controller),
        ],
      ),
    );
  }

  // ==========================================================================
  // CONTROLS
  // ==========================================================================

  Widget _buildControls(
    BuildContext context,
    VideoPlayerController controller,
  ) {
    final value = controller.value;

    final horizontalPadding = Responsive.spacing(
      context,
      base: 14,
      min: 10,
      max: 26,
    );

    final titleSize = Responsive.bodyTextSize(
      context,
      base: 14,
      min: 12,
      max: 18,
    );

    final skipIconSize = Responsive.iconSize(
      context,
      base: 34,
      min: 29,
      max: 44,
    );

    final playButtonSize = Responsive.clamped(
      context,
      base: 70,
      min: 58,
      max: 88,
    );

    final playIconSize = playButtonSize * 0.58;

    final controlsGap = Responsive.spacing(context, base: 20, min: 12, max: 30);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: _showControls ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent, Colors.black87],
              stops: [0, 0.45, 1],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // =============================================================
                // TOP BAR
                // =============================================================
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    children: [
                      if (_fullscreen)
                        IconButton(
                          onPressed: _toggleFullscreen,
                          color: Colors.white,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),

                      Expanded(
                        child: Text(
                          widget.fileTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      PopupMenuButton<double>(
                        tooltip: 'Playback speed',
                        icon: Icon(
                          Icons.speed_rounded,
                          color: Colors.white,
                          size: Responsive.iconSize(
                            context,
                            base: 23,
                            min: 20,
                            max: 29,
                          ),
                        ),
                        initialValue: _playbackSpeed,
                        onSelected: _setSpeed,
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 0.75, child: Text('0.75x')),
                          PopupMenuItem(value: 1.0, child: Text('1.0x')),
                          PopupMenuItem(value: 1.25, child: Text('1.25x')),
                          PopupMenuItem(value: 1.5, child: Text('1.5x')),
                          PopupMenuItem(value: 1.75, child: Text('1.75x')),
                          PopupMenuItem(value: 2.0, child: Text('2.0x')),
                        ],
                      ),

                      IconButton(
                        onPressed: _toggleFullscreen,
                        color: Colors.white,
                        icon: Icon(
                          _fullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          size: Responsive.iconSize(
                            context,
                            base: 24,
                            min: 21,
                            max: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // =============================================================
                // CENTER CONTROLS
                // =============================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        unawaited(_seekRelative(const Duration(seconds: -15)));
                      },
                      color: Colors.white,
                      tooltip: 'Rewind 15 seconds',
                      icon: Icon(Icons.replay_10_rounded, size: skipIconSize),
                    ),

                    SizedBox(width: controlsGap),

                    Container(
                      width: playButtonSize,
                      height: playButtonSize,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: _togglePlayback,
                        color: Colors.white,
                        icon: Icon(
                          value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: playIconSize,
                        ),
                      ),
                    ),

                    SizedBox(width: controlsGap),

                    IconButton(
                      onPressed: () {
                        unawaited(_seekRelative(const Duration(seconds: 15)));
                      },
                      color: Colors.white,
                      tooltip: 'Forward 15 seconds',
                      icon: Icon(Icons.forward_10_rounded, size: skipIconSize),
                    ),
                  ],
                ),

                const Spacer(),

                // =============================================================
                // BOTTOM PROGRESS
                // =============================================================
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(value.position),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.smallTextSize(
                            context,
                            base: 12,
                            min: 10,
                            max: 14,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      SizedBox(
                        width: Responsive.spacing(
                          context,
                          base: 6,
                          min: 4,
                          max: 9,
                        ),
                      ),

                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbColor: Colors.white,
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white30,
                            overlayColor: Colors.white12,
                            trackHeight: Responsive.clamped(
                              context,
                              base: 3,
                              min: 2,
                              max: 5,
                            ),
                            thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: Responsive.clamped(
                                context,
                                base: 6,
                                min: 5,
                                max: 8,
                              ),
                            ),
                            overlayShape: RoundSliderOverlayShape(
                              overlayRadius: Responsive.clamped(
                                context,
                                base: 14,
                                min: 11,
                                max: 18,
                              ),
                            ),
                          ),
                          child: Slider(
                            min: 0,
                            max: value.duration.inMilliseconds.toDouble() > 0
                                ? value.duration.inMilliseconds.toDouble()
                                : 1,
                            value: value.position.inMilliseconds
                                .clamp(
                                  0,
                                  value.duration.inMilliseconds > 0
                                      ? value.duration.inMilliseconds
                                      : 0,
                                )
                                .toDouble(),
                            onChanged: value.duration > Duration.zero
                                ? (position) {
                                    unawaited(
                                      controller.seekTo(
                                        Duration(
                                          milliseconds: position.round(),
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ),
                      ),

                      SizedBox(
                        width: Responsive.spacing(
                          context,
                          base: 6,
                          min: 4,
                          max: 9,
                        ),
                      ),

                      Text(
                        _formatDuration(value.duration),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.smallTextSize(
                            context,
                            base: 12,
                            min: 10,
                            max: 14,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
