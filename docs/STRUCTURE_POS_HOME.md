# 🏠 Module POS – Home (Plan de table)

## 📍 Objectif
Décrire l’architecture du module « Home » (plan de table) : fichiers, services, widgets et flux de données. Ce document complète la vue d’ensemble présente dans `STRUCTURE_POS.md`.

---

## 📂 Fichiers clés

| Type | Fichier | Rôle |
|------|---------|------|
| Page principale | `lib/features/pos/pages/home/PosHomePage_refactor.dart` | Vue plan de table, navigation vers Order/Payment, sockets |
| State | `state/home_state.dart` | Store centralisé (tables, filtres, serveur actif) |
| Controller | `state/home_controller.dart` | Logique métier (filtrage, recherche, actions UI) |
| Utils | `utils/time_helpers.dart` | Formatage durées (inactivité, temps écoulé) |

---

## 🎯 Responsabilités
- Afficher toutes les tables d’un serveur avec leurs statuts.
- Synchroniser les commandes serveur ↔ stockage local (`OrdersSyncService`).
- Router vers `PosOrderPage` (tap) ou `PosPaymentPage` (long press).
- Gérer les sous-notes (dialog de sélection si plusieurs notes ouvertes).
- Administrer l’historique, la simulation, le nettoyage des tables vides.
- Supporter les bascules API (local/cloud) et la connexion Socket.IO.

---

## 🧩 Services

| Service | Emplacement | Responsabilité principale | Dépendances |
|---------|-------------|---------------------------|-------------|
| `HomeSocketService` | `services/socket_service.dart` | Connexion Socket.IO, écoute `order:updated`, `table:sync` | `socket_io_client`, `HomeState` |
| `OrdersSyncService` | `services/orders_sync_service.dart` | Sync tables ↔ API (`/orders?table=`) | `ApiClient`, `TablesRepository` |
| `TablesRepository` | `services/tables_repository.dart` | Lecture/écriture des tables (SharedPreferences) | `SharedPreferences` |
| `TableActions` | `services/table_actions.dart` | Ouvrir/fermer table, navigation vers Order/Payment | `Navigator`, `PosOrderPage`, `PosPaymentPage` |
| `ApiPrefsService` | `services/api_prefs.dart` | Bascule API local/cloud + persistance | `SharedPreferences`, `ApiClient` |
| `HistoryService` + `HistoryController` | `services/history_*.dart` | Chargement et gestion de l'historique des tables | `ApiClient` |
| `ServerSalesReportService` | `services/server_sales_report_service.dart` | Chargement des KPI pour le mini-X report d'un serveur | `KpiService` (admin) |
| `ServerSalesReportController` | `services/server_sales_report_controller.dart` | Orchestration du chargement et de l'affichage du mini-X | `ServerSalesReportService` |
| `CleanupService` | `services/cleanup_service.dart` | Suppression des tables vides et persistantes | `TablesRepository` |
| `LocalStorageService` | `services/local_storage_service.dart` | Utility pour vider le cache POS | `SharedPreferences` |
| `AdminActions` | `services/admin_actions.dart` | Simulation, reset système, tests API | `ApiClient`, `LocalStorageService` |

---

## 🧱 Widgets clés

- **Structure principale**
  - `TableGrid.dart` : grille des tables avec gestion tap/long press.
  - `TableCard.dart` : carte individuelle (statut, serveur, timers).
  - `HeaderLogoTitle.dart`, `HeaderActions.dart` (Simulation/Admin isolés), `DateTimeBadge.dart`, bouton `Historique`, bouton `Déconnexion`.

- **Dialogs utilisateurs**
  - `AddTableDialog.dart` : création table (numéro, couverts).
  - `ReservationDialog.dart` : gestion des tables réservées.
  - `CleanupEmptyTablesDialog.dart` : suppression tables vides.
  - `SimulationDialog.dart` : déclenche des scénarios via `AdminActions`.
  - `ApiConfigDialog.dart` : configuration URLs API.
  - `TableHistoryDialog.dart`, `HistoryView.dart` : consultation de l'historique.
  - `ServerSalesReportDialog.dart` : 🆕 affichage du mini-X report (ventes du jour) pour le serveur actif, avec option d'impression.

- **Outils visuels**
  - `TableLegendBar.dart`, `TableFiltersBar.dart`, `TableSearchBar.dart`.
  - `TableSyncBanner.dart` : bannière de synchronisation forcée.
  - `BottomToolbar.dart` : accès rapide aux fonctions secondaires (inclut bouton "Mes encaissements" pour mini-X).

---

## 🧭 Parcours utilisateur

```
Tap table occupée
  ├─ Charger notes via OrderRepository.loadExistingOrder()
  ├─ Sous-notes ? → dialog `_showNoteSelectionDialog`
  └─ Navigation vers PosOrderPage(initialNoteId choisi)

Long press table occupée
  ├─ Charge notes + commandes (`_loadNotesForTable`, `getAllOrdersForTable`)
  └─ Navigation directe vers PosPaymentPage

Tap table réservée
  └─ `ReservationDialog` (libérer / ouvrir)
```

---

## 🔄 Flux de données

```
PosHomePage
  ├─ initState()
  │   ├─ HomeController/HomeState
  │   ├─ _loadApiPrefs() → ApiPrefsService + reconnect socket
  │   ├─ _loadTables() → TablesRepository + OrdersSyncService
  │   └─ _connectSocket() → HomeSocketService
  │
  ├─ _handleTableTap()
  │   ├─ Charge notes via OrderRepository
  │   └─ Navigue vers PosOrderPage (TableActions)
  │
  └─ _handleTableLongPress()
      ├─ Charge notes + commandes (OrderPaymentService)
      └─ Navigue vers PosPaymentPage
```

---

## 🔔 Événements Socket.IO
- `order:updated`, `order:archived`, `order:new` → recharge des tables et timers.
- `table:sync` → relance `OrdersSyncService.syncOrdersWithTables()`.

---

## 🎨 Patterns Récurrents

### Synchronisation après navigation
```dart
Navigator.of(context).push(...).then((result) {
  if (result?['force_refresh'] == true) {
    _syncOrdersWithTables();
  }
});
```

### Gestion Socket.IO avec vérification mounted
```dart
_homeSocket.bindDefaultHandlers(
  onUiUpdate: () {
    if (!mounted) return;
    Future.microtask(() {
      if (!mounted) return;
      setState(() {});
    });
  },
);
```

### Chargement tables avec fallback
```dart
await _loadTables(); // Charge depuis SharedPreferences
await _syncOrdersWithTables(); // Synchronise avec API
```

---

## ⚠️ Points d'Attention

- **Synchronisation** : Toujours vérifier `mounted` avant `setState()` après opérations async
- **Socket.IO** : Nettoyer les listeners dans `dispose()` via `_homeSocket.dispose()` pour éviter fuites mémoire
- **Multi-serveurs** : Les tables sont groupées par serveur dans `serverTables` (Map<String, List>)
- **Sous-notes** : Lors du tap, charger les notes via `OrderRepository.loadExistingOrder()` avant de naviguer
- **API local/cloud** : Le basculement via `ApiPrefsService` nécessite une reconnexion Socket.IO
- **Historique** : Le mode historique (`_showHistory`) charge les données via `HistoryController.loadHistory()`

---

## 🧼 Maintenance
- Toute modification de navigation (tap/long press) doit être répercutée dans `TableActions` et ici.
- Ajouter un service ou un widget : compléter les tableaux ci-dessus.
- En cas de nouveau dialog ou action admin, mentionner la dépendance (`AdminActions`, `OrdersSyncService`, etc.).

**Dernière mise à jour** : 2024-12-19 (ajout mini-X report serveur)

