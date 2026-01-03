# POS Home – Structure refactorisée

## But
Découper `PosHomePage` en modules clairs, testables et faciles à maintenir, alignés avec la structure serveur (routes/controllers/utils).

## Arborescence

- pages/home/
  - PosHomePage_refactor.dart (UI principale – build + wiring)
  - state/
    - home_state.dart (source de vérité: userName, useCloudApi, query, selectedStatuses, serverTables; getters dérivés: filteredTables)
    - home_controller.dart (actions UI: setQuery, toggleStatus, changeServer, toggle API)
  - services/
    - api_prefs.dart (charger/sauver/apply URLs + mode cloud/local)
    - socket_service.dart (Socket.IO; bind des events → sync + notify)
    - tables_repository.dart (SharedPreferences load/save des tables)
    - orders_sync_service.dart (GET /orders → agrégation table/serveur, totaux, purge)
    - table_actions.dart (ouvrir/fermer table, navigation PosOrderPage)
    - cleanup_service.dart (suppression et nettoyage tables vides)
    - admin_actions.dart (test API, simulation, reset, clear history)
    - local_storage_service.dart (purge cache POS côté client)
  - utils/
    - time_helpers.dart (affichages temps + couleurs d’inactivité)
  - widgets/
    - HeaderLogoTitle.dart, DateTimeBadge.dart, HeaderActions.dart (bloc Simulation/Admin)
    - TableLegendBar.dart, TableFiltersBar.dart, TableSearchBar.dart, TableGrid.dart, TableCard.dart
    - AddTableDialog.dart, ReservationDialog.dart, TableOptionsDialog.dart, CleanupEmptyTablesDialog.dart
    - SimulationDialog.dart, BottomToolbar.dart

## Principes
- State unique (`HomeState`) + services par domaine (prefs, sockets, sync, actions).
- La page ne contient que l’assemblage visuel et des callbacks vers contrôleur/services.
- Synchronisation temps réel: events Socket.IO → `OrdersSyncService.syncOrdersWithTables` → `HomeState.notifyListeners` → UI.

## Checklist parité fonctionnelle
- [x] Navigation table → commande et retour avec resync
- [x] Ajout/suppression/cleanup tables
- [x] Recherche + filtres par statut
- [x] Bascule API local/cloud + configuration
- [x] Simulation / reset / clear history

## Objectif taille
- Page cible: 500–600 lignes (actuel ~680–830 selon builds).
- Déplacer toute logique métier supplémentaire dans services.
