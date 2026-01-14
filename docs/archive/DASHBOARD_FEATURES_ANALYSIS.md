# 📊 Analyse Complète des Fonctionnalités Dashboard

## 🎯 Vue d'ensemble

Le Dashboard Admin offre de nombreuses fonctionnalités qui interagissent avec le POS. Voici l'analyse complète de ce qui doit être synchronisé.

---

## ✅ Fonctionnalités Dashboard

### 1. **Gestion des Menus** (`admin-menu.js`)
**Routes :**
- `GET /api/admin/menu/:restaurantId` - Lire un menu
- `PATCH /api/admin/menu/:restaurantId` - Modifier un menu complet
- `POST /api/admin/menu/:restaurantId/categories` - Ajouter une catégorie
- `DELETE /api/admin/menu/:restaurantId/categories/:categoryName` - Supprimer une catégorie
- `POST /api/admin/menu/:restaurantId/items` - Ajouter un article
- `PATCH /api/admin/menu/:restaurantId/items/:itemId` - Modifier un article (nom, prix, disponibilité, masquer)
- `DELETE /api/admin/menu/:restaurantId/items/:itemId` - Supprimer un article

**Stockage actuel :** `data/restaurants/:restaurantId/menu.json`

**⚠️ Problème :** Les modifications depuis Railway ne sont pas synchronisées vers le local.

---

### 2. **Gestion des Profils Serveurs** (`admin-servers.js`)
**Routes :**
- `GET /api/admin/servers-profiles` - Liste des profils
- `GET /api/admin/servers-profiles/:id` - Détails d'un profil
- `POST /api/admin/servers-profiles` - Créer un profil
- `PATCH /api/admin/servers-profiles/:id` - Modifier un profil (nom, PIN, rôle, permissions)
- `DELETE /api/admin/servers-profiles/:id` - Supprimer un profil

**Stockage actuel :** `data/pos/server_permissions.json`

**⚠️ Problème :** Les modifications depuis Railway ne sont pas synchronisées vers le local.

---

### 3. **Gestion des Restaurants** (`admin-restaurants.js`)
**Routes :**
- `GET /api/admin/restaurants` - Liste des restaurants
- `POST /api/admin/restaurants` - Créer un restaurant (crée un menu.json vide)

**Stockage actuel :** `data/restaurants/:id/menu.json`

**⚠️ Problème :** Création de restaurant depuis Railway non synchronisée.

---

### 4. **Archives** (`admin-archive.js`)
**Routes :**
- `GET /api/admin/archived-orders` - Liste des commandes archivées
- `GET /api/admin/archived-bills` - Liste des factures archivées

**Stockage actuel :** `data/pos/archived_orders.json`, `data/pos/archived_bills.json`

**✅ Déjà synchronisé :** Via `savePersistedData()` lors des archivages.

---

### 5. **Système & Maintenance** (`admin-system.js`)
**Routes :**
- `POST /api/admin/cleanup-duplicate-notes` - Nettoyer les doublons de sous-notes
- `POST /api/admin/clear-table-consumption` - Archiver la consommation d'une table
- `POST /api/admin/full-reset` - Reset complet (supprime fichiers)
- `POST /api/admin/reset-system` - Reset système (vide les données)
- `POST /api/admin/credit/reset` - Reset crédits clients

**Stockage actuel :** Modifie directement les données en mémoire puis appelle `savePersistedData()`

**✅ Déjà synchronisé :** Via `savePersistedData()`.

---

### 6. **Simulation de Données** (`admin-simulation.js`)
**Routes :**
- `POST /api/admin/simulate-data` - Générer des données de test (commandes, factures, crédits)

**Stockage actuel :** Modifie directement les données puis appelle `savePersistedData()`

**✅ Déjà synchronisé :** Via `savePersistedData()`.

---

### 7. **Parse Menu (PDF → JSON)** (`admin-parse.js`)
**Routes :**
- `POST /api/admin/parse-menu` - Parser un menu PDF via IA (DeepSeek)

**Stockage actuel :** Retourne le menu parsé, mais ne le sauvegarde pas automatiquement (l'admin doit ensuite utiliser PATCH /menu pour sauvegarder)

**⚠️ Problème :** Si le menu est sauvegardé depuis Railway, pas de synchronisation.

---

### 8. **Génération Factures PDF** (`admin-invoice.js`)
**Routes :**
- `POST /api/admin/generate-invoice` - Générer une facture PDF

**Stockage actuel :** Crée un fichier PDF dans `public/invoices/`

**✅ Pas de synchronisation nécessaire :** Les PDFs sont servis statiquement.

---

### 9. **Rapports Financiers** (`admin-report-x.js`)
**Routes :**
- `GET /api/admin/report-x` - Rapport X (JSON)
- `GET /api/admin/report-x-ticket` - Rapport X (ticket texte)
- `GET /api/admin/credit-report` - État crédits (JSON)
- `GET /api/admin/credit-report-ticket` - État crédits (ticket texte)

**Stockage actuel :** Lit depuis les données en mémoire (orders, bills, clientCredits)

**✅ Pas de synchronisation nécessaire :** Lecture uniquement, données déjà synchronisées.

---

### 10. **Authentification** (`admin-auth.js`)
**Routes :**
- `POST /api/admin/login` - Connexion admin

**✅ Pas de synchronisation nécessaire :** Authentification uniquement.

---

## 📋 Résumé : Ce qui DOIT être synchronisé

### ❌ **NON synchronisé actuellement :**

1. **Menus** (`data/restaurants/:id/menu.json`)
   - Modifications depuis Railway → Local : ❌
   - Modifications depuis Local → Railway : ❌ (fichier sur GitHub mais pas de sync automatique)

2. **Permissions Serveurs** (`data/pos/server_permissions.json`)
   - Modifications depuis Railway → Local : ❌
   - Modifications depuis Local → Railway : ❌

3. **Création de Restaurants** (`data/restaurants/:id/`)
   - Création depuis Railway → Local : ❌

---

### ✅ **Déjà synchronisé :**

1. **Commandes** (`orders`) - ✅
2. **Commandes archivées** (`archivedOrders`) - ✅
3. **Factures** (`bills`) - ✅
4. **Factures archivées** (`archivedBills`) - ✅
5. **Services** (`services`) - ✅
6. **Clients crédit** (`clientCredits`) - ✅
7. **Compteurs** (`counters`) - ✅

---

## 🎯 Solution Proposée

### Option 1 : Synchronisation MongoDB complète (RECOMMANDÉE)

**Collections MongoDB à ajouter :**
- `menus` - Stocker les menus par restaurant
- `server_permissions` - Stocker les profils serveurs

**Avantages :**
- ✅ Dashboard et POS voient toujours les mêmes données
- ✅ Modifications depuis Railway → visibles immédiatement sur POS
- ✅ Modifications depuis POS → visibles immédiatement sur Railway
- ✅ Synchronisation bidirectionnelle automatique

**Implémentation :**
1. Modifier `admin-menu.js` pour sauvegarder dans MongoDB + fichier local
2. Modifier `admin-servers.js` pour sauvegarder dans MongoDB + fichier local
3. Modifier `fileManager.js` pour synchroniser menus et permissions
4. Modifier `data.js` pour charger menus depuis MongoDB si disponible

---

### Option 2 : Synchronisation unidirectionnelle (Local → Cloud)

**Comportement :**
- Local = source de vérité
- Railway lit depuis MongoDB (backup du local)
- Modifications depuis Railway non synchronisées vers local

**Inconvénients :**
- ❌ Modifications depuis Railway non visibles sur POS
- ❌ Pas de synchronisation bidirectionnelle

---

## 🚀 Recommandation Finale

**Option 1 : Synchronisation MongoDB complète**

Cela permettra :
- ✅ Édition de menu depuis Railway → visible sur POS
- ✅ Création/modification profils serveurs depuis Railway → visible sur POS
- ✅ Tout fonctionne de manière bidirectionnelle
- ✅ Dashboard et POS toujours synchronisés

**Fichiers à modifier :**
1. `server/utils/fileManager.js` - Ajouter sync menus + permissions
2. `server/routes/admin-menu.js` - Sauvegarder dans MongoDB
3. `server/routes/admin-servers.js` - Sauvegarder dans MongoDB
4. `server/data.js` - Charger menus depuis MongoDB si disponible
5. `server/utils/dbManager.js` - Ajouter collection `menus`

---

## 📝 Prochaines Étapes

1. ✅ Analyser les fonctionnalités Dashboard (FAIT)
2. ⏳ Implémenter la synchronisation MongoDB pour menus
3. ⏳ Implémenter la synchronisation MongoDB pour permissions serveurs
4. ⏳ Tester la synchronisation bidirectionnelle
5. ⏳ Documenter les changements

