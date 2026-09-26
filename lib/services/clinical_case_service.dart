import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicalCase {
  final String id;
  final String title;
  final DateTime caseDate;
  final String? shortDescription;
  final String? clinicalPresentation;
  final String? clinicalPresentationRich;
  final String? history;
  final String? historyRich;
  final String? examination;
  final String? examinationRich;
  final String? investigations;
  final String? investigationsRich;
  final String? diagnosis;
  final String? diagnosisRich;
  final String? management;
  final String? managementRich;
  final String? medications;
  final String? medicationsRich;
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
    required this.id,
    required this.title,
    required this.caseDate,
    this.shortDescription,
    this.clinicalPresentation,
    this.clinicalPresentationRich,
    this.history,
    this.historyRich,
    this.examination,
    this.examinationRich,
    this.investigations,
    this.investigationsRich,
    this.diagnosis,
    this.diagnosisRich,
    this.management,
    this.managementRich,
    this.medications,
    this.medicationsRich,
    this.imageUrls = const [],
    this.presentationImageUrl,
    this.historyImageUrl,
    this.examinationImageUrl,
    this.investigationsImageUrl,
    this.diagnosisImageUrl,
    this.managementImageUrl,
    this.medicationsImageUrl,
    this.cardBackgroundUrl,
    this.fontFamily = 'default',
    this.fontSize = 16,
    this.fontColor = '#000000',
    this.isPublished = false,
  });

  factory ClinicalCase.fromMap(Map<String, dynamic> map) => ClinicalCase(
    id: map['id'].toString(),
    title: map['title']?.toString() ?? '',
    caseDate: DateTime.parse(map['case_date'].toString()),
    shortDescription: map['short_description']?.toString(),
    clinicalPresentation: map['clinical_presentation']?.toString(),
    clinicalPresentationRich: map['clinical_presentation_rich']?.toString(),
    history: map['history']?.toString(),
    historyRich: map['history_rich']?.toString(),
    examination: map['examination']?.toString(),
    examinationRich: map['examination_rich']?.toString(),
    investigations: map['investigations']?.toString(),
    investigationsRich: map['investigations_rich']?.toString(),
    diagnosis: map['diagnosis']?.toString(),
    diagnosisRich: map['diagnosis_rich']?.toString(),
    management: map['management']?.toString(),
    managementRich: map['management_rich']?.toString(),
    medications: map['medications']?.toString(),
    medicationsRich: map['medications_rich']?.toString(),
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
    final date = DateTime(now.year, now.month, now.day)
        .toIso8601String()
        .split('T')
        .first;

    final row = await _client
        .from('clinical_cases')
        .select()
        .eq('case_date', date)
        .eq('is_published', true)
        .maybeSingle();

    return row == null
        ? null
        : ClinicalCase.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<ClinicalCase>> getSavedCases() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client
        .from('saved_clinical_cases')
        .select('''
          id,
          case_id,
          saved_at,
          title,
          case_date,
          short_description,
          clinical_presentation,
          clinical_presentation_rich,
          history,
          history_rich,
          examination,
          examination_rich,
          investigations,
          investigations_rich,
          diagnosis,
          diagnosis_rich,
          management,
          management_rich,
          medications,
          medications_rich,
          image_urls,
          presentation_image_url,
          history_image_url,
          examination_image_url,
          investigations_image_url,
          diagnosis_image_url,
          management_image_url,
          medications_image_url,
          card_background_url,
          font_family,
          font_size,
          font_color,
          is_published
        ''')
        .eq('user_id', user.id)
        .order('saved_at', ascending: false);

    return (rows as List)
        .map((row) {
          final data = Map<String, dynamic>.from(row as Map);
          data['id'] = data['case_id'];
          return ClinicalCase.fromMap(data);
        })
        .toList();
  }

  Future<bool> isSaved(String caseId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final row = await _client
        .from('saved_clinical_cases')
        .select('id')
        .eq('user_id', user.id)
        .eq('case_id', caseId)
        .maybeSingle();

    return row != null;
  }

  Future<void> setSaved(String caseId, bool saved) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    if (!saved) {
      await _client
          .from('saved_clinical_cases')
          .delete()
          .eq('user_id', user.id)
          .eq('case_id', caseId);
      return;
    }

    // Save a complete snapshot of the case.
    // Future edits to clinical_cases will not change this saved copy.
    final row = await _client
        .from('clinical_cases')
        .select()
        .eq('id', caseId)
        .maybeSingle();

    if (row == null) {
      throw Exception('Clinical case not found.');
    }

    final c = ClinicalCase.fromMap(Map<String, dynamic>.from(row));

    await _client.from('saved_clinical_cases').upsert(
      {
        'user_id': user.id,
        'case_id': c.id,
        'title': c.title,
        'case_date': c.caseDate.toIso8601String().split('T').first,
        'short_description': c.shortDescription,
        'clinical_presentation': c.clinicalPresentation,
        'clinical_presentation_rich': c.clinicalPresentationRich,
        'history': c.history,
        'history_rich': c.historyRich,
        'examination': c.examination,
        'examination_rich': c.examinationRich,
        'investigations': c.investigations,
        'investigations_rich': c.investigationsRich,
        'diagnosis': c.diagnosis,
        'diagnosis_rich': c.diagnosisRich,
        'management': c.management,
        'management_rich': c.managementRich,
        'medications': c.medications,
        'medications_rich': c.medicationsRich,
        'image_urls': c.imageUrls,
        'presentation_image_url': c.presentationImageUrl,
        'history_image_url': c.historyImageUrl,
        'examination_image_url': c.examinationImageUrl,
        'investigations_image_url': c.investigationsImageUrl,
        'diagnosis_image_url': c.diagnosisImageUrl,
        'management_image_url': c.managementImageUrl,
        'medications_image_url': c.medicationsImageUrl,
        'card_background_url': c.cardBackgroundUrl,
        'font_family': c.fontFamily,
        'font_size': c.fontSize,
        'font_color': c.fontColor,
        'is_published': c.isPublished,
      },
      onConflict: 'user_id,case_id',
    );
  }
}
