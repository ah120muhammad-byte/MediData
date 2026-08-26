import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/responsive/responsive.dart';
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

  StreamSubscription<ProcessingState>?
      _processingSubscription;

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _initializePlayer();
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _processingSubscription?.cancel();

    // Save current position and pause.
    unawaited(
      _audio.pause(),
    );

    super.dispose();
  }

  // ==========================================================================
  // INITIALIZE
  // ==========================================================================

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
        source =
            await DownloadsService.instance
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

          if (state ==
              ProcessingState.completed) {
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
        _error =
            'Unable to play this audio.';
      });
    }
  }

  // ==========================================================================
  // FORMAT DURATION
  // ==========================================================================

  String _formatDuration(
    Duration duration,
  ) {
    final hours =
        duration.inHours;

    final minutes =
        duration.inMinutes
            .remainder(60);

    final seconds =
        duration.inSeconds
            .remainder(60);

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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lectureTitle,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _error != null
              ? _buildError(context)
              : _buildPlayer(context),
    );
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  Widget _buildError(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final maxWidth =
        Responsive.width(context) >=
                900
            ? 560.0
            : 480.0;

    return Center(
      child: SingleChildScrollView(
        padding:
            EdgeInsets.all(
          Responsive.cardPadding(
            context,
          ),
        ),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(
            maxWidth:
                maxWidth,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons
                    .error_outline_rounded,
                size:
                    Responsive.clamped(
                  context,
                  base: 64,
                  min: 52,
                  max: 82,
                ),
                color:
                    theme
                        .colorScheme
                        .error,
              ),

              SizedBox(
                height:
                    Responsive.spacing(
                  context,
                  base: 16,
                  min: 10,
                  max: 22,
                ),
              ),

              Text(
                _error!,
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize:
                      Responsive.bodyTextSize(
                    context,
                    base: 15,
                    min: 13,
                    max: 19,
                  ),
                  height: 1.4,
                ),
              ),

              SizedBox(
                height:
                    Responsive.spacing(
                  context,
                  base: 18,
                  min: 12,
                  max: 24,
                ),
              ),

              SizedBox(
                height:
                    Responsive.buttonHeight(
                  context,
                ),
                child: FilledButton.icon(
                  onPressed:
                      _initializePlayer,
                  icon:
                      const Icon(
                    Icons
                        .refresh_rounded,
                  ),
                  label:
                      const Text(
                    'Retry',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // PLAYER
  // ==========================================================================

  Widget _buildPlayer(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final horizontalPadding =
            Responsive.horizontalPadding(
          context,
        );

        final contentMaxWidth =
            constraints.maxWidth >=
                    900
                ? 820.0
                : 680.0;

        final artSize =
            Responsive.clamped(
          context,
          base: 190,
          min: 155,
          max: 250,
        );

        final artIconSize =
            Responsive.clamped(
          context,
          base: 88,
          min: 72,
          max: 116,
        );

        final titleSize =
            Responsive.titleSize(
          context,
          base: 23,
          min: 20,
          max: 31,
        );

        return SingleChildScrollView(
          physics:
              const BouncingScrollPhysics(),
          padding:
              EdgeInsets.fromLTRB(
            horizontalPadding,
            Responsive.spacing(
              context,
              base: 22,
              min: 14,
              max: 34,
            ),
            horizontalPadding,
            Responsive.scrollBottomPadding(
              context,
              base: 32,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(
                maxWidth:
                    contentMaxWidth,
              ),
              child: Column(
                children: [
                  // ===========================================================
                  // ART
                  // ===========================================================

                  Container(
                    width:
                        artSize,
                    height:
                        artSize,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          theme.colorScheme.primary
                              .withValues(
                        alpha:
                            0.10,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              theme.colorScheme.primary
                                  .withValues(
                            alpha:
                                0.12,
                          ),
                          blurRadius:
                              Responsive.clamped(
                            context,
                            base:
                                30,
                            min:
                                22,
                            max:
                                40,
                          ),
                          spreadRadius:
                              Responsive.clamped(
                            context,
                            base:
                                4,
                            min:
                                2,
                            max:
                                7,
                          ),
                        ),
                      ],
                    ),
                    child:
                        Icon(
                      Icons
                          .headphones_rounded,
                      size:
                          artIconSize,
                      color:
                          theme.colorScheme.primary,
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          28,
                      min:
                          20,
                      max:
                          38,
                    ),
                  ),

                  // ===========================================================
                  // TITLE
                  // ===========================================================

                  Text(
                    widget.fileTitle,
                    textAlign:
                        TextAlign.center,
                    maxLines:
                        3,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        TextStyle(
                      fontSize:
                          titleSize,
                      fontWeight:
                          FontWeight.w800,
                      height:
                          1.25,
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          8,
                      min:
                          5,
                      max:
                          12,
                    ),
                  ),

                  Text(
                    widget.lectureTitle,
                    textAlign:
                        TextAlign.center,
                    maxLines:
                        2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        TextStyle(
                      fontSize:
                          Responsive.bodyTextSize(
                        context,
                        base:
                            14,
                        min:
                            12,
                        max:
                            18,
                      ),
                      height:
                          1.35,
                      color:
                          theme.colorScheme
                              .onSurface
                              .withValues(
                        alpha:
                            0.60,
                      ),
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          30,
                      min:
                          20,
                      max:
                          40,
                    ),
                  ),

                  // ===========================================================
                  // PROGRESS
                  // ===========================================================

                  _buildProgress(
                    context,
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          22,
                      min:
                          16,
                      max:
                          30,
                    ),
                  ),

                  // ===========================================================
                  // CONTROLS
                  // ===========================================================

                  _buildControls(
                    context,
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          22,
                      min:
                          16,
                      max:
                          30,
                    ),
                  ),

                  // ===========================================================
                  // SPEED
                  // ===========================================================

                  OutlinedButton.icon(
                    onPressed:
                        () {
                      _showSpeedPicker(
                        context,
                        _playbackSpeed,
                      );
                    },
                    icon:
                        Icon(
                      Icons
                          .speed_rounded,
                      size:
                          Responsive.iconSize(
                        context,
                        base:
                            20,
                        min:
                            18,
                        max:
                            25,
                      ),
                    ),
                    label:
                        Text(
                      '${_playbackSpeed}x',
                      style:
                          TextStyle(
                        fontSize:
                            Responsive.bodyTextSize(
                          context,
                          base:
                              14,
                          min:
                              12,
                          max:
                              17,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.spacing(
                      context,
                      base:
                          24,
                      min:
                          18,
                      max:
                          34,
                    ),
                  ),

                  Text(
                    'Background playback is enabled',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          Responsive.smallTextSize(
                        context,
                        base:
                            12,
                        min:
                            10,
                        max:
                            14,
                      ),
                      color:
                          theme.colorScheme
                              .onSurface
                              .withValues(
                        alpha:
                            0.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // PROGRESS
  // ==========================================================================

  Widget _buildProgress(
    BuildContext context,
  ) {
    return StreamBuilder<Duration>(
      stream:
          _audio.positionStream,
      builder:
          (
        context,
        positionSnapshot,
      ) {
        final position =
            positionSnapshot.data ??
                Duration.zero;

        return StreamBuilder<Duration?>(
          stream:
              _audio.durationStream,
          builder:
              (
            context,
            durationSnapshot,
          ) {
            final duration =
                durationSnapshot.data ??
                    Duration.zero;

            final durationMs =
                duration.inMilliseconds;

            final positionMs =
                position.inMilliseconds;

            final maxValue =
                durationMs > 0
                    ? durationMs.toDouble()
                    : 1.0;

            final currentValue =
                positionMs
                    .clamp(
                      0,
                      durationMs > 0
                          ? durationMs
                          : 0,
                    )
                    .toDouble();

            final horizontal =
                Responsive.spacing(
              context,
              base:
                  4,
              min:
                  2,
              max:
                  8,
            );

            return Column(
              children: [
                SliderTheme(
                  data:
                      SliderTheme.of(
                    context,
                  ).copyWith(
                    trackHeight:
                        Responsive.clamped(
                      context,
                      base:
                          5,
                      min:
                          4,
                      max:
                          7,
                    ),
                    thumbShape:
                        RoundSliderThumbShape(
                      enabledThumbRadius:
                          Responsive.clamped(
                        context,
                        base:
                            7,
                        min:
                            6,
                        max:
                            9,
                      ),
                    ),
                    overlayShape:
                        RoundSliderOverlayShape(
                      overlayRadius:
                          Responsive.clamped(
                        context,
                        base:
                            16,
                        min:
                            13,
                        max:
                            20,
                      ),
                    ),
                  ),
                  child:
                      Slider(
                    min:
                        0,
                    max:
                        maxValue,
                    value:
                        currentValue,
                    onChanged:
                        duration >
                                Duration.zero
                            ? (
                                value,
                              ) {
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
                ),

                Padding(
                  padding:
                      EdgeInsets.symmetric(
                    horizontal:
                        horizontal,
                  ),
                  child:
                      Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      Text(
                        _formatDuration(
                          position,
                        ),
                        style:
                            TextStyle(
                          fontSize:
                              Responsive.smallTextSize(
                            context,
                            base:
                                12,
                            min:
                                10,
                            max:
                                14,
                          ),
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      Text(
                        _formatDuration(
                          duration,
                        ),
                        style:
                            TextStyle(
                          fontSize:
                              Responsive.smallTextSize(
                            context,
                            base:
                                12,
                            min:
                                10,
                            max:
                                14,
                          ),
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

  // ==========================================================================
  // CONTROLS
  // ==========================================================================

  Widget _buildControls(
    BuildContext context,
  ) {
    final skipSize =
        Responsive.clamped(
      context,
      base:
          32,
      min:
          28,
      max:
          40,
    );

    final playButtonSize =
        Responsive.clamped(
      context,
      base:
          68,
      min:
          58,
      max:
          84,
    );

    final playIconSize =
        playButtonSize *
            0.52;

    final controlGap =
        Responsive.spacing(
      context,
      base:
          18,
      min:
          12,
      max:
          26,
    );

    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed:
              () {
            unawaited(
              _audio.skipBackward(),
            );
          },
          tooltip:
              'Rewind 10 seconds',
          icon:
              Icon(
            Icons
                .replay_10_rounded,
            size:
                skipSize,
          ),
        ),

        SizedBox(
          width:
              controlGap,
        ),

        StreamBuilder<bool>(
          stream:
              _audio.playingStream,
          builder:
              (
            context,
            snapshot,
          ) {
            final playing =
                snapshot.data ??
                    false;

            return SizedBox(
              width:
                  playButtonSize,
              height:
                  playButtonSize,
              child:
                  FilledButton(
                onPressed:
                    playing
                        ? _audio.pause
                        : _audio.play,
                style:
                    FilledButton.styleFrom(
                  shape:
                      const CircleBorder(),
                  padding:
                      EdgeInsets.zero,
                ),
                child:
                    Icon(
                  playing
                      ? Icons
                          .pause_rounded
                      : Icons
                          .play_arrow_rounded,
                  size:
                      playIconSize,
                ),
              ),
            );
          },
        ),

        SizedBox(
          width:
              controlGap,
        ),

        IconButton(
          onPressed:
              () {
            unawaited(
              _audio.skipForward(),
            );
          },
          tooltip:
              'Forward 10 seconds',
          icon:
              Icon(
            Icons
                .forward_10_rounded,
            size:
                skipSize,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // SPEED PICKER
  // ==========================================================================

  void _showSpeedPicker(
    BuildContext context,
    double currentSpeed,
  ) {
    const speeds =
        <double>[
      0.75,
      1.0,
      1.25,
      1.5,
      1.75,
      2.0,
    ];

    showModalBottomSheet<void>(
      context:
          context,
      showDragHandle:
          true,
      builder:
          (
        sheetContext,
      ) {
        return SafeArea(
          child:
              ListView(
            shrinkWrap:
                true,
            children: [
              Padding(
                padding:
                    EdgeInsets.fromLTRB(
                  Responsive.cardPadding(
                    context,
                  ),
                  4,
                  Responsive.cardPadding(
                    context,
                  ),
                  8,
                ),
                child:
                    Text(
                  'Playback Speed',
                  style:
                      TextStyle(
                    fontSize:
                        Responsive.titleSize(
                      context,
                      base:
                          18,
                      min:
                          16,
                      max:
                          23,
                    ),
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              ...speeds.map(
                (
                  speed,
                ) {
                  final selected =
                      speed ==
                          currentSpeed;

                  return ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(
                      horizontal:
                          Responsive.cardPadding(
                        context,
                      ),
                    ),
                    title:
                        Text(
                      '${speed}x',
                      style:
                          TextStyle(
                        fontSize:
                            Responsive.bodyTextSize(
                          context,
                          base:
                              15,
                          min:
                              13,
                          max:
                              18,
                        ),
                        fontWeight:
                            selected
                                ? FontWeight
                                    .w700
                                : FontWeight
                                    .w400,
                      ),
                    ),
                    trailing:
                        selected
                            ? Icon(
                                Icons
                                    .check_rounded,
                                color:
                                    Theme.of(
                                  context,
                                )
                                        .colorScheme
                                        .primary,
                              )
                            : null,
                    onTap:
                        () {
                      if (!sheetContext
                          .mounted) {
                        return;
                      }

                      setState(
                        () {
                          _playbackSpeed =
                              speed;
                        },
                      );

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

              SizedBox(
                height:
                    Responsive.spacing(
                  context,
                  base:
                      8,
                  min:
                      4,
                  max:
                      14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}