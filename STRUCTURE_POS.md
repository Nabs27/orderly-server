# 📋 Structure du POS - Vue d'ensemble

Ce document est une carte rapide du module POS (Point of Sale). Il donne la vue d'ensemble et renvoie vers trois fiches détaillées :

- `STRUCTURE_POS_HOME.md` — plan de table (Home)
- `STRUCTURE_POS_ORDER.md` — gestion des commandes
- `STRUCTURE_POS_PAYMENT.md` — caisse et paiements

Pour la partie backend, voir `STRUCTURE_SERVEUR.md`.

---

## 📑 Index Rapide

- **Annulation articles** → `STRUCTURE_POS_ORDER.md` → `CancellationService`, `CancelItemsDialog`
- **Crédit client** → `STRUCTURE_POS_PAYMENT.md` → `CreditClientDialog`, `payment_service.dart`
- **Historique tables** → `STRUCTURE_POS_HOME.md` → `HistoryService`, `HistoryView`
- **Mini-X report serveur** → `STRUCTURE_POS_HOME.md` → `ServerSalesReportDialog`, `ServerSalesReportService`, `ServerSalesReportController`
- **Paiement partiel** → `STRUCTURE_POS_PAYMENT.md` → `PartialPaymentDialog`, `payment_validation_service.dart`
- **Paiements divisés (Split Payments)** → `STRUCTURE_POS_PAYMENT.md` → `splitPaymentId`, `payMultiOrders`, `pos-report-x.js`
- **Source de vérité unique** → `STRUCTURE_POS_PAYMENT.md` → `_currentAllOrders`, `getAllItemsOrganized()`, `PaymentCalculator`, `PaymentValidationService`
- **Remises** → `STRUCTURE_POS_PAYMENT.md` → `DiscountSection`, `DiscountClientNameDialog`, `PaymentSummaryDialog`, `payment_service.dart`
- **Profils serveurs / droits** → `STRUCTURE_POS_ORDER.md` → `AdminServersPage`, `ServerPermissionsService`, `PosOrderActionPanel`
- **Sous-notes** → `STRUCTURE_POS_ORDER.md` → `AddNoteDialog`, `NoteActions.createSubNote`
- **Synchronisation tables** → `STRUCTURE_POS_HOME.md` → `OrdersSyncService`, `HomeSocketService`
- **Transferts** → `STRUCTURE_POS_ORDER.md` → `TransferService`, `TransferDialog`
- **Envoi cuisine** → `STRUCTURE_POS_ORDER.md` → `TransferService.sendToKitchen`
- **Commandes client** → `STRUCTURE_POS_ORDER.md` → `ClientOrderConfirmationService`, architecture "Boîte aux Lettres" (polling 5s)

---

## 🔍 Où trouver... ?

| Je cherche... | Module | Fichier principal | Service/Widget clé |
|---------------|--------|-------------------|-------------------|
| Comment ajouter une table ? | Home | `PosHomePage_refactor.dart` | `AddTableDialog`, `TableActions` |
| Comment créer une sous-note ? | Order | `PosOrderPage_refactor.dart` | `AddNoteDialog`, `NoteActions.createSubNote` |
| Comment appliquer une remise ? | Payment | `PosPaymentPage_refactor.dart` | `DiscountSection`, `DiscountClientNameDialog`, `PaymentCalculator.calculateFinalTotal` |
| Comment justifier une remise avec un nom client ? | Payment | `PosPaymentPage_refactor.dart` | `DiscountClientNameDialog`, `DiscountSection` |
| Comment transférer des articles ? | Order | `PosOrderPage_refactor.dart` | `TransferService`, `TransferDialog` |
| Comment gérer le crédit client ? | Payment | `PosPaymentPage_refactor.dart` | `CreditClientDialog`, `payment_service.processCreditPayment` |
| Comment synchroniser les tables ? | Home | `PosHomePage_refactor.dart` | `OrdersSyncService.syncOrdersWithTables`, `HomeSocketService` |
| Comment voir mes encaissements (mini-X) ? | Home | `PosHomePage_refactor.dart` | `ServerSalesReportDialog`, `ServerSalesReportService`, `BottomToolbar` |
| Comment annuler des articles ? | Order | `PosOrderPage_refactor.dart` | `CancellationService.cancelItems`, `CancelItemsDialog` |
| Comment faire un paiement partiel ? | Payment | `PosPaymentPage_refactor.dart` | `PartialPaymentDialog`, `payment_validation_service.getItemsToPay` |
| Comment fonctionnent les paiements divisés ? | Payment | `PosPaymentPage_refactor.dart`, `server/controllers/pos-payment.js` | `splitPaymentId`, `payMultiOrders`, regroupement dans KPI via `pos-report-x.js` |
| Quelle est la source de vérité pour les quantités non payées ? | Payment | `PosPaymentPage_refactor.dart` | `_currentAllOrders` (backend) via `getAllItemsOrganized()`, jamais `mainNote.items` directement |
| Comment générer une facture ? | Payment | `PosPaymentPage_refactor.dart` | `InvoicePreviewDialog`, `PaymentService.generateInvoicePDF` |
| Comment changer de serveur ? | Login/Order | `pos_login_page.dart` / `PosOrderPage_refactor.dart` | Déconnexion → re-login (PIN) / `TransferServerDialog` (transfert table) |
| Comment gérer les droits serveurs ? | Admin/Order | `admin_servers_page.dart`, `PosOrderPage_refactor.dart` | `ServersService`, `ServerPermissionsService`, `PosOrderActionPanel` |
| Comment afficher le résumé du paiement ? | Payment | `PosPaymentPage_refactor.dart` | `PaymentSummaryDialog`, `PaymentSection` |
| Comment confirmer/décliner une commande client ? | Order | `PosOrderPage_refactor.dart` | `ClientOrderConfirmationService`, `_confirmClientOrder()`, `_declineClientOrder()`, boutons dans `PosOrderAppBar` |

---

## 📂 Architecture Générale

```
lib/features/pos/
├── models/
│   └── order_note.dart
├── pages/
│   ├── home/ (plan de table)
│   ├── order/ (prise de commande)
│   └── payment/ (caisse)
├── pos_login_page.dart
├── pos_invoice_viewer_page.dart
└── widgets/ (composants partagés)
```

| Module | Fichier principal | Points clés | Fiche détaillée |
|--------|-------------------|-------------|-----------------|
| Home (plan de table) | `pages/home/PosHomePage_refactor.dart` | Grille tables, sockets, historique | `STRUCTURE_POS_HOME.md` |
| Order (commande) | `pages/order/PosOrderPage_refactor.dart` | Notes multiples, transferts, annulations | `STRUCTURE_POS_ORDER.md` |
| Payment (caisse) | `pages/payment/PosPaymentPage_refactor.dart` | Paiement total/partiel, crédits, factures | `STRUCTURE_POS_PAYMENT.md` |
| Admin (profils serveurs) | `features/admin/admin_servers_page.dart` | Création profils, permissions, rôles | `STRUCTURE_SERVEUR.md` |

---

## 📊 Modèles de Données (résumé)

| Modèle | Rôle | Champs clés |
|--------|------|-------------|
| `OrderNote` | Note principale ou sous-note d'une table | `id`, `name`, `covers`, `items`, `total`, `paid`, `sourceOrderId` |
| `OrderNoteItem` | Article dans une note | `id`, `name`, `price`, `quantity`, `isSent`, `paidQuantity`, `sourceOrderId`, `sourceNoteId` |
| `PaymentRecord` (backend) | Enregistrement de paiement | `timestamp`, `mode`, `amount`, `items`, `splitPaymentId`, `isSplitPayment`, `isCompletePayment`, `orderId`, `noteId` |

Notes principales (`id = main`) et sous-notes (`id = sub_x`) partagent la même structure. Les quantités payées (`paidQuantity`) permettent le suivi des paiements partiels.

🆕 **Source de vérité unique** : Les quantités non payées (`unpaidQuantity = quantity - paidQuantity`) viennent toujours de `_currentAllOrders` (données backend) via `getAllItemsOrganized()`. Ne jamais utiliser `mainNote.items` ou `subNotes` directement pour les calculs de paiement.

🆕 **Paiements divisés** : Les paiements divisés utilisent `splitPaymentId` (format: `split_TIMESTAMP`) pour regrouper tous les modes de paiement d'une même transaction. Le regroupement se fait dans les rapports KPI via `splitPaymentId` (sans le mode de paiement dans l'ID).

🆕 **Commandes client (Architecture "Boîte aux Lettres")** : Les commandes passées depuis l'app mobile client sont déposées dans MongoDB par le serveur Cloud avec `waitingForPos: true`, `processedByPos: false`, `id: null`. Le serveur POS local les aspire automatiquement toutes les 5 secondes via `pullFromMailbox()`, leur attribue un ID local, et les marque comme traitées dans MongoDB. Une fois confirmées, elles sont gérées exactement comme les commandes POS (même structure, même traitement). Voir `STRUCTURE_SERVEUR.md` pour les détails backend.

---

## 🧱 Bandeau supérieur (Home)

- `HeaderActions` : bloc isolé tout à gauche regroupant **Simulation** et **Admin** (actions provisoires).
- `HeaderLogoTitle` : branding + rappel du serveur connecté (temps réel via `HomeState`).
- Plus de sélection de serveur sur le plan (un serveur se déconnecte, revient à la page PIN).  
- `DateTimeBadge`, bouton `Historique` et bouton `Déconnexion` sont regroupés à droite.
- **Mode Manager** : quand `userRole = Manager/ADMIN`, le titre et les boutons reflètent la vue globale (“Vue manager – Toutes les tables”, bouton “Changer de serveur”).

Ces éléments sont décrits dans `PosHomePage_refactor.dart`.

---

## 👤 Vue Manager (plan Home)

- **Overview globale** : tant qu’aucun serveur n’est sélectionné, `PosHomePage_refactor.dart` affiche une grille de cartes (`_AdminServerOverviewCard`) listant chaque serveur avec ses tables actives, l’encours total, les tables “à encaisser” et la table la plus ancienne.
- **Sélection de serveur** : bouton “Ouvrir” sur une carte → `_adminViewingServer` prend la valeur du serveur ciblé et on retombe sur la grille standard (`TableGrid`) mais avec toutes les permissions (l’admin agit comme le serveur sélectionné).
- **Historique manager** : si l’admin ouvre l’historique sans avoir choisi de serveur, un placeholder lui demande d’en sélectionner un. Une fois la sélection faite, `HistoryView` est filtré sur ce serveur.
- **Retour overview** : bouton “Changer de serveur” (dans l’entête) pour revenir à la vue globale et basculer sur un autre serveur sans se déconnecter.

Réfs : `PosHomePage_refactor.dart` – helpers `_isAdminOverviewVisible`, `_selectServerForAdmin`, classes `_AdminServerOverviewCard` et `_AdminOverviewMetric`.

---

## 💳 Crédit client (POS & serveur)

- **POS** : `CreditClientDialog` impose désormais nom + téléphone pour tout nouveau client ; `PosPaymentPage_refactor` transmet le serveur courant et un ticket détaillé lorsqu’un paiement est réalisé à crédit (`PaymentService.processCreditPayment`).
- **Suivi dettes** : `DebtPaymentDialog` / `ClientHistoryPage` lisent les transactions via `credit.js`, affichent le solde progressif et permettent d’ouvrir le ticket associé (`TicketPreviewDialog`). Les paiements partiels (`pay-oldest`) transmettent aussi le serveur.
- **Backend** : `server/controllers/credit.js` stocke le champ `server` et le `ticket` sur chaque transaction (création et simulation). Le module X (`pos-report-x.js`) filtre désormais `collectCreditPayments` par serveur, ce qui évite d’additionner les crédits de tous les serveurs dans l’encart Encaissements/Mini-X.
- **Simulation** : `routes/admin-simulation.js` renseigne également le serveur lorsqu’il génère des dettes fictives pour conserver une cohérence lors des rapports.

Ces éléments garantissent que les blocs “Crédit” du dashboard reflètent uniquement le serveur sélectionné et qu’un ticket peut être consulté pour chaque dette.

---

## 🔄 Navigation Globale

```
PosHomePage
  ├─ Tap table → PosOrderPage (ou sélection de sous-note)
  ├─ Long press table occupée → PosPaymentPage
  └─ Historique / actions admin → dialogs dédiés

PosOrderPage
  ├─ Envoi cuisine → retour Home
  ├─ Paiement → PosPaymentPage
  └─ Transferts (notes/tables/serveurs)

PosPaymentPage
  ├─ Paiement complet → retour Home (force refresh)
  ├─ Paiement partiel → reste sur Payment
  └─ Génération facture → PosInvoiceViewerPage
```

---

## 🔌 Services Partagés

| Sujet | Emplacement | Utilisation |
|-------|-------------|-------------|
| Client HTTP (`ApiClient`) | `lib/core/api_client.dart` | Accès API (orders, payments, crédits, admin) |
| Socket.IO | `HomeSocketService`, `OrderSocketService`, `CreditSocketService` | Synchronisation tables, commandes, crédits |
| Stockage local | `SharedPreferences` (via `TablesRepository`, `ApiPrefsService`, etc.) | Tables, préférences API, session utilisateur |

---

## 📡 Endpoints REST utilisés (extraits)

- `GET /orders?table=X`, `POST /orders`, `POST /orders/:id/payment`
- `POST /orders/:id/cancel`, `POST /api/payments`
- `GET /api/credit/clients`, `POST /api/credit/transactions`
- `GET /api/admin/report-x`

(Détails complets : `STRUCTURE_POS_*` et `STRUCTURE_SERVEUR.md`)

---

## 🔧 Maintenance

1. Mettre à jour la fiche détaillée concernée (Home/Order/Payment) après toute modification.
2. Reporter le lien ou la section touchée dans ce document si l’architecture globale change.
3. Mentionner la date de mise à jour et le type de changement.

---

## 📚 Références

- **Home** : `STRUCTURE_POS_HOME.md`
- **Order** : `STRUCTURE_POS_ORDER.md`
- **Payment** : `STRUCTURE_POS_PAYMENT.md`
- **Serveur** : `STRUCTURE_SERVEUR.md`

**Dernière mise à jour** : 2025-01-24 (Architecture "Boîte aux Lettres" pour commandes client, polling 5s, confirmation/déclin commandes client)

