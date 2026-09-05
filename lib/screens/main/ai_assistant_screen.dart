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
      final String? existingSessionId = await _historyService.getCurrentSessionId();
      if (existingSessionId == null || existingSessionId.isEmpty) {
        final String newSessionId = await _historyService.createSession(title: 'New chat');
        if (!mounted) return;
        setState(() { _chatSessionId = newSessionId; _isLoadingHistory = false; });
        return;
      }
      final List<AiChatMessage> savedMessages = await _historyService.loadMessages(existingSessionId);
      if (!mounted) return;
      setState(() {
        _chatSessionId = existingSessionId;
        _messages..clear()..addAll(savedMessages);
        _isLoadingHistory = false;
      });
      if (_messages.isNotEmpty) await _scrollToBottom(animated: false);
    } catch (e, stackTrace) {
      debugPrint('AI history load error: $e');
      debugPrint(stackTrace.toString());
      try {
        final String newSessionId = await _historyService.createSession(title: 'New chat');
        if (!mounted) return;
        setState(() { _chatSessionId = newSessionId; _isLoadingHistory = false; });
      } catch (sessionError) {
        debugPrint('AI session create error: $sessionError');
        if (mounted) setState(() { _isLoadingHistory = false; });
      }
    }
  }

  Future<void> _saveMessageToHistory(AiChatMessage message) async {
    try {
      if (_chatSessionId == null || _chatSessionId!.isEmpty) {
        _chatSessionId = await _historyService.createSession(title: _buildSessionTitle(message));
      }
      await _historyService.saveMessage(sessionId: _chatSessionId!, message: message);
      if (message.role == 'user') {
        final savedMessageCount = _messages.where((item) => item.role == 'user');
        if (savedMessageCount.length == 1) {
          await _historyService.updateTitle(sessionId: _chatSessionId!, title: _buildSessionTitle(message));
        }
      }
    } catch (e, stackTrace) {
      debugPrint('AI save message error: $e');
      debugPrint(stackTrace.toString());
    }
  }

  String _buildSessionTitle(AiChatMessage message) {
    final String text = message.content.trim();
    if (text.isEmpty) return 'New chat';
    return text.length <= 60 ? text : '${text.substring(0, 60)}...';
  }

  Future<void> _startNewChat() async {
    if (_isSending || _isLoadingHistory) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start a new chat?'),
        content: const Text('Your current conversation will remain saved. A new conversation will be started.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('New Chat')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final String newSessionId = await _historyService.createSession(title: 'New chat');
      if (!mounted) return;
      setState(() {
        _chatSessionId = newSessionId;
        _messages.clear();
        _selectedAttachment = null;
        _messageController.clear();
      });
      _inputFocusNode.requestFocus();
    } catch (e, stackTrace) {
      debugPrint('Create new AI chat error: $e');
      debugPrint(stackTrace.toString());
      if (mounted) _showError('Unable to start a new chat.');
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending || _isLoadingHistory) return;
    final String text = _messageController.text.trim();
    final AiAttachment? attachment = _selectedAttachment;
    if (text.isEmpty && attachment == null) return;
    final String userMessage = text.isEmpty ? 'Please analyze the attached file and explain the important points.' : text;
    final AiChatMessage userChatMessage = AiChatMessage(role: 'user', content: userMessage);
    final List<AiChatMessage> outgoingMessages = [..._messages, userChatMessage];

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
        final response = await _aiService.sendMessageWithAttachment(messages: outgoingMessages, attachment: attachment);
        if (!mounted) return;
        final assistantMessage = AiChatMessage(role: 'assistant', content: response.reply);
        setState(() { _messages.add(assistantMessage); _isSending = false; });
        await _saveMessageToHistory(assistantMessage);
      } else {
        final int assistantIndex = _messages.length;
        setState(() => _messages.add(const AiChatMessage(role: 'assistant', content: '')));
        await _aiService.sendMessageStreaming(
          messages: outgoingMessages,
          onText: (partialText) {
            if (!mounted) return;
            setState(() {
              _messages[assistantIndex] = AiChatMessage(role: 'assistant', content: partialText);
            });
            unawaited(_scrollToBottom());
          },
        ).then((response) async {
          if (!mounted) return;
          final assistantMessage = AiChatMessage(role: 'assistant', content: response.reply);
          setState(() { _messages[assistantIndex] = assistantMessage; _isSending = false; });
          await _saveMessageToHistory(assistantMessage);
        });
      }
      await _scrollToBottom();
      if (mounted) _inputFocusNode.requestFocus();
    } catch (e, stackTrace) {
      debugPrint('AI send error: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        _isSending = false;
        if (_messages.isNotEmpty && _messages.last.role == 'assistant' && _messages.last.content.trim().isEmpty) _messages.removeLast();
      });
      _showError(_cleanErrorMessage(e));
      _inputFocusNode.requestFocus();
    }
  }

  Future<void> _pickFile() async {
    if (_isSending) return;
    try {
      final PlatformFile? pickedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg','jpeg','png','webp','gif','pdf','txt','md','docx','pptx'],
      );
      if (pickedFile == null) return;
      final int fileSize = await pickedFile.length();
      if (fileSize <= 0) { _showError('The selected file is empty.'); return; }
      if (fileSize > AiChatService.maxFileBytes) { _showError('File size must be 20 MB or less.'); return; }
      final String fileName = pickedFile.name;
      if (!AiChatService.isSupportedFile(fileName)) { _showError('This file type is not supported.'); return; }
      final Uint8List bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) { _showError('Unable to read the selected file.'); return; }
      final String mimeType = AiChatService.mimeTypeForFile(fileName);
      if (!mounted) return;
      setState(() {
        _selectedAttachment = AiAttachment(fileName: fileName, mimeType: mimeType, bytes: bytes, isImage: mimeType.startsWith('image/'));
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

  Future<void> _scrollToBottom({bool animated = true}) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted || !_scrollController.hasClients) return;
    final double maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (!animated) { _scrollController.jumpTo(maxScrollExtent); return; }
    await _scrollController.animateTo(maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  String _cleanErrorMessage(Object error) {
    final String text = error.toString().trim();
    if (text.startsWith('Exception:')) return text.substring('Exception:'.length).trim();
    return text.isEmpty ? 'Unable to get an AI response. Please try again.' : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('MediData AI'),
        actions: [
          IconButton(tooltip: 'New chat', onPressed: _isSending ? null : _startNewChat, icon: const Icon(Icons.add_comment_outlined)),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.auto_awesome_rounded, size: 54, color: Theme.of(context).colorScheme.primary.withValues(alpha: .75)),
            const SizedBox(height: 14),
            Text('How can I help you study?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Ask about lectures, medical concepts, or exam preparation.', textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(context, _messages[index]),
    );
  }

  Widget _buildMessageBubble(BuildContext context, AiChatMessage message) {
    final theme = Theme.of(context);
    final bool isUser = message.role == 'user';
    final String content = message.content;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 780),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: isUser
            ? Text(content, style: TextStyle(color: theme.colorScheme.onPrimary, height: 1.45))
            : content.isEmpty
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.2))
                : MarkdownBody(data: content, selectable: true),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(children: [
          IconButton(tooltip: 'Attach file', onPressed: _isSending ? null : _pickFile, icon: const Icon(Icons.attach_file_rounded)),
          Expanded(child: TextField(
            controller: _messageController,
            focusNode: _inputFocusNode,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            onSubmitted: (_) => _sendMessage(),
            decoration: InputDecoration(
              hintText: _selectedAttachment == null ? 'Ask MediData AI...' : 'Add a message about the file...',
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            ),
          )),
          const SizedBox(width: 6),
          IconButton.filled(tooltip: 'Send', onPressed: _isSending ? null : _sendMessage, icon: const Icon(Icons.arrow_upward_rounded)),
        ]),
      ),
    );
  }
}