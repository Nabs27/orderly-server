# 🍳 Dashboard Cuisine / Stations - Les Emirs

Interface multi-stations pour gérer les commandes en temps réel : Caisse, Bar, Cuisine, Service, Serveur.

---

## 📍 Objectif

Fournir une interface centralisée pour :
- **Caisse** : Voir les commandes en attente de paiement
- **Bar** : Gérer les commandes de boissons (routage automatique)
- **Cuisine** : Gérer les commandes de plats (routage automatique)
- **Service** : Articles prêts à servir
- **Serveur** : File d'attente pour le service

---

## 📂 Structure du Projet

### Dashboard Flutter

```
flutter_les_emirs/lib/features/dashboard/
└── dashboard_page.dart          # Page principale avec onglets multi-stations
```

### Dashboard Web

```
public/dashboard/
├── index.html                    # Interface HTML simple
├── main.js                       # Logique JavaScript (Socket.IO)
└── styles.css                    # Styles CSS
```

---

## 🎯 Dashboard Flutter (`dashboard_page.dart`)

### Architecture

**Onglets** :
- **0 - Caisse** : Commandes en attente de paiement
- **1 - Bar** : Articles de bar (boissons, cocktails)
- **2 - Cuisine** : Articles de cuisine (entrées, plats, desserts)
- **3 - Service** : Articles prêts à servir
- **4 - Serveur** : File d'attente pour le service

### Fonctionnalités

#### 1. Routage Automatique des Articles

**Mapping Menu → Station** :
- Chargement du menu depuis l'API (`GET /menu/les-emirs`)
- Mapping `itemId → station` :
  - `group == 'drinks' || group == 'spirits'` → `'bar'`
  - Sinon → `'kitchen'`
- Mapping `itemId → category` :
  - `'starter'`, `'main'`, `'dessert'`, `'drink'`, `'other'`

**Routage lors de `order:new`** :
```dart
final station = itemIdToStation[id] ?? 'kitchen';
if (station == 'bar') {
  barItems.insert(0, item);
} else {
  kitchenItems.insert(0, item);
}
```

#### 2. Synchronisation Temps Réel (Socket.IO)

**Événements écoutés** :
- `order:new` : Nouvelle commande → Routage automatique vers Bar/Cuisine
- `order:updated` : Commande mise à jour → Rafraîchissement
- `bill:new` : Nouvelle demande de facture → Ajout à Caisse

**Connexion** :
```dart
final s = io.io(uri, io.OptionBuilder()
  .setTransports(['websocket'])
  .setExtraHeaders({'Origin': uri})
  .build());
```

#### 3. Badges de Notification

**Comptage par table** :
- `unseenCaisseTables` : Tables avec nouvelles commandes (Caisse)
- `unseenBarTables` : Tables avec nouveaux articles (Bar)
- `unseenKitchenTables` : Tables avec nouveaux articles (Cuisine)
- `unseenServiceTables` : Tables avec articles prêts (Service)

**Comptage par groupe** (Bar/Cuisine) :
- `unseenBarGroups` : Groupes `orderId|table` non vus
- `unseenKitchenGroups` : Groupes `orderId|table` non vus

**Animation pulse** : Badges avec animation de pulsation pour attirer l'attention.

#### 4. Filtres et Tri (Bar & Cuisine)

**Filtres** :
- `active` : En cours (liste de travail)
- `done` : Terminés (archives)
- `all` : Tous

**Tri** :
- `urgency` : Par urgence (ratio SLA)
- `table` : Par numéro de table
- `age` : Par ancienneté

**Application** :
```dart
final visible = _applyFilters(source);
final groups = _groupByOrderAndTable(visible, station);
_sortGroups(groups);
```

#### 5. Calcul d'Urgence (SLA)

**SLA par station** :
- **Bar** : 5 minutes
- **Cuisine** : 20 minutes

**Ratio d'urgence** :
```dart
final elapsed = DateTime.now().difference(item.createdAt).inMinutes;
final ratio = elapsed / item.slaMinutes;
```

**Couleur visuelle** :
- Vert : `ratio < 0.5` (OK)
- Orange : `0.5 <= ratio < 1.0` (Attention)
- Rouge : `ratio >= 1.0` (Urgent)

#### 6. Mode Kiosque

**Fonctionnalité** : Mode plein écran pour affichage sur tablette/écran mural.

**Activation** : Bouton dans l'AppBar (`Icons.fullscreen` / `Icons.fullscreen_exit`)

**Comportement** :
- Masque l'AppBar
- Masque les onglets (si nécessaire)
- Optimisé pour interaction tactile

#### 7. Gestion des Statuts

**Statuts d'articles** :
- `newItem` : Nouvel article (non traité)
- `inProgress` : En cours de préparation
- `ready` : Prêt à servir
- `served` : Servi
- `archived` : Archivé

**Transitions** :
- Nouvel article → `inProgress` (clic "Commencer")
- `inProgress` → `ready` (clic "Prêt")
- `ready` → `served` (clic "Servi")
- `served` → `archived` (après un délai)

---

## 🌐 Dashboard Web (`public/dashboard/`)

### Architecture

**Interface HTML simple** avec JavaScript pour Socket.IO.

**Sections** :
- **Commandes** : Liste des commandes en temps réel
- **Demandes de facture** : Liste des demandes de facture
- **Services** : Liste des services

### Fonctionnalités

- Connexion Socket.IO automatique
- Affichage des événements `order:new`, `bill:new`
- Interface minimaliste pour affichage sur écran

**Accès** : `http://localhost:3000/dashboard` (ou URL serveur)

---

## 🔄 Flux de Données

### 1. Nouvelle Commande

```
POS → order:new (Socket.IO)
    ↓
Dashboard → Routage automatique (Bar/Cuisine)
    ↓
Affichage dans l'onglet correspondant
    ↓
Badge de notification si onglet non actif
```

### 2. Préparation d'un Article

```
Cuisine/Bar → Clic "Commencer"
    ↓
Statut → inProgress
    ↓
Clic "Prêt"
    ↓
Statut → ready
    ↓
Ajout à Service
```

### 3. Service

```
Service → Clic "Servi"
    ↓
Statut → served
    ↓
Ajout à Serveur (file d'attente)
    ↓
Après délai → archived
```

---

## 📡 Endpoints API Utilisés

| Endpoint | Méthode | Rôle |
|----------|---------|------|
| `/menu/les-emirs?lng=fr` | GET | Charger le menu pour le mapping station |

**Routes backend** : `routes/client.js`

---

## 🔔 Événements Socket.IO

| Événement | Émetteur | Effet Dashboard |
|-----------|----------|----------------|
| `order:new` | POS (création commande) | Routage automatique → Bar/Cuisine |
| `order:updated` | POS (modification commande) | Rafraîchissement de l'affichage |
| `bill:new` | POS (demande facture) | Ajout à Caisse |

**Émission** : `server/utils/socket.js`

---

## 🎨 Interface Utilisateur

### Onglets

- **Caisse** : Liste des commandes avec total et détails
- **Bar** : Liste groupée par `(orderId, table)` avec expansion
- **Cuisine** : Liste groupée par `(orderId, table)` avec expansion
- **Service** : Liste des articles prêts à servir
- **Serveur** : File d'attente pour le service

### Badges

- **Rouge avec compteur** : Nombre de tables/nouveaux groupes non vus
- **Animation pulse** : Attire l'attention sur les nouveautés
- **Badge "Nouveau"** : Sur les groupes non vus

### Couleurs d'Urgence

- **Vert** : OK (ratio < 0.5)
- **Orange** : Attention (0.5 <= ratio < 1.0)
- **Rouge** : Urgent (ratio >= 1.0)

---

## ⚠️ Points d'Attention

- **Routage automatique** : Le routage Bar/Cuisine se base sur le `group` du menu. Vérifier que le menu est correctement structuré.
- **SLA** : Les SLA (5 min Bar, 20 min Cuisine) sont codés en dur. Adapter si nécessaire.
- **Synchronisation** : Le dashboard se synchronise uniquement via Socket.IO. Pas de polling HTTP.
- **Mode kiosque** : Optimisé pour affichage sur tablette/écran mural en mode plein écran.
- **Archives** : Les articles archivés sont conservés dans `archiveItems` pour consultation historique.

---

## 🧼 Maintenance

- Après chaque modification du menu, vérifier que le routage Bar/Cuisine fonctionne correctement.
- Tester le flux complet : Nouvelle commande → Routage → Préparation → Service → Archive.
- Vérifier la synchronisation temps réel (Socket.IO) en cas de déconnexion/reconnexion.

**Dernière mise à jour** : 2025-01-03 (Documentation structure complète)

