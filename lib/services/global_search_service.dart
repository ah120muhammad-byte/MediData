import 'package:supabase_flutter/supabase_flutter.dart';

enum SearchResultType {
  level,
  module,
  lecture,
}

class GlobalSearchResult {
  final SearchResultType type;

  final String id;
  final String title;

  final String? description;

  final String? levelId;
  final String? levelName;

  final String? moduleId;
  final String? moduleName;

  final String? lectureId;
  final String? lectureTitle;

  const GlobalSearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.description,
    this.levelId,
    this.levelName,
    this.moduleId,
    this.moduleName,
    this.lectureId,
    this.lectureTitle,
  });
}

class GlobalSearchService {
  GlobalSearchService._();

  static final GlobalSearchService instance =
      GlobalSearchService._();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  Future<List<GlobalSearchResult>> search(
    String query,
  ) async {
    final normalizedQuery =
        query.trim();

    if (normalizedQuery.isEmpty) {
      return [];
    }

    final results =
        <GlobalSearchResult>[];

    await Future.wait([
      _searchLevels(
        normalizedQuery,
        results,
      ),
      _searchModules(
        normalizedQuery,
        results,
      ),
      _searchLectures(
        normalizedQuery,
        results,
      ),
    ]);

    // -------------------------------------------------------------------------
    // Sort:
    //
    // 1. exact title match
    // 2. starts with query
    // 3. contains query
    // -------------------------------------------------------------------------

    final lowerQuery =
        normalizedQuery.toLowerCase();

    results.sort(
      (a, b) {
        final aTitle =
            a.title.toLowerCase();

        final bTitle =
            b.title.toLowerCase();

        int score(
          String value,
        ) {
          if (value == lowerQuery) {
            return 0;
          }

          if (value.startsWith(
            lowerQuery,
          )) {
            return 1;
          }

          if (value.contains(
            lowerQuery,
          )) {
            return 2;
          }

          return 3;
        }

        final scoreCompare =
            score(aTitle).compareTo(
          score(bTitle),
        );

        if (scoreCompare != 0) {
          return scoreCompare;
        }

        return aTitle.compareTo(
          bTitle,
        );
      },
    );

    return results;
  }

  // ===========================================================================
  // LEVELS
  // ===========================================================================

  Future<void> _searchLevels(
    String query,
    List<GlobalSearchResult> results,
  ) async {
    final response =
        await _supabase
            .from('academic_levels')
            .select(
              '''
              id,
              name,
              description,
              is_active
              ''',
            )
            .eq(
              'is_active',
              true,
            )
            .ilike(
              'name',
              '%$query%',
            )
            .limit(20);

    for (final item
        in response as List) {
      final map =
          Map<String, dynamic>.from(
        item,
      );

      results.add(
        GlobalSearchResult(
          type:
              SearchResultType.level,
          id:
              map['id'].toString(),
          title:
              map['name']?.toString() ??
                  '',
          description:
              map['description']
                  ?.toString(),
          levelId:
              map['id'].toString(),
          levelName:
              map['name']?.toString(),
        ),
      );
    }
  }

  // ===========================================================================
  // MODULES
  // ===========================================================================

  Future<void> _searchModules(
    String query,
    List<GlobalSearchResult> results,
  ) async {
    final response =
        await _supabase
            .from('modules')
            .select(
              '''
              id,
              name,
              description,
              academic_level_id,
              is_active,
              academic_levels (
                id,
                name
              )
              ''',
            )
            .eq(
              'is_active',
              true,
            )
            .ilike(
              'name',
              '%$query%',
            )
            .limit(30);

    for (final item
        in response as List) {
      final map =
          Map<String, dynamic>.from(
        item,
      );

      final levelRaw =
          map['academic_levels'];

      Map<String, dynamic>?
          level;

      if (levelRaw is Map) {
        level =
            Map<String, dynamic>.from(
          levelRaw,
        );
      }

      results.add(
        GlobalSearchResult(
          type:
              SearchResultType.module,
          id:
              map['id'].toString(),
          title:
              map['name']?.toString() ??
                  '',
          description:
              map['description']
                  ?.toString(),
          levelId:
              map['academic_level_id']
                  ?.toString(),
          levelName:
              level?['name']?.toString(),
          moduleId:
              map['id'].toString(),
          moduleName:
              map['name']?.toString(),
        ),
      );
    }
  }

  // ===========================================================================
  // LECTURES
  // ===========================================================================

  Future<void> _searchLectures(
    String query,
    List<GlobalSearchResult> results,
  ) async {
    final response =
        await _supabase
            .from('lectures')
            .select(
              '''
              id,
              module_id,
              title,
              description,
              is_published,
              is_active,
              modules (
                id,
                name,
                academic_level_id,
                academic_levels (
                  id,
                  name
                )
              )
              ''',
            )
            .eq(
              'is_active',
              true,
            )
            .eq(
              'is_published',
              true,
            )
            .ilike(
              'title',
              '%$query%',
            )
            .limit(50);

    for (final item
        in response as List) {
      final map =
          Map<String, dynamic>.from(
        item,
      );

      final moduleRaw =
          map['modules'];

      Map<String, dynamic>?
          module;

      if (moduleRaw is Map) {
        module =
            Map<String, dynamic>.from(
          moduleRaw,
        );
      }

      Map<String, dynamic>?
          level;

      final levelRaw =
          module?['academic_levels'];

      if (levelRaw is Map) {
        level =
            Map<String, dynamic>.from(
          levelRaw,
        );
      }

      final lectureId =
          map['id'].toString();

      final moduleId =
          map['module_id']?.toString();

      if (moduleId == null ||
          moduleId.isEmpty) {
        continue;
      }

      results.add(
        GlobalSearchResult(
          type:
              SearchResultType.lecture,
          id:
              lectureId,
          title:
              map['title']?.toString() ??
                  '',
          description:
              map['description']
                  ?.toString(),
          lectureId:
              lectureId,
          lectureTitle:
              map['title']?.toString(),
          moduleId:
              moduleId,
          moduleName:
              module?['name']
                  ?.toString(),
          levelId:
              module?['academic_level_id']
                  ?.toString(),
          levelName:
              level?['name']
                  ?.toString(),
        ),
      );
    }
  }
}