import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../../core/api_client.dart';
import '../../payment/services/credit_socket_service.dart';
import '../../payment/widgets/TicketPreviewDialog.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';

class DebtPaymentDialog extends StatefulWidget {
  final Map<String, dynamic> client;
  final String currentServer;
  const DebtPaymentDialog({super.key, required this.client, required this.currentServer});

  @override
  State<DebtPaymentDialog> createState() => DebtPaymentDialogState();
}

class DebtPaymentDialogState extends State<DebtPaymentDialog> {
  final TextEditingController amountController = TextEditingController();
  String paymentMode = 'ESPECE';
  bool loading = false;
  bool loadingHistory = true;
  List<Map<String, dynamic>> transactions = [];
  double balance = 0.0;
  final CreditSocketService _creditSocket = CreditSocketService();
  VoidCallback? _balanceUpdateCallback;

  @override
  void initState() {
    super.initState();
    _loadClientHistory();
    
    // 🔄 Écouter les mises à jour en temps réel
    final clientId = widget.client['id'] as int?;
    if (clientId != null) {
      _balanceUpdateCallback = () {
        if (mounted) {
          print('[CREDIT] Mise à jour temps réel détectée, rechargement...');
          _loadClientHistory();
        }
      };
      _creditSocket.listenToClientUpdates(
        clientId: clientId,
        onBalanceUpdated: _balanceUpdateCallback!,
      );
    }
  }

  @override
  void dispose() {
    // Nettoyer les listeners socket
    final clientId = widget.client['id'] as int?;
    if (clientId != null && _balanceUpdateCallback != null) {
      _creditSocket.stopListeningToClient(clientId, _balanceUpdateCallback!);
      _creditSocket.dispose();
    }
    amountController.dispose();
    super.dispose();
  }

  Future<void> _loadClientHistory() async {
    try {
      // ⚠️ IMPORTANT : Recharger toujours depuis le serveur pour avoir le balance à jour
      final resp = await ApiClient.dio.get('/api/credit/clients/${widget.client['id']}');
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = resp.data;
        setState(() {
          transactions = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
          balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
          loadingHistory = false;
        });
        print('[CREDIT] Balance rechargé pour client ${widget.client['id']}: $balance TND');
      } else {
        setState(() => loadingHistory = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingHistory = false);
      print('[CREDIT] Erreur chargement historique client ${widget.client['id']}: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement historique: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submit() async {
    final raw = amountController.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
      );
      return;
    }
    
    // 🆕 Vérifier que le montant ne dépasse pas le solde
    if (amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Le montant (${amount.toStringAsFixed(3)} DT) ne peut pas dépasser le solde restant (${balance.toStringAsFixed(3)} DT)'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // 🔔 Demander confirmation avant de payer
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirmer le paiement'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${widget.client['name']}'),
            const SizedBox(height: 8),
            Text('Montant: ${amount.toStringAsFixed(2)} TND'),
            const SizedBox(height: 8),
            Text('Mode: ${_getPaymentModeLabel(paymentMode)}'),
            const SizedBox(height: 16),
            const Text(
              'Êtes-vous sûr de vouloir effectuer ce paiement ?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => loading = true);
    try {
      final response = await ApiClient.dio.post(
        '/api/credit/clients/${widget.client['id']}/pay-oldest',
        data: {
          'amount': amount,
          'paymentMode': paymentMode,
          'server': widget.currentServer,
        },
      );
      if (!mounted) return;
      setState(() => loading = false);
      if (response.statusCode == 201) {
        // 🔄 Recharger immédiatement après paiement
        await _loadClientHistory();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.data['message'] ?? 'Paiement effectué'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur paiement: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _payAllDebts() async {
    if (balance <= 0) return;
    
    // 🔔 Demander confirmation avant de payer tout
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirmer le paiement total'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client: ${widget.client['name']}'),
            const SizedBox(height: 8),
            Text('Montant total: ${balance.toStringAsFixed(2)} TND'),
            const SizedBox(height: 8),
            Text('Mode: ${_getPaymentModeLabel(paymentMode)}'),
            const SizedBox(height: 16),
            const Text(
              'Êtes-vous sûr de vouloir payer toutes les dettes en une fois ?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => loading = true);
    try {
      double remaining = balance;
      int guard = 0;
      while (remaining > 0 && guard < 100) {
        final resp = await ApiClient.dio.post(
          '/api/credit/clients/${widget.client['id']}/pay-oldest',
          data: {
            // Envoyer uniquement le montant restant pour éviter les surpaiements
            'amount': remaining,
            'paymentMode': paymentMode,
            'server': widget.currentServer,
          },
        );
        if (resp.statusCode != 201) break;
        final newBalance = (resp.data['balance'] as num?)?.toDouble() ?? 0.0;
        guard++;
        
        // Si aucun progrès (balance identique), éviter une boucle infinie
        if ((newBalance - remaining).abs() < 0.0001) {
          remaining = newBalance;
          break;
        }
        
        remaining = newBalance;
        if (remaining <= 0) break;
      }
      if (!mounted) return;
      
      // 🔄 Recharger immédiatement après paiement total
      await _loadClientHistory();
      
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toutes les dettes ont été réglées'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur paiement total: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _getPaymentModeLabel(String mode) {
    switch (mode) {
      case 'ESPECE': return 'Espèces';
      case 'CARTE': return 'Carte';
      case 'CHEQUE': return 'Chèque';
      case 'TPE': return 'TPE';
      default: return mode;
    }
  }


  Future<void> _showClientSelector() async {
    // Charger la liste des clients
    try {
      final response = await ApiClient.dio.get('/api/credit/clients');
      if (response.statusCode == 200 && mounted) {
        final allClients = List<Map<String, dynamic>>.from(response.data);
        
        // 🆕 État local pour la recherche
        final searchController = TextEditingController();
        final searchFocusNode = FocusNode();
        final searchQueryRef = <String>['']; // Utiliser une liste pour la référence mutable
        final searchKeyboardTypeRef = <VirtualKeyboardType>[VirtualKeyboardType.alpha];
        
        final selectedClient = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) {
                // 🆕 Filtrer les clients selon la recherche
                final filteredClients = allClients.where((client) {
                  if (searchQueryRef[0].trim().isEmpty) return true;
                  final q = searchQueryRef[0].trim().toLowerCase();
                  final name = (client['name'] ?? '').toString().toLowerCase();
                  final phone = (client['phone'] ?? '').toString();
                  return name.contains(q) || phone.contains(q);
                }).toList();
                
                return AlertDialog(
            title: const Text('Sélectionner un client'),
            content: SizedBox(
              width: 500,
                    height: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🆕 Champ de recherche avec bouton toggle
                        Row(
                          children: [
                            Expanded(
                              child: VirtualKeyboardTextField(
                                controller: searchController,
                                focusNode: searchFocusNode,
                                keyboardType: searchKeyboardTypeRef[0],
                                onChanged: (value) {
                                  searchQueryRef[0] = value;
                                  setDialogState(() {});
                                },
                                decoration: InputDecoration(
                                  hintText: searchKeyboardTypeRef[0] == VirtualKeyboardType.phone
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
                              message: searchKeyboardTypeRef[0] == VirtualKeyboardType.alpha
                                  ? 'Basculer vers clavier numérique (téléphone)'
                                  : 'Basculer vers clavier texte (nom)',
                              child: IconButton(
                                onPressed: () {
                                  searchKeyboardTypeRef[0] = searchKeyboardTypeRef[0] == VirtualKeyboardType.phone
                                      ? VirtualKeyboardType.alpha
                                      : VirtualKeyboardType.phone;
                                  // Réinitialiser le focus pour que le nouveau clavier s'affiche
                                  searchFocusNode.unfocus();
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    if (context.mounted) {
                                      searchFocusNode.requestFocus();
                                    }
                                  });
                                  setDialogState(() {});
                                },
                                icon: Icon(
                                  searchKeyboardTypeRef[0] == VirtualKeyboardType.phone
                                      ? Icons.abc
                                      : Icons.dialpad,
                                  size: 28,
                                ),
                                color: searchKeyboardTypeRef[0] == VirtualKeyboardType.phone
                                    ? Colors.blue.withValues(alpha: 0.7)
                                    : Colors.green.withValues(alpha: 0.7),
                                style: IconButton.styleFrom(
                                  backgroundColor: searchKeyboardTypeRef[0] == VirtualKeyboardType.phone
                                      ? Colors.blue.shade50
                                      : Colors.green.shade50,
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Liste des clients filtrés
                        Expanded(
                          child: filteredClients.isEmpty
                              ? Center(
                                  child: Text(
                                    searchQueryRef[0].trim().isEmpty
                                        ? 'Aucun client disponible'
                                        : 'Aucun résultat pour "${searchQueryRef[0]}"',
                                  ),
                                )
                  : ListView.builder(
                                  itemCount: filteredClients.length,
                      itemBuilder: (context, index) {
                                    final client = filteredClients[index];
                        final clientBalance = (client['balance'] as num?)?.toDouble() ?? 0.0;
                        final isSelected = client['id'] == widget.client['id'];
                        
                        return ListTile(
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.person,
                            color: isSelected ? Colors.green : Colors.grey,
                          ),
                          title: Text(client['name'] ?? ''),
                          subtitle: Text('Tél: ${client['phone'] ?? ''}'),
                          trailing: Text(
                            '${clientBalance.toStringAsFixed(2)} TND',
                            style: TextStyle(
                              color: clientBalance > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: isSelected
                              ? null
                              : () => Navigator.of(context).pop(client),
                          enabled: !isSelected,
                        );
                      },
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
                );
              },
            ),
        ).then((_) {
          // 🆕 Nettoyer les controllers et focusNodes après fermeture du dialog
          searchController.dispose();
          searchFocusNode.dispose();
        });
        
        if (selectedClient != null && mounted) {
          // Recharger l'historique avec le nouveau client
          Navigator.of(context).pop(); // Fermer le dialog actuel
          // Ouvrir un nouveau dialog avec le nouveau client
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => DebtPaymentDialog(
                client: selectedClient,
                currentServer: widget.currentServer,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement clients: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text('Payer une dette - ${widget.client['name']}'),
          ),
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'Changer de client',
            onPressed: _showClientSelector,
          ),
        ],
      ),
      content: SizedBox(
        width: 700, // Agrandi de 520 à 700
        height: MediaQuery.of(context).size.height * 0.75, // 75% de la hauteur de l'écran
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête solde
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: balance > 0 ? Colors.red.shade50 : Colors.green.shade50,
                border: Border.all(color: balance > 0 ? Colors.red.shade200 : Colors.green.shade200),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(balance > 0 ? Icons.warning : Icons.check_circle, color: balance > 0 ? Colors.red : Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text('Solde: ${balance.toStringAsFixed(2)} TND', style: TextStyle(color: balance > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Historique
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text('DESCRIPTION', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('DÉBIT', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('CRÉDIT', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('SOLDE\nINTER.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 300, // Agrandi de 240 à 300
              child: loadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        // plus anciennes en premier
                        final reversedIndex = transactions.length - 1 - index;
                        final t = transactions[reversedIndex];
                        final isDebit = (t['type'] == 'DEBIT');
                        final amount = (t['amount'] as num).toDouble();
                        final date = DateTime.tryParse(t['date'] ?? '') ?? DateTime.now();
                        final hasTicket = (t['type'] == 'DEBIT'); // montrer pour toute dette (avec fallback)
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(flex: 2, child: Text('${date.day}/${date.month}')),
                                  Expanded(flex: 3, child: Text(t['description'] ?? '', overflow: TextOverflow.ellipsis)),
                                  Expanded(flex: 1, child: Text(isDebit ? amount.toStringAsFixed(2) : '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                                  Expanded(flex: 1, child: Text(!isDebit ? amount.toStringAsFixed(2) : '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: ((t['runningBalance'] as num?)?.toDouble() ?? 0.0) > 0 
                                            ? Colors.red.shade50 
                                            : ((t['runningBalance'] as num?)?.toDouble() ?? 0.0) < 0 
                                                ? Colors.green.shade50 
                                                : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: ((t['runningBalance'] as num?)?.toDouble() ?? 0.0) > 0 
                                              ? Colors.red.shade200 
                                              : ((t['runningBalance'] as num?)?.toDouble() ?? 0.0) < 0 
                                                  ? Colors.green.shade200 
                                                  : Colors.grey.shade300,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        // Ne pas mettre de signe '+' pour les débits dans le solde intermédiaire
                                        // Le solde positif représente une dette, pas un crédit
                                        (t['runningBalance'] as num?)?.toStringAsFixed(2) ?? '0.00',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: ((t['runningBalance'] as num?)?.toDouble() ?? 0.0) > 0 
                                              ? Colors.red.withValues(alpha: 0.7) 
                                              : ((t['runningBalance'] as num?)?.toDouble() ?? 0.0) < 0 
                                                  ? Colors.green.withValues(alpha: 0.7) 
                                                  : Colors.grey.withValues(alpha: 0.7),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (hasTicket)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _showTicketPreview(t),
                                        icon: const Icon(Icons.receipt_long, size: 18),
                                        label: const Text('Voir ticket'),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        tooltip: 'Imprimer (à venir)',
                                        icon: const Icon(Icons.print, size: 20),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Impression de ticket – bientôt disponible')),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),

            // Saisie paiement
            VirtualKeyboardTextField(
              controller: amountController,
              keyboardType: VirtualKeyboardType.numericDecimal,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Montant',
                labelStyle: TextStyle(fontSize: 16),
                border: OutlineInputBorder(),
                suffixText: 'DT', // 🆕 "DT" au lieu de l'icône dollar
                suffixStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              ),
              // 🆕 Overlay pour afficher le montant au-dessus du clavier
              overlayWidget: Builder(
                builder: (context) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Montant à payer',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: amountController,
                        builder: (context, value, child) {
                          final amount = value.text.trim().isEmpty
                              ? 0.0
                              : (double.tryParse(value.text.trim().replaceAll(',', '.')) ?? 0.0);
                          
                          final isAmountValid = amount > 0 && amount <= balance;
                          final isAmountTooHigh = amount > balance;
                          
                          return Column(
                            children: [
                              Text(
                                '${amount.toStringAsFixed(3)} DT', // 🆕 3 décimales au lieu de 2
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: amount == 0.0
                                      ? Colors.grey.shade400
                                      : isAmountTooHigh
                                          ? Colors.red.withValues(alpha: 0.7) // 🆕 Rouge si montant trop élevé
                                          : Colors.blue.withValues(alpha: 0.7),
                                ),
                              ),
                              // 🆕 Message d'avertissement si montant trop élevé
                              if (isAmountTooHigh) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning, color: Colors.red.withValues(alpha: 0.7), size: 18),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Solde restant: ${balance.toStringAsFixed(3)} DT',
                                          style: TextStyle(
                                            color: Colors.red.withValues(alpha: 0.7),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              // 🆕 Bouton de confirmation
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: (loading || !isAmountValid || balance <= 0)
                                      ? null
                                      : () async {
                                          // Fermer le clavier et l'overlay
                                          FocusScope.of(context).unfocus();
                                          // Appeler _submit
                                          await _submit();
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.withValues(alpha: 0.7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Confirmer',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: paymentMode,
              decoration: const InputDecoration(labelText: 'Mode de paiement', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'ESPECE', child: Text('Espèces')),
                DropdownMenuItem(value: 'CARTE', child: Text('Carte')),
                DropdownMenuItem(value: 'CHEQUE', child: Text('Chèque')),
                DropdownMenuItem(value: 'TPE', child: Text('TPE')),
              ],
              onChanged: (v) => setState(() => paymentMode = v ?? 'ESPECE'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        TextButton(
          onPressed: loading || balance <= 0 ? null : _payAllDebts,
          child: const Text('Payer tout'),
        ),
        ElevatedButton(
          onPressed: (loading || balance <= 0) ? null : _submit,
          child: loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Payer'),
        ),
      ],
    );
  }

  // 🆕 Aperçu ticket (format proche pré-addition)
  void _showTicketPreview(Map<String, dynamic> transaction) {
    final rawTicket = transaction['ticket'];
    final ticket = (rawTicket is Map<String, dynamic> && rawTicket.isNotEmpty)
        ? rawTicket
        : _buildFallbackTicket(transaction);
    final items = ((ticket['items'] as List?) ?? [])
        .map<Map<String, dynamic>>((it) => {
              'name': it['name'] ?? 'Article',
              'price': (it['price'] as num?)?.toDouble() ?? 0.0,
              'quantity': (it['quantity'] as num?)?.toInt() ?? 1,
            })
        .toList();
    if (items.isEmpty) {
      items.add({
        'name': transaction['description'] ?? 'Article',
        'price': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
        'quantity': 1,
      });
    }
    final double total = (ticket['total'] as num?)?.toDouble() ??
        (transaction['amount'] as num?)?.toDouble() ??
        0.0;
    final double subtotal = (ticket['subtotal'] as num?)?.toDouble() ?? total;
    final double discount = (ticket['discount'] as num?)?.toDouble() ?? 0.0;
    final bool isPercent = ticket['isPercentDiscount'] == true;
    final int tableNumber = int.tryParse('${ticket['table'] ?? transaction['table'] ?? 0}') ?? 0;

    showDialog(
      context: context,
      builder: (_) => TicketPreviewDialog(
        tableNumber: tableNumber,
        paymentTotal: subtotal,
        finalTotal: total,
        discount: discount,
        isPercentDiscount: isPercent,
        itemsToPay: items,
      ),
    );
  }

  // 🆕 Ticket minimal de secours si la transaction n'a pas de ticket
  Map<String, dynamic> _buildFallbackTicket(Map<String, dynamic> t) {
    final date = t['date'] ?? DateTime.now().toIso8601String();
    final total = (t['amount'] as num?)?.toDouble() ?? 0.0;
    return {
      'table': t['table'] ?? '-',
      'date': date,
      'items': [
        {
          'name': t['description'] ?? 'Dette',
          'quantity': 1,
          'price': total,
        }
      ],
      'total': total,
      'subtotal': total,
      'discount': 0.0,
      'isPercentDiscount': false,
    };
  }
}

