import 'package:flutter/material.dart';
import '../../../../../../core/api_client.dart';

class TransferServerDialog extends StatefulWidget {
  final String currentServer;
  final String currentTable;
  final Function(String targetServer, List<String> tables) onTransfer;

  const TransferServerDialog({
    super.key,
    required this.currentServer,
    required this.currentTable,
    required this.onTransfer,
  });

  @override
  State<TransferServerDialog> createState() => TransferServerDialogState();
}

class TransferServerDialogState extends State<TransferServerDialog> {
  final List<String> _availableServers = ['ALI', 'FATIMA', 'MOHAMED'];
  String _selectedTargetServer = 'ALI';
  final Map<String, bool> _selectedTables = {};
  List<Map<String, dynamic>> _serverTables = [];

  @override
  void initState() {
    super.initState();
    _loadServerTables();
    // Ne pas inclure le serveur actuel dans les options
    _availableServers.remove(widget.currentServer);
    if (_availableServers.isNotEmpty) {
      _selectedTargetServer = _availableServers.first;
    }
  }

  Future<void> _loadServerTables() async {
    try {
      final response = await ApiClient.dio.get('/orders');
      if (response.statusCode == 200) {
        final orders = response.data as List;
        final tablesMap = <String, Map<String, dynamic>>{};
        
        for (var order in orders) {
          final table = order['table'].toString();
          final server = order['server'] ?? 'INCONNU';
          
          if (server == widget.currentServer) {
            if (!tablesMap.containsKey(table)) {
              tablesMap[table] = {
                'table': table,
                'total': 0.0,
                'covers': 0,
                'orders': 0,
              };
            }
            
            tablesMap[table]!['total'] += (order['total'] ?? 0.0);
            tablesMap[table]!['covers'] += (order['covers'] ?? 0);
            tablesMap[table]!['orders'] += 1;
          }
        }
        
        setState(() {
          _serverTables = tablesMap.values.toList();
          _serverTables.sort((a, b) => a['table'].compareTo(b['table']));
          
          // Initialiser la sélection - présélectionner la table courante
          for (var table in _serverTables) {
            _selectedTables[table['table']] = table['table'] == widget.currentTable;
          }
        });
      }
    } catch (e) {
      print('[TRANSFER-SERVER] Erreur chargement tables: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Transfert Serveur - ${widget.currentServer}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sélection du serveur cible
            DropdownButtonFormField<String>(
              value: _selectedTargetServer,
              decoration: const InputDecoration(
                labelText: 'Serveur cible',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: _availableServers.map((server) {
                return DropdownMenuItem(
                  value: server,
                  child: Text(server),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTargetServer = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Liste des tables avec cases à cocher
            Text(
              'Tables de ${widget.currentServer}:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            if (_serverTables.isEmpty)
              const Text('Aucune table trouvée')
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _serverTables.length,
                  itemBuilder: (context, index) {
                    final table = _serverTables[index];
                    final tableNumber = table['table'];
                    final isSelected = _selectedTables[tableNumber] ?? false;
                    final isCurrentTable = tableNumber == widget.currentTable;
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrentTable ? Colors.blue.shade50 : (isSelected ? Colors.green.shade50 : Colors.grey.shade50),
                        border: Border.all(
                          color: isCurrentTable ? Colors.blue.shade300 : (isSelected ? Colors.green.shade300 : Colors.grey.shade300),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              _selectedTables[tableNumber] = !isSelected;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Checkbox personnalisé plus grand
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.green : Colors.white,
                                    border: Border.all(
                                      color: isSelected ? Colors.green : Colors.grey,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                // Informations de la table
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Table $tableNumber',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isCurrentTable ? Colors.blue.withValues(alpha: 0.7) : Colors.black87,
                                            ),
                                          ),
                                          if (isCurrentTable) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.7),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'ACTUELLE',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${table['covers']} couverts - ${table['total'].toStringAsFixed(2)} TND',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            // Boutons d'action rapide (optimisés pour tactile)
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedTables.updateAll((key, value) => true);
                        });
                      },
                      icon: const Icon(Icons.select_all, size: 20),
                      label: const Text('Toutes', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedTables.updateAll((key, value) => false);
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 20),
                      label: const Text('Aucune', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          height: 50,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
            child: const Text('Annuler', style: TextStyle(fontSize: 16)),
          ),
        ),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              final selectedTablesList = _selectedTables.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList();
              
              if (selectedTablesList.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez sélectionner au moins une table'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              widget.onTransfer(_selectedTargetServer, selectedTablesList);
            },
            icon: const Icon(Icons.swap_horiz, size: 20),
            label: const Text('Transférer', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF39C12),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

