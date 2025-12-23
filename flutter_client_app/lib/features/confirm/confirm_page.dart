import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class ConfirmPage extends StatefulWidget {
  final dynamic orderId; // 🆕 Accepte int (ID officiel) ou String (tempId pour commandes client)
  const ConfirmPage({super.key, required this.orderId});

  @override
  State<ConfirmPage> createState() => _ConfirmPageState();
}

class _ConfirmPageState extends State<ConfirmPage> {
  Map<String, dynamic>? order;
  String? error;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      print('[CONFIRM] Chargement commande ${widget.orderId}...');
      final res = await ApiClient.dio.get('/orders/${widget.orderId}');
      
      // 🆕 Vérifier que la réponse est valide
      if (res.data == null) {
        print('[CONFIRM] ❌ Réponse serveur vide');
        setState(() => error = 'Commande introuvable');
        return;
      }
      
      // 🆕 Vérifier le type de la réponse
      if (res.data is! Map<String, dynamic>) {
        print('[CONFIRM] ❌ Format de réponse invalide: ${res.data.runtimeType}');
        setState(() => error = 'Format de réponse invalide');
        return;
      }
      
      final orderData = res.data as Map<String, dynamic>;
      print('[CONFIRM] ✅ Commande chargée: id=${orderData['id']}, table=${orderData['table']}');
      print('[CONFIRM] Structure: mainNote=${orderData['mainNote'] != null ? 'présent' : 'absent'}, subNotes=${orderData['subNotes'] != null ? 'présent' : 'absent'}, items=${orderData['items'] != null ? 'présent' : 'absent'}');
      
      setState(() => order = orderData);
    } on DioException catch (e) {
      print('[CONFIRM] ❌ Erreur DioException: ${e.message}');
      setState(() => error = e.message ?? 'Erreur de connexion');
    } catch (e, stackTrace) {
      print('[CONFIRM] ❌ Erreur inattendue: $e');
      print('[CONFIRM] Stack trace: $stackTrace');
      setState(() => error = e.toString());
    }
  }

  Future<void> _confirm() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      await ApiClient.dio.patch('/orders/${widget.orderId}/confirm');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consommation confirmée')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(appBar: AppBar(title: const Text('Confirmation')), body: Center(child: Text('Erreur: $error')));
    }
    if (order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 🆕 Support de la nouvelle structure avec mainNote/subNotes
    List<Map<String, dynamic>> items = [];
    double total = 0.0;
    
    print('[CONFIRM] 🔍 Parsing de la commande...');
    
    try {
      // Vérifier si c'est la nouvelle structure (avec mainNote)
      final mainNoteData = order!['mainNote'];
      print('[CONFIRM] mainNoteData: ${mainNoteData != null ? mainNoteData.runtimeType : 'null'}');
      
      if (mainNoteData != null && mainNoteData is Map<String, dynamic>) {
        print('[CONFIRM] ✅ Nouvelle structure détectée (avec mainNote)');
        // Nouvelle structure
        final mainNote = mainNoteData;
        
        // Récupérer les items de la note principale
        final mainItemsRaw = mainNote['items'];
        print('[CONFIRM] mainItemsRaw: ${mainItemsRaw != null ? '${mainItemsRaw.runtimeType} (${mainItemsRaw is List ? mainItemsRaw.length : 'N/A'} éléments)' : 'null'}');
        
        if (mainItemsRaw != null && mainItemsRaw is List && mainItemsRaw.isNotEmpty) {
          try {
            // Vérifier que tous les éléments sont des Maps avant de caster
            final validItems = <Map<String, dynamic>>[];
            for (int i = 0; i < mainItemsRaw.length; i++) {
              final item = mainItemsRaw[i];
              if (item != null && item is Map<String, dynamic>) {
                validItems.add(item);
              } else {
                print('[CONFIRM] ⚠️ Item $i ignoré: ${item != null ? item.runtimeType : 'null'}');
              }
            }
            items = validItems;
            print('[CONFIRM] ✅ ${items.length} items valides récupérés de mainNote');
          } catch (e, stackTrace) {
            print('[CONFIRM] ❌ Erreur cast mainItems: $e');
            print('[CONFIRM] Stack trace: $stackTrace');
            items = [];
          }
        } else {
          print('[CONFIRM] ⚠️ mainItemsRaw est null, vide ou n\'est pas une List');
          items = [];
        }
        
        // Récupérer le total de la note principale
        try {
          total = (mainNote['total'] as num?)?.toDouble() ?? 0.0;
        } catch (e) {
          print('[CONFIRM] Erreur récupération total mainNote: $e');
          total = 0.0;
        }
        
        // Ajouter les sous-notes si présentes
        final subNotesRaw = order!['subNotes'];
        print('[CONFIRM] subNotesRaw: ${subNotesRaw != null ? '${subNotesRaw.runtimeType} (${subNotesRaw is List ? subNotesRaw.length : 'N/A'} éléments)' : 'null'}');
        
        if (subNotesRaw != null && subNotesRaw is List && subNotesRaw.isNotEmpty) {
          print('[CONFIRM] ✅ ${subNotesRaw.length} sous-notes trouvées');
          for (int i = 0; i < subNotesRaw.length; i++) {
            final subNote = subNotesRaw[i];
            if (subNote != null && subNote is Map<String, dynamic>) {
              try {
                final subNoteData = subNote;
                final subItemsRaw = subNoteData['items'];
                print('[CONFIRM] Sous-note $i: items=${subItemsRaw != null ? '${subItemsRaw.runtimeType}' : 'null'}');
                
                if (subItemsRaw != null && subItemsRaw is List && subItemsRaw.isNotEmpty) {
                  try {
                    // Vérifier que tous les éléments sont des Maps avant de caster
                    int addedCount = 0;
                    for (final item in subItemsRaw) {
                      if (item != null && item is Map<String, dynamic>) {
                        items.add(item);
                        addedCount++;
                      }
                    }
                    print('[CONFIRM] ✅ $addedCount items ajoutés depuis sous-note $i');
                  } catch (e, stackTrace) {
                    print('[CONFIRM] ❌ Erreur cast subItems: $e');
                    print('[CONFIRM] Stack trace: $stackTrace');
                  }
                }
                final subTotal = (subNoteData['total'] as num?)?.toDouble() ?? 0.0;
                total += subTotal;
              } catch (e, stackTrace) {
                print('[CONFIRM] ❌ Erreur traitement sous-note $i: $e');
                print('[CONFIRM] Stack trace: $stackTrace');
              }
            } else {
              print('[CONFIRM] ⚠️ Sous-note $i ignorée: ${subNote != null ? subNote.runtimeType : 'null'}');
            }
          }
        } else {
          print('[CONFIRM] ⚠️ Pas de sous-notes ou liste vide');
        }
      } else {
        // Ancienne structure (compatibilité) - utiliser order['items'] directement
        print('[CONFIRM] ✅ Ancienne structure détectée (sans mainNote)');
        final itemsRaw = order!['items'];
        print('[CONFIRM] itemsRaw: ${itemsRaw != null ? '${itemsRaw.runtimeType} (${itemsRaw is List ? itemsRaw.length : 'N/A'} éléments)' : 'null'}');
        
        if (itemsRaw != null && itemsRaw is List && itemsRaw.isNotEmpty) {
          try {
            // Vérifier que tous les éléments sont des Maps avant de caster
            final validItems = <Map<String, dynamic>>[];
            for (int i = 0; i < itemsRaw.length; i++) {
              final item = itemsRaw[i];
              if (item != null && item is Map<String, dynamic>) {
                validItems.add(item);
              } else {
                print('[CONFIRM] ⚠️ Item $i ignoré: ${item != null ? item.runtimeType : 'null'}');
              }
            }
            items = validItems;
            print('[CONFIRM] ✅ ${items.length} items valides récupérés (ancienne structure)');
          } catch (e, stackTrace) {
            print('[CONFIRM] ❌ Erreur cast items (ancienne structure): $e');
            print('[CONFIRM] Stack trace: $stackTrace');
            items = [];
          }
        } else {
          print('[CONFIRM] ⚠️ itemsRaw est null, vide ou n\'est pas une List');
          items = [];
        }
        
        // Calculer le total
        try {
          total = (order!['total'] as num?)?.toDouble() ?? 0.0;
          if (total == 0.0 && items.isNotEmpty) {
            // Si total est 0, le calculer depuis les items
            total = items.fold<double>(0, (s, i) {
              try {
                final price = (i['price'] as num?)?.toDouble() ?? 0.0;
                final qty = (i['quantity'] as num?)?.toInt() ?? 1;
                return s + (price * qty);
              } catch (e) {
                return s;
              }
            });
          }
        } catch (e) {
          print('[CONFIRM] Erreur calcul total: $e');
          total = 0.0;
        }
      }
    } catch (e, stackTrace) {
      // En cas d'erreur critique, essayer de récupérer au moins les items de base
      print('[CONFIRM] ❌❌❌ ERREUR CRITIQUE lors du parsing: $e');
      print('[CONFIRM] Type d\'erreur: ${e.runtimeType}');
      print('[CONFIRM] Stack trace: $stackTrace');
      
      // Dernière tentative : essayer order['items'] directement
      try {
        final itemsRaw = order!['items'];
        if (itemsRaw != null && itemsRaw is List && itemsRaw.isNotEmpty) {
          // Vérifier que tous les éléments sont des Maps avant de caster
          final validItems = <Map<String, dynamic>>[];
          for (final item in itemsRaw) {
            if (item != null && item is Map<String, dynamic>) {
              validItems.add(item);
            }
          }
          items = validItems;
          total = items.fold<double>(0, (s, i) {
            try {
              final price = (i['price'] as num?)?.toDouble() ?? 0.0;
              final qty = (i['quantity'] as num?)?.toInt() ?? 1;
              return s + (price * qty);
            } catch (e) {
              return s;
            }
          });
        } else {
          items = [];
          total = 0.0;
        }
      } catch (e2) {
        print('[CONFIRM] Erreur même dans le fallback: $e2');
        items = [];
        total = 0.0;
      }
    }
    
    // S'assurer que items n'est jamais null
    print('[CONFIRM] 📊 Résultat final: ${items.length} items, total: $total TND');
    
    if (items.isEmpty && total == 0.0) {
      // Si tout est vide, afficher un message
      print('[CONFIRM] ⚠️ Aucun article trouvé, affichage du message d\'erreur');
      return Scaffold(
        appBar: AppBar(title: Text('Commande #${order!['id']} — Table ${order!['table']}')),
        body: const Center(
          child: Text('Aucun article trouvé dans cette commande'),
        ),
      );
    }
    final confirmed = (order!['consumptionConfirmed'] as bool?) == true;
    return Scaffold(
      appBar: AppBar(title: Text('Commande #${order!['id']} — Table ${order!['table']}')),
      body: Column(children: [
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = items[i];
              final price = (it['price'] as num).toDouble();
              final qty = (it['quantity'] as num).toInt();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                child: Row(children: [
                  Expanded(child: Text('${it['name']} × $qty', style: const TextStyle(fontWeight: FontWeight.w600))),
                  SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: Text('${(price * qty).toStringAsFixed(2)} TND', style: const TextStyle(fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 120),
                  const SizedBox(width: 44),
                ]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(children: [
            const Text('Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${total.toStringAsFixed(2)} TND', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: confirmed
              ? const SizedBox.shrink()
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: loading ? null : _confirm, child: Text(loading ? '...' : 'Confirmer la consommation')),
                ),
        )
      ]),
    );
  }
}



