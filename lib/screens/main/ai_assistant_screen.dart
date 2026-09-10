import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../services/ai_chat_history_service.dart';
import '../../services/ai_chat_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

enum _AiMode {
  smart,
  study,
  examPrep,
  summarize,
}

extension on _AiMode {
  String get label {
    switch (this) {
      case _AiMode.smart:
        return 'Smart';
      case _AiMode.study:
        return 'Study tutor';
      case _AiMode.examPrep:
        return 'Exam prep';
      case _AiMode.summarize:
        return 'Summarize';
    }
  }

  String get description {
    switch (this) {
      case _AiMode.smart:
        return 'Best general answer';
      case _AiMode.study:
        return 'Explain, teach and quiz me';
      case _AiMode.examPrep:
        return 'High-yield revision';
      case _AiMode.summarize:
        return 'Condense notes and files';
    }
  }

  IconData get icon {
    switch (this) {
      case _AiMode.smart:
        return Icons.auto_awesome_rounded;
      case _AiMode.study:
        return Icons.school_rounded;
      case _AiMode.examPrep:
        return Icons.quiz_rounded;
      case _AiMode.summarize:
        return Icons.summarize_rounded;
    }
  }
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final AiChatService _aiService = AiChatService();
  final AiChatHistoryService _historyService = AiChatHistoryService.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<AiChatMessage> _messages = <AiChatMessage>[];
  final Map<int, List<AiSource>> _sourcesByMessage = <int, List<AiSource>>{};

  String? _chatSessionId;
  bool _isLoadingHistory = true;
  bool _isSending = false;
  bool _useWebSearch = false;
  bool _useCodeExecution = false;
  AiAttachment? _selectedAttachment;
  _AiMode _mode = _AiMode.smart;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
    _loadSavedConversation();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedConversation() async {
    try {
      final existingSessionId = await _historyService.getCurrentSessionId();
      if (existingSessionId == null || existingSessionId.isEmpty) {
        final newSessionId = await _historyService.createSession(title: 'New chat');
        if (!mounted) return;
        setState(() {
          _chatSessionId = newSessionId;
          _isLoadingHistory = false;
        });
        return;
      }

      final savedMessages = await _historyService.loadMessages(existingSessionId);
      if (!mounted) return;
      setState(() {
        _chatSessionId = existingSessionId;
        _messages
          ..clear()
          ..addAll(savedMessages);
        _isLoadingHistory = false;
      });

      if (_messages.isNotEmpty) {
        await _scrollToBottom(animated: false);
      }
    } catch (e, stackTrace) {
      debugPrint('AI history load error: $e');
      debugPrint(stackTrace.toString());
      try {
        final newSessionId = await _historyService.createSession(title: 'New chat');
        if (!mounted) return;
        setState(() {
          _chatSessionId = newSessionId;
          _isLoadingHistory = false;
        });
      } catch (sessionError) {
        debugPrint('AI session create error: $sessionError');
        if (mounted) setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _saveMessageToHistory(AiChatMessage message) async {
    try {
      if (_chatSessionId == null || _chatSessionId!.isEmpty) {
        _chatSessionId = await _historyService.createSession(
          title: _buildSessionTitle(message),
        );
      }

      await _historyService.saveMessage(
        sessionId: _chatSessionId!,
        message: message,
      );

      if (message.role == 'user') {
        final savedMessageCount = _messages.where((item) => item.role == 'user');
        if (savedMessageCount.length == 1) {
          await _historyService.updateTitle(
            sessionId: _chatSessionId!,
            title: _buildSessionTitle(message),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('AI save message error: $e');
      debugPrint(stackTrace.toString());
    }
  }

  String _buildSessionTitle(AiChatMessage message) {
    final text = message.content.trim();
    if (text.isEmpty) return 'New chat';
    return text.length <= 60 ? text : '${text.substring(0, 60)}...';
  }

  Future<void> _startNewChat() async {
    if (_isSending || _isLoadingHistory) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start a new chat?'),
        content: const Text(
          'Your current conversation will remain saved and a new conversation will start.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('New chat'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final newSessionId = await _historyService.createSession(title: 'New chat');
      if (!mounted) return;
      setState(() {
        _chatSessionId = newSessionId;
        _messages.clear();
        _sourcesByMessage.clear();
        _selectedAttachment = null;
        _messageController.clear();
        _mode = _AiMode.smart;
        _useWebSearch = false;
        _useCodeExecution = false;
      });
      _inputFocusNode.requestFocus();
    } catch (e, stackTrace) {
      debugPrint('Create new AI chat error: $e');
      debugPrint(stackTrace.toString());
      if (mounted) _showError('Unable to start a new chat.');
    }
  }

  String _modeInstruction() {
    switch (_mode) {
      case _AiMode.smart:
        return '';
      case _AiMode.study:
        return '[Study Tutor Mode] Teach the concept step-by-step, use a clear mental model, and finish with 2-3 quick check questions when appropriate.';
      case _AiMode.examPrep:
        return '[Exam Prep Mode] Focus on high-yield facts, common exam traps, clinical correlations, and concise memory aids.';
      case _AiMode.summarize:
        return '[Summarize Mode] Summarize the provided content into key ideas, definitions, tables, and actionable revision points. Keep it faithful to the source.';
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending || _isLoadingHistory) return;

    final text = _messageController.text.trim();
    final attachment = _selectedAttachment;
    if (text.isEmpty && attachment == null) return;

    final rawUserMessage = text.isEmpty
        ? 'Please analyze the attached file and explain the important points.'
        : text;
    final instruction = _modeInstruction();
    final userMessage = instruction.isEmpty
        ? rawUserMessage
        : '$instruction\n\n$rawUserMessage';

    final userChatMessage = AiChatMessage(
      role: 'user',
      content: userMessage,
    );
    final outgoingMessages = [..._messages, userChatMessage];

    setState(() {
      _messages.add(userChatMessage);
      _messageController.clear();
      _selectedAttachment = null;
      _isSending = true;
    });

    await _saveMessageToHistory(userChatMessage);
    await _scrollToBottom();

    try {
      if (attachment != null) {
        final response = await _aiService.sendMessageWithAttachment(
          messages: outgoingMessages,
          attachment: attachment,
          mode: _mode.name,
          useWebSearch: _useWebSearch,
          useCodeExecution: _useCodeExecution,
        );

        if (!mounted) return;
        final assistantIndex = _messages.length;
        final assistantMessage = AiChatMessage(
          role: 'assistant',
          content: response.reply,
        );
        setState(() {
          _messages.add(assistantMessage);
          _sourcesByMessage[assistantIndex] = response.sources;
          _isSending = false;
        });
        await _saveMessageToHistory(assistantMessage);
      } else {
        final assistantIndex = _messages.length;
        setState(() {
          _messages.add(
            const AiChatMessage(role: 'assistant', content: ''),
          );
        });

        final response = await _aiService.sendMessageStreaming(
          messages: outgoingMessages,
          mode: _mode.name,
          useWebSearch: _useWebSearch,
          useCodeExecution: _useCodeExecution,
          onText: (partialText) {
            if (!mounted) return;
            setState(() {
              _messages[assistantIndex] = AiChatMessage(
                role: 'assistant',
                content: partialText,
              );
            });
            unawaited(_scrollToBottom());
          },
        );

        if (!mounted) return;
        final assistantMessage = AiChatMessage(
          role: 'assistant',
          content: response.reply,
        );
        setState(() {
          _messages[assistantIndex] = assistantMessage;
          _sourcesByMessage[assistantIndex] = response.sources;
          _isSending = false;
        });
        await _saveMessageToHistory(assistantMessage);
      }

      await _scrollToBottom();
      if (mounted) _inputFocusNode.requestFocus();
    } catch (e, stackTrace) {
      debugPrint('AI send error: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) return;

      setState(() {
        _isSending = false;
        if (_messages.isNotEmpty &&
            _messages.last.role == 'assistant' &&
            _messages.last.content.trim().isEmpty) {
          _messages.removeLast();
        }
      });
      _showError(_cleanErrorMessage(e));
      _inputFocusNode.requestFocus();
    }
  }

  Future<void> _regenerateLastResponse() async {
    if (_isSending || _messages.isEmpty) return;

    final assistantIndex = _messages.lastIndexWhere(
      (message) => message.role == 'assistant',
    );
    if (assistantIndex < 0) return;

    final userIndex = assistantIndex - 1;
    if (userIndex < 0 || _messages[userIndex].role != 'user') return;

    final previousMessages = _messages.sublist(0, userIndex + 1);
    final assistantPlaceholderIndex = _messages.length - 1;

    setState(() {
      _messages[assistantPlaceholderIndex] =
          const AiChatMessage(role: 'assistant', content: '');
      _isSending = true;
      _sourcesByMessage.remove(assistantPlaceholderIndex);
    });

    try {
      final response = await _aiService.sendMessageStreaming(
        messages: previousMessages,
        mode: _mode.name,
        useWebSearch: _useWebSearch,
        useCodeExecution: _useCodeExecution,
        onText: (partialText) {
          if (!mounted) return;
          setState(() {
            _messages[assistantPlaceholderIndex] = AiChatMessage(
              role: 'assistant',
              content: partialText,
            );
          });
          unawaited(_scrollToBottom());
        },
      );

      if (!mounted) return;
      final assistantMessage = AiChatMessage(
        role: 'assistant',
        content: response.reply,
      );
      setState(() {
        _messages[assistantPlaceholderIndex] = assistantMessage;
        _sourcesByMessage[assistantPlaceholderIndex] = response.sources;
        _isSending = false;
      });
      await _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages[assistantPlaceholderIndex] =
            const AiChatMessage(role: 'assistant', content: '');
      });
      _showError(_cleanErrorMessage(e));
    }
  }

  Future<void> _pickFile() async {
    if (_isSending) return;

    try {
      final pickedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'pdf',
          'txt',
          'md',
          'docx',
          'pptx',
        ],
      );
      if (pickedFile == null) return;

      final fileSize = await pickedFile.length();
      if (fileSize <= 0) {
        _showError('The selected file is empty.');
        return;
      }
      if (fileSize > AiChatService.maxFileBytes) {
        _showError('File size must be 20 MB or less.');
        return;
      }

      final fileName = pickedFile.name;
      if (!AiChatService.isSupportedFile(fileName)) {
        _showError('This file type is not supported.');
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) {
        _showError('Unable to read the selected file.');
        return;
      }

      final mimeType = AiChatService.mimeTypeForFile(fileName);
      if (!mounted) return;

      setState(() {
        _selectedAttachment = AiAttachment(
          fileName: fileName,
          mimeType: mimeType,
          bytes: bytes,
          isImage: mimeType.startsWith('image/'),
        );
      });
      _inputFocusNode.requestFocus();
      await _scrollToBottom();
    } on TimeoutException {
      if (mounted) _showError('The file took too long to read.');
    } catch (e, stackTrace) {
      debugPrint('AI file picker error: $e');
      debugPrint(stackTrace.toString());
      if (mounted) _showError(_cleanErrorMessage(e));
    }
  }

  void _removeAttachment() {
    if (_isSending) return;
    setState(() => _selectedAttachment = null);
  }

  void _showToolsSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'AI tools',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  value: _useWebSearch,
                  onChanged: _isSending
                      ? null
                      : (value) {
                          setState(() => _useWebSearch = value);
                        },
                  secondary: Icon(Icons.travel_explore_rounded, color: scheme.primary),
                  title: const Text('Web search'),
                  subtitle: const Text('Use fresh web information and sources'),
                ),
                SwitchListTile.adaptive(
                  value: _useCodeExecution,
                  onChanged: _isSending
                      ? null
                      : (value) {
                          setState(() => _useCodeExecution = value);
                        },
                  secondary: Icon(Icons.functions_rounded, color: scheme.primary),
                  title: const Text('Code execution'),
                  subtitle: const Text('Let AI calculate, analyze and verify with Python'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showModeSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose AI mode',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
              ..._AiMode.values.map(
                (mode) => RadioListTile<_AiMode>(
                  value: mode,
                  groupValue: _mode,
                  onChanged: _isSending
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _mode = value);
                          Navigator.of(sheetContext).pop();
                        },
                  secondary: Icon(mode.icon),
                  title: Text(mode.label),
                  subtitle: Text(mode.description),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scrollToBottom({bool animated = true}) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted || !_scrollController.hasClients) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (!animated) {
      _scrollController.jumpTo(maxScrollExtent);
      return;
    }

    await _scrollController.animateTo(
      maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showToast('Copied to clipboard');
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception:')) {
      return text.substring('Exception:'.length).trim();
    }
    return text.isEmpty
        ? 'Unable to get an AI response. Please try again.'
        : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasTools = _useWebSearch || _useCodeExecution;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MediData AI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Study smarter',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (hasTools)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(
                Icons.bolt_rounded,
                size: 19,
                color: scheme.primary,
              ),
            ),
          IconButton(
            tooltip: 'AI tools',
            onPressed: _isSending ? null : _showToolsSheet,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: _isSending ? null : _startNewChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(child: _buildMessagesArea(context)),
                  _buildComposer(context),
                ],
              ),
            ),
    );
  }

  Widget _buildMessagesArea(BuildContext context) {
    if (_messages.isEmpty) {
      return _buildWelcome(context);
    }

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(context, _messages[index], index);
      },
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = scheme.surfaceContainerHighest.withValues(alpha: .55);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: .18),
                      scheme.secondary.withValues(alpha: .12),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 38,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Your study copilot',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask questions, upload notes, search the web, solve calculations, and turn difficult topics into clear lessons.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .62),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  _promptChip(
                    context,
                    'Explain this simply',
                    Icons.lightbulb_outline_rounded,
                  ),
                  _promptChip(
                    context,
                    'Make me a quiz',
                    Icons.quiz_outlined,
                  ),
                  _promptChip(
                    context,
                    'Summarize my notes',
                    Icons.summarize_outlined,
                  ),
                  _promptChip(
                    context,
                    'Give me a study plan',
                    Icons.calendar_month_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 0,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.tips_and_updates_rounded, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tip: turn on Web Search when you need current guidelines, recent papers, or up-to-date facts.',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: .70),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _promptChip(BuildContext context, String prompt, IconData icon) {
    return ActionChip(
      onPressed: _isSending
          ? null
          : () {
              _messageController.text = prompt;
              _messageController.selection = TextSelection.collapsed(
                offset: _messageController.text.length,
              );
              _inputFocusNode.requestFocus();
            },
      avatar: Icon(icon, size: 18),
      label: Text(prompt),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    AiChatMessage message,
    int index,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = message.role == 'user';
    final content = message.content;
    final sources = _sourcesByMessage[index] ?? const <AiSource>[];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: isUser
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isUser ? 20 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 20),
                  ),
                  border: Border.all(
                    color: isUser
                        ? Colors.transparent
                        : scheme.outline.withValues(alpha: .08),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  child: isUser
                      ? Text(
                          _displayUserMessage(content),
                          style: TextStyle(
                            color: scheme.onPrimary,
                            height: 1.5,
                          ),
                        )
                      : content.isEmpty
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : MarkdownBody(
                              data: content,
                              selectable: true,
                              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                p: theme.textTheme.bodyLarge?.copyWith(
                                  height: 1.55,
                                ),
                                h1: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                h2: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                h3: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                code: TextStyle(
                                  fontFamily: 'monospace',
                                  color: scheme.onSurface,
                                ),
                                blockquoteDecoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: .06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border(
                                    left: BorderSide(
                                      color: scheme.primary,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
              if (!isUser && content.isNotEmpty) ...[
                if (sources.isNotEmpty) _buildSources(context, sources),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      tooltip: 'Copy',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copyMessage(content),
                      icon: const Icon(Icons.copy_all_rounded, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Regenerate',
                      visualDensity: VisualDensity.compact,
                      onPressed: _isSending ? null : _regenerateLastResponse,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Helpful',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showToast('Thanks for the feedback'),
                      icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _displayUserMessage(String content) {
    return content
        .replaceFirst(RegExp(r'^\[.*?Mode\] '), '')
        .trim();
  }

  Widget _buildSources(BuildContext context, List<AiSource> sources) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: sources.take(5).map((source) {
          return ActionChip(
            avatar: Icon(Icons.link_rounded, size: 15, color: scheme.primary),
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 230),
              child: Text(
                source.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            onPressed: () => Clipboard.setData(
              ClipboardData(text: source.uri),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasText = _messageController.text.trim().isNotEmpty;
    final hasAttachment = _selectedAttachment != null;
    final hasTools = _useWebSearch || _useCodeExecution;

    return Material(
      elevation: 10,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      avatar: Icon(_mode.icon, size: 17),
                      label: Text(_mode.label),
                      onPressed: _isSending ? null : _showModeSheet,
                    ),
                    const SizedBox(width: 8),
                    if (hasTools)
                      InputChip(
                        avatar: Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                        label: Text(
                          [
                            if (_useWebSearch) 'Web',
                            if (_useCodeExecution) 'Code',
                          ].join(' + '),
                        ),
                        onPressed: _isSending ? null : _showToolsSheet,
                        onDeleted: _isSending
                            ? null
                            : () {
                                setState(() {
                                  _useWebSearch = false;
                                  _useCodeExecution = false;
                                });
                              },
                      ),
                  ],
                ),
              ),
              if (hasAttachment) ...[
                const SizedBox(height: 7),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedAttachment!.isImage
                              ? Icons.image_rounded
                              : Icons.description_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 7),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            _selectedAttachment!.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          visualDensity: VisualDensity.compact,
                          onPressed: _removeAttachment,
                          icon: const Icon(Icons.close_rounded, size: 17),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Attach file',
                    onPressed: _isSending ? null : _pickFile,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _inputFocusNode,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) {
                        if (hasText || hasAttachment) {
                          _sendMessage();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: hasAttachment
                            ? 'Ask something about this file...'
                            : 'Ask MediData AI ...',
                        filled: true,
                        fillColor:
                            scheme.surfaceContainerHighest.withValues(alpha: .72),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed:
                        _isSending || (!hasText && !hasAttachment) ? null : _sendMessage,
                    icon: Icon(
                      _isSending
                          ? Icons.hourglass_top_rounded
                          : Icons.arrow_upward_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
