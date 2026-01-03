import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../../../../core/api_client.dart';
import '../services/credit_socket_service.dart';
import '../../../widgets/virtual_keyboard/virtual_keyboard.dart';

class CreditClientDialog extends StatefulWidget {
  final Function(Map<String, dynamic> client, double amount) onClientSelected;
  final double totalAmount;

  const CreditClientDialog({
    super.key,
    required this.onClientSelected,
    required this.totalAmount,
  });

  @override
  State<CreditClientDialog> createState() => _CreditClientDialogState();
}

class _CreditClientDialogState extends State<CreditClientDialog> {
  List<Map<String, dynamic>> clients = [];
  bool loading = true;
  bool showCreateForm = false;
  VirtualKeyboardType searchKeyboardType = VirtualKeyboardType.alpha; // Type de clavier pour la recherche
  
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  final CreditSocketService _creditSocket = CreditSocketService();
  VoidCallback? _globalUpdateCallback;

  String _toTitleCase(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .split(RegExp(r"\s+"))
        .map((w) => w.isEmpty ? '' : (w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : '')))
        .join(' ');
  }

  @override
  void initState() {
    super.initState();
    _loadClients();
    
    // 🔄 Écouter les mises à jour globales de crédit pour tous les clients
    _globalUpdateCallback = () {
      if (mounted && !loading) {
        print('[CREDIT] Mise à jour globale détectée, rechargement liste...');
        _loadClients();
      }
    };
    _creditSocket.listenToClientUpdates(
      clientId: 0, // 0 = tous les clients (pour recharger la liste)
      onBalanceUpdated: _globalUpdateCallback!,
    );
  }

  @override
  void dispose() {
    // Arrêter d'écouter les mises à jour globales
    if (_globalUpdateCallback != null) {
      _creditSocket.stopListeningToClient(0, _globalUpdateCallback!);
    }
    // Note: ne pas appeler dispose() car le service peut être partagé
    nameController.dispose();
    phoneController.dispose();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      // ⚠️ IMPORTANT : Recharger la liste à chaque ouverture pour avoir les balances à jour
      setState(() => loading = true);
      final response = await ApiClient.dio.get('/api/credit/clients');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          clients = List<Map<String, dynamic>>.from(response.data);
          loading = false;
        });
      } else if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      print('[CREDIT] Erreur chargement clients: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _createClient() async {
    final name = _toTitleCase(nameController.text);
    final phone = phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nom et téléphone requis'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      print('[CREDIT] Tentative création client: nom="$name", téléphone="$phone"');
      final response = await ApiClient.dio.post('/api/credit/clients', data: {
        'name': name,
        'phone': phone,
      });

      if (response.statusCode == 201) {
        final createdClient = Map<String, dynamic>.from(response.data);
        // 🔄 Recharger la liste après création
        await _loadClients();
        widget.onClientSelected(createdClient, widget.totalAmount);
      }
    } catch (e) {
      print('[CREDIT] Erreur création client: $e');
      
      // Extraire le message d'erreur du serveur si disponible
      String errorMessage = 'Erreur création client';
      if (e is DioException && e.response != null) {
        final errorData = e.response?.data;
        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['details'] ?? errorData['error'] ?? errorMessage;
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get filteredClients {
    final q = searchController.text.trim();
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    return clients.where((client) {
      final name = (client['name'] ?? '').toString().toLowerCase();
      final phone = (client['phone'] ?? '').toString();
      return name.startsWith(lower) || phone.startsWith(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Color(0xFF34495E)),
          const SizedBox(width: 8),
          Text(
            'Paiement Crédit Client',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
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
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
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
                  const SizedBox(height: 16),
                  if (!showCreateForm)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => showCreateForm = true),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Nouveau Client'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  if (showCreateForm) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          VirtualKeyboardTextField(
                            controller: nameController,
                            keyboardType: VirtualKeyboardType.alpha,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nom du client',
                              border: OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              TextInputFormatter.withFunction((oldValue, newValue) {
                                // Préserver TOUS les caractères, y compris les espaces
                                // Formater seulement la casse des lettres, sans modifier la structure
                                final text = newValue.text;
                                if (text.isEmpty) return newValue;
                                
                                // Convertir en liste de caractères pour préserver chaque caractère
                                final chars = text.split('');
                                final formattedChars = chars.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final char = entry.value;
                                  
                                  // Si c'est un espace, le garder tel quel
                                  if (char == ' ' || char == '\t' || char == '\n') {
                                    return char;
                                  }
                                  
                                  // Si c'est le premier caractère ou après un espace, mettre en majuscule
                                  if (index == 0 || (index > 0 && chars[index - 1] == ' ')) {
                                    return char.toUpperCase();
                                  }
                                  
                                  // Sinon, mettre en minuscule
                                  return char.toLowerCase();
                                }).join('');
                                
                                // Si le texte a changé, mettre à jour en préservant la position du curseur
                                if (formattedChars != text) {
                                  return TextEditingValue(
                                    text: formattedChars,
                                    selection: newValue.selection,
                                  );
                                }
                                return newValue;
                              }),
                            ],
                          ),
                          const SizedBox(height: 12),
                          VirtualKeyboardTextField(
                            controller: phoneController,
                            keyboardType: VirtualKeyboardType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Numéro de téléphone',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _createClient,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Créer'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() => showCreateForm = false);
                                    nameController.clear();
                                    phoneController.clear();
                                  },
                                  child: const Text('Annuler'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.blue.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (searchController.text.trim()).isEmpty
                                ? 'Tapez pour rechercher un client (nom ou téléphone)'
                                : 'Résultats pour "${searchController.text.trim()}"',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'CLIENT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'TÉLÉPHONE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'SOLDE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: (searchController.text.trim()).isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tapez une première lettre pour afficher des suggestions',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : (filteredClients.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_off,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Aucun résultat pour "${searchController.text.trim()}"',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
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

                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                    decoration: BoxDecoration(
                                      color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        widget.onClientSelected(client, widget.totalAmount);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: isDebt ? Colors.red : Colors.green,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    client['name'],
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                client['phone'],
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 14,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                '${balance.toStringAsFixed(2)} TND',
                                                style: TextStyle(
                                                  color: isDebt ? Colors.red : Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_ios,
                                              size: 16,
                                              color: Colors.grey.shade400,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )),
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
  }
}

