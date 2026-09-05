import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AiChatMessage {
  final String role;
  final String content;
  const AiChatMessage({required this.role, required this.content});
  Map<String, dynamic> toMap() => {'role': role, 'content': content};
}

class AiAttachment {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final bool isImage;
  const AiAttachment({required this.fileName, required this.mimeType, required this.bytes, required this.isImage});
  int get sizeInBytes => bytes.length;
}

class AiChatResponse {
  final String reply;
  final String? model;
  const AiChatResponse({required this.reply, this.model});
}

class AiChatService {
  AiChatService();
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _functionName = 'ai-chat';
  static const String _supabaseProjectUrl = 'https://eoyehpqknyoksaxlvnwl.supabase.co';
  static const String _functionUrl = '$_supabaseProjectUrl/functions/v1/$_functionName';
  static const Duration _requestTimeout = Duration(seconds: 90);
  static const int maxFileBytes = 20 * 1024 * 1024;

  Future<AiChatResponse> sendMessage({required List<AiChatMessage> messages}) async {
    _validateMessages(messages);
    _requireSession();
    try {
      final response = await _supabase.functions.invoke(_functionName, body: {'messages': messages.map((m) => m.toMap()).toList()}).timeout(_requestTimeout);
      return _parseResponse(response.data);
    } on TimeoutException {
      throw Exception('The AI service took too long to respond.');
    } catch (e, stackTrace) {
      _debugLog('Text request failed: $e');
      _debugLog(stackTrace.toString());
      throw _normalizeFunctionError(e);
    }
  }

  /// Streams assistant text as it arrives from the Edge Function.
  /// The callback receives the complete accumulated text after each chunk.
  Future<AiChatResponse> sendMessageStreaming({
    required List<AiChatMessage> messages,
    required void Function(String text) onText,
  }) async {
    _validateMessages(messages);
    final session = _requireSession();
    final request = http.Request('POST', Uri.parse(_functionUrl));
    request.headers.addAll({'Authorization': 'Bearer ${session.accessToken}', 'apikey': _publishableKey(), 'Accept': 'text/event-stream', 'Content-Type': 'application/json'});
    request.body = jsonEncode({'messages': messages.map((m) => m.toMap()).toList(), 'stream': true});

    try {
      final response = await request.send().timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw Exception(_extractError(_decodeJsonResponse(body), fallback: 'Unable to get an AI response.'));
      }

      final buffer = StringBuffer();
      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        final raw = line.trim();
        if (raw.isEmpty || raw.startsWith(':')) continue;
        final payload = raw.startsWith('data:') ? raw.substring(5).trim() : raw;
        if (payload == '[DONE]') break;
        try {
          final decoded = jsonDecode(payload);
          final chunk = decoded is Map ? (decoded['delta'] ?? decoded['content'] ?? decoded['reply'] ?? '') : decoded.toString();
          if (chunk.toString().isNotEmpty) {
            buffer.write(chunk.toString());
            onText(buffer.toString());
          }
        } catch (_) {
          // Some providers may send plain text chunks.
          buffer.write(payload);
          onText(buffer.toString());
        }
      }

      final reply = buffer.toString().trim();
      if (reply.isEmpty) throw Exception('AI returned an empty response.');
      return AiChatResponse(reply: reply);
    } on TimeoutException {
      throw Exception('The AI service took too long to respond.');
    } catch (e, stackTrace) {
      _debugLog('Streaming request failed: $e');
      _debugLog(stackTrace.toString());
      throw _normalizeFunctionError(e);
    }
  }

  Future<AiChatResponse> sendMessageWithAttachment({required List<AiChatMessage> messages, required AiAttachment attachment}) async {
    _validateMessages(messages);
    final session = _requireSession();
    _validateAttachment(attachment);
    final request = http.MultipartRequest('POST', Uri.parse(_functionUrl));
    request.headers.addAll({'Authorization': 'Bearer ${session.accessToken}', 'apikey': _publishableKey(), 'Accept': 'application/json'});
    request.fields['messages'] = jsonEncode(messages.map((m) => m.toMap()).toList());
    request.fields['fileName'] = attachment.fileName;
    request.fields['mimeType'] = attachment.mimeType;
    request.files.add(http.MultipartFile.fromBytes('file', attachment.bytes, filename: attachment.fileName));
    try {
      final streamedResponse = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final data = _decodeJsonResponse(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(_extractError(data, fallback: 'Unable to process the attachment.'));
      return _parseResponse(data);
    } on TimeoutException {
      throw Exception('The AI service took too long to process the file.');
    } catch (e) {
      if (e is Exception && e.toString().startsWith('Exception:')) rethrow;
      throw Exception('Unable to process the attachment.');
    }
  }

  Session _requireSession() {
    final session = _supabase.auth.currentSession;
    if (session == null || session.accessToken.trim().isEmpty) throw Exception('Your session has expired. Please log in again.');
    return session;
  }

  void _validateMessages(List<AiChatMessage> messages) {
    if (messages.isEmpty) throw Exception('No messages were provided.');
    for (final message in messages) {
      if (message.role.trim().isEmpty || message.content.trim().isEmpty) throw Exception('A message cannot be empty.');
      if (!{'user', 'assistant', 'system'}.contains(message.role.trim())) throw Exception('Invalid AI message role: ${message.role}');
    }
  }

  void _validateAttachment(AiAttachment attachment) {
    if (attachment.bytes.isEmpty) throw Exception('The selected file is empty.');
    if (attachment.bytes.length > maxFileBytes) throw Exception('File size must be 20 MB or less.');
    if (!isSupportedFile(attachment.fileName)) throw Exception('This file type is not supported.');
  }

  AiChatResponse _parseResponse(dynamic data) {
    if (data == null) throw Exception('AI service returned no response.');
    Map<String, dynamic> map;
    if (data is Map) map = Map<String, dynamic>.from(data);
    else if (data is String) {
      final decoded = _decodeJsonResponse(data);
      if (decoded is! Map) throw Exception('Invalid response from AI service.');
      map = Map<String, dynamic>.from(decoded);
    } else throw Exception('Invalid response from AI service.');
    final error = _extractError(map, fallback: '');
    if (error.isNotEmpty) throw Exception(error);
    final reply = (map['reply'] ?? map['response'] ?? map['message'])?.toString().trim() ?? '';
    if (reply.isEmpty) throw Exception('AI returned an empty response.');
    return AiChatResponse(reply: reply, model: map['model']?.toString());
  }

  dynamic _decodeJsonResponse(String body) {
    if (body.trim().isEmpty) throw Exception('AI service returned an empty response.');
    try { return jsonDecode(body.trim()); } catch (_) { throw Exception('Invalid response from AI service.'); }
  }

  String _extractError(dynamic data, {required String fallback}) {
    if (data is Map) {
      final value = (data['error'] ?? data['message'] ?? data['detail'])?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  Exception _normalizeFunctionError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('401') || lower.contains('unauthorized')) return Exception('Your session is not authorized. Please log in again.');
    if (lower.contains('403') || lower.contains('forbidden')) return Exception('You are not allowed to use the AI service.');
    if (lower.contains('timeout') || lower.contains('timed out')) return Exception('The AI service took too long to respond.');
    if (lower.contains('network') || lower.contains('socket') || lower.contains('connection')) return Exception('Unable to connect to the AI service. Please check your internet connection.');
    if (lower.contains('provider')) return Exception('The AI provider is temporarily unavailable.');
    final cleaned = raw.replaceFirst('Exception:', '').trim();
    return Exception(cleaned.isEmpty ? 'Unable to get an AI response. Please try again.' : cleaned);
  }

  String _publishableKey() {
    final key = _supabase.rest.headers['apikey'];
    if (key == null || key.trim().isEmpty) throw Exception('Supabase publishable key is not available.');
    return key;
  }

  void _debugLog(String message) { print('[MediData AI] $message'); }

  static String mimeTypeForFile(String fileName) {
    switch (fileName.split('.').last.toLowerCase()) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'gif': return 'image/gif';
      case 'pdf': return 'application/pdf';
      case 'txt': return 'text/plain';
      case 'md': return 'text/markdown';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default: return 'application/octet-stream';
    }
  }

  static bool isSupportedFile(String fileName) => {'jpg','jpeg','png','webp','gif','pdf','txt','md','docx','pptx'}.contains(fileName.split('.').last.toLowerCase());
}
