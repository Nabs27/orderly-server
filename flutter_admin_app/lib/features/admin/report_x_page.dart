import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/auth_service.dart';

class ReportXPage extends StatefulWidget {
  const ReportXPage({super.key});

  @override
  State<ReportXPage> createState() => _ReportXPageState();
}

class _ReportXPageState extends State<ReportXPage> {
  Map<String, dynamic>? reportData;
  bool loading = false;
  String? error;
  
  // Paramètres de filtrage
  String? selectedServer;
  String selectedPeriod = 'ALL';
  DateTime? dateFrom;
  DateTime? dateTo;
  
  final List<String> periods = ['ALL', 'MIDI', 'SOIR'];
  final List<String> servers = ['ALI', 'FATIMA', 'MOHAMED']; // À adapter selon vos serveurs

  @override
  void initState() {
    super.initState();
    // 🆕 Initialiser les dates à aujourd'hui par défaut
    final now = DateTime.now();
    dateFrom = DateTime(now.year, now.month, now.day);
    dateTo = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    // 🆕 Charger automatiquement le rapport d'aujourd'hui
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReport();
    });
  }

  Future<void> _loadReport() async {
    setState(() {
      loading = true;
      error = null;
      reportData = null;
    });

    try {
      final queryParams = <String, dynamic>{};
      
      if (selectedServer != null && selectedServer!.isNotEmpty) {
        queryParams['server'] = selectedServer;
      }
      
      if (selectedPeriod != 'ALL') {
        queryParams['period'] = selectedPeriod;
      }
      
      if (dateFrom != null) {
        queryParams['dateFrom'] = dateFrom!.toIso8601String();
      }
      
      if (dateTo != null) {
        queryParams['dateTo'] = dateTo!.toIso8601String();
      }

      // Récupérer le token depuis AuthService
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Non authentifié. Veuillez vous reconnecter.');
      }
      
      final response = await ApiClient.dio.get(
        '/api/admin/report-x',
        queryParameters: queryParams,
        options: Options(
          headers: {'x-admin-token': token}
        ),
      );

      setState(() {
        reportData = response.data as Map<String, dynamic>;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
      
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

  Future<void> _selectDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dateFrom = picked;
      });
    }
  }

  Future<void> _selectDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateTo ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dateTo = picked;
      });
    }
  }

  // 🖨️ Imprimer le rapport X au format ticket de caisse
  Future<void> _printReport() async {
    try {
      // Construire l'URL avec les mêmes paramètres que le rapport
      final queryParams = <String, String>{};
      
      if (selectedServer != null && selectedServer!.isNotEmpty) {
        queryParams['server'] = selectedServer!;
      }
      
      if (selectedPeriod != 'ALL') {
        queryParams['period'] = selectedPeriod;
      }
      
      if (dateFrom != null) {
        queryParams['dateFrom'] = dateFrom!.toIso8601String();
      }
      
      if (dateTo != null) {
        queryParams['dateTo'] = dateTo!.toIso8601String();
      }

      // Construire l'URL complète
      final baseUrl = ApiClient.dio.options.baseUrl;
      
      // Ajouter le token admin dans les paramètres
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Non authentifié. Veuillez vous reconnecter.');
      }
      queryParams['x-admin-token'] = token;
      
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      final finalUrl = '$baseUrl/api/admin/report-x-ticket?$queryString';
      
      // Ouvrir l'URL dans une nouvelle fenêtre pour impression
      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Ouvre dans le navigateur par défaut
        );
        
        // Afficher un message pour guider l'utilisateur
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le ticket s\'ouvre dans votre navigateur. Utilisez Ctrl+P pour imprimer.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw 'Impossible d\'ouvrir l\'URL d\'impression';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'impression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printCreditReport() async {
    try {
      final queryParams = <String, String>{};
      
      if (selectedServer != null && selectedServer!.isNotEmpty) {
        queryParams['server'] = selectedServer!;
      }
      if (selectedPeriod != 'ALL') {
        queryParams['period'] = selectedPeriod;
      }
      if (dateFrom != null) {
        queryParams['dateFrom'] = dateFrom!.toIso8601String();
      }
      if (dateTo != null) {
        queryParams['dateTo'] = dateTo!.toIso8601String();
      }
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Non authentifié. Veuillez vous reconnecter.');
      }
      queryParams['x-admin-token'] = token;
      
      final baseUrl = ApiClient.dio.options.baseUrl;
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final finalUrl = '$baseUrl/api/admin/credit-report-ticket?$queryString';
      
      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le ticket crédit s\'ouvre dans votre navigateur. Utilisez Ctrl+P pour imprimer.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw 'Impossible d\'ouvrir l\'URL d\'impression';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'impression des crédits: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport X'),
        actions: [
          // 🖨️ Bouton d'impression
          if (reportData != null)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Imprimer le rapport',
              onPressed: _printReport,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: Column(
        children: [
          // Formulaire de sélection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paramètres du rapport',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedServer,
                        decoration: const InputDecoration(
                          labelText: 'Serveur',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tous')),
                          ...servers.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (value) => setState(() => selectedServer = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedPeriod,
                        decoration: const InputDecoration(
                          labelText: 'Période',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: periods.map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p),
                        )).toList(),
                        onChanged: (value) => setState(() => selectedPeriod = value ?? 'ALL'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDateFrom,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(dateFrom == null 
                          ? 'Date début' 
                          : '${dateFrom!.day}/${dateFrom!.month}/${dateFrom!.year}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDateTo,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(dateTo == null 
                          ? 'Date fin' 
                          : '${dateTo!.day}/${dateTo!.month}/${dateTo!.year}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : _loadReport,
                    icon: loading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long),
                    label: const Text('Générer le rapport'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Affichage du rapport
          Expanded(
            child: loading && reportData == null
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text('Erreur: $error', style: TextStyle(color: Colors.red.withValues(alpha: 0.7))),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadReport,
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : reportData == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Sélectionnez les paramètres et générez le rapport',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : _buildReportView(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportView() {
    final summary = reportData!['summary'] as Map<String, dynamic>? ?? {};
    final itemsByCategory = reportData!['itemsByCategory'] as Map<String, dynamic>? ?? {};
    final paymentsByMode = reportData!['paymentsByMode'] as Map<String, dynamic>? ?? {};
    final unpaidTables = reportData!['unpaidTables'] as Map<String, dynamic>? ?? {};
    final creditSummary = reportData!['creditSummary'] as Map<String, dynamic>?;
    
    final generatedAt = reportData!['generatedAt'] as String?;
    final server = reportData!['server'] as String? ?? 'TOUS';
    final period = reportData!['period'] as String? ?? 'ALL';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du ticket (style préaddition)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text(
                  'LES EMIRS RESTAURANT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text('73 348 700'),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'RAPPORT FINANCIER (X)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                if (generatedAt != null)
                  Text('Date: ${_formatDate(generatedAt)}'),
                Text('Serveur: $server'),
                Text('Période: $period'),
                const SizedBox(height: 8),
                const Divider(),
                
                // Résumé
                const SizedBox(height: 8),
                _buildSummaryRow('CHIFFRE D\'AFFAIRE', summary['chiffreAffaire'] ?? 0.0),
                _buildSummaryRow('TOTAL RECETTE', summary['totalRecette'] ?? 0.0),
                const SizedBox(height: 8),
                const Divider(),
                
                // 🆕 REMISES ACCORDÉES (section dédiée, cliquable pour voir les détails)
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: ((summary['totalRemises'] as num?)?.toDouble() ?? 0.0) > 0 
                    ? Colors.red.shade50 
                    : Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: ((summary['totalRemises'] as num?)?.toDouble() ?? 0.0) > 0 
                        ? Colors.red.shade300 
                        : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: ((summary['totalRemises'] as num?)?.toDouble() ?? 0.0) > 0 
                        ? Colors.red.shade300 
                        : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  leading: Icon(
                    Icons.local_offer,
                    size: 20,
                    color: ((summary['totalRemises'] as num?)?.toDouble() ?? 0.0) > 0 
                      ? Colors.red.withValues(alpha: 0.7) 
                      : Colors.grey.shade600,
                  ),
                  title: const Text(
                    'REMISES ACCORDÉES:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_formatNumber((summary['totalRemises'] as num?)?.toDouble() ?? 0.0)} TND',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ((summary['totalRemises'] as num?)?.toDouble() ?? 0.0) > 0 
                            ? Colors.red.withValues(alpha: 0.7) 
                            : Colors.grey.withValues(alpha: 0.7),
                        ),
                      ),
                      if (((summary['nombreRemises'] as num?)?.toInt() ?? 0) > 0) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.expand_more,
                          color: ((summary['totalRemises'] as num?)?.toDouble() ?? 0.0) > 0 
                            ? Colors.red.withValues(alpha: 0.7) 
                            : Colors.grey.shade600,
                        ),
                      ],
                    ],
                  ),
                  children: [
                    if (((summary['nombreRemises'] as num?)?.toInt() ?? 0) > 0) ...[
                      Text(
                        'Nombre de remises: ${summary['nombreRemises'] ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade600,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      // 🆕 Liste détaillée des remises
                      Builder(
                        builder: (context) {
                          if (reportData == null) {
                            return const SizedBox.shrink();
                          }
                          final discountDetails = (reportData!['discountDetails'] as List?);
                          if (discountDetails == null || discountDetails.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Aucun détail de remise disponible',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: discountDetails.map((discountData) {
                              final timestamp = discountData['timestamp'] as String? ?? '';
                              final table = discountData['table'] as String? ?? 'N/A';
                              final server = discountData['server'] as String? ?? 'unknown';
                              final noteName = discountData['noteName'] as String? ?? 'Note Principale';
                              final noteId = discountData['noteId'] as String?;
                              final subtotal = (discountData['subtotal'] as num?)?.toDouble() ?? 0.0;
                              final discountAmount = (discountData['discountAmount'] as num?)?.toDouble() ?? 0.0;
                              final discountValue = (discountData['discount'] as num?)?.toDouble() ?? 0.0;
                              final isPercent = discountData['isPercentDiscount'] as bool? ?? false;
                              final amount = (discountData['amount'] as num?)?.toDouble() ?? 0.0;
                              final paymentMode = discountData['paymentMode'] as String? ?? 'N/A';
                              final itemsCount = (discountData['itemsCount'] as num?)?.toInt() ?? 0;
                              
                              // 🆕 Déterminer le type de paiement (comme dans l'historique)
                              final isSubNote = discountData['isSubNote'] == true || (noteId != null && noteId.startsWith('sub_'));
                              final isMainNote = discountData['isMainNote'] == true || noteId == 'main' || noteId == null;
                              final isPartial = discountData['isPartial'] == true;
                              
                              // 🆕 Titre selon le type de paiement
                              String paymentTitle;
                              IconData paymentTypeIcon;
                              Color paymentTypeColor;
                              
                              if (isSubNote && noteName != null) {
                                paymentTitle = 'Sous-note: $noteName';
                                paymentTypeIcon = Icons.person;
                                paymentTypeColor = Colors.purple.withValues(alpha: 0.7);
                              } else if (isPartial && isMainNote) {
                                paymentTitle = 'Paiement partiel - Note principale';
                                paymentTypeIcon = Icons.payment;
                                paymentTypeColor = Colors.orange.withValues(alpha: 0.7);
                              } else if (isMainNote) {
                                paymentTitle = 'Note principale';
                                paymentTypeIcon = Icons.receipt;
                                paymentTypeColor = Colors.blue.withValues(alpha: 0.7);
                              } else {
                                paymentTitle = 'Ticket';
                                paymentTypeIcon = Icons.receipt;
                                paymentTypeColor = Colors.grey.withValues(alpha: 0.7);
                              }
                              
                              // Formater la date
                              String formattedDate = 'N/A';
                              try {
                                if (timestamp.isNotEmpty) {
                                  final date = DateTime.parse(timestamp);
                                  formattedDate = '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                }
                              } catch (e) {
                                formattedDate = timestamp;
                              }
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.red.shade200, width: 1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🆕 En-tête avec badge de type de paiement
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    paymentTypeIcon,
                                                    size: 16,
                                                    color: paymentTypeColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    paymentTitle,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: paymentTypeColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Table $table',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '-${_formatNumber(discountAmount)} TND',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          formattedDate,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '•',
                                          style: TextStyle(color: Colors.grey.shade400),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Serveur: $server',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Avant remise: ${_formatNumber(subtotal)} TND',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.withValues(alpha: 0.7),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '•',
                                          style: TextStyle(color: Colors.grey.shade400),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isPercent 
                                            ? 'Remise: ${discountValue.toStringAsFixed(1)}%'
                                            : 'Remise: ${_formatNumber(discountValue)} TND',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Après remise: ${_formatNumber(amount)} TND',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.green.withValues(alpha: 0.7),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '•',
                                          style: TextStyle(color: Colors.grey.shade400),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$paymentMode • $itemsCount article(s)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // 🆕 Afficher les articles du ticket (comme dans l'historique)
                                    if (discountData['items'] != null && 
                                        (discountData['items'] as List).isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      const Divider(height: 1),
                                      const SizedBox(height: 4),
                                      ...((discountData['items'] as List).map((item) {
                                        final itemName = item['name'] as String? ?? 'Article';
                                        final itemQuantity = (item['quantity'] as num?)?.toInt() ?? 0;
                                        final itemPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
                                        final itemTotal = itemQuantity * itemPrice;
                                        
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '$itemName x$itemQuantity',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${_formatNumber(itemTotal)} TND',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList()),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ] else ...[
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Aucune remise accordée',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                
                // 🆕 ANNULATIONS ET RETOURS (section dédiée, cliquable pour voir les détails)
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    if (reportData == null) {
                      return const SizedBox.shrink();
                    }
                    final cancellations = reportData!['cancellations'] as Map<String, dynamic>?;
                    if (cancellations == null) {
                      return const SizedBox.shrink();
                    }
                    final summary = cancellations['summary'] as Map<String, dynamic>? ?? {};
                    final details = cancellations['details'] as List? ?? [];
                    final nombreAnnulations = (summary['nombreAnnulations'] as num?)?.toInt() ?? 0;
                    final montantTotalRembourse = (summary['montantTotalRembourse'] as num?)?.toDouble() ?? 0.0;
                    final coutTotalPertes = (summary['coutTotalPertes'] as num?)?.toDouble() ?? 0.0;
                    final nombreReaffectations = (summary['nombreReaffectations'] as num?)?.toInt() ?? 0;
                    final nombreRemakes = (summary['nombreRemakes'] as num?)?.toInt() ?? 0; // 🆕 Nombre de remakes
                    
                    return ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: nombreAnnulations > 0 
                        ? Colors.orange.shade50 
                        : Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: nombreAnnulations > 0 
                            ? Colors.orange.shade300 
                            : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: nombreAnnulations > 0 
                            ? Colors.orange.shade300 
                            : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      leading: Icon(
                        Icons.cancel,
                        size: 20,
                        color: nombreAnnulations > 0 
                          ? Colors.orange.withValues(alpha: 0.7) 
                          : Colors.grey.shade600,
                      ),
                      title: const Text(
                        'ANNULATIONS ET RETOURS:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$nombreAnnulations',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: nombreAnnulations > 0 
                                ? Colors.orange.withValues(alpha: 0.7) 
                                : Colors.grey.withValues(alpha: 0.7),
                            ),
                          ),
                          if (nombreAnnulations > 0) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.expand_more,
                              color: Colors.orange.withValues(alpha: 0.7),
                            ),
                          ],
                        ],
                      ),
                      children: [
                        if (nombreAnnulations > 0) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Nombre d\'annulations:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange.withValues(alpha: 0.7),
                                  ),
                                ),
                                Text(
                                  nombreAnnulations.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (montantTotalRembourse > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Montant total remboursé:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    '${_formatNumber(montantTotalRembourse)} TND',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (coutTotalPertes > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Coût total des pertes:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    '${_formatNumber(coutTotalPertes)} TND',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (nombreReaffectations > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Nombre de réaffectations:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    nombreReaffectations.toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (nombreRemakes > 0) // 🆕 Afficher le nombre de remakes
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Nombre de plats refaits:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    nombreRemakes.toString(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          // Liste détaillée des annulations
                          ...details.map((cancellation) {
                            final timestamp = cancellation['timestamp'] as String? ?? '';
                            final orderCreatedAt = cancellation['orderCreatedAt'] as String?; // 🆕 Heure de création de la commande
                            final table = cancellation['table'] as String? ?? 'N/A';
                            final server = cancellation['server'] as String? ?? 'unknown';
                            final noteName = cancellation['noteName'] as String? ?? 'Note Principale';
                            final items = cancellation['items'] as List? ?? [];
                            final itemsTotal = (cancellation['itemsTotal'] as num?)?.toDouble() ?? 0.0;
                            final state = cancellation['state'] as String? ?? 'not_prepared';
                            final reason = cancellation['reason'] as String? ?? 'other';
                            final description = cancellation['description'] as String? ?? '';
                            final action = cancellation['action'] as String? ?? 'cancel';
                            final refundAmount = (cancellation['refundAmount'] as num?)?.toDouble() ?? 0.0;
                            final wasteCost = (cancellation['wasteCost'] as num?)?.toDouble() ?? 0.0;
                            final reassignment = cancellation['reassignment'] as Map<String, dynamic>?;
                            
                            // Labels pour état, raison, action
                            final stateLabels = {
                              'not_prepared': 'Non préparé',
                              'prepared_not_served': 'Préparé non servi',
                              'served_untouched': 'Servi non entamé',
                              'served_touched': 'Servi entamé',
                            };
                            final reasonLabels = {
                              'non_conformity': 'Non-conformité',
                              'quality': 'Qualité/Goût',
                              'delay': 'Délai',
                              'order_error': 'Erreur commande',
                              'client_dissatisfied': 'Client insatisfait',
                              'other': 'Autre',
                            };
                            final actionLabels = {
                              'cancel': 'Annulation',
                              'refund': 'Remboursement',
                              'replace': 'Remplacement',
                              'remake': 'Refaire',
                              'reassign': 'Réaffectation',
                            };
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // En-tête avec type de paiement
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.cancel_outlined,
                                        size: 18,
                                        color: Colors.orange.withValues(alpha: 0.7),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          noteName != 'Note Principale' ? 'Sous-note: $noteName' : 'Note principale',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Table $table',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // 🆕 Date de création de la commande et date d'annulation
                                  if (orderCreatedAt != null && orderCreatedAt.isNotEmpty) ...[
                                  Row(
                                    children: [
                                        Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                                        const SizedBox(width: 4),
                                      Text(
                                          'Commande: ${_formatDate(orderCreatedAt)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  // Date d'annulation et serveur
                                  Row(
                                    children: [
                                      Icon(Icons.cancel_outlined, size: 12, color: Colors.orange.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Annulé: ${_formatDate(timestamp)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '•',
                                        style: TextStyle(color: Colors.grey.shade400),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Serveur: $server',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Articles annulés
                                  ...items.map((item) {
                                    final itemName = item['name'] as String? ?? 'Article';
                                    final itemQuantity = (item['quantity'] as num?)?.toInt() ?? 0;
                                    final itemPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
                                    final itemTotal = itemQuantity * itemPrice;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$itemName x$itemQuantity',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${_formatNumber(itemTotal)} TND',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  // État, raison, action
                                  Row(
                                    children: [
                                      Chip(
                                        label: Text(
                                          stateLabels[state] ?? state,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        backgroundColor: Colors.blue.shade50,
                                        labelStyle: TextStyle(color: Colors.blue.withValues(alpha: 0.7)),
                                      ),
                                      const SizedBox(width: 4),
                                      Chip(
                                        label: Text(
                                          reasonLabels[reason] ?? reason,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        backgroundColor: Colors.grey.shade100,
                                        labelStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.7)),
                                      ),
                                      const SizedBox(width: 4),
                                      Chip(
                                        label: Text(
                                          actionLabels[action] ?? action,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        backgroundColor: Colors.green.shade50,
                                        labelStyle: TextStyle(color: Colors.green.withValues(alpha: 0.7)),
                                      ),
                                    ],
                                  ),
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Description: $description',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.withValues(alpha: 0.7),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  if (refundAmount > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Remboursé: ${_formatNumber(refundAmount)} TND',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                  if (wasteCost > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Coût de perte: ${_formatNumber(wasteCost)} TND',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                  if (reassignment != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.swap_horiz, size: 14, color: Colors.green.withValues(alpha: 0.7)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Réaffecté vers table ${reassignment['toTable']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Aucune annulation enregistrée',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Divider(),
                
                // Paiements par mode
                const SizedBox(height: 8),
                const Text(
                  'PAIEMENTS PAR MODE',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...paymentsByMode.entries.map((entry) {
                  final mode = entry.key;
                  final data = entry.value as Map<String, dynamic>;
                  final total = (data['total'] as num?)?.toDouble() ?? 0.0;
                  final count = data['count'] as int? ?? 0;
                  final payers = (data['payers'] as List<dynamic>?)?.cast<String>() ?? [];
                  
                  // 🆕 Détecter si c'est un paiement non payé
                  final isUnpaid = mode == 'NON PAYÉ';
                  
                  // 🆕 Construire le label avec le nom du payeur si disponible
                  String label = '$mode';
                  if (count > 0) {
                    label += '($count)';
                  }
                  if (payers.isNotEmpty && !isUnpaid) {
                    // Afficher les noms des payeurs (max 2 pour ne pas surcharger)
                    final payersDisplay = payers.length > 2 
                      ? '${payers.take(2).join(", ")}...' 
                      : payers.join(", ");
                    label += ' - $payersDisplay';
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$label:',
                            style: TextStyle(
                              fontSize: 12,
                              color: isUnpaid ? Colors.orange.withValues(alpha: 0.7) : null,
                              fontWeight: isUnpaid ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          '${_formatNumber(total)} TND',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isUnpaid ? Colors.orange.withValues(alpha: 0.7) : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Divider(),
                
                // Statistiques
                const SizedBox(height: 8),
                _buildSummaryRow('NOMBRE DE COUVERTS', summary['nombreCouverts'] ?? 0, isInteger: true),
                _buildSummaryRow('NOMBRE D\'ARTICLES', (summary['nombreArticles'] as num?)?.toInt() ?? 0, isInteger: true),
                const SizedBox(height: 8),
                const Divider(),
                
                // Articles par catégorie
                const SizedBox(height: 8),
                const Text(
                  'LECTURE DES VENTES PAR ARTICLE',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...itemsByCategory.entries.map((entry) {
                  final categoryName = entry.key;
                  final categoryData = entry.value as Map<String, dynamic>;
                  final items = categoryData['items'] as List<dynamic>? ?? [];
                  final totalQuantity = categoryData['totalQuantity'] as num? ?? 0;
                  final totalValue = categoryData['totalValue'] as num? ?? 0.0;
                  
                  // 🆕 Afficher le Total Famille directement (pas dans ExpansionTile)
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête de catégorie avec Total Famille visible
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              categoryName.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Total Famille: QTE: ${_formatQuantity(totalQuantity)}    Valeur: ${_formatNumber(totalValue.toDouble())}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Détails des articles (expandable)
                      ExpansionTile(
                        title: const Text(
                          'Détails des articles',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                        initiallyExpanded: false,
                        children: [
                          ...items.map((item) {
                            final itemMap = item as Map<String, dynamic>;
                            final name = itemMap['name'] as String? ?? '';
                            final quantity = itemMap['quantity'] as num? ?? 0;
                            final total = itemMap['total'] as num? ?? 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text('$name'),
                                  ),
                                  Text(
                                    'QTE: ${_formatQuantity(quantity)}    Valeur: ${_formatNumber((total as num?)?.toDouble() ?? 0.0)}',
                                    style: const TextStyle(fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
                
                _buildCreditSummaryCard(creditSummary),
                const SizedBox(height: 16),
                const Text(
                  'Merci de votre visite !',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditSummaryCard(Map<String, dynamic>? creditSummary) {
    final totalBalance = (creditSummary?['totalBalance'] as num?)?.toDouble()
        ?? (creditSummary?['totalAmount'] as num?)?.toDouble()
        ?? 0.0;
    final totalDebit = (creditSummary?['totalDebit'] as num?)?.toDouble() ?? 0.0;
    final totalCredit = (creditSummary?['totalCredit'] as num?)?.toDouble() ?? 0.0;
    final transactionsCount = (creditSummary?['transactionsCount'] as num?)?.toInt() ?? 0;
    final clients = (creditSummary?['clients'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final recentTransactions = (creditSummary?['recentTransactions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    
    final hasContent = totalDebit > 0 ||
        totalCredit > 0 ||
        totalBalance.abs() > 0.001 ||
        clients.isNotEmpty ||
        recentTransactions.isNotEmpty;
    if (!hasContent) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.credit_score, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Crédits clients',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _printCreditReport,
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimer'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _buildStatChip(
                      label: 'Dettes émises',
                      value: '${_formatNumber(totalDebit)} TND',
                      color: Colors.deepPurple.shade50,
                    ),
                    _buildStatChip(
                      label: 'Paiements reçus',
                      value: '${_formatNumber(totalCredit)} TND',
                      color: Colors.blue.shade50,
                    ),
                    _buildStatChip(
                      label: 'Solde en cours',
                      value: '${_formatNumber(totalBalance)} TND',
                      color: totalBalance >= 0 ? Colors.orange.shade50 : Colors.green.shade50,
                    ),
                    _buildStatChip(
                      label: 'Transactions période',
                      value: '$transactionsCount',
                      color: Colors.grey.shade200,
                    ),
                  ],
                ),
                if (clients.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Clients (top 5)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...clients.take(5).map((client) {
                    final name = client['clientName'] as String? ?? 'N/A';
                    final debit = (client['debitTotal'] as num?)?.toDouble() ?? 0.0;
                    final credit = (client['creditTotal'] as num?)?.toDouble() ?? 0.0;
                    final balance = (client['balance'] as num?)?.toDouble() ?? 0.0;
                    final count = (client['transactionsCount'] as num?)?.toInt() ?? 0;
                    final last = client['lastTransaction'] as String?;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        last != null ? 'Dernier: ${_formatDate(last)}' : 'Aucun mouvement récent',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Dette: ${_formatNumber(debit)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Payé: ${_formatNumber(credit)}', style: const TextStyle(fontSize: 12)),
                          Text(
                            'Solde: ${_formatNumber(balance)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: balance >= 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text('$count mouvement(s)', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    );
                  }),
                  if (clients.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${clients.length - 5} client(s) supplémentaires',
                        style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
                if (recentTransactions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Derniers mouvements',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...recentTransactions.take(5).map((tx) {
                    final name = tx['clientName'] as String? ?? 'N/A';
                    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                    final description = tx['description'] as String? ?? '';
                    final paymentMode = tx['paymentMode'] as String? ?? 'CREDIT';
                    final date = tx['date'] as String?;
                    final type = (tx['type'] as String? ?? 'CREDIT').toUpperCase();
                    final sign = type == 'DEBIT' ? '+' : '-';
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.receipt_long, size: 18),
                      title: Text('$name • $type', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (date != null)
                            Text(
                              _formatDate(date),
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$sign${_formatNumber(amount)} TND',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(paymentMode, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }),
                  if (recentTransactions.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+ ${recentTransactions.length - 5} mouvement(s) supplémentaires',
                        style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, dynamic value, {bool isDiscount = false, bool isInteger = false}) {
    final displayValue = isInteger 
      ? value.toString() 
      : '${_formatNumber((value as num?)?.toDouble() ?? 0.0)} TND';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDiscount ? Colors.red.withValues(alpha: 0.7) : null,
            ),
          ),
          Text(
            displayValue,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDiscount ? Colors.red.withValues(alpha: 0.7) : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(3).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  String _formatQuantity(num quantity) {
    return quantity.toStringAsFixed(3);
  }
}

