import 'package:flutter/material.dart';
import '../../core/responsive/responsive.dart';
import '../../services/clinical_case_service.dart';

class ClinicalCaseScreen extends StatefulWidget {
  final ClinicalCase clinicalCase;
  const ClinicalCaseScreen({super.key, required this.clinicalCase});

  @override
  State<ClinicalCaseScreen> createState() => _ClinicalCaseScreenState();
}

class _ClinicalCaseScreenState extends State<ClinicalCaseScreen> {
  final _service = ClinicalCaseService.instance;
  bool _saved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final value = await _service.isSaved(widget.clinicalCase.id);
      if (mounted) setState(() => _saved = value);
    } catch (_) {}
  }

  Future<void> _toggleSaved() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final next = !_saved;
      await _service.setSaved(widget.clinicalCase.id, next);
      if (mounted) setState(() => _saved = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update saved cases.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  FontWeight _fontWeight(String family) =>
      family == 'monospace' ? FontWeight.w500 : FontWeight.normal;

  TextStyle _articleStyle(BuildContext context, ClinicalCase c) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyLarge!.copyWith(
      fontSize: c.fontSize.clamp(12, 30),
      height: 1.65,
      color: _parseColor(c.fontColor, theme.colorScheme.onSurface),
      fontFamily: c.fontFamily == 'default' ? null : c.fontFamily,
      fontWeight: _fontWeight(c.fontFamily),
    );
  }

  Widget _section(
    BuildContext context,
    ClinicalCase c,
    String title,
    String? value,
    String? imageUrl,
    IconData icon,
  ) {
    if ((value ?? '').trim().isEmpty && (imageUrl ?? '').trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final textStyle = _articleStyle(context, c);
    final hasImage = (imageUrl ?? '').trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(Responsive.cardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (hasImage) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 42),
                    ),
                  ),
                ),
              ),
            ],
            if ((value ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(value!, style: textStyle),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.clinicalCase;
    final images = c.imageUrls.where((e) => e.trim().isNotEmpty).toList();
    final theme = Theme.of(context);
    final articleStyle = _articleStyle(context, c);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Case of the Day'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _toggleSaved,
            tooltip: _saved ? 'Remove from saved' : 'Save case',
            icon: Icon(
              _saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              Responsive.horizontalPadding(context),
              16,
              Responsive.horizontalPadding(context),
              32,
            ),
            children: [
              Text(
                c.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                c.caseDate.toLocal().toString().split(' ').first,
                style: theme.textTheme.bodySmall,
              ),
              if ((c.shortDescription ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(c.shortDescription!, style: articleStyle),
              ],
              if (images.isNotEmpty) ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 260,
                  child: PageView.builder(
                    itemCount: images.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          images[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 42),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _section(context, c, 'Clinical Presentation', c.clinicalPresentation, c.presentationImageUrl, Icons.personal_injury_outlined),
              _section(context, c, 'History', c.history, c.historyImageUrl, Icons.history_edu_outlined),
              _section(context, c, 'Examination', c.examination, c.examinationImageUrl, Icons.health_and_safety_outlined),
              _section(context, c, 'Investigations', c.investigations, c.investigationsImageUrl, Icons.biotech_outlined),
              _section(context, c, 'Diagnosis', c.diagnosis, c.diagnosisImageUrl, Icons.medical_information_outlined),
              _section(context, c, 'Management / Interventions', c.management, c.managementImageUrl, Icons.healing_outlined),
              _section(context, c, 'Medications', c.medications, c.medicationsImageUrl, Icons.medication_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

Color _parseColor(String value, Color fallback) {
  var hex = value.trim().replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return fallback;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
