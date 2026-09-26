import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicalCase {
  final String id;
  final String title;
  final DateTime caseDate;
  final String? shortDescription;
  final String? clinicalPresentation;
  final String? history;
  final String? examination;
  final String? investigations;
  final String? diagnosis;
  final String? management;
  final String? medications;
  final List<String> imageUrls;
  final String? presentationImageUrl;
  final String? historyImageUrl;
  final String? examinationImageUrl;
  final String? investigationsImageUrl;
  final String? diagnosisImageUrl;
  final String? managementImageUrl;
  final String? medicationsImageUrl;
  final String? cardBackgroundUrl;
  final String fontFamily;
  final double fontSize;
  final String fontColor;
  final bool isPublished;

  const ClinicalCase({
    required this.id, required this.title, required this.caseDate,
    this.shortDescription, this.clinicalPresentation, this.history,
    this.examination, this.investigations, this.diagnosis, this.management,
    this.medications, this.imageUrls = const [],
    this.presentationImageUrl, this.historyImageUrl, this.examinationImageUrl,
    this.investigationsImageUrl, this.diagnosisImageUrl, this.managementImageUrl,
    this.medicationsImageUrl, this.cardBackgroundUrl, this.fontFamily = 'default',
    this.fontSize = 16, this.fontColor = '#000000', this.isPublished = false,
  });

  factory ClinicalCase.fromMap(Map<String, dynamic> map) => ClinicalCase(
    id: map['id'].toString(),
    title: map['title']?.toString() ?? '',
    caseDate: DateTime.parse(map['case_date'].toString()),
    shortDescription: map['short_description']?.toString(),
    clinicalPresentation: map['clinical_presentation']?.toString(),
    history: map['history']?.toString(),
    examination: map['examination']?.toString(),
    investigations: map['investigations']?.toString(),
    diagnosis: map['diagnosis']?.toString(),
    management: map['management']?.toString(),
    medications: map['medications']?.toString(),
    imageUrls: List<String>.from(map['image_urls'] ?? const []),
    presentationImageUrl: map['presentation_image_url']?.toString(),
    historyImageUrl: map['history_image_url']?.toString(),
    examinationImageUrl: map['examination_image_url']?.toString(),
    investigationsImageUrl: map['investigations_image_url']?.toString(),
    diagnosisImageUrl: map['diagnosis_image_url']?.toString(),
    managementImageUrl: map['management_image_url']?.toString(),
    medicationsImageUrl: map['medications_image_url']?.toString(),
    cardBackgroundUrl: map['card_background_url']?.toString(),
    fontFamily: map['font_family']?.toString() ?? 'default',
    fontSize: (map['font_size'] as num?)?.toDouble() ?? 16,
    fontColor: map['font_color']?.toString() ?? '#000000',
    isPublished: map['is_published'] as bool? ?? false,
  );
}

class ClinicalCaseService {
  ClinicalCaseService._();
  static final instance = ClinicalCaseService._();
  final SupabaseClient _client = Supabase.instance.client;

  Future<ClinicalCase?> getTodayCase() async {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day).toIso8601String().split('T').first;
    final row = await _client.from('clinical_cases').select().eq('case_date', date).eq('is_published', true).maybeSingle();
    return row == null ? null : ClinicalCase.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<ClinicalCase>> getSavedCases() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client.from('saved_clinical_cases').select('saved_at, clinical_cases(*)').eq('user_id', user.id).order('saved_at', ascending: false);
    return (rows as List).map((r) => r['clinical_cases']).whereType<Map>().map((r) => ClinicalCase.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<bool> isSaved(String caseId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client.from('saved_clinical_cases').select('id').eq('user_id', user.id).eq('case_id', caseId).maybeSingle();
    return row != null;
  }

  Future<void> setSaved(String caseId, bool saved) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    if (saved) {
      await _client.from('saved_clinical_cases').upsert({'user_id': user.id, 'case_id': caseId}, onConflict: 'user_id,case_id');
    } else {
      await _client.from('saved_clinical_cases').delete().eq('user_id', user.id).eq('case_id', caseId);
    }
  }
}