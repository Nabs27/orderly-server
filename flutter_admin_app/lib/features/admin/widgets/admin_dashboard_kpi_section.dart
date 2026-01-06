import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/api_client.dart';
import '../models/kpi_model.dart';
import '../services/kpi_service.dart';
import '../pages/ca_details_page.dart';
import '../pages/credit_details_page.dart';
import '../pages/discount_details_page.dart';
import '../pages/unpaid_tables_page.dart';
import '../pages/paid_history_page.dart';

class AdminDashboardKpiSection extends StatefulWidget {
  const AdminDashboardKpiSection({super.key});

  @override
  AdminDashboardKpiSectionState createState() => AdminDashboardKpiSectionState();
}

class AdminDashboardKpiSectionState extends State<AdminDashboardKpiSection> {
  KpiModel? _kpis;
  bool _loading = true;
  String? _error;
  io.Socket? socket;

  @override
  void initState() {
    super.initState();
    _loadKpis();
    _connectSocket();
  }

  @override
  void dispose() {
    socket?.dispose();
    super.dispose();
  }

  void _connectSocket() {
    try {
      final base = ApiClient.dio.options.baseUrl;
      final uri = base.replaceAll(RegExp(r"/+\$"), '');
      final s = io.io(uri, io.OptionBuilder().setTransports(['websocket']).setExtraHeaders({'Origin': uri}).build());
      socket = s;
      
      // Écouter les mises à jour
      s.on('connect', (_) {
        print('[KPI] Socket connecté');
        s.emit('client:identify', {
          'type': 'admin-dashboard',
          'timestamp': DateTime.now().toIso8601String(),
        });
      });
      
      // Rafraîchir sur toute activité pertinente
      void refresh(_) {
        print('[KPI] Activité détectée, rafraîchissement...');
        _loadKpis();
      }

      s.on('order:updated', refresh);
      s.on('order:new', refresh);
      s.on('order:archived', refresh);
      s.on('table:payment', refresh);
      s.on('sync:stats', refresh);

      s.connect();
    } catch (e) {
      print('[KPI] Erreur connexion socket: $e');
    }
  }

  Future<void> refresh() async {
    await _loadKpis();
  }

  Future<void> _loadKpis() async {
    if (!mounted) return;
    
    // N'afficher le squelette de chargement que si on n'a pas encore de données
    final isInitialLoad = _kpis == null;
    
    setState(() {
      if (isInitialLoad) _loading = true;
      _error = null;
    });

    try {
      final kpis = await KpiService.loadTodayKpis();
      if (!mounted) return;
      setState(() {
        _kpis = kpis;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          height: 90,
          child: Row(
            children: const [
              Expanded(child: _KpiSkeleton()),
              SizedBox(width: 12),
              Expanded(child: _KpiSkeleton()),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: Text('Erreur KPIs: $_error')),
                TextButton.icon(
                  onPressed: _loadKpis,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_kpis == null) {
      return const SizedBox.shrink();
    }

    final kpis = _kpis!;

    final cards = <Map<String, dynamic>>[
      {
        'title': 'CA du jour',
        'value': _formatCurrency(kpis.chiffreAffaire),
        'subtitle': 'Chiffre d\'affaires brut',
        'icon': Icons.trending_up,
        'color': const LinearGradient(colors: [Color(0xFFDCE9FF), Color(0xFFEEF4FF)]),
        'iconColor': Colors.blue.shade600,
        'onTap': () => _showCaDetails(context, kpis),
      },
      {
        'title': 'Recette encaissée',
        'value': _formatCurrency(kpis.totalRecette),
        'subtitle': 'Encaissements nets',
        'icon': Icons.payments,
        'color': const LinearGradient(colors: [Color(0xFFDDF7E3), Color(0xFFF2FFF2)]),
        'iconColor': Colors.green.shade700,
        'onTap': () => _showPaidHistory(context, kpis),
      },
      {
        'title': 'Recette non encaissée',
        'value': _formatCurrency(kpis.montantTablesNonPayees),
        'subtitle': '${kpis.tablesNonPayees} table(s) actives',
        'icon': Icons.table_restaurant,
        'color': const LinearGradient(colors: [Color(0xFFFFE0D5), Color(0xFFFFF1EA)]),
        'iconColor': Colors.deepOrange.shade600,
        'onTap': () => _showUnpaidTables(context, kpis),
      },
      {
        'title': 'Crédit client',
        'value': _formatCurrency(kpis.soldeCredit),
        'subtitle': '${kpis.clientsAvecCredit} client(s) en dette',
        'icon': Icons.account_balance_wallet,
        'color': LinearGradient(
          colors: [
            kpis.soldeCredit > 0 ? const Color(0xFFFFE2E0) : const Color(0xFFE0F9F4),
            kpis.soldeCredit > 0 ? const Color(0xFFFFF0EF) : const Color(0xFFF2FFFC),
          ],
        ),
        'iconColor': kpis.soldeCredit > 0 ? Colors.red.shade600 : Colors.teal.shade600,
        'onTap': () => _showCreditDetails(context, kpis),
      },
      {
        'title': 'Taux de remise',
        'value': _formatCurrency(kpis.totalRemises),
        'subtitle': '${kpis.tauxRemise.toStringAsFixed(1)}% • ${kpis.nombreRemises} remise(s)',
        'icon': Icons.percent,
        'color': const LinearGradient(colors: [Color(0xFFFFF0C2), Color(0xFFFFF7E1)]),
        'iconColor': Colors.amber.shade700,
        'onTap': () => _showDiscountDetails(context, kpis),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Retour au style "large" (1 colonne sur mobile) pour maximiser la lisibilité
        // mais avec une hauteur réduite grâce au layout horizontal des cartes
        final columns = width >= 1200
            ? 3 // Desktop : 3 colonnes
            : width >= 700
                ? 2 // Tablette : 2 colonnes
                : 1; // Mobile : 1 colonne (Pleine largeur)
        
        final cardWidth = (width - (columns - 1) * 8) / columns;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Marges ajustées
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12, // Espacement horizontal
                runSpacing: 16, // Espacement vertical augmenté pour aérer
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          title: card['title'] as String,
                          value: card['value'] as String,
                          subtitle: card['subtitle'] as String,
                          icon: card['icon'] as IconData,
                          gradient: card['color'] as LinearGradient,
                          iconColor: card['iconColor'] as Color,
                          onTap: card['onTap'] as VoidCallback?,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    ) + ' TND';
  }

  void _showCaDetails(BuildContext context, KpiModel kpis) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaDetailsPage(
          ca: kpis.chiffreAffaire,
          nombreTickets: kpis.nombreTickets,
          panierMoyen: kpis.panierMoyen,
        ),
      ),
    );
  }

  void _showCreditDetails(BuildContext context, KpiModel kpis) {
    if (kpis.creditClients.isEmpty && kpis.recentCreditTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun mouvement de crédit pour la période.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreditDetailsPage(
          totalDebit: kpis.totalDettes,
          totalCredit: kpis.totalPaiements,
          totalBalance: kpis.soldeCredit,
          clients: kpis.creditClients,
          recentTransactions: kpis.recentCreditTransactions,
        ),
      ),
    );
  }

  void _showDiscountDetails(BuildContext context, KpiModel kpis) {
    if (kpis.discountDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune remise appliquée sur cette période.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiscountDetailsPage(
          discountDetails: kpis.discountDetails,
        ),
      ),
    );
  }

  void _showUnpaidTables(BuildContext context, KpiModel kpis) {
    if (kpis.unpaidTablesDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toutes les tables sont encaissées.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnpaidTablesPage(
          unpaidTables: kpis.unpaidTablesDetails,
        ),
      ),
    );
  }

  void _showPaidHistory(BuildContext context, KpiModel kpis) {
    if (kpis.paidPayments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun paiement encaissé sur cette période.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaidHistoryPage(
          paidPayments: kpis.paidPayments,
        ),
      ),
    );
  }
}

class _KpiCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final Color iconColor;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.iconColor,
    this.onTap,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant _KpiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Déclencher le pulse si la valeur change
    if (oldWidget.value != widget.value) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        // Overlay de flash qui s'estompe
        final flashOpacity = (1.0 - _pulseAnimation.value) * 0.4 * (_pulseController.isAnimating ? 1.0 : 0.0);
        
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.iconColor.withOpacity(
                  0.15 + (flashOpacity * 0.5), // Le bord s'illumine aussi
                ),
                width: 1.0 + (flashOpacity * 2),
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.iconColor.withOpacity(0.06 + (flashOpacity * 0.2)),
                  blurRadius: 10 + (flashOpacity * 10),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Fond de flash blanc discret
                if (flashOpacity > 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(flashOpacity),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                
                Row(
                  children: [
                    // Zone Icône
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: widget.iconColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    // Zone Texte
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.value,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.onTap != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: widget.iconColor.withOpacity(0.4),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 12, width: 40, color: Colors.white),
          const SizedBox(height: 8),
          Container(height: 16, width: 120, color: Colors.white),
          const SizedBox(height: 6),
          Container(height: 12, width: 80, color: Colors.white),
        ],
      ),
    );
  }
}


