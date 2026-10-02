import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class R2VideoService {
  static const String backendUrl = String.fromEnvironment(
    'R2_BACKEND_URL',
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

    String? token = await _getValidAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    late Response<Map<String, dynamic>> response;

    try {
      response = await _requestSignedUrl(
        key: cleanKey,
        accessToken: token,
      );
    } on DioException catch (error) {
      debugPrint(
        'R2 signed-url request failed: status=${error.response?.statusCode}, data=${error.response?.data}, backend=$backendUrl',
      );
      // A cached access token can become invalid while the app is open.
      // Refresh once and retry the request before asking the user to sign in.
      if (error.response?.statusCode != 401) {
        rethrow;
      }

      token = await _refreshAccessToken();
      response = await _requestSignedUrl(
        key: cleanKey,
        accessToken: token,
      );
    }

    final url = response.data?['url']?.toString() ?? '';
    if (url.isEmpty) throw Exception('R2 did not return a video URL.');
    return url;
  }

  Future<String?> _getValidAccessToken() async {
    final session = _supabase.auth.currentSession;

    if (session == null) {
      return null;
    }

    if (session.isExpired) {
      return _refreshAccessToken();
    }

    return session.accessToken;
  }

  Future<String> _refreshAccessToken() async {
    try {
      final authResponse = await _supabase.auth.refreshSession();
      final refreshedSession = authResponse.session;
      final token = refreshedSession?.accessToken;

      if (token == null || token.isEmpty) {
        throw Exception('Supabase did not return a refreshed access token.');
      }

      return token;
    } catch (_) {
      throw Exception('Your session has expired. Please sign in again.');
    }
  }

  Future<Response<Map<String, dynamic>>> _requestSignedUrl({
    required String key,
    required String accessToken,
  }) {
    return _dio.post<Map<String, dynamic>>(
      '$backendUrl/api/r2/signed-url',
      data: {'key': key},
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
        contentType: 'application/json',
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
  }
}
