# Inventaire Complet - Extraction PosOrderPage_refactor.dart

**Fichier source**: `PosOrderPage_refactor.dart` (3877 lignes)
**Méthode**: Cut-and-paste strict

## 📋 ANALYSE RÉELLE DU CODE

### PHASE 1: Widgets/Dialogs à extraire

#### ✅ Déjà extraits (mais peut-être encore dans le fichier - À VÉRIFIER):
1. `AddNoteDialog` - ligne 382 (`_showAddNoteDialog()`)
2. `ServerSelectionDialog` - ligne 840 (`_showServerSelectionDialog()`)
3. `CoversDialog` - ligne 2861 (`_showCoversDialog()`)
4. `NotesDialog` - ligne 2874 (`_showNotesDialog()`)
5. `DebtSettlementDialog` - (utilisé ligne 3117)
6. `DebtPaymentDialog` - classe ligne 3307 (`_DebtPaymentDialog`)
7. `TransferServerDialog` - classe ligne 3649 (`_TransferServerDialog`)

#### ❓ À EXTRAIRE (dialogs trouvés dans le code):
8. `IngredientDialog` - ligne 2886 (`_showIngredientDialog()`) - Dialog simple pour modifier ingrédients
9. `TransferDialog` - ligne 1064 (`_showTransferDialog()`) - Dialog complexe pour transfert items/notes
10. `CompleteTableTransferDialog` - ligne 2909 (`_showCompleteTableTransferDialog()`) - Dialog pour transfert complet de table
11. `TransferToTableDialog` - ligne 1391 (`_showTransferToTableDialog()`) - À vérifier si existe
12. `TransferItemsSelectionDialog` - ligne 1474 (`_showTransferItemsSelectionDialog()`) - À vérifier

### PHASE 2: Services à extraire

#### OrderRepository (méthodes de chargement/sauvegarde):
- `_loadMenu()` - ligne 212
- `_loadExistingOrder()` - ligne 228
- `_saveOrderIdToTable(int orderId)` - ligne 788

#### OrderSocketService (communication socket):
- `_setupSocketListeners()` - ligne 935

#### NoteActions (actions sur les notes):
- `_addItem(Map<String, dynamic> item)` - ligne 432
- `_updateQuantity(int index, int newQty)` - ligne 503
- `_deleteLine(int index)` - ligne 561
- `_saveHistoryState(String action)` - ligne 79
- `_undoLastAction()` - ligne 98
- `_resetNewlyAddedItems()` - ligne 140
- `_clearTicket()` - ligne 598
- `_createSubNote(String name, int noteCovers)` - ligne 392

#### TransferService (toutes les méthodes de transfert):
- `_sendToKitchen()` - ligne 629
- `_executeTransferToNote(String targetNoteId, Map<int, int> selectedItems)` - ligne 1944
- `_executeTransferToTable(...)` - ligne 2047
- `_transferItemsDirectly(...)` - ligne 2179
- `_createNoteAndTransfer(...)` - ligne 2239
- `_executeCompleteTableTransfer(...)` - ligne 3068
- `_executeServerTransfer(...)` - ligne 3126
- `_showTransferDialog()` - ligne 1064 (dialog mais logique de transfert)
- `_showTransferToTableDialog()` - ligne 1391 (à vérifier)
- `_showTransferItemsSelectionDialog()` - ligne 1474 (à vérifier)
- `_showCompleteTableTransferDialog()` - ligne 2909 (dialog mais logique de transfert)

#### DebtService (gestion des dettes - à vérifier si nécessaire):
- `_loadClients()` - ligne 3169
- `_loadClientHistory()` - ligne 3335
- (Logique dans DebtSettlementDialog et DebtPaymentDialog)

#### TableService (gestion des tables - à vérifier si nécessaire):
- `_loadServerTables()` - ligne 3681
- `_getAvailableTables()` - (à chercher)

### PHASE 3: State/Controller (à décider)
- Variables d'état à centraliser dans `OrderState`
- Controller pour orchestrer

## 📊 COMPTEUR RÉEL

**Dialogs/Widgets identifiés**: 
- Déjà extraits (7): AddNoteDialog, ServerSelectionDialog, CoversDialog, NotesDialog, DebtSettlementDialog, DebtPaymentDialog, TransferServerDialog
- À extraire (au moins 3-5): IngredientDialog, TransferDialog, CompleteTableTransferDialog, + autres si trouvés

**Services identifiés**:
- OrderRepository: ~3 méthodes
- OrderSocketService: ~1 méthode
- NoteActions: ~8 méthodes
- TransferService: ~11 méthodes
- Autres: DebtService, TableService (à décider)

**Total estimé**: 
- ~10-12 widgets/dialogs (dont 7 déjà faits, 3-5 à faire)
- ~4-6 services
- ~2 fichiers state/controller

## ⚠️ IMPORTANT

**Cette liste est basée sur l'analyse grep, pas une lecture complète**. 
Il peut y avoir d'autres éléments cachés dans le code (dialogs inline, méthodes privées, etc.).

**Action requise**: 
1. Vérifier si les 7 widgets "déjà extraits" sont vraiment supprimés du fichier
2. Analyser chaque `_show*` pour voir si c'est un dialog à extraire
3. Compter les lignes réellement utilisées par chaque méthode
4. Ajuster la liste après analyse complète

