import 'package:flutter/foundation.dart';

class HomeState extends ChangeNotifier {
  // Utilisateur/session
  String userName = '';
  String userRole = '';

  // API
  bool useCloudApi = false;
  String apiLocalBaseUrl = 'http://localhost:3000';
  String apiCloudBaseUrl = '';

  // Filtres & recherche
  String query = '';
  final Set<String> selectedStatuses = <String>{};

  // Tables par serveur
  final Map<String, List<Map<String, dynamic>>> serverTables = {
    'ALI': [],
    'MOHAMED': [],
    'FATIMA': [],
    'ADMIN': [],
  };

  List<Map<String, dynamic>> getCurrentServerTables() {
    return serverTables[userName] ?? <Map<String, dynamic>>[];
  }

  // Sélection filtrée selon query/statuts
  List<Map<String, dynamic>> get filteredTables {
    final base = getCurrentServerTables();
    final q = query.trim().toLowerCase();
    final selected = selectedStatuses;
    return base.where((t) {
      final status = (t['status'] as String?)?.toLowerCase() ?? '';
      final number = (t['number']?.toString() ?? '').toLowerCase();
      final server = (t['server']?.toString() ?? '').toLowerCase();
      final matchesQuery = q.isEmpty || number.contains(q) || server.contains(q);
      final matchesStatus = selected.isEmpty || selected.contains(status);
      return matchesQuery && matchesStatus;
    }).toList();
  }

  // Mutations utilisateur
  void setUser(String name, String role) {
    userName = name;
    userRole = role;
    notifyListeners();
  }

  // Mutations API
  void setApiMode(bool cloud) {
    useCloudApi = cloud;
    notifyListeners();
  }

  void setApiUrls({String? local, String? cloud}) {
    if (local != null) apiLocalBaseUrl = local;
    if (cloud != null) apiCloudBaseUrl = cloud;
    notifyListeners();
  }

  // Filtres & recherche
  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  void toggleStatus(String status, bool selected) {
    if (selected) {
      selectedStatuses.add(status);
    } else {
      selectedStatuses.remove(status);
    }
    notifyListeners();
  }

  // Tables
  void replaceServerTables(String server, List<Map<String, dynamic>> tables) {
    serverTables[server] = tables;
    notifyListeners();
  }

  void upsertTable(String server, Map<String, dynamic> table) {
    final list = serverTables[server] ??= <Map<String, dynamic>>[];
    final idx = list.indexWhere((t) => t['id'] == table['id']);
    if (idx >= 0) {
      list[idx] = table;
    } else {
      list.add(table);
    }
    notifyListeners();
  }

  void removeTablesByNumbers(String server, List<String> numbers) {
    final list = serverTables[server] ??= <Map<String, dynamic>>[];
    list.removeWhere((t) => numbers.contains(t['number'] as String));
    notifyListeners();
  }
}


