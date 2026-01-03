/// Modèle pour gérer les notes (principale et sous-notes) d'une table
class OrderNote {
  final String id;
  final String name;
  final int covers;
  final List<OrderNoteItem> items;
  final double total;
  final bool paid;
  final DateTime? createdAt;
  final int? sourceOrderId; // 🆕 Identifiant de la commande d'origine

  OrderNote({
    required this.id,
    required this.name,
    required this.covers,
    required this.items,
    required this.total,
    this.paid = false,
    this.createdAt,
    this.sourceOrderId,
  });

  factory OrderNote.fromJson(Map<String, dynamic> json) {
    return OrderNote(
      id: json['id'] as String,
      name: json['name'] as String,
      covers: (json['covers'] as num?)?.toInt() ?? 1,
      items: ((json['items'] as List?) ?? [])
          .map((item) => OrderNoteItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      paid: json['paid'] as bool? ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      sourceOrderId: json['sourceOrderId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'covers': covers,
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'paid': paid,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (sourceOrderId != null) 'sourceOrderId': sourceOrderId,
    };
  }

  OrderNote copyWith({
    String? id,
    String? name,
    int? covers,
    List<OrderNoteItem>? items,
    double? total,
    bool? paid,
    DateTime? createdAt,
    int? sourceOrderId,
  }) {
    return OrderNote(
      id: id ?? this.id,
      name: name ?? this.name,
      covers: covers ?? this.covers,
      items: items ?? this.items,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      createdAt: createdAt ?? this.createdAt,
      sourceOrderId: sourceOrderId ?? this.sourceOrderId,
    );
  }
}

class OrderNoteItem {
  final int id;
  final String name;
  final double price;
  int quantity;
  bool isSent; // 🆕 Indique si l'article a été envoyé à la cuisine
  int? paidQuantity; // 🆕 Quantité payée (pour gérer les paiements partiels)
  final int? sourceOrderId; // 🆕 Commande d'origine
  final String? sourceNoteId; // 🆕 Note d'origine

  OrderNoteItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.isSent = false, // 🆕 Par défaut, non envoyé
    this.paidQuantity, // 🆕 Quantité payée optionnelle
    this.sourceOrderId,
    this.sourceNoteId,
  });

  factory OrderNoteItem.fromJson(Map<String, dynamic> json) {
    return OrderNoteItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      isSent: json['isSent'] as bool? ?? false, // 🆕 Lire le statut envoyé
      paidQuantity: (json['paidQuantity'] as num?)?.toInt(), // 🆕 Lire la quantité payée
      sourceOrderId: (json['sourceOrderId'] as num?)?.toInt(),
      sourceNoteId: json['sourceNoteId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'isSent': isSent, // 🆕 Sauvegarder le statut envoyé
      if (paidQuantity != null) 'paidQuantity': paidQuantity, // 🆕 Sauvegarder la quantité payée
      if (sourceOrderId != null) 'sourceOrderId': sourceOrderId,
      if (sourceNoteId != null) 'sourceNoteId': sourceNoteId,
    };
  }

  OrderNoteItem copyWith({
    int? id,
    String? name,
    double? price,
    int? quantity,
    bool? isSent, // 🆕 Ajouter isSent dans copyWith
    int? paidQuantity, // 🆕 Ajouter paidQuantity dans copyWith
    int? sourceOrderId,
    String? sourceNoteId,
  }) {
    return OrderNoteItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      isSent: isSent != null ? isSent : this.isSent, // 🆕 Corriger pour éviter null
      paidQuantity: paidQuantity ?? this.paidQuantity, // 🆕 Copier la quantité payée
      sourceOrderId: sourceOrderId ?? this.sourceOrderId,
      sourceNoteId: sourceNoteId ?? this.sourceNoteId,
    );
  }
}

