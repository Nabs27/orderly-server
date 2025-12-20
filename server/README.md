# 📁 Structure du serveur

## 🎯 Organisation modulaire

Ce dossier contient le code refactorisé du serveur Node.js avec une structure claire et découpée.

### 📂 routes/ - Les routes API
**Qui fait quoi ?**
- `base.js` - Routes de base (/, /health, QR codes)
- `client.js` - Routes pour l'application client (menu avec traduction)
- `pos.js` - Routes spécifiques au POS (transferts, archives)
- `admin.js` - **Fichier principal** combinant tous les modules admin
- `shared.js` - Routes partagées (orders, bills, crédit)

**🆕 Routes Admin découpées** (structure plate pour facilité de navigation) :
- `admin-auth.js` - Login admin
- `admin-restaurants.js` - CRUD restaurants (GET, POST)
- `admin-menu.js` - CRUD menu complet (GET, PATCH, POST categories/items, DELETE)
- `admin-archive.js` - Consultation archives (GET archived-orders, archived-bills)
- `admin-system.js` - Système & Reset (cleanup, clear-table, full-reset, reset-system, credit/reset)
- `admin-parse.js` - Parse Menu PDF (POST parse-menu)
- `admin-invoice.js` - Génération factures PDF (POST generate-invoice)

### 📂 controllers/ - La logique métier
**Qui fait quoi ?**
- `orders.js` - CRUD des commandes (créer, lire, modifier)
- `bills.js` - CRUD des factures et paiements
- `pos.js` - **Fichier principal** combinant tous les modules POS
- `credit.js` - Système de crédit clients

**🆕 Controllers POS découpés** (structure plate pour facilité de navigation) :
- `pos-transfer.js` - Transferts (transferItems, transferCompleteTable, transferServer)
- `pos-payment.js` - Paiements (deleteNoteItems, payMultiOrders)
- `pos-archive.js` - Archives (getArchivedNotes)

### 📂 utils/ - Fonctions utilitaires
**Qui fait quoi ?**
- `fileManager.js` - Chargement/sauvegarde des données JSON
- `translation.js` - Traductions DeepL avec cache
- `socket.js` - Gestion globale de Socket.IO (getIO/setIO)

### 📂 middleware/ - Middlewares
**Qui fait quoi ?**
- `auth.js` - Authentification admin

### 📄 data.js - Données globales
Singleton contenant toutes les variables globales (orders, bills, etc.)

## 🔍 Comment trouver rapidement un fichier ?

1. **Vous cherchez une route API ?** → Regardez dans `routes/`
   - Routes admin : `routes/admin-*.js` (structure plate)
   - Routes POS : `routes/pos.js`
2. **Vous cherchez la logique métier ?** → Regardez dans `controllers/`
   - Logique POS : `controllers/pos-*.js` (structure plate)
   - Logique commandes : `controllers/orders.js`
3. **Vous cherchez une fonction utilitaire ?** → Regardez dans `utils/`

## 📝 État actuel

- ✅ **Serveur refactorisé** : `server-new.js` avec structure modulaire complète
- ✅ **Routes admin** : Structure découpée en 7 modules spécialisés (19 routes au total)
  - `admin.js` combine tous les modules pour utilisation simplifiée
- ✅ **Controllers POS** : Structure découpée en 3 modules spécialisés (6 fonctions au total)
  - `pos.js` combine tous les modules pour utilisation simplifiée
- ✅ **Socket.IO** : Gestion globale via `utils/socket.js` (getIO) - utilisée partout
- ✅ **Compatibilité** : Double routes (anciennes + /api/) pour POS Flutter
- ✅ **Structure plate** : Fichiers faciles à trouver et maintenir

## 📊 Détails des routes Admin

| Module | Routes | Description |
|--------|--------|-------------|
| `admin-auth.js` | POST `/login` | Authentification admin |
| `admin-restaurants.js` | GET/POST `/restaurants` | Liste et création restaurants |
| `admin-menu.js` | GET/PATCH `/menu/:id` + CRUD catégories/items | Gestion complète des menus |
| `admin-archive.js` | GET `/archived-orders`, `/archived-bills` | Consultation archives |
| `admin-system.js` | POST `/cleanup-duplicate-notes`, `/clear-table-consumption`, `/full-reset`, `/reset-system`, `/credit/reset` | Opérations système |
| `admin-parse.js` | POST `/parse-menu` | Parsing PDF → JSON |
| `admin-invoice.js` | POST `/generate-invoice` | Génération factures PDF |

**Total : 19 routes** organisées en modules logiques.

## 📊 Détails des controllers POS

| Module | Fonctions | Description |
|--------|-----------|-------------|
| `pos-transfer.js` | `transferItems`, `transferCompleteTable`, `transferServer` | Tous les transferts |
| `pos-payment.js` | `deleteNoteItems`, `payMultiOrders` | Tous les paiements |
| `pos-archive.js` | `getArchivedNotes` | Consultation archives |

**Total : 6 fonctions** organisées par domaine fonctionnel.
