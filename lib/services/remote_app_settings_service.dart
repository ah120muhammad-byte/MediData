import 'package:supabase_flutter/supabase_flutter.dart';

class RemoteAppSettings {
  final bool maintenanceMode;
  final String maintenanceMessage;
  final bool allowRegistration;
  final bool notificationsEnabled;
  final String homeAnnouncement;
  final String minimumSupportedVersion;
  final bool forceUpdate;
  final String supportEmail;
  final String appName;
  final String appVersion;

  const RemoteAppSettings({
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.allowRegistration,
    required this.notificationsEnabled,
    required this.homeAnnouncement,
    required this.minimumSupportedVersion,
    required this.forceUpdate,
    required this.supportEmail,
    required this.appName,
    required this.appVersion,
  });

  factory RemoteAppSettings.fromMap(Map<String, dynamic> map) {
    return RemoteAppSettings(
      maintenanceMode: map['maintenance_mode'] as bool? ?? false,
      maintenanceMessage: map['maintenance_message']?.toString() ?? '',
      allowRegistration: map['allow_registration'] as bool? ?? true,
      notificationsEnabled: map['notifications_enabled'] as bool? ?? true,
      homeAnnouncement: map['home_announcement']?.toString() ?? '',
      minimumSupportedVersion: map['minimum_supported_version']?.toString() ?? '1.0.0',
      forceUpdate: map['force_update'] as bool? ?? false,
      supportEmail: map['support_email']?.toString() ?? '',
      appName: map['app_name']?.toString() ?? 'MediData',
      appVersion: map['app_version']?.toString() ?? '1.0.0',
    );
  }

  static const defaults = RemoteAppSettings(
    maintenanceMode: false,
    maintenanceMessage: 'The app is temporarily under maintenance. Please try again later.',
    allowRegistration: true,
    notificationsEnabled: true,
    homeAnnouncement: '',
    minimumSupportedVersion: '1.0.0',
    forceUpdate: false,
    supportEmail: '',
    appName: 'MediData',
    appVersion: '1.0.0',
  );
}

class RemoteAppSettingsService {
  RemoteAppSettingsService({SupabaseClient? supabase}) : _supabase = supabase ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  Future<RemoteAppSettings> getSettings() async {
    final response = await _supabase
        .from('student_app_settings')
        .select('maintenance_mode,maintenance_message,allow_registration,notifications_enabled,home_announcement,minimum_supported_version,force_update,support_email,app_name,app_version')
        .limit(1)
        .single();
    return RemoteAppSettings.fromMap(Map<String, dynamic>.from(response));
  }
}
