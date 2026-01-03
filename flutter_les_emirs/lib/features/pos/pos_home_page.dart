import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';
import 'dart:convert';
import '../../core/api_client.dart';
// import 'pos_order_page.dart'; // Ancienne version
import 'pages/order/PosOrderPage_refactor.dart' as refactor; // Version refactorisée pour test

class PosHomePage extends StatefulWidget {
  final String? selectedServer;
  
  const PosHomePage({super.key, this.selectedServer});
  @override
  State<PosHomePage> createState() => _PosHomePageState();
}

class _PosHomePageState extends State<PosHomePage> {
  String userName = '';
  String userRole = '';
  String sessionStart = '';
  io.Socket? socket;
  Timer? _timer;
  
  // ⚙️ Sélecteur d'API (local/cloud)
  bool useCloudApi = false;
  String apiLocalBaseUrl = 'http://localhost:3000';
  String apiCloudBaseUrl = '';
  
  // Tables par serveur - chaque serveur a ses propres tables
  Map<String, List<Map<String, dynamic>>> serverTables = {
    'ALI': [],
    'MOHAMED': [],
    'FATIMA': [],
    'ADMIN': [],
  };
  
  // Tables du serveur actuel
  List<Map<String, dynamic>> get currentServerTables => serverTables[userName] ?? [];

  @override
  void initState() {
    super.initState();
    _loadApiPrefs(); // 🔧 CORRECTION : Charger les préférences API en premier
    _loadUserInfo();
    _loadTables(); // Charger les tables sauvegardées (inclut maintenant la synchronisation)
    _connectSocket();
    _startTimer();
    
    _checkForcedSync(); // Vérifier si synchronisation forcée demandée
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🔧 CORRECTION : Synchroniser quand on revient au plan de table
    print('[POS] 🔥 didChangeDependencies - synchronisation automatique');
    _syncOrdersWithTables().catchError((e) {
      print('[POS] ❌ Erreur synchronisation didChangeDependencies: $e');
    });
  }

  @override
  void didUpdateWidget(PosHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🔧 CORRECTION : Synchroniser quand le widget est mis à jour (retour au plan de table)
    print('[POS] 🔥 didUpdateWidget - synchronisation automatique');
    _syncOrdersWithTables().catchError((e) {
      print('[POS] ❌ Erreur synchronisation didUpdateWidget: $e');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    socket?.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Mise à jour des chronomètres
        });
        
        // Plus de synchronisation automatique périodique - juste les chronomètres
      }
    });
  }

  // Calculer le temps écoulé depuis l'ouverture de la table
  String _getElapsedTime(DateTime? openedAt) {
    if (openedAt == null) return '';
    final elapsed = DateTime.now().difference(openedAt);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    final seconds = elapsed.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // 🆕 Calculer le temps depuis la dernière commande
  String _getTimeSinceLastOrder(dynamic lastOrderAt) {
    DateTime? dateTime;
    
    if (lastOrderAt is String) {
      dateTime = DateTime.tryParse(lastOrderAt);
    } else if (lastOrderAt is DateTime) {
      dateTime = lastOrderAt;
    }
    
    if (dateTime == null) return '';
    
    final elapsed = DateTime.now().difference(dateTime);
    final minutes = elapsed.inMinutes;
    
    if (minutes < 60) {
      return '${minutes}min';
    } else {
      final hours = elapsed.inHours;
      final mins = minutes % 60;
      return '${hours}h${mins.toString().padLeft(2, '0')}';
    }
  }

  // 🆕 Couleur selon le temps d'inactivité
  Color _getInactivityColor(dynamic lastOrderAt) {
    DateTime? dateTime;
    
    if (lastOrderAt is String) {
      dateTime = DateTime.tryParse(lastOrderAt);
    } else if (lastOrderAt is DateTime) {
      dateTime = lastOrderAt;
    }
    
    if (dateTime == null) return Colors.grey;
    
    final elapsed = DateTime.now().difference(dateTime);
    final minutes = elapsed.inMinutes;
    
    // Vert < 15min, Orange 15-30min, Rouge > 30min
    if (minutes < 15) {
      return Colors.green.shade600;
    } else if (minutes < 30) {
      return Colors.orange.shade600;
    } else {
      return Colors.red.shade700;
    }
  }

  // Ouvrir une table (démarrer le chronomètre)
  void _openTable(String tableId) {
    setState(() {
      final tables = currentServerTables;
      final tableIndex = tables.indexWhere((t) => t['id'] == tableId);
      if (tableIndex != -1) {
        tables[tableIndex]['status'] = 'occupee';
        tables[tableIndex]['openedAt'] = DateTime.now();
        tables[tableIndex]['server'] = userName;
      }
    });
    _saveTables(); // Sauvegarder
  }

  // Fermer une table (arrêter le chronomètre)
  void _closeTable(String tableId) {
    setState(() {
      // Supprimer la table de TOUS les serveurs
      for (final serverName in serverTables.keys) {
        final tables = serverTables[serverName]!;
        tables.removeWhere((t) => t['id'] == tableId);
      }
    });
    _saveTables(); // Sauvegarder immédiatement
    print('[POS] Table $tableId fermée définitivement');
  }

  // Gérer le tap sur une table
  void _handleTableTap(Map<String, dynamic> table) {
    final status = table['status'] as String;
    
    if (status == 'occupee') {
      // Ouvrir la caisse pour une table occupée
      _openOrderPageFromTable(table);
    } else if (status == 'reservee') {
      // Gérer la réservation
      _showReservationDialog(table);
    }
    // Note: Plus de tables "libre" - on ajoute des tables dynamiquement
  }

  // Dialog pour ajouter une nouvelle table
  void _showAddTableDialog() {
    final tableNumberController = TextEditingController();
    int covers = 1;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter une table', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tableNumberController,
                  style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Numéro de table',
                    labelStyle: TextStyle(fontSize: 16),
                  hintText: 'Ex: 1, 2, 3...',
                  border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.table_restaurant, size: 24),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                ),
                keyboardType: TextInputType.number,
                  autofocus: true,
              ),
                const SizedBox(height: 24),
                const Text('Nombre de couverts:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: IconButton(
                    onPressed: () {
                      if (covers > 1) {
                        setDialogState(() => covers--);
                      }
                    },
                        icon: const Icon(Icons.remove_circle, size: 40),
                        color: Colors.red.shade700,
                      ),
                  ),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                    ),
                    child: Text(
                      '$covers',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: IconButton(
                    onPressed: () {
                      setDialogState(() => covers++);
                    },
                        icon: const Icon(Icons.add_circle, size: 40),
                        color: Colors.green.shade700,
                      ),
                  ),
                ],
              ),
            ],
            ),
          ),
          actions: [
            SizedBox(
              height: 56,
              child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
                child: const Text('Annuler', style: TextStyle(fontSize: 18)),
              ),
            ),
            SizedBox(
              height: 56,
              child: ElevatedButton(
              onPressed: () {
                final tableNumber = tableNumberController.text.trim();
                if (tableNumber.isNotEmpty) {
                  // Vérifier si le numéro existe déjà avant de fermer le dialog
                  bool tableExists = false;
                  String existingServer = '';
                  
                  for (final serverName in serverTables.keys) {
                    final tables = serverTables[serverName]!;
                    final existingTable = tables.firstWhere(
                      (table) => table['number'] == tableNumber,
                      orElse: () => {},
                    );
                    
                    if (existingTable.isNotEmpty) {
                      tableExists = true;
                      existingServer = serverName;
                      break;
                    }
                  }
                  
                  if (tableExists) {
                    // Afficher l'erreur dans le dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Table N° $tableNumber existe déjà chez le serveur $existingServer !'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return; // Ne pas fermer le dialog
                  }
                  
                  Navigator.of(context).pop(); // Fermer le popup d'abord
                  _addNewTable(tableNumber, covers); // Puis ajouter la table
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                backgroundColor: Colors.green,
              ),
              child: const Text('Créer', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            ),
          ],
        ),
      ),
    );
  }

  // Ajouter une nouvelle table au serveur
  void _addNewTable(String tableNumber, int covers) {
    // Vérifier si une table avec ce numéro existe déjà dans TOUS les serveurs
    bool tableExists = false;
    String existingServer = '';
    
    for (final serverName in serverTables.keys) {
      final tables = serverTables[serverName]!;
      final existingTable = tables.firstWhere(
        (table) => table['number'] == tableNumber,
        orElse: () => {},
      );
      
      if (existingTable.isNotEmpty) {
        tableExists = true;
        existingServer = serverName;
        break;
      }
    }
    
    if (tableExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Table N° $tableNumber existe déjà chez le serveur $existingServer !'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    
    setState(() {
      final tables = currentServerTables;
      final newTableId = '${userName}_${tableNumber}_${DateTime.now().millisecondsSinceEpoch}';
      
      tables.add({
        'id': newTableId,
        'number': tableNumber,
        'status': 'occupee',
        'covers': covers,
        'server': userName,
        'orderId': null,
        'orderTotal': 0.0,
        'orderItems': [],
        'openedAt': DateTime.now(),
        'lastOrderAt': DateTime.now(), // 🔧 CORRECTION : Initialiser avec DateTime.now()
      });
      
      // Sauvegarder
      _saveTables();
      
      // Ouvrir directement la caisse pour cette table
      _openOrderPageFromTable(tables.last);
    });
  }


  // Dialog pour gérer les réservations
  void _showReservationDialog(Map<String, dynamic> table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Table N° ${table['number']} - Réservée'),
        content: const Text('Cette table est réservée. Voulez-vous la libérer ou l\'ouvrir ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              _closeTable(table['id'] as String);
              Navigator.of(context).pop();
            },
            child: const Text('Libérer'),
          ),
          ElevatedButton(
            onPressed: () {
              // Ouvrir directement la caisse pour une table réservée
              _openOrderPageFromTable(table);
              Navigator.of(context).pop();
            },
            child: const Text('Ouvrir'),
          ),
        ],
      ),
    );
  }

  // Afficher les options de table (appui long)
  void _showTableOptions(Map<String, dynamic> table) {
    final tableNumber = table['number'] as String;
    final orderTotal = (table['orderTotal'] as num?)?.toDouble() ?? 0.0;
    final hasOrder = orderTotal > 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Options - Table N° $tableNumber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statut: ${table['status']}'),
            Text('Couverts: ${table['covers']}'),
            if (hasOrder) Text('Total: ${orderTotal.toStringAsFixed(2)} TND'),
            if (!hasOrder) const Text('Aucune commande', style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          if (hasOrder)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openOrderPageFromTable(table);
              },
              icon: const Icon(Icons.receipt),
              label: const Text('Voir commande'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDeleteTable(table);
            },
            icon: const Icon(Icons.delete),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  // Confirmer la suppression d'une table
  void _confirmDeleteTable(Map<String, dynamic> table) {
    final tableNumber = table['number'] as String;
    final orderTotal = (table['orderTotal'] as num?)?.toDouble() ?? 0.0;
    final hasOrder = orderTotal > 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer Table N° $tableNumber ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasOrder) ...[
              const Text('⚠️ ATTENTION: Cette table a une commande en cours !'),
              const SizedBox(height: 8),
              Text('Total: ${orderTotal.toStringAsFixed(2)} TND'),
              const SizedBox(height: 8),
              const Text('Êtes-vous sûr de vouloir supprimer cette table ?'),
            ] else ...[
              const Text('Cette table sera définitivement supprimée.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTable(table);
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Supprimer'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }


  // Supprimer définitivement une table
  void _deleteTable(Map<String, dynamic> table) async {
    final tableNumber = table['number'] as String;
    final tableId = table['id'] as String;
    final orderTotal = (table['orderTotal'] as num?)?.toDouble() ?? 0.0;
    final hasOrder = orderTotal > 0;
    
    try {
      // Si la table a une commande, nettoyer d'abord côté serveur
      if (hasOrder) {
        await ApiClient.dio.post('/api/admin/clear-table-consumption', 
          data: {'table': tableNumber},
          options: Options(headers: {'x-admin-token': 'admin123'})
        );
        print('[POS] Consommation table $tableNumber nettoyée côté serveur');
      }
      
      // Supprimer la table localement de TOUS les serveurs
      for (final serverName in serverTables.keys) {
        final tables = serverTables[serverName]!;
        tables.removeWhere((t) => t['id'] == tableId || t['number'] == tableNumber);
      }
      
      // Sauvegarder immédiatement
      await _saveTables();
      
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Table N° $tableNumber supprimée définitivement'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[POS] Erreur suppression table: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur suppression: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Dialog de nettoyage des tables vides
  void _showCleanupDialog() {
    final emptyTables = currentServerTables.where((table) {
      final orderTotal = (table['orderTotal'] as num?)?.toDouble() ?? 0.0;
      return orderTotal == 0;
    }).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nettoyer les tables vides'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tables sans commande trouvées: ${emptyTables.length}'),
            if (emptyTables.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Tables à supprimer:'),
              const SizedBox(height: 4),
              ...emptyTables.map((table) => Text('• Table N° ${table['number']}')),
            ] else ...[
              const SizedBox(height: 8),
              const Text('Aucune table vide à nettoyer.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          if (emptyTables.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _cleanupEmptyTables(emptyTables);
              },
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Nettoyer'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            ),
        ],
      ),
    );
  }

  // Nettoyer les tables vides
  void _cleanupEmptyTables(List<Map<String, dynamic>> emptyTables) async {
    int cleanedCount = 0;
    
    for (final table in emptyTables) {
      try {
        final tableId = table['id'] as String;
        final tableNumber = table['number'] as String;
        
        // Supprimer de TOUS les serveurs
        for (final serverName in serverTables.keys) {
          final tables = serverTables[serverName]!;
          tables.removeWhere((t) => t['id'] == tableId || t['number'] == tableNumber);
        }
        cleanedCount++;
        print('[POS] Table N° $tableNumber supprimée (vide)');
      } catch (e) {
        print('[POS] Erreur nettoyage table ${table['number']}: $e');
      }
    }
    
    // Sauvegarder immédiatement
    await _saveTables();
    
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$cleanedCount table(s) vide(s) supprimée(s) définitivement'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Utiliser le serveur sélectionné ou celui des préférences
      userName = widget.selectedServer ?? prefs.getString('pos_user_name') ?? 'Utilisateur';
      userRole = prefs.getString('pos_user_role') ?? 'Staff';
      sessionStart = prefs.getString('pos_session_start') ?? DateTime.now().toIso8601String();
    });
    _loadApiPrefs();
  }

  // Charger les tables depuis SharedPreferences
  Future<void> _loadTables() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Récupérer les IDs des tables à fermer
    final keys = prefs.getKeys().where((k) => k.startsWith('pos_table_to_close_')).toList();
    final tablesToClose = <String>{};
    for (final key in keys) {
      final tableId = prefs.getString(key);
      if (tableId != null) {
        tablesToClose.add(tableId);
        await prefs.remove(key); // Nettoyer
        print('[POS] Table $tableId marquée pour suppression');
      }
    }
    
    for (final serverName in serverTables.keys) {
      final tablesJson = prefs.getString('pos_tables_$serverName');
      if (tablesJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(tablesJson);
          final tables = decoded.map((t) {
            final table = Map<String, dynamic>.from(t);
            // Convertir les dates String en DateTime
            if (table['openedAt'] != null && table['openedAt'] is String) {
              table['openedAt'] = DateTime.parse(table['openedAt'] as String);
            }
            if (table['lastOrderAt'] != null && table['lastOrderAt'] is String) {
              table['lastOrderAt'] = DateTime.tryParse(table['lastOrderAt'] as String);
            }
            return table;
          }).where((t) => !tablesToClose.contains(t['id'])).toList(); // Filtrer les tables à fermer
          
          setState(() {
            serverTables[serverName] = tables;
          });
          
          if (tablesToClose.isNotEmpty) {
            print('[POS] Tables supprimées pour $serverName: ${tablesToClose.length}');
          }
        } catch (e) {
          print('[POS] Erreur chargement tables pour $serverName: $e');
        }
      }
    }
    
    // 🔧 CORRECTION : Synchroniser automatiquement après chargement des tables
    print('[POS] Synchronisation automatique après chargement des tables');
    await _syncOrdersWithTables();
  }


  // Nettoyer le localStorage local
  Future<void> _clearLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int deletedKeys = 0;
      
      for (final key in keys) {
        if (key.startsWith('pos_tables_') || 
            key.startsWith('pos_order_') || 
            key.startsWith('pos_table_to_close_')) {
          await prefs.remove(key);
          deletedKeys++;
        }
      }
      
      print('[POS] localStorage nettoyé: $deletedKeys clés supprimées');
    } catch (e) {
      print('[POS] Erreur nettoyage localStorage: $e');
    }
  }

  // Synchroniser les commandes existantes avec les tables
  // Afficher le dialog de simulation
  void _showSimulationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simulation de Données'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Générer des données réalistes pour tester le système :'),
            const SizedBox(height: 16),
            const Text('• 3 serveurs (MOHAMED, ALI, FATMA)'),
            const Text('• 30 tables au total (10 par serveur)'),
            const Text('• Commandes sur 5h d\'ouverture'),
            const Text('• Sous-notes avec noms de clients'),
            const Text('• Articles du menu réel'),
            const SizedBox(height: 16),
            const Text('Mode de simulation :', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _runSimulation('once');
                    },
                    icon: const Icon(Icons.flash_on),
                    label: const Text('En une fois'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _runSimulation('progressive');
                    },
                    icon: const Icon(Icons.timeline),
                    label: const Text('Progressive'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 🆕 Bouton Remettre à zéro
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetSystem();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Remettre à zéro'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  // Test de connexion API
  Future<void> _testApiConnection() async {
    try {
      print('[TEST API] Test de connexion...');
      
      // Test simple
      final response = await ApiClient.dio.get('/health');
      print('[TEST API] Health check: ${response.statusCode} - ${response.data}');
      
      // Test admin
      final adminResponse = await ApiClient.dio.post(
        '/api/admin/login',
        data: {'password': 'admin123'},
      );
      print('[TEST API] Admin login: ${adminResponse.statusCode} - ${adminResponse.data}');
      
      // Test simulation
      final simResponse = await ApiClient.dio.post(
        '/api/admin/simulate-data',
        data: {'mode': 'once', 'servers': ['MOHAMED']},
        options: Options(
          headers: {'x-admin-token': 'admin123'},
        ),
      );
      print('[TEST API] Simulation: ${simResponse.statusCode} - ${simResponse.data}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test API réussi ! Vérifiez les logs console.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('[TEST API] Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur API: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Exécuter la simulation
  Future<void> _runSimulation(String mode) async {
    try {
      print('[SIMULATION] Démarrage simulation mode: $mode');
      
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Génération des données...'),
            ],
          ),
        ),
      );

      print('[SIMULATION] Appel API /api/admin/simulate-data');
      
      // Appeler l'API de simulation
      final response = await ApiClient.dio.post(
        '/api/admin/simulate-data',
        data: {
          'mode': mode,
          'servers': ['MOHAMED', 'ALI', 'FATMA'],
          'progressive': mode == 'progressive',
        },
        options: Options(
          headers: {
            'x-admin-token': 'admin123', // Token admin
          },
        ),
      );
      
      print('[SIMULATION] Réponse reçue: ${response.statusCode}');
      print('[SIMULATION] Données: ${response.data}');

      // Fermer le dialog de chargement
      if (mounted) Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final generated = data['generated'] as Map<String, dynamic>;
        
        // Afficher le résultat
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Simulation terminée !\n'
                '${generated['orders']} commandes générées\n'
                '${generated['totalTables']} tables créées',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // Synchroniser les nouvelles données
        await _syncOrdersWithTables();
        
        // Sauvegarder les tables mises à jour
        _saveTables();
        
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('[SIMULATION] Erreur: $e');
      
      // Fermer le dialog de chargement en cas d'erreur
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur simulation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🆕 Remettre à zéro le système
  Future<void> _resetSystem() async {
    try {
      print('[RESET] Remise à zéro du système...');
      
      // Afficher une confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Remettre à zéro'),
          content: const Text(
            'Cette action va supprimer TOUTES les données :\n'
            '• Toutes les commandes\n'
            '• Toutes les factures\n'
            '• Tous les historiques\n\n'
            'Êtes-vous sûr de vouloir continuer ?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Oui, remettre à zéro'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Remise à zéro en cours...'),
            ],
          ),
        ),
      );
      
      // Appeler l'API de reset (utiliser l'endpoint existant)
      final response = await ApiClient.dio.post(
        '/api/admin/full-reset',
        options: Options(
          headers: {'x-admin-token': 'admin123'},
        ),
      );
      
      print('[RESET] Réponse reçue: ${response.statusCode} - ${response.data}');
      
      // Fermer le dialog de chargement
      if (mounted) {
        Navigator.of(context).pop();
        
        // 🔧 CORRECTION : Nettoyer aussi le cache client Flutter
        await _clearLocalStorage();
        
        // Réinitialiser les tables en mémoire
        setState(() {
          serverTables.clear();
          serverTables[userName] = [];
        });
        
        // Afficher le résultat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Système remis à zéro: ${response.data['message']}\nCache client également vidé.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Recharger les tables (vides) et synchroniser
        await _loadTables();
        await _syncOrdersWithTables();
      }
      
    } catch (e) {
      print('[RESET] Erreur: $e');
      
      // Fermer le dialog de chargement
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur remise à zéro: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Nettoyer l'historique des tables (local + serveur)
  Future<void> _clearHistory() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nettoyage Complet'),
        content: const Text('Voulez-vous vraiment supprimer TOUT l\'historique (commandes, factures, tables) et repartir sur une caisse vierge ?\n\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                // Afficher un indicateur de chargement
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 16),
                        Text('Nettoyage en cours...'),
                      ],
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 30),
                  ),
                );
                
                // Appeler l'endpoint serveur pour nettoyage complet
                final response = await ApiClient.dio.post(
                  '/api/admin/full-reset',
                  options: Options(
                    headers: {
                      'x-admin-token': 'admin123', // Token admin
                    },
                  ),
                );
                
                if (response.statusCode == 200) {
                  // Nettoyage côté serveur réussi, maintenant nettoyer le local
                  final prefs = await SharedPreferences.getInstance();
                  
                  // Supprimer toutes les clés de tables
                  final keys = prefs.getKeys();
                  int deletedKeys = 0;
                  for (final key in keys) {
                    if (key.startsWith('pos_tables_') || 
                        key.startsWith('pos_order_') || 
                        key.startsWith('pos_table_to_close_')) {
                      await prefs.remove(key);
                      deletedKeys++;
                    }
                  }
                  
                  // Réinitialiser les tables pour tous les serveurs
                  setState(() {
                    serverTables.clear();
                    // Réinitialiser avec le serveur actuel
                    serverTables[userName] = [];
                  });
                  
                  // Masquer le SnackBar de chargement
                  ScaffoldMessenger.of(context).clearSnackBars();
                  
                  // Afficher le succès
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🧹 Nettoyage complet terminé !\n${deletedKeys} clés locales supprimées'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                  
                  print('[POS] Nettoyage complet terminé: $deletedKeys clés locales supprimées');
                } else {
                  throw Exception('Erreur serveur: ${response.statusCode}');
                }
              } catch (e) {
                // Masquer le SnackBar de chargement
                ScaffoldMessenger.of(context).clearSnackBars();
                
                // Afficher l'erreur
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Erreur lors du nettoyage: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
                
                print('[POS] Erreur nettoyage: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Nettoyer Tout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🆕 Vérifier si synchronisation forcée demandée (après paiement complet)
  Future<void> _checkForcedSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final forceSync = prefs.getBool('pos_force_table_sync') ?? false;
      
      if (forceSync) {
        print('[POS] Synchronisation forcée détectée - rechargement des tables');
        await prefs.remove('pos_force_table_sync'); // Nettoyer le flag
        await _loadTables(); // Recharger les tables (supprime les tables fermées)
        await _syncOrdersWithTables(); // Resynchroniser avec les commandes
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('[POS] Erreur lors de la vérification de synchronisation forcée: $e');
    }
  }

  Future<void> _syncOrdersWithTables() async {
    try {
      print('[POS] Synchronisation des commandes avec les tables...');
      final response = await ApiClient.dio.get('/orders');
      final orders = (response.data as List).cast<Map<String, dynamic>>();
      
      print('[POS] ${orders.length} commandes trouvées sur le serveur');
      if (orders.isNotEmpty) {
        for (final order in orders) {
          print('[POS] Commande trouvée: table=${order['table']}, server=${order['server']}, id=${order['id']}');
        }
      }
      
      if (orders.isEmpty) {
        print('[POS] Aucune commande sur le serveur - suppression de toutes les tables');
        // Supprimer toutes les tables vides
        serverTables.clear();
        await _saveTables();
        if (mounted) {
          setState(() {});
        }
        return;
      }
      
      // Grouper les commandes par table ET par serveur
      final ordersByTableAndServer = <String, Map<String, List<Map<String, dynamic>>>>{};
      for (final order in orders) {
        final tableNumber = order['table']?.toString() ?? '';
        final server = order['server']?.toString() ?? 'MOHAMED';
        if (tableNumber.isNotEmpty) {
          ordersByTableAndServer.putIfAbsent(tableNumber, () => {});
          ordersByTableAndServer[tableNumber]!.putIfAbsent(server, () => []).add(order);
        }
      }
      
      // Créer aussi un mapping simple par table (pour compatibilité)
      final ordersByTable = <String, List<Map<String, dynamic>>>{};
      for (final tableNumber in ordersByTableAndServer.keys) {
        final allOrdersForTable = <Map<String, dynamic>>[];
        for (final serverOrders in ordersByTableAndServer[tableNumber]!.values) {
          allOrdersForTable.addAll(serverOrders);
        }
        ordersByTable[tableNumber] = allOrdersForTable;
      }
      
      print('[POS] Commandes groupées par table: ${ordersByTable.keys.join(', ')}');
      
      // 🆕 Créer automatiquement les tables manquantes pour les commandes
      for (final tableNumber in ordersByTable.keys) {
        final tableOrders = ordersByTable[tableNumber]!;
        if (tableOrders.isNotEmpty) {
          final firstOrder = tableOrders.first;
          final server = firstOrder['server'] as String? ?? 'MOHAMED';
          
          // Vérifier si la table existe déjà pour ce serveur
          final existingTables = serverTables[server] ?? [];
          final tableExists = existingTables.any((table) => table['number'] == tableNumber);
          
          if (!tableExists) {
            // Créer la table manquante
            final newTable = {
              'id': 'table_${server}_$tableNumber',
              'number': tableNumber,
              'status': 'occupee',
              'server': server,
              'covers': firstOrder['covers'] ?? 1,
              'openedAt': DateTime.now(),
              'orderId': null,
              'orderTotal': 0.0,
              'orderItems': [],
              'lastOrderAt': DateTime.now(), // 🔧 CORRECTION : Initialiser avec DateTime.now()
            };
            
            // Initialiser la liste des tables pour ce serveur si nécessaire
            if (serverTables[server] == null) {
              serverTables[server] = [];
            }
            
            serverTables[server]!.add(newTable);
            print('[POS] Table $tableNumber créée automatiquement pour serveur $server');
          }
        }
      }
      
      // Mettre à jour les tables avec les totaux
      bool hasUpdates = false;
      for (final serverName in serverTables.keys) {
        final tables = serverTables[serverName]!;
        for (final table in tables) {
          final tableNumber = table['number'] as String;
          // Ne traiter que les commandes de ce serveur pour cette table
          final tableOrders = ordersByTableAndServer[tableNumber]?[serverName] ?? [];
          
          if (tableOrders.isNotEmpty) {
            // 🔧 CORRECTION : Calculer le total en excluant les sous-notes payées
            double total = 0.0;
            for (final order in tableOrders) {
              // Si la commande a des notes (nouvelle structure)
              if (order.containsKey('mainNote') && order['mainNote'] != null) {
                final mainNote = order['mainNote'] as Map<String, dynamic>;
                final mainTotal = (mainNote['total'] as num?)?.toDouble() ?? 0.0;
                total += mainTotal;
                
                // Ajouter seulement les sous-notes non payées
                final subNotes = (order['subNotes'] as List?) ?? [];
                for (final subNote in subNotes) {
                  final subTotal = (subNote['total'] as num?)?.toDouble() ?? 0.0;
                  final isPaid = (subNote['paid'] as bool?) ?? false;
                  
                  if (!isPaid && subTotal > 0) {
                    total += subTotal;
                    print('[POS] Sous-note ${subNote['id']} ajoutée au total: $subTotal');
                  } else {
                    print('[POS] Sous-note ${subNote['id']} exclue du total: paid=$isPaid, total=$subTotal');
                  }
                }
              } else {
                // Ancienne structure (compatibilité)
                total += (order['total'] as num?)?.toDouble() ?? 0.0;
              }
            }
            
            // 🔧 CORRECTION : Forcer la mise à jour de l'interface
            hasUpdates = true;
            
            // Prendre la commande la plus récente pour l'ID
            final latestOrder = tableOrders.reduce((a, b) => 
              DateTime.parse(a['createdAt'] as String).isAfter(DateTime.parse(b['createdAt'] as String)) ? a : b);
            
            // 🆕 Gérer les notes multiples - cumuler tous les items de toutes les commandes
            final allItems = <Map<String, dynamic>>[];
            for (final order in tableOrders) {
              // Si la commande a des notes (nouvelle structure)
              if (order.containsKey('mainNote') && order['mainNote'] != null) {
                final mainNote = order['mainNote'] as Map<String, dynamic>;
                final mainItems = (mainNote['items'] as List?) ?? [];
                allItems.addAll(mainItems.cast<Map<String, dynamic>>());
                
                // Ajouter aussi les sous-notes (seulement celles qui ne sont pas payées et ont des articles)
                final subNotes = (order['subNotes'] as List?) ?? [];
                for (final subNote in subNotes) {
                  final subItems = (subNote['items'] as List?) ?? [];
                  final subTotal = (subNote['total'] as num?)?.toDouble() ?? 0.0;
                  final isPaid = (subNote['paid'] as bool?) ?? false;
                  
                  // 🔧 CORRECTION : Ne pas inclure les sous-notes payées ou vides
                  if (!isPaid && subTotal > 0 && subItems.isNotEmpty) {
                    allItems.addAll(subItems.cast<Map<String, dynamic>>());
                    print('[POS] Sous-note ${subNote['id']} incluse: ${subItems.length} items, total: $subTotal');
                  } else {
                    print('[POS] Sous-note ${subNote['id']} exclue: paid=$isPaid, total=$subTotal, items=${subItems.length}');
                  }
                }
              } else {
                // Ancienne structure (compatibilité)
                final items = (order['items'] as List?) ?? [];
                allItems.addAll(items.cast<Map<String, dynamic>>());
              }
            }
            
            table['orderId'] = latestOrder['id'];
            table['orderTotal'] = total;
            table['orderItems'] = allItems; // 🆕 Tous les items de toutes les commandes
            
            // 🆕 Horodatage de la dernière commande (la plus récente)
            final latestUpdatedAt = latestOrder['updatedAt'] as String?;
            if (latestUpdatedAt != null) {
              table['lastOrderAt'] = DateTime.tryParse(latestUpdatedAt) ?? DateTime.now();
            }
            
            hasUpdates = true;
            
            print('[POS] Table $tableNumber synchronisée: $total TND (${tableOrders.length} commandes, ${allItems.length} items)');
          } else {
            // Pas de commandes pour cette table
            table['orderId'] = null;
            table['orderTotal'] = 0.0;
            table['orderItems'] = [];
            print('[POS] Table $tableNumber: aucune commande');
          }
        }
      }
      
      // 🆕 Supprimer les tables qui n'ont plus de commandes actives pour ce serveur
      final tablesToRemove = <String, List<String>>{};
      for (final serverName in serverTables.keys) {
        final tables = serverTables[serverName]!;
        final tablesToDelete = <String>[];
        
        for (final table in tables) {
          final tableNumber = table['number'] as String;
          
          // Vérifier si cette table a des commandes pour ce serveur spécifique
          bool hasOrdersForThisServer = false;
          if (ordersByTableAndServer.containsKey(tableNumber)) {
            hasOrdersForThisServer = ordersByTableAndServer[tableNumber]!.containsKey(serverName) && 
                                    ordersByTableAndServer[tableNumber]![serverName]!.isNotEmpty;
          }
          
          // Si la table n'a pas de commandes pour ce serveur, la marquer pour suppression
          if (!hasOrdersForThisServer) {
            tablesToDelete.add(tableNumber);
            print('[POS] Table $tableNumber marquée pour suppression chez $serverName (plus de commandes pour ce serveur)');
          }
        }
        
        if (tablesToDelete.isNotEmpty) {
          tablesToRemove[serverName] = tablesToDelete;
        }
      }
      
      // Supprimer les tables vides
      for (final serverName in tablesToRemove.keys) {
        final tablesToDelete = tablesToRemove[serverName]!;
        serverTables[serverName]!.removeWhere((table) => 
          tablesToDelete.contains(table['number'] as String));
        print('[POS] Tables supprimées pour $serverName: ${tablesToDelete.join(', ')}');
      }
      
      if (hasUpdates || tablesToRemove.isNotEmpty) {
        await _saveTables();
        if (mounted) {
          setState(() {});
        }
        print('[POS] Synchronisation terminée avec mises à jour');
      } else {
        print('[POS] Synchronisation terminée - aucune mise à jour nécessaire');
      }
    } catch (e) {
      print('[POS] Erreur synchronisation: $e');
      // En cas d'erreur, réinitialiser les totaux
      for (final serverName in serverTables.keys) {
        final tables = serverTables[serverName]!;
        for (final table in tables) {
          table['orderId'] = null;
          table['orderTotal'] = 0.0;
          table['orderItems'] = [];
        }
      }
      await _saveTables();
      if (mounted) {
        setState(() {});
      }
    }
  }


  // Sauvegarder les tables dans SharedPreferences
  Future<void> _saveTables() async {
    final prefs = await SharedPreferences.getInstance();
    
    for (final entry in serverTables.entries) {
      final serverName = entry.key;
      final tables = entry.value.map((t) {
        final table = Map<String, dynamic>.from(t);
        // Convertir DateTime en String pour JSON
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

  void _connectSocket() {
    final base = ApiClient.dio.options.baseUrl;
    final uri = base.replaceAll(RegExp(r"/+$"), '');
    print('[POS HOME] Connexion Socket.IO vers: $uri');
    final s = io.io(uri, io.OptionBuilder().setTransports(['websocket']).setExtraHeaders({'Origin': uri}).build());
    socket = s;
    
    s.on('connect', (_) {
      print('[POS HOME] Socket.IO connecté avec succès');
    });
    
    s.on('disconnect', (_) {
      print('[POS HOME] Socket.IO déconnecté');
    });
    
    s.on('connect_error', (error) {
      print('[POS HOME] Erreur connexion Socket.IO: $error');
    });
    
    s.on('order:new', (payload) {
      // 🔧 CORRECTION : Synchronisation automatique pour les nouvelles commandes
      print('[POS HOME] Événement order:new reçu dans pos_home_page.dart');
      final order = (payload as Map).cast<String, dynamic>();
      final table = order['table']?.toString() ?? '';
      final orderId = (order['id'] as num?)?.toInt() ?? 0;
      
      print('[POS HOME] Événement order:new reçu pour table $table, commande $orderId');
      
      // Synchroniser automatiquement pour mettre à jour le plan de table
      print('[POS] Déclenchement synchronisation automatique après order:new');
      _syncOrdersWithTables().then((_) {
        print('[POS] Synchronisation automatique terminée après order:new');
        if (mounted) {
          setState(() {});
        }
      }).catchError((e) {
        print('[POS] Erreur synchronisation automatique: $e');
      });
    });

    // 🔧 CORRECTION : Synchronisation automatique pour les mises à jour
    s.on('order:updated', (payload) {
      print('[POS] Événement order:updated reçu');
      // Synchroniser automatiquement pour mettre à jour le plan de table
      _syncOrdersWithTables().then((_) {
        if (mounted) {
          setState(() {});
        }
      }).catchError((e) {
        print('[POS] Erreur synchronisation automatique: $e');
      });
    });

    s.on('order:archived', (payload) {
      // 🔧 CORRECTION : Synchronisation automatique pour les commandes archivées
      print('[POS] Événement order:archived reçu pour commande ${payload['orderId']}, table ${payload['table']}');
      // Synchroniser automatiquement pour mettre à jour le plan de table
      _syncOrdersWithTables().then((_) {
        if (mounted) {
          setState(() {});
        }
      }).catchError((e) {
        print('[POS] Erreur synchronisation automatique: $e');
      });
    });

    // 🔧 REFACTORISATION : Simple mise à jour d'interface pour création de table
    s.on('table:created', (payload) {
      print('[POS] Événement table:created reçu: $payload');
      // Juste une mise à jour d'interface, la synchronisation se fera via _syncOrdersWithTables()
      if (mounted) {
        setState(() {});
      }
    });

    // Écouter les événements de reset système
    s.on('system:reset', (payload) {
      print('[POS] Événement system:reset reçu: $payload');
      final data = (payload as Map).cast<String, dynamic>();
      final message = data['message']?.toString() ?? 'Système réinitialisé';
      final deleted = data['deleted'] as Map<String, dynamic>?;
      
      // Nettoyer automatiquement le localStorage local
      _clearLocalStorage();
      
      if (mounted) {
        setState(() {
          // Réinitialiser les tables pour tous les serveurs
          serverTables.clear();
          serverTables[userName] = [];
        });
        
        // Afficher une notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🧹 $message'),
                if (deleted != null) ...[
                  const SizedBox(height: 4),
                  Text('Données supprimées:', style: TextStyle(fontSize: 12)),
                  Text('• ${deleted['orders'] ?? 0} commandes', style: TextStyle(fontSize: 12)),
                  Text('• ${deleted['bills'] ?? 0} factures', style: TextStyle(fontSize: 12)),
                  Text('• ${deleted['services'] ?? 0} services', style: TextStyle(fontSize: 12)),
                ],
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    });

    // 🔧 REFACTORISATION : Simple mise à jour d'interface pour table nettoyée
    s.on('table:cleared', (payload) {
      final data = (payload as Map).cast<String, dynamic>();
      final tableNumber = data['table']?.toString() ?? '';
      print('[POS] Table $tableNumber nettoyée');
      // Juste une mise à jour d'interface, la synchronisation se fera via _syncOrdersWithTables()
      if (mounted) {
        setState(() {});
      }
    });
    
    // 🔧 REFACTORISATION : Simple mise à jour d'interface pour transfert serveur
    s.on('server:transferred', (payload) async {
      print('[POS] Événement server:transferred reçu: $payload');
      // Juste une mise à jour d'interface, la synchronisation se fera via _syncOrdersWithTables()
      if (mounted) {
        setState(() {});
      }
    });
    
    // 🆕 Écouter l'événement table:transferred pour libérer la table source et créer la destination
    // 🔧 REFACTORISATION : Simple mise à jour d'interface pour transfert de table
    s.on('table:transferred', (payload) async {
      print('[POS] Événement table:transferred reçu: $payload');
      // Juste une mise à jour d'interface, la synchronisation se fera via _syncOrdersWithTables()
      if (mounted) {
        setState(() {});
      }
    });
    
    s.connect();
  }

  Future<void> _reconnectSocket() async {
    try { socket?.dispose(); } catch (_) {}
    socket = null;
    _connectSocket();
  }

  void _loadApiPrefs() {
    // 🔧 CORRECTION : Chargement synchrone des préférences par défaut
    useCloudApi = false; // Par défaut : local
    apiLocalBaseUrl = 'http://localhost:3000';
    apiCloudBaseUrl = 'https://orderly-server-production.up.railway.app';
    _applyApiBase();
    print('[API] Préférences par défaut appliquées: useCloud=$useCloudApi, local=$apiLocalBaseUrl');
    
    // Charger les vraies préférences en arrière-plan
    _loadApiPrefsAsync();
  }

  Future<void> _loadApiPrefsAsync() async {
    final prefs = await SharedPreferences.getInstance();
    useCloudApi = prefs.getBool('api_use_cloud') ?? false;
    apiLocalBaseUrl = prefs.getString('api_local_url') ?? 'http://localhost:3000';
    apiCloudBaseUrl = prefs.getString('api_cloud_url') ?? 'https://orderly-server-production.up.railway.app';
    _applyApiBase();
    print('[API] Préférences chargées: useCloud=$useCloudApi, local=$apiLocalBaseUrl, cloud=$apiCloudBaseUrl');
  }

  Future<void> _saveApiPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('api_use_cloud', useCloudApi);
    await prefs.setString('api_local_url', apiLocalBaseUrl);
    await prefs.setString('api_cloud_url', apiCloudBaseUrl);
  }

  void _applyApiBase() {
    final target = useCloudApi && apiCloudBaseUrl.isNotEmpty ? apiCloudBaseUrl : apiLocalBaseUrl;
    if (target.isNotEmpty) {
      ApiClient.dio.options.baseUrl = target;
      print('[API] Base URL appliquée: ${ApiClient.dio.options.baseUrl} (useCloud=' + useCloudApi.toString() + ')');
    }
  }

  Future<void> _toggleApiMode() async {
    setState(() => useCloudApi = !useCloudApi);
    _applyApiBase();
    await _saveApiPrefs();
    await _reconnectSocket();
    await _syncOrdersWithTables();
  }

  Future<void> _configureApiUrls() async {
    final localCtrl = TextEditingController(text: apiLocalBaseUrl);
    final cloudCtrl = TextEditingController(text: apiCloudBaseUrl);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Configuration API (Local / Cloud)'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: localCtrl,
                decoration: const InputDecoration(labelText: 'API Local', hintText: 'http://localhost:3000', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cloudCtrl,
                decoration: const InputDecoration(labelText: 'API Cloud', hintText: 'https://ton-app.up.railway.app', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              apiLocalBaseUrl = localCtrl.text.trim().isNotEmpty ? localCtrl.text.trim() : apiLocalBaseUrl;
              apiCloudBaseUrl = cloudCtrl.text.trim();
              _applyApiBase();
              await _saveApiPrefs();
              Navigator.of(context).pop();
              await _reconnectSocket();
              await _syncOrdersWithTables();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pos_user_id');
    await prefs.remove('pos_user_name');
    await prefs.remove('pos_user_role');
    await prefs.remove('pos_session_start');
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/pos');
    }
  }

  Color _getTableColor(String status) {
    switch (status) {
      case 'libre':
        return Colors.green.shade50;
      case 'occupee':
        return Colors.orange.shade50;
      case 'reservee':
        return Colors.blue.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  IconData _getTableIcon(String status) {
    switch (status) {
      case 'libre':
        return Icons.check_circle;
      case 'occupee':
        return Icons.restaurant;
      case 'reservee':
        return Icons.event;
      default:
        return Icons.help;
    }
  }

  void _openOrderPageFromTable(Map<String, dynamic> table) {
    // 🔧 CORRECTION : Synchroniser avant d'ouvrir la page de commande
    print('[POS] Synchronisation avant ouverture de la page de commande');
    _syncOrdersWithTables().then((_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => refactor.PosOrderPage( // Version refactorisée pour test
            tableNumber: table['number'],
            tableId: table['id'],
            orderId: table['orderId'],
          currentCovers: table['covers'] ?? 0,
          currentServer: table['server'] ?? userName,
        ),
      ),
    ).then((_) {
      // 🔧 CORRECTION : Synchroniser automatiquement au retour de la caisse
      print('[POS] 🔥 Retour de la caisse - synchronisation automatique');
      _syncOrdersWithTables().then((_) {
        if (mounted) {
          setState(() {});
        }
      }).catchError((e) {
        print('[POS] ❌ Erreur synchronisation au retour: $e');
      });
    });
    }).catchError((e) {
      print('[POS] Erreur synchronisation avant ouverture: $e');
      // Ouvrir quand même la page en cas d'erreur
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => refactor.PosOrderPage( // Version refactorisée pour test
            tableNumber: table['number'],
            tableId: table['id'],
            orderId: table['orderId'],
            currentCovers: table['covers'] ?? 0,
            currentServer: table['server'] ?? userName,
          ),
        ),
      ).then((_) {
        setState(() {});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECF0F1),
      body: Column(
        children: [
          // En-tête MACAISE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF2C3E50), const Color(0xFF34495E)],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.point_of_sale, color: Color(0xFF3498DB), size: 32),
                ),
                const SizedBox(width: 16),
                // Titre
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MACAISE APPLICATION D\'ENCAISSEMENT',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Caissier $userName',
                        style: const TextStyle(color: Color(0xFF3498DB), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
        const SizedBox(width: 12),
        // Sélecteur API Local/Cloud
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(useCloudApi ? Icons.cloud : Icons.computer, color: Colors.white),
              const SizedBox(width: 6),
              Switch(
                value: useCloudApi,
                onChanged: (_) => _toggleApiMode(),
                activeColor: Colors.lightGreenAccent,
              ),
              Text(useCloudApi ? 'Cloud' : 'Local', style: const TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _configureApiUrls,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                child: const Text('API', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  _syncOrdersWithTables().then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔄 Synchronisation terminée'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Erreur synchronisation: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  });
                },
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                child: const Text('🔄 Sync', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
                // Date/Heure
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Color(0xFF3498DB), fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Bouton Simulation
                ElevatedButton.icon(
                  onPressed: _showSimulationDialog,
                  icon: const Icon(Icons.play_circle_outline, color: Colors.white),
                  label: const Text('Simulation', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                // 🆕 Basculer vers version refactor (copie)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/pos_refactor', arguments: {'selectedServer': userName});
                  },
                  icon: const Icon(Icons.transform, color: Colors.white),
                  label: const Text('Refactor', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton Quitter
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/pos');
                  },
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  label: const Text('Quitter', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE74C3C),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                // Déconnexion
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Déconnexion',
                ),
              ],
            ),
          ),

          // Plan de salle
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre section
                  Row(
                    children: [
                      const Icon(Icons.table_restaurant, size: 32, color: Color(0xFF2C3E50)),
                      const SizedBox(width: 12),
                      Text(
                        'Tables de $userName',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                      ),
                      const Spacer(),
                      const SizedBox(width: 16),
                      // Légende
                      _buildLegend('Libre', Colors.green),
                      const SizedBox(width: 16),
                      _buildLegend('Occupée', Colors.orange),
                      const SizedBox(width: 16),
                      _buildLegend('Réservée', Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Grille de tables adaptée pour tablette
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 📱 Calculer le nombre de colonnes selon la largeur de l'écran
                        final screenWidth = constraints.maxWidth;
                        final crossAxisCount = screenWidth > 1200 ? 6 : (screenWidth > 800 ? 5 : 4);
                        final spacing = screenWidth > 1200 ? 20.0 : 16.0;
                        
                        // 📱 Déterminer si c'est une tablette
                        final isTablet = screenWidth > 600;
                        
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio: isTablet ? 1.3 : 1.1, // Adaptation automatique
                          ),
                          itemCount: currentServerTables.length + 1, // +1 pour le bouton "Ajouter table"
                          itemBuilder: (_, i) {
                        // Premier élément : bouton "Ajouter table"
                        if (i == 0) {
                          return InkWell(
                            onTap: _showAddTableDialog,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade300,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_circle_outline, size: 40, color: Colors.blue.shade600),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ajouter Table',
                                      style: TextStyle(
                                        fontSize: 16, 
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Nouvelle table',
                                      style: TextStyle(
                                        fontSize: 12, 
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        
                        // Éléments suivants : tables normales (index -1 car on a ajouté le bouton)
                        final table = currentServerTables[i - 1];
                        final status = table['status'] as String;
                        final number = table['number'] as String;
                        final covers = table['covers'] as int;
                        final server = table['server'] as String? ?? '';
                        final openedAt = table['openedAt'] is String 
                            ? DateTime.tryParse(table['openedAt'] as String)
                            : table['openedAt'] as DateTime?;
                        final elapsedTime = _getElapsedTime(openedAt);
                        
                        // Calculer le total dépensé
                        final orderTotal = (table['orderTotal'] as num?)?.toDouble() ?? 0.0;
                        final hasOrder = orderTotal > 0;
                        
                        return InkWell(
                          onTap: () => _handleTableTap(table),
                          onLongPress: () => _showTableOptions(table),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getTableColor(status),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: status == 'occupee' ? Colors.orange : Colors.grey.shade300,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRect(
                            child: Padding(
                                padding: EdgeInsets.all(isTablet ? 8.0 : 6.0),
                                child: SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                              child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                children: [
                                // Numéro de table (adaptatif)
                                Text(
                                  'Table N° $number',
                                  style: TextStyle(
                                    fontSize: isTablet ? 20 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                // Couverts (adaptatif)
                                if (covers > 0) ...[
                                  SizedBox(height: isTablet ? 4 : 3),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 10 : 6,
                                      vertical: isTablet ? 4 : 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$covers couverts',
                                      style: TextStyle(
                                        fontSize: isTablet ? 12 : 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                                
                                // Temps d'occupation (adaptatif)
                                if (openedAt != null) ...[
                                  SizedBox(height: isTablet ? 4 : 3),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 12 : 8,
                                      vertical: isTablet ? 5 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade600,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          color: Colors.white,
                                          size: isTablet ? 14 : 12,
                                        ),
                                        SizedBox(width: isTablet ? 6 : 4),
                                        Text(
                                          elapsedTime,
                                          style: TextStyle(
                                            fontSize: isTablet ? 12 : 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                
                                // Total des commandes (adaptatif)
                                if (hasOrder) ...[
                                  SizedBox(height: isTablet ? 4 : 3),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 14 : 10,
                                      vertical: isTablet ? 7 : 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF27AE60),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: isTablet ? 2 : 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      '${orderTotal.toStringAsFixed(2)} TND',
                                      style: TextStyle(
                                        fontSize: isTablet ? 14 : 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                                
                                // Temps depuis dernière commande (adaptatif)
                                if (table['lastOrderAt'] != null) ...[
                                  SizedBox(height: isTablet ? 4 : 3),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 10 : 8,
                                      vertical: isTablet ? 5 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getInactivityColor(table['lastOrderAt']),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.shopping_cart,
                                          color: Colors.white,
                                          size: isTablet ? 14 : 12,
                                        ),
                                        SizedBox(width: isTablet ? 6 : 4),
                                        Text(
                                          _getTimeSinceLastOrder(table['lastOrderAt']),
                                          style: TextStyle(
                                            fontSize: isTablet ? 12 : 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                // Indicateur appui long
                                const SizedBox(height: 1),
                                const Text(
                                  'Appui long',
                                  style: TextStyle(
                                    fontSize: 6,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                ],
                                    ),
                                  ),
                              ),
                            ),
                          ),
                        );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Barre d'outils adaptée pour tablette
          Container(
            padding: const EdgeInsets.all(20), // Plus d'espace pour tablette
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.search),
                    label: const Text('Rechercher Table'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(20), // Plus grand pour tablette
                      backgroundColor: const Color(0xFF3498DB),
                      minimumSize: const Size(0, 60), // Hauteur minimale pour tablette
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Factures du Jour'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(20), // Plus grand pour tablette
                      backgroundColor: const Color(0xFF27AE60),
                      minimumSize: const Size(0, 60), // Hauteur minimale pour tablette
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.analytics),
                    label: const Text('Statistiques'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(20), // Plus grand pour tablette
                      backgroundColor: const Color(0xFF9B59B6),
                      minimumSize: const Size(0, 60), // Hauteur minimale pour tablette
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

