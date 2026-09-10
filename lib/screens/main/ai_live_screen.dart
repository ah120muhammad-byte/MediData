import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';
import '../../services/ai_live_service.dart';

class AiLiveScreen extends StatefulWidget {
  final String mode;

  const AiLiveScreen({super.key, this.mode = 'smart'});

  @override
  State<AiLiveScreen> createState() => _AiLiveScreenState();
}

class _AiLiveScreenState extends State<AiLiveScreen>
    with SingleTickerProviderStateMixin {
  final AiLiveService _service = AiLiveService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _transcriptScrollController = ScrollController();

  StreamSubscription<String>? _inputSubscription;
  StreamSubscription<String>? _outputSubscription;
  StreamSubscription<String>? _statusSubscription;

  String _status = 'Ready';
  String _studentText = '';
  String _assistantText = '';
  bool _connecting = false;
  bool _muted = false;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: .92,
      upperBound: 1.08,
    );
    _inputSubscription = _service.transcriptStream.listen((text) {
      if (!mounted) return;
      setState(() => _studentText = text);
      _scrollTranscript();
    });
    _outputSubscription = _service.assistantTranscriptStream.listen((text) {
      if (!mounted) return;
      setState(() => _assistantText = text);
      _scrollTranscript();
    });
    _statusSubscription = _service.statusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _status = status;
        _connecting = status == 'Connecting…';
      });
    });
  }

  @override
  void dispose() {
    _inputSubscription?.cancel();
    _outputSubscription?.cancel();
    _statusSubscription?.cancel();
    _textController.dispose();
    _transcriptScrollController.dispose();
    _pulseController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _toggleLive() async {
    if (_connecting) return;

    if (_service.isConnected) {
      await _service.disconnect();
      _pulseController.stop();
      if (mounted) setState(() {});
      return;
    }

    setState(() {
      _connecting = true;
      _studentText = '';
      _assistantText = '';
    });
    try {
      await _service.connect(mode: widget.mode);
      if (mounted) {
        _pulseController.repeat(reverse: true);
        setState(() => _status = 'Live');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _status = 'Unable to connect';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleMute() async {
    await _service.toggleMute();
    if (!mounted) return;
    setState(() => _muted = _service.isMuted);
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty || !_service.isConnected) return;
    _service.sendText(text);
    _textController.clear();
  }

  Future<void> _interrupt() async {
    await _service.interrupt();
  }

  void _scrollTranscript() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_transcriptScrollController.hasClients) return;
      _transcriptScrollController.animateTo(
        _transcriptScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = Responsive.width(context);
    final compact = width < 420;
    final wide = width >= 800;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediData AI Live'),
        centerTitle: !wide,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 820 : double.infinity),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 20,
                18,
                compact ? 14 : 20,
                16,
              ),
              child: Column(
                children: [
                  Expanded(child: _buildLivePanel(context)),
                  const SizedBox(height: 14),
                  _buildTextBar(context),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _service.isConnected ? _toggleMute : null,
                        icon: Icon(
                          _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        ),
                        label: Text(_muted ? 'Muted' : 'Mute'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _service.isConnected ? _interrupt : null,
                        icon: const Icon(Icons.pan_tool_rounded),
                        label: const Text('Stop response'),
                      ),
                      FilledButton.icon(
                        onPressed: _connecting ? null : _toggleLive,
                        icon: Icon(
                          _service.isConnected
                              ? Icons.call_end_rounded
                              : Icons.graphic_eq_rounded,
                        ),
                        label: Text(
                          _service.isConnected ? 'End live chat' : 'Start live chat',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gemini Live • $_status',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: .55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLivePanel(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connected = _service.isConnected;
    final width = Responsive.width(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(width < 420 ? 16 : 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Spacer(),
          ScaleTransition(
            scale: connected
                ? _pulseController
                : const AlwaysStoppedAnimation<double>(1),
            child: Container(
              width: width < 420 ? 122 : 150,
              height: width < 420 ? 122 : 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: .10),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: connected ? .45 : .18),
                  width: 2,
                ),
                boxShadow: connected
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: .16),
                          blurRadius: 34,
                          spreadRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                connected
                    ? Icons.graphic_eq_rounded
                    : Icons.auto_awesome_rounded,
                size: width < 420 ? 56 : 68,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            connected ? 'Talk naturally' : 'Your AI study companion',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            connected
                ? 'Speak normally. MediData AI listens and answers in real time.'
                : 'Use your voice to ask about anatomy, physiology, lectures or exam prep.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: .60),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 26),
          if (_studentText.isNotEmpty || _assistantText.isNotEmpty)
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SingleChildScrollView(
                  controller: _transcriptScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_studentText.isNotEmpty)
                        _Transcript(
                          label: 'You',
                          text: _studentText,
                          icon: Icons.person_rounded,
                        ),
                      if (_assistantText.isNotEmpty) ...[
                        if (_studentText.isNotEmpty) const SizedBox(height: 12),
                        _Transcript(
                          label: 'MediData AI',
                          text: _assistantText,
                          icon: Icons.auto_awesome_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTextBar(BuildContext context) {
    final enabled = _service.isConnected;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            enabled: enabled,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendText(),
            decoration: InputDecoration(
              hintText: enabled ? 'Type while in Live mode…' : 'Start Live to use text too',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: enabled ? _sendText : null,
          icon: const Icon(Icons.arrow_upward_rounded),
          tooltip: 'Send text',
        ),
      ],
    );
  }
}

class _Transcript extends StatelessWidget {
  final String label;
  final String text;
  final IconData icon;

  const _Transcript({
    required this.label,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(text, style: const TextStyle(height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
