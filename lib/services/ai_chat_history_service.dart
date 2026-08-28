import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_chat_service.dart';

class AiChatHistoryService {
  AiChatHistoryService._();

  static final AiChatHistoryService instance =
      AiChatHistoryService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  static const String _currentSessionKey =
      'medidata_current_ai_chat_session';

  Future<String> createSession({
    String title = 'New chat',
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Your session has expired. Please log in again.',
      );
    }

    final response = await _supabase
        .from('ai_chat_sessions')
        .insert({
          'user_id': user.id,
          'title': _sanitizeTitle(title),
        })
        .select('id')
        .single();

    final id = response['id']?.toString();

    if (id == null || id.isEmpty) {
      throw Exception('Unable to create AI chat session.');
    }

    await _saveCurrentSessionId(id);

    return id;
  }

  Future<String?> getCurrentSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentSessionKey);
  }

  Future<void> _saveCurrentSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentSessionKey, sessionId);
  }

  Future<void> clearCurrentSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
  }

  Future<List<AiChatMessage>> loadMessages(
    String sessionId,
  ) async {
    final response = await _supabase
        .from('ai_chat_messages')
        .select('role, content')
        .eq('session_id', sessionId)
        .order('created_at', ascending: true);

    return (response as List)
        .map(
          (row) => AiChatMessage(
            role: row['role'].toString(),
            content: row['content'].toString(),
          ),
        )
        .toList();
  }

  Future<void> saveMessage({
    required String sessionId,
    required AiChatMessage message,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Your session has expired. Please log in again.',
      );
    }

    await _supabase.from('ai_chat_messages').insert({
      'session_id': sessionId,
      'user_id': user.id,
      'role': message.role,
      'content': message.content,
    });

    await _supabase
        .from('ai_chat_sessions')
        .update({
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId)
        .eq('user_id', user.id);
  }

  Future<void> updateTitle({
    required String sessionId,
    required String title,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    await _supabase
        .from('ai_chat_sessions')
        .update({
          'title': _sanitizeTitle(title),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId)
        .eq('user_id', user.id);
  }

  Future<void> deleteSession(String sessionId) async {
    await _supabase
        .from('ai_chat_sessions')
        .delete()
        .eq('id', sessionId);

    final current = await getCurrentSessionId();

    if (current == sessionId) {
      await clearCurrentSessionId();
    }
  }

  Future<void> ensureCurrentSession() async {
    final existing = await getCurrentSessionId();

    if (existing != null && existing.isNotEmpty) {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        final row = await _supabase
            .from('ai_chat_sessions')
            .select('id')
            .eq('id', existing)
            .eq('user_id', user.id)
            .maybeSingle();

        if (row != null) {
          return;
        }
      }

      await clearCurrentSessionId();
    }

    await createSession();
  }

  String _sanitizeTitle(String title) {
    final value = title.trim();

    if (value.isEmpty) {
      return 'New chat';
    }

    if (value.length <= 80) {
      return value;
    }

    return value.substring(0, 80);
  }
}