import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lecture_files_service.dart';

// ============================================================================
// UI HELPERS FOR LectureFile
// ============================================================================
//
// Same icon/label logic that already lived inline inside
// LectureContentScreen — pulled out here so both the new LectureCard
// and the existing LectureContentScreen can share it.

extension LectureFileUi on LectureFile {
  IconData get icon {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'audio':
        return Icons.audio_file_rounded;
      case 'video':
        return Icons.video_library_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  String get actionLabel {
    switch (fileType) {
      case 'pdf':
        return 'Open';
      case 'audio':
        return 'Play';
      case 'video':
        return 'Watch';
      default:
        return 'Open';
    }
  }
}

// ============================================================================
// LECTURE MODEL
// ============================================================================

class Lecture {
  final String id;
  final String moduleId;
  final String title;
  final String? subtitle;
  final int displayOrder;
  final List<LectureFile> files;

  const Lecture({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.subtitle,
    required this.displayOrder,
    required this.files,
  });
}

// ============================================================================
// LECTURES SERVICE
// ============================================================================

class LecturesService {
  final SupabaseClient _supabase;

  LecturesService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  // ==========================================================================
  // GET LECTURES FOR A MODULE (with their files, batched in 2 queries)
  // ==========================================================================

  Future<List<Lecture>> getModuleLectures(String moduleId) async {
    final lecturesResponse = await _supabase
        .from('lectures')
        .select('id, module_id, title, subtitle, display_order, is_active')
        .eq('module_id', moduleId)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    final lectureRows = List<Map<String, dynamic>>.from(lecturesResponse);

    if (lectureRows.isEmpty) {
      return [];
    }

    final lectureIds = lectureRows
        .map((row) => row['id'] as String)
        .toList();

    final filesResponse = await _supabase
        .from('lecture_files')
        .select(
          'id, lecture_id, title, file_type, file_url, '
          'display_order, is_active',
        )
        .inFilter('lecture_id', lectureIds)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    final fileRows = List<Map<String, dynamic>>.from(filesResponse);

    final Map<String, List<LectureFile>> filesByLecture = {};

    for (final row in fileRows) {
      final file = LectureFile.fromMap(row);
      filesByLecture.putIfAbsent(file.lectureId, () => []).add(file);
    }

    return lectureRows.map((row) {
      final id = row['id'] as String;

      return Lecture(
        id: id,
        moduleId: row['module_id'] as String,
        title: row['title']?.toString() ?? '',
        subtitle: row['subtitle']?.toString(),
        displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
        files: filesByLecture[id] ?? const [],
      );
    }).toList();
  }
}
