import 'package:supabase_flutter/supabase_flutter.dart';

class LectureFile {
  final String id;
  final String lectureId;
  final String title;
  final String fileType;
  final String filePath;
  final int displayOrder;
  final bool isActive;

  const LectureFile({
    required this.id,
    required this.lectureId,
    required this.title,
    required this.fileType,
    required this.filePath,
    required this.displayOrder,
    required this.isActive,
  });

  factory LectureFile.fromMap(Map<String, dynamic> map) {
    return LectureFile(
      id: map['id']?.toString() ?? '',
      lectureId: map['lecture_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      fileType: map['file_type']?.toString().toLowerCase() ?? '',
      filePath: map['file_url']?.toString() ?? '',
      displayOrder:
          (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  bool get isPdf => fileType == 'pdf';

  bool get isAudio => fileType == 'audio';

  bool get isVideo => fileType == 'video';

  String get typeLabel {
    switch (fileType) {
      case 'pdf':
        return 'PDF';

      case 'audio':
        return 'Audio';

      case 'video':
        return 'Video';

      default:
        return fileType.toUpperCase();
    }
  }
}

class LectureContentService {
  final SupabaseClient _supabase;

  LectureContentService({
    SupabaseClient? supabase,
  }) : _supabase =
            supabase ?? Supabase.instance.client;

  // ==========================================================================
  // GET FILES FOR LECTURE
  // ==========================================================================

  Future<List<LectureFile>> getFilesForLecture(
    String lectureId,
  ) async {
    final response = await _supabase
        .from('lecture_files')
        .select(
          '''
          id,
          lecture_id,
          title,
          file_type,
          file_url,
          display_order,
          is_active
          ''',
        )
        .eq(
          'lecture_id',
          lectureId,
        )
        .eq(
          'is_active',
          true,
        )
        .order(
          'display_order',
          ascending: true,
        );

    return (response as List)
        .map(
          (item) => LectureFile.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // BUCKET
  // ==========================================================================

  String bucketForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return 'Lecture pdfs';

      case 'audio':
        return 'Lecture audios';

      case 'video':
        return 'lecture videos';

      default:
        throw Exception(
          'Unsupported lecture file type: $type',
        );
    }
  }

  // ==========================================================================
  // CREATE SIGNED URL
  // ==========================================================================

  Future<String> createSignedUrl(
    LectureFile file,
  ) async {
    final bucket = bucketForType(
      file.fileType,
    );

    final path = _extractStoragePath(
      file.filePath,
      bucket,
    );

    if (path.isEmpty) {
      throw Exception(
        'Invalid storage path for "${file.title}".',
      );
    }

    return await _supabase.storage
        .from(bucket)
        .createSignedUrl(
          path,
          3600,
        );
  }

  // ==========================================================================
  // EXTRACT STORAGE PATH
  // ==========================================================================

  String _extractStoragePath(
    String value,
    String bucket,
  ) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    // =========================================================================
    // CURRENT FORMAT
    //
    // lectureId/file.pdf
    // =========================================================================

    if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://')) {
      return trimmed;
    }

    // =========================================================================
    // OLD URL FORMAT
    // =========================================================================

    final uri = Uri.tryParse(trimmed);

    if (uri == null) {
      return trimmed;
    }

    final segments = uri.pathSegments;

    final bucketIndex = segments.indexWhere(
      (segment) {
        final decoded = Uri.decodeComponent(segment);

        return decoded == bucket;
      },
    );

    if (bucketIndex == -1) {
      throw Exception(
        'Bucket "$bucket" was not found in file URL.',
      );
    }

    if (bucketIndex + 1 >= segments.length) {
      return '';
    }

    final pathSegments = segments.sublist(
      bucketIndex + 1,
    );

    return pathSegments
        .map(
          Uri.decodeComponent,
        )
        .join('/');
  }
}