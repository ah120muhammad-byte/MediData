import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class ModuleCard extends StatelessWidget {
  final String name;
  final String? description;
  final String? imageUrl;
  final VoidCallback onTap;

  const ModuleCard({
    super.key,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;
    final radius = isTablet ? 22.0 : 19.0;
    final imageWidth = isTablet ? 150.0 : 116.0;
    final imageHeight = isTablet ? 154.0 : 124.0;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Semantics(
      button: true,
      label: 'Open $name module',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.055),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.075),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: imageWidth,
                  height: imageHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      hasImage
                          ? Image.network(
                              imageUrl!.trim(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const _ModulePlaceholder(),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const _ModulePlaceholder(loading: true);
                              },
                            )
                          : const _ModulePlaceholder(),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: 0.02),
                                Colors.black.withValues(alpha: 0.16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 19 : 15,
                      isTablet ? 17 : 14,
                      isTablet ? 17 : 13,
                      isTablet ? 17 : 14,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isTablet ? 18.5 : 16.5,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.15,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (description != null &&
                            description!.trim().isNotEmpty) ...[
                          SizedBox(height: isTablet ? 8 : 6),
                          Text(
                            description!.trim(),
                            maxLines: isTablet ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isTablet ? 13 : 12,
                              height: 1.38,
                              color: scheme.onSurface.withValues(alpha: 0.58),
                            ),
                          ),
                        ],
                        SizedBox(height: isTablet ? 13 : 10),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Open Module',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isTablet ? 13 : 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              width: isTablet ? 27 : 24,
                              height: isTablet ? 27 : 24,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: isTablet ? 16 : 14,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModulePlaceholder extends StatelessWidget {
  final bool loading;

  const _ModulePlaceholder({this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.82),
            AppColors.primary.withValues(alpha: 0.40),
          ],
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.menu_book_rounded,
                size: 43,
                color: Colors.white.withValues(alpha: 0.30),
              ),
      ),
    );
  }
}
