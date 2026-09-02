import 'package:supabase_flutter/supabase_flutter.dart';

class SupportService {
  SupportService._();
  static final SupportService instance = SupportService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> submitMessage({
    required String subject,
    required String message,
  }) async {
    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();

    if (cleanSubject.isEmpty || cleanMessage.isEmpty) {
      throw Exception('Subject and message are required.');
    }

    final response = await _supabase.functions.invoke(
      'submit-support-message',
      body: {
        'subject': cleanSubject,
        'message': cleanMessage,
      },
    );

    if (response.data is Map && (response.data as Map)['error'] != null) {
      throw Exception((response.data as Map)['error'].toString());
    }
  }
}
