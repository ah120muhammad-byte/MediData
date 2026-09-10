import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../services/ai_chat_history_service.dart';
import '../../services/ai_chat_service.dart';
import 'ai_live_screen.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

enum _AiMode { smart, study, examPrep, summarize }

extension on _AiMode {
  String get label => switch (this) {
    _AiMode.smart => 'Smart',
    _AiMode.study => 'Study tutor',
    _AiMode.examPrep => 'Exam prep',
    _AiMode.summarize => 'Summarize',
  };

  String get description => switch (this) {
    _AiMode.smart => 'Best general answer',
    _AiMode.study => 'Explain, teach and quiz me',
    _AiMode.examPrep => 'High-yield revision',
    _AiMode.summarize => 'Condense notes and files',
  };

  IconData get icon => switch (this) {
    _AiMode.smart => Icons.auto_awesome_rounded,
    _AiMode.study => Icons.school_rounded,
    _AiMode.examPrep => Icons.quiz_rounded,
    _AiMode.summarize => Icons.summarize_rounded,
  };
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final AiChatService _aiService = AiChatService();
  final AiChatHistoryService _historyService = AiChatHistoryService.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<AiChatMessage> _messages = <AiChatMessage>[];

  String? _chatSessionId;
  bool _loading = true;
  bool _sending = false;
  AiAttachment? _attachment;
  _AiMode _mode = _AiMode.smart;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_refresh);
    _loadConversation();
  }

  @override
  void dispose() {
    _messageController.removeListener(_refresh);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadConversation() async {
    try {
      var sessionId = await _historyService.getCurrentSessionId();
      if (sessionId == null || sessionId.isEmpty) {
        sessionId = await _historyService.createSession(title: 'New chat');
      }
      final messages = await _historyService.loadMessages(sessionId);
      if (!mounted) return;
      setState(() {
        _chatSessionId = sessionId;
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
      });
      await _scrollToBottom(animated: false);
    } catch (e, stackTrace) {
      debugPrint('AI history load error: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Unable to load AI chat.');
    }
  }

  Future<void> _showHistory() async {
    try {
      final sessions = await _historyService.loadSessions();
      if (!mounted) return;

      final selectedId = _chatSessionId;
      final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          final scheme = Theme.of(sheetContext).colorScheme;
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .82,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Chat history',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: 'New chat',
                          onPressed: () => Navigator.of(sheetContext).pop('__new__'),
                          icon: const Icon(Icons.add_comment_outlined),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: sessions.isEmpty
                        ? const Center(child: Text('No saved conversations yet.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: sessions.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 3),
                            itemBuilder: (context, index) {
                              final session = sessions[index];
                              final selected = session.id == selectedId;
                              return ListTile(
                                selected: selected,
                                selectedTileColor: scheme.primary.withValues(alpha: .09),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                leading: Icon(
                                  selected ? Icons.forum_rounded : Icons.chat_bubble_outline_rounded,
                                  color: selected ? scheme.primary : null,
                                ),
                                title: Text(
                                  session.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(_dateLabel(session.updatedAt)),
                                trailing: IconButton(
                                  tooltip: 'Delete',
                                  onPressed: _sending ? null : () => _deleteSession(session),
                                  icon: const Icon(Icons.delete_outline_rounded),
                                ),
                                onTap: () => Navigator.of(sheetContext).pop(session.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (!mounted || result == null) return;
      if (result == '__new__') {
        await _startNewChat();
      } else {
        await _loadSession(result);
      }
    } catch (e, stackTrace) {
      debugPrint('AI history error: $e');
      debugPrint(stackTrace.toString());
      if (mounted) _showError('Unable to load chat history.');
    }
  }

  Future<void> _loadSession(String id) async {
    if (_sending) return;
    setState(() => _loading = true);
    try {
      final messages = await _historyService.loadMessages(id);
      await _historyService.setCurrentSessionId(id);
      if (!mounted) return;
      setState(() {
        _chatSessionId = id;
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
        _attachment = null;
      });
      await _scrollToBottom(animated: false);
      _inputFocusNode.requestFocus();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Unable to open this conversation.');
      }
    }
  }

  Future<void> _deleteSession(AiChatSession session) async {
    try {
      await _historyService.deleteSession(session.id);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      if (_chatSessionId == session.id) {
        await _startNewChat(confirm: false);
      }
    } catch (e) {
      if (mounted) _showError('Unable to delete this conversation.');
    }
  }

  Future<void> _startNewChat({bool confirm = true}) async {
    if (_sending) return;
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Start a new chat?'),
          content: const Text('Your current conversation will remain saved.'),
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
      if (ok != true || !mounted) return;
    }

    try {
      final newId = await _historyService.createSession(title: 'New chat');
      if (!mounted) return;
      setState(() {
        _chatSessionId = newId;
        _messages.clear();
        _attachment = null;
        _mode = _AiMode.smart;
      });
      _inputFocusNode.requestFocus();
    } catch (e) {
      if (mounted) _showError('Unable to start a new chat.');
    }
  }

  Future<void> _send() async {
    if (_sending || _loading) return;
    final text = _messageController.text.trim();
    final attachment = _attachment;
    if (text.isEmpty && attachment == null) return;

    final instruction = switch (_mode) {
      _AiMode.smart => '',
      _AiMode.study => '[Study Tutor Mode] Teach step-by-step and check understanding.',
      _AiMode.examPrep => '[Exam Prep Mode] Focus on high-yield facts, traps and memory aids.',
      _AiMode.summarize => '[Summarize Mode] Summarize the source into key ideas and revision points.',
    };
    final userText = text.isEmpty
        ? 'Please analyze the attached file and explain the important points.'
        : text;
    final content = instruction.isEmpty ? userText : '$instruction\n\n$userText';
    final user = AiChatMessage(role: 'user', content: content);
    final outgoing = [..._messages, user];

    setState(() {
      _messages.add(user);
      _messageController.clear();
      _attachment = null;
      _sending = true;
    });
    await _ensureSession();
    await _historyService.saveMessage(sessionId: _chatSessionId!, message: user);
    await _historyService.updateTitle(
      sessionId: _chatSessionId!,
      title: _buildTitle(userText),
    );
    await _scrollToBottom();

    try {
      if (attachment != null) {
        final response = await _aiService.sendMessageWithAttachment(
          messages: outgoing,
          attachment: attachment,
          mode: _mode.name,
        );
        if (!mounted) return;
        final assistant = AiChatMessage(role: 'assistant', content: response.reply);
        setState(() {
          _messages.add(assistant);
          _sending = false;
        });
        await _historyService.saveMessage(sessionId: _chatSessionId!, message: assistant);
      } else {
        final assistantIndex = _messages.length;
        setState(() => _messages.add(const AiChatMessage(role: 'assistant', content: '')));
        final response = await _aiService.sendMessageStreaming(
          messages: outgoing,
          mode: _mode.name,
          onText: (partial) {
            if (!mounted) return;
            setState(() {
              _messages[assistantIndex] = AiChatMessage(role: 'assistant', content: partial);
            });
            unawaited(_scrollToBottom());
          },
        );
        if (!mounted) return;
        final assistant = AiChatMessage(role: 'assistant', content: response.reply);
        setState(() {
          _messages[assistantIndex] = assistant;
          _sending = false;
        });
        await _historyService.saveMessage(sessionId: _chatSessionId!, message: assistant);
      }
      await _scrollToBottom();
      if (mounted) _inputFocusNode.requestFocus();
    } catch (e, stackTrace) {
      debugPrint('AI send error: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (_messages.isNotEmpty &&
            _messages.last.role == 'assistant' &&
            _messages.last.content.isEmpty) {
          _messages.removeLast();
        }
      });
      _showError(_cleanError(e));
    }
  }

  Future<void> _ensureSession() async {
    if (_chatSessionId != null && _chatSessionId!.isNotEmpty) return;
    _chatSessionId = await _historyService.createSession(title: 'New chat');
  }

  Future<void> _regenerate() async {
    if (_sending || _messages.length < 2) return;
    final assistantIndex = _messages.lastIndexWhere((m) => m.role == 'assistant');
    if (assistantIndex < 1) return;
    final userIndex = assistantIndex - 1;
    if (_messages[userIndex].role != 'user') return;

    final outgoing = _messages.sublist(0, userIndex + 1);
    setState(() {
      _sending = true;
      _messages[assistantIndex] = const AiChatMessage(role: 'assistant', content: '');
    });

    try {
      final response = await _aiService.sendMessageStreaming(
        messages: outgoing,
        mode: _mode.name,
        onText: (partial) {
          if (!mounted) return;
          setState(() {
            _messages[assistantIndex] = AiChatMessage(role: 'assistant', content: partial);
          });
          unawaited(_scrollToBottom());
        },
      );
      if (!mounted) return;
      final assistant = AiChatMessage(role: 'assistant', content: response.reply);
      setState(() {
        _messages[assistantIndex] = assistant;
        _sending = false;
      });
      if (_chatSessionId != null) {
        await _historyService.saveMessage(sessionId: _chatSessionId!, message: assistant);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _showError(_cleanError(e));
    }
  }

  Future<void> _pickFile() async {
    if (_sending) return;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf', 'txt', 'md', 'docx', 'pptx'
        ],
      );
      if (file == null) return;
      final size = await file.length();
      if (size <= 0) return _showError('The selected file is empty.');
      if (size > AiChatService.maxFileBytes) return _showError('File size must be 20 MB or less.');
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        final mime = AiChatService.mimeTypeForFile(file.name);
        _attachment = AiAttachment(
          fileName: file.name,
          mimeType: mime,
          bytes: bytes,
          isImage: mime.startsWith('image/'),
        );
      });
      _inputFocusNode.requestFocus();
    } catch (e) {
      if (mounted) _showError(_cleanError(e));
    }
  }

  Future<void> _openLive() async {
    if (_sending) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiLiveScreen(mode: _mode.name)),
    );
    if (mounted) _inputFocusNode.requestFocus();
  }

  void _chooseMode() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Choose AI mode', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 8),
              ..._AiMode.values.map(
                (mode) => ListTile(
                  leading: Icon(mode.icon),
                  title: Text(mode.label),
                  subtitle: Text(mode.description),
                  trailing: _mode == mode ? const Icon(Icons.check_circle_rounded) : null,
                  onTap: () {
                    setState(() => _mode = mode);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scrollToBottom({bool animated = true}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted || !_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (!animated) {
      _scrollController.jumpTo(target);
    } else {
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  String _buildTitle(String text) {
    final value = text.trim();
    if (value.isEmpty) return 'New chat';
    return value.length <= 60 ? value : '${value.substring(0, 60)}...';
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Saved conversation';
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final days = today.difference(date).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days > 1 && days < 7) return '${days}d ago';
    return '${local.day}/${local.month}/${local.year}';
  }

  String _cleanError(Object error) {
    final text = error.toString().trim();
    return text.startsWith('Exception:')
        ? text.substring('Exception:'.length).trim()
        : (text.isEmpty ? 'Unable to get an AI response. Please try again.' : text);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 420;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: scheme.surface,
        titleSpacing: compact ? 4 : 12,
        leading: IconButton(
          tooltip: 'Chat history',
          onPressed: _sending ? null : _showHistory,
          icon: const Icon(Icons.menu_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MediData AI', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(_mode.label, style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: .55))),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Live AI',
            onPressed: _sending ? null : _openLive,
            icon: const Icon(Icons.graphic_eq_rounded),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: _sending ? null : _startNewChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(child: _buildMessages()),
                  _buildComposer(),
                ],
              ),
            ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 58, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              const Text('How can I help you study?', textAlign: TextAlign.center, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Ask about lectures, medical concepts, or exam preparation.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55))),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Suggestion(text: 'Explain a concept', onTap: () => _useSuggestion('Explain this medical concept step by step.')),
                  _Suggestion(text: 'Revision notes', onTap: () => _useSuggestion('Turn this topic into high-yield revision notes.')),
                  _Suggestion(text: 'Quiz me', onTap: () => _useSuggestion('Quiz me with 5 questions and explain my mistakes.')),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessage(_messages[index], index),
    );
  }

  Widget _buildMessage(AiChatMessage message, int index) {
    final scheme = Theme.of(context).colorScheme;
    final user = message.role == 'user';
    final content = message.content;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820),
        margin: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: user ? scheme.primary.withValues(alpha: .13) : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: user
                  ? Text(content, style: const TextStyle(height: 1.5))
                  : content.isEmpty
                      ? const _TypingIndicator()
                      : MarkdownBody(
                          data: content,
                          selectable: true,
                          styleSheet:  MarkdownStyleSheet(
                            p: TextStyle(fontSize: 15, height: 1.6),
                            h1: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                            h2: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            h3: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                        ),
            ),
            if (!user && content.isNotEmpty && !_sending)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copyText(content),
                    icon: const Icon(Icons.copy_rounded, size: 17),
                  ),
                  if (index == _messages.lastIndexWhere((item) => item.role == 'assistant'))
                    IconButton(
                      tooltip: 'Regenerate',
                      visualDensity: VisualDensity.compact,
                      onPressed: _regenerate,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_attachment != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_attachment!.isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded, size: 18),
                        const SizedBox(width: 7),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(_attachment!.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          visualDensity: VisualDensity.compact,
                          onPressed: _sending ? null : () => setState(() => _attachment = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .70),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: scheme.outline.withValues(alpha: .10)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Attach file',
                      onPressed: _sending ? null : _pickFile,
                      icon: const Icon(Icons.add_rounded),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _inputFocusNode,
                        minLines: 1,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          hintText: 'Ask MediData AI...',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Choose mode',
                      onPressed: _sending ? null : _chooseMode,
                      icon: Icon(_mode.icon, color: scheme.primary),
                    ),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: _sending || (_messageController.text.trim().isEmpty && _attachment == null) ? null : _send,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _useSuggestion(String text) {
    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(offset: text.length);
    _inputFocusNode.requestFocus();
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _showError('Copied to clipboard.');
  }
}

class _Suggestion extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _Suggestion({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: Text(text),
      onPressed: onTap,
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color.withValues(alpha: .65), shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
