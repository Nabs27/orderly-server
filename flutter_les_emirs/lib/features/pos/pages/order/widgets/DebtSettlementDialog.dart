import 'package:flutter/material.dart';
import '../../../../../../core/api_client.dart';
import 'DebtPaymentDialog.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';

class DebtSettlementDialog extends StatefulWidget {
  final String currentServer;
  const DebtSettlementDialog({super.key, required this.currentServer});

  @override
  State<DebtSettlementDialog> createState() => DebtSettlementDialogState();
}

class DebtSettlementDialogState extends State<DebtSettlementDialog> {
  List<Map<String, dynamic>> clients = [];
  bool loading = true;
  String searchQuery = '';
  VirtualKeyboardType searchKeyboardType = VirtualKeyboardType.alpha; // 🆕 Type de clavier pour la recherche
  
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final response = await ApiClient.dio.get('/api/credit/clients');
      if (mounted) {
        setState(() {
          final allClients = List<Map<String, dynamic>>.from(response.data);
          // Filtrer uniquement les clients avec une dette (balance > 0)
          // Trier selon les bonnes pratiques :
          // 1. Par montant décroissant (plus grosses dettes en premier)
          // 2. Par date de dernière transaction croissante (plus anciennes en premier)
          clients = allClients
              .where((c) {
                final balance = (c['balance'] as num?)?.toDouble() ?? 0.0;
                return balance > 0.001; // Tolérance pour les erreurs de virgule flottante
              })
              .toList()
            ..sort((a, b) {
              final balanceA = (a['balance'] as num?)?.toDouble() ?? 0.0;
              final balanceB = (b['balance'] as num?)?.toDouble() ?? 0.0;
              
              // 1. Trier par montant décroissant (plus grosses dettes en premier)
              final balanceComparison = balanceB.compareTo(balanceA);
              if (balanceComparison != 0) return balanceComparison;
              
              // 2. Si même montant, trier par date de dernière transaction croissante (plus anciennes en premier)
              final lastTxA = a['lastTransaction'] as String?;
              final lastTxB = b['lastTransaction'] as String?;
              
              if (lastTxA == null && lastTxB == null) return 0;
              if (lastTxA == null) return 1; // Les clients sans transaction en dernier
              if (lastTxB == null) return -1;
              
              final dateA = DateTime.tryParse(lastTxA);
              final dateB = DateTime.tryParse(lastTxB);
              
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              
              return dateA.compareTo(dateB); // Croissant = plus anciennes en premier
            });
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement clients: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get filteredClients {
    final q = searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      // Si pas de recherche, afficher tous les clients avec dette (déjà filtrés et triés)
      return clients;
    }
    
    // Filtrer par nom ou téléphone
    return clients.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Régler dettes clients'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // 🆕 Champ de recherche avec bouton toggle
                  Row(
                    children: [
                      Expanded(
                        child: VirtualKeyboardTextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
                          keyboardType: searchKeyboardType,
                          onChanged: (value) => setState(() {
                            // Mise à jour automatique pour déclencher le filtrage
                          }),
                          decoration: InputDecoration(
                            hintText: searchKeyboardType == VirtualKeyboardType.phone
                                ? 'Rechercher par téléphone...'
                                : 'Rechercher par nom...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 🆕 Bouton toggle pour basculer entre alpha et numpad
                      Tooltip(
                        message: searchKeyboardType == VirtualKeyboardType.phone
                            ? 'Basculer vers clavier texte (nom)'
                            : 'Basculer vers clavier numérique (téléphone)',
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              searchKeyboardType = searchKeyboardType == VirtualKeyboardType.phone
                                  ? VirtualKeyboardType.alpha
                                  : VirtualKeyboardType.phone;
                              // Réinitialiser le focus pour que le nouveau clavier s'affiche
                              searchFocusNode.unfocus();
                              Future.delayed(const Duration(milliseconds: 100), () {
                                if (mounted) {
                                  searchFocusNode.requestFocus();
                                }
                              });
                            });
                          },
                          icon: Icon(
                            searchKeyboardType == VirtualKeyboardType.phone
                                ? Icons.abc
                                : Icons.dialpad,
                            size: 28,
                          ),
                          color: searchKeyboardType == VirtualKeyboardType.phone
                              ? Colors.blue.withValues(alpha: 0.7)
                              : Colors.green.withValues(alpha: 0.7),
                          style: IconButton.styleFrom(
                            backgroundColor: searchKeyboardType == VirtualKeyboardType.phone
                                ? Colors.blue.shade50
                                : Colors.green.shade50,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    color: Colors.blue.shade600,
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('CLIENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('TÉLÉPHONE', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('SOLDE', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: filteredClients.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  searchController.text.trim().isEmpty
                                      ? Icons.account_balance_wallet_outlined
                                      : Icons.search_off,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  searchController.text.trim().isEmpty
                                      ? 'Aucun client avec dette enregistré'
                                      : 'Aucun résultat pour "${searchController.text.trim()}"',
                                  style: TextStyle(color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                              )
                            : ListView.builder(
                                itemCount: filteredClients.length,
                                itemBuilder: (context, index) {
                                  final client = filteredClients[index];
                                  final balance = (client['balance'] as num).toDouble();
                                  final isDebt = balance > 0;
                                  return InkWell(
                                    onTap: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                    builder: (context) => DebtPaymentDialog(
                                      client: client,
                                      currentServer: widget.currentServer,
                                    ),
                                      );
                                      if (ok == true) {
                                        // 🔄 Recharger la liste après paiement
                                        await _loadClients();
                                        if (mounted) setState(() {});
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              children: [
                                                Container(width: 8, height: 8, decoration: BoxDecoration(color: isDebt ? Colors.red : Colors.green, shape: BoxShape.circle)),
                                                const SizedBox(width: 10),
                                                Text(client['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(client['phone'], textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.withValues(alpha: 0.7))),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text('${balance.toStringAsFixed(2)} TND', textAlign: TextAlign.right, style: TextStyle(color: isDebt ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
      ],
    );
  }
}

