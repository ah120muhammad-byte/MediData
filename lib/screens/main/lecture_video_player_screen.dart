import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
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
  State<LectureVideoPlayerScreen> createState() => _LectureVideoPlayerScreenState();
}

class _LectureVideoPlayerScreenState extends State<LectureVideoPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  final LectureProgressService _progressService = LectureProgressService.instance;
  final StudyActivityTracker _studyTracker = StudyActivityTracker.instance;

  Timer? _saveTimer;
  Timer? _controlsTimer;

  bool _loading = true;
  bool _initializing = false;
  bool _showControls = true;
  bool _fullscreen = false;
  bool _completed = false;
  bool _muted = false;
  String? _error;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_handleBackground());
    } else if (state == AppLifecycleState.resumed) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        _resumeStudyTracking();
        unawaited(_saveProgress());
      }
    }
  }

  Future<void> _handleBackground() async {
    await _saveProgress();
    await _studyTracker.pause();
  }

  void _resumeStudyTracking() {
    final controller = _controller;
    if (controller != null && controller.value.isPlaying) {
      _studyTracker.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _controlsTimer?.cancel();
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

  Future<void> _initializeVideo() async {
    if (_initializing) return;
    _initializing = true;

    try {
      final downloaded = await DownloadsService.instance.findById(widget.fileId);
      late final VideoPlayerController controller;

      if (downloaded != null) {
        final file = File(downloaded.localPath);
        if (await file.exists()) {
          controller = VideoPlayerController.file(file);
        } else {
          final url = await DownloadsService.instance.createSignedUrlForLectureFile(
            fileUrl: widget.fileUrl,
            fileType: 'video',
          );
          controller = VideoPlayerController.networkUrl(Uri.parse(url));
        }
      } else {
        final url = await DownloadsService.instance.createSignedUrlForLectureFile(
          fileUrl: widget.fileUrl,
          fileType: 'video',
        );
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }

      _controller?.removeListener(_videoListener);
      _controller?.dispose();
      _controller = controller;
      await controller.initialize();

      final progress = await _progressService.getProgress(widget.lectureId);
      if (!progress.videoCompleted && progress.videoPosition > 0) {
        final saved = Duration(seconds: progress.videoPosition);
        final duration = controller.value.duration;
        await controller.seekTo(saved >= duration ? duration : saved);
      }

      controller.addListener(_videoListener);
      _startAutoSave();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });

      await controller.setPlaybackSpeed(_playbackSpeed);
      await controller.play();
      _studyTracker.start();
      _scheduleControlsHide();
    } catch (e) {
      debugPrint('Video player error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to play this video.';
      });
    } finally {
      _initializing = false;
    }
  }

  void _videoListener() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    final value = controller.value;
    if (value.hasError) {
      if (mounted) {
        setState(() => _error = 'Unable to play this video.');
      }
      return;
    }

    if (value.position >= value.duration &&
        value.duration > Duration.zero &&
        !_completed) {
      _completed = true;
      unawaited(_handleCompleted());
    }

    if (mounted) setState(() {});
  }

  Future<void> _handleCompleted() async {
    try {
      await _saveProgress();
      await _progressService.markVideoCompleted(widget.lectureId);
      _studyTracker.markVideoCompleted();
      await _studyTracker.flush();
    } catch (e) {
      debugPrint('Video completion error: $e');
    }
  }

  void _startAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_saveProgress());
    });
  }

  Future<void> _saveProgress() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await _progressService.saveVideoPosition(
        lectureId: widget.lectureId,
        positionSeconds: controller.value.position.inSeconds,
      );
    } catch (e) {
      debugPrint('Video progress save error: $e');
    }
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    if (!_showControls) return;
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      final controller = _controller;
      if (controller != null && controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleControlsHide();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
      await _studyTracker.pause();
    } else {
      await controller.play();
      _studyTracker.start();
    }
    if (mounted) {
      setState(() => _showControls = true);
      _scheduleControlsHide();
    }
  }

  Future<void> _seekRelative(Duration offset) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;
    var target = value.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (target > value.duration) target = value.duration;
    await controller.seekTo(target);
    await _saveProgress();
    if (mounted) setState(() => _showControls = true);
    _scheduleControlsHide();
  }

  Future<void> _setSpeed(double speed) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.setPlaybackSpeed(speed);
    if (!mounted) return;
    setState(() => _playbackSpeed = speed);
    _scheduleControlsHide();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
    _scheduleControlsHide();
  }

  Future<void> _toggleFullscreen() async {
    if (_fullscreen) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    if (!mounted) return;
    setState(() {
      _fullscreen = !_fullscreen;
      _showControls = true;
    });
    _scheduleControlsHide();
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen
          ? null
          : AppBar(
              title: Text(widget.lectureTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || controller == null
              ? _buildError(context)
              : _buildVideo(context, controller),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.cardPadding(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            const Text('Unable to play this video.', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: _initializeVideo, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo(BuildContext context, VideoPlayerController controller) {
    final value = controller.value;
    final aspect = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      onDoubleTapDown: (details) {
        final width = MediaQuery.sizeOf(context).width;
        final isLeft = details.localPosition.dx < width / 2;
        unawaited(_seekRelative(Duration(seconds: isLeft ? -10 : 10)));
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: AspectRatio(aspectRatio: aspect, child: VideoPlayer(controller))),
          if (value.isBuffering)
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
              ),
            ),
          AnimatedOpacity(
            opacity: _showControls ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: _buildControls(context, controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context, VideoPlayerController controller) {
    final value = controller.value;
    final scheme = Theme.of(context).colorScheme;
    final horizontal = Responsive.spacing(context, base: 14, min: 10, max: 24);
    final playSize = Responsive.clamped(context, base: 72, min: 60, max: 90);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black87],
          stops: [0, .45, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  PopupMenuButton<double>(
                    icon: const Icon(Icons.speed_rounded, color: Colors.white),
                    initialValue: _playbackSpeed,
                    onSelected: _setSpeed,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: .75, child: Text('.75x')),
                      PopupMenuItem(value: 1, child: Text('1.0x')),
                      PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      PopupMenuItem(value: 1.75, child: Text('1.75x')),
                      PopupMenuItem(value: 2, child: Text('2.0x')),
                    ],
                  ),
                  IconButton(
                    onPressed: _toggleMute,
                    color: Colors.white,
                    icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                  ),
                  IconButton(
                    onPressed: _toggleFullscreen,
                    color: Colors.white,
                    icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => unawaited(_seekRelative(const Duration(seconds: -10))),
                  color: Colors.white,
                  icon: const Icon(Icons.replay_10_rounded, size: 38),
                ),
                SizedBox(width: Responsive.spacing(context, base: 16, min: 10, max: 26)),
                SizedBox(
                  width: playSize,
                  height: playSize,
                  child: Material(
                    color: scheme.primary,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: _togglePlayback,
                      color: scheme.onPrimary,
                      icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: playSize * .5),
                    ),
                  ),
                ),
                SizedBox(width: Responsive.spacing(context, base: 16, min: 10, max: 26)),
                IconButton(
                  onPressed: () => unawaited(_seekRelative(const Duration(seconds: 10))),
                  color: Colors.white,
                  icon: const Icon(Icons.forward_10_rounded, size: 38),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: Row(
                children: [
                  Text(_format(value.position), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.gold,
                        thumbColor: AppColors.gold,
                        inactiveTrackColor: Colors.white30,
                        trackHeight: 4,
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        min: 0,
                        max: value.duration.inMilliseconds.toDouble() > 0 ? value.duration.inMilliseconds.toDouble() : 1,
                        value: value.position.inMilliseconds.clamp(0, value.duration.inMilliseconds).toDouble(),
                        onChanged: value.duration > Duration.zero
                            ? (position) => unawaited(controller.seekTo(Duration(milliseconds: position.round())))
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(_format(value.duration), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
