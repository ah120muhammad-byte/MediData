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

  String? _chatSessionId;
  bool _isLoadingHistory = true;
  bool _isSending = false;
  AiAttachment? _selectedAttachment;
  _AiMode _mode = _AiMode.smart;

  @override
  void initState() {
    super.initState();
    _loadSavedConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConversation() async {
    try {
      final existingSessionId = await _historyService.getCurrentSessionId();
      if (existingSessionId == null || existingSessionId.isEmpty) {
        final newSessionId = await _historyService.createSession(
          title: 'New chat',
        );
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
        final newSessionId = await _historyService.createSession(
          title: 'New chat',
        );
        if (!mounted) return;
        setState(() {
          _chatSessionId = newSessionId;
          _isLoadingHistory = false;
        });
      } catch (sessionError) {
        debugPrint('AI session create error: $sessionError');
        if (mounted) {
          setState(() => _isLoadingHistory = false);
        }
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
        final userMessages = _messages.where((item) => item.role == 'user');
        if (userMessages.length == 1) {
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

  String _modeInstruction() {
    switch (_mode) {
      case _AiMode.smart:
        return '';
      case _AiMode.study:
        return '[Study Tutor Mode] Teach the concept step-by-step, build a clear mental model, and finish with a few quick-check questions when helpful.';
      case _AiMode.examPrep:
        return '[Exam Prep Mode] Focus on high-yield facts, common traps, clinical correlations, and concise memory aids.';
      case _AiMode.summarize:
        return '[Summarize Mode] Summarize the provided content into key ideas, definitions, tables, and revision points. Stay faithful to the source.';
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
        );

        if (!mounted) return;
        final assistantMessage = AiChatMessage(
          role: 'assistant',
          content: response.reply,
        );
        setState(() {
          _messages.add(assistantMessage);
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
    setState(() {
      _messages[assistantIndex] =
          const AiChatMessage(role: 'assistant', content: '');
      _isSending = true;
    });

    try {
      final response = await _aiService.sendMessageStreaming(
        messages: previousMessages,
        mode: _mode.name,
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
        _isSending = false;
      });
      await _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages[assistantIndex] =
            const AiChatMessage(role: 'assistant', content: '');
      });
      _showError(_cleanErrorMessage(e));
    }
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
      final newSessionId = await _historyService.createSession(
        title: 'New chat',
      );
      if (!mounted) return;
      setState(() {
        _chatSessionId = newSessionId;
        _messages.clear();
        _selectedAttachment = null;
        _mode = _AiMode.smart;
        _messageController.clear();
      });
      _inputFocusNode.requestFocus();
    } catch (e, stackTrace) {
      debugPrint('Create new AI chat error: $e');
      debugPrint(stackTrace.toString());
      if (mounted) _showError('Unable to start a new chat.');
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

  void _showModeSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final keyboardInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 12 + keyboardInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choose AI mode',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._AiMode.values.map(
                      (mode) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Icon(mode.icon),
                        title: Text(mode.label),
                        subtitle: Text(
                          mode.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _mode == mode
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: Theme.of(sheetContext)
                                    .colorScheme
                                    .primary,
                              )
                            : null,
                        onTap: _isSending
                            ? null
                            : () {
                                setState(() => _mode = mode);
                                Navigator.of(sheetContext).pop();
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isCompact = width < 420;
    final isWide = width >= 900;
    final horizontalPadding = isCompact ? 10.0 : (width < 600 ? 14.0 : 20.0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: isCompact ? 4 : 12,
        toolbarHeight: isCompact ? 56 : 64,
        title: Row(
          children: [
            Container(
              width: isCompact ? 34 : 38,
              height: isCompact ? 34 : 38,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(isCompact ? 10 : 11),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: isCompact ? 19 : 21,
                color: scheme.primary,
              ),
            ),
            SizedBox(width: isCompact ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MediData AI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 15 : 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _mode.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 10.5 : 11,
                      color: scheme.onSurface.withValues(alpha: .55),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'AI mode',
            visualDensity: isCompact ? VisualDensity.compact : null,
            onPressed: _isSending ? null : _showModeSheet,
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'New chat',
            visualDensity: isCompact ? VisualDensity.compact : null,
            onPressed: _isSending ? null : _startNewChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      Expanded(
                        child: _buildMessagesArea(
                          context,
                          horizontalPadding: horizontalPadding,
                          maxWidth: isWide ? 900 : 780,
                        ),
                      ),
                      _buildComposer(
                        context,
                        horizontalPadding: horizontalPadding,
                        keyboardOpen: keyboardOpen,
                        availableHeight: constraints.maxHeight,
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildMessagesArea(
    BuildContext context, {
    required double horizontalPadding,
    required double maxWidth,
  }) {
    final width = MediaQuery.sizeOf(context).width;

    if (_messages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            18,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width < 600 ? 620 : maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: width < 420 ? 50 : 58,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: .75),
                ),
                const SizedBox(height: 12),
                Text(
                  'How can I help you study?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: width < 420 ? 20 : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ask about lectures, medical concepts, or exam preparation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .55),
                    height: 1.45,
                    fontSize: width < 420 ? 13 : 14,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickPrompt(
                      text: 'Explain a concept',
                      onTap: () => _setPrompt('Explain this concept simply: '),
                    ),
                    _QuickPrompt(
                      text: 'Revision notes',
                      onTap: () =>
                          _setPrompt('Turn this into high-yield revision notes: '),
                    ),
                    _QuickPrompt(
                      text: 'Quiz me',
                      onTap: () =>
                          _setPrompt('Quiz me on this topic with 5 questions: '),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        18,
        horizontalPadding,
        16,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: _buildMessageBubble(
              context,
              _messages[index],
              index,
            ),
          ),
        );
      },
    );
  }

  void _setPrompt(String prompt) {
    _messageController
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
    _inputFocusNode.requestFocus();
  }

  Widget _buildMessageBubble(
    BuildContext context,
    AiChatMessage message,
    int index,
  ) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final bool isUser = message.role == 'user';
    final content = message.content;
    final bubbleMaxWidth = width < 420
        ? width * .92
        : width < 700
            ? width * .86
            : 780.0;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              width: isUser ? null : double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: width < 420 ? 13 : 16,
                vertical: width < 420 ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(width < 420 ? 16 : 18),
              ),
              child: isUser
                  ? Text(
                      content,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        height: 1.45,
                        fontSize: width < 420 ? 14 : 15,
                      ),
                    )
                  : content.isEmpty
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : MarkdownBody(
                          data: content,
                          selectable: true,
                        ),
            ),
            if (!isUser && content.trim().isNotEmpty && !_isSending)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Copy',
                      onPressed: () => _copyMessage(content),
                      icon: const Icon(Icons.copy_rounded, size: 17),
                    ),
                    if (index == _messages.lastIndexWhere(
                      (item) => item.role == 'assistant',
                    ))
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Regenerate',
                        onPressed: _regenerateLastResponse,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(
    BuildContext context, {
    required double horizontalPadding,
    required bool keyboardOpen,
    required double availableHeight,
  }) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 420;
    final isWide = width >= 900;
    final maxWidth = isWide ? 900.0 : double.infinity;

    // Keep the composer small while the keyboard is open. This prevents the
    // text field from consuming the already-reduced viewport height.
    final maxLines = keyboardOpen
        ? (isCompact ? 2 : 3)
        : (isCompact ? 4 : 6);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isCompact ? 5 : 8,
                horizontalPadding,
                isCompact ? 6 : 10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedAttachment != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _AttachmentChip(
                          attachment: _selectedAttachment!,
                          onRemove: _removeAttachment,
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Attach file',
                        visualDensity:
                            isCompact ? VisualDensity.compact : null,
                        onPressed: _isSending ? null : _pickFile,
                        icon: const Icon(Icons.attach_file_rounded),
                      ),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: keyboardOpen
                                ? (isCompact ? 78 : 104)
                                : (isCompact ? 130 : 180),
                          ),
                          child: TextField(
                            controller: _messageController,
                            focusNode: _inputFocusNode,
                            minLines: 1,
                            maxLines: maxLines,
                            textInputAction: TextInputAction.newline,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: _selectedAttachment == null
                                  ? 'Ask MediData AI...'
                                  : 'Add a message about the file...',
                              filled: true,
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  isCompact ? 19 : 22,
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 13 : 16,
                                vertical: isCompact ? 10 : 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isCompact ? 3 : 6),
                      IconButton.filled(
                        tooltip: 'Send',
                        visualDensity:
                            isCompact ? VisualDensity.compact : null,
                        onPressed: _isSending ? null : _sendMessage,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPrompt extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _QuickPrompt({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      height: width < 420 ? 36 : 40,
      child: ActionChip(
        avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
        label: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: onTap,
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final AiAttachment attachment;
  final VoidCallback onRemove;

  const _AttachmentChip({
    required this.attachment,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = (width - 40).clamp(180.0, 520.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              attachment.isImage
                  ? Icons.image_rounded
                  : Icons.insert_drive_file_rounded,
              size: 18,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                attachment.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
