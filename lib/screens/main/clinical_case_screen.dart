import 'package:flutter/material.dart';
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
    try { final v = await _service.isSaved(widget.clinicalCase.id); if (mounted) setState(() => _saved = v); } catch (_) {}
  }
  Future<void> _toggleSaved() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final next = !_saved;
      await _service.setSaved(widget.clinicalCase.id, next);
      if (mounted) setState(() => _saved = next);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to update saved cases.')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  Widget _section(BuildContext context, String title, String? value, IconData icon) {
    if ((value ?? '').trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(Responsive.cardPadding(context)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: theme.colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)))]),
          const SizedBox(height: 10),
          Text(value!, style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    final c = widget.clinicalCase;
    final images = c.imageUrls.where((e) => e.trim().isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Case of the Day'), actions: [
        IconButton(onPressed: _saving ? null : _toggleSaved, tooltip: _saved ? 'Remove from saved' : 'Save case', icon: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded)),
      ]),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 950),
        child: ListView(
          padding: EdgeInsets.fromLTRB(Responsive.horizontalPadding(context), 16, Responsive.horizontalPadding(context), 32),
          children: [
            Text(c.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(c.caseDate.toLocal().toString().split(' ').first, style: Theme.of(context).textTheme.bodySmall),
            if ((c.shortDescription ?? '').trim().isNotEmpty) ...[const SizedBox(height: 12), Text(c.shortDescription!, style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.45))],
            if (images.isNotEmpty) ...[
              const SizedBox(height: 18),
              SizedBox(height: 260, child: PageView.builder(itemCount: images.length, itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.network(images[i], fit: BoxFit.cover, errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, size: 42)))),
              ))),
            ],
            const SizedBox(height: 18),
            _section(context, 'Clinical Presentation', c.clinicalPresentation, Icons.personal_injury_outlined),
            _section(context, 'History', c.history, Icons.history_edu_outlined),
            _section(context, 'Examination', c.examination, Icons.health_and_safety_outlined),
            _section(context, 'Investigations', c.investigations, Icons.biotech_outlined),
            _section(context, 'Diagnosis', c.diagnosis, Icons.medical_information_outlined),
            _section(context, 'Management / Interventions', c.management, Icons.healing_outlined),
            _section(context, 'Medications', c.medications, Icons.medication_outlined),
          ],
        ),
      )),
    );
  }
}