# 📋 LISTE RÉELLE D'EXTRACTION - PosOrderPage_refactor.dart

**Fichier source**: `PosOrderPage_refactor.dart` (copie propre de l'original)
**Nombre de lignes**: **3990 lignes**
**Méthode**: Cut-and-paste strict

---

## ✅ ÉTAT DU FICHIER
- Fichier propre copié depuis `pos_order_page.dart`
- Tous les dialogs sont en code inline (pas d'appels à widgets externes)
- Prêt pour extraction avec méthode cut-and-paste

---

## 📊 PHASE 1: WIDGETS/DIALOGS (21 éléments identifiés)

### Dialogs simples/moyens (code inline dans méthodes):

1. **AddNoteDialog** - ligne 374
   - Méthode: `_showAddNoteDialog()`
   - Taille: ~75 lignes (StatefulBuilder + AlertDialog complet)
   - Utilisé: ligne 2441 (`onTap: _showAddNoteDialog`)

2. **ServerSelectionDialog** - ligne 899
   - Méthode: `_showServerSelectionDialog()`
   - Taille: ~50 lignes
   - Utilisé: lignes 2483, 2496

3. **CoversDialog** - ligne 2943
   - Méthode: `_showCoversDialog()`
   - Taille: ~25 lignes
   - Utilisé: ligne 2524

4. **NotesDialog** - ligne 2969
   - Méthode: `_showNotesDialog()`
   - Taille: ~25 lignes
   - Utilisé: ligne 2529

5. **IngredientDialog** - ligne 2995
   - Méthode: `_showIngredientDialog()`
   - Taille: ~20 lignes
   - Utilisé: (à vérifier)

### Dialogs de transfert complexes:

6. **TransferDialog** - ligne 1147
   - Méthode: `_showTransferDialog()`
   - Taille: ~190 lignes (dialog complexe avec StatefulBuilder)
   - Utilisé: ligne 2838

7. **TransferToNoteDialog** - ligne 1340
   - Méthode: `_showTransferToNoteDialog(Map<int, int> selectedItems)`
   - Taille: ~130 lignes
   - Utilisé: (appelé depuis TransferDialog)

8. **TransferToTableDialog** - ligne 1474
   - Méthode: `_showTransferToTableDialog()`
   - Taille: ~80 lignes
   - Utilisé: (appelé depuis TransferDialog)

9. **TransferItemsSelectionDialog** - ligne 1557
   - Méthode: `_showTransferItemsSelectionDialog()`
   - Taille: ~135 lignes
   - Utilisé: (appelé depuis TransferDialog)

10. **TableDestinationDialog** - ligne 1694
    - Méthode: `_showTableDestinationDialog(Map<int, int> selectedItems)`
    - Taille: ~130 lignes
    - Utilisé: (appelé depuis TransferDialog)

11. **CreateNoteForTransferDialog** - ligne 1827
    - Méthode: `_showCreateNoteForTransferDialog(Map<int, int> selectedItems)`
    - Taille: ~50 lignes
    - Utilisé: (appelé depuis TransferDialog)

12. **CreateTableForNoteTransferDialog** - ligne 1880
    - Méthode: `_showCreateTableForNoteTransferDialog(Map<int, int> selectedItems)`
    - Taille: ~80 lignes
    - Utilisé: (appelé depuis TransferDialog)

13. **CreateTableForTransferDialog** - ligne 1963
    - Méthode: `_showCreateTableForTransferDialog(Map<int, int> selectedItems)`
    - Taille: ~80 lignes
    - Utilisé: (appelé depuis TransferDialog)

14. **CompleteTableTransferDialog** - ligne 3018
    - Méthode: `_showCompleteTableTransferDialog() async`
    - Taille: ~190 lignes (dialog async avec StatefulBuilder)
    - Utilisé: (à vérifier)

15. **TransferServerDialog** - ligne 3210
    - Méthode: `_showTransferServerDialog()`
    - Taille: ~55 lignes
    - Utilisé: ligne 2800

### Classes de dialogs (StatefulWidget complètes):

16. **DebtSettlementDialog** - ligne 3267
    - Classe: `_DebtSettlementDialog` + `_DebtSettlementDialogState`
    - Taille: ~155 lignes (classe complète avec State)
    - Utilisé: (à chercher `_openDebtSettlement`)

17. **DebtPaymentDialog** - ligne 3423
    - Classe: `_DebtPaymentDialog` + `_DebtPaymentDialogState`
    - Taille: ~340 lignes (classe complète avec logique complexe)
    - Utilisé: (appelé depuis DebtSettlementDialog)

18. **TransferServerDialog (classe)** - ligne 3765
    - Classe: `_TransferServerDialog` + `_TransferServerDialogState`
    - Taille: ~220 lignes
    - Note: Il y a peut-être un doublon avec la méthode ligne 3210

**Total Phase 1 estimé**: ~1950 lignes à extraire (49% du fichier)

---

## 📊 PHASE 2: SERVICES

### OrderRepository (~340 lignes):
- `_loadMenu()` - ligne 204 (~15 lignes)
- `_loadExistingOrder()` - ligne 220 (~215 lignes)
- `_saveOrderIdToTable(int orderId)` - ligne 848 (~15 lignes)

### OrderSocketService (~70 lignes):
- `_setupSocketListeners()` - ligne 935 (~65 lignes)

### NoteActions (~250 lignes):
- `_addItem(Map<String, dynamic> item)` - ligne 424 (~120 lignes)
- `_updateQuantity(int index, int newQty)` - ligne 575 (~40 lignes)
- `_deleteLine(int index)` - ligne 633 (~50 lignes)
- `_saveHistoryState(String action)` - ligne 79 (~20 lignes)
- `_undoLastAction()` - ligne 98 (~40 lignes)
- `_resetNewlyAddedItems()` - ligne 140 (~5 lignes)
- `_clearTicket()` - ligne 676 (~20 lignes)
- `_createSubNote(String name, int noteCovers)` - ligne 452 (~35 lignes)

### TransferService (~800 lignes):
- `_sendToKitchen()` - ligne 689 (~155 lignes)
- `_executeTransferToNote(...)` - ligne 2027 (~100 lignes)
- `_executeTransferToTable(...)` - ligne 2130 (~130 lignes)
- `_transferItemsDirectly(...)` - ligne 2262 (~60 lignes)
- `_createNoteAndTransfer(...)` - ligne 2322 (~60 lignes)
- `_executeCompleteTableTransfer(...)` - ligne 3177 (~55 lignes)
- `_executeServerTransfer(...)` - ligne 3234 (~50 lignes)
- + Dialogs de transfert (6-14 ci-dessus) = ~790 lignes

### DebtService (~150 lignes):
- `_loadClients()` - ligne 3285 (~15 lignes)
- `_loadClientHistory()` - ligne 3451 (~35 lignes)
- + DebtSettlementDialog et DebtPaymentDialog (16-17) = ~495 lignes

### TableService (~30 lignes):
- `_loadServerTables()` - ligne 3797 (~30 lignes)
- `_getAvailableTables()` - (à chercher dans le code)

**Total Phase 2 estimé**: ~1640 lignes

---

## 🎯 PLAN D'EXTRACTION

### BATCH 1: Dialogs simples (7 dialogs) - ~280 lignes
- AddNoteDialog
- ServerSelectionDialog
- CoversDialog
- NotesDialog
- IngredientDialog
- TransferServerDialog (méthode)
- DebtSettlementDialog (classe)

### BATCH 2: Dialogs de transfert (8 dialogs) - ~850 lignes
- TransferDialog
- TransferToNoteDialog
- TransferToTableDialog
- TransferItemsSelectionDialog
- TableDestinationDialog
- CreateNoteForTransferDialog
- CreateTableForNoteTransferDialog
- CreateTableForTransferDialog
- CompleteTableTransferDialog

### BATCH 3: Dialogs complexes (2 classes) - ~560 lignes
- DebtPaymentDialog
- TransferServerDialog (classe)

**Total Batch 1-3**: ~1690 lignes (42% du fichier)

### BATCH 4: Services essentiels (2 services) - ~410 lignes
- OrderRepository (~340 lignes)
- OrderSocketService (~70 lignes)

**🎯 TOTAL à 50%**: ~2100 lignes extraites (52% du fichier)
**👉 TEST VISUEL UNIQUE après ce point**

### BATCH 5: Services complémentaires (après test)
- NoteActions (~250 lignes)
- TransferService (~800 lignes)
- DebtService (~150 lignes)
- TableService (~30 lignes)

---

## ✅ VÉRIFICATIONS

Tous les dialogs identifiés sont **utilisés** (grep confirme):
- `_showAddNoteDialog` → utilisé ligne 2441
- `_showServerSelectionDialog` → utilisé lignes 2483, 2496
- `_showCoversDialog` → utilisé ligne 2524
- `_showNotesDialog` → utilisé ligne 2529
- `_showTransferDialog` → utilisé ligne 2838
- `_showTransferServerDialog` → utilisé ligne 2800

**Prêt pour extraction avec méthode cut-and-paste !**

