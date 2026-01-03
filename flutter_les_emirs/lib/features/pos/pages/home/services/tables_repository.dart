import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TablesRepository {
  static Future<Map<String, List<Map<String, dynamic>>>> loadAll(
      Map<String, List<Map<String, dynamic>>> initialServers) async {
    final prefs = await SharedPreferences.getInstance();

    // Récupérer et purger les tables marquées pour suppression
    final keys = prefs.getKeys().where((k) => k.startsWith('pos_table_to_close_')).toList();
    final toClose = <String>{};
    for (final key in keys) {
      final tableId = prefs.getString(key);
      if (tableId != null) {
        toClose.add(tableId);
        await prefs.remove(key);
      }
    }

    final serverTables = <String, List<Map<String, dynamic>>>{};
    for (final serverName in initialServers.keys) {
      final tablesJson = prefs.getString('pos_tables_$serverName');
      if (tablesJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(tablesJson);
          final tables = decoded.map((t) {
            final table = Map<String, dynamic>.from(t);
            if (table['openedAt'] != null && table['openedAt'] is String) {
              table['openedAt'] = DateTime.tryParse(table['openedAt'] as String);
            }
            if (table['lastOrderAt'] != null && table['lastOrderAt'] is String) {
              table['lastOrderAt'] = DateTime.tryParse(table['lastOrderAt'] as String);
            }
            return table;
          }).where((t) => !toClose.contains(t['id'])).toList();
          serverTables[serverName] = tables;
        } catch (_) {
          // ignorer erreurs de parsing, on laisse vide
          serverTables[serverName] = <Map<String, dynamic>>[];
        }
      } else {
        serverTables[serverName] = <Map<String, dynamic>>[];
      }
    }

    return serverTables;
  }

  static Future<void> saveAll(Map<String, List<Map<String, dynamic>>> serverTables) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in serverTables.entries) {
      final serverName = entry.key;
      final tables = entry.value.map((t) {
        final table = Map<String, dynamic>.from(t);
        if (table['openedAt'] is DateTime) {
          table['openedAt'] = (table['openedAt'] as DateTime).toIso8601String();
        }
        if (table['lastOrderAt'] is DateTime) {
          table['lastOrderAt'] = (table['lastOrderAt'] as DateTime).toIso8601String();
        }
        return table;
      }).toList();
      await prefs.setString('pos_tables_$serverName', jsonEncode(tables));
    }
  }
}
