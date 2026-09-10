import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import '../../services/global_search_service.dart';
import '../../widgets/module_card.dart';

class SearchScreen extends StatefulWidget {
  final Future<void> Function(String lectureId)? onOpenLecture;
  final Future<void> Function(String moduleId)? onOpenModule;

  const SearchScreen({
    super.key,
    this.onOpenLecture,
    this.onOpenModule,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final GlobalSearchService _searchService = GlobalSearchService.instance;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _loading = false;
  String _query = '';
  String? _error;
  List<GlobalSearchResult> _results = <GlobalSearchResult>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (!mounted) return;

    setState(() {
      _query = query;
      _error = null;
    });

    if (query.isEmpty) {
      setState(() {
        _results = <GlobalSearchResult>[];
        _loading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_performSearch(query));
    });
  }

  Future<void> _performSearch(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _searchService.search(normalizedQuery);
      if (!mounted || _query != normalizedQuery) return;

      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Global search error: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Unable to search right now.';
      });
    }
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _debounce?.cancel();
    unawaited(_performSearch(query));
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    if (!mounted) return;

    setState(() {
      _query = '';
      _results = <GlobalSearchResult>[];
      _loading = false;
      _error = null;
    });

    _focusNode.requestFocus();
  }

  Future<void> _openResult(GlobalSearchResult result) async {
    _focusNode.unfocus();

    switch (result.type) {
      case SearchResultType.lecture:
        final lectureId = result.lectureId?.trim();
        final callback = widget.onOpenLecture;
        if (lectureId == null || lectureId.isEmpty || callback == null) return;

        await callback(lectureId);
        if (mounted) Navigator.of(context).pop();
        return;

      case SearchResultType.module:
        final moduleId = result.moduleId?.trim();
        final callback = widget.onOpenModule;
        if (moduleId == null || moduleId.isEmpty || callback == null) return;

        await callback(moduleId);
        if (mounted) Navigator.of(context).pop();
        return;

      case SearchResultType.level:
        final levelId = result.levelId?.trim();
        if (levelId == null || levelId.isEmpty) return;

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _SearchLevelModulesScreen(
              levelId: levelId,
              levelName: result.levelName?.trim().isNotEmpty == true
                  ? result.levelName!.trim()
                  : result.title,
              onOpenModule: widget.onOpenModule,
            ),
          ),
        );

        if (mounted) Navigator.of(context).pop();
        return;
    }
  }

  IconData _iconForType(SearchResultType type) {
    switch (type) {
      case SearchResultType.level:
        return Icons.school_rounded;
      case SearchResultType.module:
        return Icons.menu_book_rounded;
      case SearchResultType.lecture:
        return Icons.play_lesson_rounded;
    }
  }

  String _labelForType(SearchResultType type) {
    switch (type) {
      case SearchResultType.level:
        return 'Level';
      case SearchResultType.module:
        return 'Module';
      case SearchResultType.lecture:
        return 'Lecture';
    }
  }

  String _contextForResult(GlobalSearchResult result) {
    switch (result.type) {
      case SearchResultType.level:
        return 'Academic Level';
      case SearchResultType.module:
        return result.levelName?.trim().isNotEmpty == true
            ? result.levelName!.trim()
            : 'Module';
      case SearchResultType.lecture:
        final parts = <String>[];
        if (result.levelName?.trim().isNotEmpty == true) {
          parts.add(result.levelName!.trim());
        }
        if (result.moduleName?.trim().isNotEmpty == true) {
          parts.add(result.moduleName!.trim());
        }
        return parts.isEmpty ? 'Lecture' : parts.join(' • ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = Responsive.width(context) >= 700;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: isWide ? 12 : 4,
        title: Container(
          height: Responsive.clamped(context, base: 46, min: 42, max: 52),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: colorScheme.outline.withValues(alpha: .10)),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: _submitSearch,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search levels, modules or lectures...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: _buildBody(context, isWide),
    );
  }

  Widget _buildBody(BuildContext context, bool isWide) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => unawaited(_performSearch(_query)),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
        ),
      );
    }

    if (_query.isEmpty) return const _SearchEmptyState();

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'No results found for “$_query”.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .60)),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(isWide ? 28 : 16, isWide ? 24 : 16, isWide ? 28 : 16, 24),
          itemCount: _results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final result = _results[index];
            return _SearchResultCard(
              result: result,
              icon: _iconForType(result.type),
              typeLabel: _labelForType(result.type),
              contextLabel: _contextForResult(result),
              onTap: () => unawaited(_openResult(result)),
            );
          },
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final GlobalSearchResult result;
  final IconData icon;
  final String typeLabel;
  final String contextLabel;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.result,
    required this.icon,
    required this.typeLabel,
    required this.contextLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = Responsive.clamped(context, base: 48, min: 44, max: 56);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(Responsive.clamped(context, base: 13, min: 11, max: 18)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.primary, size: size * .48),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Responsive.bodyTextSize(context, base: 16, min: 14, max: 19),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: scheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      contextLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.smallTextSize(context, base: 12, min: 10.5, max: 14),
                        color: scheme.onSurface.withValues(alpha: .58),
                      ),
                    ),
                    if (result.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(
                        result.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Responsive.smallTextSize(context, base: 11.5, min: 10, max: 13.5),
                          color: scheme.onSurface.withValues(alpha: .46),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 8),
                child: Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: .08), shape: BoxShape.circle),
              child: Icon(Icons.search_rounded, size: 42, color: scheme.primary.withValues(alpha: .65)),
            ),
            const SizedBox(height: 18),
            const Text('Search MediData', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Find academic levels, modules and lectures quickly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurface.withValues(alpha: .55), height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchLevelModulesScreen extends StatefulWidget {
  final String levelId;
  final String levelName;
  final Future<void> Function(String moduleId)? onOpenModule;

  const _SearchLevelModulesScreen({
    required this.levelId,
    required this.levelName,
    required this.onOpenModule,
  });

  @override
  State<_SearchLevelModulesScreen> createState() => _SearchLevelModulesScreenState();
}

class _SearchLevelModulesScreenState extends State<_SearchLevelModulesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<_SearchModule>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadModules();
  }

  Future<List<_SearchModule>> _loadModules() async {
    final response = await _supabase
        .from('modules')
        .select('id,academic_level_id,name,description,image_url,display_order,is_active')
        .eq('academic_level_id', widget.levelId)
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return (response as List)
        .map((item) => _SearchModule.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _markModuleCurrent(_SearchModule module) async {
    final user = _supabase.auth.currentUser;
    if (user == null || module.id.isEmpty) return;

    try {
      final firstLecture = await _supabase
          .from('lectures')
          .select('id')
          .eq('module_id', module.id)
          .eq('is_active', true)
          .eq('is_published', true)
          .order('display_order', ascending: true)
          .limit(1)
          .maybeSingle();

      final lectureId = firstLecture?['id']?.toString().trim();
      if (lectureId == null || lectureId.isEmpty) return;

      await _supabase.from('lecture_progress').upsert(
        {
          'user_id': user.id,
          'lecture_id': lectureId,
          'last_opened_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,lecture_id',
      );
    } catch (e) {
      debugPrint('Search module current error: $e');
    }
  }

  Future<void> _openModule(_SearchModule module) async {
    await _markModuleCurrent(module);
    if (!mounted) return;

    final callback = widget.onOpenModule;
    if (callback == null || module.id.trim().isEmpty) return;

    await callback(module.id.trim());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = Responsive.horizontalPadding(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.levelName),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: FutureBuilder<List<_SearchModule>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: () {
                  if (mounted) setState(() => _future = _loadModules());
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            );
          }

          final modules = snapshot.data ?? const <_SearchModule>[];
          if (modules.isEmpty) {
            return Center(
              child: Text(
                'No modules available for this level.',
                style: TextStyle(color: scheme.onSurface.withValues(alpha: .60)),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              if (!mounted) return;
              setState(() => _future = _loadModules());
              await _future;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
              itemCount: modules.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final module = modules[index];
                return ModuleCard(
                  name: module.name,
                  description: module.description,
                  imageUrl: module.imageUrl,
                  onTap: () => unawaited(_openModule(module)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SearchModule {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;

  const _SearchModule({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
  });

  factory _SearchModule.fromMap(Map<String, dynamic> map) {
    return _SearchModule(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      imageUrl: map['image_url']?.toString(),
    );
  }
}
