# 📚 Guide Consolidé - Système POS & Admin

## 🎯 Vue d'Ensemble

Ce guide unique regroupe toutes les informations importantes du système POS et Admin pour éviter la confusion entre plusieurs guides.

### **Structure du Système**
- **POS Caisse** → Interface tactile pour serveurs (Flutter)
- **Dashboard Admin** → Gestion des menus et restaurants (Flutter)
- **Serveur Backend** → API Node.js avec Socket.IO (temps réel)

---

## 🏪 **PARTIE 1 : POS CAISSE**

### **Fonctionnalités Principales**
- ✅ **Gestion des commandes** avec sous-notes individuelles
- ✅ **Paiements** (complet, partiel, par note)
- ✅ **Transferts** (articles, notes, tables, serveurs)
- ✅ **Plan de salle** avec synchronisation temps réel
- ✅ **Interface tactile** optimisée

### **Structure des Données**
```dart
// Note principale + sous-notes
OrderNote mainNote = OrderNote(id: 'main', name: 'Note Principale', ...);
List<OrderNote> subNotes = []; // Notes individuelles par client

// Articles avec distinction visuelle
Set<int> newlyAddedItems = {}; // Articles verts (session serveur)
Map<int, int> newlyAddedQuantities = {}; // Quantités ajoutées
```

### **API Endpoints Clés**
- `POST /orders` - Créer commande
- `POST /orders/:id/subnotes` - Créer sous-note
- `DELETE /api/pos/orders/:orderId/notes/:noteId/items` - Supprimer articles payés
- `POST /api/pos/transfer-server` - Changer serveur
- `POST /api/pos/transfer-items` - Transférer articles

### **Événements Socket.IO**
- `server:transferred` - Table transférée vers nouveau serveur
- `order:archived` - Commande archivée après paiement
- `table:cleared` - Table vidée

---

## 🔧 **PARTIE 2 : DASHBOARD ADMIN**

### **Fonctionnalités**
- ✅ **Gestion des restaurants** (CRUD complet)
- ✅ **Upload PDF** → Parsing automatique via IA (DeepSeek V3.1)
- ✅ **Gestion disponibilité** des articles
- ✅ **Traduction automatique** (DeepL)

### **Configuration Requise**
```bash
# Fichier .env
DEEPL_KEY=votre_cle_deepl:fx
OPENROUTER_API_KEY=sk-or-v1-xxxxx  # DeepSeek V3.1 (GRATUIT)
ADMIN_PASSWORD=votre_mot_de_passe
```

### **Utilisation**
```bash
# Lancer l'admin
cd flutter_les_emirs
flutter run -d chrome --dart-define=INITIAL_ROUTE=/admin
```

---

## 🎯 **PARTIE 3 : BONNES PRATIQUES**

### **Règles de Cohérence POS**
1. **Toujours** utiliser les endpoints existants
2. **Toujours** écouter les événements Socket.IO
3. **Toujours** supprimer les tables vides automatiquement
4. **JAMAIS** créer de nouvelles commandes/factures après paiement
5. **Toujours** utiliser la mise à jour optimiste des données

### **Interface Tactile**
- Boutons minimum 48px
- Feedback visuel immédiat
- Distinction des nouveaux articles (vert)
- Reset automatique quand serveur quitte

### **Tests de Validation**
Avant chaque modification, vérifier :
- [ ] Les totaux sont corrects
- [ ] Les articles payés disparaissent
- [ ] Transfert serveur fonctionne
- [ ] Tables vides supprimées
- [ ] Synchronisation temps réel
- [ ] Interface cohérente

---

## 📁 **Fichiers Clés**

### **Backend**
- `server.js` - API principale avec Socket.IO

### **Frontend POS**
- `pos_home_page.dart` - Plan de salle avec synchronisation
- `pos_order_page.dart` - Gestion des commandes et sous-notes
- `pos_payment_page.dart` - Interface de paiement

### **Frontend Admin**
- `admin_home_page.dart` - Dashboard principal
- `admin_restaurant_page.dart` - Gestion des restaurants

### **Documentation**
- `POS_PAYMENT_REFERENCE_GUIDE.md` - Guide technique détaillé
- `NOTES_SOUS_TABLES_IMPLEMENTATION.md` - Documentation sous-notes

---

## 🚀 **Démarrage Rapide**

### **1. Lancer le serveur**
```bash
node server.js
```

### **2. Lancer le POS**
```bash
cd flutter_les_emirs
flutter run --dart-define=INITIAL_ROUTE=/pos
```

### **3. Lancer l'Admin**
```bash
cd flutter_les_emirs
flutter run --dart-define=INITIAL_ROUTE=/admin
```

---

**💡 Ce guide consolidé remplace tous les autres guides pour éviter la confusion. Consultez `POS_PAYMENT_REFERENCE_GUIDE.md` pour les détails techniques.**
