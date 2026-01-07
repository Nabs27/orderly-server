/// Modèle de données pour les KPI du dashboard admin
class KpiModel {
  // KPI financiers
  final double chiffreAffaire;
  final double totalRecette;
  final double totalRemises;
  final int nombreRemises;
  
  // KPI opérationnels
  final int nombreCouverts;
  final int nombreTickets;
  final int tablesNonPayees;
  final double montantTablesNonPayees;
  
  // KPI produits
  final String topProduit;
  final double topProduitValeur;
  final String topCategorie;
  final double topCategorieValeur;
  
  // KPI paiements
  final String modePaiementPrincipal;
  final double modePaiementPrincipalMontant;
  final int modePaiementPrincipalCount;
  final double tauxRemise;
  
  // KPI crédit client
  final double soldeCredit;
  final double totalDettes;
  final double totalPaiements;
  final int clientsAvecCredit;
  
  // KPI annulations
  final int nombreAnnulations;
  final double montantRembourse;
  final double coutPertes;
  final int nombreRemakes;
  
  // KPI enrichis
  final double panierMoyen;
  final int nombreArticles;
  final String serveurLePlusActif;
  final int nombreSousNotes;
  final Map<String, double> repartitionPaiements; // Mode -> pourcentage
  final List<Map<String, dynamic>> creditClients;
  final List<Map<String, dynamic>> recentCreditTransactions;
  final List<Map<String, dynamic>> discountDetails;
  
  // 🆕 Données enrichies pour les dialogs
  final List<Map<String, dynamic>> unpaidTablesDetails; // Tables non encaissées avec tickets provisoires
  final List<Map<String, dynamic>> paidPayments; // Paiements encaissés avec tickets
  
  KpiModel({
    required this.chiffreAffaire,
    required this.totalRecette,
    required this.totalRemises,
    required this.nombreRemises,
    required this.nombreCouverts,
    required this.nombreTickets,
    required this.tablesNonPayees,
    required this.montantTablesNonPayees,
    required this.topProduit,
    required this.topProduitValeur,
    required this.topCategorie,
    required this.topCategorieValeur,
    required this.modePaiementPrincipal,
    required this.modePaiementPrincipalMontant,
    required this.modePaiementPrincipalCount,
    required this.tauxRemise,
    required this.soldeCredit,
    required this.totalDettes,
    required this.totalPaiements,
    required this.clientsAvecCredit,
    required this.nombreAnnulations,
    required this.montantRembourse,
    required this.coutPertes,
    required this.nombreRemakes,
    required this.panierMoyen,
    required this.nombreArticles,
    required this.serveurLePlusActif,
    required this.nombreSousNotes,
    required this.repartitionPaiements,
    required this.creditClients,
    required this.recentCreditTransactions,
    required this.discountDetails,
    required this.unpaidTablesDetails,
    required this.paidPayments,
  });

  factory KpiModel.fromReportXData(Map<String, dynamic> reportData) {
    // 🆕 CORRECTION WEB : Convertir tous les objets JSON avec Map.from() pour Flutter Web
    // Sur Web, les objets JSON sont des _JsonMap qui ne peuvent pas être castés directement
    
    // Convertir summary
    dynamic summaryRaw = reportData['summary'];
    Map<String, dynamic> summary = {};
    if (summaryRaw != null && summaryRaw is Map) {
      summary = Map<String, dynamic>.from(summaryRaw);
    }
    
    // Convertir itemsByCategory
    dynamic itemsByCategoryRaw = reportData['itemsByCategory'];
    Map<String, dynamic> itemsByCategory = {};
    if (itemsByCategoryRaw != null) {
      if (itemsByCategoryRaw is Map) {
        itemsByCategory = Map<String, dynamic>.from(itemsByCategoryRaw);
      } else if (itemsByCategoryRaw is List) {
        itemsByCategory = {};
      }
    }
    
    // Convertir paymentsByMode
    dynamic paymentsByModeRaw = reportData['paymentsByMode'];
    Map<String, dynamic> paymentsByMode = {};
    if (paymentsByModeRaw != null && paymentsByModeRaw is Map) {
      paymentsByMode = Map<String, dynamic>.from(paymentsByModeRaw);
    }
    
    // Convertir unpaidTables
    dynamic unpaidTablesRaw = reportData['unpaidTables'];
    Map<String, dynamic> unpaidTables = {};
    if (unpaidTablesRaw != null && unpaidTablesRaw is Map) {
      unpaidTables = Map<String, dynamic>.from(unpaidTablesRaw);
    }
    
    // Convertir creditSummary
    dynamic creditSummaryRaw = reportData['creditSummary'];
    Map<String, dynamic> creditSummary = {};
    if (creditSummaryRaw != null && creditSummaryRaw is Map) {
      creditSummary = Map<String, dynamic>.from(creditSummaryRaw);
    }
    
    // Convertir cancellations
    dynamic cancellationsRaw = reportData['cancellations'];
    Map<String, dynamic> cancellations = {};
    if (cancellationsRaw != null && cancellationsRaw is Map) {
      cancellations = Map<String, dynamic>.from(cancellationsRaw);
    }
    
    // Convertir cancellationsSummary
    dynamic cancellationsSummaryRaw = cancellations['summary'];
    Map<String, dynamic> cancellationsSummary = {};
    if (cancellationsSummaryRaw != null && cancellationsSummaryRaw is Map) {
      cancellationsSummary = Map<String, dynamic>.from(cancellationsSummaryRaw);
    }

    // Calcul du top produit
    double topItemValue = 0.0;
    String topItemName = '—';
    itemsByCategory.forEach((_, categoryData) {
      // 🆕 Vérifier que categoryData est bien un Map
      if (categoryData is! Map) {
        print('[KPI] ⚠️ categoryData n\'est pas un Map: ${categoryData.runtimeType}');
        return;
      }
      final categoryMap = categoryData as Map<String, dynamic>;
      final itemsRaw = categoryMap['items'];
      final items = (itemsRaw is List) ? itemsRaw : <dynamic>[];
      
      for (final item in items) {
        if (item is! Map) {
          print('[KPI] ⚠️ item n\'est pas un Map: ${item.runtimeType}');
          continue;
        }
        final itemMap = item as Map<String, dynamic>;
        final total = (itemMap['total'] as num?)?.toDouble() ??
            ((itemMap['quantity'] as num?)?.toDouble() ?? 0.0) *
                ((itemMap['price'] as num?)?.toDouble() ?? 0.0);
        if (total > topItemValue) {
          topItemValue = total;
          topItemName = itemMap['name'] as String? ?? 'Article';
        }
      }
    });

    // Calcul du top catégorie
    double topCategoryValue = 0.0;
    String topCategoryName = '—';
    itemsByCategory.forEach((categoryName, categoryData) {
      // 🆕 Vérifier que categoryData est bien un Map
      if (categoryData is! Map) {
        print('[KPI] ⚠️ categoryData n\'est pas un Map pour catégorie $categoryName: ${categoryData.runtimeType}');
        return;
      }
      final categoryMap = categoryData as Map<String, dynamic>;
      final total = (categoryMap['totalValue'] as num?)?.toDouble() ?? 0.0;
      if (total > topCategoryValue) {
        topCategoryValue = total;
        topCategoryName = categoryName;
      }
    });

    // Calcul du mode de paiement principal
    String topPaymentMode = '—';
    double topPaymentAmount = 0.0;
    int topPaymentCount = 0;
    paymentsByMode.forEach((mode, data) {
      if (mode == 'NON PAYÉ') return; // Exclure les non payés
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      if (total > topPaymentAmount) {
        topPaymentAmount = total;
        topPaymentMode = mode;
        topPaymentCount = (data['count'] as int?) ?? 0;
      }
    });

    // 🆕 Calcul du nombre de tickets : utiliser nombreTickets du summary (qui regroupe les paiements divisés)
    // Si nombreTickets n'est pas disponible, fallback sur la somme des count (rétrocompatibilité)
    int totalTickets = (summary['nombreTickets'] as int?) ?? 0;
    if (totalTickets == 0) {
      // Fallback : calculer depuis paymentsByMode (pour rétrocompatibilité avec anciennes données)
      paymentsByMode.forEach((mode, data) {
        if (mode != 'NON PAYÉ') {
          final count = (data['count'] as int?) ?? 0;
          totalTickets += count;
        }
      });
    }

    // Calcul du taux de remise
    final ca = ((summary['chiffreAffaire'] as num?)?.toDouble()) ?? 0.0;
    final remises = ((summary['totalRemises'] as num?)?.toDouble()) ?? 0.0;
    final tauxRemise = (ca > 0 && remises > 0) ? ((remises / ca) * 100) : 0.0;

    // Données crédit client
    // 🆕 Utiliser totalDebitsInPeriod (dettes créées dans la période) au lieu de totalBalance (solde qui peut être négatif)
    // Le KPI doit afficher les dettes créées aujourd'hui, pas le solde (qui peut être négatif si des remboursements dépassent les nouvelles dettes)
    // 🆕 DEBUG: Log pour vérifier ce qui est reçu du backend
    print('[KPI Android] creditSummary keys: ${creditSummary.keys.toList()}');
    print('[KPI Android] totalDebitsInPeriod: ${creditSummary['totalDebitsInPeriod']}');
    print('[KPI Android] totalAmount: ${creditSummary['totalAmount']}');
    print('[KPI Android] totalDebit: ${creditSummary['totalDebit']}');
    print('[KPI Android] totalCredit: ${creditSummary['totalCredit']}');
    final creditBalance = (creditSummary['totalDebitsInPeriod'] as num?)?.toDouble() 
        ?? (creditSummary['totalAmount'] as num?)?.toDouble() 
        ?? 0.0;
    print('[KPI Android] creditBalance calculé: $creditBalance');
    final totalDebit = (creditSummary['totalDebit'] as num?)?.toDouble() ?? 0.0;
    final totalCredit = (creditSummary['totalCredit'] as num?)?.toDouble() ?? 0.0;
    final clients = (creditSummary['clients'] as List<dynamic>?) ?? [];
    final clientsAvecCredit = clients.where((c) {
      final balance = (c['balance'] as num?)?.toDouble() ?? 0.0;
      return balance > 0;
    }).length;

    // Tables non payées
    final unpaidCount = (unpaidTables['count'] as int?) ?? 0;
    final unpaidTotal = (unpaidTables['total'] as num?)?.toDouble() ?? 0.0;
    final unpaidTablesDetails = ((unpaidTables['details'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
    
    // 🆕 Paiements encaissés avec tickets
    final paidPayments = ((reportData['paidPayments'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();

    // Calcul du panier moyen (garantir un double non-null)
    double panierMoyen = 0.0;
    if (totalTickets > 0 && ca > 0) {
      panierMoyen = ca / totalTickets;
    }

    // Nombre d'articles vendus
    final nombreArticles = (summary['nombreArticles'] as int?) ?? 0;

    // Serveur le plus actif (basé sur les remises ou paiements encaissés)
    final discountDetailsRaw = (reportData['discountDetails'] as List<dynamic>?) ?? [];
    final serverActivity = <String, int>{};
    
    // 🆕 Compter les serveurs depuis les remises
    discountDetailsRaw.forEach((discount) {
      if (discount is Map) {
        final server = (discount['server'] as String?) ?? 'unknown';
        if (server != 'unknown') {
          serverActivity[server] = (serverActivity[server] ?? 0) + 1;
        }
      }
    });
    
    // 🆕 Si pas de remises, utiliser les paiements encaissés (paidPayments contient le champ 'server')
    if (serverActivity.isEmpty) {
      final paidPaymentsRaw = (reportData['paidPayments'] as List<dynamic>?) ?? [];
      paidPaymentsRaw.forEach((payment) {
        if (payment is Map) {
          final server = (payment['server'] as String?) ?? 'unknown';
          if (server != 'unknown') {
            serverActivity[server] = (serverActivity[server] ?? 0) + 1;
          }
        }
      });
    }
    String serveurLePlusActif = '—';
    int maxActivity = 0;
    serverActivity.forEach((server, count) {
      if (count > maxActivity) {
        maxActivity = count;
        serveurLePlusActif = server;
      }
    });

    // Compter les sous-notes
    int nombreSousNotes = 0;
    discountDetailsRaw.forEach((discount) {
      if ((discount['isSubNote'] as bool?) == true) {
        nombreSousNotes++;
      }
    });

    // Répartition des modes de paiement (en pourcentage)
    final repartitionPaiements = <String, double>{};
    double totalPaiements = 0.0;
    paymentsByMode.forEach((mode, data) {
      if (mode != 'NON PAYÉ') {
        final total = (data['total'] as num?)?.toDouble() ?? 0.0;
        totalPaiements += total;
      }
    });
    if (totalPaiements > 0) {
      paymentsByMode.forEach((mode, data) {
        if (mode != 'NON PAYÉ') {
          final total = (data['total'] as num?)?.toDouble() ?? 0.0;
          repartitionPaiements[mode] = (total / totalPaiements) * 100;
        }
      });
    }

    return KpiModel(
      chiffreAffaire: ca,
      totalRecette: (summary['totalRecette'] as num?)?.toDouble() ?? 0.0,
      totalRemises: remises,
      nombreRemises: (summary['nombreRemises'] as int?) ?? 0,
      nombreCouverts: (summary['nombreCouverts'] as int?) ?? 0,
      nombreTickets: totalTickets,
      tablesNonPayees: unpaidCount,
      montantTablesNonPayees: unpaidTotal,
      topProduit: topItemName,
      topProduitValeur: topItemValue,
      topCategorie: topCategoryName,
      topCategorieValeur: topCategoryValue,
      modePaiementPrincipal: topPaymentMode,
      modePaiementPrincipalMontant: topPaymentAmount,
      modePaiementPrincipalCount: topPaymentCount,
      tauxRemise: tauxRemise,
      soldeCredit: creditBalance,
      totalDettes: totalDebit,
      totalPaiements: totalCredit,
      clientsAvecCredit: clientsAvecCredit,
      nombreAnnulations: (cancellationsSummary['nombreAnnulations'] as int?) ?? 0,
      montantRembourse: (cancellationsSummary['montantTotalRembourse'] as num?)?.toDouble() ?? 0.0,
      coutPertes: (cancellationsSummary['coutTotalPertes'] as num?)?.toDouble() ?? 0.0,
      nombreRemakes: (cancellationsSummary['nombreRemakes'] as int?) ?? 0,
      panierMoyen: panierMoyen,
      nombreArticles: nombreArticles,
      serveurLePlusActif: serveurLePlusActif,
      nombreSousNotes: nombreSousNotes,
      repartitionPaiements: repartitionPaiements,
      creditClients: clients.cast<Map<String, dynamic>>(),
      recentCreditTransactions: ((creditSummary['recentTransactions'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>(),
      discountDetails: discountDetailsRaw.cast<Map<String, dynamic>>(),
      unpaidTablesDetails: unpaidTablesDetails,
      paidPayments: paidPayments,
    );
  }
}

