# 📱 Application Client - Les Emirs

Application Flutter mobile dédiée **uniquement aux clients** pour commander en ligne depuis leur téléphone.

---

## 📍 Objectif

Permettre aux clients de :
- Parcourir le menu du restaurant
- Ajouter des articles au panier
- Passer une commande en ligne
- Suivre l'état de leur commande
- Consulter leur historique et leurs factures

---

## 📂 Structure du Projet

```
flutter_client_app/
├── lib/
│   ├── core/                    # Services de base
│   │   ├── api_client.dart      # Client HTTP (Dio) pour l'API
│   │   ├── cart_service.dart     # Gestion du panier (SharedPreferences)
│   │   ├── lang_service.dart     # Gestion des traductions
│   │   └── strings.dart          # Chaînes de caractères traduites
│   ├── features/                 # Modules fonctionnels
│   │   ├── welcome/              # Page d'accueil (sélection langue)
│   │   │   └── welcome_page.dart
│   │   ├── menu/                 # Page menu
│   │   │   ├── menu_page.dart
│   │   │   └── options.dart      # Options des articles
│   │   ├── cart/                 # Page panier
│   │   │   └── cart_page.dart
│   │   ├── confirm/               # Page confirmation de commande
│   │   │   └── confirm_page.dart
│   │   ├── history/              # Page historique
│   │   │   └── history_page.dart
│   │   ├── bill/                 # Page facture
│   │   │   └── bill_page.dart
│   │   └── payment/              # Page paiement (si nécessaire)
│   │       └── pay_confirm_page.dart
│   └── main.dart                 # Point d'entrée de l'application
├── pubspec.yaml                  # Dépendances Flutter
└── README.md                     # Guide d'installation
```

---

## 🎯 Modules Principaux

### 1. Welcome (`welcome_page.dart`)

**Rôle** : Page d'accueil avec sélection de la langue.

**Fonctionnalités** :
- Sélection de la langue (français, anglais, arabe)
- Initialisation de `LangService`
- Navigation vers `/menu`

---

### 2. Menu (`menu_page.dart`)

**Rôle** : Afficher le menu du restaurant avec catégories et articles.

**Fonctionnalités** :
- Chargement du menu depuis l'API (`GET /menu/les-emirs?lng=fr`)
- Affichage par catégories
- Sélection d'articles avec options (`options.dart`)
- Ajout au panier via `CartService`

**API** : `routes/client.js` → `GET /menu/les-emirs`

---

### 3. Cart (`cart_page.dart`)

**Rôle** : Gérer le panier de commande.

**Fonctionnalités** :
- Affichage des articles ajoutés
- Modification des quantités
- Suppression d'articles
- Calcul du total
- Navigation vers confirmation

**Stockage** : `CartService` (SharedPreferences)

---

### 4. Confirm (`confirm_page.dart`)

**Rôle** : Valider et envoyer la commande.

**Fonctionnalités** :
- Affichage du récapitulatif
- Saisie du numéro de table
- Envoi de la commande via `POST /orders` avec `source: 'client'`
- Suivi de l'état de la commande (en attente, confirmée, refusée)
- Génération d'un `tempId` si pas encore d'ID officiel

**Flux** :
1. Client → `POST /orders` → **Serveur Cloud (Railway)**
2. Cloud → Insert MongoDB avec `waitingForPos: true`, `processedByPos: false`, `id: null`
3. Serveur Local (polling 5s) → `pullFromMailbox()` → Aspire la commande
4. Local → Attribue un ID local → Marque `processedByPos: true` dans MongoDB

**Pour plus de détails** : Voir `STRUCTURE_SERVEUR.md` → Section "Architecture Boîte aux Lettres"

---

### 5. History (`history_page.dart`)

**Rôle** : Afficher l'historique des commandes par table.

**Fonctionnalités** :
- Saisie du numéro de table
- Chargement de l'historique depuis l'API
- Affichage des commandes passées
- Navigation vers les factures

**API** : `GET /orders?table=X&archived=true`

---

### 6. Bill (`bill_page.dart`)

**Rôle** : Consulter une facture.

**Fonctionnalités** :
- Affichage de la facture PDF ou HTML
- Téléchargement de la facture

**API** : `GET /bills/:id` ou `GET /bills/:id/pdf`

---

## 🔧 Services Core

### `api_client.dart`

**Rôle** : Client HTTP centralisé utilisant Dio.

**Configuration** :
- URL de base depuis `.env` (`API_BASE_URL`)
- Gestion des erreurs
- Headers par défaut

**Utilisation** :
```dart
final response = await ApiClient.dio.get('/menu/les-emirs', queryParameters: {'lng': 'fr'});
```

---

### `cart_service.dart`

**Rôle** : Gestion du panier via SharedPreferences.

**Fonctionnalités** :
- Sauvegarde/chargement du panier
- Ajout/suppression d'articles
- Calcul du total
- Persistance entre les sessions

**Méthodes clés** :
- `addItem(item)` : Ajouter un article
- `removeItem(itemId)` : Supprimer un article
- `updateQuantity(itemId, quantity)` : Modifier la quantité
- `clear()` : Vider le panier
- `getTotal()` : Calculer le total

---

### `lang_service.dart`

**Rôle** : Gestion des traductions multi-langues.

**Fonctionnalités** :
- Chargement des traductions depuis l'API ou fichiers locaux
- Changement de langue
- Traduction des chaînes via `strings.dart`

---

## 🔄 Flux de Navigation

```
WelcomePage (sélection langue)
    ↓
MenuPage (parcourir menu)
    ↓
CartPage (gérer panier)
    ↓
ConfirmPage (valider commande)
    ↓
HistoryPage (voir historique)
    ↓
BillPage (consulter facture)
```

---

## 🌐 Architecture "Boîte aux Lettres"

Les commandes client suivent un flux spécifique :

1. **Client mobile** → `POST /orders` avec `source: 'client'` → **Serveur Cloud (Railway)**
2. **Serveur Cloud** (`controllers/orders.js`) :
   - Détecte `source: 'client'`
   - Insère dans MongoDB avec :
     - `waitingForPos: true`
     - `processedByPos: false`
     - `id: null` (le POS local attribuera l'ID)
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

**Pour plus de détails** : Voir `STRUCTURE_SERVEUR.md` → Section "Architecture Boîte aux Lettres"

---

## 📡 Endpoints API Utilisés

| Endpoint | Méthode | Rôle |
|----------|---------|------|
| `/menu/les-emirs` | GET | Récupérer le menu avec traductions |
| `/orders` | POST | Créer une commande client |
| `/orders?table=X&archived=true` | GET | Récupérer l'historique d'une table |
| `/orders/:id/confirm` | POST | Confirmer une commande (POS) |
| `/orders/:id/decline` | POST | Refuser une commande (POS) |
| `/bills/:id` | GET | Récupérer une facture |
| `/bills/:id/pdf` | GET | Télécharger la facture PDF |

**Routes backend** : `routes/client.js`, `routes/shared.js`

---

## 🚀 Installation & Déploiement

### Configuration

1. **Créer le fichier `.env`** :
   ```env
   API_BASE_URL=http://localhost:3000
   # Ou pour le serveur cloud :
   # API_BASE_URL=https://orderly-server-production.up.railway.app
   ```

2. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```

### Construire l'APK Android

```bash
flutter build apk --release
```

L'APK sera créé dans :
```
build/app/outputs/flutter-apk/app-release.apk
```

### Installer sur le téléphone

1. Transférez l'APK sur votre téléphone Android
2. Activez "Sources inconnues" dans les paramètres
3. Installez l'APK

---

## ⚠️ Points d'Attention

- **Application dédiée** : Cette app est **uniquement pour les clients**. Elle ne contient **pas** le POS ni l'Admin.
- **Légèreté** : L'application est plus légère et plus simple que l'app complète (`flutter_les_emirs`).
- **Source de vérité** : Les commandes client sont gérées par le serveur Cloud puis aspirées par le serveur Local (architecture "Boîte aux Lettres").
- **tempId vs ID officiel** : Les commandes client commencent avec un `tempId` (String) généré côté client. Une fois aspirées par le serveur Local, elles reçoivent un ID officiel (int).

---

## 🧼 Maintenance

- Après chaque modification de l'API, vérifier que les endpoints sont toujours accessibles.
- Tester le flux complet : Menu → Panier → Confirmation → Historique → Facture.
- Vérifier la compatibilité avec les différentes versions Android.

**Dernière mise à jour** : 2025-01-03 (Documentation structure complète)

