import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class LectureStorageService {
  LectureStorageService._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================================================================
  // BUCKETS
  // ==========================================================================

  static const String pdfBucket = 'Lecture pdfs';
  static const String audioBucket = 'Lecture audios';
  static const String videoBucket = 'lecture videos';

  // ==========================================================================
  // GET BUCKET
  // ==========================================================================

  static String bucketForType(LectureFileType type) {
    switch (type) {
      case LectureFileType.pdf:
        return pdfBucket;

      case LectureFileType.audio:
        return audioBucket;

      case LectureFileType.video:
        return videoBucket;
    }
  }

  // ==========================================================================
  // NORMALIZE PATH
  // ==========================================================================

  static String normalizePath(String path) {
    var cleanPath = path.trim();

    // لو الـ DB فيها URL كامل بدل path،
    // نحاول استخراج الـ path من URL.
    if (cleanPath.startsWith('http://') ||
        cleanPath.startsWith('https://')) {
      final uri = Uri.tryParse(cleanPath);

      if (uri != null) {
        final segments = uri.pathSegments;

        final objectIndex = segments.indexOf('object');

        if (objectIndex != -1 &&
            objectIndex + 2 < segments.length) {
          return Uri.decodeComponent(
            segments.sublist(objectIndex + 2).join('/'),
          );
        }

        final downloadIndex = segments.indexOf('download');

        if (downloadIndex != -1 &&
            downloadIndex + 2 < segments.length) {
          return Uri.decodeComponent(
            segments.sublist(downloadIndex + 2).join('/'),
          );
        }
      }
    }

    return cleanPath.startsWith('/')
        ? cleanPath.substring(1)
        : cleanPath;
  }

  // ==========================================================================
  // CREATE SIGNED URL
  // ==========================================================================

  static Future<String> createSignedUrl({
    required LectureFileType type,
    required String path,
    int expiresIn = 3600,
  }) async {
    final cleanPath = normalizePath(path);

    if (cleanPath.isEmpty) {
      throw Exception('File path is empty.');
    }

    final bucket = bucketForType(type);

    return await _supabase.storage
        .from(bucket)
        .createSignedUrl(
          cleanPath,
          expiresIn,
        );
  }

  // ==========================================================================
  // DOWNLOAD FILE
  // ==========================================================================

  static Future<Uint8List> download({
    required LectureFileType type,
    required String path,
  }) async {
    final cleanPath = normalizePath(path);

    if (cleanPath.isEmpty) {
      throw Exception('File path is empty.');
    }

    final bucket = bucketForType(type);

    return await _supabase.storage
        .from(bucket)
        .download(cleanPath);
  }
}

// ============================================================================
// FILE TYPE
// ============================================================================

enum LectureFileType {
  pdf,
  audio,
  video,
}