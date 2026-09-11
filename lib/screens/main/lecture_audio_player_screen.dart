import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../services/audio_player_service.dart';
import '../../services/download_service.dart';

class LectureAudioPlayerScreen extends StatefulWidget {
  final String lectureId;
  final String lectureTitle;
  final String fileId;
  final String fileTitle;
  final String fileUrl;

  const LectureAudioPlayerScreen({
    super.key,
    required this.lectureId,
    required this.lectureTitle,
    required this.fileId,
    required this.fileTitle,
    required this.fileUrl,
  });

  @override
  State<LectureAudioPlayerScreen> createState() => _LectureAudioPlayerScreenState();
}

class _LectureAudioPlayerScreenState extends State<LectureAudioPlayerScreen> {
  final AudioPlayerService _audio = AudioPlayerService.instance;

  StreamSubscription<ProcessingState>? _processingSubscription;
  StreamSubscription<bool>? _playerStateSubscription;

  bool _loading = true;
  bool _completed = false;
  String? _error;
  double _playbackSpeed = 1.0;

  Timer? _sleepTimer;
  Duration? _sleepRemaining;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializePlayer();
    });
  }

  @override
  void dispose() {
    _processingSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _sleepTimer?.cancel();
    // Intentionally do not pause here. AudioService owns background playback.
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      // Reuse the current AudioService session when returning to the same
      // lecture. This prevents the source from being reloaded from zero and
      // preserves the live position/background playback state.
      final sameLectureIsLoaded =
          _audio.currentMediaItem?.id == widget.lectureId &&
          _audio.duration != null;

      if (!sameLectureIsLoaded) {
        final downloaded = await DownloadsService.instance.findById(widget.fileId);
        var source = widget.fileUrl;
        var isLocal = false;

        if (downloaded != null) {
          final file = File(downloaded.localPath);
          if (await file.exists()) {
            source = file.path;
            isLocal = true;
          }
        }

        if (!isLocal) {
          source = await DownloadsService.instance.createSignedUrlForLectureFile(
            fileUrl: widget.fileUrl,
            fileType: 'audio',
          );
        }

        await _audio.load(
          source: source,
          lectureId: widget.lectureId,
          title: widget.fileTitle,
          lectureTitle: widget.lectureTitle,
          isLocalFile: isLocal,
        );

        await _audio.setSpeed(_playbackSpeed);
        await _audio.play();
      }

      _processingSubscription = _audio.processingStateStream.listen((state) {
        if (!mounted) return;
        if (state == ProcessingState.completed) {
          setState(() => _completed = true);
        }
      });

      _playerStateSubscription = _audio.playingStream.listen((_) {
        if (mounted) setState(() {});
      });

      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Audio player error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to play this audio.';
      });
    }
  }

  String _format(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _seekRelative(Duration offset) async {
    final position = _audio.position;
    final duration = _audio.duration ?? Duration.zero;
    var target = position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    await _audio.seek(target);
  }

  Future<void> _togglePlayback() async {
    if (_loading) return;
    if (_audio.isPlaying) {
      await _audio.pause();
    } else {
      await _audio.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _setSpeed(double speed) async {
    await _audio.setSpeed(speed);
    if (!mounted) return;
    setState(() => _playbackSpeed = speed);
  }

  void _setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepRemaining = duration;
    if (duration == null) {
      if (mounted) setState(() {});
      return;
    }

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final current = _sleepRemaining;
      if (current == null || current <= Duration.zero) {
        timer.cancel();
        await _audio.pause();
        if (mounted) setState(() => _sleepRemaining = null);
        return;
      }
      if (mounted) {
        setState(() => _sleepRemaining = current - const Duration(seconds: 1));
      }
    });
    if (mounted) setState(() {});
  }

  void _showSpeedSheet() {
    const speeds = <double>[0.75, 1, 1.25, 1.5, 1.75, 2];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('Playback speed'),
                subtitle: Text('Choose how fast the lecture plays'),
              ),
              ...speeds.map(
                (speed) => ListTile(
                  title: Text('${speed}x'),
                  trailing: speed == _playbackSpeed
                      ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                      : null,
                  onTap: () {
                    unawaited(_setSpeed(speed));
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showSleepSheet() {
    final options = <({String label, Duration? duration})>[
      (label: 'Off', duration: null),
      (label: '10 minutes', duration: const Duration(minutes: 10)),
      (label: '20 minutes', duration: const Duration(minutes: 20)),
      (label: '30 minutes', duration: const Duration(minutes: 30)),
      (label: '60 minutes', duration: const Duration(minutes: 60)),
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Sleep timer'),
                subtitle: Text('Pause playback automatically'),
              ),
              ...options.map(
                (option) => ListTile(
                  title: Text(option.label),
                  trailing: _sleepRemaining != null && option.duration != null
                      ? const Icon(Icons.check_rounded)
                      : option.duration == null && _sleepRemaining == null
                          ? const Icon(Icons.check_rounded)
                          : null,
                  onTap: () {
                    _setSleepTimer(option.duration);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lectureTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Playback speed',
            onPressed: _loading ? null : _showSpeedSheet,
            icon: const Icon(Icons.speed_rounded),
          ),
          IconButton(
            tooltip: 'Sleep timer',
            onPressed: _loading ? null : _showSleepSheet,
            icon: Icon(_sleepRemaining == null ? Icons.bedtime_outlined : Icons.bedtime_rounded),
          ),
        ],
      ),
      body: _error != null
          ? _buildError(context)
          : Stack(
              children: [
                _buildPlayer(context, scheme),
                if (_loading)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black12,
                      child: Center(
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.4),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Loading audio…',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.cardPadding(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.audio_file_outlined, size: 66, color: scheme.error),
            const SizedBox(height: 16),
            Text(_error ?? 'Unable to play this audio.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: _initializePlayer, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer(BuildContext context, ColorScheme scheme) {
    final horizontal = Responsive.horizontalPadding(context);
    final maxWidth = MediaQuery.sizeOf(context).width >= 900 ? 760.0 : 640.0;
    final artwork = Responsive.clamped(context, base: 220, min: 170, max: 280);

    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                Container(
                  width: artwork,
                  height: artwork,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primary, AppColors.gold],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .18),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: artwork * .44, color: scheme.onPrimary.withValues(alpha: .9)),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .20), borderRadius: BorderRadius.circular(999)),
                          child: const Text('AUDIO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(widget.fileTitle, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(widget.lectureTitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 22),
                _buildProgress(context),
                const SizedBox(height: 14),
                _buildMainControls(context),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(onPressed: _showSpeedSheet, icon: const Icon(Icons.speed_rounded), label: Text('${_playbackSpeed}x')),
                    OutlinedButton.icon(onPressed: _showSleepSheet, icon: Icon(_sleepRemaining == null ? Icons.bedtime_outlined : Icons.bedtime_rounded), label: Text(_sleepRemaining == null ? 'Sleep timer' : _format(_sleepRemaining!))),
                    if (_sleepRemaining != null)
                      FilledButton.tonalIcon(onPressed: () => _setSleepTimer(null), icon: const Icon(Icons.alarm_off_rounded), label: const Text('Cancel timer')),
                  ],
                ),
                if (_completed) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.primary.withValues(alpha: .18))),
                    child: Row(children: [Icon(Icons.check_circle_rounded, color: scheme.primary), const SizedBox(width: 10), Expanded(child: Text('Lecture completed', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)))]),
                  ),
                ],
                const SizedBox(height: 18),
                Text('You can leave this screen and keep listening.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgress(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: _audio.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: _audio.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
            final value = position.inMilliseconds.clamp(0, duration.inMilliseconds > 0 ? duration.inMilliseconds : 0).toDouble();
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.gold,
                    thumbColor: AppColors.gold,
                    trackHeight: 5,
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    min: 0,
                    max: max,
                    value: value,
                    onChanged: duration > Duration.zero
                        ? (next) => unawaited(_audio.seek(Duration(milliseconds: next.round())))
                        : null,
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_format(position)), Text(_format(duration))]),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMainControls(BuildContext context) {
    final main = Responsive.clamped(context, base: 76, min: 64, max: 92);
    return StreamBuilder<bool>(
      stream: _audio.playingStream,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? _audio.isPlaying;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: () => unawaited(_seekRelative(const Duration(seconds: -15))),
              icon: const Icon(Icons.replay_10_rounded),
              tooltip: 'Back 15 seconds',
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: main,
              height: main,
              child: FilledButton(
                onPressed: _loading ? null : _togglePlayback,
                style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: main * .48),
              ),
            ),
            const SizedBox(width: 16),
            IconButton.filledTonal(
              onPressed: () => unawaited(_seekRelative(const Duration(seconds: 15))),
              icon: const Icon(Icons.forward_10_rounded),
              tooltip: 'Forward 15 seconds',
            ),
          ],
        );
      },
    );
  }
}
