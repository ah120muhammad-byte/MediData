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
  final SupabaseClient _supabase =
      Supabase.instance.client;

  static const String _supabaseProjectUrl =
      'https://eoyehpqknyoksaxlvnwl.supabase.co';

  static const String _functionUrl =
      '$_supabaseProjectUrl/functions/v1/ai-chat';

  static const int maxFileBytes =
      20 * 1024 * 1024;

  // ===========================================================================
  // SEND TEXT ONLY
  // ===========================================================================

  Future<AiChatResponse> sendMessage({
    required List<AiChatMessage> messages,
  }) async {
    final session =
        _supabase.auth.currentSession;

    if (session == null) {
      throw Exception(
        'Your session has expired. Please log in again.',
      );
    }

    final response =
        await _supabase.functions.invoke(
      'ai-chat',
      body: {
        'messages': messages
            .map(
              (message) => message.toMap(),
            )
            .toList(),
      },
    );

    return _parseResponse(
      response.data,
    );
  }

  // ===========================================================================
  // SEND WITH ATTACHMENT
  // ===========================================================================

  Future<AiChatResponse> sendMessageWithAttachment({
    required List<AiChatMessage> messages,
    required AiAttachment attachment,
  }) async {
    final session =
        _supabase.auth.currentSession;

    if (session == null) {
      throw Exception(
        'Your session has expired. Please log in again.',
      );
    }

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

    final request =
        http.MultipartRequest(
      'POST',
      Uri.parse(_functionUrl),
    );

    request.headers.addAll({
      'Authorization':
          'Bearer ${session.accessToken}',
      'apikey':
          _publishableKey(),
    });

    request.fields['messages'] =
        jsonEncode(
      messages
          .map(
            (message) =>
                message.toMap(),
          )
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
        filename:
            attachment.fileName,
      ),
    );

    final streamedResponse =
        await request.send();

    final response =
        await http.Response.fromStream(
      streamedResponse,
    );

    dynamic data;

    try {
      data = jsonDecode(
        response.body,
      );
    } catch (_) {
      throw Exception(
        'Invalid response from AI service.',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      final error =
          data is Map
              ? data['error']?.toString()
              : null;

      throw Exception(
        error ??
            'Unable to process the attachment.',
      );
    }

    return _parseResponse(data);
  }

  // ===========================================================================
  // RESPONSE
  // ===========================================================================

  AiChatResponse _parseResponse(
    dynamic data,
  ) {
    if (data is! Map) {
      throw Exception(
        'Invalid response from AI service.',
      );
    }

    final map =
        Map<String, dynamic>.from(data);

    final error =
        map['error']?.toString();

    if (error != null &&
        error.trim().isNotEmpty) {
      throw Exception(error);
    }

    final reply =
        map['reply']?.toString().trim();

    if (reply == null ||
        reply.isEmpty) {
      throw Exception(
        'AI returned an empty response.',
      );
    }

    return AiChatResponse(
      reply: reply,
      model:
          map['model']?.toString(),
    );
  }

  // ===========================================================================
  // PUBLISHABLE KEY
  // ===========================================================================

  String _publishableKey() {
    // Uses the same public key already configured
    // in your Flutter Supabase initialization.
    //
    // Replace this with your existing publishable/
    // anon key constant if your project keeps it
    // in a separate config file.

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
        return 'application/'
            'vnd.openxmlformats-officedocument'
            '.wordprocessingml.document';

      case 'pptx':
        return 'application/'
            'vnd.openxmlformats-officedocument'
            '.presentationml.presentation';

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