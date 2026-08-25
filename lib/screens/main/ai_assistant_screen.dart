import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/ai_chat_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  // ===========================================================================
  // APP SHELL / BOTTOM NAV DIMENSIONS
  // ===========================================================================

  static const double _mobileNavHeight = 74.0;
  static const double _tabletNavHeight = 82.0;

  static const double _mobileNavBottomMargin = 10.0;
  static const double _tabletNavBottomMargin = 20.0;

  static const double _mobileSelectedCircleOverlap = 20.0;
  static const double _tabletSelectedCircleOverlap = 22.0;

  static const double _contentGap = 12.0;

  static const double _inputReservedHeight = 170.0;

  // ===========================================================================
  // SERVICES
  // ===========================================================================

  final AiChatService _aiService = AiChatService();

  // ===========================================================================
  // CONTROLLERS
  // ===========================================================================

  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final FocusNode _inputFocusNode = FocusNode();

  // ===========================================================================
  // CHAT
  // ===========================================================================

  final List<AiChatMessage> _messages = [];

  bool _isLoading = false;

  // ===========================================================================
  // ATTACHMENT
  // ===========================================================================

  AiAttachment? _selectedAttachment;

  double get _selectedFileSizeMb {
    final bytes = _selectedAttachment?.sizeInBytes ?? 0;
    return bytes / (1024 * 1024);
  }

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _messages.add(
      const AiChatMessage(
        role: 'assistant',
        content:
            'Hi! I’m MediData AI 👋\n\n'
            'I can help you understand medical concepts, '
            'summarize topics, prepare for exams, quiz you, '
            'and analyze images or study files.',
      ),
    );
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();

    super.dispose();
  }

  // ===========================================================================
  // PICK ATTACHMENT
  // ===========================================================================

  Future<void> _pickAttachment() async {
    debugPrint('AI ATTACHMENT: button pressed');

    if (_isLoading) {
      debugPrint('AI ATTACHMENT: blocked because loading');
      return;
    }

    try {
      final files = await FilePicker.pickFiles(
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

      debugPrint('AI ATTACHMENT: picker returned ${files.length} file(s)');

      if (files.isEmpty) {
        debugPrint('AI ATTACHMENT: user cancelled picker');
        return;
      }

      final file = files.first;

      debugPrint('AI ATTACHMENT: selected ${file.name}');

      final bytes = await file.readAsBytes();

      debugPrint('AI ATTACHMENT: bytes=${bytes.length}');

      if (bytes.isEmpty) {
        _showError('Unable to read the selected file.');
        return;
      }

      if (bytes.length > AiChatService.maxFileBytes) {
        _showError('File size must be 20 MB or less.');
        return;
      }

      if (!AiChatService.isSupportedFile(file.name)) {
        _showError('This file type is not supported.');
        return;
      }

      final mimeType = AiChatService.mimeTypeForFile(file.name);

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedAttachment = AiAttachment(
          fileName: file.name,
          mimeType: mimeType,
          bytes: bytes,
          isImage: mimeType.startsWith('image/'),
        );
      });

      _inputFocusNode.requestFocus();

      debugPrint('AI ATTACHMENT: attachment ready');
    } catch (e, stackTrace) {
      debugPrint('AI ATTACHMENT ERROR: $e');

      debugPrint(stackTrace.toString());

      if (!mounted) {
        return;
      }

      _showError('Unable to open the file picker.');
    }
  }
  // ===========================================================================
  // REMOVE ATTACHMENT
  // ===========================================================================

  void _removeAttachment() {
    if (_isLoading) {
      return;
    }

    setState(() {
      _selectedAttachment = null;
    });
  }

  // ===========================================================================
  // SEND
  // ===========================================================================

  Future<void> _sendMessage() async {
    if (_isLoading) {
      return;
    }

    final text = _messageController.text.trim();

    final attachment = _selectedAttachment;

    if (text.isEmpty && attachment == null) {
      return;
    }

    final sentText = text.isEmpty
        ? 'Please analyze this attachment and explain it to me.'
        : text;

    _messageController.clear();

    final userMessage = AiChatMessage(role: 'user', content: sentText);

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      late final AiChatResponse response;

      if (attachment == null) {
        response = await _aiService.sendMessage(messages: _messages);
      } else {
        response = await _aiService.sendMessageWithAttachment(
          messages: _messages,
          attachment: attachment,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          AiChatMessage(role: 'assistant', content: response.reply),
        );

        _selectedAttachment = null;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('AI assistant error: $e');

      if (!mounted) {
        return;
      }

      // Remove the user message when
      // the request failed.
      setState(() {
        if (_messages.isNotEmpty && _messages.last.role == 'user') {
          _messages.removeLast();
        }
      });

      _showError(_friendlyErrorMessage(e));

      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // NEW CHAT
  // ===========================================================================

  void _startNewChat() {
    if (_isLoading) {
      return;
    }

    setState(() {
      _messages
        ..clear()
        ..add(
          const AiChatMessage(
            role: 'assistant',
            content:
                'New study session started 📚\n\n'
                'What would you like to learn?',
          ),
        );

      _selectedAttachment = null;
    });

    _messageController.clear();

    _scrollToBottom();
  }

  // ===========================================================================
  // SUGGESTION
  // ===========================================================================

  void _useSuggestion(String text) {
    if (_isLoading) {
      return;
    }

    _messageController.text = text;

    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );

    _inputFocusNode.requestFocus();
  }

  // ===========================================================================
  // SCROLL
  // ===========================================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  String _friendlyErrorMessage(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('session has expired')) {
      return 'Your session has expired. Please log in again.';
    }

    if (message.contains('20 mb')) {
      return 'File size must be 20 MB or less.';
    }

    if (message.contains('unsupported')) {
      return 'This file type is not supported.';
    }

    if (message.contains('provider error')) {
      return 'The AI service is temporarily unavailable. Please try again.';
    }

    return 'Unable to get an AI response. Please try again.';
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final isTablet = size.shortestSide >= 600;

    final horizontalPadding = isTablet ? 28.0 : 12.0;

    final maxContentWidth = isTablet ? 820.0 : 700.0;

    // -------------------------------------------------------------------------
    // BOTTOM NAV
    // -------------------------------------------------------------------------

    final navHeight = isTablet ? _tabletNavHeight : _mobileNavHeight;

    final navBottomMargin = isTablet
        ? _tabletNavBottomMargin
        : _mobileNavBottomMargin;

    final selectedCircleOverlap = isTablet
        ? _tabletSelectedCircleOverlap
        : _mobileSelectedCircleOverlap;

    final systemBottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    // -------------------------------------------------------------------------
    // KEYBOARD
    // -------------------------------------------------------------------------

    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    final keyboardVisible = keyboardHeight > 0;

    // -------------------------------------------------------------------------
    // NAV VISUAL SPACE
    // -------------------------------------------------------------------------

    final floatingNavVisualHeight =
        systemBottomPadding +
        navBottomMargin +
        navHeight +
        selectedCircleOverlap +
        _contentGap;

    final inputBottom = keyboardVisible
        ? keyboardHeight + _contentGap
        : floatingNavVisualHeight;

    final messagesBottomPadding = inputBottom + _inputReservedHeight + 20;

    final suggestionsBottom = inputBottom + _inputReservedHeight + 8;

    return Scaffold(
      resizeToAvoidBottomInset: true,

      // =========================================================================
      // APP BAR
      // =========================================================================
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 17,
              child: Icon(Icons.auto_awesome_rounded, size: 19),
            ),
            SizedBox(width: 10),
            Text('MediData AI'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _isLoading ? null : _startNewChat,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      // =========================================================================
      // BODY
      // =========================================================================
      body: Stack(
        children: [
          // =====================================================================
          // MESSAGES
          // =====================================================================
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                messagesBottomPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isLoading && index == _messages.length) {
                        return const _TypingIndicator();
                      }

                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
                ),
              ),
            ),
          ),

          // =====================================================================
          // INITIAL SUGGESTIONS
          // =====================================================================
          if (!_isLoading &&
              _messages.length <= 1 &&
              _selectedAttachment == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: suggestionsBottom,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      children: [
                        _StudyActionChip(
                          icon: Icons.lightbulb_outline_rounded,
                          label: 'Explain',
                          onTap: () {
                            _useSuggestion(
                              'Explain a medical topic to me in a simple, clear, step-by-step way.',
                            );
                          },
                        ),
                        _StudyActionChip(
                          icon: Icons.summarize_outlined,
                          label: 'Summarize',
                          onTap: () {
                            _useSuggestion(
                              'Give me a concise but complete study summary of this topic, focusing on the most important points I should remember for an exam.',
                            );
                          },
                        ),
                        _StudyActionChip(
                          icon: Icons.quiz_outlined,
                          label: 'Quiz Me',
                          onTap: () {
                            _useSuggestion(
                              'Quiz me on this topic with 5 medical study questions. Ask one question at a time and wait for my answer before revealing the correct answer.',
                            );
                          },
                        ),
                        _StudyActionChip(
                          icon: Icons.style_outlined,
                          label: 'Flashcards',
                          onTap: () {
                            _useSuggestion(
                              'Create 8 study flashcards about this topic. Format each one as Question and Answer, focusing on high-yield facts.',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // =====================================================================
          // INPUT AREA
          // =====================================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: inputBottom,
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              elevation: 8,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      8,
                      horizontalPadding,
                      8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // =======================================================
                        // ATTACHMENT PREVIEW
                        // =======================================================
                        if (_selectedAttachment != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _AttachmentPreview(
                              attachment: _selectedAttachment!,
                              sizeInMb: _selectedFileSizeMb,
                              onRemove: _removeAttachment,
                            ),
                          ),

                        // =======================================================
                        // INPUT ROW
                        // =======================================================
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // ============================================================
                            // ATTACHMENT BUTTON
                            // ============================================================
                            SizedBox(
                              width: 48,
                              height: 50,
                              child: FilledButton.tonal(
                                onPressed: _isLoading ? null : _pickAttachment,
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Icon(Icons.attach_file_rounded),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // ============================================================
                            // TEXT INPUT
                            // ============================================================
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                focusNode: _inputFocusNode,
                                enabled: !_isLoading,
                                minLines: 1,
                                maxLines: 5,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: _selectedAttachment == null
                                      ? 'Ask MediData AI...'
                                      : 'Ask about this file...',
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 13,
                                  ),
                                ),
                                onSubmitted: (_) {
                                  _sendMessage();
                                },
                              ),
                            ),

                            const SizedBox(width: 8),

                            // ============================================================
                            // SEND BUTTON
                            // ============================================================
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _sendMessage,
                                style: FilledButton.styleFrom(
                                  shape: const CircleBorder(),
                                  padding: EdgeInsets.zero,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_upward_rounded),
                              ),
                            ),
                          ],
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
}

// ============================================================================
// ATTACHMENT PREVIEW
// ============================================================================

class _AttachmentPreview extends StatelessWidget {
  final AiAttachment attachment;
  final double sizeInMb;
  final VoidCallback onRemove;

  const _AttachmentPreview({
    required this.attachment,
    required this.sizeInMb,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // -------------------------------------------------------------------
          // THUMBNAIL / FILE ICON
          // -------------------------------------------------------------------
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
            ),
            child: attachment.isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(attachment.bytes, fit: BoxFit.cover),
                  )
                : Icon(
                    _fileIcon(attachment.mimeType),
                    color: theme.colorScheme.primary,
                  ),
          ),

          const SizedBox(width: 10),

          // -------------------------------------------------------------------
          // FILE INFO
          // -------------------------------------------------------------------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sizeInMb.toStringAsFixed(2)} MB',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------------
          // REMOVE
          // -------------------------------------------------------------------
          IconButton(
            tooltip: 'Remove attachment',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(String mimeType) {
    if (mimeType == 'application/pdf') {
      return Icons.picture_as_pdf_rounded;
    }

    if (mimeType.contains('word')) {
      return Icons.article_outlined;
    }

    if (mimeType.contains('presentation')) {
      return Icons.slideshow_outlined;
    }

    return Icons.insert_drive_file_outlined;
  }
}

// ============================================================================
// STUDY ACTION CHIP
// ============================================================================

class _StudyActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StudyActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(icon, size: 18, color: theme.colorScheme.primary),
        label: Text(label),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      ),
    );
  }
}

// ============================================================================
// MESSAGE BUBBLE
// ============================================================================

class _MessageBubble extends StatelessWidget {
  final AiChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
        ),
        child: SelectableText(
          message.content,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: isUser
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TYPING INDICATOR
// ============================================================================

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: const _ThreeDotsLoader(),
      ),
    );
  }
}

class _ThreeDotsLoader extends StatefulWidget {
  const _ThreeDotsLoader();

  @override
  State<_ThreeDotsLoader> createState() => _ThreeDotsLoaderState();
}

class _ThreeDotsLoaderState extends State<_ThreeDotsLoader>
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
    return SizedBox(
      width: 35,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          final active = (_controller.value * 3).floor();

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: index == active ? 1 : 0.35,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
