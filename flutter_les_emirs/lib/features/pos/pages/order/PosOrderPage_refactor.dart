import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:convert';
import '../../../../core/api_client.dart';
import '../../widgets/pos_numpad.dart';
import '../../widgets/pos_menu_grid.dart';
import '../../widgets/pos_note_items.dart';
import '../../pages/payment/PosPaymentPage_refactor.dart';
import '../home/PosHomePage_refactor.dart';
import '../../models/order_note.dart';
import 'widgets/AddNoteDialog.dart';
import 'widgets/ServerSelectionDialog.dart';
import 'widgets/CoversDialog.dart';
import 'widgets/NotesDialog.dart';
import 'widgets/IngredientDialog.dart';
import 'widgets/DebtSettlementDialog.dart';
import 'widgets/DebtPaymentDialog.dart';
import 'widgets/TransferServerDialog.dart';
import 'widgets/TransferDialog.dart';
import 'widgets/TransferToNoteDialog.dart';
import 'widgets/TransferToTableDialog.dart';
import 'widgets/CompleteTableTransferDialog.dart';
import 'widgets/TransferItemsSelectionDialog.dart';
import 'widgets/TableDestinationDialog.dart';
import 'widgets/CreateNoteForTransferDialog.dart';
import 'widgets/CreateTableForNoteTransferDialog.dart';
import 'widgets/CreateTableForTransferDialog.dart';
import 'widgets/CancelItemsDialog.dart';
import 'widgets/pos_order_app_bar.dart';
import 'widgets/pos_order_ticket_panel.dart';
import 'widgets/pos_order_action_panel.dart';
import 'widgets/pos_order_menu_panel.dart';
import 'services/order_repository.dart';
import 'services/order_socket_service.dart';
import 'services/note_actions.dart';
import 'services/transfer_service.dart';
import 'services/payment_service.dart';
import 'services/admin_service.dart';
import 'services/sync_service.dart';
import 'services/local_update_service.dart';
import 'services/cancellation_service.dart';
import 'services/client_order_confirmation_service.dart';
import '../../services/server_permissions_service.dart';
import 'utils/order_helpers.dart';

class PosOrderPage extends StatefulWidget {
  final String? tableNumber;
  final String? tableId;
  final dynamic orderId; // 🆕 Accepte int? (ID officiel) ou String? (tempId pour commandes client)
  final int currentCovers;
  final String currentServer;
  final String initialNoteId;

  const PosOrderPage({
    super.key,
    this.tableNumber,
    this.tableId,
    this.orderId,
    this.currentCovers = 0,
    this.currentServer = '',
    this.initialNoteId = 'main',
  });

  @override
  State<PosOrderPage> createState() => _PosOrderPageState();
}

class _PosOrderPageState extends State<PosOrderPage> {
  final List<Map<String, dynamic>> ticketItems = [];
  int covers = 0;
  String notes = '';
  int? selectedLineIndex;
  Map<String, dynamic>? menu;
  bool loadingMenu = true;
  
  // Gestion serveur
  String selectedServer = '';
  String currentTableNumber = '1';
  String currentTableId = '1';
  
  // 🆕 Gestion des notes (principale + sous-notes)
  OrderNote mainNote = OrderNote(
    id: 'main',
    name: 'Note Principale',
    covers: 1,
    items: [],
    total: 0.0,
  );
  List<OrderNote> subNotes = [];
  late String activeNoteId; // Note actuellement sélectionnée
  
  // 🆕 ID de la commande active (pour les transferts)
  int? activeOrderId;
  
  // 🆕 Suivi des nouveaux articles ajoutés (pour distinction visuelle)
  Set<int> newlyAddedItems = {};
  // 🆕 Suivi du nombre d'articles ajoutés pour chaque item
  Map<int, int> newlyAddedQuantities = {}; // itemId -> quantité ajoutée
  // 🆕 Commandes brutes pour la vue chronologique
  List<Map<String, dynamic>> rawOrders = [];
  bool _sendingOrder = false;
  
  // 🐛 BUG FIX #3 : Quantité en attente pour le numpad (commander plusieurs articles d'un coup)
  int _pendingQuantity = 0;
  
  // 🆕 Commande client en attente de confirmation
  Map<String, dynamic>? _pendingClientOrder;
  bool get hasPendingClientOrder => _pendingClientOrder != null && 
    ClientOrderConfirmationService.canCurrentServerConfirm(_pendingClientOrder!, selectedServer);

  Map<String, bool> _defaultPermissions() => {
        'canTransferNote': true,
        'canTransferTable': true,
        'canTransferServer': true,
        'canCancelItems': true,
        'canEditCovers': true,
        'canOpenDebt': true,
        'canOpenPayment': true,
      };

  bool _hasPermission(String key) => _serverPermissions[key] ?? true;

  bool get canTransferServer => _hasPermission('canTransferServer');
  bool get canTransferNote => _hasPermission('canTransferNote');
  bool get canTransferTable => _hasPermission('canTransferTable');
  bool get canOpenDebt => _hasPermission('canOpenDebt');
  bool get canCancelItems => _hasPermission('canCancelItems');
  bool get canEditCovers => _hasPermission('canEditCovers');
  bool get canOpenPayment => _hasPermission('canOpenPayment');

  void _showPermissionSnack(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature non autorisé pour ce serveur'),
        backgroundColor: Colors.red.shade600,
      ),
    );
  }
  
  // 🆕 Historique des actions pour annulation (undo)
  List<Map<String, dynamic>> actionHistory = [];
  
  // 🆕 Sauvegarder l'état actuel dans l'historique (avant une action)
  void _saveHistoryState(String action) {
    NoteActions.saveHistoryState(
      actionHistory: actionHistory,
      mainNote: mainNote,
      subNotes: subNotes,
      action: action,
    );
  }
  
  // 🆕 Annuler la dernière action (bouton Retour)
  void _undoLastAction() {
    final result = NoteActions.undoLastAction(
      actionHistory: actionHistory,
      context: context,
    );
    
    if (result != null) {
    setState(() {
      // Restaurer la note principale
      mainNote = mainNote.copyWith(
          items: result['mainNoteItems'] as List<OrderNoteItem>,
          total: result['mainNoteTotal'] as double,
      );
      
      // Restaurer les sous-notes
        subNotes = (result['subNotes'] as List<OrderNote>?) ?? [];
      
      // Réinitialiser les articles nouvellement ajoutés
      newlyAddedItems.clear();
      newlyAddedQuantities.clear();
    });
    }
  }
  
  // 🆕 Réinitialiser les nouveaux articles (quand le serveur quitte la table)
  void _resetNewlyAddedItems() {
    NoteActions.resetNewlyAddedItems(
      newlyAddedItems: newlyAddedItems,
      newlyAddedQuantities: newlyAddedQuantities,
    );
    setState(() {}); // Notifier le changement
    print('[POS] Nouveaux articles réinitialisés - table ${currentTableNumber}');
  }
  
  // 🆕 Appelé quand on change de table ou quitte la table
  void onTableExit() {
    _resetNewlyAddedItems();
  }

  Future<void> _executeWithPermission({
    required bool canDo,
    required String featureLabel,
    required Future<void> Function() action,
  }) async {
    if (canDo) {
      await action();
      return;
    }
    final approved = await _requestManagerOverride(featureLabel);
    if (approved) {
      await action();
    }
  }

  Future<bool> _requestManagerOverride(String featureLabel) async {
    if (!mounted) return false;
    final pinController = TextEditingController();
    bool loading = false;
    String? error;

    Future<void> submit(BuildContext dialogContext, void Function(void Function()) setDialogState) async {
      final pin = pinController.text.trim();
      if (pin.isEmpty) {
        setDialogState(() {
          error = 'PIN requis';
        });
        return;
      }
      setDialogState(() {
        loading = true;
        error = null;
      });
      try {
        final profile = await ServerPermissionsService.verifyOverridePin(pin);
        if (!mounted) return;
        Navigator.of(dialogContext).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Autorisation accordée par ${profile['name']}'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      } on DioException catch (e) {
        setDialogState(() {
          loading = false;
          error = (e.response?.data is Map && e.response?.data['error'] is String)
              ? e.response?.data['error']
              : 'PIN invalide';
        });
      } catch (e) {
        setDialogState(() {
          loading = false;
          error = 'Erreur: $e';
        });
      }
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Autorisation requise – $featureLabel'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Un manager doit saisir son PIN pour autoriser cette action.'),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'PIN manager',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  onSubmitted: (_) async {
                    if (!loading) {
                      await submit(dialogContext, setDialogState);
                    }
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        await submit(dialogContext, setDialogState);
                      },
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Autoriser'),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }


  Future<void> _loadServerProfiles() async {
    try {
      final profiles = await ServerPermissionsService.loadServerProfiles();
      if (!mounted) return;
      setState(() {
        servers = profiles;
      });
    } catch (e) {
      print('[POS] Impossible de charger les profils serveurs: $e');
      if (!mounted) return;
      setState(() {
        servers = List<Map<String, dynamic>>.from(_fallbackServers);
      });
    }
  }

  Future<void> _loadServerPermissions(String serverName) async {
    if (serverName.isEmpty) {
      setState(() => _serverPermissions = _defaultPermissions());
      return;
    }
    try {
      final perms = await ServerPermissionsService.loadPermissionsFor(serverName);
      if (!mounted) return;
      setState(() {
        _serverPermissions = perms;
      });
    } catch (e) {
      print('[POS] Impossible de charger les permissions pour $serverName: $e');
      if (!mounted) return;
      setState(() {
        _serverPermissions = _defaultPermissions();
      });
    }
  }
  
  // 🆕 Widget pour afficher les articles de la note avec distinction visuelle
  Widget buildNoteItemsWidget(Function(int, int) onQuantityChanged, Function(int) onItemRemoved) {
    return PosNoteItems(
      note: activeNote,
      newlyAddedItems: newlyAddedItems,
      onQuantityChanged: onQuantityChanged,
      onItemRemoved: onItemRemoved,
    );
  }
  
  // Base de données serveurs
  List<Map<String, dynamic>> servers = [];
  final List<Map<String, dynamic>> _fallbackServers = [
    {'id': 'srv-mohamed', 'name': 'MOHAMED', 'role': 'Serveur'},
    {'id': 'srv-ali', 'name': 'ALI', 'role': 'Serveur'},
    {'id': 'srv-fatima', 'name': 'FATIMA', 'role': 'Serveur'},
    {'id': 'srv-admin', 'name': 'ADMIN', 'role': 'Manager'},
  ];
  Map<String, bool> _serverPermissions = {};
  
  @override
  void initState() {
    super.initState();
    covers = widget.currentCovers;
    if (covers <= 0) {
      covers = 1;
    }
    mainNote = mainNote.copyWith(covers: covers);
    
    // Initialiser les valeurs par défaut
    currentTableNumber = widget.tableNumber ?? '1';
    currentTableId = widget.tableId ?? '1';
    selectedServer = widget.currentServer;
    activeNoteId = widget.initialNoteId;
    servers = List<Map<String, dynamic>>.from(_fallbackServers);
    _serverPermissions = _defaultPermissions();
    _loadServerProfiles();
    if (selectedServer.isNotEmpty) {
      _loadServerPermissions(selectedServer);
    }
    
    // Activer le mode plein écran au démarrage
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    _loadMenu();
    if (widget.orderId != null) _loadExistingOrder();
    
    // 🆕 Écouter les événements Socket.IO pour synchronisation temps réel
    _socketService = OrderSocketService();
    _socketService!.setupSocketListeners(
      tableNumber: currentTableNumber,
      tableId: currentTableId,
      context: context,
      onOrderUpdated: () {
        if (!mounted) return;
        // 🆕 CORRECTION : Délai pour éviter les rechargements multiples rapides
        // Si plusieurs événements arrivent rapidement, on ne recharge qu'une fois
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _loadExistingOrder().catchError((e) {
              // Ignorer les erreurs defunct mais logger les autres
              if (e.toString().contains('defunct')) {
                print('[POS] Widget détruit lors du rechargement après order:updated (ignoré)');
              } else {
                print('[POS] Erreur rechargement après order:updated: $e');
              }
            });
          }
        });
      },
      onOrderArchived: () {
        if (!mounted) return;
        _loadExistingOrder().catchError((e) {
          if (e.toString().contains('defunct')) {
            print('[POS] Widget détruit lors du rechargement après order:archived (ignoré)');
          } else {
            print('[POS] Erreur rechargement après order:archived: $e');
          }
        });
      },
      onOrderNew: () {
        if (!mounted) return;
        // 🆕 CORRECTION : Délai pour éviter les rechargements multiples rapides
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _loadExistingOrder().catchError((e) {
              if (e.toString().contains('defunct')) {
                print('[POS] Widget détruit lors du rechargement après order:new (ignoré)');
              } else {
                print('[POS] Erreur rechargement après order:new: $e');
              }
            });
          }
        });
      },
      onOrderServerConfirmed: () {
        if (!mounted) return;
        // 🆕 CORRECTION : Mise à jour optimiste de l'état local
        // Au lieu de recharger toutes les commandes, on met à jour seulement la commande confirmée
        // Cela évite que les commandes confirmées réapparaissent
        setState(() {
          // Marquer la commande en attente comme confirmée localement
          if (_pendingClientOrder != null) {
            // 🆕 CORRECTION : Utiliser tempId si id est null (commandes client sans ID officiel)
            final orderId = _pendingClientOrder!['id'] ?? _pendingClientOrder!['tempId'] ?? 'sans ID';
            print('[POS] ✅ Mise à jour optimiste: commande $orderId confirmée localement');
            _pendingClientOrder = null; // Retirer de la liste des commandes en attente
          }
        });
        // Recharger seulement après un court délai pour laisser le serveur se synchroniser
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _loadExistingOrder().catchError((e) {
              if (e.toString().contains('defunct')) {
                print('[POS] Widget détruit lors du rechargement après order:server-confirmed (ignoré)');
              } else {
                print('[POS] Erreur rechargement après order:server-confirmed: $e');
              }
            });
          }
        });
      },
      onTableCleared: () {
        if (mounted) {
          // Utiliser Future.microtask pour éviter les problèmes de timing
          Future.microtask(() {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }
      },
      onMenuUpdated: () {
        print('[POS] 🔄 Mise à jour automatique du menu suite au signal socket');
        if (mounted) _loadMenu();
      },
    );
  }
  
  @override
  void dispose() {
    // Fermer le socket service
    _socketService?.dispose();
    
    // Restaurer les contrôles système à la sortie
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadMenu() async {
    final menuData = await OrderRepository.loadMenu();
      setState(() {
      menu = menuData;
        loadingMenu = false;
      });
  }

  Future<void> _loadExistingOrder() async {
    final data = await OrderRepository.loadExistingOrder(currentTableNumber);
    if (data == null) return;
    
    // Vérifier que le widget est encore monté avant setState
    if (!mounted) return;
    
    // Utiliser Future.microtask pour éviter setState pendant un build
    Future.microtask(() {
      if (!mounted) return;
      
      try {
      final fetchedCovers = (data['covers'] as int?) ??
          (widget.currentCovers > 0 ? widget.currentCovers : (covers > 0 ? covers : 1));
      setState(() {
        covers = fetchedCovers;
        mainNote = mainNote.copyWith(
          covers: fetchedCovers,
          items: data['mainItems'] as List<OrderNoteItem>,
          total: (data['mainItems'] as List<OrderNoteItem>).fold<double>(
            0.0,
            (sum, item) => sum + (item.price * item.quantity),
          ),
        );
        subNotes = (data['subNotes'] as List<OrderNote>?) ?? [];
        rawOrders = (data['rawOrders'] as List<Map<String, dynamic>>?) ?? [];
        
        // 🆕 Détecter les commandes client en attente de confirmation
        // 🆕 CORRECTION : Exclure explicitement les commandes confirmées
        _pendingClientOrder = null;
        int pendingCount = 0;
        int confirmedCount = 0;
        
        for (final order in rawOrders) {
          final source = order['source'] as String?;
          final status = order['status'] as String?;
          final serverConfirmed = order['serverConfirmed'] as bool?;
          
          print('[POS] Vérification commande ${order['id']}: source=$source, status=$status, server=${order['server']}, serverConfirmed=$serverConfirmed');
          
          // 🆕 CORRECTION : Les commandes confirmées deviennent source='pos', donc pas besoin de les filtrer
          // Seules les commandes avec source='client' et status='pending_server_confirmation' sont en attente
          // Les commandes confirmées (source='pos') sont traitées comme des commandes normales
          
          // Vérifier si c'est une commande en attente
          if (ClientOrderConfirmationService.isPendingClientOrder(order) &&
              ClientOrderConfirmationService.canCurrentServerConfirm(order, selectedServer)) {
            pendingCount++;
            if (_pendingClientOrder == null) {
              // 🆕 CORRECTION : Afficher tempId si id est null (commandes client sans ID officiel)
              final orderId = order['id'] ?? order['tempId'] ?? 'sans ID';
              print('[POS] ✅ Commande client en attente trouvée: $orderId');
              _pendingClientOrder = order;
            }
          }
        }
        
        print('[POS] 📊 Résumé: ${rawOrders.length} commandes totales, $pendingCount en attente');
        
        if (_pendingClientOrder == null && pendingCount == 0 && rawOrders.isNotEmpty) {
          print('[POS] ℹ️ Aucune commande client en attente trouvée (toutes confirmées ou non-éligibles)');
        }
        
        // 🆕 CORRECTION : Marquer les articles des commandes client comme "nouveaux"
        // pour qu'ils aient le même aspect visuel que les commandes POS
        newlyAddedItems.clear();
        newlyAddedQuantities.clear();
        
        // Parcourir les commandes client en attente pour marquer leurs articles
        for (final order in rawOrders) {
          final source = order['source'] as String?;
          final status = order['status'] as String?;
          final serverConfirmed = order['serverConfirmed'] as bool?;
          
          // Si c'est une commande client en attente de confirmation
          if (source == 'client' && 
              status == 'pending_server_confirmation' && 
              (serverConfirmed == false || serverConfirmed == null)) {
            
            // Marquer les articles de la note principale
            final mainNote = order['mainNote'] as Map<String, dynamic>?;
            if (mainNote != null) {
              final mainItems = (mainNote['items'] as List?) ?? [];
              for (final itemData in mainItems) {
                final itemId = (itemData['id'] as num?)?.toInt();
                final quantity = (itemData['quantity'] as num?)?.toInt() ?? 1;
                if (itemId != null) {
                  newlyAddedItems.add(itemId);
                  newlyAddedQuantities[itemId] = 
                    (newlyAddedQuantities[itemId] ?? 0) + quantity;
                }
              }
            }
            
            // Marquer les articles des sous-notes
            final subNotes = (order['subNotes'] as List?) ?? [];
            for (final subNoteData in subNotes) {
              final subItems = (subNoteData['items'] as List?) ?? [];
              for (final itemData in subItems) {
                final itemId = (itemData['id'] as num?)?.toInt();
                final quantity = (itemData['quantity'] as num?)?.toInt() ?? 1;
                if (itemId != null) {
                  newlyAddedItems.add(itemId);
                  newlyAddedQuantities[itemId] = 
                    (newlyAddedQuantities[itemId] ?? 0) + quantity;
                }
              }
            }
          }
        }
        
          if (data['activeOrderId'] != null) {
            activeOrderId = data['activeOrderId'] as int?;
          print('[POS] Commande active définie: $activeOrderId');
        }

        final noteExists = activeNoteId == 'main' ||
            subNotes.any((note) => note.id == activeNoteId);
        if (!noteExists) {
          activeNoteId = 'main';
        }
      });
      
        print('[POS] Chargement terminé: ${(data['mainItems'] as List).length} items dans note principale, ${(data['subNotes'] as List).length} sous-notes');
    } catch (e) {
        // Ignorer les erreurs defunct ou widget tree locked
        if (e.toString().contains('defunct') || e.toString().contains('locked')) {
          print('[POS] Widget détruit/verrouillé lors de setState dans _loadExistingOrder (ignoré)');
        } else {
          print('[POS] Erreur setState dans _loadExistingOrder: $e');
          rethrow;
        }
      }
    });
  }

  // 🆕 Confirmer une commande client
  Future<void> _confirmClientOrder() async {
    if (_pendingClientOrder == null) return;
    
    // 🆕 CORRECTION : Utiliser tempId si id est null (commandes client sans ID officiel)
    final orderId = _pendingClientOrder!['id'] ?? _pendingClientOrder!['tempId'];
    if (orderId == null) return;
    
    // 🆕 CORRECTION : Mise à jour optimiste immédiate
    // Marquer la commande comme confirmée dans l'état local AVANT l'appel serveur
    // Cela évite qu'elle réapparaisse pendant le traitement
    final pendingOrderId = orderId;
    setState(() {
      _pendingClientOrder = null; // Retirer immédiatement de la liste
      print('[POS] ✅ Mise à jour optimiste: commande $pendingOrderId retirée de la liste des attentes');
    });
    
    // Demander confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la commande client'),
        content: Text(
          'Confirmer la commande #$orderId de la table $currentTableNumber ?\n\n'
          'Cette action validera la commande passée par le client.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    try {
      // Afficher un indicateur de chargement
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      await ClientOrderConfirmationService.confirmClientOrder(
        orderId: orderId,
        serverName: selectedServer,
      );
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Fermer le loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commande client confirmée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 🆕 CORRECTION : Ne pas recharger immédiatement
      // La mise à jour optimiste a déjà été faite, et Socket.IO va notifier
      // On attend un court délai pour laisser Socket.IO mettre à jour
      // Cela évite les rechargements multiples et les commandes qui réapparaissent
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _loadExistingOrder().catchError((e) {
            if (!e.toString().contains('defunct')) {
              print('[POS] Erreur rechargement après confirmation: $e');
            }
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fermer le loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🆕 Obtenir la note active
  OrderNote get activeNote => OrderHelpers.getActiveNote(activeNoteId, mainNote, subNotes);

  // 🆕 Total de toutes les notes
  double get totalAmount => OrderHelpers.calculateTotalAmount(mainNote, subNotes);

  // 🆕 Obtenir la couleur d'une note
  Color getNoteColor(String noteId) => OrderHelpers.getNoteColor(noteId, subNotes);

  // 🆕 Ajouter une sous-note
  void _showAddNoteDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AddNoteDialog(
          onCreateNote: (name, covers) => _createSubNote(name, covers),
        );
      },
    );
  }

  // 🆕 Créer une sous-note
  Future<void> _createSubNote(String name, int noteCovers) async {
    if (activeOrderId == null) return;
    
    final createdNote = await NoteActions.createSubNote(
      activeOrderId: activeOrderId!,
      name: name,
      noteCovers: noteCovers,
      context: context,
    );

    if (createdNote != null) {
        setState(() {
          subNotes.add(createdNote);
          activeNoteId = createdNote.id; // Sélectionner automatiquement la nouvelle note
        }      );
    }
  }

  // 🆕 Décliner une commande client
  Future<void> _declineClientOrder() async {
    if (_pendingClientOrder == null) return;
    
    // 🆕 CORRECTION : Utiliser tempId si id est null (commandes client sans ID officiel)
    final orderId = _pendingClientOrder!['id'] ?? _pendingClientOrder!['tempId'];
    if (orderId == null) return;
    
    // Demander confirmation avec raison optionnelle
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Décliner la commande client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Voulez-vous vraiment décliner cette commande ?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Raison (optionnelle)',
                hintText: 'Ex: Article indisponible',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.of(context).pop(value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Décliner'),
          ),
        ],
      ),
    );
    
    if (reason == null) return; // Annulé par l'utilisateur
    
    // Mise à jour optimiste
    setState(() {
      _pendingClientOrder = null;
    });
    
    try {
      await ClientOrderConfirmationService.declineClientOrder(
        orderId: orderId,
        reason: reason.isEmpty ? null : reason,
        serverName: selectedServer,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande déclinée avec succès'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      // Recharger les commandes
      await _loadExistingOrder();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addItem(Map<String, dynamic> item) {
    // 🆕 Sauvegarder l'état avant d'ajouter un article
    _saveHistoryState('add');
    
    // 🐛 BUG FIX #3 : Utiliser la quantité en attente si définie, sinon 1
    final quantityToAdd = _pendingQuantity > 0 ? _pendingQuantity : 1;
    
    final result = NoteActions.addItem(
      item: item,
      activeNoteId: activeNoteId,
      mainNote: mainNote,
      subNotes: subNotes,
      newlyAddedItems: newlyAddedItems,
      newlyAddedQuantities: newlyAddedQuantities,
      quantity: quantityToAdd, // 🐛 BUG FIX #3 : Passer la quantité personnalisée
    );
    
    setState(() {
      mainNote = result['mainNote'] as OrderNote;
        subNotes = (result['subNotes'] as List<OrderNote>?) ?? [];
      newlyAddedItems = result['newlyAddedItems'] as Set<int>;
      newlyAddedQuantities = result['newlyAddedQuantities'] as Map<int, int>;
      // 🐛 BUG FIX #3 : Réinitialiser la quantité en attente après ajout
      _pendingQuantity = 0;
    });
  }

  void _updateQuantity(int index, int newQty) {
    _saveHistoryState('update');
    
    final result = NoteActions.updateQuantity(
      index: index,
      newQty: newQty,
      activeNoteId: activeNoteId,
      activeNote: activeNote,
      mainNote: mainNote,
      subNotes: subNotes,
      context: context,
    );
    
    if (result != null) {
    setState(() {
        mainNote = result['mainNote'] as OrderNote;
        subNotes = (result['subNotes'] as List<OrderNote>?) ?? [];
      });
    }
  }

  void _deleteLine(int index) {
    _saveHistoryState('delete');
    
    final result = NoteActions.deleteLine(
      index: index,
      activeNoteId: activeNoteId,
      activeNote: activeNote,
      mainNote: mainNote,
      subNotes: subNotes,
      context: context,
    );
    
    if (result != null) {
      setState(() {
        mainNote = result['mainNote'] as OrderNote;
        subNotes = (result['subNotes'] as List<OrderNote>?) ?? [];
        selectedLineIndex = null;
      });
    }
  }

  // 🆕 Organiser les articles disponibles pour annulation (non payés uniquement)
  // ⚠️ IMPORTANT: On doit charger les articles bruts depuis l'API car order_repository modifie les quantités
  // 🆕 Chercher dans TOUTES les commandes de la table (comme pour le transfert)
  Future<List<Map<String, dynamic>>> getOrganizedItemsForCancellation() async {
    try {
      // Charger les commandes brutes depuis l'API
      final response = await ApiClient.dio.get('/orders', queryParameters: {'table': currentTableNumber});
      final orders = (response.data as List).cast<Map<String, dynamic>>();
      
      if (orders.isEmpty) return [];
      
      final items = <Map<String, dynamic>>[];
      
      // Parcourir TOUTES les commandes de la table
      for (final order in orders) {
        final orderId = order['id'] as int;
        
        // Chercher dans la note principale
        final mainNoteData = order['mainNote'] as Map<String, dynamic>?;
        if (mainNoteData != null && activeNoteId == 'main') {
          final noteItems = (mainNoteData['items'] as List?) ?? [];
          for (final itemData in noteItems) {
            final item = itemData as Map<String, dynamic>;
            final totalQty = (item['quantity'] as num?)?.toInt() ?? 0;
            final paidQty = (item['paidQuantity'] as num?)?.toInt() ?? 0;
            final unpaidQty = totalQty - paidQty;
            
            if (unpaidQty > 0) {
              items.add({
                'id': item['id'] as int,
                'name': item['name'] as String,
                'price': (item['price'] as num?)?.toDouble() ?? 0.0,
                'quantity': totalQty, // 🆕 Quantité totale (le serveur utilisera paidQuantity)
                'orderId': orderId, // 🆕 ID de la commande
                'noteId': 'main', // 🆕 ID de la note
              });
            }
          }
        }
        
        // Chercher dans les sous-notes
        if (activeNoteId != 'main') {
          final subNotes = (order['subNotes'] as List?) ?? [];
          for (final subNoteData in subNotes) {
            final subNote = subNoteData as Map<String, dynamic>;
            if (subNote['id'] == activeNoteId) {
              final noteItems = (subNote['items'] as List?) ?? [];
              for (final itemData in noteItems) {
                final item = itemData as Map<String, dynamic>;
                final totalQty = (item['quantity'] as num?)?.toInt() ?? 0;
                final paidQty = (item['paidQuantity'] as num?)?.toInt() ?? 0;
                final unpaidQty = totalQty - paidQty;
                
                if (unpaidQty > 0) {
                  items.add({
                    'id': item['id'] as int,
                    'name': item['name'] as String,
                    'price': (item['price'] as num?)?.toDouble() ?? 0.0,
                    'quantity': totalQty, // 🆕 Quantité totale (le serveur utilisera paidQuantity)
                    'orderId': orderId, // 🆕 ID de la commande
                    'noteId': activeNoteId, // 🆕 ID de la note
                  });
                }
              }
              break; // On a trouvé la sous-note, pas besoin de continuer
            }
          }
        }
      }
      
      return items;
    } catch (e) {
      print('[CANCELLATION] Erreur chargement articles bruts: $e');
      return [];
    }
  }

  Future<void> _showCancelDialog() async {
    if (activeOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune commande active')),
      );
      return;
    }
    if (!canCancelItems) {
      final approved = await _requestManagerOverride('Annulation d\'articles');
      if (!approved) return;
    }

    // Afficher un indicateur de chargement
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final availableItems = await getOrganizedItemsForCancellation();
    
    // Fermer l'indicateur de chargement
    if (mounted) Navigator.pop(context);
    
    if (availableItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun article non payé à annuler')),
        );
      }
        return;
      }
      
    final Map<int, int> selectedQuantities = {};
    final Map<int, bool> selectedItems = {};

    showDialog(
      context: context,
      builder: (_) => CancelItemsDialog(
        availableItems: availableItems,
        selectedQuantities: selectedQuantities,
        onQuantityChanged: (itemId, quantity) {
          selectedQuantities[itemId] = quantity;
        },
        onToggleItem: (itemId) {
          if (selectedItems.containsKey(itemId)) {
            selectedItems.remove(itemId);
            selectedQuantities.remove(itemId);
      } else {
            selectedItems[itemId] = true;
            final item = availableItems.firstWhere((i) => i['id'] == itemId);
            selectedQuantities[itemId] = 1;
          }
        },
        onConfirm: (cancellationData) async {
          Navigator.pop(context);
          
          try {
            // Afficher un indicateur de chargement
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(child: CircularProgressIndicator()),
            );

            // Appeler l'API d'annulation pour chaque article (peut être dans différentes commandes)
            final itemsToCancel = cancellationData['items'] as List<Map<String, dynamic>>;
            final cancellationDetails = cancellationData['cancellationDetails'] as Map<String, dynamic>;
            
            // 🆕 Grouper les articles par orderId/noteId pour faire un appel par commande/note
            final Map<String, List<Map<String, dynamic>>> itemsByOrderNote = {};
            
            for (final item in itemsToCancel) {
              final orderId = item['orderId'] as int? ?? activeOrderId!;
              final noteId = item['noteId'] as String? ?? activeNoteId;
              final key = '${orderId}_$noteId';
              
              if (!itemsByOrderNote.containsKey(key)) {
                itemsByOrderNote[key] = [];
              }
              
              // Enlever orderId et noteId de l'item avant l'envoi (le serveur les a déjà dans l'URL)
              itemsByOrderNote[key]!.add({
                'id': item['id'],
                'name': item['name'],
                'price': item['price'],
                'quantity': item['quantity'],
              });
            }
            
            // Appeler l'API pour chaque groupe
            for (final entry in itemsByOrderNote.entries) {
              final parts = entry.key.split('_');
              final orderId = int.parse(parts[0]);
              final noteId = parts[1];
              
              print('[CANCELLATION] Envoi annulation: orderId=$orderId, noteId=$noteId');
              print('[CANCELLATION] Articles: ${entry.value}');
              print('[CANCELLATION] Détails: $cancellationDetails');
              
              await CancellationService.cancelItems(
                orderId: orderId,
                noteId: noteId,
                items: entry.value,
                cancellationDetails: cancellationDetails,
              );
            }

            // Fermer l'indicateur de chargement
            if (mounted) Navigator.pop(context);

            // Recharger les commandes
            await _loadExistingOrder();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Articles annulés avec succès'),
            backgroundColor: Colors.green,
          ),
        );
            }
          } catch (e) {
            // Fermer l'indicateur de chargement
            if (mounted) Navigator.pop(context);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur lors de l\'annulation: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _sendToKitchen() async {
    if (_sendingOrder) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commande déjà en cours d\'envoi...')),
        );
      }
      return;
    }

    setState(() {
      _sendingOrder = true;
    });

    try {
      final newOrderId = await TransferService.sendToKitchen(
        selectedServer: selectedServer,
        currentTableNumber: currentTableNumber,
        currentTableId: currentTableId,
        activeNoteId: activeNoteId,
        activeNote: activeNote,
        subNotes: subNotes,
        newlyAddedItems: newlyAddedItems,
        newlyAddedQuantities: newlyAddedQuantities,
        activeOrderId: activeOrderId,
        notes: notes,
        context: context,
        covers: covers,
      );

      if (newOrderId != null) {
        // Sauvegarder l'orderId dans la table
        await OrderRepository.saveOrderIdToTable(
          orderId: newOrderId,
          tableId: currentTableId,
          tableNumber: currentTableNumber,
          mainNote: mainNote,
          subNotes: subNotes,
          totalAmount: totalAmount,
          covers: covers,
          ticketItems: ticketItems,
        );

        if (mounted) {
          // Vider la note active après envoi
          setState(() {
            newlyAddedItems.clear();
            newlyAddedQuantities.clear();
            actionHistory.clear();
            
            if (activeNoteId == 'main') {
              mainNote = mainNote.copyWith(items: [], total: 0.0);
            } else {
              final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
              if (noteIndex != -1) {
                subNotes[noteIndex] = subNotes[noteIndex].copyWith(items: [], total: 0.0);
              }
            }
          });
          
          // Recharger les données pour mettre à jour l'interface
          await _loadExistingOrder();
          
          // Retourner automatiquement au plan de salle
          Navigator.of(context).pop();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _sendingOrder = false;
        });
      } else {
        _sendingOrder = false;
      }
    }
  }



  void _showServerSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => ServerSelectionDialog(
        servers: servers.isEmpty ? _fallbackServers : servers,
        onServerSelected: (server) {
                setState(() {
            selectedServer = server;
                });
          _loadServerPermissions(server);
                _openTablePlan();
              },
      ),
    );
  }

  void _openTablePlan() {
    // Navigation vers le plan de salle (PosHomePage) avec le serveur sélectionné
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PosHomePage(selectedServer: selectedServer),
      ),
    );
  }

  void _openPayment() async {
    if (!canOpenPayment) {
      _showPermissionSnack('Accès à la caisse');
      return;
    }
    final allOrders = await PaymentService.getAllOrdersForTable(currentTableNumber);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PosPaymentPage(
          tableNumber: currentTableNumber,
          tableId: currentTableId,
          items: activeNote.items.map((item) => {
            'id': item.id,
            'name': item.name,
            'price': item.price,
            'quantity': item.quantity,
          }).toList(),
          total: totalAmount,
          covers: covers,
        currentServer: selectedServer,
          mainNote: mainNote,
          subNotes: subNotes,
          activeNoteId: activeNoteId,
          allOrders: allOrders,
        ),
      ),
    ).then((result) async {
      if (result != null && result['force_refresh'] == true) {
        print('[POS] Rechargement forcé après paiement');
        
        PaymentService.updateDataOptimistically(
          paymentResult: result,
          context: context,
          setState: setState,
          getMainNote: () => mainNote,
          setMainNote: (note) => mainNote = note,
          getSubNotes: () => subNotes,
          setSubNotes: (notes) => subNotes = notes,
          getActiveNoteId: () => activeNoteId,
          setActiveNoteId: (id) => activeNoteId = id,
          loadExistingOrder: _loadExistingOrder,
        );
        
        final paymentType = result['payment_type'] as String?;
        final stayInPos = result['stay_in_pos'] as bool? ?? false;
        
        if (paymentType == 'all' || !stayInPos) {
          print('[POS] Paiement complet, retour au plan de table');
          await SyncService.forceTableSync();
          Navigator.of(context).pop();
        }
      }
    });
  }


  // 🆕 Socket.IO pour synchronisation temps réel
  OrderSocketService? _socketService;

  // 🆕 Dialog de transfert d'articles entre notes
  Future<void> _showTransferDialog() async {
    if (activeNote.items.isEmpty) return;
    await _executeWithPermission(
      canDo: canTransferNote,
      featureLabel: 'Transfert vers une autre note',
      action: () async {
        await showDialog(
      context: context,
      builder: (_) => TransferDialog(
        activeNote: activeNote,
        activeNoteId: activeNoteId,
        onTransfer: (selectedItems) => _showTransferToNoteDialog(selectedItems),
      ),
        );
      },
    );
  }

  void _showTransferToNoteDialog(Map<int, int> selectedItems) {
    showDialog(
      context: context,
      builder: (_) => TransferToNoteDialog(
        selectedItems: selectedItems,
        activeNoteId: activeNoteId,
        activeOrderId: activeOrderId,
        mainNote: mainNote,
        subNotes: subNotes,
        getNoteColor: getNoteColor,
        onTransferToNote: (noteId, items, targetOrderId) => _executeTransferToNote(noteId, items, targetOrderId: targetOrderId),
        onCreateNewNote: () => _showCreateNoteForTransferDialog(selectedItems),
      ),
    );
  }

  Future<void> _showTransferToTableDialog() async {
    if (totalAmount == 0) return;
    await _executeWithPermission(
      canDo: canTransferTable,
      featureLabel: 'Transfert vers une autre table',
      action: () async {
        await showDialog(
      context: context,
      builder: (_) => TransferToTableDialog(
        totalAmount: totalAmount,
        subNotesCount: subNotes.length,
        currentTableNumber: currentTableNumber,
        onTransferCompleteTable: () => _showCompleteTableTransferDialog(),
        onTransferSpecificItems: () => _showTransferItemsSelectionDialog(),
      ),
        );
      },
    );
  }

  // 🆕 Dialog de sélection d'articles pour transfert
  void _showTransferItemsSelectionDialog() {
    if (activeNote.items.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (_) => TransferItemsSelectionDialog(
        activeNote: activeNote,
        activeNoteId: activeNoteId,
        onItemsSelected: (selectedItems) => _showTableDestinationDialog(selectedItems),
      ),
    );
  }

  // 🆕 Dialog pour choisir la table de destination
  void _showTableDestinationDialog(Map<int, int> selectedItems) {
    showDialog(
      context: context,
      builder: (_) => TableDestinationDialog(
        selectedItems: selectedItems,
        currentTableNumber: currentTableNumber,
        activeNoteId: activeNoteId,
        activeNote: activeNote,
        getAvailableTables: _getAvailableTables,
        onTransferToTable: (tableNumber, items, createTable) => _executeTransferToTable(tableNumber, items, createTable),
        onCreateTableForTransfer: (items) => _showCreateTableForTransferDialog(items),
        onCreateTableForNoteTransfer: (items) => _showCreateTableForNoteTransferDialog(items),
      ),
    );
  }

  // 🆕 Récupérer les tables disponibles
  Future<List<Map<String, dynamic>>> _getAvailableTables() async {
    return await TransferService.getAvailableTables(
      currentTableNumber: currentTableNumber,
    );
  }

  // 🆕 Dialog pour créer une nouvelle note lors du transfert
  void _showCreateNoteForTransferDialog(Map<int, int> selectedItems) {
    showDialog(
      context: context,
      builder: (_) => CreateNoteForTransferDialog(
        selectedItems: selectedItems,
        onCreateNote: (name, covers, items) => _createNoteAndTransfer(name, covers, items),
      ),
    );
  }

  // 🆕 Dialog pour créer une nouvelle table avec note séparée (transfert de sous-note)
  void _showCreateTableForNoteTransferDialog(Map<int, int> selectedItems) {
    showDialog(
      context: context,
      builder: (_) => CreateTableForNoteTransferDialog(
        noteName: activeNote.name,
        selectedItems: selectedItems,
        onCreateTable: (tableNumber, covers, items) => _executeTransferToTable(
                  tableNumber, 
          items,
          true,
                  covers: covers,
          clientName: activeNote.name,
        ),
      ),
    );
  }

  // 🆕 Dialog pour créer une nouvelle table lors du transfert
  void _showCreateTableForTransferDialog(Map<int, int> selectedItems) {
    showDialog(
      context: context,
      builder: (_) => CreateTableForTransferDialog(
        selectedItems: selectedItems,
        onCreateTable: (tableNumber, covers, clientName, items) => _executeTransferToTable(
          tableNumber,
          items,
          true,
          covers: covers,
          clientName: clientName ?? '',
        ),
      ),
    );
  }

  // 🆕 Exécuter le transfert vers une note
  Future<void> _executeTransferToNote(String targetNoteId, Map<int, int> selectedItems, {int? targetOrderId}) async {
    // Synchronisation avant transfert si nécessaire
      if (targetNoteId != 'main') {
        await _loadExistingOrder();
      }
      
    final success = await TransferService.executeTransferToNote(
      targetNoteId: targetNoteId,
      targetNoteOrderId: targetOrderId,
      selectedItems: selectedItems,
      currentTableNumber: currentTableNumber,
      activeOrderId: activeOrderId,
      activeNoteId: activeNoteId,
      activeNote: activeNote,
      subNotes: subNotes,
      context: context,
    );
    
    if (success) {
      LocalUpdateService.updateAfterTransferToNote(
        selectedItems: selectedItems,
        activeNote: activeNote,
        activeNoteId: activeNoteId,
        getMainNote: () => mainNote,
        setMainNote: (note) => mainNote = note,
        getSubNotes: () => subNotes,
        setSubNotes: (notes) => subNotes = notes,
        setState: setState,
      );
      
        await _loadExistingOrder();
    }
  }

  // 🆕 Exécuter le transfert vers une table
  Future<void> _executeTransferToTable(String targetTable, Map<int, int> selectedItems, bool createTable, {int covers = 1, String clientName = ''}) async {
      await _loadExistingOrder();
    
    final success = await TransferService.executeTransferToTable(
      targetTable: targetTable,
      selectedItems: selectedItems,
      createTable: createTable,
      currentTableNumber: currentTableNumber,
      activeOrderId: activeOrderId,
      activeNoteId: activeNoteId,
      activeNote: activeNote,
      covers: covers,
      clientName: clientName,
      context: context,
    );
    
    if (success) {
        await _loadExistingOrder();
        
        final noteStillExists = activeNoteId == 'main' || 
          subNotes.any((note) => note.id == activeNoteId);
        
        if (!noteStillExists) {
          setState(() {
            activeNoteId = 'main';
          });
      }
    }
  }

  // 🆕 Nettoyer les doublons de sous-notes
  Future<void> _cleanupDuplicates() async {
    await AdminService.cleanupDuplicates(
      currentTableNumber: currentTableNumber,
      context: context,
      loadExistingOrder: _loadExistingOrder,
    );
  }

  // 🆕 Transférer des articles directement (pour nouvelles notes)
  Future<void> _transferItemsDirectly(String targetNoteId, Map<int, int> selectedItems) async {
    final success = await TransferService.transferItemsDirectly(
      targetNoteId: targetNoteId,
      selectedItems: selectedItems,
      currentTableNumber: currentTableNumber,
      activeOrderId: activeOrderId,
      activeNoteId: activeNoteId,
      activeNote: activeNote,
      context: context,
    );
    
    if (success) {
      LocalUpdateService.updateAfterDirectTransfer(
        selectedItems: selectedItems,
        activeNote: activeNote,
        activeNoteId: activeNoteId,
        getMainNote: () => mainNote,
        setMainNote: (note) => mainNote = note,
        getSubNotes: () => subNotes,
        setSubNotes: (notes) => subNotes = notes,
        setState: setState,
      );
    }
  }

  // 🆕 Créer une note et transférer
  Future<void> _createNoteAndTransfer(String name, int covers, Map<int, int> selectedItems) async {
    if (activeOrderId == null) return;
    
    final createdNote = await TransferService.createNoteAndTransfer(
      activeOrderId: activeOrderId!,
      name: name,
      covers: covers,
      selectedItems: selectedItems,
      currentTableNumber: currentTableNumber,
      activeNoteId: activeNoteId,
      activeNote: activeNote,
      context: context,
    );
    
    if (createdNote != null) {
      setState(() {
        subNotes.add(createdNote);
        activeNoteId = createdNote.id;
      });

      LocalUpdateService.updateAfterCreateNoteAndTransfer(
        selectedItems: selectedItems,
        activeNote: activeNote,
        activeNoteId: activeNoteId,
        getMainNote: () => mainNote,
        setMainNote: (note) => mainNote = note,
        getSubNotes: () => subNotes,
        setSubNotes: (notes) => subNotes = notes,
        setState: setState,
      );
      
      await _loadExistingOrder();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECF0F1),
      appBar: PosOrderAppBar(
        selectedServer: selectedServer,
        activeNoteId: activeNoteId,
        subNotes: subNotes,
        getNoteColor: getNoteColor,
        onShowAddNoteDialog: _showAddNoteDialog,
        onShowServerSelectionDialog: _showServerSelectionDialog,
        onBack: () => Navigator.of(context).pop(),
        onShowCoversDialog: canEditCovers ? _showCoversDialog : null,
        onShowNotesDialog: _showNotesDialog,
        onNoteSelected: (noteId) => setState(() => activeNoteId = noteId),
        onConfirmClientOrder: hasPendingClientOrder ? _confirmClientOrder : null, // 🆕
        onDeclineClientOrder: hasPendingClientOrder ? _declineClientOrder : null, // 🆕
        hasPendingClientOrder: hasPendingClientOrder, // 🆕
      ),
      body: Row(
        children: [
          PosOrderTicketPanel(
            currentTableNumber: currentTableNumber,
            covers: covers,
            selectedServer: selectedServer,
            activeNote: activeNote,
            totalAmount: totalAmount,
            selectedLineIndex: selectedLineIndex,
            newlyAddedItems: newlyAddedItems,
            newlyAddedQuantities: newlyAddedQuantities,
            onItemSelected: (index) => setState(() => selectedLineIndex = index),
            activeNoteId: activeNoteId,
            subNotes: subNotes,
            getNoteColor: getNoteColor,
            onNoteSelected: (noteId) => setState(() => activeNoteId = noteId),
            onShowAddNoteDialog: _showAddNoteDialog,
            rawOrders: rawOrders,
            pendingQuantity: _pendingQuantity > 0 && selectedLineIndex == null ? _pendingQuantity : null, // 🆕 Passer la quantité en attente
          ),
          PosOrderActionPanel(
            activeNote: activeNote,
            selectedLineIndex: selectedLineIndex,
            onSendToKitchen: _sendToKitchen,
            sendingOrder: _sendingOrder,
                      onNumberPressed: (num) {
                        if (selectedLineIndex != null) {
                          // Si une ligne est sélectionnée, modifier sa quantité
                          _updateQuantity(selectedLineIndex!, num);
                        } else {
                          // 🐛 BUG FIX #3 : Si aucune ligne sélectionnée, accumuler pour la prochaine commande
                          setState(() {
                            _pendingQuantity = _pendingQuantity * 10 + num;
                            // Limiter à 999 pour éviter les nombres trop grands
                            if (_pendingQuantity > 999) {
                              _pendingQuantity = 999;
                            }
                          });
                        }
                      },
                      onClear: () {
                        if (selectedLineIndex != null) {
                          _deleteLine(selectedLineIndex!);
                        } else {
                          // 🐛 BUG FIX #3 : Effacer la quantité en attente si aucune ligne sélectionnée
                          setState(() {
                            _pendingQuantity = 0;
                          });
                        }
                      },
            onCancel: _showCancelDialog,
            onNote: _showNotesDialog,
            onIngredient: _showIngredientDialog,
            onBack: _undoLastAction,
            onShowTransferServerDialog: _showTransferServerDialog,
            onOpenDebtSettlement: _openDebtSettlement,
            onShowTransferDialog: _showTransferDialog,
            onShowTransferToTableDialog: _showTransferToTableDialog,
            onOpenPayment: _openPayment,
            pendingQuantity: _pendingQuantity > 0 && selectedLineIndex == null ? _pendingQuantity : null, // 🐛 BUG FIX #3 : Passer la quantité en attente
          ),
          const SizedBox(width: 16),
          PosOrderMenuPanel(
            loadingMenu: loadingMenu,
            menu: menu,
                        onItemSelected: _addItem,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.all(4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showCoversDialog() {
    if (!canEditCovers) {
      _showPermissionSnack('Modification des couverts');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => CoversDialog(
        currentCovers: covers,
        onCoversChanged: (newCovers) {
          setState(() {
            covers = newCovers;
            mainNote = mainNote.copyWith(covers: newCovers);
          });
        },
      ),
    );
  }

  void _showNotesDialog() {
    showDialog(
      context: context,
      builder: (_) => NotesDialog(
        currentNotes: notes,
        onNotesChanged: (newNotes) {
          setState(() => notes = newNotes);
        },
      ),
    );
  }

  void _showIngredientDialog() {
    if (selectedLineIndex == null) return;
    final item = ticketItems[selectedLineIndex!];
    showDialog(
      context: context,
      builder: (_) => IngredientDialog(
        itemName: item['name'] as String,
      ),
    );
  }

  // 🆕 Dialog pour transfert COMPLET de table
  void _showCompleteTableTransferDialog() {
    showDialog(
      context: context,
      builder: (_) => CompleteTableTransferDialog(
        currentTableNumber: currentTableNumber,
        subNotesCount: subNotes.length,
        totalAmount: totalAmount,
        covers: covers,
        getAvailableTables: _getAvailableTables,
        onTransfer: (targetTable, createTable, {int covers = 1}) => _executeCompleteTableTransfer(targetTable, createTable, covers: covers),
      ),
    );
  }

  // 🆕 Exécuter le transfert complet de table
  Future<void> _executeCompleteTableTransfer(String targetTable, bool createTable, {int covers = 1}) async {
    final success = await TransferService.executeCompleteTableTransfer(
      targetTable: targetTable,
      createTable: createTable,
      currentTableNumber: currentTableNumber,
      selectedServer: selectedServer,
      covers: covers,
      context: context,
    );
    
    if (success) {
        Navigator.of(context).pop();
    }
  }

  // 🆕 Dialog de transfert serveur
  Future<void> _showTransferServerDialog() async {
    await _executeWithPermission(
      canDo: canTransferServer,
      featureLabel: 'Transfert de serveur',
      action: () async {
        await showDialog(
      context: context,
      builder: (context) => TransferServerDialog(
        currentServer: selectedServer,
        currentTable: currentTableNumber,
        onTransfer: _executeServerTransfer,
      ),
        );
      },
    );
  }

  // 🆕 Ouvrir le règlement des dettes (global, hors contexte table)
  Future<void> _openDebtSettlement() async {
    await _executeWithPermission(
      canDo: canOpenDebt,
      featureLabel: 'Règlement des dettes',
      action: () async {
        await showDialog(
      context: context,
      builder: (context) => DebtSettlementDialog(currentServer: selectedServer),
        );
      },
    );
  }
  
  // 🆕 Exécuter le transfert serveur (reste dans l'écran commande)
  Future<void> _executeServerTransfer(String targetServer, List<String> tablesToTransfer) async {
    final success = await TransferService.executeServerTransfer(
      targetServer: targetServer,
      tablesToTransfer: tablesToTransfer,
      currentTableNumber: currentTableNumber,
                                        context: context,
    );
    
    if (success && tablesToTransfer.contains(currentTableNumber)) {
      Navigator.of(context).pop();
    }
  }
}

// 🆕 Classe pour l'historique des actions (annulation)
class _OrderHistoryState {
  final List<OrderNoteItem> mainNoteItems;
  final List<OrderNote> subNotes;
  final double mainNoteTotal;
  final String action; // "add", "update", "delete"
  
  _OrderHistoryState({
    required this.mainNoteItems,
    required this.subNotes,
    required this.mainNoteTotal,
    required this.action,
  });
}

