# 💳 Module POS – Payment (Caisse)

## 📍 Objectif
Décrire la structure du module « Payment » : paiement complet/partiel, modes de règlement, crédits clients, génération de factures. Ce fichier complète `STRUCTURE_POS.md`.

---

## 📂 Fichiers clés

| Type | Fichier | Rôle |
|------|---------|------|
| Page principale | `lib/features/pos/pages/payment/PosPaymentPage_refactor.dart` | Interface de paiement (notes, remises, modes de règlement) |
| Services | `services/payment_service.dart` | Communication avec l’API (ventilation articles, enregistrements paiements) |
| Validation | `services/payment_validation_service.dart` | Vérification prérequis (mode, crédit, facture, quantités) |
| Socket crédits | `services/credit_socket_service.dart` | Synchronisation des soldes clients crédit |
| Utils | `utils/item_organizer.dart`, `utils/payment_calculator.dart` | Organisation des articles et calculs financiers |

---

## 🎯 Responsabilités
- Afficher les articles à payer (note principale, sous-notes, ou combinaison).
- Gérer les modes de paiement (ESPECE, CARTE/TPE, CHEQUE, OFFRE, CREDIT).
- Supporter les remises (montant fixe ou pourcentage).
- Permettre les paiements partiels (sélection d’articles précis).
- Enregistrer les transactions de crédit client (dettes, règlements).
- Générer les factures PDF et les tickets.

---

## 🧩 Services & Utils

| Élément | Description |
|---------|-------------|
| `payment_service.dart` | Ventile les quantités par `(orderId, noteId)`, enregistre les paiements (`POST /orders/:id/payment`, `POST /api/payments`). Gère aussi les transactions crédit (DEBIT). |
| `payment_validation_service.dart` | 🆕 **SOURCE DE VÉRITÉ UNIQUE** : Utilise `getAllItemsOrganized()` qui vient de `_currentAllOrders` (données backend) pour obtenir `unpaidQuantity`. Vérifie le mode sélectionné, la présence d'un client crédit, les remises, et prépare `itemsToPay` avec `orderId` et `noteId` pour la traçabilité. |
| `credit_socket_service.dart` | Écoute les événements liés aux crédits pour rafraîchir les soldes affichés. |
| `item_organizer.dart` | Regroupe les articles non payés par catégorie pour l'affichage. |
| `payment_calculator.dart` | 🆕 **SOURCE DE VÉRITÉ UNIQUE** : Utilise `organizedItemsForPartialPayment` et `getAllItemsOrganized()` qui viennent de `_currentAllOrders` (données backend) pour calculer les totaux. Les paramètres `mainNote` et `subNotes` sont conservés pour compatibilité mais non utilisés pour les calculs. |

---

## 🧱 Widgets principaux

- **Panneau gauche**
  - `PaymentLeftPanel.dart` : sélection des notes, liste des articles, totaux intermédiaires.
  - `NoteSelectionSection.dart` : bascule entre « all », `main`, `sub_x`, `partial`.
  - `ItemsDetailSection.dart`, `TotalsSection.dart`.

- **Panneau droit**
  - `PaymentSection.dart` : panneaux mode de paiement, remises et actions.
  - `PaymentModesSection.dart` : boutons ESPECE / CARTE / CREDIT / etc.
  - `DiscountSection.dart` : saisie des remises (bouton pour ouvrir dialog nom client).
  - `DiscountClientNameDialog.dart` : 🆕 dialog pour saisir prénom/nom du client (justification remise).
  - `PaymentAppBar.dart` : entête (retour, impression note, facture).

- **Dialogs**
  - `PartialPaymentDialog.dart` : sélection de quantités/articles pour paiement partiel.
  - `CreditClientDialog.dart` + `ClientHistoryPage.dart` : gestion des clients crédit.
  - `DiscountClientNameDialog.dart` : 🆕 saisie prénom/nom client pour justifier une remise (optionnel, prérempli si sous-note).
  - `InvoicePreviewDialog.dart` + `InvoiceForm.dart` : saisie info facture.
  - `TicketPreviewDialog.dart` : aperçu ticket avant impression.

---

## 🔄 Scénarios de paiement

```
Sélection note
  ├─ 'all' → regroupe toutes les notes (main + sub)
  ├─ 'main' ou 'sub_x' → ne montre que la note choisie
  └─ 'partial' → ouvre PartialPaymentDialog pour choisir des articles précis

Validation
  ├─ PaymentValidationService.validatePaymentPrerequisites()
  │   └─ vérifie mode, client crédit, facture, remises
  ├─ PaymentValidationService.getItemsToPay()
  │   └─ 🆕 Utilise getAllItemsOrganized() (source de vérité unique)
  │       └─ construit la liste des articles/quantités avec orderId et noteId
  └─ PaymentValidationService.processPayment()
      ├─ 🆕 Recharge _currentAllOrders avant paiement (_reloadAllOrders)
      ├─ marque les articles comme payés (ventilation par orderId/noteId)
      ├─ enregistre les paiements (PaymentService.recordIndividualPayment)
      │   └─ 🆕 Pour paiements divisés : crée splitPaymentId unique (sans mode)
      └─ traite le crédit si mode = CREDIT (PaymentService.processCreditPayment)

Backend (payMultiOrders)
  ├─ 🆕 ÉTAPE 1: Calculer subtotals SANS modifier paidQuantity
  ├─ 🆕 ÉTAPE 2: Créer TOUS les paiements dans paymentHistory AVANT paidQuantity
  │   └─ 🆕 Utilise processAllItemInstances() pour traiter TOUTES les instances
  ├─ 🆕 ÉTAPE 3: Modifier paidQuantity APRÈS création réussie des paiements
  └─ 🆕 ÉTAPE 4: Archiver commandes APRÈS tous paiements créés

Retour
  ├─ Paiement complet → Navigator.pop(force_refresh = true)
  ├─ Paiement partiel → reste sur l'écran
  └─ Facture demandée → PosInvoiceViewerPage avant de revenir
```

---

## 💼 Modes de paiement & remises

| Mode | Particularités |
|------|----------------|
| ESPECE / CARTE / TPE | Paiement classique (montant encaissé immédiatement). |
| CHEQUE | Identique aux autres modes non différés. |
| OFFRE | Encaissement à 0 TND mais trace la remise. |
| CREDIT | Crée une transaction DEBIT dans le module crédit client, nécessite la sélection d’un client. |

Remises :
- Fixe → montant TND soustrait au sous-total.
- Pourcentage → `%` appliqué au sous-total (`isPercentDiscount`).
- 🆕 **Nom du client** : optionnel, permet de justifier la remise (prénom + nom, capitalisation automatique).
  - Prérempli automatiquement si c'est une sous-note avec un nom.
  - Saisi via `DiscountClientNameDialog` (dialog séparé).
  - Stocké dans `paymentRecord.discountClientName` (backend).
  - Affiché dans historique (`DiscountDetailsDialog`), KPI et rapport X.
- Trackées dans l'historique (`discountDetails`, `nombreRemises`).

---

## 👥 Crédit client

- `CreditClientDialog` : sélection d’un client existant ou création rapide.
- `PaymentService.processCreditPayment` : enregistre la dette (transaction DEBIT).
- `PaymentService.recordIndividualPayment` : enregistre quand même le paiement côté POS (mode CREDIT).
- `ClientHistoryPage` : montre les transactions récentes, soldes.
- `credit_socket_service.dart` : rafraîchit les soldes quand une dette est réglée ailleurs.

---

## 📑 Facturation & tickets

| Action | Détails |
|--------|---------|
| Impression note | `_printNote()` → `TicketPreviewDialog` (pré-addition). |
| Ticket de caisse | `_printTicket()` (console + preview). |
| Facture PDF | `PaymentService.generateInvoicePDF` → `PosInvoiceViewerPage`. |
| Facture requise | `needsInvoice = true` + formulaire `InvoiceForm`. |

---

## 🎨 Patterns Récurrents

### Validation avant paiement
```dart
final validationError = PaymentValidationService.validatePaymentPrerequisites(
  selectedPaymentMode: selectedPaymentMode,
  selectedNoteForPayment: selectedNoteForPayment,
  selectedPartialQuantities: selectedPartialQuantities,
  needsInvoice: needsInvoice,
  companyName: companyName,
  selectedClientForCredit: _selectedClientForCredit,
);
if (validationError != null) {
  // Afficher erreur ou ouvrir dialog
  return;
}
```

### Traitement paiement avec rechargement (🆕 Source de vérité unique)
```dart
// 1. Rafraîchir avant paiement (CRITIQUE pour avoir les dernières unpaidQuantity)
await _reloadAllOrders(); // Met à jour _currentAllOrders depuis le backend
// 2. Valider et traiter
//    - PaymentValidationService.getItemsToPay() utilise getAllItemsOrganized()
//    - getAllItemsOrganized() vient de _currentAllOrders (source de vérité unique)
await PaymentValidationService.processPayment(...);
// 3. Recharger après paiement pour voir les nouveaux paidQuantity
await _reloadAllOrders(); // Met à jour _currentAllOrders avec les nouvelles paidQuantity
```

### Paiement crédit avec transaction
```dart
// 1. Créer transaction DEBIT AVANT de supprimer articles
if (selectedPaymentMode == 'CREDIT') {
  await _processCreditPayment(_selectedClientForCredit!, finalTotal);
}
// 2. Marquer articles comme payés
await PaymentValidationService.processPayment(...);
// 3. Recharger balance client
await _reloadClientBalance(clientId);
```

### Répartition remise multi-commandes
```dart
// Remise fixe : répartir proportionnellement
if (isPercentDiscount != true && totalSubtotal > 0) {
  final proportion = batchSubtotal / totalSubtotal;
  allocDiscount = discount * proportion;
} else {
  // Remise % : identique pour chaque commande
  allocDiscount = discount;
}
```

### 🆕 Paiements divisés (Split Payments)
```dart
// Frontend : Lors d'un paiement divisé, chaque mode crée un paiement séparé
// mais avec le même splitPaymentId (sans le mode dans l'ID)
// Exemple : split_2025-01-15T10:30:00.000Z (pas split_2025-01-15T10:30:00.000Z_ESPECE)

// Backend (payMultiOrders) :
const sharedTimestamp = new Date().toISOString();
const splitPaymentBaseId = `split_${sharedTimestamp}`; // Sans le mode
// Tous les modes partagent le même splitPaymentId pour regroupement dans KPI
```

### 🆕 Traitement instances multiples d'articles
```javascript
// Backend (pos-payment.js) : processAllItemInstances()
// Traite TOUTES les instances d'un article dans une note, pas seulement la première
function processAllItemInstances(targetNote, itemToRemove) {
  const paidItems = [];
  const itemUpdates = [];
  let removedTotal = 0;
  let remainingQty = itemToRemove.quantity;
  
  // Parcourir TOUTES les instances de l'article dans la note
  for (const existingItem of targetNote.items) {
    if (existingItem.id === itemToRemove.id && existingItem.name === itemToRemove.name) {
      const unpaidQty = existingItem.quantity - (existingItem.paidQuantity || 0);
      if (unpaidQty > 0 && remainingQty > 0) {
        const qtyToPay = Math.min(remainingQty, unpaidQty);
        // Traiter cette instance...
        remainingQty -= qtyToPay;
      }
    }
  }
  return { paidItems, itemUpdates, removedTotal };
}
```

### 🆕 Paiements divisés (Split Payments)
```dart
// Frontend : Lors d'un paiement divisé, chaque mode crée un paiement séparé
// mais avec le même splitPaymentId (sans le mode dans l'ID)
// Exemple : split_2025-01-15T10:30:00.000Z (pas split_2025-01-15T10:30:00.000Z_ESPECE)

// Backend (payMultiOrders) :
const sharedTimestamp = new Date().toISOString();
const splitPaymentBaseId = `split_${sharedTimestamp}`; // Sans le mode
// Tous les modes partagent le même splitPaymentId pour regroupement dans KPI
```

### 🆕 Traitement instances multiples d'articles
```javascript
// Backend (pos-payment.js) : processAllItemInstances()
// Traite TOUTES les instances d'un article dans une note, pas seulement la première
function processAllItemInstances(targetNote, itemToRemove) {
  const paidItems = [];
  const itemUpdates = [];
  let removedTotal = 0;
  let remainingQty = itemToRemove.quantity;
  
  // Parcourir TOUTES les instances de l'article dans la note
  for (const existingItem of targetNote.items) {
    if (existingItem.id === itemToRemove.id && existingItem.name === itemToRemove.name) {
      const unpaidQty = existingItem.quantity - (existingItem.paidQuantity || 0);
      if (unpaidQty > 0 && remainingQty > 0) {
        const qtyToPay = Math.min(remainingQty, unpaidQty);
        // Traiter cette instance...
        remainingQty -= qtyToPay;
      }
    }
  }
  return { paidItems, itemUpdates, removedTotal };
}
```

---

## 🎁 Pourboires

### Calcul des pourboires

Les pourboires sont calculés pour les paiements scripturaux (TPE/CHEQUE/CARTE) via :
- `enteredAmount` : Montant réellement encaissé (saisi par le serveur, peut inclure un pourboire)
- `allocatedAmount` : Montant nécessaire pour couvrir la commande (après remise, sans pourboire)
- `excessAmount` : Pourboire = `enteredAmount - allocatedAmount` (si > 0)

**Important** : `allocatedAmount` doit être calculé **après remise** :
```javascript
// Backend (pos-payment.js)
const orderNetAmount = orderSubtotal - orderDiscountAmount; // Montant APRÈS remise
const allocatedAmount = orderNetAmount * splitProp; // Pour split payment
// ou
const allocatedAmount = orderSubtotal - orderDiscountAmount; // Pour paiement simple
```

### Gestion du flag `hasCashInPayment`

Le flag `hasCashInPayment` détermine si le pourboire scriptural doit être comptabilisé :

| Scénario | `hasCashInPayment` | Pourboire scriptural | Comptabilisation |
|----------|-------------------|---------------------|------------------|
| Paiement TPE seul avec pourboire | `false` | ✅ Comptabilisé | Inclus dans `totalRecette` |
| Paiement divisé TPE + ESPECE | `true` | ❌ Indicatif uniquement | **Exclu** de `totalRecette` |
| Paiement ESPECE seul | `true` | N/A | Le serveur prend le pourboire du liquide |

**Règle** : Si du liquide est présent dans un paiement divisé, le pourboire scriptural est purement indicatif et ne doit **PAS** être inclus dans `totalRecette`. Le serveur prend le pourboire directement du liquide.

### Enregistrement dans paymentRecord

```javascript
// Backend (pos-payment.js)
const paymentRecord = {
  enteredAmount: enteredAmount,      // Montant réellement encaissé
  allocatedAmount: allocatedAmount,  // Montant nécessaire (après remise)
  excessAmount: excessAmount,        // Pourboire (si > 0)
  hasCashInPayment: hasCashInPayment, // Présence de liquide
  // ...
};
```

### Affichage dans les rapports

- **X Report** : Les pourboires sont affichés séparément par serveur en bas du récapitulatif
- **KPI** : Les pourboires sont inclus dans "Recette encaissée" seulement si `hasCashInPayment === false`
- **Historique** : Les pourboires sont affichés comme indication ("Inclut pourboire: X TND")

---

## 🔄 Single Source of Truth pour les Paiements

### Module `payment-processor.js`

Le module `server/utils/payment-processor.js` est la **source de vérité unique** pour la déduplication et le calcul des paiements :

- ✅ `pos-report-x.js` (X Report, KPI) utilise `paymentProcessor.calculatePaymentsByMode()` et `paymentProcessor.deduplicateAndCalculate()`
- ✅ `history-processor.js` (Historique) utilise les mêmes principes de déduplication
- ⚠️ **En cours d'intégration complète** : `history-processor.js` doit encore être refactorisé pour utiliser ce module

### Fonctions principales

#### `deduplicateAndCalculate(payments)`

Déduplique les transactions de paiements divisés multi-commandes et calcule les totaux :
- **Clé de déduplication** : `splitPaymentId + mode + enteredAmount`
- **Problème résolu** : Pour N commandes, chaque transaction apparaît N fois dans `paymentHistory`. Le module déduplique correctement.
- **Retourne** : `{ uniquePayments, totals, tipsByServer }`
  - `totals.chiffreAffaire` : Somme des `allocatedAmount` (valeur des tickets)
  - `totals.totalRecette` : Somme des `enteredAmount` (avec pourboires si pas de liquide)
  - `totals.totalPourboires` : Somme des `excessAmount` par serveur

#### `calculatePaymentsByMode(payments)`

Groupe les paiements par mode et calcule les pourboires :
- Regroupe par `splitPaymentId` pour les paiements divisés
- Calcule les pourboires par serveur en dédupliquant correctement
- **Retourne** : `{ [mode]: { total, count }, _tipsByServer: { [server]: amount } }`

### Garantie de cohérence

Cela garantit que **History = KPI = X Report** (cohérence des données) :
- Même logique de déduplication
- Même calcul des totaux
- Même attribution des pourboires

---

## ⚠️ Points d'Attention

- **🆕 SOURCE DE VÉRITÉ UNIQUE (quantités)** : 
  - Les quantités non payées (`unpaidQuantity`) viennent toujours de `_currentAllOrders` (données backend) via `getAllItemsOrganized()`
  - Ne jamais utiliser `mainNote.items` ou `subNotes` directement pour les calculs de paiement
  - `PaymentCalculator` et `PaymentValidationService` utilisent `organizedItemsForPartialPayment` qui dérive de `_currentAllOrders`
  - Cela garantit la synchronisation entre frontend et backend et évite les écarts de quantité

- **🆕 SOURCE DE VÉRITÉ UNIQUE (paiements)** :
  - Toujours utiliser `payment-processor.js` pour la déduplication et les calculs
  - Ne jamais recalculer manuellement les totaux pour les paiements divisés
  - Vérifier que History, KPI et X Report utilisent les mêmes fonctions du module
  - **Clé de déduplication** : `splitPaymentId + mode + enteredAmount` pour identifier les transactions uniques

- **🆕 Paiements divisés (Split Payments)** :
  - Les paiements divisés utilisent un `splitPaymentId` unique (format: `split_TIMESTAMP`) pour regrouper tous les modes de paiement
  - Le `splitPaymentId` ne contient PAS le mode de paiement pour permettre le regroupement dans les rapports KPI
  - Tous les paiements d'une transaction divisée partagent le même `timestamp` et `splitPaymentId`
  - Le regroupement se fait dans `pos-report-x.js` via `splitPaymentId` pour éviter les doublons dans les rapports

- **🆕 Pourboires** :
  - Les pourboires sont calculés uniquement pour les paiements scripturaux (TPE/CHEQUE/CARTE)
  - Si `hasCashInPayment === true`, le pourboire scriptural est indicatif et n'est **pas** inclus dans `totalRecette`
  - Les pourboires sont affichés séparément par serveur dans le X Report
  - Vérifier que `excessAmount` est correctement calculé : `enteredAmount - allocatedAmount` (après remise)

- **🆕 Instances multiples d'articles** :
  - Le backend utilise `processAllItemInstances()` pour traiter TOUTES les instances d'un article dans une note
  - Si le même article (même `id` et `name`) apparaît plusieurs fois dans une note, toutes les instances sont traitées
  - La quantité demandée est distribuée sur toutes les instances disponibles (pas seulement la première)
  - Cela évite qu'un article reste non payé si plusieurs instances existent

- **🆕 Ordre des opérations dans payMultiOrders** :
  1. Calculer les subtotals SANS modifier `paidQuantity`
  2. Créer TOUS les paiements dans `paymentHistory` AVANT de modifier `paidQuantity`
  3. Modifier `paidQuantity` APRÈS la création réussie des paiements
  4. Archiver les commandes APRÈS tous les paiements créés et `paidQuantity` mis à jour
  - Cet ordre garantit qu'un paiement est toujours créé même si une commande est archivée entre-temps

- **Paiement multi-commandes** : Les remises sont réparties proportionnellement entre commandes (voir `PaymentService.removeNoteItemsFromTable`)
- **Sous-notes** : Ne peuvent pas être payées partiellement (seulement note principale via `PartialPaymentDialog`)
- **paidQuantity** : Doit être rechargé depuis serveur après paiement via `_reloadAllOrders()` (pas dans `OrderNote` initial)
- **Remises** : Toujours passer `discount`, `isPercentDiscount`, `finalAmount` ET `discountClientName` (optionnel) à l'API pour cohérence reporting
- **Crédit client** : Créer la transaction DEBIT AVANT de supprimer les articles pour éviter les incohérences
- **Force refresh** : Retourner `{'force_refresh': true}` après paiement complet pour resynchroniser HomePage
- **Ventilation articles** : Respecter la logique `(orderId, noteId, paidQuantity)` pour éviter les écarts de quantité

---

## 🧼 Maintenance
- Toute évolution de la ventilation des articles doit respecter la logique `(orderId, noteId, paidQuantity)` pour éviter les écarts.
- Après chaque ajout de mode paiement ou de dialog, mettre à jour la section correspondante.
- Garder les références aux services alignées : si un service change de signature, ajuster cette fiche.

**Dernière mise à jour** : 2025-01-03 (Intégration pourboires, single source of truth payment-processor.js, calcul allocatedAmount après remise)

