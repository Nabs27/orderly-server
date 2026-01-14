# 📝 Module POS – Order (Prise de commande)

## 📍 Objectif
Documenter la structure complète du module « Order » : notes, services, widgets, transferts et annulations. Ce fichier complète `STRUCTURE_POS.md` (vue globale) et se concentre sur `PosOrderPage_refactor.dart`.

---

## 📂 Fichiers clés

| Type | Fichier | Rôle |
|------|---------|------|
| Page principale | `lib/features/pos/pages/order/PosOrderPage_refactor.dart` | Interface prise de commande, gestion notes, transferts, annulations |
| Aides métier | `services/note_actions.dart` | Ajout/suppression/modif des articles dans les notes |
| Gestion sockets | `services/order_socket_service.dart` | Abonnement aux événements `order:*` |
| Repository | `services/order_repository.dart` | CRUD commandes via API |
| Utils | `utils/order_helpers.dart` | Sélection note active, calculs totaux |

---

## 🎯 Responsabilités
- Créer et manipuler des notes (principale + sous-notes).
- Enrichir les notes avec des articles du menu (`pos_menu_grid`, `pos_numpad`).
- Envoyer les commandes à la cuisine (`TransferService.sendToKitchen`).
- Gérer transferts d’articles entre notes ou tables, changements de serveur.
- Annuler des articles et générer des remboursements partiels.
- Naviguer vers la caisse/paiement.
- Respecter les autorisations associées au serveur connecté (transferts, annulations, dettes, accès caisse).

---

## 🧩 Services

| Service | Description | Usage clé |
|---------|-------------|-----------|
| `order_repository.dart` | Accès API `/orders` (load, create, update) | `_loadExistingOrder`, sauvegarde orderId |
| `order_socket_service.dart` | Connexion Socket.IO (order:updated/new/archived) | Auto-refresh commande active |
| `note_actions.dart` | Ajout, édition, suppression d’articles dans les notes | `_addItem`, `_updateQuantity`, `_deleteLine` |
| `transfer_service.dart` | Transferts (note↔note, table↔table, serveur) + envoi cuisine | Dialogs de transfert, envoi complet |
| `payment_service.dart` (module order) | Prépare les données pour la caisse (getAllOrdersForTable) | `_openPayment` |
| `cancellation_service.dart` | API d’annulation d’articles | `CancelItemsDialog` |
| `sync_service.dart` | Force la resynchronisation des tables après paiement | `PaymentService.updateDataOptimistically` |
| `local_update_service.dart` | Met à jour localement les notes après transferts | Optimisation UI sans attendre API |
| `admin_service.dart` | Fonctions d’administration ponctuelles (nettoyage duplicats) | `_cleanupDuplicates` |
| `server_permissions_service.dart` | Charge les profils/droits côté POS | `_loadServerProfiles`, `_loadServerPermissions` |

---

## 🧱 Widgets et Dialogs

- **Panels principaux**
  - `pos_order_app_bar.dart` : sélection serveur, notes, actions rapides.
  - `pos_order_ticket_panel.dart` : liste des articles, totaux, sélection de ligne.
  - `pos_order_action_panel.dart` : numpad, boutons d’actions (envoyer cuisine, annuler, transfert).
  - `pos_order_menu_panel.dart` : catalogue produits, recherche, catégories.

- **Dialogs de transfert**
  - `TransferDialog`, `TransferToNoteDialog`, `TransferToTableDialog`.
  - `TransferItemsSelectionDialog`, `CompleteTableTransferDialog`.
  - `TableDestinationDialog`, `CreateNote/TableForTransferDialog`.
  - `TransferServerDialog` : changer le serveur assigné à une table.

- **Autres dialogs clés**
  - `AddNoteDialog` : création sous-note.
  - `CancelItemsDialog` : annulation avec raisons et remboursement.
  - `CoversDialog`, `NotesDialog`, `IngredientDialog`.
  - `DebtSettlementDialog`, `DebtPaymentDialog`.
  - `ServerSelectionDialog` : changer de serveur depuis la page.
  - `AdminServersPage` (admin) : création/édition des profils serveurs (droits appliqués dans `PosOrderActionPanel`).

---

## 🧭 Gestion des notes

| Concept | Détails |
|---------|---------|
| Note principale | `id = 'main'`, contient les articles par défaut. |
| Sous-notes | `id = 'sub_xxx'`, créées pour distinguer les clients ou paiements. |
| Note active | `activeNoteId` conserve la note en cours d’édition. |
| Historique actions | `actionHistory` + `_undoLastAction()` pour annuler la dernière modification. |

Création de sous-note : `NoteActions.createSubNote` via `TransferService` (API). Lorsqu’une note est supprimée ou vidée, on repasse sur `main`.

---

## 🔄 Flux principaux

```
initState()
  ├─ Charge menu (OrderRepository.loadMenu)
  ├─ Charge commande existante (OrderRepository.loadExistingOrder)
  └─ Connecte OrderSocketService (événements order:*)

Ajout article
  └─ NoteActions.addItem → met à jour mainNote/subNotes + indicateurs visuels

Envoi cuisine
  ├─ TransferService.sendToKitchen (POST /orders)
  ├─ Sauve orderId sur la table (OrderRepository.saveOrderIdToTable)
  └─ Vide la note active + recharge commande

Transfert articles
  ├─ Sélection items via dialogs
  ├─ TransferService.executeTransfer... (API)
  └─ LocalUpdateService pour feedback instantané

Annulation
  ├─ CancelItemsDialog → sélection quantités
  └─ CancellationService.cancelItems (groupé par orderId/noteId)

Accès paiement
  └─ `_openPayment()` → PaymentService.getAllOrdersForTable → PosPaymentPage
```

---

## 🔔 Socket.IO

| Événement | Effet |
|-----------|-------|
| `order:updated` | Relance `_loadExistingOrder()` pour rafraîchir notes/totaux. |
| `order:archived` | Recharge l’écran (commande terminée). |
| `order:new` | Permet de prendre la main sur une commande créée ailleurs. |
| `table:cleared` | Ferme la page et retourne au plan de table si la table est libérée. |

---

## 🎨 Patterns Récurrents

### Historique actions (Undo)
```dart
_saveHistoryState('add'); // Avant modification
// ... modification des notes ...
// Si besoin d'annuler : _undoLastAction()
```

### Mise à jour optimiste après transfert
```dart
// 1. Update local immédiat
LocalUpdateService.updateAfterTransferToNote(...);
// 2. Envoi API
await TransferService.executeTransferToNote(...);
// 3. Rechargement depuis serveur
await _loadExistingOrder();
```

### Gestion Socket.IO avec gestion d'erreurs
```dart
_socketService.setupSocketListeners(
  onOrderUpdated: () {
    if (!mounted) return;
    _loadExistingOrder().catchError((e) {
      if (e.toString().contains('defunct')) {
        print('[POS] Widget détruit (ignoré)');
      }
    });
  },
);
```

### Envoi cuisine avec nettoyage
```dart
await TransferService.sendToKitchen(...);
// Vider la note active après envoi
setState(() {
  newlyAddedItems.clear();
  if (activeNoteId == 'main') {
    mainNote = mainNote.copyWith(items: [], total: 0.0);
  }
});
await _loadExistingOrder(); // Recharger depuis serveur
```

---

## ⚠️ Points d'Attention

- **Historique actions** : Toujours appeler `_saveHistoryState()` avant toute modification de notes pour permettre l'undo
- **paidQuantity** : Ce champ doit être rechargé depuis le serveur après paiement (pas présent dans `OrderNote` initial)
- **Sous-notes** : Ne peuvent pas être payées partiellement (seulement la note principale via `PartialPaymentDialog`)
- **Transferts multi-commandes** : Vérifier l'impact sur `paidQuantity` qui est partagé avec le module Payment
- **Socket.IO** : Utiliser `Future.microtask` pour éviter `setState` pendant un build
- **Articles non payés** : Pour annulation, charger depuis API brute (`/orders?table=X`) car `order_repository` peut modifier les quantités
- **Permissions serveurs** : Toute nouvelle action sensible doit être liée à un flag (`server_permissions.json`) et propagée dans `PosOrderActionPanel`.

---

## 🧼 Maintenance
- Toute nouvelle action (dialog, bouton) doit appeler `_saveHistoryState` avant de modifier les notes pour garder la fonction undo.
- Documenter chaque nouveau dialog ou service ici pour garder la trace des flux.
- Lorsqu'un transfert touche plusieurs commandes, vérifier l'impact sur `OrderNoteItem.paidQuantity` (partagé avec la caisse).
- Mettre à jour `server_permissions.json` + `AdminServersPage` dès qu'un droit est ajouté/supprimé, puis vérifier l'application dans `PosOrderActionPanel`.

**Dernière mise à jour** : 2024-12-19 (profils serveurs / permissions)

