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
      s.on('connect', (_) => print('[KPI] Socket connecté'));
      
      // Rafraîchir sur toute activité pertinente
      void refresh(_) {
        print('[KPI] Activité détectée, rafraîchissement...');
        _loadKpis();
      }

      s.on('order:updated', refresh);
      s.on('order:new', refresh);
      s.on('order:archived', refresh);
      s.on('table:payment', refresh);
      s.on('sync:stats', refresh); // Événement spécifique si implémenté

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
    setState(() {
      _loading = true;
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
        'iconColor': Colors.green.withValues(alpha: 0.7),
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
        'iconColor': Colors.amber.withValues(alpha: 0.7),
        'onTap': () => _showDiscountDetails(context, kpis),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Optimisation pour mobile : 2 colonnes minimum pour éviter le scroll vertical excessif
        final width = constraints.maxWidth;
        final columns = width >= 1200
            ? 5 // Desktop large : tout sur une ligne
            : width >= 800
                ? 3 // Tablette : 3 par ligne
                : 2; // Mobile : 2 par ligne (plus compact)
        
        final cardWidth = (width - (columns - 1) * 8) / columns; // Marge réduite (8 au lieu de 12)

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Marges réduites
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Suppression du titre "Pilotage express" et bouton "Actualiser" (demande user)
              Wrap(
                spacing: 8, // Espacement réduit
                runSpacing: 8, // Espacement réduit
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

class _KpiCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6), // Réduit
        Text(
          title,
          style: TextStyle(
            fontSize: 13, // Réduit
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10, // Réduit
            color: Colors.grey.shade600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12), // Padding réduit (était 18)
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16), // Rayon réduit
          border: Border.all(color: iconColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10, // Ombre réduite
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            cardContent,
            if (onTap != null)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(Icons.touch_app, size: 14, color: iconColor.withValues(alpha: 0.5)),
              ),
          ],
        ),
      ),
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


