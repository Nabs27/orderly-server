import 'package:flutter/material.dart';
import '../../../models/order_note.dart';
import '../models/order_display_mode.dart';
import 'chronological_order_view.dart';

class PosOrderTicketPanel extends StatefulWidget {
  final String currentTableNumber;
  final int covers;
  final String selectedServer;
  final OrderNote activeNote;
  final double totalAmount;
  final int? selectedLineIndex;
  final Set<int> newlyAddedItems;
  final Map<int, int> newlyAddedQuantities;
  final Function(int) onItemSelected;
  // 🆕 Nouveaux paramètres pour la sélection de note
  final String activeNoteId;
  final List<OrderNote> subNotes;
  final Color Function(String) getNoteColor;
  final Function(String) onNoteSelected;
  final VoidCallback onShowAddNoteDialog;
  final List<Map<String, dynamic>> rawOrders;
  final int? pendingQuantity; // 🆕 Quantité en attente pour affichage
  final VoidCallback? onActionPerformed; // 🆕 Callback appelé après chaque action pour réinitialiser le mode

  const PosOrderTicketPanel({
    super.key,
    required this.currentTableNumber,
    required this.covers,
    required this.selectedServer,
    required this.activeNote,
    required this.totalAmount,
    required this.selectedLineIndex,
    required this.newlyAddedItems,
    required this.newlyAddedQuantities,
    required this.onItemSelected,
    required this.activeNoteId,
    required this.subNotes,
    required this.getNoteColor,
    required this.onNoteSelected,
    required this.onShowAddNoteDialog,
    required this.rawOrders,
    this.pendingQuantity, // 🆕 Quantité en attente (optionnelle)
    this.onActionPerformed, // 🆕 Callback optionnel
  });

  @override
  State<PosOrderTicketPanel> createState() => _PosOrderTicketPanelState();
}

class _PosOrderTicketPanelState extends State<PosOrderTicketPanel> {
  OrderDisplayMode _displayMode = OrderDisplayMode.aggregated;
  // 🆕 ScrollController pour le ListView des articles
  final ScrollController _scrollController = ScrollController();
  int? _lastPendingQuantity; // 🆕 Suivre la dernière quantité en attente pour détecter les changements

  @override
  void initState() {
    super.initState();
    _lastPendingQuantity = widget.pendingQuantity;
    // 🆕 Si une quantité en attente existe déjà à l'initialisation, scroller vers le bas
    if (widget.pendingQuantity != null && widget.pendingQuantity! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottomIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 🆕 Méthode helper pour scroller vers le bas
  void _scrollToBottomIfNeeded() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didUpdateWidget(PosOrderTicketPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🆕 Réinitialiser le mode d'affichage si une action a été effectuée
    // On détecte cela en vérifiant si les items ont changé dans la MÊME note
    if (oldWidget.activeNoteId == widget.activeNoteId) {
      // Même note : vérifier si les items ou le total ont changé (ajout/modification/suppression)
      if (oldWidget.activeNote.items.length != widget.activeNote.items.length ||
          oldWidget.activeNote.total != widget.activeNote.total) {
        if (_displayMode != OrderDisplayMode.aggregated) {
          setState(() {
            _displayMode = OrderDisplayMode.aggregated;
          });
        }
      }
    }
    
    // 🆕 Scroll automatique vers le bas si une quantité en attente apparaît ou change
    if (widget.pendingQuantity != null && widget.pendingQuantity! > 0) {
      if (_lastPendingQuantity == null || _lastPendingQuantity == 0 || _lastPendingQuantity != widget.pendingQuantity) {
        _lastPendingQuantity = widget.pendingQuantity;
        // Attendre que le widget soit construit avant de scroller
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottomIfNeeded();
        });
      }
    } else {
      _lastPendingQuantity = widget.pendingQuantity;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Zone centrale pour le numéro de table (bien visible)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Numéro de table (très visible)
                  Text(
                    'TABLE ${widget.currentTableNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Infos détaillées
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Couverts: ${widget.covers}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.person, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                          widget.selectedServer.isEmpty ? 'Serveur non assigné' : 'Serveur: ${widget.selectedServer}',
                        style: TextStyle(
                            color: widget.selectedServer.isEmpty ? Colors.yellow.shade200 : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 🆕 Sélecteur de note (très visible, juste sous la barre Table)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label "Note active"
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, size: 16, color: Colors.grey.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          'NOTE ACTIVE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.withValues(alpha: 0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Boutons de sélection des notes
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Bouton Note Principale
                        _buildNoteButton(
                          label: 'Note Principale',
                          noteId: 'main',
                          itemCount: widget.activeNoteId == 'main' ? widget.activeNote.items.length : 0,
                          isActive: widget.activeNoteId == 'main',
                          color: Colors.blue,
                          onTap: () => widget.onNoteSelected('main'),
                        ),
                        const SizedBox(width: 8),
                        // Boutons sous-notes
                        ...widget.subNotes.map((note) {
                          final isActive = widget.activeNoteId == note.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildNoteButton(
                              label: note.name,
                              noteId: note.id,
                              itemCount: isActive ? note.items.length : 0,
                              isActive: isActive,
                              color: widget.getNoteColor(note.id),
                              onTap: () => widget.onNoteSelected(note.id),
                            ),
                          );
                        }).toList(),
                        // Bouton + pour ajouter une note
                        InkWell(
                          onTap: widget.onShowAddNoteDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400, width: 1.5, style: BorderStyle.solid),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 18, color: Colors.grey.withValues(alpha: 0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  'Nouvelle note',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // En-tête ticket
            Container(
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF3498DB),
              child: Row(
                children: [
                  // Bouton toggle vue chronologique
                  IconButton(
                    icon: Icon(
                      _displayMode == OrderDisplayMode.chronological
                          ? Icons.view_list
                          : Icons.access_time,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: _displayMode == OrderDisplayMode.chronological
                        ? 'Vue agrégée'
                        : 'Vue chronologique',
                    onPressed: () {
                      setState(() {
                        _displayMode = _displayMode == OrderDisplayMode.aggregated
                            ? OrderDisplayMode.chronological
                            : OrderDisplayMode.aggregated;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _displayMode == OrderDisplayMode.chronological
                          ? 'Commandes'
                          : 'Désignation',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_displayMode == OrderDisplayMode.aggregated) ...[
                  const SizedBox(width: 60, child: Text('Qté', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 80, child: Text('Prix', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 100, child: Text('Montant', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ],
                ],
              ),
            ),
            // Lignes du ticket - vue agrégée ou chronologique
            Expanded(
              child: _displayMode == OrderDisplayMode.chronological
                  ? ChronologicalOrderView(
                      rawOrders: widget.rawOrders,
                      activeNoteId: widget.activeNoteId,
                      selectedLineIndex: widget.selectedLineIndex,
                      onItemSelected: widget.onItemSelected,
                    )
                  : _buildAggregatedView(),
            ),
            // Total
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, -2))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TL:', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(
                        '${widget.activeNote.total.toStringAsFixed(3)} TND',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (widget.totalAmount != widget.activeNote.total) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Total table: ${widget.totalAmount.toStringAsFixed(3)} TND',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAggregatedView() {
    // Ne pas afficher "Aucun article" si on a une quantité en attente
    final hasItems = widget.activeNote.items.isNotEmpty;
    final hasPending = widget.pendingQuantity != null && widget.pendingQuantity! > 0;

    if (!hasItems && !hasPending) {
      return const Center(
        child: Text('Aucun article', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return ListView.builder(
      controller: _scrollController, // 🆕 Ajouter le ScrollController
      itemCount: widget.activeNote.items.length + (widget.pendingQuantity != null && widget.pendingQuantity! > 0 ? 1 : 0), // 🆕 Ajouter une ligne pour le badge
                      itemBuilder: (_, i) {
                        // 🆕 Afficher le badge de quantité en attente après la dernière ligne
                        if (i == widget.activeNote.items.length && widget.pendingQuantity != null && widget.pendingQuantity! > 0) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              border: Border.all(color: Colors.blue.shade300, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_shopping_cart, color: Colors.blue.withValues(alpha: 0.7), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Quantité en attente: ${widget.pendingQuantity}',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Ligne normale d'article
                        final itemIndex = i;
                        final item = widget.activeNote.items[itemIndex];
        final isSelected = widget.selectedLineIndex == i;
        final isNewlyAdded = widget.newlyAddedItems.contains(item.id);
                        
                        return InkWell(
          onTap: () => widget.onItemSelected(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? const Color(0xFFE8F4F8) 
                                  : (isNewlyAdded 
                                      ? Colors.green.shade50 
                                      : (i % 2 == 0 ? Colors.white : Colors.grey.shade50)),
                              border: isNewlyAdded 
                                  ? Border.all(color: Colors.green.shade300, width: 2)
                                  : null,
                              borderRadius: isNewlyAdded ? BorderRadius.circular(8) : null,
                            ),
                            child: Row(
                              children: [
                                // Badge avec nombre exact d'articles ajoutés
                if (isNewlyAdded && widget.newlyAddedQuantities.containsKey(item.id))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                        '+${widget.newlyAddedQuantities[item.id]}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isNewlyAdded ? Colors.green.shade900 : Colors.black87,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    '${item.quantity}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isNewlyAdded ? Colors.green.withValues(alpha: 0.7) : Colors.black87,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    '${item.price.toStringAsFixed(3)}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isNewlyAdded ? Colors.green.withValues(alpha: 0.7) : Colors.black87,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    '${(item.price * item.quantity).toStringAsFixed(3)}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 14, 
                                      fontWeight: FontWeight.bold,
                                      color: isNewlyAdded ? Colors.green.withValues(alpha: 0.7) : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
    );
  }

  // 🆕 Widget pour créer un bouton de note
  Widget _buildNoteButton({
    required String label,
    required String noteId,
    required int itemCount,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : Colors.grey.shade400,
            width: isActive ? 2.5 : 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.grey.withValues(alpha: 0.7),
              ),
            ),
            if (isActive && itemCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$itemCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

