import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static Future<void> clearPosCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('pos_tables_') || key.startsWith('pos_order_') || key.startsWith('pos_table_to_close_')) {
        await prefs.remove(key);
      }
    }
  }
}
