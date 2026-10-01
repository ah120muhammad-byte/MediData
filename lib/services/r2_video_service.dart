import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class R2VideoService {
  static const String backendUrl = String.fromEnvironment(
    'TELEGRAM_BACKEND_URL',
    defaultValue: 'https://admin-dashboard-web.ahmedmmunir.blitz.cloud',
  );

  final SupabaseClient _supabase;
  final Dio _dio;

  R2VideoService({
    SupabaseClient? supabase,
    Dio? dioClient,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _dio = dioClient ?? Dio();

  Future<String> createSignedUrl(String key) async {
    final cleanKey = key.startsWith('r2:') ? key.substring(3).trim() : key.trim();
    if (cleanKey.isEmpty) throw Exception('R2 video key is empty.');

    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '$backendUrl/api/r2/signed-url',
      data: {'key': cleanKey},
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        contentType: 'application/json',
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );

    final url = response.data?['url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('R2 did not return a video URL.');
    return url;
  }
}
