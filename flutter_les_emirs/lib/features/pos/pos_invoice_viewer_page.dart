import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PosInvoiceViewerPage extends StatefulWidget {
  final String tableNumber;
  final String companyName;
  final List<Map<String, dynamic>> items;
  final double total;
  final double amountPerPerson;
  final int covers;
  final String paymentMode;
  final String pdfUrl;

  const PosInvoiceViewerPage({
    super.key,
    required this.tableNumber,
    required this.companyName,
    required this.items,
    required this.total,
    required this.amountPerPerson,
    required this.covers,
    required this.paymentMode,
    required this.pdfUrl,
  });

  @override
  State<PosInvoiceViewerPage> createState() => _PosInvoiceViewerPageState();
}

class _PosInvoiceViewerPageState extends State<PosInvoiceViewerPage> {
  @override
  void initState() {
    super.initState();
    print('[INVOICE] Invoice viewer page initialized');
    print('[INVOICE] Table: ${widget.tableNumber}');
    print('[INVOICE] Total: ${widget.total}');
    print('[INVOICE] Items count: ${widget.items.length}');
  }

  @override
  Widget build(BuildContext context) {
    print('[INVOICE] Building invoice viewer page');
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('FACTURE - Table ${widget.tableNumber}'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.receipt_long,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                'FACTURE GÉNÉRÉE !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Text('Table: ${widget.tableNumber}'),
                    const SizedBox(height: 8),
                    Text('Total: ${widget.total.toStringAsFixed(2)} TND'),
                    const SizedBox(height: 8),
                    Text('Société: ${widget.companyName}'),
                    const SizedBox(height: 8),
                    Text('Articles: ${widget.items.length}'),
                    const SizedBox(height: 8),
                    Text('Couverts: ${widget.covers}'),
                    const SizedBox(height: 8),
                    Text('Mode: ${widget.paymentMode}'),
                    const SizedBox(height: 8),
                    Text('PDF: ${widget.pdfUrl}'),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        print('[INVOICE] Ouverture PDF: ${widget.pdfUrl}');
                        // Ouvrir le PDF dans le navigateur
                        final fullUrl = 'http://localhost:3000${widget.pdfUrl}';
                        print('[INVOICE] URL complète: $fullUrl');
                        
                        try {
                          final uri = Uri.parse(fullUrl);
                          if (await canLaunchUrl(uri)) {
                            // Ouvrir directement dans l'impression Windows
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                            print('[INVOICE] PDF ouvert avec succès - page d\'impression Windows');
                          } else {
                            print('[INVOICE] Impossible d\'ouvrir le PDF');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Impossible d\'ouvrir le PDF'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          print('[INVOICE] Erreur ouverture PDF: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        print('[INVOICE] Retour au plan de salle');
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
