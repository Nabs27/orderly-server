# 📊 Module POS – Admin Dashboard

## 📍 Objectif
Décrire la structure du module « Admin Dashboard » : KPI, historique enrichi, rapport X. Ce fichier complète `STRUCTURE_POS.md`.

---

## 📂 Fichiers clés

| Type | Fichier | Rôle |
|------|---------|------|
| Page principale | `lib/features/admin/admin_dashboard_page.dart` | Dashboard principal avec navigation et sections KPI/Historique |
| Section KPI | `lib/features/admin/widgets/admin_dashboard_kpi_section.dart` | Affiche les indicateurs clés (CA, Recette, Remises, Crédits) |
| Section Historique | `lib/features/admin/widgets/enriched_history_section.dart` | Affiche l'historique enrichi des paiements |
| Rapport X | `lib/features/admin/report_x_page.dart` | Génération et affichage du rapport financier X |
| Dialog Historique | `lib/features/admin/widgets/paid_history_dialog.dart` | Dialog détaillé des encaissements par table |
| Service KPI | `lib/features/admin/services/kpi_service.dart` | Récupération des données KPI depuis `/api/admin/report-x` |
| Modèle KPI | `lib/features/admin/models/kpi_model.dart` | Structure des données KPI |
| Backend Rapport X | `server/controllers/pos-report-x.js` | Génération des données (KPI, historique, rapport X) |
| Processeur paiements | `server/utils/payment-processor.js` | **SOURCE DE VÉRITÉ UNIQUE** pour déduplication et calculs |
| Processeur historique | `server/utils/history-processor.js` | Traitement de l'historique des paiements |

---

## 🎯 Responsabilités

- Afficher les **KPI du jour** (CA, Recette encaissée, Remises, Crédits)
- Afficher l'**historique enrichi** des paiements par table et service
- Générer et afficher le **Rapport X** (rapport financier détaillé)
- Garantir la **cohérence des données** entre History, KPI et X Report via `payment-processor.js`

---

## 🧩 Architecture

### Frontend (Flutter)

```
lib/features/admin/
├── admin_dashboard_page.dart          # Page principale
├── report_x_page.dart                 # Page Rapport X
├── models/
│   └── kpi_model.dart                 # Modèle de données KPI
├── services/
│   └── kpi_service.dart               # Service API pour KPI
└── widgets/
    ├── admin_dashboard_kpi_section.dart    # Section KPI
    ├── enriched_history_section.dart        # Section historique
    ├── paid_history_dialog.dart            # Dialog historique détaillé
    ├── paid_ticket_dialog.dart             # Dialog ticket individuel
    ├── ca_details_dialog.dart              # Dialog détails CA
    ├── credit_details_dialog.dart          # Dialog détails crédits
    ├── discount_details_dialog.dart        # Dialog détails remises
    └── unpaid_tables_dialog.dart           # Dialog tables non payées
```

### Backend (Node.js)

```
server/
├── controllers/
│   └── pos-report-x.js                # Génération rapport X et données KPI
└── utils/
    ├── payment-processor.js           # **SOURCE DE VÉRITÉ UNIQUE** pour déduplication
    └── history-processor.js            # Traitement historique (en cours de refactoring)
```

---

## 📊 Indicateurs KPI

Les KPI sont calculés depuis le rapport X (`pos-report-x.js`) et incluent :

| KPI | Description | Calcul |
|-----|-------------|--------|
| **CA du jour** | Chiffre d'affaires brut | Somme des `allocatedAmount` (valeur des tickets, sans pourboires) |
| **Recette encaissée** | Montants réellement encaissés | Somme des `enteredAmount` (avec pourboires pour paiements scripturaux, sans pourboire si `hasCashInPayment === true`) |
| **Recette non encaissée** | Tables actives avec montants en attente | Calcul depuis les commandes actives |
| **Crédit client** | Dettes clients en cours | Solde total des crédits clients |
| **Taux de remise** | Total des remises et pourcentage | Somme des `discountAmount` et calcul du pourcentage |

### Pourboires

Les pourboires sont calculés via `excessAmount = enteredAmount - allocatedAmount` pour les paiements scripturaux (TPE/CHEQUE/CARTE). Le flag `hasCashInPayment` détermine si le pourboire scriptural doit être comptabilisé :
- Si `hasCashInPayment === true` : le pourboire est purement indicatif et n'est **pas inclus** dans `totalRecette`
- Si `hasCashInPayment === false` : le pourboire est **inclus** dans `totalRecette` et affiché séparément par serveur

---

## 📜 Historique enrichi

L'historique utilise `history-processor.js` pour :

1. **Regrouper les paiements** par table et service (gap de 30 minutes = nouveau service)
2. **Dédupliquer les transactions** de paiements divisés multi-commandes
3. **Calculer les totaux** depuis les articles dédupliqués (pas depuis les montants proportionnels)
4. **Afficher les tickets** avec les bonnes valeurs (subtotal, remise, total)

### Tickets dans l'historique

Pour les **paiements divisés**, les tickets sont créés dynamiquement côté Flutter en utilisant les valeurs calculées par le backend :
- `subtotal` : Calculé depuis les articles dédupliqués (pas depuis `allocatedAmount`)
- `discountAmount` : Remise totale du ticket
- `amount` : Montant du ticket après remise (`subtotal - discountAmount`)
- `items` : Articles dédupliqués du ticket global

**Important** : Le backend (`pos-report-x.js`) calcule déjà correctement ces valeurs depuis les articles dédupliqués. Le Flutter doit utiliser ces valeurs directement, pas les recalculer.

---

## 🔄 Source de données

### Backend

- **Endpoint** : `GET /api/admin/report-x`
- **Contrôleur** : `server/controllers/pos-report-x.js` → `buildReportData()`
- **Déduplication** : `server/utils/payment-processor.js` garantit la cohérence (History = KPI = X Report)
- **Historique** : `server/utils/history-processor.js` traite les sessions archivées

### Flux de données

```
Archived Orders / Active Orders
    ↓
pos-report-x.js (buildReportData)
    ↓
payment-processor.js (deduplicateAndCalculate, calculatePaymentsByMode)
    ↓
KPI Model (Flutter)
    ↓
admin_dashboard_kpi_section.dart
```

---

## 🆕 Single Source of Truth

Le module `server/utils/payment-processor.js` est la **source de vérité unique** pour la déduplication des paiements :

- ✅ `pos-report-x.js` (X Report, KPI) utilise `paymentProcessor.calculatePaymentsByMode()` et `paymentProcessor.deduplicateAndCalculate()`
- ✅ `history-processor.js` (Historique) utilise les mêmes principes de déduplication
- ⚠️ **En cours d'intégration complète** : `history-processor.js` doit encore être refactorisé pour utiliser ce module

**Clé de déduplication** : `splitPaymentId + mode + enteredAmount` pour identifier les transactions uniques.

**Problème résolu** : Pour N commandes, chaque transaction apparaît N fois dans `paymentHistory`. Le module commun déduplique correctement.

---

## 🧱 Widgets principaux

### AdminDashboardPage

Page principale du dashboard avec :
- Navigation entre sections (KPI, Historique, Rapport X)
- Filtres par période (jour, midi, soir)
- Filtres par serveur

### AdminDashboardKpiSection

Affiche 5 cartes KPI :
- CA du jour
- Recette encaissée (clic → `PaidHistoryDialog`)
- Recette non encaissée (clic → `UnpaidTablesDialog`)
- Crédit client (clic → `CreditDetailsDialog`)
- Taux de remise (clic → `DiscountDetailsDialog`)

### EnrichedHistorySection

Affiche l'historique enrichi avec :
- Regroupement par table
- Regroupement par service (gap de 30 minutes)
- Affichage des tickets principaux et tickets de paiement
- Support des paiements divisés avec tickets dynamiques

### PaidHistoryDialog

Dialog détaillé des encaissements par table :
- Liste des tables avec totaux
- Détail par service avec ticket principal
- Tickets individuels par paiement
- Support des paiements divisés avec création dynamique de tickets

### ReportXPage

Page de génération et affichage du Rapport X :
- Filtres par période et serveur
- Affichage détaillé des paiements par mode
- Affichage des pourboires par serveur
- Export/impression

---

## 🔍 Points d'attention

### Paiements divisés multi-commandes

⚠️ **CRITIQUE** : Une table peut avoir plusieurs commandes (orders) distinctes. Pour les paiements divisés :
- Chaque commande enregistre son propre `paymentRecord` avec le même `splitPaymentId`
- Le backend doit dédupliquer lors du calcul des totaux
- Le frontend doit utiliser les valeurs calculées par le backend (subtotal depuis articles, pas depuis `allocatedAmount`)

### Calcul des totaux

- **Subtotal** : Toujours calculé depuis les articles dédupliqués, jamais depuis les montants proportionnels
- **Remise** : Pour les split payments, prendre la remise du premier paiement (tous ont la même remise)
- **Total ticket** : `subtotal - discountAmount` (pas le montant encaissé)

### Pourboires

- **Calcul** : `excessAmount = enteredAmount - allocatedAmount` (pour paiements scripturaux uniquement)
- **Affichage** : Séparément par serveur en bas du X Report
- **Comptabilisation** : Inclus dans `totalRecette` seulement si `hasCashInPayment === false`

---

## 📡 Endpoints REST

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/api/admin/report-x` | GET | Génère les données KPI, historique et rapport X |

**Paramètres** :
- `dateFrom` : Date de début (ISO 8601)
- `dateTo` : Date de fin (ISO 8601)
- `period` : 'ALL', 'MIDI', ou 'SOIR'
- `server` : Nom du serveur (optionnel)

---

## 🔧 Maintenance

1. **Mettre à jour ce fichier** après toute modification du Dashboard Admin
2. **Vérifier la cohérence** entre `payment-processor.js`, `pos-report-x.js` et `history-processor.js`
3. **Tester les calculs** : Vérifier que History = KPI = X Report après chaque modification
4. **Documenter les changements** dans la section "Changements récents" de `STRUCTURE_POS.md`

---

## 📚 Références

- **Vue d'ensemble** : `STRUCTURE_POS.md` (section Dashboard Admin)
- **Paiements** : `STRUCTURE_POS_PAYMENT.md` (pourboires, split payments)
- **Backend** : `STRUCTURE_SERVEUR.md` (API, endpoints)

**Dernière mise à jour** : 2025-01-03 (Création du fichier, intégration pourboires, single source of truth)

