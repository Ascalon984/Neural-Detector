import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static const _kSensitivityKey = 'detection_sensitivity_level';
  static const _kHighAccuracyKey = 'high_accuracy_mode';
  static const _kAutoScanKey = 'auto_scan_documents';
  static const _kNotificationsKey = 'notifications_enabled';
  static const _kLanguageKey = 'app_language';

  // cached current language code ('en' or 'id')
  static String currentLanguage = 'en';

  /// Sensitivity level stored as integer 1..10. Default is 5.
  static Future<int> getSensitivityLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSensitivityKey) ?? 5;
  }

  static Future<void> setSensitivityLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = level.clamp(1, 10);
    await prefs.setInt(_kSensitivityKey, clamped);
  }

  static Future<bool> getHighAccuracy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHighAccuracyKey) ?? false;
  }

  static Future<void> setHighAccuracy(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHighAccuracyKey, value);
  }

  static Future<bool> getAutoScan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoScanKey) ?? false;
  }

  static Future<void> setAutoScan(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoScanKey, value);
  }

  static Future<bool> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNotificationsKey) ?? false;
  }

  static Future<void> setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsKey, value);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_kLanguageKey) ?? 'en';
    currentLanguage = lang;
    return lang;
  }

  static Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageKey, code);
    currentLanguage = code;
  }
}
