import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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
  State<LectureAudioPlayerScreen> createState() =>
      _LectureAudioPlayerScreenState();
}

class _LectureAudioPlayerScreenState
    extends State<LectureAudioPlayerScreen> {
  final AudioPlayerService _audio =
      AudioPlayerService.instance;

  bool _loading = true;

  String? _error;

  double _playbackSpeed = 1.0;

  StreamSubscription<ProcessingState>? _processingSubscription;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _initializePlayer();
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _processingSubscription?.cancel();

    // Save current position and pause.
    unawaited(
      _audio.pause(),
    );

    super.dispose();
  }

  // ===========================================================================
  // INITIALIZE
  // ===========================================================================

  Future<void> _initializePlayer() async {
    try {
      final downloaded =
          await DownloadsService.instance.findById(
        widget.fileId,
      );

      bool isLocal = false;

      String source = widget.fileUrl;

      // -----------------------------------------------------------------------
      // LOCAL DOWNLOAD
      // -----------------------------------------------------------------------

      if (downloaded != null) {
        final file = File(
          downloaded.localPath,
        );

        if (await file.exists()) {
          source = file.path;
          isLocal = true;
        }
      }

      // -----------------------------------------------------------------------
      // ONLINE SOURCE
      // -----------------------------------------------------------------------

      if (!isLocal) {
        source = await DownloadsService.instance
            .createSignedUrlForLectureFile(
          fileUrl: widget.fileUrl,
          fileType: 'audio',
        );
      }

      // -----------------------------------------------------------------------
      // LOAD AUDIO
      // -----------------------------------------------------------------------

      await _audio.load(
        source: source,
        lectureId: widget.lectureId,
        title: widget.fileTitle,
        lectureTitle: widget.lectureTitle,
        isLocalFile: isLocal,
      );

      _processingSubscription =
          _audio.processingStateStream.listen(
        (state) {
          if (!mounted) {
            return;
          }

          if (state == ProcessingState.completed) {
            setState(() {});
          }
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = null;
      });

      await _audio.play();
    } catch (e) {
      debugPrint(
        'Audio player error: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to play this audio.';
      });
    }
  }

  // ===========================================================================
  // FORMAT DURATION
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
    return Scaffold(
      appBar: AppBar(
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
              : _buildPlayer(),
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildError() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _initializePlayer,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PLAYER
  // ===========================================================================

  Widget _buildPlayer() {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final isTablet =
            MediaQuery.sizeOf(context).shortestSide >=
                600;

        final horizontalPadding =
            isTablet ? 48.0 : 24.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            32,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 56,
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // =================================================================
                // ART
                // =================================================================

                Container(
                  width: isTablet ? 220 : 170,
                  height: isTablet ? 220 : 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        theme.colorScheme.primary.withValues(
                      alpha: 0.10,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.headphones_rounded,
                    size: isTablet ? 100 : 82,
                    color: theme.colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 30),

                // =================================================================
                // TITLE
                // =================================================================

                Text(
                  widget.fileTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isTablet ? 25 : 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.lectureTitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isTablet ? 15 : 13,
                    color:
                        theme.colorScheme.onSurface.withValues(
                      alpha: 0.60,
                    ),
                  ),
                ),

                const SizedBox(height: 34),

                // =================================================================
                // PROGRESS
                // =================================================================

                _buildProgress(isTablet),

                const SizedBox(height: 22),

                // =================================================================
                // CONTROLS
                // =================================================================

                _buildControls(isTablet),

                const SizedBox(height: 22),

                // =================================================================
                // SPEED
                // =================================================================

                OutlinedButton.icon(
                  onPressed: () {
                    _showSpeedPicker(
                      context,
                      _playbackSpeed,
                    );
                  },
                  icon: const Icon(
                    Icons.speed_rounded,
                  ),
                  label: Text(
                    '${_playbackSpeed}x',
                  ),
                ),

                const SizedBox(height: 26),

                Text(
                  'Background playback is enabled',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        theme.colorScheme.onSurface.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // PROGRESS
  // ===========================================================================

  Widget _buildProgress(
    bool isTablet,
  ) {
    return StreamBuilder<Duration>(
      stream: _audio.positionStream,
      builder: (
        context,
        positionSnapshot,
      ) {
        final position =
            positionSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration?>(
          stream: _audio.durationStream,
          builder: (
            context,
            durationSnapshot,
          ) {
            final duration =
                durationSnapshot.data ?? Duration.zero;

            final durationMs =
                duration.inMilliseconds;

            final positionMs =
                position.inMilliseconds;

            final maxValue =
                durationMs > 0
                    ? durationMs.toDouble()
                    : 1.0;

            final currentValue = positionMs
                .clamp(
                  0,
                  durationMs > 0
                      ? durationMs
                      : 0,
                )
                .toDouble();

            return Column(
              children: [
                Slider(
                  min: 0,
                  max: maxValue,
                  value: currentValue,
                  onChanged: duration > Duration.zero
                      ? (value) {
                          unawaited(
                            _audio.seek(
                              Duration(
                                milliseconds:
                                    value.round(),
                              ),
                            ),
                          );
                        }
                      : null,
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: TextStyle(
                          fontSize:
                              isTablet ? 13 : 12,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(
                          fontSize:
                              isTablet ? 13 : 12,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // CONTROLS
  // ===========================================================================

  Widget _buildControls(
    bool isTablet,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            unawaited(
              _audio.skipBackward(),
            );
          },
          tooltip: 'Rewind 15 seconds',
          icon: Icon(
            Icons.replay_10_rounded,
            size: isTablet ? 34 : 30,
          ),
        ),

        SizedBox(
          width: isTablet ? 22 : 14,
        ),

        StreamBuilder<bool>(
          stream: _audio.playingStream,
          builder: (
            context,
            snapshot,
          ) {
            final playing =
                snapshot.data ?? false;

            return FilledButton(
              onPressed:
                  playing
                      ? _audio.pause
                      : _audio.play,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.all(
                  isTablet ? 22 : 19,
                ),
              ),
              child: Icon(
                playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: isTablet ? 38 : 34,
              ),
            );
          },
        ),

        SizedBox(
          width: isTablet ? 22 : 14,
        ),

        IconButton(
          onPressed: () {
            unawaited(
              _audio.skipForward(),
            );
          },
          tooltip: 'Forward 15 seconds',
          icon: Icon(
            Icons.forward_10_rounded,
            size: isTablet ? 34 : 30,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SPEED
  // ===========================================================================

  void _showSpeedPicker(
    BuildContext context,
    double currentSpeed,
  ) {
    const speeds = <double>[
      0.75,
      1.0,
      1.25,
      1.5,
      1.75,
      2.0,
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (
        sheetContext,
      ) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Playback Speed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              ...speeds.map(
                (speed) {
                  final selected =
                      speed == currentSpeed;

                  return ListTile(
                    title: Text(
                      '${speed}x',
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check_rounded,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _playbackSpeed =
                            speed;
                      });

                      unawaited(
                        _audio.setSpeed(
                          speed,
                        ),
                      );

                      Navigator.of(
                        sheetContext,
                      ).pop();
                    },
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}