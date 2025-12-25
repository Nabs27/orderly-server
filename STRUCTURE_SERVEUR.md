# 📋 Structure du serveur (état actuel)

Le dossier `server/` est désormais découpé en sous-modules thématiques (`routes/`, `controllers/`, `utils/`, `middleware/`). Cette fiche sert de guide rapide pour localiser les différents blocs backend utilisés par le POS et l’admin.

---

## 📂 Arborescence principale

```
server/
├── controllers/        ← logique métier POS/Admin/Credit
├── routes/             ← routes Express regroupées par domaine
├── utils/              ← utilitaires transverses (socket, fichiers, db, traduction)
├── middleware/         ← ex. auth
├── data.js             ← bootstrap/configuration des services
└── README.md
```

> L’ancien monolithe `server.js` n’est plus utilisé : le point d’entrée est `server-new.js` (script `npm run dev`/`start`), lequel initialise `dbManager` puis importe les routes.

### 💾 Architecture "Boîte aux Lettres" (Mailbox) - Local vs Cloud

Le serveur utilise une architecture hybride avec **source de vérité unique** gérée par `server/utils/dbManager.js` et `server/utils/fileManager.js` :

1. **Mode Local (🏠 Restaurant - Source de vérité)** : 
   - Utilise les fichiers **JSON** dans `data/pos/` comme source de vérité unique.
   - **MongoDB** utilisé uniquement pour :
     - Recevoir les commandes client (boîte aux lettres)
     - Backup des archives et factures
   - **Polling périodique** : Vérifie MongoDB toutes les 5 secondes via `pullFromMailbox()` pour aspirer les nouvelles commandes client.
   - Avantage : Fonctionne sans internet, rapidité maximale pour le service.
   - Activé si `IS_CLOUD_SERVER` n'est pas défini ou vaut `false`.

2. **Mode Cloud (☁️ Railway - Stateless)** :
   - **Stateless** : Ne sauvegarde PAS de fichiers JSON locaux (effacés à chaque redémarrage).
   - **Rôle de "Réceptionniste"** : Reçoit les commandes client et les dépose dans MongoDB avec :
     - `waitingForPos: true`
     - `processedByPos: false`
     - `id: null` (le POS local attribuera l'ID)
   - **Ne traite JAMAIS les commandes** : Se contente de les insérer dans MongoDB.
   - Activé si `IS_CLOUD_SERVER=true` est défini dans les variables d'environnement.

**Flux des commandes client** :
1. Client mobile → POST `/orders` → Serveur Cloud (Railway)
2. Cloud → Insert MongoDB avec `waitingForPos: true`
3. Serveur Local (toutes les 5s) → `pullFromMailbox()` → Aspire la commande
4. Local → Attribue un ID local → Marque `processedByPos: true` dans MongoDB
5. Local → Sauvegarde dans JSON (source de vérité)

---

## 🚦 Routes

| Domaine | Fichiers | Description |
|---------|----------|-------------|
| POS / Clients | `routes/pos.js`, `routes/client.js`, `routes/shared.js`, `routes/base.js` | Commandes en cours, synchronisation tables, API publiques pour les clients. |
| Admin général | `routes/admin.js` (agrégateur) | Monte l’ensemble des routes admin. |
| Admin spécialisés | `routes/admin-menu.js`, `admin-report-x.js`, `admin-archive.js`, `admin-restaurants.js`, `admin-system.js`, `admin-simulation.js`, `admin-invoice.js`, `admin-auth.js`, `admin-parse.js`, `admin-servers.js` | Fonctions backoffice : menus, rapports X/Z, archives, imports, authentification, gestion des profils serveurs, etc. |

Chaque route importe les contrôleurs correspondants et applique `middleware/auth.js` lorsque nécessaire (ex : routes admin).

---

## 🧠 Controllers

| Fichier | Rôle |
|---------|------|
| `controllers/orders.js` | CRUD commandes / tables (POS). **🆕 Architecture "Boîte aux Lettres"** : Si commande client (`source: 'client'`), le serveur Cloud insère dans MongoDB avec `waitingForPos: true`, `processedByPos: false`, `id: null`. Le serveur Local aspire ces commandes via `pullFromMailbox()`. |
| `controllers/pos.js` | Coordonne les opérations POS (utilisé par `routes/pos.js`). |
| `controllers/pos-payment.js` | Traitement des paiements, ventilation des articles, envoi d’événements. |
| `controllers/pos-transfer.js` | Transferts d’articles, tables, serveurs. |
| `controllers/pos-cancellation.js` | Annulation d’articles, remboursements. |
| `controllers/pos-archive.js` | Archivage et nettoyage des commandes. |
| `controllers/pos-report-x.js` | Génération des rapports financiers X / ticket texte. |
| `controllers/bills.js` | Génération de factures PDF. |
| `controllers/credit.js` | Gestion du crédit client (DEBIT/CREDIT, balances). |
| `controllers/admin.js` | Fonctions administrateur génériques (indicateurs, reset, etc.). |
| `controllers/admin-servers.js` | CRUD profils serveurs + exposition des permissions pour le POS. |

### Profils & permissions serveurs

- **Admin** : `routes/admin-servers.js` expose `/api/admin/servers-profiles` (GET/POST/PATCH/DELETE) protégés par `authAdmin`.
- **POS / publiques** : `routes/shared.js` expose `/api/server-profiles` (liste sans PIN) et `/api/server-permissions/:name` (droits appliqués dans `PosOrderPage`).
| `controllers/admin-servers.js` | CRUD profils serveurs + exposition des permissions pour le POS. |

Ces contrôleurs utilisent les utilitaires (`utils`) pour accéder aux fichiers, traductions, sockets, etc.

---

## 🧰 Utils & middleware

| Fichier | Description |
|---------|-------------|
| `utils/socket.js` | Instancie Socket.IO, émet les événements (`order:*`, `table:*`, `credit:*`). |
| `utils/translation.js` | Intègre DeepL / normalise les textes de menu. |
| `utils/fileManager.js` | Lecture/écriture de fichiers (exports, sauvegardes). **🆕 Fonctions clés** : `pullFromMailbox()` (aspire les commandes client depuis MongoDB), `smartSyncWithMongoDB()` (synchronisation intelligente au démarrage), `saveToMongoDB()` (backup uniquement des commandes en attente et archives). |
| `utils/dbManager.js` | Gestion MongoDB Atlas. **🆕 Détection mode** : `isCloud = process.env.IS_CLOUD_SERVER === 'true'` pour différencier serveur Cloud (stateless) vs Local (source de vérité). |
| `middleware/auth.js` | Vérifie le token admin (`x-admin-token`). |

---

## 🔄 Flux type

### Exemple : Paiement POS

1. Requête `POST /orders/:id/payment` → définie dans `routes/pos.js`.
2. La route appelle `controllers/pos-payment.js`.
3. Le contrôleur :
   - charge les commandes/notes depuis la source de données,
   - ventile les articles payés,
   - met à jour les archives/états,
   - émet les événements Socket.IO,
   - renvoie la réponse JSON.

### Exemple : Commande client (Architecture "Boîte aux Lettres")

1. **Client mobile** → `POST /orders` → **Serveur Cloud (Railway)**
2. **Cloud** (`controllers/orders.js`) :
   - Détecte `source: 'client'` → Insère dans MongoDB avec `waitingForPos: true`, `processedByPos: false`, `id: null`
   - Log : `📬 Commande client reçue. Déposée dans la boîte aux lettres`
3. **Serveur Local** (polling toutes les 5s via `server-new.js`) :
   - Appelle `fileManager.pullFromMailbox()`
   - Scan MongoDB pour `waitingForPos: true` et `processedByPos: false`
   - Pour chaque commande trouvée :
     - Vérifie anti-doublon (par `tempId`)
     - Attribue un ID local (`dataStore.nextOrderId++`)
     - Ajoute à `dataStore.orders` (JSON local)
     - Met à jour MongoDB : `waitingForPos: false`, `processedByPos: true`, `id: <localId>`
   - Log : `✍️ Attribution ID #X à temp_xxx. Enregistré localement.`
4. **Confirmation** (`POST /orders/:id/confirm`) :
   - Supprime la commande de MongoDB (confirmée = gérée uniquement en local)
   - Sauvegarde dans JSON local uniquement

Même pattern pour les rapports X (`routes/admin-report-x.js` → `controllers/pos-report-x.js`) ou le crédit (`routes/pos.js` / `routes/admin.js` → `controllers/credit.js`).

---

## 🧼 Maintenance & conventions

- **Nouvelle route** : créer un fichier dans `routes/` si le domaine est important, sinon enrichir le module existant. Toujours appliquer `middleware/auth.js` pour les endpoints sensibles.
- **Nouvelle logique métier** : ajouter un contrôleur dédié ou compléter celui du domaine concerné.
- **Socket.IO** : centraliser les nouveaux événements dans `utils/socket.js` pour assurer une diffusion homogène côté clients.
- **Documentation** : mettre à jour cette fiche à chaque ajout/suppression significative de route ou de contrôleur afin de garder la cartographie à jour.

**Dernière mise à jour** : 2025-01-24 (Architecture "Boîte aux Lettres", polling 5s, différenciation Cloud/Local via IS_CLOUD_SERVER)

