import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/api_client.dart';
import '../../pos_invoice_viewer_page.dart';
import '../../models/order_note.dart';
import 'widgets/CreditClientDialog.dart';
import 'widgets/SplitPaymentDialog.dart';
import 'widgets/ClientHistoryPage.dart';
import 'widgets/InvoicePreviewDialog.dart';
import 'widgets/InvoiceForm.dart';
import 'widgets/PartialPaymentDialog.dart';
import 'widgets/NoteSelectionSection.dart';
import 'widgets/ItemsDetailSection.dart';
import 'widgets/TotalsSection.dart';
import 'widgets/DiscountSection.dart';
import 'widgets/PaymentModesSection.dart';
import 'widgets/PaymentSection.dart';
import 'widgets/TicketPreviewDialog.dart';
import 'widgets/PaymentAppBar.dart';
import 'widgets/PaymentLeftPanel.dart';
import 'widgets/PaymentSummaryDialog.dart';
import 'services/payment_service.dart';
import '../order/services/payment_service.dart' as OrderPaymentService;
import 'utils/item_organizer.dart';
import 'utils/payment_calculator.dart';
import 'services/payment_validation_service.dart';
import '../../widgets/virtual_keyboard/virtual_keyboard.dart';

class PosPaymentPage extends StatefulWidget {
  final String tableNumber;
  final String tableId;
  final List<Map<String, dynamic>> items;
  final double total;
  final int covers;
  final String currentServer;
  // 🆕 Nouveaux paramètres pour les sous-notes
  final OrderNote mainNote;
  final List<OrderNote> subNotes;
  final String? activeNoteId;
  // 🆕 Nouveau : toutes les commandes de la table (pour payer des articles de plusieurs commandes)
  final List<Map<String, dynamic>>? allOrders;

  const PosPaymentPage({
    super.key,
    required this.tableNumber,
    required this.tableId,
    required this.items,
    required this.total,
    required this.covers,
    required this.currentServer,
    // 🆕 Nouveaux paramètres
    required this.mainNote,
    required this.subNotes,
    this.activeNoteId,
    this.allOrders, // 🆕 Optionnel : toutes les commandes si disponible
  });

  @override
  State<PosPaymentPage> createState() => _PosPaymentPageState();
}

class _PosPaymentPageState extends State<PosPaymentPage> {
  String selectedPaymentMode = 'ESPECE';
  double discount = 0;
  bool isPercentDiscount = false;
  bool needsInvoice = false;
  int covers = 1;
  
  // 🆕 Gestion des sous-notes et paiement partiel
  String selectedNoteForPayment = 'all'; // 'all', 'main', ou ID de sous-note
  Map<String, double> notePayments = {}; // noteId -> montant payé
  Map<String, String> notePaymentModes = {}; // noteId -> mode de paiement
  
  // 🆕 Gestion du paiement divisé
  bool isSplitPayment = false;
  Map<String, double> splitPayments = {}; // mode -> montant
  Map<String, int>? splitCreditClients = null; // mode -> clientId (pour CREDIT)
  Map<String, String>? splitCreditClientNames = null; // mode -> nom du client (pour CREDIT)
  
  // 🆕 Protection contre les doubles clics
  bool _isProcessingPayment = false;
  
  // 🆕 État local pour allOrders (peut être mis à jour après paiement)
  List<Map<String, dynamic>>? _currentAllOrders;
  
  // 🆕 Nom du client pour justifier la remise (optionnel)
  String? discountClientName;
  
  // Infos facture
  String companyName = '';
  String companyAddress = '';
  String companyPhone = '';
  String companyEmail = '';
  String taxNumber = '';
  
  // Couleurs pour les notes (cohérentes avec pos_order_page.dart)
  final List<Color> noteColors = [
    const Color(0xFF2196F3), // Bleu (principale)
    const Color(0xFF4CAF50), // Vert
    const Color(0xFFFF9800), // Orange
    const Color(0xFF9C27B0), // Violet
    const Color(0xFFE91E63), // Rose
    const Color(0xFF00BCD4), // Cyan
  ];
  
  @override
  void initState() {
    super.initState();
    covers = widget.covers;
    
    // 🆕 Initialiser allOrders depuis widget
    _currentAllOrders = widget.allOrders;
    
    // 🆕 Initialiser les paiements par note
    _initializeNotePayments();
    
    // 🆕 Préremplir discountClientName avec le nom de la note (principale ou sous-note)
    if (widget.activeNoteId != null && widget.activeNoteId != 'all') {
      final activeNote = widget.activeNoteId == 'main'
        ? widget.mainNote
        : widget.subNotes.firstWhere(
            (note) => note.id == widget.activeNoteId,
            orElse: () => widget.mainNote,
          );

      // 🆕 CORRECTION : Utiliser le nom de la note si c'est un client spécifique (pas "Note Principale")
      if (activeNote.name != 'Note Principale' && activeNote.name.isNotEmpty) {
        discountClientName = activeNote.name;
      }
    }
  }
  
  // 🆕 Initialiser les paiements par note
  void _initializeNotePayments() {
    notePayments.clear();
    notePaymentModes.clear();
    
    // Paiement global par défaut
    notePayments['all'] = widget.total;
    notePaymentModes['all'] = selectedPaymentMode;
    
    // Paiements individuels des sous-notes
    for (final note in widget.subNotes) {
      if (!note.paid) {
        notePayments[note.id] = note.total;
        notePaymentModes[note.id] = selectedPaymentMode;
      }
    }
  }
  
  // 🆕 Obtenir la note sélectionnée
  OrderNote? get selectedNote {
    if (selectedNoteForPayment == 'all') return null;
    if (selectedNoteForPayment == 'main') return widget.mainNote;
    return widget.subNotes.firstWhere(
      (note) => note.id == selectedNoteForPayment,
      orElse: () => widget.mainNote,
    );
  }
  
  // 🆕 Obtenir le total à payer selon la sélection
  // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utilise organizedItemsForPartialPayment et getAllItemsOrganized
  double get paymentTotal {
    return PaymentCalculator.calculatePaymentTotal(
      selectedNoteForPayment: selectedNoteForPayment,
      mainNote: widget.mainNote, // ⚠️ Conservé pour compatibilité mais non utilisé pour les calculs
      subNotes: widget.subNotes, // ⚠️ Conservé pour compatibilité mais non utilisé pour les calculs
      selectedPartialQuantities: selectedPartialQuantities,
      organizedItemsForPartialPayment: organizedItemsForPartialPayment, // 🆕 Source de vérité pour 'main' et 'partial'
      getAllItemsOrganized: getAllItemsOrganized, // 🆕 Source de vérité pour 'all' et sous-notes
    );
  }
  
  // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour "Tout payer" (toujours calculé depuis getAllItemsOrganized)
  double get totalForAll {
    final allItems = _getAllItemsOrganized();
    return allItems.fold(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      return sum + (price * quantity);
    });
  }
  
  // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour la note principale (toujours calculé depuis organizedItemsForPartialPayment)
  double get totalForMain {
    return organizedItemsForPartialPayment.fold(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      int quantity = 0;
      
      final sources = item['sources'] as List?;
      if (sources != null && sources.isNotEmpty) {
        quantity = sources
            .where((s) => (s as Map<String, dynamic>)['noteId'] == 'main' || s['noteId'] == null)
            .fold<int>(0, (s, src) => s + ((src as Map<String, dynamic>)['quantity'] as int? ?? 0));
      } else {
        quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      }
      return sum + (price * quantity);
    });
  }
  
  // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour le paiement partiel (calculé depuis selectedPartialQuantities)
  double get totalForPartial {
    if (selectedPartialQuantities.isEmpty) return 0.0;
    return selectedPartialQuantities.entries.fold(0.0, (sum, entry) {
      final itemId = entry.key;
      final quantity = entry.value;
      final item = organizedItemsForPartialPayment.firstWhere(
        (it) => it['id'] == itemId,
        orElse: () => {'price': 0.0},
      );
      return sum + ((item['price'] as num).toDouble() * quantity);
    });
  }
  
  double get finalTotal {
    return PaymentCalculator.calculateFinalTotal(
      paymentTotal: paymentTotal,
      discount: discount,
      isPercentDiscount: isPercentDiscount,
    );
  }
  
  double get amountPerPerson {
    final effectiveCovers = selectedNoteForPayment == 'partial' 
        ? widget.mainNote.covers 
        : covers;
    return PaymentCalculator.calculateAmountPerPerson(
      finalTotal: finalTotal,
      covers: effectiveCovers,
    );
  }
  
  /// Vérifie si le paiement peut être validé
  bool get isPaymentValid {
    print('[PAYMENT] 🔍 isPaymentValid - Début validation');
    print('[PAYMENT] 🔍 finalTotal: $finalTotal');
    print('[PAYMENT] 🔍 isSplitPayment: $isSplitPayment');
    
    // Montant doit être > 0
    if (finalTotal <= 0) {
      print('[PAYMENT] 🔍 ❌ finalTotal <= 0');
      return false;
    }
    
    // 🆕 Si paiement divisé, valider les montants divisés
    if (isSplitPayment) {
      print('[PAYMENT] 🔍 Validation paiement divisé');
      // 🆕 Utiliser _splitPaymentTransactions si disponible (nouveau format)
      if (_splitPaymentTransactions != null && _splitPaymentTransactions!.isNotEmpty) {
        print('[PAYMENT] 🔍 splitPaymentTransactions.length: ${_splitPaymentTransactions!.length}');
        if (_splitPaymentTransactions!.length < 1) {
          print('[PAYMENT] 🔍 ❌ Aucune transaction');
          return false;
        }
        final totalSplit = _splitPaymentTransactions!.fold<double>(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
        final difference = totalSplit - finalTotal;
        print('[PAYMENT] 🔍 totalSplit: $totalSplit, difference: $difference');
        // 🆕 Autoriser le dépassement (pourboire) mais refuser si insuffisant
        if (difference < -0.01) {
          print('[PAYMENT] 🔍 ❌ Montant insuffisant: $difference');
          return false;
        }
        // Vérifier que chaque mode CREDIT a un client
        for (final transaction in _splitPaymentTransactions!) {
          if (transaction['mode'] == 'CREDIT') {
            if (transaction['clientId'] == null) {
              print('[PAYMENT] 🔍 ❌ Client CREDIT manquant');
              return false;
            }
          }
        }
        print('[PAYMENT] 🔍 ✅ Paiement divisé valide (nouveau format)');
      } else if (splitPayments.isNotEmpty) {
        // Fallback sur l'ancien format
        print('[PAYMENT] 🔍 splitPayments.length: ${splitPayments.length}');
        if (splitPayments.length < 2) {
          print('[PAYMENT] 🔍 ❌ Moins de 2 modes sélectionnés');
          return false;
        }
        final totalSplit = splitPayments.values.fold<double>(0, (sum, amount) => sum + amount);
        final difference = totalSplit - finalTotal;
        print('[PAYMENT] 🔍 totalSplit: $totalSplit, difference: $difference');
        // 🆕 Autoriser le dépassement (pourboire) mais refuser si insuffisant
        if (difference < -0.01) {
          print('[PAYMENT] 🔍 ❌ Montant insuffisant: $difference');
          return false;
        }
        // Vérifier que chaque mode CREDIT a un client
        for (final entry in splitPayments.entries) {
          if (entry.key == 'CREDIT') {
            if (splitCreditClients == null || splitCreditClients![entry.key] == null) {
              print('[PAYMENT] 🔍 ❌ Client CREDIT manquant pour ${entry.key}');
              return false;
            }
          }
        }
        print('[PAYMENT] 🔍 ✅ Paiement divisé valide (ancien format)');
      } else {
        print('[PAYMENT] 🔍 ❌ Aucune transaction de paiement divisé');
        return false;
      }
    } else {
      // Mode de paiement doit être sélectionné
      if (selectedPaymentMode.isEmpty) {
        print('[PAYMENT] 🔍 ❌ selectedPaymentMode vide');
        return false;
      }
      
      // Si paiement crédit, client doit être sélectionné
      if (selectedPaymentMode == 'CREDIT' && _selectedClientForCredit == null) {
        print('[PAYMENT] 🔍 ❌ Client CREDIT manquant');
        return false;
      }
    }
    
    // Si paiement partiel, articles doivent être sélectionnés
    if (selectedNoteForPayment == 'partial' && selectedPartialQuantities.isEmpty) {
      print('[PAYMENT] 🔍 ❌ Articles partiels vides');
      return false;
    }
    
    // Si facture demandée, nom société requis
    if (needsInvoice && companyName.trim().isEmpty) {
      print('[PAYMENT] 🔍 ❌ Nom société manquant');
      return false;
    }
    
    // Vérifier qu'il y a des articles à payer
    final itemsToPay = PaymentValidationService.getItemsToPay(
      selectedNoteForPayment: selectedNoteForPayment,
      selectedPartialQuantities: selectedPartialQuantities,
      organizedItemsForPartialPayment: organizedItemsForPartialPayment,
      mainNote: widget.mainNote,
      subNotes: widget.subNotes,
      getAllItemsOrganized: getAllItemsOrganized,
    );
    
    print('[PAYMENT] 🔍 itemsToPay.length: ${itemsToPay.length}');
    if (itemsToPay.isEmpty) {
      print('[PAYMENT] 🔍 ❌ Aucun article à payer');
      return false;
    }
    
    print('[PAYMENT] 🔍 ✅ Paiement VALIDE');
    return true;
  }
  
  /// Retourne le message d'erreur si le paiement n'est pas valide
  String? get paymentValidationMessage {
    if (finalTotal <= 0) return 'Le montant à payer doit être supérieur à 0';
    
    // 🆕 Validation paiement divisé
    if (isSplitPayment) {
      // 🆕 Utiliser _splitPaymentTransactions si disponible (nouveau format)
      if (_splitPaymentTransactions != null && _splitPaymentTransactions!.isNotEmpty) {
        if (_splitPaymentTransactions!.length < 1) {
          return 'Veuillez ajouter au moins une transaction';
        }
        final totalSplit = _splitPaymentTransactions!.fold<double>(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
        final difference = totalSplit - finalTotal;
        // 🆕 Autoriser le dépassement (pourboire) mais refuser si insuffisant
        if (difference < -0.01) {
          return 'La somme des montants (${totalSplit.toStringAsFixed(2)} TND) est inférieure au total (${finalTotal.toStringAsFixed(2)} TND)';
        }
        // Si difference > 0.01, c'est un pourboire, on l'autorise
        // Vérifier que chaque mode CREDIT a un client
        for (final transaction in _splitPaymentTransactions!) {
          if (transaction['mode'] == 'CREDIT') {
            if (transaction['clientId'] == null) {
              return 'Veuillez sélectionner un client pour le paiement CREDIT';
            }
          }
        }
      } else if (splitPayments.isNotEmpty) {
        // Fallback sur l'ancien format
        if (splitPayments.length < 2) {
          return 'Veuillez sélectionner au moins 2 modes de paiement';
        }
        final totalSplit = splitPayments.values.fold<double>(0, (sum, amount) => sum + amount);
        final difference = totalSplit - finalTotal;
        // 🆕 Autoriser le dépassement (pourboire) mais refuser si insuffisant
        if (difference < -0.01) {
          return 'La somme des montants (${totalSplit.toStringAsFixed(2)} TND) est inférieure au total (${finalTotal.toStringAsFixed(2)} TND)';
        }
        // Vérifier que chaque mode CREDIT a un client
        for (final entry in splitPayments.entries) {
          if (entry.key == 'CREDIT') {
            if (splitCreditClients == null || splitCreditClients![entry.key] == null) {
              return 'Veuillez sélectionner un client pour le paiement CREDIT';
            }
          }
        }
      } else {
        return 'Veuillez ajouter au moins une transaction de paiement';
      }
    } else {
      if (selectedPaymentMode.isEmpty) return 'Veuillez sélectionner un mode de paiement';
      if (selectedPaymentMode == 'CREDIT' && _selectedClientForCredit == null) {
        return 'Veuillez sélectionner un client pour le paiement à crédit';
      }
    }
    
    if (selectedNoteForPayment == 'partial' && selectedPartialQuantities.isEmpty) {
      return 'Veuillez sélectionner des articles pour le paiement partiel';
    }
    if (needsInvoice && companyName.trim().isEmpty) {
      return 'Nom de la société requis pour la facture';
    }
    
    final itemsToPay = PaymentValidationService.getItemsToPay(
      selectedNoteForPayment: selectedNoteForPayment,
      selectedPartialQuantities: selectedPartialQuantities,
      organizedItemsForPartialPayment: organizedItemsForPartialPayment,
      mainNote: widget.mainNote,
      subNotes: widget.subNotes,
      getAllItemsOrganized: getAllItemsOrganized,
    );
    
    if (itemsToPay.isEmpty) return 'Aucun article à payer';
    
    return null;
  }
  
  // 🆕 Obtenir la couleur d'une note
  Color getNoteColor(String noteId) {
    if (noteId == 'main' || noteId == 'all') return noteColors[0];
    final index = widget.subNotes.indexWhere((n) => n.id == noteId);
    if (index == -1) return noteColors[0];
    return noteColors[(index + 1) % noteColors.length];
  }
  
  // 🆕 Map des quantités sélectionnées pour paiement partiel (itemId -> quantité)
  final Map<int, int> selectedPartialQuantities = {};
  
  // 🆕 Cache pour les articles organisés (performance)
  List<Map<String, dynamic>>? _cachedOrganizedItems;
  
  // 🆕 Helper commun: organise des articles bruts par catégories (évite la duplication)
  List<Map<String, dynamic>> _organizeFromRawItems(List<Map<String, dynamic>> rawItems) {
    // 🆕 ItemOrganizer détecte maintenant automatiquement les métadonnées (orderId/noteId)
    // et ne regroupe pas dans ce cas pour préserver la provenance
    return ItemOrganizer.organizeFromRawItems(rawItems);
  }

  // 🆕 Obtenir les articles organisés par catégories pour paiement partiel
  // 🆕 IMPORTANT : Le paiement partiel inclut UNIQUEMENT les articles de la note principale
  // Les sous-notes doivent être payées séparément via leur propre option de paiement
  // 
  // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utilise toujours _currentAllOrders (données backend) en priorité
  // _currentAllOrders est mis à jour après chaque paiement via _reloadAllOrders()
  // Cela garantit que les unpaidQuantity sont toujours synchronisées avec le backend
  List<Map<String, dynamic>> get organizedItemsForPartialPayment {
    // 🆕 SOURCE DE VÉRITÉ UNIQUE : Pour le paiement partiel, on ne prend QUE la note principale
    final allItems = _getAllItemsOrganized();
    return allItems.where((item) {
      final directNoteId = item['noteId'] as String?;
      if (directNoteId == 'main' || directNoteId == null) return true;
      
      final sources = item['sources'] as List?;
      if (sources != null && sources.isNotEmpty) {
        return sources.any((s) => s['noteId'] == 'main' || s['noteId'] == null);
      }
      return false;
    }).map((item) {
      // Si l'item est mixte (main + sub), on ne garde que la partie "main" pour le dialogue partiel
      final sources = item['sources'] as List?;
      if (sources != null && sources.isNotEmpty) {
        final mainQuantity = sources
            .where((s) => s['noteId'] == 'main' || s['noteId'] == null)
            .fold<int>(0, (sum, s) => sum + (s['quantity'] as int? ?? 0));
        
        final newItem = Map<String, dynamic>.from(item);
        newItem['quantity'] = mainQuantity;
        newItem['noteId'] = 'main';
        return newItem;
      }
      return item;
    }).where((item) => (item['quantity'] as int? ?? 0) > 0).toList();
  }

  // 🆕 Invalider le cache quand nécessaire
  void _invalidateOrganizedItemsCache() {
    _cachedOrganizedItems = null;
  }
  
  // 🆕 Recharger toutes les commandes depuis le serveur
  Future<void> _reloadAllOrders() async {
    try {
      // 🆕 Attendre un peu pour que le serveur ait fini de sauvegarder
      await Future.delayed(const Duration(milliseconds: 300));
      
      final updatedOrders = await OrderPaymentService.PaymentService.getAllOrdersForTable(widget.tableNumber);
      if (updatedOrders != null && mounted) {
        setState(() {
          _currentAllOrders = updatedOrders;
          // Invalider le cache pour forcer le recalcul avec les nouvelles données
          _invalidateOrganizedItemsCache();
        });
        print('[PAYMENT] ✅ Commandes rechargées: ${updatedOrders.length} commande(s)');
        
        // 🆕 Log pour déboguer : afficher les paidQuantity des articles
        for (final order in updatedOrders) {
          final mainNote = order['mainNote'] as Map<String, dynamic>?;
          if (mainNote != null) {
            final items = mainNote['items'] as List? ?? [];
            for (final item in items) {
              final paidQty = item['paidQuantity'] as int? ?? 0;
              final totalQty = (item['quantity'] as num?)?.toInt() ?? 0;
              if (paidQty > 0) {
                print('[PAYMENT] 📊 Article ${item['name']} (id: ${item['id']}): qté totale=$totalQty, payée=$paidQty, reste=${totalQty - paidQty}');
              }
            }
          }
        }
      }
    } catch (e) {
      print('[PAYMENT] ⚠️ Erreur rechargement commandes: $e');
    }
  }
  
  // 🆕 Obtenir TOUS les articles de TOUTES les notes (organisés par catégories)
  // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utilise toujours _currentAllOrders (données backend) en priorité
  List<Map<String, dynamic>> _getAllItemsOrganized() {
    // Collecter tous les articles NON PAYÉS de toutes les commandes, notes principales et sous-notes
    final allItems = <Map<String, dynamic>>[];

    // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utiliser _currentAllOrders en priorité (données backend à jour)
    // _currentAllOrders est mis à jour après chaque paiement pour garantir la synchronisation
    final allOrders = _currentAllOrders ?? widget.allOrders;

    if (allOrders != null) {
      for (final order in allOrders) {
        final orderId = order['id'] as int?;
        // Note principale
        final mainNote = order['mainNote'] as Map<String, dynamic>?;
        if (mainNote != null) {
          final items = mainNote['items'] as List? ?? [];
          for (final item in items) {
            final totalQuantity = (item['quantity'] as num?)?.toInt() ?? 0;
            final paidQuantity = (item['paidQuantity'] as num?)?.toInt() ?? 0;
            final unpaidQuantity = totalQuantity - paidQuantity;
            if (unpaidQuantity > 0) {
              allItems.add({
                'id': item['id'],
                'name': item['name'],
                'price': (item['price'] as num).toDouble(),
                'quantity': unpaidQuantity,
                'orderId': orderId,
                'noteId': 'main',
              });
            }
          }
        }
        // Sous-notes
        final subNotes = order['subNotes'] as List? ?? [];
        for (final sub in subNotes) {
          final subId = sub['id'] as String? ?? '';
          final subPaid = sub['paid'] == true;
          if (subPaid) continue; // ignorer sous-notes déjà payées
          final items = sub['items'] as List? ?? [];
          for (final item in items) {
            final totalQuantity = (item['quantity'] as num?)?.toInt() ?? 0;
            final paidQuantity = (item['paidQuantity'] as num?)?.toInt() ?? 0;
            final unpaidQuantity = totalQuantity - paidQuantity;
            if (unpaidQuantity > 0) {
              allItems.add({
                'id': item['id'],
                'name': item['name'],
                'price': (item['price'] as num).toDouble(),
                'quantity': unpaidQuantity,
                'orderId': orderId,
                'noteId': subId,
              });
            }
          }
        }
      }

      // Organiser par catégories avec regroupement
      final organizedItems = _organizeFromRawItems(allItems);
      return organizedItems;
    }

    // ⚠️ FALLBACK OBSOLÈTE : Utiliser les objets passés au widget
    // Ce fallback ne devrait jamais être utilisé en production car widget.mainNote/widget.subNotes
    // peuvent être désynchronisés avec le backend après un paiement
    // TODO: Supprimer ce fallback une fois que tous les cas utilisent _currentAllOrders
    print('[PAYMENT] ⚠️ FALLBACK: Utilisation de widget.mainNote/widget.subNotes (peut être désynchronisé)');
    for (final item in widget.mainNote.items) {
      final paidQty = item.paidQuantity ?? 0;
      final unpaidQty = item.quantity - paidQty;
      if (unpaidQty > 0) {
        allItems.add({
          'id': item.id,
          'name': item.name,
          'price': item.price,
          'quantity': unpaidQty, // Essayer d'utiliser unpaidQty si disponible
          'orderId': null, // ⚠️ Perte de traçabilité dans le fallback
          'noteId': 'main',
        });
      }
    }
    for (final note in widget.subNotes) {
      if (!note.paid) {
        for (final item in note.items) {
          final paidQty = item.paidQuantity ?? 0;
          final unpaidQty = item.quantity - paidQty;
          if (unpaidQty > 0) {
            allItems.add({
              'id': item.id,
              'name': item.name,
              'price': item.price,
              'quantity': unpaidQty, // Essayer d'utiliser unpaidQty si disponible
              'orderId': null, // ⚠️ Perte de traçabilité dans le fallback
              'noteId': note.id,
            });
          }
        }
      }
    }

    final organizedItems = _organizeFromRawItems(allItems);
    return organizedItems;
  }
  
  // Getter pour exposer _getAllItemsOrganized pour les services
  List<Map<String, dynamic>> getAllItemsOrganized() => _getAllItemsOrganized();
  
  // 🆕 Calculer le total pour chaque sous-note depuis _getAllItemsOrganized()
  Map<String, double> _calculateSubNoteTotals() {
    final totals = <String, double>{};
    final allItems = _getAllItemsOrganized();
    
    for (final note in widget.subNotes) {
      if (note.paid) continue;
      
      double total = 0.0;
      for (final item in allItems) {
        final sources = item['sources'] as List?;
        int quantity = 0;
        
        if (sources != null && sources.isNotEmpty) {
          quantity = sources
              .where((source) {
                final sourceNoteId = (source as Map<String, dynamic>)['noteId'] as String?;
                return sourceNoteId == note.id;
              })
              .fold<int>(0, (sum, source) => sum + ((source as Map<String, dynamic>)['quantity'] as int? ?? 0));
        } else if (item['noteId'] == note.id) {
          quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        }
        
        if (quantity > 0) {
          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
          total += price * quantity;
        }
      }
      
      totals[note.id] = total;
    }
    
    return totals;
  }

  // 🆕 Détecter si seule une sous-note contient encore des impayés
  String? _detectSingleUnpaidSubNoteId() {
    final allOrders = _currentAllOrders ?? widget.allOrders;
    if (allOrders == null) return null;

    int unpaidMainCount = 0;
    final List<String> unpaidSubNoteIds = [];

    for (final order in allOrders) {
      // Compter impayés main
      final main = order['mainNote'] as Map<String, dynamic>?;
      if (main != null) {
        final items = main['items'] as List? ?? [];
        for (final it in items) {
          final total = (it['quantity'] as num?)?.toInt() ?? 0;
          final paid = (it['paidQuantity'] as num?)?.toInt() ?? 0;
          if (total - paid > 0) unpaidMainCount++;
        }
      }
      // Détecter sous-notes impayées
      final subs = order['subNotes'] as List? ?? [];
      for (final sn in subs) {
        final snId = sn['id']?.toString() ?? '';
        final items = sn['items'] as List? ?? [];
        bool hasUnpaid = false;
        for (final it in items) {
          final total = (it['quantity'] as num?)?.toInt() ?? 0;
          final paid = (it['paidQuantity'] as num?)?.toInt() ?? 0;
          if (total - paid > 0) { hasUnpaid = true; break; }
        }
        if (hasUnpaid) unpaidSubNoteIds.add(snId);
      }
    }

    if (unpaidMainCount == 0 && unpaidSubNoteIds.length == 1) {
      return unpaidSubNoteIds.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECF0F1),
      appBar: PaymentAppBar(
        tableNumber: widget.tableNumber,
        serverName: widget.currentServer,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Row(
        children: [
          // GAUCHE: Sélection des notes et détails (50%)
          Expanded(
            flex: 3,
            child: PaymentLeftPanel(
              selectedNoteForPayment: selectedNoteForPayment,
              total: widget.total,
              mainNote: widget.mainNote,
              subNotes: widget.subNotes,
              getNoteColor: getNoteColor,
              onNoteSelected: (noteId) {
                setState(() {
                  selectedNoteForPayment = noteId;
                  
                  // 🆕 CORRECTION: Mettre à jour discountClientName avec le nom de la note sélectionnée
                  if (noteId.startsWith('sub_')) {
                    // C'est une sous-note : récupérer son nom
                    final selectedSubNote = widget.subNotes.firstWhere(
                      (note) => note.id == noteId,
                      orElse: () => widget.mainNote,
                    );
                    if (selectedSubNote.name != 'Note Principale' && selectedSubNote.name.isNotEmpty) {
                      discountClientName = selectedSubNote.name;
                    } else {
                      discountClientName = null;
                    }
                  } else if (noteId == 'main') {
                    // 🆕 CORRECTION : Note principale - vérifier si elle a un nom de client spécifique
                    if (widget.mainNote.name != 'Note Principale' && widget.mainNote.name.isNotEmpty) {
                      discountClientName = widget.mainNote.name;
                    } else {
                      discountClientName = null;
                    }
                  } else if (noteId == 'all') {
                    // Tout payer : pas de nom de client par défaut (mélange de tous les clients)
                    discountClientName = null;
                  } else if (noteId == 'partial') {
                    // 🆕 CORRECTION : Paiement partiel - vérifier si on paie des articles d'une note spécifique
                    // Si c'est un paiement partiel sur une note avec nom de client, préserver le nom
                    final activeNote = widget.activeNoteId == 'main'
                      ? widget.mainNote
                      : widget.subNotes.firstWhere(
                          (note) => note.id == widget.activeNoteId,
                          orElse: () => widget.mainNote,
                        );
                    if (activeNote.name != 'Note Principale' && activeNote.name.isNotEmpty) {
                      discountClientName = activeNote.name;
                    } else {
                      discountClientName = null;
                    }
                  }
                  
                  _updatePaymentForNote();
                  if (noteId == 'partial') {
                    _showPartialPaymentDialog();
                  }
                });
              },
              itemsToShow: _getItemsToShow(),
              paymentTotal: paymentTotal,
              finalTotal: finalTotal,
              discount: discount,
              isPercentDiscount: isPercentDiscount,
              tableNumber: widget.tableNumber,
              covers: covers,
              serverName: widget.currentServer,
              subNoteTotals: _calculateSubNoteTotals(), // 🆕 Totaux calculés depuis _getAllItemsOrganized()
              totalForAll: totalForAll, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour "Tout payer"
              totalForMain: totalForMain, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour la note principale
              totalForPartial: totalForPartial, // 🆕 SOURCE DE VÉRITÉ UNIQUE : Total pour le paiement partiel
            ),
          ),
          
          const SizedBox(width: 16),
          
          // DROITE: Paiement (50%)
          Expanded(
            flex: 3,
            child: PaymentSection(
              discount: discount,
              isPercentDiscount: isPercentDiscount,
              selectedPaymentMode: selectedPaymentMode,
              selectedClientForCredit: _selectedClientForCredit,
              onDiscountSelected: (value, isPercent) {
                setState(() {
                  discount = value;
                  isPercentDiscount = isPercent;
                });
              },
              initialClientName: discountClientName,
              onClientNameChanged: (clientName) {
                setState(() {
                  discountClientName = clientName;
                });
              },
              isSplitPayment: isSplitPayment,
              onPaymentModeSelected: (mode) async {
                setState(() {
                  // Si on sélectionne un mode normal, désactiver le paiement divisé
                  if (isSplitPayment) {
                    isSplitPayment = false;
                    splitPayments.clear();
                    splitCreditClients = null;
                    splitCreditClientNames = null;
                    _splitPaymentTransactions = null;
                  }
                  selectedPaymentMode = mode;
                  // 🆕 Réinitialiser le montant scriptural si on change de mode
                  if (mode != 'CARTE' && mode != 'CHEQUE' && mode != 'TPE') {
                    _scripturalEnteredAmount = null;
                  }
                  if (mode != 'CREDIT') {
                    _selectedClientForCredit = null;
                  }
                });
                
                // 🆕 Pour CARTE/CHEQUE/TPE, permettre de saisir un montant supérieur au total (pourboire)
                if ((mode == 'CARTE' || mode == 'CHEQUE' || mode == 'TPE') && !isSplitPayment) {
                  await _showScripturalAmountDialog(mode);
                } else if (mode == 'CREDIT' && _selectedClientForCredit == null) {
                  Future.delayed(Duration.zero, () {
                    _showCreditClientDialog();
                  });
                } else {
                  _updatePaymentForNote();
                }
              },
              onShowCreditClientDialog: _showCreditClientDialog,
              onClearCreditClient: () {
                setState(() {
                  _selectedClientForCredit = null;
                });
              },
              onShowSplitPaymentDialog: _showSplitPaymentDialog,
              onPrintNote: _printNote,
              onShowInvoicePreview: _showInvoicePreview,
              onValidatePayment: _showPaymentSummary,
              isPaymentValid: isPaymentValid,
              validationMessage: paymentValidationMessage,
            ),
          ),
        ],
      ),
    );
  }
  
  // 🆕 Section de sélection des notes (boutons compacts en haut)
  // 🆕 Méthode pour obtenir la liste des articles à afficher
  List<Map<String, dynamic>> _getItemsToShow() {
    List<Map<String, dynamic>> itemsToShow = [];
    
    if (selectedNoteForPayment == 'all') {
      // 🆕 CORRECTION : Afficher tous les articles pour "Tout payer"
      final allItems = _getAllItemsOrganized();
      itemsToShow = allItems.map((item) {
        return {
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'quantity': item['quantity'] as int? ?? 0,
        };
      }).where((item) => (item['quantity'] as int) > 0).toList();
    } else if (selectedNoteForPayment == 'partial' && selectedPartialQuantities.isNotEmpty) {
      // Afficher les articles sélectionnés pour paiement partiel
      itemsToShow = selectedPartialQuantities.entries.map((entry) {
        final itemId = entry.key;
        final quantity = entry.value;
        final item = organizedItemsForPartialPayment.firstWhere(
          (item) => item['id'] == itemId,
          orElse: () => {'id': itemId, 'name': 'Article inconnu', 'price': 0.0}
        );
        return {
          'id': item['id'],
          'name': item['name'],
          'price': item['price'],
          'quantity': quantity,
        };
      }).toList();
    } else if (selectedNoteForPayment == 'main' || selectedNoteForPayment.startsWith('sub_')) {
      // 🆕 SOURCE DE VÉRITÉ UNIQUE : Utiliser directement getItemsToPay() pour garantir la cohérence
      // Ce qui est affiché correspond exactement à ce qui sera payé
      final itemsToPay = PaymentValidationService.getItemsToPay(
        selectedNoteForPayment: selectedNoteForPayment,
        selectedPartialQuantities: selectedPartialQuantities,
        organizedItemsForPartialPayment: organizedItemsForPartialPayment,
        mainNote: widget.mainNote,
        subNotes: widget.subNotes,
        getAllItemsOrganized: getAllItemsOrganized,
      );
      
      // Regrouper visuellement les articles identiques (même id, nom, prix) pour l'affichage
      final Map<String, Map<String, dynamic>> itemsMap = {};
      for (final item in itemsToPay) {
        final itemId = item['id'];
        final itemName = item['name'] as String;
        final itemPrice = item['price'] as num;
        final key = "$itemId-$itemName-$itemPrice";
        
        if (itemsMap.containsKey(key)) {
          // Article déjà présent : additionner la quantité
          itemsMap[key]!['quantity'] = (itemsMap[key]!['quantity'] as int) + (item['quantity'] as int? ?? 0);
        } else {
          // Nouvel article
          itemsMap[key] = {
            'id': itemId,
            'name': itemName,
            'price': itemPrice,
            'quantity': item['quantity'] as int? ?? 0,
          };
        }
      }
      
      itemsToShow = itemsMap.values.where((item) => (item['quantity'] as int) > 0).toList();
    }
    
    return itemsToShow;
  }
  
  
  
  // 🆕 Section montant donné (compacte)
  // Méthode supprimée : _buildAmountGivenSection()
  // (section "Montant donné" supprimée pour interface simplifiée)
  
  // Méthode supprimée : _buildInvoiceSection()
  // (section "Facturation" Ticket/Facture supprimée - le vrai bouton facture est conservé plus bas)
  
  // Méthode supprimée : _buildInvoiceTypeButton()
  // (plus utilisée après suppression de _buildInvoiceSection)
  
  // Méthodes supprimées : _buildQuickActionsSection() et _buildQuickActionButton()
  // (section "Actions rapides" supprimée pour interface simplifiée)
  
  // 🆕 Configuration et génération de facture
  void _showInvoicePreview() {
    // Remplir automatiquement les données société par défaut si vides
    if (companyName.isEmpty) {
      setState(() {
      companyName = 'Entreprise Tunisienne SARL';
      companyAddress = '123 Avenue Habib Bourguiba, Tunis 1000';
      companyPhone = '+216 71 123 456';
      companyEmail = 'contact@entreprise.tn';
      taxNumber = '12345678/A/M/000';
      });
    }
    
    int dialogCovers = covers;
    String dialogCompanyName = companyName;
    String dialogCompanyAddress = companyAddress;
    String dialogCompanyPhone = companyPhone;
    String dialogCompanyEmail = companyEmail;
    String dialogTaxNumber = taxNumber;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => InvoicePreviewDialog(
          tableNumber: int.tryParse(widget.tableNumber) ?? 0,
          finalTotal: finalTotal,
          selectedPaymentMode: selectedPaymentMode,
          selectedNoteName: selectedNote?.name,
          selectedNoteForPayment: selectedNoteForPayment,
          covers: dialogCovers,
          companyName: dialogCompanyName,
          companyAddress: dialogCompanyAddress,
          companyPhone: dialogCompanyPhone,
          companyEmail: dialogCompanyEmail,
          taxNumber: dialogTaxNumber,
          onInvoiceFormBuilt: (setDialogState) => InvoiceForm(
            companyName: dialogCompanyName,
            companyAddress: dialogCompanyAddress,
            companyPhone: dialogCompanyPhone,
            companyEmail: dialogCompanyEmail,
            taxNumber: dialogTaxNumber,
            onCompanyNameChanged: (value) {
              dialogCompanyName = value;
              setDialogState(() {});
            },
            onCompanyAddressChanged: (value) {
              dialogCompanyAddress = value;
              setDialogState(() {});
            },
            onCompanyPhoneChanged: (value) {
              dialogCompanyPhone = value;
              setDialogState(() {});
            },
            onCompanyEmailChanged: (value) {
              dialogCompanyEmail = value;
              setDialogState(() {});
            },
            onTaxNumberChanged: (value) {
              dialogTaxNumber = value;
              setDialogState(() {});
            },
          ),
          onGenerateInvoice: () {
            setState(() {
              covers = dialogCovers;
              companyName = dialogCompanyName;
              companyAddress = dialogCompanyAddress;
              companyPhone = dialogCompanyPhone;
              companyEmail = dialogCompanyEmail;
              taxNumber = dialogTaxNumber;
              needsInvoice = true;
            });
                Navigator.of(context).pop();
            _validatePayment();
          },
        ),
      ),
    );
  }

  // 🆕 Dialog pour paiement partiel (style transfert cohérent)
  void _showPartialPaymentDialog() async {
    // Vider les sélections précédentes
    selectedPartialQuantities.clear();
    
    // 🆕 Recharger les données depuis le serveur pour avoir les quantités payées à jour
    await _reloadAllOrders();
    
    final Map<int, int> dialogSelectedQuantities = {};
    
    showDialog(
      context: context,
      builder: (context) => PartialPaymentDialog(
        organizedItems: organizedItemsForPartialPayment,
        selectedQuantities: dialogSelectedQuantities,
        onQuantityChanged: (itemId, quantity) {
          dialogSelectedQuantities[itemId] = quantity;
        },
        onToggleItem: (itemId) {
          if (dialogSelectedQuantities.containsKey(itemId)) {
            dialogSelectedQuantities.remove(itemId);
          } else {
            final originalQty = organizedItemsForPartialPayment
                .firstWhere((item) => item['id'] == itemId, orElse: () => {'quantity': 0})['quantity'] as int;
            dialogSelectedQuantities[itemId] = originalQty;
          }
        },
        onConfirm: () {
                setState(() {
            selectedPartialQuantities.clear();
            selectedPartialQuantities.addAll(dialogSelectedQuantities);
                  selectedNoteForPayment = 'partial';
                  _updatePaymentForNote();
                });
          Navigator.of(context).pop();
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
  
  // 🆕 Mettre à jour le paiement pour la note sélectionnée
  void _updatePaymentForNote() {
    notePayments[selectedNoteForPayment] = finalTotal;
    notePaymentModes[selectedNoteForPayment] = selectedPaymentMode;
  }


  void _printNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impression de la pré-addition...'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      _showTicketPreview();
    });
  }
  
  void _showTicketPreview() async {
    // 🆕 Rafraîchir avant de calculer la pré‑addition
    await _reloadAllOrders();

    final items = PaymentValidationService.getItemsToPay(
      selectedNoteForPayment: selectedNoteForPayment,
      selectedPartialQuantities: selectedPartialQuantities,
      organizedItemsForPartialPayment: organizedItemsForPartialPayment,
      mainNote: widget.mainNote,
      subNotes: widget.subNotes,
      getAllItemsOrganized: getAllItemsOrganized,
    );
    
    // 🆕 Debug: vérifier l'état du paiement divisé
    print('[TICKET] _showTicketPreview - isSplitPayment: $isSplitPayment');
    print('[TICKET] _showTicketPreview - splitPayments: $splitPayments');
    print('[TICKET] _showTicketPreview - splitCreditClients: $splitCreditClients');
    print('[TICKET] _showTicketPreview - splitCreditClientNames: $splitCreditClientNames');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TicketPreviewDialog(
        tableNumber: int.tryParse(widget.tableNumber) ?? 0,
        paymentTotal: paymentTotal,
        finalTotal: finalTotal,
        discount: discount,
        isPercentDiscount: isPercentDiscount,
        itemsToPay: items,
        isSplitPayment: isSplitPayment,
        splitPayments: isSplitPayment ? splitPayments : null,
        splitCreditClients: isSplitPayment ? splitCreditClients : null,
        splitCreditClientNames: isSplitPayment ? splitCreditClientNames : null,
      ),
    );
  }

  /// Affiche le résumé du paiement avant validation
  void _showPaymentSummary() {
    print('[PAYMENT] 📋 _showPaymentSummary appelé');
    print('[PAYMENT] 📋 isPaymentValid: $isPaymentValid');
    print('[PAYMENT] 📋 isSplitPayment: $isSplitPayment');
    print('[PAYMENT] 📋 paymentValidationMessage: $paymentValidationMessage');
    
    if (!isPaymentValid) {
      print('[PAYMENT] ❌ Paiement invalide: ${paymentValidationMessage ?? 'Paiement invalide'}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paymentValidationMessage ?? 'Paiement invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('[PAYMENT] ✅ Paiement valide, affichage du résumé...');

    final itemsToPay = PaymentValidationService.getItemsToPay(
      selectedNoteForPayment: selectedNoteForPayment,
      selectedPartialQuantities: selectedPartialQuantities,
      organizedItemsForPartialPayment: organizedItemsForPartialPayment,
      mainNote: widget.mainNote,
      subNotes: widget.subNotes,
      getAllItemsOrganized: getAllItemsOrganized,
    );

    if (itemsToPay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun article à payer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => PaymentSummaryDialog(
        tableNumber: widget.tableNumber,
        selectedNoteName: selectedNote?.name ??
            (selectedNoteForPayment == 'all'
                ? 'Toutes les notes'
                : selectedNoteForPayment == 'partial'
                    ? 'Paiement partiel'
                    : 'Note Principale'),
        paymentTotal: paymentTotal,
        finalTotal: finalTotal,
        discountAmount: discount > 0
            ? (isPercentDiscount ? paymentTotal * discount / 100 : discount)
            : 0,
        discountLabel: discount > 0
            ? (isPercentDiscount
                ? 'Remise (${discount.toStringAsFixed(0)}%)'
                : 'Remise')
            : null,
        selectedPaymentMode: selectedPaymentMode,
        creditClientName: _selectedClientForCredit?['name'] as String?,
        discountClientName: discountClientName,
        covers: covers,
        isPartialPayment: selectedNoteForPayment == 'partial',
        isSplitPayment: isSplitPayment,
        splitPayments: isSplitPayment ? splitPayments : null,
        splitCreditClients: isSplitPayment ? splitCreditClients : null,
        splitPaymentTransactions: isSplitPayment ? _splitPaymentTransactions : null, // 🆕 Passer les transactions
        serverName: widget.currentServer, // 🆕 Passer le nom du serveur
        enteredAmount: !isSplitPayment ? _scripturalEnteredAmount : null, // 🐛 BUG FIX : Passer le montant saisi pour calculer le pourboire
        onConfirm: () {
          Navigator.of(context).pop();
          _validatePayment();
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _validatePayment() async {
    print('[PAYMENT] 🚀 Début validation paiement');
    print('[PAYMENT] 🚀 isSplitPayment: $isSplitPayment');
    print('[PAYMENT] 🚀 splitPayments: $splitPayments');
    print('[PAYMENT] 🚀 selectedPaymentMode: $selectedPaymentMode');
    print('[PAYMENT] 🚀 finalTotal: $finalTotal');
    
    // 🆕 Rafraîchir avant paiement
    await _reloadAllOrders();

    // 🆕 Valider les prérequis (adapter pour paiement divisé)
    String? validationError;
    if (isSplitPayment) {
      // 🆕 Validation spécifique pour paiement divisé - utiliser _splitPaymentTransactions
      if (_splitPaymentTransactions != null && _splitPaymentTransactions!.isNotEmpty) {
        if (_splitPaymentTransactions!.length < 1) {
          validationError = 'Veuillez ajouter au moins une transaction';
        } else {
          final totalSplit = _splitPaymentTransactions!.fold<double>(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
          final difference = totalSplit - finalTotal;
          // 🆕 Autoriser le dépassement (pourboire) mais refuser si insuffisant
          if (difference < -0.01) {
            validationError = 'La somme des montants (${totalSplit.toStringAsFixed(2)} TND) est inférieure au total (${finalTotal.toStringAsFixed(2)} TND)';
          }
          // Si difference > 0.01, c'est un pourboire, on l'autorise
          // Vérifier clients CREDIT
          for (final transaction in _splitPaymentTransactions!) {
            if (transaction['mode'] == 'CREDIT') {
              if (transaction['clientId'] == null) {
                validationError = 'Veuillez sélectionner un client pour le paiement CREDIT';
                break;
              }
            }
          }
        }
      } else if (splitPayments.isNotEmpty) {
        // Fallback sur l'ancien format
        if (splitPayments.length < 2) {
          validationError = 'Veuillez sélectionner au moins 2 modes de paiement';
        } else {
          final totalSplit = splitPayments.values.fold<double>(0, (sum, amount) => sum + amount);
          final difference = totalSplit - finalTotal;
          // 🆕 Autoriser le dépassement (pourboire) mais refuser si insuffisant
          if (difference < -0.01) {
            validationError = 'La somme des montants (${totalSplit.toStringAsFixed(2)} TND) est inférieure au total (${finalTotal.toStringAsFixed(2)} TND)';
          }
          // Vérifier clients CREDIT
          for (final entry in splitPayments.entries) {
            if (entry.key == 'CREDIT') {
              if (splitCreditClients == null || splitCreditClients![entry.key] == null) {
                validationError = 'Veuillez sélectionner un client pour le paiement CREDIT';
                break;
              }
            }
          }
        }
      } else {
        validationError = 'Veuillez ajouter au moins une transaction de paiement';
      }
    } else {
      // Validation normale
      validationError = PaymentValidationService.validatePaymentPrerequisites(
        selectedPaymentMode: selectedPaymentMode,
        selectedNoteForPayment: selectedNoteForPayment,
        selectedPartialQuantities: selectedPartialQuantities,
        needsInvoice: needsInvoice,
        companyName: companyName,
        selectedClientForCredit: _selectedClientForCredit,
      );
    }
    
    if (validationError == 'CREDIT_DIALOG') {
        _showCreditClientDialog();
      return;
    }
    
    if (validationError != null) {
      print('[PAYMENT] ❌ Erreur validation: $validationError');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red),
      );
      return;
    }
    
    print('[PAYMENT] ✅ Validation OK, traitement du paiement...');

    // 🆕 Protection contre les doubles clics
    if (_isProcessingPayment) {
      print('[PAYMENT] ⚠️ Paiement déjà en cours, ignore le clic');
      return;
    }
    _isProcessingPayment = true;

    try {
      // Déterminer les articles à payer selon la sélection
      final itemsToPay = PaymentValidationService.getItemsToPay(
        selectedNoteForPayment: selectedNoteForPayment,
        selectedPartialQuantities: selectedPartialQuantities,
        organizedItemsForPartialPayment: organizedItemsForPartialPayment,
        mainNote: widget.mainNote,
        subNotes: widget.subNotes,
        getAllItemsOrganized: getAllItemsOrganized,
      );
      
      print('[PAYMENT] 📦 Articles à payer: ${itemsToPay.length}');
      print('[PAYMENT] 📦 selectedNoteForPayment: $selectedNoteForPayment');
      print('[PAYMENT] 📦 isSplitPayment: $isSplitPayment');
      
      // 🆕 ÉTAPE 0: Si paiement CREDIT simple (NON divisé), créer la transaction de crédit AVANT de supprimer les articles
      // ⚠️ Pour les paiements divisés, le backend crée la transaction CREDIT globale, donc on ne le fait PAS ici
      if (!isSplitPayment && selectedPaymentMode == 'CREDIT' && _selectedClientForCredit != null) {
        // 🎯 ÉTAPE 0: Si paiement CREDIT simple, créer la transaction de crédit AVANT de supprimer les articles
        try {
          await _processCreditPayment(_selectedClientForCredit!, finalTotal);
          print('[CREDIT] ✅ Transaction de crédit créée avec succès');
        } catch (e) {
          print('[CREDIT] ❌ Erreur création transaction crédit: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur enregistrement crédit: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return; // Arrêter le processus si la transaction crédit échoue
        }
      }
      
      // 🎯 ÉTAPE 1: Marquer les articles comme vendus/payés (supprimer de la commande)
      try {
        await PaymentValidationService.processPayment(
          selectedNoteForPayment: selectedNoteForPayment,
          selectedPartialQuantities: selectedPartialQuantities,
          tableNumber: widget.tableNumber,
          tableId: widget.tableId,
          selectedPaymentMode: isSplitPayment ? 'SPLIT' : selectedPaymentMode, // 🆕 Mode spécial pour paiement divisé
          itemsToPay: itemsToPay,
          organizedItemsForPartialPayment: selectedNoteForPayment == 'all'
              ? _getAllItemsOrganized() // 🆕 Utiliser la source complète pour mapping orderId/noteId
              : organizedItemsForPartialPayment,
          finalAmount: _scripturalEnteredAmount ?? finalTotal, // 🆕 Montant réellement payé (avec remise + pourboire si scriptural)
          discount: discount, // 🆕 Remise
          isPercentDiscount: isPercentDiscount, // 🆕 Type de remise
          discountClientName: discountClientName, // 🆕 Nom du client pour justifier la remise
          splitPayments: isSplitPayment ? splitPayments : null, // 🆕 DEPRECATED
          splitCreditClients: isSplitPayment ? splitCreditClients : null, // 🆕 DEPRECATED
          splitPaymentTransactions: isSplitPayment ? _splitPaymentTransactions : null, // 🆕 Liste de transactions
          serverName: widget.currentServer, // 🆕 CORRECTION : Transmettre le serveur pour les détails des remises KPI
          scripturalEnteredAmount: _scripturalEnteredAmount, // 🆕 Montant réellement saisi pour paiement scriptural simple
        );
        print('[PAYMENT] Articles marqués comme vendus et supprimés avec succès');
        
        // 🆕 Recharger les commandes depuis le serveur pour avoir les données à jour (avec paidQuantity)
        await _reloadAllOrders();
        
      } catch (e) {
        print('[PAYMENT] ❌ Erreur lors de la suppression des articles: $e');
        print('[PAYMENT] ❌ Stack trace: ${StackTrace.current}');
        // 🆕 Réinitialiser le flag en cas d'erreur
        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
          });
        }
        if (selectedNoteForPayment == 'all') {
          try {
            await PaymentService.clearTableConsumption(tableNumber: widget.tableNumber);
            await PaymentService.closeTableAfterPayment(
              tableId: widget.tableId,
              tableNumber: widget.tableNumber,
            );
          } catch (e2) {
            print('Erreur vidage table (ignorée): $e2');
          }
        }
        return; // 🆕 Arrêter le traitement en cas d'erreur
      }
      
      // 🎯 ÉTAPE 2: Enregistrer le paiement individuel (pour détails restaurateur)
      await PaymentService.recordIndividualPayment(
        tableNumber: widget.tableNumber,
        paymentType: selectedNoteForPayment,
        paymentMode: selectedPaymentMode,
        amount: finalTotal,
        items: itemsToPay,
        discount: discount,
        isPercentDiscount: isPercentDiscount,
        covers: covers,
        needsInvoice: needsInvoice,
      );
      
      // 🎯 ÉTAPE 2.5: Si paiement CREDIT (simple ou divisé), recharger le balance du client
      if (isSplitPayment && splitCreditClients != null) {
        // Paiement divisé avec CREDIT
        for (final entry in splitCreditClients!.entries) {
          final clientId = entry.value.toString();
          await _reloadClientBalance(clientId);
        }
      } else if (selectedPaymentMode == 'CREDIT' && _selectedClientForCredit != null) {
        // Paiement CREDIT simple
        final clientId = _selectedClientForCredit!['id'].toString();
        await _reloadClientBalance(clientId);
        // Nettoyer la sélection client après paiement
        setState(() {
          _selectedClientForCredit = null;
        });
      }
      
      // 🆕 Nettoyer l'état du paiement divisé après paiement
      if (isSplitPayment) {
        setState(() {
          isSplitPayment = false;
          splitPayments.clear();
          splitCreditClients = null;
          splitCreditClientNames = null;
          _splitPaymentTransactions = null;
          _isProcessingPayment = false; // 🆕 Réinitialiser le flag après succès
        });
      } else {
        setState(() {
          _isProcessingPayment = false; // 🆕 Réinitialiser le flag après succès
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paiement validé - $selectedPaymentMode'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 🎯 ÉTAPE 3: Imprimer ticket de caisse
        _printTicket();
        
        // 🎯 ÉTAPE 4: Générer facture PDF si demandée
        String? pdfUrl;
        if (needsInvoice) {
          pdfUrl = await PaymentService.generateInvoicePDF(
            tableNumber: widget.tableNumber,
            companyName: companyName,
            companyAddress: companyAddress,
            companyPhone: companyPhone,
            companyEmail: companyEmail,
            taxNumber: taxNumber,
            items: widget.items,
            total: finalTotal,
            amountPerPerson: amountPerPerson,
            covers: covers,
            paymentMode: selectedPaymentMode,
          );
          
          if (pdfUrl == null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erreur génération facture'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        
        // NAVIGUER SELON LE TYPE DE PAIEMENT
        // 🆕 Vérifier s'il reste des commandes pour cette table après paiement
        bool forceReturnToPlan = false;
        try {
          final res = await ApiClient.dio.get('/orders', queryParameters: {'table': widget.tableNumber});
          final remaining = (res.data as List?)?.length ?? 0;
          if (remaining == 0) {
            forceReturnToPlan = true;
          }
        } catch (_) {}

        if (pdfUrl != null) {
          // Naviguer vers l'écran de facture
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PosInvoiceViewerPage(
                tableNumber: widget.tableNumber,
                companyName: companyName,
                items: itemsToPay,
                total: finalTotal,
                amountPerPerson: amountPerPerson,
                covers: covers,
                paymentMode: selectedPaymentMode,
                pdfUrl: pdfUrl!,
              ),
            ),
          ).then((_) {
            Navigator.of(context).pop({
              'payment_completed': true,
              'table': widget.tableNumber,
              'paid_amount': finalTotal,
              'payment_type': selectedNoteForPayment,
              'stay_in_pos': forceReturnToPlan ? false : (selectedNoteForPayment != 'all'),
              'force_refresh': true, // 🆕 Forcer la mise à jour optimiste
            }); 
          });
        } else {
          // Retourner à la caisse
          Navigator.of(context).pop({
            'payment_completed': true,
            'table': widget.tableNumber,
            'paid_amount': finalTotal,
            'payment_type': selectedNoteForPayment,
            'stay_in_pos': forceReturnToPlan ? false : (selectedNoteForPayment != 'all'),
            'force_refresh': true, // 🆕 Forcer la mise à jour optimiste
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 🎯 Enregistrer le paiement individuel (pour détails restaurateur)

  void _printTicket() {
    // Simulation impression
    final effectiveCovers = selectedNoteForPayment == 'partial' 
        ? widget.mainNote.covers 
        : covers;
    print('=== TICKET CAISSE ===');
    print('Table: ${widget.tableNumber}');
    print('Couverts: $effectiveCovers');
    print('Mode: $selectedPaymentMode');
    print('Total: ${finalTotal.toStringAsFixed(3)} TND');
    if (effectiveCovers > 1) {
      print('Par personne: ${amountPerPerson.toStringAsFixed(3)} TND');
    }
    // Supprimé : affichage "Donné" et "Rendu" (plus de saisie de montant en espèces)
    if (needsInvoice) {
      print('Facture: ${companyName}');
    }
    print('====================');
  }

  // 🆕 Dialog de sélection/création client pour crédit
  void _showCreditClientDialog() {
      showDialog(
        context: context,
      builder: (context) => CreditClientDialog(
        onClientSelected: _selectClientForCredit,
        totalAmount: finalTotal,
      ),
    );
  }

  // 🆕 Dialog pour paiement divisé
  void _showSplitPaymentDialog() async {
    print('[PAYMENT] 💬 Ouverture dialog paiement divisé');
    print('[PAYMENT] 💬 finalTotal: $finalTotal');
    print('[PAYMENT] 💬 selectedNoteForPayment: $selectedNoteForPayment');
    print('[PAYMENT] 💬 _splitPaymentTransactions: $_splitPaymentTransactions');
    if (_splitPaymentTransactions != null && _splitPaymentTransactions!.isNotEmpty) {
      final totalFromTransactions = _splitPaymentTransactions!.fold<double>(0.0, (sum, t) => sum + (t['amount'] as num).toDouble());
      print('[PAYMENT] 💬 Total des transactions existantes: $totalFromTransactions');
    }
    
    final result = await showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false, // 🆕 Empêcher la fermeture en cliquant en dehors
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SplitPaymentDialog(
          totalAmount: finalTotal,
          selectedClientForCredit: _selectedClientForCredit,
          // 🆕 Préserver les transactions existantes si on rouvre le dialog
          initialTransactions: _splitPaymentTransactions,
          // 🆕 Préserver les clients CREDIT pour restaurer les noms
          initialCreditClients: splitCreditClients,
          initialCreditClientNames: splitCreditClientNames,
          onConfirm: (transactions, creditClients) {
            // 🆕 Ne pas faire Navigator.pop ici, le dialog le fait lui-même
            print('[PAYMENT] 💬 Dialog confirmé avec ${transactions.length} transactions');
          },
          onCancel: () {
            // 🆕 Ne pas faire Navigator.pop ici, le dialog le fait lui-même
            print('[PAYMENT] 💬 Dialog annulé');
          },
        );
      },
    );

    if (result != null && result is Map<String, dynamic>) {
      print('[PAYMENT] 💬 Résultat dialog reçu: ${result['transactions']}');
      final transactions = result['transactions'] as List<Map<String, dynamic>>?;
      final creditClients = result['creditClients'] as Map<String, int>?;
      
      if (transactions != null && transactions.isNotEmpty) {
      // 🆕 Convertir la liste de transactions en Map pour compatibilité avec le reste du code
      // On groupe par mode pour l'affichage, mais on garde la liste pour l'envoi au backend
      Map<String, double> paymentsMap = {};
      for (final transaction in transactions) {
        final mode = transaction['mode'] as String;
        final amount = (transaction['amount'] as num).toDouble();
        paymentsMap[mode] = (paymentsMap[mode] ?? 0.0) + amount; // Additionner si plusieurs du même mode
      }
      
      // 🆕 Récupérer les noms des clients CREDIT
      Map<String, String>? creditClientNames;
      if (creditClients != null && creditClients.isNotEmpty) {
        creditClientNames = {};
        for (final entry in creditClients.entries) {
          try {
            final clientResponse = await ApiClient.dio.get('/api/credit/clients/${entry.value}');
            if (clientResponse.statusCode == 200) {
              final client = Map<String, dynamic>.from(clientResponse.data);
              creditClientNames[entry.key] = client['name'] ?? 'Client #${entry.value}';
            }
          } catch (e) {
            print('[PAYMENT] Erreur récupération nom client ${entry.value}: $e');
            creditClientNames[entry.key] = 'Client #${entry.value}';
          }
        }
      }
      
      setState(() {
        isSplitPayment = true;
        splitPayments = paymentsMap; // Pour l'affichage
        splitCreditClients = creditClients;
        splitCreditClientNames = creditClientNames;
        selectedPaymentMode = 'SPLIT'; // Mode spécial pour indiquer paiement divisé
        // 🆕 Stocker la liste complète de transactions pour l'envoi au backend
        _splitPaymentTransactions = transactions;
      });
      // 🆕 Appeler _updatePaymentForNote() pour mettre à jour l'état (comme pour paiement simple)
      _updatePaymentForNote();
      print('[PAYMENT] 💬 État mis à jour: isSplitPayment=$isSplitPayment, ${transactions.length} transactions');
      print('[PAYMENT] 💬 isPaymentValid après mise à jour: $isPaymentValid');
      } else {
        print('[PAYMENT] 💬 ⚠️ Résultat invalide: transactions est null ou vide');
      }
    } else {
      print('[PAYMENT] 💬 Dialog fermé sans résultat valide');
    }
  }
  
  // 🆕 Stocker la liste complète de transactions pour l'envoi au backend
  List<Map<String, dynamic>>? _splitPaymentTransactions;
  
  // 🆕 Montant réel saisi pour paiement scriptural simple (non divisé)
  double? _scripturalEnteredAmount;

  // 🆕 Variable pour stocker le client sélectionné pour crédit
  Map<String, dynamic>? _selectedClientForCredit;
  
  // 🆕 Dialog pour saisir le montant réel pour paiement scriptural (CARTE/CHEQUE/TPE)
  Future<void> _showScripturalAmountDialog(String mode) async {
    final amountController = TextEditingController(text: finalTotal.toStringAsFixed(3));
    final modeLabel = mode == 'CARTE' ? 'Carte' : mode == 'CHEQUE' ? 'Chèque' : 'TPE';
    
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Material(
                  type: MaterialType.card,
                  borderRadius: BorderRadius.circular(8),
                  elevation: 8,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Montant $modeLabel',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Total à payer: ${finalTotal.toStringAsFixed(3)} TND',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        VirtualKeyboardTextField(
                          controller: amountController,
                          keyboardType: VirtualKeyboardType.numericDecimal,
                          decoration: InputDecoration(
                            labelText: 'Montant réellement encaissé (TND)',
                            hintText: 'Peut être supérieur au total (pourboire)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                          autofocus: true,
                          onChanged: (value) {
                            setDialogState(() {}); // Mettre à jour l'affichage du pourboire
                          },
                          onTap: () {
                            // 🆕 Vider le champ quand on clique dessus pour faciliter la saisie
                            if (amountController.text == finalTotal.toStringAsFixed(3)) {
                              amountController.clear();
                              setDialogState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final entered = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
                            final excess = entered > finalTotal ? entered - finalTotal : 0.0;
                            if (excess > 0.01) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.money, size: 16, color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Pourboire: ${excess.toStringAsFixed(3)} DT',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  selectedPaymentMode = 'ESPECE';
                                  _scripturalEnteredAmount = null;
                                });
                                Navigator.of(context).pop(false);
                              },
                              child: const Text('Annuler'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
                                if (amount >= finalTotal) {
                                  Navigator.of(context).pop(true);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Le montant doit être au moins égal au total (${finalTotal.toStringAsFixed(3)} TND)'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Valider'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    
    if (result == true) {
      final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? finalTotal;
      setState(() {
        _scripturalEnteredAmount = amount;
      });
      _updatePaymentForNote();
    }
  }

  // 🆕 Sélectionner le client pour crédit (sans traiter immédiatement)
  void _selectClientForCredit(Map<String, dynamic> client, double amount) {
    setState(() {
      _selectedClientForCredit = client;
    });
    Navigator.of(context).pop(); // Fermer le dialog
    // Le bouton "Valider" apparaîtra maintenant
  }

  // 🆕 Recharger le balance du client après paiement crédit (avec retry)
  Future<void> _reloadClientBalance(String clientId) async {
    // ⚠️ IMPORTANT : Faire plusieurs tentatives car le serveur peut avoir besoin de temps
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        // Attendre progressivement plus longtemps à chaque tentative
        await Future.delayed(Duration(milliseconds: 300 + (attempt * 200)));
        
        final response = await ApiClient.dio.get('/api/credit/clients/$clientId');
        if (response.statusCode == 200 && mounted) {
          final updatedClient = Map<String, dynamic>.from(response.data);
          final newBalance = (updatedClient['balance'] as num?)?.toDouble() ?? 0.0;
          print('[CREDIT] ✅ Balance rechargé (tentative ${attempt + 1}): $newBalance TND pour client $clientId');
          return; // Succès, sortir
        }
      } catch (e) {
        print('[CREDIT] ⚠️ Erreur rechargement balance (tentative ${attempt + 1}): $e');
        if (attempt == 2) {
          print('[CREDIT] ❌ Échec après 3 tentatives pour client $clientId');
        }
      }
    }
  }

  // 🆕 Traiter le paiement crédit client (créer uniquement la transaction de crédit)
  Future<void> _processCreditPayment(Map<String, dynamic> client, double amount) async {
      // Calculer exactement les articles à payer selon la sélection courante
    final itemsToPay = PaymentValidationService.getItemsToPay(
      selectedNoteForPayment: selectedNoteForPayment,
      selectedPartialQuantities: selectedPartialQuantities,
      organizedItemsForPartialPayment: organizedItemsForPartialPayment,
      mainNote: widget.mainNote,
      subNotes: widget.subNotes,
      getAllItemsOrganized: getAllItemsOrganized,
    );

            // 🆕 Extraction des orderIds pour traçabilité crédit/commandes
      final Set<int> paidOrderIds = itemsToPay
          .where((it) => it['orderId'] != null)
          .map<int>((it) => it['orderId'] as int)
          .toSet();

    // Appeler l'API pour ajouter la transaction DEBIT
    await PaymentService.processCreditPayment(
      clientId: client['id'].toString(),
      tableNumber: widget.tableNumber,
      amount: amount,
      description: 'Table ${widget.tableNumber} - ${_getPaymentDescription()}',
      paidOrderIds: paidOrderIds,
      ticketItems: itemsToPay,
      serverName: widget.currentServer,
    );
  }

  // 🆕 Obtenir la description du paiement
  String _getPaymentDescription() {
    if (selectedNoteForPayment == 'all') {
      return 'Paiement complet';
    } else if (selectedNoteForPayment == 'main') {
      return 'Note principale';
    } else if (selectedNoteForPayment.startsWith('sub_')) {
      final note = widget.subNotes.firstWhere(
        (n) => n.id == selectedNoteForPayment,
        orElse: () => OrderNote(id: '', name: 'Inconnu', covers: 1, items: [], total: 0.0),
      );
      return 'Note ${note.name}';
    } else if (selectedNoteForPayment == 'partial') {
      return 'Paiement partiel';
    }
    return 'Commande';
  }
}
