import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../services/ai_chat_history_service.dart';
import '../../services/ai_chat_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({
    super.key,
  });

  @override
  State<AiAssistantScreen> createState() =>
      _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  // ===========================================================================
  // SERVICES
  // ===========================================================================

  final AiChatService _aiService = AiChatService();

  final AiChatHistoryService _historyService =
      AiChatHistoryService.instance;

  // ===========================================================================
  // CONTROLLERS
  // ===========================================================================

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final FocusNode _inputFocusNode =
      FocusNode();

  // ===========================================================================
  // CHAT STATE
  // ===========================================================================

  final List<AiChatMessage> _messages =
      <AiChatMessage>[];

  String? _chatSessionId;

  bool _isLoadingHistory = true;

  bool _isSending = false;

  AiAttachment? _selectedAttachment;

  // ===========================================================================
  // LIFECYCLE
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _messageController.addListener(
      _onMessageChanged,
    );

    _loadSavedConversation();
  }

  @override
  void dispose() {
    _messageController.removeListener(
      _onMessageChanged,
    );

    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();

    super.dispose();
  }

  // ===========================================================================
  // MESSAGE CONTROLLER
  // ===========================================================================

  void _onMessageChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ===========================================================================
  // LOAD SAVED CONVERSATION
  // ===========================================================================

  Future<void> _loadSavedConversation() async {
    try {
      final String? existingSessionId =
          await _historyService.getCurrentSessionId();

      if (existingSessionId == null ||
          existingSessionId.isEmpty) {
        final String newSessionId =
            await _historyService.createSession(
          title: 'New chat',
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _chatSessionId = newSessionId;
          _isLoadingHistory = false;
        });

        return;
      }

      final List<AiChatMessage> savedMessages =
          await _historyService.loadMessages(
        existingSessionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _chatSessionId = existingSessionId;

        _messages
          ..clear()
          ..addAll(savedMessages);

        _isLoadingHistory = false;
      });

      if (_messages.isNotEmpty) {
        await _scrollToBottom(
          animated: false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'AI history load error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      try {
        final String newSessionId =
            await _historyService.createSession(
          title: 'New chat',
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _chatSessionId = newSessionId;
          _isLoadingHistory = false;
        });
      } catch (sessionError) {
        debugPrint(
          'AI session create error: $sessionError',
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  // ===========================================================================
  // SAVE MESSAGE
  // ===========================================================================

  Future<void> _saveMessageToHistory(
    AiChatMessage message,
  ) async {
    try {
      if (_chatSessionId == null ||
          _chatSessionId!.isEmpty) {
        _chatSessionId =
            await _historyService.createSession(
          title: _buildSessionTitle(
            message,
          ),
        );
      }

      await _historyService.saveMessage(
        sessionId: _chatSessionId!,
        message: message,
      );

      // First user message becomes the chat title.
      if (message.role == 'user') {
        final savedMessageCount =
            _messages.where(
          (item) => item.role == 'user',
        );

        if (savedMessageCount.length == 1) {
          await _historyService.updateTitle(
            sessionId: _chatSessionId!,
            title: _buildSessionTitle(
              message,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
        'AI save message error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );
    }
  }

  String _buildSessionTitle(
    AiChatMessage message,
  ) {
    final String text =
        message.content.trim();

    if (text.isEmpty) {
      return 'New chat';
    }

    if (text.length <= 60) {
      return text;
    }

    return '${text.substring(0, 60)}...';
  }

  // ===========================================================================
  // NEW CHAT
  // ===========================================================================

  Future<void> _startNewChat() async {
    if (_isSending ||
        _isLoadingHistory) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Start a new chat?',
          ),
          content: const Text(
            'Your current conversation will remain saved. A new conversation will be started.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'New Chat',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    try {
      final String newSessionId =
          await _historyService.createSession(
        title: 'New chat',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _chatSessionId = newSessionId;

        _messages.clear();

        _selectedAttachment = null;

        _messageController.clear();
      });

      _inputFocusNode.requestFocus();
    } catch (e, stackTrace) {
      debugPrint(
        'Create new AI chat error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      _showError(
        'Unable to start a new chat.',
      );
    }
  }

  // ===========================================================================
  // SEND MESSAGE
  // ===========================================================================

  Future<void> _sendMessage() async {
    if (_isSending ||
        _isLoadingHistory) {
      return;
    }

    final String text =
        _messageController.text.trim();

    final AiAttachment? attachment =
        _selectedAttachment;

    if (text.isEmpty &&
        attachment == null) {
      return;
    }

    final String userMessage =
        text.isEmpty
            ? 'Please analyze the attached file and explain the important points.'
            : text;

    final AiChatMessage userChatMessage =
        AiChatMessage(
      role: 'user',
      content: userMessage,
    );

    final List<AiChatMessage>
        outgoingMessages = [
      ..._messages,
      userChatMessage,
    ];

    setState(() {
      _messages.add(
        userChatMessage,
      );

      _messageController.clear();

      _selectedAttachment = null;

      _isSending = true;
    });

    await _saveMessageToHistory(
      userChatMessage,
    );

    await _scrollToBottom();

    try {
      late final AiChatResponse response;

      if (attachment != null) {
        response =
            await _aiService
                .sendMessageWithAttachment(
          messages:
              outgoingMessages,
          attachment:
              attachment,
        );
      } else {
        response =
            await _aiService.sendMessage(
          messages:
              outgoingMessages,
        );
      }

      if (!mounted) {
        return;
      }

      final AiChatMessage assistantMessage =
          AiChatMessage(
        role: 'assistant',
        content: response.reply,
      );

      setState(() {
        _messages.add(
          assistantMessage,
        );

        _isSending = false;
      });

      await _saveMessageToHistory(
        assistantMessage,
      );

      await _scrollToBottom();

      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    } catch (e, stackTrace) {
      debugPrint(
        'AI send error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSending = false;
      });

      _showError(
        _cleanErrorMessage(e),
      );

      // Keep keyboard open.
      _inputFocusNode.requestFocus();
    }
  }

  // ===========================================================================
  // PICK FILE
  //
  // Compatible with file_picker ^12.0.0
  // ===========================================================================

  Future<void> _pickFile() async {
    if (_isSending) {
      return;
    }

    try {
      final PlatformFile? pickedFile =
          await FilePicker.pickFile(
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

      if (pickedFile == null) {
        return;
      }

      final int fileSize =
          await pickedFile.length();

      if (fileSize <= 0) {
        _showError(
          'The selected file is empty.',
        );
        return;
      }

      if (fileSize >
          AiChatService.maxFileBytes) {
        _showError(
          'File size must be 20 MB or less.',
        );
        return;
      }

      final String fileName =
          pickedFile.name;

      if (!AiChatService.isSupportedFile(
        fileName,
      )) {
        _showError(
          'This file type is not supported.',
        );
        return;
      }

      final Uint8List bytes =
          await pickedFile.readAsBytes();

      if (bytes.isEmpty) {
        _showError(
          'Unable to read the selected file.',
        );
        return;
      }

      final String mimeType =
          AiChatService.mimeTypeForFile(
        fileName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedAttachment =
            AiAttachment(
          fileName: fileName,
          mimeType: mimeType,
          bytes: bytes,
          isImage:
              mimeType.startsWith(
            'image/',
          ),
        );
      });

      _inputFocusNode.requestFocus();

      await _scrollToBottom();
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      _showError(
        'The file took too long to read.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'AI file picker error: $e',
      );

      debugPrint(
        stackTrace.toString(),
      );

      if (!mounted) {
        return;
      }

      _showError(
        _cleanErrorMessage(e),
      );
    }
  }

  // ===========================================================================
  // SCROLL
  // ===========================================================================

  Future<void> _scrollToBottom({
    bool animated = true,
  }) async {
    await Future<void>.delayed(
      const Duration(
        milliseconds: 60,
      ),
    );

    if (!mounted ||
        !_scrollController.hasClients) {
      return;
    }

    final double maxScrollExtent =
        _scrollController
            .position
            .maxScrollExtent;

    if (!animated) {
      _scrollController.jumpTo(
        maxScrollExtent,
      );
      return;
    }

    await _scrollController.animateTo(
      maxScrollExtent,
      duration:
          const Duration(
        milliseconds: 260,
      ),
      curve:
          Curves.easeOut,
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  String _cleanErrorMessage(
    Object error,
  ) {
    final String text =
        error.toString().trim();

    if (text.startsWith(
      'Exception:',
    )) {
      return text
          .substring(
            'Exception:'.length,
          )
          .trim();
    }

    return text.isEmpty
        ? 'Unable to get an AI response. Please try again.'
        : text;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colorScheme =
        theme.colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor:
          colorScheme.surface,
      appBar:
          _buildAppBar(context),
      body: _isLoadingHistory
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : SafeArea(
              top: false,
              bottom: true,
              child:
                  LayoutBuilder(
                builder:
                    (
                  BuildContext context,
                  BoxConstraints constraints,
                ) {
                  final bool isWide =
                      constraints.maxWidth >=
                          700;

                  final double maxWidth =
                      isWide
                          ? 920
                          : double.infinity;

                  return Center(
                    child:
                        ConstrainedBox(
                      constraints:
                          BoxConstraints(
                        maxWidth:
                            maxWidth,
                      ),
                      child:
                          Column(
                        children: [
                          Expanded(
                            child:
                                _buildMessagesArea(
                              context,
                            ),
                          ),
                          _buildComposer(
                            context,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colorScheme =
        theme.colorScheme;

    return AppBar(
      elevation: 0,
      centerTitle: true,
      backgroundColor:
          colorScheme.surface,
      surfaceTintColor:
          Colors.transparent,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(
          Icons.arrow_back_rounded,
        ),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
      title: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color:
                  colorScheme.primary
                      .withValues(
                alpha: .12,
              ),
              shape:
                  BoxShape.circle,
            ),
            child:
                Icon(
              Icons
                  .auto_awesome_rounded,
              color:
                  colorScheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          const Text(
            'MediData AI',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip:
              'New chat',
          onPressed:
              _isSending ||
                      _isLoadingHistory
                  ? null
                  : _startNewChat,
          icon:
              const Icon(
            Icons
                .add_comment_outlined,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MESSAGES AREA
  // ===========================================================================

  Widget _buildMessagesArea(
    BuildContext context,
  ) {
    if (_messages.isEmpty) {
      return _buildWelcome(
        context,
      );
    }

    return ListView.builder(
      controller:
          _scrollController,
      physics:
          const BouncingScrollPhysics(),
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior
              .onDrag,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        18,
      ),
      itemCount:
          _messages.length +
              (_isSending ? 1 : 0),
      itemBuilder:
          (
        BuildContext context,
        int index,
      ) {
        if (_isSending &&
            index ==
                _messages.length) {
          return const _TypingBubble();
        }

        final AiChatMessage message =
            _messages[index];

        return _MessageBubble(
          message:
              message.content,
          isUser:
              message.role ==
                  'user',
        );
      },
    );
  }

  // ===========================================================================
  // WELCOME
  // ===========================================================================

  Widget _buildWelcome(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colorScheme =
        theme.colorScheme;

    final double iconContainerSize =
        MediaQuery.sizeOf(context).width <
                400
            ? 72
            : 82;

    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child:
            ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 680,
          ),
          child:
              Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width:
                    iconContainerSize,
                height:
                    iconContainerSize,
                decoration:
                    BoxDecoration(
                  color:
                      colorScheme.primary
                          .withValues(
                    alpha: .12,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    Icon(
                  Icons
                      .auto_awesome_rounded,
                  size:
                      iconContainerSize *
                          .50,
                  color:
                      colorScheme.primary,
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Text(
                'MediData AI',
                textAlign:
                    TextAlign.center,
                style:
                    theme.textTheme
                        .headlineSmall
                        ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                'Your study assistant for medical learning.',
                textAlign:
                    TextAlign.center,
                style:
                    theme.textTheme
                        .bodyMedium
                        ?.copyWith(
                  color:
                      colorScheme
                          .onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(
                height: 24,
              ),
              Wrap(
                alignment:
                    WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SuggestionChip(
                    icon:
                        Icons.school_outlined,
                    label:
                        'Explain a topic',
                    onTap: () {
                      _setSuggestion(
                        'Explain this medical topic in a simple, clear, step-by-step way.',
                      );
                    },
                  ),
                  _SuggestionChip(
                    icon:
                        Icons.summarize_outlined,
                    label:
                        'Summarize',
                    onTap: () {
                      _setSuggestion(
                        'Summarize this topic and give me the most important points for an exam.',
                      );
                    },
                  ),
                  _SuggestionChip(
                    icon:
                        Icons.quiz_outlined,
                    label:
                        'Quiz me',
                    onTap: () {
                      _setSuggestion(
                        'Quiz me on this topic with medical questions, one question at a time.',
                      );
                    },
                  ),
                  _SuggestionChip(
                    icon:
                        Icons.menu_book_outlined,
                    label:
                        'Study help',
                    onTap: () {
                      _setSuggestion(
                        'Help me understand this topic and tell me what I should focus on for studying.',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setSuggestion(
    String text,
  ) {
    if (_isSending) {
      return;
    }

    _messageController.text =
        text;

    _messageController.selection =
        TextSelection.collapsed(
      offset:
          _messageController
              .text
              .length,
    );

    _inputFocusNode.requestFocus();
  }

  // ===========================================================================
  // COMPOSER
  // ===========================================================================

  Widget _buildComposer(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colorScheme =
        theme.colorScheme;

    return Material(
      color:
          colorScheme.surface,
      child:
          SafeArea(
        top: false,
        bottom: true,
        child:
            Padding(
          padding:
              const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            12,
          ),
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              if (_selectedAttachment !=
                  null)
                _buildAttachmentPreview(
                  context,
                ),
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  _ComposerButton(
                    tooltip:
                        'Attach file',
                    icon:
                        Icons
                            .attach_file_rounded,
                    onPressed:
                        _isSending
                            ? null
                            : _pickFile,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child:
                        Container(
                      constraints:
                          const BoxConstraints(
                        minHeight:
                            52,
                        maxHeight:
                            160,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            colorScheme
                                .surfaceContainerHighest,
                        borderRadius:
                            BorderRadius
                                .circular(
                          26,
                        ),
                        border:
                            Border.all(
                          color:
                              colorScheme
                                  .outline
                                  .withValues(
                            alpha:
                                .08,
                          ),
                        ),
                      ),
                      child:
                          TextField(
                        controller:
                            _messageController,
                        focusNode:
                            _inputFocusNode,
                        enabled:
                            !_isSending,
                        minLines:
                            1,
                        maxLines:
                            6,
                        keyboardType:
                            TextInputType
                                .multiline,
                        textInputAction:
                            TextInputAction
                                .newline,
                        textCapitalization:
                            TextCapitalization
                                .sentences,
                        decoration:
                            const InputDecoration(
                          hintText:
                              'Ask MediData AI...',
                          border:
                              InputBorder
                                  .none,
                          contentPadding:
                              EdgeInsets
                                  .symmetric(
                            horizontal:
                                18,
                            vertical:
                                14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  _buildSendButton(
                    context,
                  ),
                ],
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                'AI-generated information may contain mistakes. Verify important medical information.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize:
                      10,
                  color:
                      colorScheme
                          .onSurface
                          .withValues(
                    alpha:
                        .38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SEND BUTTON
  // ===========================================================================

  Widget _buildSendButton(
    BuildContext context,
  ) {
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    final bool hasContent =
        _messageController.text
                .trim()
                .isNotEmpty ||
            _selectedAttachment !=
                null;

    final bool enabled =
        !_isSending &&
            hasContent;

    return SizedBox(
      width: 50,
      height: 50,
      child:
          Material(
        color:
            enabled
                ? colorScheme.primary
                : colorScheme
                    .surfaceContainerHighest,
        shape:
            const CircleBorder(),
        child:
            InkWell(
          customBorder:
              const CircleBorder(),
          onTap:
              enabled
                  ? _sendMessage
                  : null,
          child:
              Center(
            child:
                _isSending
                    ? SizedBox(
                        width:
                            19,
                        height:
                            19,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2.2,
                          color:
                              enabled
                                  ? colorScheme
                                      .onPrimary
                                  : colorScheme
                                      .onSurfaceVariant,
                        ),
                      )
                    : Icon(
                        Icons
                            .arrow_upward_rounded,
                        color:
                            enabled
                                ? colorScheme
                                    .onPrimary
                                : colorScheme
                                    .onSurfaceVariant,
                      ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ATTACHMENT PREVIEW
  // ===========================================================================

  Widget _buildAttachmentPreview(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colorScheme =
        theme.colorScheme;

    final AiAttachment attachment =
        _selectedAttachment!;

    return Container(
      width:
          double.infinity,
      margin:
          const EdgeInsets.only(
        bottom:
            8,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            10,
        vertical:
            8,
      ),
      decoration:
          BoxDecoration(
        color:
            colorScheme
                .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child:
          Row(
        children: [
          if (attachment.isImage)
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                9,
              ),
              child:
                  Image.memory(
                attachment.bytes,
                width:
                    42,
                height:
                    42,
                fit:
                    BoxFit.cover,
                errorBuilder:
                    (
                  context,
                  error,
                  stackTrace,
                ) {
                  return _FileIcon(
                    mimeType:
                        attachment.mimeType,
                  );
                },
              ),
            )
          else
            _FileIcon(
              mimeType:
                  attachment.mimeType,
            ),
          const SizedBox(
            width:
                10,
          ),
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  attachment
                      .fileName,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),
                const SizedBox(
                  height:
                      2,
                ),
                Text(
                  _formatBytes(
                    attachment
                        .sizeInBytes,
                  ),
                  style:
                      theme.textTheme
                          .bodySmall
                          ?.copyWith(
                    color:
                        colorScheme
                            .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip:
                'Remove attachment',
            onPressed:
                _isSending
                    ? null
                    : _removeAttachment,
            icon:
                const Icon(
              Icons.close_rounded,
              size:
                  20,
            ),
          ),
        ],
      ),
    );
  }

  void _removeAttachment() {
    if (_isSending) {
      return;
    }

    setState(() {
      _selectedAttachment =
          null;
    });
  }

  // ===========================================================================
  // FILE SIZE
  // ===========================================================================

  String _formatBytes(
    int bytes,
  ) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes <
        1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ============================================================================
// MESSAGE BUBBLE
// ============================================================================

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  const _MessageBubble({
    required this.message,
    required this.isUser,
  });

  bool _containsArabic(
    String text,
  ) {
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
    ).hasMatch(text);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colorScheme =
        theme.colorScheme;

    final bool isArabic =
        _containsArabic(
      message,
    );

    final Color bubbleColor =
        isUser
            ? colorScheme.primary
            : colorScheme
                .surfaceContainerHighest;

    final Color textColor =
        isUser
            ? colorScheme.onPrimary
            : colorScheme.onSurface;

    final double screenWidth =
        MediaQuery.sizeOf(
      context,
    ).width;

    final double maxWidth =
        screenWidth >= 700
            ? 700
            : screenWidth * .90;

    return Align(
      alignment:
          isUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child:
          Container(
        constraints:
            BoxConstraints(
          maxWidth:
              maxWidth,
        ),
        margin:
            const EdgeInsets.only(
          bottom:
              12,
        ),
        padding:
            const EdgeInsets.fromLTRB(
          15,
          13,
          9,
          6,
        ),
        decoration:
            BoxDecoration(
          color:
              bubbleColor,
          borderRadius:
              BorderRadius.only(
            topLeft:
                const Radius.circular(
              19,
            ),
            topRight:
                const Radius.circular(
              19,
            ),
            bottomLeft:
                Radius.circular(
              isUser
                  ? 19
                  : 5,
            ),
            bottomRight:
                Radius.circular(
              isUser
                  ? 5
                  : 19,
            ),
          ),
          border:
              isUser
                  ? null
                  : Border.all(
                      color:
                          colorScheme
                              .outline
                              .withValues(
                        alpha:
                            .08,
                      ),
                    ),
        ),
        child:
            Directionality(
          textDirection:
              isArabic
                  ? TextDirection.rtl
                  : TextDirection.ltr,
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              MarkdownBody(
                data:
                    message,
                selectable:
                    true,
                fitContent:
                    false,
                shrinkWrap:
                    true,
                softLineBreak:
                    true,
                onTapLink:
                    (
                  text,
                  href,
                  title,
                ) async {
                  if (href == null ||
                      href
                          .trim()
                          .isEmpty) {
                    return;
                  }

                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          href,
                    ),
                  );

                  if (!context
                      .mounted) {
                    return;
                  }

                  ScaffoldMessenger
                      .of(
                    context,
                  )
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content:
                            Text(
                          'Link copied.',
                        ),
                        behavior:
                            SnackBarBehavior
                                .floating,
                        duration:
                            Duration(
                          seconds:
                              1,
                        ),
                      ),
                    );
                },
                styleSheet:
                    MarkdownStyleSheet(
                  p:
                      TextStyle(
                    color:
                        textColor,
                    fontSize:
                        15.5,
                    height:
                        1.55,
                  ),
                  h1:
                      TextStyle(
                    color:
                        textColor,
                    fontSize:
                        23,
                    fontWeight:
                        FontWeight
                            .w800,
                    height:
                        1.25,
                  ),
                  h2:
                      TextStyle(
                    color:
                        textColor,
                    fontSize:
                        20,
                    fontWeight:
                        FontWeight
                            .w800,
                    height:
                        1.30,
                  ),
                  h3:
                      TextStyle(
                    color:
                        textColor,
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight
                            .w700,
                    height:
                        1.35,
                  ),
                  h4:
                      TextStyle(
                    color:
                        textColor,
                    fontSize:
                        16,
                    fontWeight:
                        FontWeight
                            .w700,
                    height:
                        1.35,
                  ),
                  strong:
                      TextStyle(
                    color:
                        textColor,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                  em:
                      TextStyle(
                    color:
                        textColor,
                    fontStyle:
                        FontStyle
                            .italic,
                  ),
                  listBullet:
                      TextStyle(
                    color:
                        textColor,
                    fontSize:
                        15,
                  ),
                  blockquote:
                      TextStyle(
                    color:
                        textColor.withValues(
                      alpha:
                          .80,
                    ),
                    fontSize:
                        14.5,
                    height:
                        1.55,
                    fontStyle:
                        FontStyle
                            .italic,
                  ),
                  blockquoteDecoration:
                      BoxDecoration(
                    color:
                        colorScheme
                            .primary
                            .withValues(
                      alpha:
                          .05,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    border:
                        Border(
                      left:
                          BorderSide(
                        color:
                            colorScheme
                                .primary,
                        width:
                            3,
                      ),
                    ),
                  ),
                  code:
                      TextStyle(
                    color:
                        textColor,
                    fontFamily:
                        'monospace',
                    fontSize:
                        13,
                  ),
                  codeblockDecoration:
                      BoxDecoration(
                    color:
                        isUser
                            ? colorScheme
                                .onPrimary
                                .withValues(
                                alpha:
                                    .08,
                              )
                            : colorScheme
                                .surface,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                    border:
                        Border.all(
                      color:
                          colorScheme
                              .outline
                              .withValues(
                        alpha:
                            .10,
                      ),
                    ),
                  ),
                  codeblockPadding:
                      const EdgeInsets.all(
                    13,
                  ),
                  tableHead:
                      TextStyle(
                    color:
                        textColor,
                    fontWeight:
                        FontWeight
                            .w800,
                    fontSize:
                        13.5,
                  ),
                  tableBody:
                      TextStyle(
                    color:
                        textColor,
                    fontSize:
                        13,
                    height:
                        1.45,
                  ),
                  tableBorder:
                      TableBorder.all(
                    color:
                        colorScheme
                            .outline
                            .withValues(
                      alpha:
                          .12,
                    ),
                  ),
                  a:
                      TextStyle(
                    color:
                        isUser
                            ? colorScheme
                                .onPrimary
                            : colorScheme
                                .primary,
                    decoration:
                        TextDecoration
                            .underline,
                  ),
                  horizontalRuleDecoration:
                      BoxDecoration(
                    border:
                        Border(
                      top:
                          BorderSide(
                        color:
                            colorScheme
                                .outline
                                .withValues(
                          alpha:
                              .15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (!isUser)
                Align(
                  alignment:
                      Alignment
                          .centerRight,
                  child:
                      IconButton(
                    tooltip:
                        'Copy response',
                    visualDensity:
                        VisualDensity
                            .compact,
                    padding:
                        EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(
                      minWidth:
                          32,
                      minHeight:
                          32,
                    ),
                    icon:
                        Icon(
                      Icons
                          .copy_rounded,
                      size:
                          17,
                      color:
                          colorScheme
                              .onSurface
                              .withValues(
                        alpha:
                            .42,
                      ),
                    ),
                    onPressed:
                        () async {
                      await Clipboard
                          .setData(
                        ClipboardData(
                          text:
                              message,
                        ),
                      );

                      if (!context
                          .mounted) {
                        return;
                      }

                      ScaffoldMessenger
                          .of(
                        context,
                      )
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content:
                                Text(
                              'Response copied.',
                            ),
                            behavior:
                                SnackBarBehavior
                                    .floating,
                            duration:
                                Duration(
                              seconds:
                                  1,
                            ),
                          ),
                        );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TYPING BUBBLE
// ============================================================================

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() =>
      _TypingBubbleState();
}

class _TypingBubbleState
    extends State<_TypingBubble>
    with
        SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds:
            900,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    return Align(
      alignment:
          Alignment.centerLeft,
      child:
          Padding(
        padding:
            const EdgeInsets.only(
          bottom:
              12,
        ),
        child:
            Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width:
                  34,
              height:
                  34,
              decoration:
                  BoxDecoration(
                color:
                    colorScheme.primary
                        .withValues(
                  alpha:
                      .10,
                ),
                shape:
                    BoxShape.circle,
              ),
              child:
                  Icon(
                Icons
                    .auto_awesome_rounded,
                size:
                    18,
                color:
                    colorScheme.primary,
              ),
            ),
            const SizedBox(
              width:
                  8,
            ),
            AnimatedBuilder(
              animation:
                  _controller,
              builder:
                  (
                BuildContext context,
                Widget? child,
              ) {
                return Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        15,
                    vertical:
                        13,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        colorScheme
                            .surfaceContainerHighest,
                    borderRadius:
                        const BorderRadius
                            .only(
                      topLeft:
                          Radius.circular(
                        18,
                      ),
                      topRight:
                          Radius.circular(
                        18,
                      ),
                      bottomRight:
                          Radius.circular(
                        18,
                      ),
                      bottomLeft:
                          Radius.circular(
                        5,
                      ),
                    ),
                  ),
                  child:
                      Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children:
                        List.generate(
                      3,
                      (
                        int index,
                      ) {
                        final double
                            value =
                            (_controller
                                        .value +
                                    index *
                                        .18) %
                                1.0;

                        final double
                            opacity =
                            .35 +
                                (.65 *
                                    (value <
                                            .5
                                        ? value *
                                            2
                                        : (1 -
                                                value) *
                                            2));

                        return Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                2.5,
                          ),
                          child:
                              Opacity(
                            opacity:
                                opacity.clamp(
                              .25,
                              1.0,
                            ),
                            child:
                                Container(
                              width:
                                  6,
                              height:
                                  6,
                              decoration:
                                  BoxDecoration(
                                color:
                                    colorScheme
                                        .primary,
                                shape:
                                    BoxShape
                                        .circle,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SUGGESTION CHIP
// ============================================================================

class _SuggestionChip
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ActionChip(
      avatar:
          Icon(
        icon,
        size:
            17,
      ),
      label:
          Text(
        label,
      ),
      onPressed:
          onTap,
    );
  }
}

// ============================================================================
// COMPOSER BUTTON
// ============================================================================

class _ComposerButton
    extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ComposerButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return IconButton(
      tooltip:
          tooltip,
      onPressed:
          onPressed,
      icon:
          Icon(icon),
      style:
          IconButton.styleFrom(
        minimumSize:
            const Size(
          50,
          50,
        ),
        fixedSize:
            const Size(
          50,
          50,
        ),
      ),
    );
  }
}

// ============================================================================
// FILE ICON
// ============================================================================

class _FileIcon extends StatelessWidget {
  final String mimeType;

  const _FileIcon({
    required this.mimeType,
  });

  IconData get _icon {
    if (mimeType ==
        'application/pdf') {
      return Icons
          .picture_as_pdf_rounded;
    }

    if (mimeType.contains(
      'word',
    )) {
      return Icons
          .description_rounded;
    }

    if (mimeType.contains(
      'presentation',
    )) {
      return Icons
          .slideshow_rounded;
    }

    if (mimeType.startsWith(
      'text/',
    )) {
      return Icons
          .article_rounded;
    }

    return Icons
        .insert_drive_file_rounded;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width:
          42,
      height:
          42,
      decoration:
          BoxDecoration(
        color:
            colorScheme.primary
                .withValues(
          alpha:
              .10,
        ),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
      ),
      child:
          Icon(
        _icon,
        color:
            colorScheme.primary,
      ),
    );
  }
}
