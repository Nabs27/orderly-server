import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadKpis();
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
        final columns = width >= 1200
            ? 4
            : width >= 900
                ? 3
                : width >= 600
                    ? 2
                    : 1;
        final cardWidth = (width - (columns - 1) * 12) / columns;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Pilotage express',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _loadKpis,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualiser'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: columns == 1 ? double.infinity : cardWidth,
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
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: iconColor.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
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
                child: Icon(Icons.touch_app, size: 16, color: iconColor.withOpacity(0.5)),
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


