import 'package:supabase_flutter/supabase_flutter.dart';

class LectureFile {
  final String id;
  final String lectureId;
  final String title;
  final String fileType;
  final String fileUrl;
  final int displayOrder;
  final bool isActive;

  const LectureFile({
    required this.id,
    required this.lectureId,
    required this.title,
    required this.fileType,
    required this.fileUrl,
    required this.displayOrder,
    required this.isActive,
  });

  factory LectureFile.fromMap(Map<String, dynamic> map) {
    return LectureFile(
      id: map['id'] as String,
      lectureId: map['lecture_id'] as String,
      title: map['title'] as String? ?? 'Untitled',
      fileType: (map['file_type'] as String? ?? '')
          .trim()
          .toLowerCase(),
      fileUrl: map['file_url'] as String? ?? '',
      displayOrder:
          (map['display_order'] as num?)?.toInt() ?? 0,
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class LectureFilesService {
  final SupabaseClient _supabase;

  LectureFilesService({
    SupabaseClient? supabase,
  }) : _supabase =
            supabase ?? Supabase.instance.client;

  Future<List<LectureFile>> getLectureFiles(
    String lectureId,
  ) async {
    final response = await _supabase
        .from('lecture_files')
        .select(
          'id, lecture_id, title, file_type, file_url, '
          'display_order, is_active',
        )
        .eq('lecture_id', lectureId)
        .eq('is_active', true)
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
}