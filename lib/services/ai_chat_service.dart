import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AiChatMessage {
  final String role;
  final String content;

  const AiChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class AiAttachment {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final bool isImage;

  const AiAttachment({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.isImage,
  });

  int get sizeInBytes => bytes.length;
}

class AiChatResponse {
  final String reply;
  final String? model;

  const AiChatResponse({
    required this.reply,
    this.model,
  });
}

class AiChatService {
  AiChatService();

  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _functionName = 'ai-chat';

  static const String _supabaseProjectUrl =
      'https://eoyehpqknyoksaxlvnwl.supabase.co';

  static const String _functionUrl =
      '$_supabaseProjectUrl/functions/v1/$_functionName';

  static const Duration _requestTimeout =
      Duration(seconds: 90);

  static const int maxFileBytes =
      20 * 1024 * 1024;

  // ===========================================================================
  // SEND TEXT
  // ===========================================================================

  Future<AiChatResponse> sendMessage({
    required List<AiChatMessage> messages,
  }) async {
    _validateMessages(messages);

    _requireSession();

    final body = {
      'messages': messages
          .map((message) => message.toMap())
          .toList(),
    };

    _debugLog(
      'Sending text request. '
      'messages=${messages.length}',
    );

    try {
      final response = await _supabase.functions
          .invoke(
            _functionName,
            body: body,
          )
          .timeout(_requestTimeout);

      _debugLog(
        'Function response received. '
        'dataType=${response.data.runtimeType}',
      );

      return _parseResponse(
        response.data,
      );
    } on TimeoutException {
      throw Exception(
        'The AI service took too long to respond.',
      );
    } catch (e, stackTrace) {
      _debugLog(
        'Text request failed: $e',
      );

      _debugLog(
        stackTrace.toString(),
      );

      throw _normalizeFunctionError(e);
    }
  }

  // ===========================================================================
  // SEND WITH ATTACHMENT
  // ===========================================================================

  Future<AiChatResponse> sendMessageWithAttachment({
    required List<AiChatMessage> messages,
    required AiAttachment attachment,
  }) async {
    _validateMessages(messages);

    final session = _requireSession();

    _validateAttachment(attachment);

    final publishableKey = _publishableKey();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_functionUrl),
    );

    request.headers.addAll({
      'Authorization':
          'Bearer ${session.accessToken}',
      'apikey':
          publishableKey,
      'Accept':
          'application/json',
    });

    request.fields['messages'] = jsonEncode(
      messages
          .map((message) => message.toMap())
          .toList(),
    );

    request.fields['fileName'] =
        attachment.fileName;

    request.fields['mimeType'] =
        attachment.mimeType;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        attachment.bytes,
        filename: attachment.fileName,
      ),
    );

    _debugLog(
      'Sending attachment request. '
      'file=${attachment.fileName}, '
      'size=${attachment.bytes.length}',
    );

    try {
      final streamedResponse = await request
          .send()
          .timeout(_requestTimeout);

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      _debugLog(
        'Attachment HTTP status=${response.statusCode}',
      );

      _debugLog(
        'Attachment response=${_safeBody(response.body)}',
      );

      final data = _decodeJsonResponse(
        response.body,
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          _extractError(
            data,
            fallback:
                'Unable to process the attachment.',
          ),
        );
      }

      return _parseResponse(data);
    } on TimeoutException {
      throw Exception(
        'The AI service took too long to process the file.',
      );
    } catch (e, stackTrace) {
      _debugLog(
        'Attachment request failed: $e',
      );

      _debugLog(
        stackTrace.toString(),
      );

      if (e is Exception &&
          e.toString().startsWith('Exception:')) {
        rethrow;
      }

      throw Exception(
        'Unable to process the attachment.',
      );
    }
  }

  // ===========================================================================
  // SESSION
  // ===========================================================================

  Session _requireSession() {
    final session =
        _supabase.auth.currentSession;

    if (session == null) {
      throw Exception(
        'Your session has expired. Please log in again.',
      );
    }

    if (session.accessToken.trim().isEmpty) {
      throw Exception(
        'Your authentication session is invalid.',
      );
    }

    return session;
  }

  // ===========================================================================
  // VALIDATE MESSAGES
  // ===========================================================================

  void _validateMessages(
    List<AiChatMessage> messages,
  ) {
    if (messages.isEmpty) {
      throw Exception(
        'No messages were provided.',
      );
    }

    for (final message in messages) {
      final role = message.role.trim();
      final content = message.content.trim();

      if (role.isEmpty) {
        throw Exception(
          'Invalid AI message role.',
        );
      }

      if (content.isEmpty) {
        throw Exception(
          'A message cannot be empty.',
        );
      }

      if (role != 'user' &&
          role != 'assistant' &&
          role != 'system') {
        throw Exception(
          'Invalid AI message role: $role',
        );
      }
    }
  }

  // ===========================================================================
  // VALIDATE ATTACHMENT
  // ===========================================================================

  void _validateAttachment(
    AiAttachment attachment,
  ) {
    if (attachment.bytes.isEmpty) {
      throw Exception(
        'The selected file is empty.',
      );
    }

    if (attachment.bytes.length >
        maxFileBytes) {
      throw Exception(
        'File size must be 20 MB or less.',
      );
    }

    if (!isSupportedFile(
      attachment.fileName,
    )) {
      throw Exception(
        'This file type is not supported.',
      );
    }
  }

  // ===========================================================================
  // PARSE FUNCTION RESPONSE
  // ===========================================================================

  AiChatResponse _parseResponse(
    dynamic data,
  ) {
    _debugLog(
      'Parsing AI response: ${_safeData(data)}',
    );

    if (data == null) {
      throw Exception(
        'AI service returned no response.',
      );
    }

    Map<String, dynamic> map;

    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else if (data is String) {
      final decoded = _decodeJsonResponse(data);

      if (decoded is! Map) {
        throw Exception(
          'Invalid response from AI service.',
        );
      }

      map = Map<String, dynamic>.from(
        decoded,
      );
    } else {
      throw Exception(
        'Invalid response from AI service.',
      );
    }

    final error = _extractError(
      map,
      fallback: '',
    );

    if (error.trim().isNotEmpty) {
      throw Exception(error);
    }

    /*
     * Primary expected response:
     *
     * {
     *   "reply": "...",
     *   "model": "..."
     * }
     */

    final rawReply =
        map['reply'] ??
        map['response'] ??
        map['message'];

    final reply =
        rawReply?.toString().trim() ?? '';

    if (reply.isEmpty) {
      throw Exception(
        'AI returned an empty response.',
      );
    }

    return AiChatResponse(
      reply: reply,
      model: map['model']?.toString(),
    );
  }

  // ===========================================================================
  // DECODE JSON
  // ===========================================================================

  dynamic _decodeJsonResponse(
    String body,
  ) {
    final trimmed = body.trim();

    if (trimmed.isEmpty) {
      throw Exception(
        'AI service returned an empty response.',
      );
    }

    try {
      return jsonDecode(trimmed);
    } catch (e) {
      _debugLog(
        'JSON decode failed. body=$trimmed',
      );

      throw Exception(
        'Invalid response from AI service.',
      );
    }
  }

  // ===========================================================================
  // EXTRACT ERROR
  // ===========================================================================

  String _extractError(
    dynamic data, {
    required String fallback,
  }) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);

      final error =
          map['error'] ??
          map['message'] ??
          map['detail'];

      if (error != null) {
        final value =
            error.toString().trim();

        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return fallback;
  }

  // ===========================================================================
  // NORMALIZE FUNCTION ERROR
  // ===========================================================================

  Exception _normalizeFunctionError(
    Object error,
  ) {
    final raw = error.toString();

    _debugLog(
      'Raw function error: $raw',
    );

    final lower = raw.toLowerCase();

    if (lower.contains('session has expired')) {
      return Exception(
        'Your session has expired. Please log in again.',
      );
    }

    if (lower.contains('unauthorized') ||
        lower.contains('401')) {
      return Exception(
        'Your session is not authorized. Please log in again.',
      );
    }

    if (lower.contains('forbidden') ||
        lower.contains('403')) {
      return Exception(
        'You are not allowed to use the AI service.',
      );
    }

    if (lower.contains('not found') ||
        lower.contains('404')) {
      return Exception(
        'The AI service is not configured correctly.',
      );
    }

    if (lower.contains('timeout') ||
        lower.contains('timed out')) {
      return Exception(
        'The AI service took too long to respond.',
      );
    }

    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return Exception(
        'Unable to connect to the AI service. '
        'Please check your internet connection.',
      );
    }

    if (lower.contains('provider')) {
      return Exception(
        'The AI provider is temporarily unavailable.',
      );
    }

    /*
     * Keep useful server messages when available.
     */
    final cleaned = raw
        .replaceFirst(
          'Exception:',
          '',
        )
        .trim();

    if (cleaned.isNotEmpty) {
      return Exception(cleaned);
    }

    return Exception(
      'Unable to get an AI response. Please try again.',
    );
  }

  // ===========================================================================
  // PUBLISHABLE KEY
  // ===========================================================================

  String _publishableKey() {
    final headers =
        _supabase.rest.headers;

    final key =
        headers['apikey'];

    if (key == null ||
        key.trim().isEmpty) {
      throw Exception(
        'Supabase publishable key is not available.',
      );
    }

    return key;
  }

  // ===========================================================================
  // DEBUG
  // ===========================================================================

  void _debugLog(String message) {
    // ignore: avoid_print
    print('[MediData AI] $message');
  }

  String _safeData(dynamic data) {
    try {
      if (data is Map ||
          data is List) {
        return jsonEncode(data);
      }

      return data.toString();
    } catch (_) {
      return data.toString();
    }
  }

  String _safeBody(String body) {
    const maxLength = 2000;

    if (body.length <= maxLength) {
      return body;
    }

    return '${body.substring(0, maxLength)}...';
  }

  // ===========================================================================
  // MIME TYPE
  // ===========================================================================

  static String mimeTypeForFile(
    String fileName,
  ) {
    final extension =
        fileName
            .split('.')
            .last
            .toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';

      case 'png':
        return 'image/png';

      case 'webp':
        return 'image/webp';

      case 'gif':
        return 'image/gif';

      case 'pdf':
        return 'application/pdf';

      case 'txt':
        return 'text/plain';

      case 'md':
        return 'text/markdown';

      case 'docx':
        return
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      case 'pptx':
        return
            'application/vnd.openxmlformats-officedocument.presentationml.presentation';

      default:
        return 'application/octet-stream';
    }
  }

  // ===========================================================================
  // SUPPORTED FILE
  // ===========================================================================

  static bool isSupportedFile(
    String fileName,
  ) {
    final extension =
        fileName
            .split('.')
            .last
            .toLowerCase();

    return {
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
    }.contains(extension);
  }
}
