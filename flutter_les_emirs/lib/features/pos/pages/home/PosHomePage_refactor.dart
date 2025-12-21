import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';
import 'dart:convert';
import '../../../../core/api_client.dart';
import '../order/PosOrderPage_refactor.dart';
import '../../models/order_note.dart';
import '../order/services/order_repository.dart';
import '../order/services/payment_service.dart' as OrderPaymentService;
import '../payment/PosPaymentPage_refactor.dart';
import 'widgets/TableLegendBar.dart';
import 'widgets/TableGrid.dart';
import 'widgets/HeaderLogoTitle.dart';
import 'widgets/DateTimeBadge.dart';
import 'widgets/HeaderActions.dart';
import 'widgets/AddTableDialog.dart';
import 'widgets/ReservationDialog.dart';
import 'widgets/CleanupEmptyTablesDialog.dart';
import 'widgets/SimulationDialog.dart';
import 'widgets/BottomToolbar.dart';
import 'widgets/HistoryView.dart';
import 'widgets/ServerSalesReportDialog.dart';
import 'state/home_state.dart';
import 'state/home_controller.dart';
import 'services/socket_service.dart';
import 'services/admin_actions.dart';
import 'services/tables_repository.dart';
import 'utils/time_helpers.dart';
import 'services/api_prefs.dart';
import 'services/table_actions.dart';
import 'services/cleanup_service.dart';
import 'services/local_storage_service.dart';
import 'services/orders_sync_service.dart';
import 'services/history_service.dart';
import 'services/history_controller.dart';
import 'services/server_sales_report_controller.dart';

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
  // State/Controller/Service (refactor en cours)
  final HomeState _homeState = HomeState();
  late final HomeController _homeController;
  final HomeSocketService _homeSocket = HomeSocketService();
  final ApiPrefsService _apiPrefs = ApiPrefsService();
  
  // ⚙️ Sélecteur d'API (local/cloud)
  bool useCloudApi = false;
  String apiLocalBaseUrl = 'http://localhost:3000';
  String apiCloudBaseUrl = '';
  
  // 🆕 Mode historique (basculer entre vue actuelle et historique)
  bool _showHistory = false;
  final HistoryController _historyController = HistoryController();
  final ServerSalesReportController _serverReportController = ServerSalesReportController();
  bool _loadingDialogVisible = false;
  bool _isAdminSession = false;
  String? _adminViewingServer;
  
  // Tables centralisées dans HomeState
  Map<String, List<Map<String, dynamic>>> get serverTables => _homeState.serverTables;
  String _getActiveServerName() {
    if (_isAdminSession && _adminViewingServer != null) {
      return _adminViewingServer!;
    }
    return _homeState.userName;
  }

  // Tables du serveur affiché (serveur courant ou sélection admin)
  List<Map<String, dynamic>> get currentServerTables {
    final target = _getActiveServerName();
    return serverTables[target] ?? <Map<String, dynamic>>[];
  }

  // Tables filtrées selon la recherche et les statuts sélectionnés
  List<Map<String, dynamic>> get _filteredTables {
    final base = currentServerTables;
    final q = _homeState.query.trim().toLowerCase();
    final selected = _homeState.selectedStatuses;
    return base.where((t) {
      final status = (t['status'] as String?)?.toLowerCase() ?? '';
      final number = (t['number']?.toString() ?? '').toLowerCase();
      final serverName = (t['server']?.toString() ?? '').toLowerCase();
      final matchesQuery = q.isEmpty || number.contains(q) || serverName.contains(q);
      final matchesStatus = selected.isEmpty || selected.contains(status);
      return matchesQuery && matchesStatus;
    }).toList();
  }

  bool _isAdminOverviewVisible() => _isAdminSession && !_showHistory && _adminViewingServer == null;
  bool _needsAdminServerSelectionForHistory() => _isAdminSession && _showHistory && _adminViewingServer == null;
  String _resolveSectionTitle() {
    if (_showHistory) {
      if (_isAdminSession) {
        return _adminViewingServer == null
            ? 'Historique - Sélectionnez un serveur'
            : 'Historique - ${_adminViewingServer!}';
      }
      return 'Historique - Tables de ${_homeState.userName}';
    }
    if (_isAdminSession) {
      return _adminViewingServer == null
          ? 'Vue manager - Toutes les tables'
          : 'Vue manager - ${_adminViewingServer!}';
    }
    return 'Tables de ${_homeState.userName}';
  }

  @override
  void initState() {
    super.initState();
    _homeController = HomeController(_homeState);
    // 🆕 CORRECTION : Charger les préférences API EN PREMIER avant toute connexion
    _loadApiPrefs();
    // 🔧 Les préférences API sont maintenant chargées dans _loadUserInfo() pour garantir l'ordre
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
    // ⚠️ IMPORTANT : Nettoyer le socket via le service pour retirer tous les listeners
    try {
      _homeSocket.dispose(); // Nettoyer via le service (retire les listeners + disconnect)
    } catch (e) {
      print('[POS HOME] Erreur lors du nettoyage socket dans dispose: $e');
    }
    try {
      socket?.dispose(); // Nettoyer aussi la référence locale
    } catch (e) {
      print('[POS HOME] Erreur lors du dispose socket local dans dispose: $e');
    }
    socket = null;
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

  // Helpers déplacés dans TimeHelpers
  String _getElapsedTime(DateTime? openedAt) => TimeHelpers.getElapsedTime(openedAt);
  String _getTimeSinceLastOrder(dynamic lastOrderAt) => TimeHelpers.getTimeSinceLastOrder(lastOrderAt);
  Color _getInactivityColor(dynamic lastOrderAt) => TimeHelpers.getInactivityColor(lastOrderAt);


  // Ouvrir une table (démarrer le chronomètre)
  void _openTable(String tableId) {
    final owner = _getActiveServerName();
    setState(() {
      TableActions.openTable(serverTables: serverTables, userName: owner, tableId: tableId);
    });
    _saveTables(); // Sauvegarder
  }

  // Fermer une table (arrêter le chronomètre)
  void _closeTable(String tableId) {
    setState(() {
      TableActions.closeTable(serverTables: serverTables, tableId: tableId);
    });
    _saveTables(); // Sauvegarder immédiatement
    print('[POS] Table $tableId fermée définitivement');
  }
  // Gérer le tap sur une table
  void _handleTableTap(Map<String, dynamic> table) {
    final status = table['status'] as String;
    
    if (status == 'occupee') {
      _handleOccupiedTableTap(table);
    } else if (status == 'reservee') {
      // Gérer la réservation
      _showReservationDialog(table);
    }
    // Note: Plus de tables "libre" - on ajoute des tables dynamiquement
  }

  Future<void> _handleOccupiedTableTap(Map<String, dynamic> table) async {
    final tableNumber = (table['number'] ?? '').toString();
    if (tableNumber.isEmpty) {
      _openOrderPageFromTable(table);
      return;
    }
    final int covers = (table['covers'] as int?) ?? 1;
    _showLoadingDialog();
    _TableNotesData? notesData;
    try {
      notesData = await _loadNotesForTable(tableNumber, covers);
    } finally {
      _hideLoadingDialog();
    }
    if (!mounted) return;
    if (notesData == null) {
      _openOrderPageFromTable(table);
      return;
    }

    if (notesData.subNotes.isEmpty) {
      _openOrderPageFromTable(table, initialNoteId: 'main');
      return;
    }

    final selectedNoteId = await _showNoteSelectionDialog(
      tableNumber: tableNumber,
      mainNote: notesData.mainNote,
      subNotes: notesData.subNotes,
    );
    if (selectedNoteId != null) {
      _openOrderPageFromTable(table, initialNoteId: selectedNoteId);
    }
  }

  void _handleTableLongPress(Map<String, dynamic> table) {
    final status = table['status'] as String?;
    if (status != 'occupee') {
      _showSnack('Impossible d\'ouvrir le paiement: la table n\'est pas occupée.');
      return;
    }
    _openPaymentForTable(table);
  }

  Future<void> _openPaymentForTable(Map<String, dynamic> table) async {
    final tableNumber = (table['number'] ?? '').toString();
    if (tableNumber.isEmpty) {
      _showSnack('Numéro de table introuvable.');
      return;
    }
    final int covers = (table['covers'] as int?) ?? 1;
    _showLoadingDialog();
    try {
      final notesData = await _loadNotesForTable(tableNumber, covers);
      final allOrders = await OrderPaymentService.PaymentService.getAllOrdersForTable(tableNumber);
      _hideLoadingDialog();
      if (!mounted) return;
      if (notesData == null) {
        _showSnack('Impossible de charger les notes pour la table $tableNumber');
        return;
      }

      final mainNote = notesData.mainNote;
      final subNotes = notesData.subNotes;
      final paymentItems = mainNote.items.map((item) => {
            'id': item.id,
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
          }).toList();
      final totalAmount = _calculateTableTotal(mainNote, subNotes);
      final tableId = table['id']?.toString() ?? tableNumber;

      final tableServer = (table['server'] as String?) ?? _getActiveServerName();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PosPaymentPage(
            tableNumber: tableNumber,
            tableId: tableId,
            items: paymentItems,
            total: totalAmount,
            covers: covers,
            currentServer: tableServer,
            mainNote: mainNote,
            subNotes: subNotes,
            activeNoteId: 'main',
            allOrders: allOrders,
          ),
        ),
      ).then((result) {
        if (result != null && result['force_refresh'] == true) {
          _syncOrdersWithTables();
        }
      });
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      _showSnack('Erreur lors de l\'ouverture du paiement: $e');
    }
  }

  Future<_TableNotesData?> _loadNotesForTable(String tableNumber, int covers) async {
    try {
      final data = await OrderRepository.loadExistingOrder(tableNumber);
      if (data == null) return null;

      final mainItems = (data['mainItems'] as List).cast<OrderNoteItem>();
      final subNotes = (data['subNotes'] as List).cast<OrderNote>();
      final double mainTotal = mainItems.fold<double>(0.0, (sum, item) => sum + (item.price * item.quantity));

      final mainNote = OrderNote(
        id: 'main',
        name: 'Note Principale',
        covers: covers,
        items: mainItems,
        total: mainTotal,
      );

      return _TableNotesData(mainNote: mainNote, subNotes: subNotes);
    } catch (e) {
      print('[POS] Erreur chargement notes table $tableNumber: $e');
      return null;
    }
  }

  Future<String?> _showNoteSelectionDialog({
    required String tableNumber,
    required OrderNote mainNote,
    required List<OrderNote> subNotes,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sélectionner une note - Table $tableNumber'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNoteChoiceTile(
                label: 'Note principale',
                itemCount: mainNote.items.length,
                total: mainNote.total,
                onTap: () => Navigator.of(context).pop('main'),
              ),
              const Divider(),
              ...subNotes.map(
                (note) => _buildNoteChoiceTile(
                  label: note.name,
                  itemCount: note.items.length,
                  total: note.total,
                  onTap: () => Navigator.of(context).pop(note.id),
                ),
              ),
            ],
          ),
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

  Widget _buildNoteChoiceTile({
    required String label,
    required int itemCount,
    required double total,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          label.isNotEmpty ? label[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(label),
      subtitle: Text('$itemCount article(s) • ${total.toStringAsFixed(3)} TND'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showLoadingDialog() {
    if (_loadingDialogVisible || !mounted) return;
    _loadingDialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _hideLoadingDialog() {
    if (_loadingDialogVisible && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _loadingDialogVisible = false;
    }
  }

  void _selectServerForAdmin(String serverName) {
    setState(() {
      serverTables.putIfAbsent(serverName, () => <Map<String, dynamic>>[]);
      _adminViewingServer = serverName;
      _showHistory = false;
    });
  }

  void _returnToAdminOverview() {
    setState(() {
      _adminViewingServer = null;
    });
  }

  Widget _buildAdminOverview() {
    if (serverTables.isEmpty) {
      return _buildAdminOverviewEmptyState();
    }
    final entries = serverTables.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (entries.every((entry) => entry.value.isEmpty)) {
      return _buildAdminOverviewEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1400
            ? 3
            : constraints.maxWidth >= 900
                ? 2
                : 1;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            final tables = entry.value;
            final totalAmount = _computeTablesTotal(tables);
            final oldest = _findOldestOpenedTable(tables);
            final busyTables = tables.length;
            final pendingPayments = _countPendingTables(tables);

            return _AdminServerOverviewCard(
              serverName: entry.key,
              tableCount: busyTables,
              pendingPayments: pendingPayments,
              totalAmountLabel: _formatTableCurrency(totalAmount),
              oldestElapsed: oldest != null ? _getElapsedTime(oldest) : '—',
              enabled: tables.isNotEmpty,
              onOpen: () => _selectServerForAdmin(entry.key),
            );
          },
        );
      },
    );
  }

  Widget _buildAdminOverviewEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_restaurant_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Aucune table active pour le moment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dès qu\'un serveur ouvre une table, elle apparaîtra ici.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminHistoryPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'Sélectionnez un serveur pour consulter son historique.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _returnToAdminOverview(),
            icon: const Icon(Icons.dashboard_customize),
            label: const Text('Choisir un serveur'),
          ),
        ],
      ),
    );
  }

  double _computeTablesTotal(List<Map<String, dynamic>> tables) {
    return tables.fold<double>(
      0.0,
      (sum, table) => sum + ((table['orderTotal'] as num?)?.toDouble() ?? 0.0),
    );
  }

  int _countPendingTables(List<Map<String, dynamic>> tables) {
    return tables.where((table) => ((table['orderTotal'] as num?)?.toDouble() ?? 0.0) > 0).length;
  }

  DateTime? _findOldestOpenedTable(List<Map<String, dynamic>> tables) {
    DateTime? oldest;
    for (final table in tables) {
      dynamic openedAt = table['openedAt'];
      DateTime? parsed;
      if (openedAt is DateTime) {
        parsed = openedAt;
      } else if (openedAt is String) {
        parsed = DateTime.tryParse(openedAt);
      }
      if (parsed != null) {
        if (oldest == null || parsed.isBefore(oldest)) {
          oldest = parsed;
        }
      }
    }
    return oldest;
  }

  String _formatTableCurrency(double value) => '${value.toStringAsFixed(2)} TND';

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  double _calculateTableTotal(OrderNote mainNote, List<OrderNote> subNotes) {
    double total = mainNote.total;
    for (final note in subNotes) {
      total += note.total;
    }
    return total;
  }

  // Dialog pour ajouter une nouvelle table
  void _showAddTableDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const AddTableDialog();
      },
    ).then((result) {
      if (result is Map<String, dynamic>) {
        final tableNumber = (result['number'] ?? '').toString().trim();
        final covers = (result['covers'] as int?) ?? 1;
        if (tableNumber.isEmpty) return;
        // Vérifier unicité
        bool exists = false;
        String existingServer = '';
        for (final serverName in serverTables.keys) {
          final tables = serverTables[serverName]!;
          final existingTable = tables.firstWhere((t) => t['number'] == tableNumber, orElse: () => {});
          if (existingTable.isNotEmpty) {
            exists = true;
            existingServer = serverName;
            break;
          }
        }
        if (exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Table N° $tableNumber existe déjà chez le serveur $existingServer !'), backgroundColor: Colors.red),
          );
          return;
        }
        _addNewTable(tableNumber, covers);
      }
    });
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
    
    final ownerServer = _getActiveServerName();
    setState(() {
      final tables = serverTables[ownerServer] ??= <Map<String, dynamic>>[];
      final newTableId = '${ownerServer}_${tableNumber}_${DateTime.now().millisecondsSinceEpoch}';
      
      tables.add({
        'id': newTableId,
        'number': tableNumber,
        'status': 'occupee',
        'covers': covers,
        'server': ownerServer,
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
    showDialog(context: context, builder: (_) => ReservationDialog(tableNumber: table['number'] as String)).then((action) {
      if (action == 'free') {
        _closeTable(table['id'] as String);
      } else if (action == 'open') {
        _openOrderPageFromTable(table);
      }
    });
  }

  // Dialog de nettoyage des tables vides
  void _showCleanupDialog() {
    final emptyTables = currentServerTables.where((t) => ((t['orderTotal'] as num?)?.toDouble() ?? 0.0) == 0).toList();
    showDialog(context: context, builder: (_) => CleanupEmptyTablesDialog(emptyTables: emptyTables)).then((confirm) {
      if (confirm == true && emptyTables.isNotEmpty) {
        CleanupService.cleanupEmptyTables(
          context: context,
          emptyTables: emptyTables,
          serverTables: serverTables,
          saveTables: _saveTables,
        ).then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString('pos_last_server');
    final name = widget.selectedServer ?? prefs.getString('pos_user_name') ?? last ?? '';
    userRole = prefs.getString('pos_user_role') ?? 'Staff';
    sessionStart = prefs.getString('pos_session_start') ?? DateTime.now().toIso8601String();
    _homeState.setUser(name, userRole);
    // Charger et appliquer les préférences API
    await _apiPrefs.load();
    _apiPrefs.apply();
    // Mettre à jour l'état local
    useCloudApi = _apiPrefs.useCloudApi;
    apiLocalBaseUrl = _apiPrefs.apiLocalBaseUrl;
    apiCloudBaseUrl = _apiPrefs.apiCloudBaseUrl;
    _homeState.setApiMode(_apiPrefs.useCloudApi);
    if (mounted) {
      setState(() {
        _isAdminSession = userRole.toLowerCase() == 'manager' || name.toUpperCase() == 'ADMIN';
        if (!_isAdminSession) {
          _adminViewingServer = null;
        }
      });
    }
  }

  // Charger les tables depuis SharedPreferences
  Future<void> _loadTables() async {
    final loaded = await TablesRepository.loadAll(serverTables);
    setState(() {
      // préserver les clés serveurs existantes, écraser valeurs
      for (final k in loaded.keys) {
        serverTables[k] = loaded[k] ?? [];
      }
    });
    print('[POS] Synchronisation automatique après chargement des tables');
    await _syncOrdersWithTables();
  }


  // Nettoyage déplacé dans LocalStorageService

  // Synchroniser les commandes existantes avec les tables
  // Afficher le dialog de simulation
  void _showSimulationDialog() {
    showDialog(
      context: context,
      builder: (context) => SimulationDialog(
        onRun: (mode) => _runSimulation(mode),
        onReset: _resetSystem,
      ),
    );
  }

  // Test de connexion API
  Future<void> _testApiConnection() async {
    await AdminActions.testApiConnection(context);
  }

  // Exécuter la simulation
  Future<void> _runSimulation(String mode) async {
    await AdminActions.runSimulation(context, mode, _syncOrdersWithTables, _saveTables);
  }

  // 🆕 Remettre à zéro le système
  Future<void> _resetSystem() async {
    await AdminActions.resetSystem(context, LocalStorageService.clearPosCache, () async {
      setState(() {
        serverTables.clear();
        serverTables[_homeState.userName] = [];
      });
      await _loadTables();
      await _syncOrdersWithTables();
    });
  }

  // Nettoyer l'historique des tables (local + serveur)
  Future<void> _clearHistory() async {
    await AdminActions.clearHistory(context, LocalStorageService.clearPosCache, () {
      setState(() {
        serverTables.clear();
        serverTables[_homeState.userName] = [];
      });
    });
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
    await OrdersSyncService.syncOrdersWithTables(serverTables);
    await _saveTables();
    if (mounted) setState(() {});
  }


  // Sauvegarder les tables dans SharedPreferences
  Future<void> _saveTables() async {
    await TablesRepository.saveAll(serverTables);
  }

  void _connectSocket() {
    // ⚠️ IMPORTANT : Éviter les connexions multiples
    // Vérifier si une connexion existe déjà
    if (socket != null) {
      try {
        // Si le socket existe déjà et n'est pas détruit, ne pas reconnecter
        // (socket.io peut ne pas avoir de propriété 'connected' directement accessible)
        print('[POS HOME] Socket déjà existant, nettoyage avant reconnexion');
        _homeSocket.dispose();
        socket = null;
      } catch (e) {
        print('[POS HOME] Erreur lors du nettoyage socket existant: $e');
      }
    }
    
    final base = ApiClient.dio.options.baseUrl;
    final uri = base.replaceAll(RegExp(r"/+$"), '');
    print('[POS HOME] Connexion Socket.IO vers: $uri');
    final s = _homeSocket.connect(uri);
    socket = s;

    // 🚨 🆕 ÉCOUTEUR DE RESET GLOBAL
    // Si le serveur envoie ce signal, on vide tout localement
    socket?.on('system:full_reset', (data) async {
      print('[POS] 🚨 Signal de RESET GLOBAL reçu du serveur !');
      
      // 1. Vider le cache SharedPreferences immédiatement
      await LocalStorageService.clearPosCache();
      
      // 2. Réinitialiser l'état local des tables
      if (mounted) {
        setState(() {
          serverTables.clear();
        });
        
        // 3. Informer l'utilisateur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Le système a été réinitialisé complètement.'),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      
      // 4. Attendre le redémarrage du serveur et synchroniser (état vide)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _loadTables();
          _syncOrdersWithTables();
        }
      });
    });
    
    _homeSocket.bindDefaultHandlers(
      onSync: _syncOrdersWithTables,
      onUiUpdate: () {
        // ⚠️ Vérifier mounted AVANT d'appeler Future.microtask
        // pour éviter même l'appel si le widget est détruit
        if (!mounted) return;
        
        // Utiliser Future.microtask pour éviter setState pendant un build/unmount
        Future.microtask(() {
          // Double vérification dans le microtask
          if (!mounted) return;
          try {
            setState(() {});
          } catch (e) {
            // Ignorer les erreurs si le widget est détruit pendant setState
            print('[POS HOME] Erreur setState dans onUiUpdate (ignorée): $e');
          }
        });
      },
    );
  }

  Future<void> _reconnectSocket() async {
    // ⚠️ IMPORTANT : Nettoyer complètement l'ancienne connexion avant de reconnecter
    // pour éviter les connexions multiples et les listeners dupliqués
    try {
      _homeSocket.dispose(); // Nettoyer via le service (retire les listeners + disconnect)
    } catch (e) {
      print('[POS HOME] Erreur lors du nettoyage socket avant reconnexion: $e');
    }
    try {
      socket?.dispose(); // Nettoyer aussi la référence locale
    } catch (e) {
      print('[POS HOME] Erreur lors du dispose socket local: $e');
    }
    socket = null;
    _connectSocket();
  }

  void _loadApiPrefs() {
    // valeurs par défaut, puis load async
    useCloudApi = _apiPrefs.useCloudApi;
    apiLocalBaseUrl = _apiPrefs.apiLocalBaseUrl;
    apiCloudBaseUrl = _apiPrefs.apiCloudBaseUrl;
    _apiPrefs.apply();
    _homeState.setApiMode(_apiPrefs.useCloudApi);
    _apiPrefs.load().then((_) async {
      setState(() {
        useCloudApi = _apiPrefs.useCloudApi;
        apiLocalBaseUrl = _apiPrefs.apiLocalBaseUrl;
        apiCloudBaseUrl = _apiPrefs.apiCloudBaseUrl;
      });
      _homeState.setApiMode(_apiPrefs.useCloudApi);
      await _reconnectSocket();
      await _syncOrdersWithTables();
    });
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

  void _openOrderPageFromTable(Map<String, dynamic> table, {String initialNoteId = 'main'}) {
    print('[POS] Synchronisation avant ouverture de la page de commande');
    TableActions.openOrderPageFromTable(
      context: context,
      table: table,
      syncOrders: _syncOrdersWithTables,
      userName: _homeState.userName,
      initialNoteId: initialNoteId,
    ).then((_) {
      if (mounted) setState(() {});
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
                HeaderActions(
                  onSimulation: _showSimulationDialog,
                  onAdmin: () => Navigator.of(context).pushNamed('/admin'),
                ),
                const SizedBox(width: 20),
                Expanded(child: HeaderLogoTitle(userName: _homeState.userName)),
                const SizedBox(width: 16),
                const DateTimeBadge(),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _toggleHistory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showHistory ? Colors.orange.shade700 : Colors.purple.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_showHistory ? 'Tables' : 'Historique'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Déconnexion'),
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
                      Icon(
                        _showHistory ? Icons.history : Icons.table_restaurant,
                        size: 32,
                        color: const Color(0xFF2C3E50),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _resolveSectionTitle(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                      ),
                      const Spacer(),
                      if (_isAdminSession && !_showHistory && _adminViewingServer != null) ...[
                        TextButton.icon(
                          onPressed: _returnToAdminOverview,
                          icon: const Icon(Icons.dashboard_customize),
                          label: const Text('Changer de serveur'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (_isAdminSession && !_showHistory && _adminViewingServer == null) ...[
                        TextButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.sync),
                          label: const Text('Actualiser'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (!_showHistory && !_isAdminOverviewVisible()) ...[
                        const SizedBox(width: 16),
                        const TableLegendBar(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Grille de tables OU vue historique
                  Expanded(
                    child: _isAdminOverviewVisible()
                        ? _buildAdminOverview()
                        : _showHistory
                            ? (_needsAdminServerSelectionForHistory()
                                ? _buildAdminHistoryPlaceholder()
                                : HistoryView(
                                    serverName: _getActiveServerName(),
                                    processedTables: _historyController.processedTables,
                                    loading: _historyController.isLoading,
                                  ))
                            : TableGrid(
                                tables: _filteredTables,
                                onAddTable: _showAddTableDialog,
                                onTapTable: _handleTableTap,
                                onLongPressTable: _handleTableLongPress,
                                getTableColor: _getTableColor,
                                getInactivityColor: _getInactivityColor,
                                getElapsedTime: _getElapsedTime,
                                getTimeSinceLastOrder: _getTimeSinceLastOrder,
                              ),
                  ),
                ],
              ),
            ),
          ),

          BottomToolbar(
            onSearch: () {},
            onBills: () {},
            onServerReport: _showServerSalesReport,
          ),
        ],
      ),
    );
  }

  Future<void> _showServerSalesReport() async {
    try {
      _showLoadingDialog();
      await _serverReportController.loadTodayReport(_homeState.userName);
      _hideLoadingDialog();
      if (!mounted) return;

      if (_serverReportController.error != null) {
        _showSnack('Erreur: ${_serverReportController.error}');
        return;
      }

      final kpis = _serverReportController.report;
      if (kpis == null) {
        _showSnack('Aucune donnée disponible.');
        return;
      }

      if (kpis.totalRecette == 0 && kpis.nombreTickets == 0) {
        _showSnack('Aucun encaissement enregistré pour ${_homeState.userName} aujourd\'hui.');
        return;
      }

      await showDialog(
        context: context,
        builder: (_) => ServerSalesReportDialog(
          serverName: _homeState.userName,
          kpis: kpis,
        ),
      );
    } catch (e) {
      _hideLoadingDialog();
      if (!mounted) return;
      _showSnack('Erreur chargement encaissements: $e');
    }
  }

  // 🆕 Basculer entre vue actuelle et historique
  Future<void> _toggleHistory() async {
    if (!_showHistory) {
      if (_isAdminSession && _adminViewingServer == null) {
        setState(() {
          _showHistory = true;
        });
        return;
      }
      final targetServer = _getActiveServerName();
      setState(() {
        _showHistory = true;
      });
      try {
        await _historyController.loadHistory(targetServer);
        if (mounted) setState(() {});
      } catch (e) {
        print('[HISTORY] Erreur chargement historique: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur chargement historique: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      setState(() {
        _showHistory = false;
        _historyController.reset();
      });
    }
  }
  
}

class _TableNotesData {
  final OrderNote mainNote;
  final List<OrderNote> subNotes;

  _TableNotesData({
    required this.mainNote,
    required this.subNotes,
  });
}

class _AdminServerOverviewCard extends StatelessWidget {
  final String serverName;
  final int tableCount;
  final int pendingPayments;
  final String totalAmountLabel;
  final String oldestElapsed;
  final bool enabled;
  final VoidCallback onOpen;

  const _AdminServerOverviewCard({
    required this.serverName,
    required this.tableCount,
    required this.pendingPayments,
    required this.totalAmountLabel,
    required this.oldestElapsed,
    required this.enabled,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueGrey.withOpacity(0.15),
                  foregroundColor: Colors.blueGrey.shade700,
                  child: const Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    serverName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  backgroundColor: Colors.blueGrey.withOpacity(0.1),
                  label: Text('$tableCount table(s)'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AdminOverviewMetric(
                    label: 'Total encours',
                    value: totalAmountLabel,
                    icon: Icons.attach_money,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdminOverviewMetric(
                    label: 'Tables à encaisser',
                    value: pendingPayments.toString(),
                    icon: Icons.warning_amber,
                    highlight: pendingPayments > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AdminOverviewMetric(
              label: 'Table la plus ancienne',
              value: oldestElapsed,
              icon: Icons.timer,
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton.icon(
                onPressed: enabled ? onOpen : null,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ouvrir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminOverviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _AdminOverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? Colors.orange.shade700 : Colors.grey.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? Colors.orange.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}