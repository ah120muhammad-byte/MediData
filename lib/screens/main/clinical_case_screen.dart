import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../core/responsive/responsive.dart';
import '../../services/clinical_case_service.dart';

class ClinicalCaseScreen extends StatefulWidget {
  final ClinicalCase clinicalCase;
  const ClinicalCaseScreen({super.key, required this.clinicalCase});
  @override State<ClinicalCaseScreen> createState() => _ClinicalCaseScreenState();
}

class _ClinicalCaseScreenState extends State<ClinicalCaseScreen> {
  final _service = ClinicalCaseService.instance;
  bool _saved = false, _saving = false;

  @override void initState() { super.initState(); _loadSaved(); }

  Future<void> _loadSaved() async {
    try {
      final v = await _service.isSaved(widget.clinicalCase.id);
      if (mounted) setState(() => _saved = v);
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

  Widget _rich(String? rich, String? plain) {
    final raw = rich?.trim() ?? '';
    if (raw.isEmpty) return Text(plain ?? '', style: const TextStyle(height: 1.65));
    try {
      final controller = QuillController(
        document: Document.fromJson(jsonDecode(raw)),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      return QuillEditor.basic(
        controller: controller,
        config: const QuillEditorConfig(
          scrollable: false,
          padding: EdgeInsets.zero,
          showCursor: false,
          showCodeBlockLineNumbers: false,
        ),
      );
    } catch (_) {
      return Text(plain ?? '', style: const TextStyle(height: 1.65));
    }
  }

  Widget _section(String title, String? plain, String? rich, String? image, IconData icon) {
    if ((plain ?? '').trim().isEmpty && (rich ?? '').trim().isEmpty && (image ?? '').trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(Responsive.cardPadding(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          ]),
          if ((image ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(image!, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 42),
                  )),
              ),
            ),
          ],
          if ((plain ?? '').trim().isNotEmpty || (rich ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12), _rich(rich, plain),
          ],
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final c = widget.clinicalCase;
    final images = c.imageUrls.where((e) => e.trim().isNotEmpty).toList();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Case of the Day'),
        actions: [IconButton(
          onPressed: _saving ? null : _toggleSaved,
          icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
        )],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: ListView(
            padding: EdgeInsets.fromLTRB(Responsive.horizontalPadding(context), 16, Responsive.horizontalPadding(context), 32),
            children: [
              Text(c.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(c.caseDate.toLocal().toString().split(' ').first, style: theme.textTheme.bodySmall),
              if ((c.shortDescription ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(c.shortDescription!, style: theme.textTheme.bodyLarge?.copyWith(height: 1.65)),
              ],
              if (images.isNotEmpty) ...[
                const SizedBox(height: 18),
                SizedBox(height: 260, child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(images[i], fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, size: 42))),
                    ),
                  ),
                )),
              ],
              const SizedBox(height: 18),
              _section('Clinical Presentation', c.clinicalPresentation, c.clinicalPresentationRich, c.presentationImageUrl, Icons.personal_injury_outlined),
              _section('History', c.history, c.historyRich, c.historyImageUrl, Icons.history_edu_outlined),
              _section('Examination', c.examination, c.examinationRich, c.examinationImageUrl, Icons.health_and_safety_outlined),
              _section('Investigations', c.investigations, c.investigationsRich, c.investigationsImageUrl, Icons.biotech_outlined),
              _section('Diagnosis', c.diagnosis, c.diagnosisRich, c.diagnosisImageUrl, Icons.medical_information_outlined),
              _section('Management / Interventions', c.management, c.managementRich, c.managementImageUrl, Icons.healing_outlined),
              _section('Medications', c.medications, c.medicationsRich, c.medicationsImageUrl, Icons.medication_outlined),
            ],
          ),
        ),
      ),
    );
  }
}