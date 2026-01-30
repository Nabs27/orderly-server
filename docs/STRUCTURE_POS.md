# 📋 Structure du POS - Vue d'ensemble

Ce document est une carte rapide du module POS (Point of Sale). Il donne la vue d'ensemble et renvoie vers les fiches détaillées :

- `STRUCTURE_POS_HOME.md` — plan de table (Home)
- `STRUCTURE_POS_ORDER.md` — gestion des commandes
- `STRUCTURE_POS_PAYMENT.md` — caisse et paiements
- `STRUCTURE_POS_ADMIN.md` — dashboard admin (KPI, historique, rapport X)
- `STRUCTURE_POS_CLIENT.md` — application client mobile
- `STRUCTURE_POS_CUISINE.md` — dashboard cuisine / stations

Pour la partie backend, voir `STRUCTURE_SERVEUR.md`.

---

## 📑 Index Rapide

- **Annulation articles** → `STRUCTURE_POS_ORDER.md` → `CancellationService`, `CancelItemsDialog`
- **Crédit client** → `STRUCTURE_POS_PAYMENT.md` → `CreditClientDialog`, `payment_service.dart`
- **Dashboard Admin** → `STRUCTURE_POS_ADMIN.md` → `admin_dashboard_page.dart`, `admin_dashboard_kpi_section.dart`, `enriched_history_section.dart`, `report_x_page.dart`
- **App Client** → `STRUCTURE_POS_CLIENT.md` → `flutter_client_app/` (menu, panier, confirmation, historique, facture)
- **Dashboard Cuisine** → `STRUCTURE_POS_CUISINE.md` → `dashboard_page.dart` (Flutter), `public/dashboard/` (Web)
- **Historique tables** → `STRUCTURE_POS_HOME.md` → `HistoryService`, `HistoryView`
- **Mini-X report serveur** → `STRUCTURE_POS_HOME.md` → `ServerSalesReportDialog`, `ServerSalesReportService`, `ServerSalesReportController`
- **Paiement partiel** → `STRUCTURE_POS_PAYMENT.md` → `PartialPaymentDialog`, `payment_validation_service.dart`
- **Paiements divisés (Split Payments)** → `STRUCTURE_POS_PAYMENT.md` → `splitPaymentId`, `payMultiOrders`, `pos-report-x.js`
- **Pourboires** → `STRUCTURE_POS_PAYMENT.md` → Section "Pourboires" (calcul, `hasCashInPayment`, affichage)
- **Source de vérité unique (paiements)** → `STRUCTURE_POS_PAYMENT.md` → Section "Single Source of Truth pour les Paiements" (`payment-processor.js`)
- **Source de vérité unique (quantités)** → `STRUCTURE_POS_PAYMENT.md` → `_currentAllOrders`, `getAllItemsOrganized()`, `PaymentCalculator`, `PaymentValidationService`
- **Remises** → `STRUCTURE_POS_PAYMENT.md` → `DiscountSection`, `DiscountClientNameDialog`, `PaymentSummaryDialog`, `payment_service.dart`
- **Stock / inventaire** → `STRUCTURE_POS_ADMIN.md` → `AdminInventoryPage`, `inventorySync.js`, déduction à l'envoi cuisine dans `orders.js`
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
| Comment accéder au dashboard admin ? | Admin | `admin_dashboard_page.dart` | Navigation depuis HeaderActions ou route directe |
| Comment voir les KPI du jour ? | Admin | `admin_dashboard_kpi_section.dart` | Clic sur les cartes KPI dans le dashboard |
| Comment voir l'historique des encaissements ? | Admin | `paid_history_dialog.dart` | Clic sur "Recette encaissée" dans les KPI |
| Comment générer un rapport X ? | Admin | `report_x_page.dart` | Navigation depuis le dashboard admin |
| Comment gérer le stock (inventaire) ? | Admin | `admin_inventory_page.dart` | Stock boissons, seuils, alertes, historique ; déduction à l'envoi cuisine via `orders.js` |
| Comment accéder au dashboard cuisine ? | Dashboard | `dashboard_page.dart` | Route `/dashboard` dans l'app Flutter principale |
| Comment les clients commandent-ils ? | Client | `STRUCTURE_POS_CLIENT.md` | Application mobile dédiée (`flutter_client_app/`) |

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
| Payment (caisse) | `pages/payment/PosPaymentPage_refactor.dart` | Paiement total/partiel, crédits, factures, pourboires | `STRUCTURE_POS_PAYMENT.md` |
| Admin (dashboard) | `features/admin/admin_dashboard_page.dart` | KPI, historique enrichi, rapport X | Voir section Dashboard Admin ci-dessous |
| Admin (profils serveurs) | `features/admin/admin_servers_page.dart` | Création profils, permissions, rôles | `STRUCTURE_SERVEUR.md` |

---

## 📊 Modèles de Données (résumé)

| Modèle | Rôle | Champs clés |
|--------|------|-------------|
| `OrderNote` | Note principale ou sous-note d'une table | `id`, `name`, `covers`, `items`, `total`, `paid`, `sourceOrderId` |
| `OrderNoteItem` | Article dans une note | `id`, `name`, `price`, `quantity`, `isSent`, `paidQuantity`, `sourceOrderId`, `sourceNoteId` |
| `PaymentRecord` (backend) | Enregistrement de paiement | `timestamp`, `mode`, `amount`, `items`, `splitPaymentId`, `isSplitPayment`, `isCompletePayment`, `orderId`, `noteId`, `enteredAmount`, `allocatedAmount`, `excessAmount`, `hasCashInPayment` |

Notes principales (`id = main`) et sous-notes (`id = sub_x`) partagent la même structure. Les quantités payées (`paidQuantity`) permettent le suivi des paiements partiels.

🆕 **Source de vérité unique** : Les quantités non payées (`unpaidQuantity = quantity - paidQuantity`) viennent toujours de `_currentAllOrders` (données backend) via `getAllItemsOrganized()`. Ne jamais utiliser `mainNote.items` ou `subNotes` directement pour les calculs de paiement.

🆕 **Paiements divisés** : Les paiements divisés utilisent `splitPaymentId` (format: `split_TIMESTAMP`) pour regrouper tous les modes de paiement d'une même transaction. Le regroupement se fait dans les rapports KPI via `splitPaymentId` (sans le mode de paiement dans l'ID).

🆕 **Pourboires** : Les pourboires sont calculés via `excessAmount = enteredAmount - allocatedAmount` pour les paiements scripturaux (TPE/CHEQUE/CARTE). Le flag `hasCashInPayment` détermine si le pourboire scriptural doit être comptabilisé : si du liquide est présent, le pourboire est purement indicatif et n'est pas inclus dans `totalRecette`. Les pourboires sont affichés séparément par serveur dans le X Report et les KPI.

🆕 **Source de vérité unique pour les paiements** : Le module `server/utils/payment-processor.js` centralise la déduplication et le calcul des paiements pour garantir la cohérence entre History, KPI et X Report. Les fonctions `deduplicateAndCalculate()` et `calculatePaymentsByMode()` sont utilisées par `pos-report-x.js` et `history-processor.js`. **⚠️ En cours d'intégration complète** : `history-processor.js` doit encore être refactorisé pour utiliser ce module.

🆕 **Commandes client (Architecture "Boîte aux Lettres")** : Les commandes passées depuis l'app mobile client sont déposées dans MongoDB par le serveur Cloud avec `waitingForPos: true`, `processedByPos: false`, `id: null`. Le serveur POS local les aspire automatiquement toutes les 5 secondes via `pullFromMailbox()`, leur attribue un ID local, et les marque comme traitées dans MongoDB. Une fois confirmées par le POS (`confirmOrderByServer`), elles sont gérées exactement comme les commandes POS (même structure, même traitement) et **le stock est déduit à la confirmation** (équivalent envoi cuisine). Voir `STRUCTURE_SERVEUR.md` pour les détails backend.

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

Ces éléments garantissent que les blocs "Crédit" du dashboard reflètent uniquement le serveur sélectionné et qu'un ticket peut être consulté pour chaque dette.

---

## 📊 Dashboard Admin

Le dashboard admin (`lib/features/admin/`) fournit une vue d'ensemble des performances et des encaissements du restaurant avec KPI, historique enrichi et rapport X.

**Pour plus de détails** : Voir `STRUCTURE_POS_ADMIN.md` (architecture complète, indicateurs KPI, historique, source de données, tickets).

---

## 📱 Application Client

L'application client (`flutter_client_app/`) est une application Flutter mobile dédiée **uniquement aux clients** pour commander en ligne.

**Fonctionnalités principales** :
- Menu, Panier, Confirmation de commande
- Historique et factures
- Architecture "Boîte aux Lettres" pour les commandes client

**Pour plus de détails** : Voir `STRUCTURE_POS_CLIENT.md` (structure complète, modules, flux, API)

---

## 🍳 Application Cuisine / Dashboard

Interface multi-stations pour gérer les commandes en temps réel : Caisse, Bar, Cuisine, Service, Serveur.

**Disponible via deux canaux** :
- **Dashboard Flutter** : `flutter_les_emirs/lib/features/dashboard/dashboard_page.dart` (onglets multi-stations, routage automatique, badges, mode kiosque)
- **Dashboard Web** : `public/dashboard/` (interface HTML/JS simple)

**Pour plus de détails** : Voir `STRUCTURE_POS_CUISINE.md` (architecture complète, routage, SLA, synchronisation temps réel)

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
- `GET /api/admin/report-x` (Dashboard Admin : KPI, historique, rapport X)

(Détails complets : `STRUCTURE_POS_*` et `STRUCTURE_SERVEUR.md`)

---

## 🔧 Maintenance

1. **Mettre à jour la fiche détaillée concernée** (Home/Order/Payment/Admin) après toute modification.
2. **Mettre à jour ce document** (`STRUCTURE_POS.md`) si l'architecture globale change (nouveau module, changement de structure).
3. **Mentionner la date de mise à jour** et le type de changement dans le fichier concerné.

**Règle** : `STRUCTURE_POS.md` reste un index/overview. Les détails doivent être dans les fichiers dédiés (`STRUCTURE_POS_*.md`).

---

## 🤖 Utilisation avec l’IA (optimisation tokens)

- **Contexte** : Placer ce fichier (ou la fiche détaillée concernée) en premier dans le contexte pour profiter du prompt caching. Puis ajouter uniquement les fichiers à modifier.
- **Session complexe** : Après une grosse session, résumer décisions et état dans un petit fichier (ex. `docs/CONTEXT.md` ou section en bas de la fiche). Pour la session suivante, fournir ce résumé au lieu de tout l’historique.

---

## 📚 Références

- **Home** : `STRUCTURE_POS_HOME.md`
- **Order** : `STRUCTURE_POS_ORDER.md`
- **Payment** : `STRUCTURE_POS_PAYMENT.md`
- **Admin Dashboard** : `STRUCTURE_POS_ADMIN.md`
- **App Client** : `STRUCTURE_POS_CLIENT.md`
- **Dashboard Cuisine** : `STRUCTURE_POS_CUISINE.md`
- **Serveur** : `STRUCTURE_SERVEUR.md`

**Dernière mise à jour** : 2025-01-26 (Stock / inventaire admin, déduction à la vente)

### Changements récents (2025-01-26)

- **Stock / inventaire** : Module Admin inventaire (boissons, groupe drinks) : `admin_inventory_page.dart` dans les deux apps (flutter_les_emirs, flutter_admin_app), routes `admin-inventory.js`, `inventorySync.js`. Déduction du stock **à l'envoi cuisine** dans `orders.js` (`deductStockForSale`), pas au paiement — bonne pratique POS pour éviter les ruptures non visibles. Événement Socket `inventory:updated`. Historique des mouvements (Vente / Ajustement / Réception) consultable depuis la page Stock.

### Changements récents (2025-01-03)

- **Intégration des pourboires** : Calcul et affichage des pourboires par serveur dans X Report et KPI. Gestion du flag `hasCashInPayment` pour exclure les pourboires scripturaux quand du liquide est présent.
- **Single source of truth pour paiements** : Création du module `payment-processor.js` pour centraliser la déduplication et les calculs. Utilisé par `pos-report-x.js` (KPI, X Report) et en cours d'intégration dans `history-processor.js`.
- **Dashboard Admin** : Nouveau module complet avec KPI, historique enrichi et rapport X. Architecture documentée dans la section "Dashboard Admin" ci-dessus.
- **Documentation App Client et Dashboard Cuisine** : Création de `STRUCTURE_POS_CLIENT.md` et `STRUCTURE_POS_CUISINE.md` avec structure complète, modules, flux et API.

