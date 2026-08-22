import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================================
/// LECTURE MODEL
/// ============================================================================

class StudentLecture {
  final String id;
  final String moduleId;
  final String title;
  final String? description;
  final int displayOrder;
  final bool isPublished;
  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  const StudentLecture({
    required this.id,
    required this.moduleId,
    required this.title,
    this.description,
    required this.displayOrder,
    required this.isPublished,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  });

  factory StudentLecture.fromMap(Map<String, dynamic> map) {
    return StudentLecture(
      id: map['id'] as String,
      moduleId: map['module_id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isPublished: map['is_published'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
      publishedAt: map['published_at'] != null
          ? DateTime.tryParse(map['published_at'].toString())
          : null,
    );
  }
}

/// ============================================================================
/// LECTURE FILE MODEL
/// ============================================================================

class StudentLectureFile {
  final String id;
  final String lectureId;
  final String title;
  final String fileType;
  final String fileUrl;
  final int displayOrder;
  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StudentLectureFile({
    required this.id,
    required this.lectureId,
    required this.title,
    required this.fileType,
    required this.fileUrl,
    required this.displayOrder,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory StudentLectureFile.fromMap(Map<String, dynamic> map) {
    return StudentLectureFile(
      id: map['id'] as String,
      lectureId: map['lecture_id'] as String,
      title: map['title'] as String? ?? '',
      fileType: map['file_type'] as String? ?? '',
      fileUrl: map['file_url'] as String? ?? '',
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }
}

/// ============================================================================
/// SERVICE
/// ============================================================================

class LecturesService {
  final SupabaseClient _supabase;

  LecturesService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  /// ==========================================================================
  /// GET LECTURES FOR MODULE
  /// ==========================================================================

  Future<List<StudentLecture>> getLectures({required String moduleId}) async {
    final response = await _supabase
        .from('lectures')
        .select(
          'id, '
          'module_id, '
          'title, '
          'description, '
          'display_order, '
          'is_published, '
          'is_active, '
          'created_at, '
          'updated_at, '
          'published_at',
        )
        .eq('module_id', moduleId)
        .eq('is_active', true)
        .eq('is_published', true)
        .order('display_order', ascending: true);

    return (response as List)
        .map((item) => StudentLecture.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// ==========================================================================
  /// GET ALL ACTIVE FILES
  /// ==========================================================================

  Future<List<StudentLectureFile>> getLectureFiles() async {
    final response = await _supabase
        .from('lecture_files')
        .select(
          'id, '
          'lecture_id, '
          'title, '
          'file_type, '
          'file_url, '
          'display_order, '
          'is_active, '
          'created_at, '
          'updated_at',
        )
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return (response as List)
        .map(
          (item) => StudentLectureFile.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  /// ==========================================================================
  /// GET FILES FOR ONE LECTURE
  /// ==========================================================================

  Future<List<StudentLectureFile>> getFilesForLecture(String lectureId) async {
    final response = await _supabase
        .from('lecture_files')
        .select(
          'id, '
          'lecture_id, '
          'title, '
          'file_type, '
          'file_url, '
          'display_order, '
          'is_active, '
          'created_at, '
          'updated_at',
        )
        .eq('lecture_id', lectureId)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return (response as List)
        .map(
          (item) => StudentLectureFile.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  /// ==========================================================================
  /// BUCKET
  /// ==========================================================================

  String bucketForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'Lecture pdfs';

      case 'audio':
        return 'Lecture audios';

      case 'video':
        return 'lecture videos';

      default:
        throw Exception('Unsupported lecture file type: $type');
    }
  }

  /// ==========================================================================
  /// CREATE SIGNED URL
  ///
  /// Buckets are PRIVATE, therefore we cannot use getPublicUrl().
  /// ==========================================================================

  Future<String> createSignedUrl(StudentLectureFile file) async {
    final bucket = bucketForType(file.fileType);

    final path = _extractStoragePath(file.fileUrl, bucket);

    if (path.isEmpty) {
      throw Exception('Invalid storage path for "${file.title}".');
    }

    return _supabase.storage.from(bucket).createSignedUrl(path, 3600);
  }

  /// ==========================================================================
  /// EXTRACT STORAGE PATH
  ///
  /// Supports:
  ///
  /// 1. lectureId/file.pdf
  ///
  /// 2. https://.../storage/v1/object/public/Bucket/file.pdf
  ///
  /// 3. https://.../storage/v1/object/sign/Bucket/file.pdf
  /// ==========================================================================

  String _extractStoragePath(String value, String bucket) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    // Already a storage path.
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);

    if (uri == null) {
      return '';
    }

    final decodedSegments = uri.pathSegments.map(Uri.decodeComponent).toList();

    final bucketIndex = decodedSegments.indexWhere(
      (segment) => segment == bucket,
    );

    if (bucketIndex == -1) {
      throw Exception('Bucket "$bucket" was not found in file URL.');
    }

    if (bucketIndex + 1 >= decodedSegments.length) {
      return '';
    }

    return decodedSegments.sublist(bucketIndex + 1).join('/');
  }
}
