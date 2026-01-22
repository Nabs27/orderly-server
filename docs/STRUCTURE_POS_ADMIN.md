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

## 💳 Détails des modes de paiement (Rapprochement bancaire)

### Fonctionnalité existante (partielle)

La page "Détails du CA" (`ca_details_page.dart`) affiche déjà une **répartition par mode de paiement** avec :

**Données récupérées** :
- `paymentsByMode` : Totaux et compteurs par mode (CARTE, TPE, CHEQUE, etc.)
- `paidPayments` : Liste complète de tous les paiements du jour
- `splitPaymentDetails` : Détails des paiements divisés

**Affichage actuel** :
- Chaque mode avec son total et nombre de paiements : `CARTE (3) - 150.00 TND`
- **Interface cliquable** : clic ouvre dialogue détaillé avec tous les paiements
- **Affichage simplifié** : plus de boîte grise avec détails individuels

### Utilisation pour rapprochement bancaire

**✅ Ce qui fonctionne déjà** :
- Comptage précis des transactions par mode
- Détails des paiements divisés (ex: 3 paiements CARTE dans un split)
- Noms des clients pour les crédits

**❌ Ce qui manque** :
- Détails des **paiements simples** (non divisés) - la majorité des paiements
- **Dialogue cliquable** sur chaque ligne de mode
- **Informations temporelles** (heure, table) pour chaque paiement

**🎯 Besoin exprimé** :
Permettre un clic sur "CARTE (3)" pour voir un dialogue listant :
- "Table 4 à 21h30 - CARTE 50.00 TND"
- "Table 7 à 22h15 - CARTE 70.00 TND"
- "Table 12 à 23h45 - CARTE 30.00 TND"

**✅ Implémentation réalisée** :
- **Interface simplifiée** : suppression de la boîte grise des détails individuels
- **Correction comptage** : déduplication complète des paiements (simples ET divisés) ✅
- Rendu cliquable de chaque ligne de mode de paiement
- Dialogue modal avec liste détaillée de TOUS les paiements du mode
- Affichage : "Table X à HH:MM - MODE Montant TND"
- Tri par heure décroissante (plus récent en haut)
- Noms de clients pour les paiements CREDIT
- Support des paiements simples et divisés
- **Heure de paiement affichée** pour tous les modes (simples et divisés)

### Architecture technique

**Backend** (`pos-report-x.js`) :
- `buildReportData()` récupère déjà toutes les données nécessaires
- `paidPayments` contient timestamp, table, paymentMode, enteredAmount
- Les données existent, il suffit de les exploiter côté frontend

**Frontend** (`ca_details_page.dart`) :
- `_buildPaymentModeBreakdown()` gère déjà l'affichage
- Logique de récupération des détails divisés existe
- Il faut étendre pour inclure les paiements simples + dialogue

### État d'implémentation

**✅ Complètement implémenté** :
- Récupération des données complètes depuis `paidPayments`
- Affichage des détails pour paiements divisés (existant)
- Comptage et totaux corrects par mode
- **Dialogue cliquable** sur chaque ligne de mode de paiement
- Liste détaillée de **TOUS les paiements** (simples + divisés)
- Affichage avec **heure et table** pour chaque paiement
- Tri chronologique (plus récent en haut)
- Noms de clients pour paiements CREDIT
- Interface responsive pour mobile

**🎯 Résultat** :
Clic sur "CARTE (3)" → Dialogue listant tous les paiements cartes avec heure/table pour rapprochement bancaire ultra-rapide !

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

## 📋 Structure "Tables Encaissées" (KPI)

### Hiérarchie des tickets

```
Table X - Service #N
├── 📊 Ticket Principal (mainTicket)
│   ├── total: TOUS les articles de la table
│   ├── paymentDetails: Agrégation de TOUS les paiements
│   ├── totalAmount: Montant encaissé (exclut CREDIT)
│   ├── excessAmount: Pourboire total
│   └── Crédit client (non encaissé) si présent
│
└── 📄 Tickets de Paiement (payments[])
    ├── Ticket 1: Espèces (134.00 TND)
    │   └── items: Articles payés dans CE paiement
    │
    └── Ticket 2: CARTE + CHEQUE + CREDIT (240.00 TND) [Divisé]
        ├── items: Articles payés dans CE paiement
        └── paymentDetails: [{mode: "CARTE", amount: 90, index: 1}, 
                            {mode: "CHEQUE", amount: 90, index: 1},
                            {mode: "CREDIT", amount: 70, clientName: "Client"}]
```

### ⚠️ Règles critiques

| Règle | Description |
|-------|-------------|
| **mainTicket** | Contient TOUS les articles de la table (résumé global) |
| **ticket (par paiement)** | Contient SEULEMENT les articles de CE paiement spécifique |
| **totalAmount** | Montant encaissé = exclut toujours CREDIT |
| **paymentDetails.index** | Utilisé pour distinguer plusieurs paiements du même mode/montant (CARTE #1, CARTE #2) |
| **creditClientName** | Nom du client pour les paiements CREDIT |

### Modes de paiement supportés

| Mode | Description | Encaissé ? |
|------|-------------|------------|
| `ESPECE` | Espèces/Liquide | ✅ Oui |
| `CARTE` | Carte bancaire | ✅ Oui |
| `CHEQUE` | Chèque | ✅ Oui |
| `TPE` | Terminal de paiement électronique | ✅ Oui |
| `CREDIT` | Crédit client (dette différée) | ❌ Non (affiché séparément) |

### Paiements divisés (Split Payments)

Les paiements divisés (`isSplitPayment === true`) regroupent plusieurs modes en une seule transaction :

- **`splitPaymentId`** : Identifiant unique du groupe (format: `split_TIMESTAMP`)
- **`splitPaymentModes`** : Liste des modes utilisés (ex: `["CARTE", "CHEQUE", "CREDIT"]`)
- **`splitPaymentAmounts`** / **`paymentDetails`** : Détails avec index

**Exemple** :
```json
{
  "paymentDetails": [
    { "mode": "CARTE", "amount": 90, "index": 1 },
    { "mode": "CHEQUE", "amount": 90, "index": 1 },
    { "mode": "CREDIT", "amount": 70, "index": 1, "clientName": "Nabil Gafsi" }
  ]
}
```

### Déduplication des paymentDetails

**Clé de déduplication** (côté frontend) : `${mode}_${amount}_${index}_${clientName}`

**⚠️ NE JAMAIS** utiliser `${mode}_${amount}` seul car plusieurs paiements peuvent avoir le même mode et montant (ex: 2x CARTE 100 TND).

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

## 🚀 Déploiement admin web (Vercel)

- **Commande de build** : `npm run vercel:build`. Elle lance le script `vercel-build.sh` (racine du repo) qui :
  - clone Flutter stable dans `~/flutter` si nécessaire,
  - ajoute `~/flutter/bin` au `PATH`, précache les dépendances et exécute `flutter build web`,
  - produit la sortie dans `build/web`.
- **Réglages Vercel conseillés**
  - Framework preset : `Other` (puisque Flutter n’est pas une option native).
  - Root Directory : `.` ou `./flutter_les_emirs` si vous ne déployez que le sous-projet admin.
  - Build command : `npm run vercel:build`.
  - Output Directory : `build/web`.
- **Variables d’environnement**
  - `API_BASE_URL` doit pointer vers l’API POS (ex. `https://votre-serveur-pos/api`).
  - Reproduisez toute autre clé utilisée par l’admin (auth tokens, flags, etc.) depuis `.env` ou le serveur cloud.
- **Sécurité** : conservez les secrets uniquement dans Vercel (ne les versionnez pas).

## 📚 Références

- **Vue d'ensemble** : `STRUCTURE_POS.md` (section Dashboard Admin)
- **Paiements** : `STRUCTURE_POS_PAYMENT.md` (pourboires, split payments)
- **Backend** : `STRUCTURE_SERVEUR.md` (API, endpoints)

**Dernière mise à jour** : 2025-01-12 (Correction comptage paiements + heures dans dialogue détails + simplification interface)

