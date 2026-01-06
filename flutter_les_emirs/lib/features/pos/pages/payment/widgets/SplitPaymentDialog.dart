import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'CreditClientDialog.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';

// 🆕 Classe pour représenter une transaction de paiement
class PaymentTransaction {
  final String mode;
  double amount;
  final int? clientId; // Pour CREDIT uniquement
  final String id; // Identifiant unique pour cette transaction
  bool isConfirmed; // 🆕 Indique si la transaction est confirmée

  PaymentTransaction({
    required this.mode,
    required this.amount,
    this.clientId,
    String? id,
    this.isConfirmed = false, // 🆕 Par défaut non confirmée
  }) : id = id ?? '${mode}_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (999 * (0.5 - 0.5))).round()}';

  PaymentTransaction copyWith({
    String? mode,
    double? amount,
    int? clientId,
    bool? isConfirmed,
  }) {
    return PaymentTransaction(
      mode: mode ?? this.mode,
      amount: amount ?? this.amount,
      clientId: clientId ?? this.clientId,
      id: id,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }
}

class SplitPaymentDialog extends StatefulWidget {
  final double totalAmount;
  final Map<String, dynamic>? selectedClientForCredit;
  final Function(List<Map<String, dynamic>>, Map<String, int>?) onConfirm; // 🆕 Liste de transactions
  final Function() onCancel;
  final List<Map<String, dynamic>>? initialTransactions; // 🆕 Transactions existantes à préserver
  final Map<String, int>? initialCreditClients; // 🆕 Clients CREDIT existants (transactionId -> clientId)
  final Map<String, String>? initialCreditClientNames; // 🆕 Noms des clients CREDIT existants

  const SplitPaymentDialog({
    super.key,
    required this.totalAmount,
    this.selectedClientForCredit,
    required this.onConfirm,
    required this.onCancel,
    this.initialTransactions, // 🆕 Transactions existantes
    this.initialCreditClients, // 🆕 Clients CREDIT existants
    this.initialCreditClientNames, // 🆕 Noms des clients CREDIT existants
  });

  @override
  State<SplitPaymentDialog> createState() => _SplitPaymentDialogState();
}

class _SplitPaymentDialogState extends State<SplitPaymentDialog> {
  // 🆕 Liste de transactions au lieu de Map
  late List<PaymentTransaction> _transactions;
  final Map<String, TextEditingController> _amountControllers = {};
  final Map<String, FocusNode> _focusNodes = {}; // 🆕 FocusNodes pour chaque transaction
  final List<String> _availableModes = ['ESPECE', 'CARTE', 'CHEQUE', 'TPE', 'OFFRE', 'CREDIT'];
  Map<String, dynamic>? _creditClientForTransaction = {}; // transactionId -> client

  @override
  void initState() {
    super.initState();
    // 🆕 Initialiser avec les transactions existantes si disponibles
    _transactions = [];
    _creditClientForTransaction = {};
    print('[SPLIT-DIALOG] 🆕 initState - totalAmount: ${widget.totalAmount}');
    print('[SPLIT-DIALOG] 🆕 initState - initialTransactions: ${widget.initialTransactions?.length ?? 0}');
    if (widget.initialTransactions != null && widget.initialTransactions!.isNotEmpty) {
      double totalInitial = 0.0;
      for (final tx in widget.initialTransactions!) {
        totalInitial += (tx['amount'] as num?)?.toDouble() ?? 0.0;
      }
      print('[SPLIT-DIALOG] 🆕 Total des initialTransactions: $totalInitial');
      print('[SPLIT-DIALOG] 🆕 Ratio totalAmount/totalInitial: ${widget.totalAmount / totalInitial}');
      
      int transactionIndex = 0;
      for (final tx in widget.initialTransactions!) {
        final originalAmount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        // 🆕 CORRECTION: Si les montants sont multipliés, les ajuster proportionnellement
        // Calculer le ratio entre totalAmount et la somme des transactions initiales
        final totalInitialAmount = widget.initialTransactions!.fold<double>(0.0, (sum, t) => sum + ((t['amount'] as num?)?.toDouble() ?? 0.0));
        final adjustedAmount = totalInitialAmount > 0.01 && widget.totalAmount > 0.01
            ? (originalAmount * widget.totalAmount / totalInitialAmount)
            : originalAmount;
        
        print('[SPLIT-DIALOG] 🆕 Transaction ${tx['mode']}: original=$originalAmount, adjusted=$adjustedAmount');
        
        final transaction = PaymentTransaction(
          mode: tx['mode'] as String,
          amount: adjustedAmount, // 🆕 Utiliser le montant ajusté
          clientId: tx['clientId'] as int?,
          isConfirmed: true, // 🆕 Les transactions existantes sont déjà confirmées
        );
        _transactions.add(transaction);
        // Initialiser les controllers pour les transactions existantes
        final controller = TextEditingController(text: transaction.amount.toStringAsFixed(3));
        _amountControllers[transaction.id] = controller;
        final focusNode = FocusNode();
        _focusNodes[transaction.id] = focusNode;
        // 🆕 Si CREDIT, restaurer le client depuis initialCreditClients et initialCreditClientNames
        if (transaction.mode == 'CREDIT' && transaction.clientId != null) {
          // 🆕 CORRECTION: initialCreditClients utilise transactionId (de l'ancien format) comme clé
          // Mais on a maintenant une liste de transactions, donc on doit chercher différemment
          // On va chercher dans initialCreditClientNames où la clé correspond à l'index ou au mode
          // Pour l'instant, on va utiliser une approche simple : chercher le premier client CREDIT qui correspond
          if (widget.initialCreditClients != null && widget.initialCreditClientNames != null) {
            // Chercher dans initialCreditClients où la valeur correspond à clientId
            for (final entry in widget.initialCreditClients!.entries) {
              if (entry.value == transaction.clientId) {
                // Trouvé ! Récupérer le nom du client
                final clientName = widget.initialCreditClientNames![entry.key];
                if (clientName != null) {
                  // Créer un objet client avec les informations disponibles
                  _creditClientForTransaction![transaction.id] = {
                    'id': transaction.clientId,
                    'name': clientName,
                  };
                  break; // Sortir de la boucle une fois trouvé
                }
              }
            }
          }
          // 🆕 Fallback : si pas trouvé dans initialCreditClientNames, utiliser selectedClientForCredit
          if (!_creditClientForTransaction!.containsKey(transaction.id) && 
              widget.selectedClientForCredit != null && 
              widget.selectedClientForCredit!['id'] == transaction.clientId) {
            _creditClientForTransaction![transaction.id] = widget.selectedClientForCredit;
          }
        }
        transactionIndex++;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  // 🆕 Calculer le total de toutes les transactions confirmées
  double _getTotalEntered() {
    return _transactions.where((t) => t.isConfirmed).fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  double _getRemaining() {
    return widget.totalAmount - _getTotalEntered();
  }

  // 🆕 Calculer le total des montants nécessaires pour TPE/CHEQUE (uniquement confirmées)
  double _getTotalNeededForScriptural() {
    // Calculer combien il reste à payer après avoir soustrait ESPECE et OFFRE
    double nonScripturalTotal = _transactions
        .where((t) => t.isConfirmed && (t.mode == 'ESPECE' || t.mode == 'OFFRE'))
        .fold<double>(0.0, (sum, t) => sum + t.amount);
    return widget.totalAmount - nonScripturalTotal;
  }

  // 🆕 Calculer le total des montants réels pour TPE/CHEQUE (uniquement confirmées)
  double _getTotalScripturalEntered() {
    return _transactions
        .where((t) => t.isConfirmed && (t.mode == 'TPE' || t.mode == 'CHEQUE' || t.mode == 'CARTE'))
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // 🆕 Calculer l'excédent (pourboire indicatif)
  double _getExcessAmount() {
    final needed = _getTotalNeededForScriptural();
    final entered = _getTotalScripturalEntered();
    return entered > needed ? entered - needed : 0.0;
  }

  // 🆕 Vérifier si ESPECE est présent (uniquement dans les transactions confirmées)
  bool _hasCashInPayment() {
    return _transactions.where((t) => t.isConfirmed).any((t) => t.mode == 'ESPECE');
  }

  // 🆕 Confirmer une transaction
  void _confirmTransaction(String transactionId) {
    setState(() {
      final transaction = _transactions.firstWhere((t) => t.id == transactionId);
      if (transaction.amount > 0) {
        transaction.isConfirmed = true;
      }
    });
  }

  // 🆕 Modifier une transaction confirmée
  void _editConfirmedTransaction(String transactionId) {
    setState(() {
      final transaction = _transactions.firstWhere((t) => t.id == transactionId);
      transaction.isConfirmed = false;
      // Remettre le montant dans le champ
      final controller = _amountControllers[transactionId];
      if (controller != null) {
        controller.text = transaction.amount.toStringAsFixed(3);
        // Sélectionner tout le texte pour faciliter la modification
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
    });
  }

  // 🆕 Ajouter une nouvelle transaction
  void _addTransaction(String mode) {
    setState(() {
      final transaction = PaymentTransaction(mode: mode, amount: 0.0);
      _transactions.add(transaction);
      final controller = TextEditingController();
      final focusNode = FocusNode();
      _amountControllers[transaction.id] = controller;
      _focusNodes[transaction.id] = focusNode;
      
      if (mode == 'CREDIT') {
        _showCreditClientDialog(transaction.id);
      } else {
        // 🆕 Faire apparaître le clavier automatiquement après un court délai
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _focusNodes.containsKey(transaction.id)) {
            _focusNodes[transaction.id]!.requestFocus();
          }
        });
      }
    });
  }

  // 🆕 Supprimer une transaction
  void _removeTransaction(String transactionId) {
    setState(() {
      _transactions.removeWhere((t) => t.id == transactionId);
      _amountControllers[transactionId]?.dispose();
      _amountControllers.remove(transactionId);
      _focusNodes[transactionId]?.dispose();
      _focusNodes.remove(transactionId);
      _creditClientForTransaction?.remove(transactionId);
    });
  }

  // 🆕 Mettre à jour le montant d'une transaction
  void _updateTransactionAmount(String transactionId, double amount) {
    setState(() {
      final index = _transactions.indexWhere((t) => t.id == transactionId);
      if (index != -1) {
        _transactions[index] = _transactions[index].copyWith(amount: amount);
      }
    });
  }

  void _showCreditClientDialog(String transactionId) async {
    final transaction = _transactions.firstWhere((t) => t.id == transactionId);
    final amountText = _amountControllers[transactionId]?.text ?? '';
    final amount = amountText.isNotEmpty 
        ? (double.tryParse(amountText.replaceAll(',', '.')) ?? 0)
        : widget.totalAmount;
    
    final client = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreditClientDialog(
        onClientSelected: (client, amount) {
          Navigator.pop(context, client);
        },
        totalAmount: amount,
      ),
    );

    if (client != null) {
      setState(() {
        _creditClientForTransaction![transactionId] = client;
        final index = _transactions.indexWhere((t) => t.id == transactionId);
        if (index != -1) {
          _transactions[index] = _transactions[index].copyWith(clientId: client['id'] as int);
        }
      });
    } else {
      // Si aucun client sélectionné, supprimer la transaction CREDIT
      _removeTransaction(transactionId);
    }
  }

  void _validateAndConfirm() {
    // 🆕 Vérifier uniquement les transactions confirmées
    final confirmedTransactions = _transactions.where((t) => t.isConfirmed).toList();
    
    if (confirmedTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez confirmer au moins une transaction')),
      );
      return;
    }

    // Vérifier que tous les montants confirmés sont valides
    for (final transaction in confirmedTransactions) {
      if (transaction.amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Le montant pour ${_getPaymentModeLabel(transaction.mode)} doit être supérieur à 0')),
        );
        return;
      }

      // Vérifier CREDIT
      if (transaction.mode == 'CREDIT') {
        final client = _creditClientForTransaction?[transaction.id];
        if (client == null || client['id'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez sélectionner un client pour le paiement CREDIT')),
          );
          return;
        }
      }
    }

    final total = _getTotalEntered();
    final difference = total - widget.totalAmount;
    final hasCash = _hasCashInPayment();

    // 🆕 Vérifier qu'on a au moins le montant minimum
    if (difference < -0.01) {
      // Si le total est inférieur au montant à payer, c'est une erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La somme des montants (${total.toStringAsFixed(3)} TND) est inférieure au total (${widget.totalAmount.toStringAsFixed(3)} TND)',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 🆕 Si liquide présent, refuser tout montant > ticket (le serveur prend le pourboire du liquide)
    if (hasCash && difference > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Avec du liquide, le montant total ne peut pas dépasser le ticket (${widget.totalAmount.toStringAsFixed(3)} TND). Le serveur prend le pourboire directement du liquide.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    // Si pas de liquide et difference > 0.01, c'est un pourboire, on l'autorise

    // 🆕 Convertir en format backend : liste de transactions (uniquement les confirmées)
    final List<Map<String, dynamic>> transactionsList = _transactions
        .where((t) => t.isConfirmed && t.amount > 0)
        .map((t) {
      return {
        'mode': t.mode,
        'amount': t.amount,
        'clientId': t.clientId,
        'transactionId': t.id, // 🆕 Envoyer l'ID unique de la transaction
      };
    }).toList();

    // 🆕 Créer le Map des clients CREDIT (pour compatibilité) - uniquement les confirmées
    final Map<String, int> creditClients = {};
    for (final transaction in _transactions.where((t) => t.isConfirmed)) {
      if (transaction.mode == 'CREDIT' && transaction.clientId != null) {
        creditClients[transaction.id] = transaction.clientId!;
      }
    }

    Navigator.pop(context, {
      'transactions': transactionsList,
      'creditClients': creditClients.isEmpty ? null : creditClients,
    });
  }

  String _getPaymentModeLabel(String mode) {
    switch (mode) {
      case 'ESPECE':
        return 'Espèces';
      case 'CARTE':
        return 'Carte';
      case 'CHEQUE':
        return 'Chèque';
      case 'TPE':
        return 'TPE';
      case 'OFFRE':
        return 'Offre';
      case 'CREDIT':
        return 'Crédit';
      default:
        return mode;
    }
  }

  Color _getPaymentModeColor(String mode) {
    switch (mode) {
      case 'ESPECE':
        return const Color(0xFF27AE60);
      case 'CARTE':
        return const Color(0xFF3498DB);
      case 'CHEQUE':
        return const Color(0xFF9B59B6);
      case 'TPE':
        return const Color(0xFFE67E22);
      case 'OFFRE':
        return const Color(0xFFE74C3C);
      case 'CREDIT':
        return const Color(0xFF34495E);
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentModeIcon(String mode) {
    switch (mode) {
      case 'ESPECE':
        return Icons.money;
      case 'CARTE':
        return Icons.credit_card;
      case 'CHEQUE':
        return Icons.receipt;
      case 'TPE':
        return Icons.payment;
      case 'OFFRE':
        return Icons.card_giftcard;
      case 'CREDIT':
        return Icons.account_balance_wallet;
      default:
        return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _getRemaining();
    final totalEntered = _getTotalEntered();
    final excessAmount = _getExcessAmount();
    final hasCash = _hasCashInPayment();
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Material(
          type: MaterialType.card,
          borderRadius: BorderRadius.circular(8),
          elevation: 8,
          child: Container(
            width: 650, // 🆕 Agrandi pour écran tactile (600 -> 650)
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.8, // 🆕 80% de l'écran max
            ),
            padding: const EdgeInsets.all(20), // 🆕 Plus d'espace (16 -> 20)
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.blue.shade700, size: 24), // 🆕 Agrandi
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Paiement divisé',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), // 🆕 Agrandi (18 -> 20)
                  ),
                ),
                // 🆕 Total à payer à côté du titre, plus grand et visible
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Text(
                    '${widget.totalAmount.toStringAsFixed(3)} TND',
                    style: TextStyle(
                      fontSize: 18, // 🆕 Plus grand et visible
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 22), // 🆕 Agrandi
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    widget.onCancel();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 🆕 Enlever "Ajouter:" et afficher directement les boutons
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableModes.map((mode) {
                    final color = _getPaymentModeColor(mode);
                    final icon = _getPaymentModeIcon(mode);
                    return ElevatedButton.icon(
                      onPressed: () => _addTransaction(mode),
                      icon: Icon(icon, size: 24), // 🆕 Plus grand pour écran tactile
                      label: Text(_getPaymentModeLabel(mode), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // 🆕 Plus grand pour tactile
                        minimumSize: const Size(120, 50), // 🆕 Taille minimale pour tactile
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _transactions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Aucune transaction.\nAjoutez un mode de paiement.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_transactions.length, (index) {
                          final transaction = _transactions[index];
                          final color = _getPaymentModeColor(transaction.mode);
                          final icon = _getPaymentModeIcon(transaction.mode);
                          final client = _creditClientForTransaction?[transaction.id];
                          final controller = _amountControllers[transaction.id] ?? TextEditingController();
                          if (!_amountControllers.containsKey(transaction.id)) {
                            _amountControllers[transaction.id] = controller;
                          }

                          // 🆕 Mode compact pour transaction confirmée
                          if (transaction.isConfirmed) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: color.withOpacity(0.5), width: 1),
                                borderRadius: BorderRadius.circular(6),
                                color: color.withOpacity(0.1),
                              ),
                              child: Row(
                                children: [
                                  Icon(icon, color: color, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_getPaymentModeLabel(transaction.mode)} #${index + 1}: ${transaction.amount.toStringAsFixed(3)} TND',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 16),
                                    color: color,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _editConfirmedTransaction(transaction.id),
                                  ),
                                ],
                              ),
                            );
                          }

                          // 🆕 Mode complet pour transaction non confirmée
                          return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            border: Border.all(color: color, width: 2),
                            borderRadius: BorderRadius.circular(8),
                            color: color.withOpacity(0.05),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(icon, color: color, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_getPaymentModeLabel(transaction.mode)} #${index + 1}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18),
                                    color: Colors.red,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _removeTransaction(transaction.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              VirtualKeyboardTextField(
                                controller: controller,
                                focusNode: _focusNodes[transaction.id], // 🆕 Utiliser le FocusNode pour contrôler le focus
                                keyboardType: VirtualKeyboardType.numericDecimal,
                                decoration: InputDecoration(
                                  labelText: 'Montant (TND)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  prefixIcon: const Icon(Icons.attach_money, size: 18),
                                  suffixText: 'TND',
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                                onChanged: (value) {
                                  final amount = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                                  _updateTransactionAmount(transaction.id, amount);
                                  setState(() {}); // Recalculer les totaux
                                },
                                onTap: () {
                                  // 🆕 Sélectionner tout le texte au focus pour permettre remplacement immédiat
                                  if (controller.text.isNotEmpty) {
                                    controller.selection = TextSelection(
                                      baseOffset: 0,
                                      extentOffset: controller.text.length,
                                    );
                                  }
                                },
                              ),
                              if (transaction.mode == 'CREDIT') ...[
                                const SizedBox(height: 6),
                                Builder(
                                  builder: (context) {
                                    // 🆕 Récupérer le client depuis _creditClientForTransaction
                                    final client = _creditClientForTransaction?[transaction.id];
                                    if (client != null) {
                                      return Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.person, size: 14, color: Colors.blue.shade700),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Client: ${client['name'] ?? 'Client #${transaction.clientId}'}',
                                                style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => _showCreditClientDialog(transaction.id),
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: const Text('Changer', style: TextStyle(fontSize: 11)),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else if (transaction.clientId != null) {
                                      // 🆕 Si pas de client dans _creditClientForTransaction mais clientId existe, afficher un placeholder
                                      return Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.orange.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.person, size: 14, color: Colors.orange.shade700),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Client: Client #${transaction.clientId}',
                                                style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => _showCreditClientDialog(transaction.id),
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: const Text('Sélectionner', style: TextStyle(fontSize: 11)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                              const SizedBox(height: 6),
                              // 🆕 Bouton de confirmation (agrandi pour écran tactile)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: transaction.amount > 0 ? () => _confirmTransaction(transaction.id) : null,
                                  icon: const Icon(Icons.check, size: 20), // 🆕 Agrandi (16 -> 20)
                                  label: const Text('Confirmer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), // 🆕 Agrandi (12 -> 15)
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: color,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), // 🆕 Agrandi (8 -> 14)
                                    minimumSize: const Size(0, 50), // 🆕 Hauteur minimale pour tactile
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        }),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            // 🆕 Résumé compact
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: remaining.abs() < 0.01 ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: remaining.abs() < 0.01 ? Colors.green.shade300 : Colors.orange.shade300,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total saisi:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${totalEntered.toStringAsFixed(3)} TND',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: remaining.abs() < 0.01 ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  if (remaining.abs() > 0.01) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          remaining > 0 ? 'Reste:' : (hasCash ? 'Excédent (non autorisé):' : 'Pourboire:'),
                          style: TextStyle(
                            fontSize: 13, // 🆕 Agrandi (11 -> 13)
                            fontWeight: FontWeight.w600,
                            color: remaining > 0 
                                ? Colors.orange.shade700 
                                : (hasCash ? Colors.red.shade700 : Colors.green.shade700),
                          ),
                        ),
                        Text(
                          '${remaining.abs().toStringAsFixed(3)} TND',
                          style: TextStyle(
                            fontSize: 16, // 🆕 Agrandi et plus visible (11 -> 16)
                            fontWeight: FontWeight.bold,
                            color: remaining > 0 
                                ? Colors.orange.shade700 
                                : (hasCash ? Colors.red.shade700 : Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onCancel();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // 🆕 Agrandi pour tactile
                    minimumSize: const Size(0, 50), // 🆕 Hauteur minimale pour tactile
                  ),
                  child: const Text('Annuler', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), // 🆕 Agrandi (12 -> 15)
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  // 🆕 Permettre la validation même avec dépassement (pourboire)
                  // Autoriser la validation si on a au moins une transaction confirmée
                  onPressed: _transactions.any((t) => t.isConfirmed) ? _validateAndConfirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), // 🆕 Agrandi pour tactile (16,8 -> 24,14)
                    minimumSize: const Size(120, 50), // 🆕 Taille minimale pour tactile
                  ),
                  child: const Text('Valider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // 🆕 Agrandi (12 -> 16)
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }
}
