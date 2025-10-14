import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_history.dart';

class HistoryManager {
  static const _kKey = 'scan_history_list_v1';

  // Broadcast stream that emits every time a new ScanHistory entry is added.
  static final StreamController<ScanHistory> _entryController = StreamController<ScanHistory>.broadcast();

  /// Stream of newly added history entries (newest first as emitted).
  static Stream<ScanHistory> get onNewEntry => _entryController.stream;

  static Future<List<ScanHistory>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kKey);
    if (s == null) return [];
    final List<dynamic> arr = jsonDecode(s);
    return arr.map((e) => ScanHistory.fromJson(e)).toList();
  }

  static Future<void> saveHistory(List<ScanHistory> list) async {
    final prefs = await SharedPreferences.getInstance();
    final s = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_kKey, s);
  }

  static Future<void> addEntry(ScanHistory entry) async {
    final list = await loadHistory();
    list.insert(0, entry);
    await saveHistory(list);
    try {
      _entryController.add(entry);
    } catch (_) {}
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
