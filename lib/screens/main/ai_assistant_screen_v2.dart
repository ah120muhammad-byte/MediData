import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../services/ai_chat_history_service.dart';
import '../../services/ai_chat_service.dart';
import 'ai_live_screen.dart';

class AiAssistantScreenV2 extends StatefulWidget {
  const AiAssistantScreenV2({super.key});

  @override
  State<AiAssistantScreenV2> createState() => _AiAssistantScreenV2State();
}

enum _AiMode { smart, study, examPrep, summarize }

extension _AiModeX on _AiMode {
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

class _AiAssistantScreenV2State extends State<AiAssistantScreenV2> {
  final AiChatService _aiService = AiChatService();
  final AiChatHistoryService _historyService = AiChatHistoryService.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<AiChatMessage> _messages = <AiChatMessage>[];

  String? _chatSessionId;
  bool _isLoadingHistory = true;
  bool _isLoadingSessions = false;
  bool _isSending = false;
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

      if (_messages.isNotEmpty) await _scrollToBottom(animated: false);
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

  Future<void> _loadSession(String sessionId) async {
    if (_isSending || sessionId.trim().isEmpty) return;

    Navigator.of(context).pop();
    setState(() => _isLoadingHistory = true);

    try {
      final messages = await _historyService.loadMessages(sessionId);
      await _historyService.setCurrentSessionId(sessionId);
      if (!mounted) return;
      setState(() {
        _chatSessionId = sessionId;
        _messages
          ..clear()
          ..addAll(messages);
        _selectedAttachment = null;
        _mode = _AiMode.smart;
        _isLoadingHistory = false;
      });
      await _scrollToBottom(animated: false);
      _inputFocusNode.requestFocus();
    } catch (e, stackTrace) {
      debugPrint('AI session load error: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        _showError('Unable to open this conversation.');
      }
    }
  }

  Future<void> _openHistoryDrawer() async {
    if (_isLoadingSessions) return;
    setState(() => _isLoadingSessions = true);

    try {
      final sessions = await _historyService.loadSessions();
      if (!mounted) return;
      setState(() => _isLoadingSessions = false);

      Scaffold.of(context).openDrawer();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (!mounted) return;
      await _showHistorySheet(sessions);
    } catch (e, stackTrace) {
      debugPrint('AI sessions load error: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        setState(() => _isLoadingSessions = false);
        _showError('Unable to load chat history.');
      }
    }
  }

  Future<void> _showHistorySheet(List<AiChatSession> sessions) async {
    if (!mounted) return;

    final selectedId = _chatSessionId;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .82,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
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
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          itemCount: sessions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            final selected = session.id == selectedId;
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              selected: selected,
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: .08),
                              leading: Icon(
                                selected
                                    ? Icons.forum_rounded
                                    : Icons.chat_bubble_outline_rounded,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              title: Text(
                                session.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(_sessionDateLabel(session.updatedAt)),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'delete') {
                                    await _confirmDeleteSession(session);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
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
      return;
    }
    await _loadSession(result);
  }

  Future<void> _confirmDeleteSession(AiChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text('This conversation and its messages will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _historyService.deleteSession(session.id);
      if (!mounted) return;
      if (_chatSessionId == session.id) {
        final newId = await _historyService.createSession(title: 'New chat');
        if (!mounted) return;
        setState(() {
          _chatSessionId = newId;
          _messages.clear();
        });
      }
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) _showError('Unable to delete this conversation.');
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
    final userMessage = instruction.isEmpty ? rawUserMessage : '$instruction\n\n$rawUserMessage';
    final userChatMessage = AiChatMessage(role: 'user', content: userMessage);
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
        final assistantMessage = AiChatMessage(role: 'assistant', content: response.reply);
        setState(() {
          _messages.add(assistantMessage);
          _isSending = false;
        });
        await _saveMessageToHistory(assistantMessage);
      } else {
        final assistantIndex = _messages.length;
        setState(() {
          _messages.add(const AiChatMessage(role: 'assistant', content: ''));
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
        final assistantMessage = AiChatMessage(role: 'assistant', content: response.reply);
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

    final assistantIndex = _messages.lastIndexWhere((message) => message.role == 'assistant');
    if (assistantIndex < 0) return;
    final userIndex = assistantIndex - 1;
    if (userIndex < 0 || _messages[userIndex].role != 'user') return;

    final previousMessages = _messages.sublist(0, userIndex + 1);
    setState(() {
      _messages[assistantIndex] = const AiChatMessage(role: 'assistant', content: '');
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
      setState(() {
        _messages[assistantIndex] = AiChatMessage(role: 'assistant', content: response.reply);
        _isSending = false;
      });
      await _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _messages[assistantIndex] = const AiChatMessage(role: 'assistant', content: '');
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
        content: const Text('Your current conversation will remain saved and a new conversation will start.'),
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
        _selectedAttachment = null;
        _mode = _AiMode.smart;
        _messageController.clear();
      });
      _inputFocusNode.requestFocus();
      await _scrollToBottom(animated: false);
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
          'jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf', 'txt', 'md', 'docx', 'pptx'
        ],
      );
      if (pickedFile == null) return;

      final fileSize = await pickedFile.length();
      if (fileSize <= 0) { _showError('The selected file is empty.'); return; }
      if (fileSize > AiChatService.maxFileBytes) { _showError('File size must be 20 MB or less.'); return; }

      final fileName = pickedFile.name;
      if (!AiChatService.isSupportedFile(fileName)) { _showError('This file type is not supported.'); return; }

      final bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) { _showError('Unable to read the selected file.'); return; }

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

  Future<void> _openLiveMode() async {
    if (_isSending || !mounted) return;
    _inputFocusNode.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiLiveScreen(mode: _mode.name)),
    );
    if (mounted) _inputFocusNode.requestFocus();
  }

  void _showModeSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                  (mode) => ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Icon(mode.icon),
                    title: Text(mode.label),
                    subtitle: Text(mode.description),
                    trailing: _mode == mode
                        ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                        : null,
                    onTap: () {
                      setState(() => _mode = mode);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scrollToBottom({bool animated = true}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted || !_scrollController.hasClients) return;
    final offset = _scrollController.position.maxScrollExtent;
    if (!animated) {
      _scrollController.jumpTo(offset);
      return;
    }
    await _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  String _cleanErrorMessage(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception:')) return text.substring('Exception:'.length).trim();
    return text.isEmpty ? 'Unable to get an AI response. Please try again.' : text;
  }

  String _sessionDateLabel(DateTime? value) {
    if (value == null) return 'Saved conversation';
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final days = today.difference(date).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days}d ago';
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: scheme.surface,
      drawer: _buildHistoryDrawer(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Chat history',
            onPressed: _isSending ? null : () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu_rounded),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MediData AI', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              _mode.label,
              style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: .55)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Live',
            onPressed: _isSending ? null : _openLiveMode,
            icon: const Icon(Icons.graphic_eq_rounded),
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

  Widget _buildHistoryDrawer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      width: MediaQuery.sizeOf(context).width.clamp(280.0, 380.0),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
              child: Row(
                children: [
                  Icon(Icons.forum_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Chat history', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'New chat',
                    onPressed: _isSending ? null : _startNewChat,
                    icon: const Icon(Icons.add_comment_outlined),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<AiChatSession>>(
                future: _historyService.loadSessions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: FilledButton.tonal(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    );
                  }

                  final sessions = snapshot.data ?? const <AiChatSession>[];
                  if (sessions.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text('Your saved conversations will appear here.'),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 20),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final selected = session.id == _chatSessionId;
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        selected: selected,
                        selectedTileColor: scheme.primary.withValues(alpha: .09),
                        leading: Icon(
                          selected ? Icons.chat_rounded : Icons.chat_bubble_outline_rounded,
                          color: selected ? scheme.primary : null,
                        ),
                        title: Text(
                          session.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w650),
                        ),
                        subtitle: Text(_sessionDateLabel(session.updatedAt)),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          onPressed: _isSending ? null : () => _confirmDeleteSession(session),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                        onTap: () => _loadSession(session.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesArea(BuildContext context) {
    if (_messages.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 50),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 38,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'How can I help you study?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ask about lectures, anatomy, physiology, pharmacology, or exam preparation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .58),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _SuggestionChip(label: 'Explain a concept', onTap: () => _useSuggestion('Explain this medical concept step by step.')),
                    _SuggestionChip(label: 'Make exam notes', onTap: () => _useSuggestion('Turn this topic into high-yield exam notes.')),
                    _SuggestionChip(label: 'Quiz me', onTap: () => _useSuggestion('Quiz me with 5 questions and explain my mistakes.')),
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
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isLast = index == _messages.length - 1;
        return _buildMessage(context, message, isLast);
      },
    );
  }

  Widget _buildMessage(BuildContext context, AiChatMessage message, bool isLast) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == 'user';
    final content = message.content;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .13),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(content, style: const TextStyle(height: 1.5)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 17, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: content.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: _TypingIndicator(),
                      )
                    : MarkdownBody(
                        data: content,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 15, height: 1.62),
                          h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                          h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          h3: const TextStyle(fontSize: 17, fontWeight: FontWeight.w750),
                          blockquote: TextStyle(
                            color: scheme.onSurface.withValues(alpha: .70),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          if (content.isNotEmpty && (!isLast || !_isSending))
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 8),
              child: Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copyText(content),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                  if (isLast)
                    IconButton(
                      tooltip: 'Regenerate',
                      visualDensity: VisualDensity.compact,
                      onPressed: _isSending ? null : _regenerateLastResponse,
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedAttachment != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedAttachment!.isImage
                            ? Icons.image_rounded
                            : Icons.insert_drive_file_rounded,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
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
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
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
                    onPressed: _isSending ? null : _pickFile,
                    icon: const Icon(Icons.add_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _inputFocusNode,
                      enabled: !_isLoadingHistory,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: _selectedAttachment == null ? 'Ask MediData AI' : 'Add a message about the file...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        suffixIcon: _messageController.text.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                visualDensity: VisualDensity.compact,
                                onPressed: _isSending ? null : _messageController.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Choose mode',
                    onPressed: _isSending ? null : _showModeSheet,
                    icon: Icon(_mode.icon, color: scheme.primary),
                  ),
                  const SizedBox(width: 2),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _isSending || _messageController.text.trim().isEmpty && _selectedAttachment == null
                        ? null
                        : _sendMessage,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _useSuggestion(String value) {
    _messageController.text = value;
    _messageController.selection = TextSelection.collapsed(offset: value.length);
    _inputFocusNode.requestFocus();
  }

  Future<void> _copyText(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied to clipboard.')),
      );
    }
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = (_controller.value * 3).floor();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Opacity(
                opacity: index == value ? 1 : .35,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
    );
  }
}
