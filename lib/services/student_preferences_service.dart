import 'package:shared_preferences/shared_preferences.dart';

class StudentPreferencesService {
  StudentPreferencesService._();

  static final StudentPreferencesService instance =
      StudentPreferencesService._();

  static const _notificationsKey =
      'student_notifications';

  static const _autoPlayKey =
      'student_auto_play';

  static const _wifiOnlyDownloadsKey =
      'student_wifi_only_downloads';

  static const _playbackSpeedKey =
      'student_default_playback_speed';

  // ===========================================================================
  // NOTIFICATIONS
  // ===========================================================================

  Future<bool> getNotificationsEnabled() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getBool(
          _notificationsKey,
        ) ??
        true;
  }

  Future<void> setNotificationsEnabled(
    bool value,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      _notificationsKey,
      value,
    );
  }

  // ===========================================================================
  // AUTO PLAY
  // ===========================================================================

  Future<bool> getAutoPlayEnabled() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getBool(
          _autoPlayKey,
        ) ??
        true;
  }

  Future<void> setAutoPlayEnabled(
    bool value,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      _autoPlayKey,
      value,
    );
  }

  // ===========================================================================
  // WIFI ONLY DOWNLOADS
  // ===========================================================================

  Future<bool> getWifiOnlyDownloads() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getBool(
          _wifiOnlyDownloadsKey,
        ) ??
        true;
  }

  Future<void> setWifiOnlyDownloads(
    bool value,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      _wifiOnlyDownloadsKey,
      value,
    );
  }

  // ===========================================================================
  // PLAYBACK SPEED
  // ===========================================================================

  Future<double>
      getDefaultPlaybackSpeed() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getDouble(
          _playbackSpeedKey,
        ) ??
        1.0;
  }

  Future<void> setDefaultPlaybackSpeed(
    double value,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setDouble(
      _playbackSpeedKey,
      value,
    );
  }
}