# 📋 Implémentation des Sous-Tables et Transfert d'Articles

## ✅ Ce qui a été implémenté

### 🔧 Backend (server.js)

#### 1. **Nouvelle structure de commande**
```javascript
{
  id: 1,
  table: "5",
  server: "ALI",
  covers: 8,
  mainNote: {
    id: 'main',
    name: 'Note Principale',
    covers: 7,
    items: [...],
    total: 245.00,
    paid: false
  },
  subNotes: [
    {
      id: 'sub_1234567890',
      name: 'Nabil',
      covers: 1,
      items: [...],
      total: 20.40,
      paid: false,
      createdAt: '2025-01-08T18:30:00Z'
    }
  ],
  total: 265.40
}
```

#### 2. **Nouveaux endpoints**

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/orders/:id/subnotes` | POST | Créer une sous-note |
| `/orders/:id/notes/:noteId/items` | POST | Ajouter des articles à une note spécifique |
| `/api/pos/transfer-items` | POST | Transférer des articles entre tables/notes |

#### 3. **Endpoint de transfert**
```javascript
POST /api/pos/transfer-items
{
  fromTable: "5",
  fromOrderId: 1,
  fromNoteId: "main",
  toTable: "12",  // ou null si nouvelle table
  toOrderId: 2,   // ou null
  toNoteId: "main", // ou "sub_xxx" ou null
  items: [
    { id: 9501, name: "Celtia", price: 6.8, quantity: 3 }
  ],
  createNote: true,   // Créer une nouvelle note dans la table destination
  noteName: "Nabil",  // Nom de la nouvelle note
  createTable: false, // ou true pour créer une nouvelle table
  tableNumber: "15",  // si createTable = true
  covers: 1           // Couverts de la nouvelle note/table
}
```

---

### 🎨 Frontend Flutter

#### 1. **Nouveau modèle de données** (`order_note.dart`)
```dart
class OrderNote {
  final String id;
  final String name;
  final int covers;
  final List<OrderNoteItem> items;
  final double total;
  final bool paid;
  final DateTime? createdAt;
}

class OrderNoteItem {
  final int id;
  final String name;
  final double price;
  int quantity;
}
```

#### 2. **Modifications dans `pos_order_page.dart`**

**Nouvelles variables d'état:**
```dart
OrderNote mainNote = OrderNote(...);
List<OrderNote> subNotes = [];
String activeNoteId = 'main';
final List<Color> noteColors = [...];
```

**Nouvelles méthodes:**
- `activeNote` - Récupère la note actuellement sélectionnée
- `getNoteColor()` - Attribue une couleur unique à chaque note
- `_showAddNoteDialog()` - Interface de création de sous-note
- `_createSubNote()` - Crée une nouvelle sous-note

---

## 🚧 À terminer (Prochaine étape)

### 1. **Interface de sélection de note** (badges colorés)
Header à ajouter dans `pos_order_page.dart` :

```dart
// En haut de la page de commande
Container(
  padding: EdgeInsets.all(8),
  child: Column(
    children: [
      // Note active
      Wrap(
        spacing: 8,
        children: [
          _buildNoteChip(mainNote, isActive: activeNoteId == 'main'),
          ...subNotes.map((note) => 
            _buildNoteChip(note, isActive: activeNoteId == note.id)
          ),
          // Bouton ajouter note
          ElevatedButton.icon(
            onPressed: _showAddNoteDialog,
            icon: Icon(Icons.add),
            label: Text('Ajouter une note'),
          ),
        ],
      ),
    ],
  ),
)
```

### 2. **Widget `_buildNoteChip`**
```dart
Widget _buildNoteChip(OrderNote note, {required bool isActive}) {
  final color = getNoteColor(note.id);
  return FilterChip(
    selected: isActive,
    backgroundColor: color.withOpacity(0.1),
    selectedColor: color.withOpacity(0.3),
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(note.name),
        SizedBox(width: 8),
        Text('${note.total.toStringAsFixed(2)} TND',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    ),
    onSelected: (_) {
      setState(() => activeNoteId = note.id);
    },
  );
}
```

### 3. **Modifier `_addItem` pour ajouter à la note active**
```dart
void _addItem(Map<String, dynamic> item) {
  setState(() {
    final noteItem = OrderNoteItem(
      id: item['id'] as int,
      name: item['name'] as String,
      price: (item['price'] as num).toDouble(),
      quantity: 1,
    );
    
    // Trouver la note active et ajouter l'article
    if (activeNoteId == 'main') {
      mainNote = mainNote.copyWith(
        items: [...mainNote.items, noteItem],
        total: mainNote.total + noteItem.price,
      );
    } else {
      final noteIndex = subNotes.indexWhere((n) => n.id == activeNoteId);
      if (noteIndex != -1) {
        subNotes[noteIndex] = subNotes[noteIndex].copyWith(
          items: [...subNotes[noteIndex].items, noteItem],
          total: subNotes[noteIndex].total + noteItem.price,
        );
      }
    }
  });
}
```

### 4. **Interface de transfert d'articles**
Bouton dans l'AppBar :
```dart
IconButton(
  icon: Icon(Icons.swap_horiz),
  tooltip: 'Transférer des articles',
  onPressed: _showTransferDialog,
)
```

### 5. **Adapter le paiement**
Modifier `_openPayment()` pour permettre la sélection de notes :
```dart
void _openPayment() {
  // Afficher un dialog de sélection de notes si plusieurs notes
  if (subNotes.isNotEmpty) {
    _showNoteSelectionForPayment();
  } else {
    // Paiement direct si une seule note
    Navigator.push(...);
  }
}
```

---

## 📊 Flux Complet

### Scénario : Table de 6 personnes (4 amis + 1 couple)

1. **Ouvrir table** → Table N° 5, 6 couverts
2. **Créer sous-note** → "Jean et Sophie", 2 couverts
3. **Sélectionner note principale** → Badge bleu actif
4. **Ajouter articles** → 4 plats pour les amis
5. **Sélectionner note "Jean et Sophie"** → Badge vert actif
6. **Ajouter articles** → 2 plats + 1 vin pour le couple
7. **Envoyer en cuisine** → Toutes les notes envoyées
8. **Payer la note "Jean et Sophie"** → Sélection de la note, paiement partiel
9. **Payer la note principale** → Paiement final, table se ferme

---

## 🎯 État Actuel

✅ Backend complet et fonctionnel
✅ Modèle de données créé
✅ Méthodes de base ajoutées
⏳ Interface visuelle à finaliser
⏳ Transfert d'articles à implémenter
⏳ Paiement multi-notes à adapter

---

## 🚀 Pour Tester

1. Redémarrer le serveur Node.js
2. Lancer l'app Flutter
3. Créer une table
4. Tester la création de sous-notes (bouton à ajouter)
5. Vérifier que les articles s'ajoutent à la bonne note

---

**Prochaine session : Finaliser l'interface visuelle et le transfert d'articles**

