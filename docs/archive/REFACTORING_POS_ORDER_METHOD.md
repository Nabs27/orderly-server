# Méthode de Refactorisation PosOrderPage - Cut-and-Paste

## 🚀 DÉMARRAGE APRÈS UNDO MANUEL

**Après avoir restauré PosOrderPage_refactor.dart à l'état initial**:
1. Dis simplement: "Suis la méthode dans REFACTORING_POS_ORDER_METHOD.md"
2. Je lirai automatiquement ce document et suivrai strictement la méthode
3. **ÉTAPE 0**: Je ferai d'abord une ANALYSE COMPLÈTE du fichier pour identifier TOUS les éléments à extraire
4. Je créerai une liste réelle basée sur l'analyse (pas d'estimation)
5. Puis j'extrairai suivant l'ordre défini

**Objectif**: Extraire ~50% du code en une passe, puis TEST VISUEL UNIQUE

## 📊 ÉTAPE 0: ANALYSE COMPLÈTE (OBLIGATOIRE)

**AVANT de commencer toute extraction**, je dois:
1. Compter les lignes du fichier: `wc -l` ou équivalent
2. Identifier TOUS les dialogs: `grep "void _show.*Dialog\|class _.*Dialog"`
3. Identifier TOUTES les méthodes de service: `grep "Future<void> _load\|Future<void> _save\|Future<void> _execute"`
4. Vérifier quels widgets sont déjà extraits (imports présents?)
5. **Créer une liste réelle** avec nombre de lignes estimé pour chaque élément
6. **Afficher cette liste** avant de commencer pour validation

**Ne pas commencer l'extraction tant que cette analyse n'est pas faite et validée.**

## PRINCIPE FONDAMENTAL
**TOUJOURS utiliser CUT-and-PASTE, jamais COPY-paste**
1. **COUPER** le code de `PosOrderPage_refactor.dart`
2. **COLLER** dans le nouveau fichier créé
3. **REMPLACER** l'ancien code par un simple appel/appel widget
4. **VÉRIFIER** que `PosOrderPage_refactor.dart` a rétréci (nombre de lignes)

## ORDRE D'EXTRACTION

### PHASE 1: Widgets/Dialogs
**⚠️ IMPORTANT**: Cette liste est une ESTIMATION basée sur grep. Le nombre réel peut varier après analyse complète du code.

**Règle**: Analyser d'abord le fichier pour identifier TOUS les dialogs, puis extraire en une passe
- **Test visuel**: UNE SEULE FOIS après avoir terminé ~50% du travail total (widgets + services partiels)

**Dialogs identifiés (analyse grep)**:
1. AddNoteDialog (déjà extrait? - ligne 382)
2. ServerSelectionDialog (déjà extrait? - ligne 840)
3. CoversDialog (déjà extrait? - ligne 2861)
4. NotesDialog (déjà extrait? - ligne 2874)
5. DebtSettlementDialog (déjà extrait? - ligne 3117)
6. DebtPaymentDialog (classe ligne 3307 - À VÉRIFIER si supprimée)
7. TransferServerDialog (classe ligne 3649 - À VÉRIFIER si supprimée)
8. **IngredientDialog** (ligne 2886 - À EXTRAIRE)
9. **TransferDialog** (ligne 1064 - À EXTRAIRE - complexe)
10. **CompleteTableTransferDialog** (ligne 2909 - À EXTRAIRE)

**Action**: Analyser d'abord le fichier pour identifier TOUS les dialogs, puis lister le nombre réel avant de commencer

1. **AddNoteDialog**
   - COUPER: Méthode `_showAddNoteDialog()` + son StatefulBuilder/AlertDialog complet
   - COLLER dans: `widgets/AddNoteDialog.dart`
   - REMPLACER dans PosOrderPage_refactor par: `showDialog(context: context, builder: (ctx) => AddNoteDialog(onCreateNote: _createSubNote))`
   - VÉRIFIER: PosOrderPage_refactor a perdu ~75 lignes

2. **ServerSelectionDialog**
   - COUPER: Méthode `_showServerSelectionDialog()` + AlertDialog complet
   - COLLER dans: `widgets/ServerSelectionDialog.dart`
   - REMPLACER par: `showDialog(context: context, builder: (ctx) => ServerSelectionDialog(servers: servers, onServerSelected: (s) { setState(() => selectedServer = s); _openTablePlan(); }))`
   - VÉRIFIER: Fichier rétréci de ~40 lignes

3. **CoversDialog**
   - COUPER: Méthode `_showCoversDialog()` + AlertDialog
   - COLLER dans: `widgets/CoversDialog.dart`
   - REMPLACER par: `showDialog(context: context, builder: (_) => CoversDialog(currentCovers: covers, onCoversChanged: (c) => setState(() => covers = c)))`
   - VÉRIFIER: Fichier rétréci de ~25 lignes

4. **NotesDialog**
   - COUPER: Méthode `_showNotesDialog()` + AlertDialog
   - COLLER dans: `widgets/NotesDialog.dart`
   - REMPLACER par: `showDialog(context: context, builder: (_) => NotesDialog(currentNotes: notes, onNotesChanged: (n) => setState(() => notes = n)))`
   - VÉRIFIER: Fichier rétréci de ~25 lignes

5. **DebtSettlementDialog**
   - COUPER: Classe complète `class _DebtSettlementDialog extends StatefulWidget { ... }` + State
   - COLLER dans: `widgets/DebtSettlementDialog.dart` (exporter comme classe publique)
   - REMPLACER dans `_openDebtSettlement()`: `showDialog(context: context, builder: (ctx) => const DebtSettlementDialog())`
   - VÉRIFIER: Fichier rétréci de ~155 lignes (toute la classe)

6. **DebtPaymentDialog**
   - COUPER: Classe complète `class _DebtPaymentDialog extends StatefulWidget { ... }` + State (TOUT)
   - COLLER dans: `widgets/DebtPaymentDialog.dart`
   - REMPLACER dans DebtSettlementDialog: `DebtPaymentDialog(client: client)` (déjà utilisé)
   - VÉRIFIER: Fichier rétréci de ~235 lignes

7. **TransferServerDialog**
   - COUPER: Classe complète `class _TransferServerDialog extends StatefulWidget { ... }` + State (TOUT)
   - COLLER dans: `widgets/TransferServerDialog.dart`
   - REMPLACER dans `_showTransferServerDialog()`: `TransferServerDialog(...)`
   - VÉRIFIER: Fichier rétréci de ~220 lignes

**Total Phase 1**: ~775 lignes supprimées de PosOrderPage_refactor

### PHASE 2: Services (extraction partielle jusqu'à 50%)
**Règle**: Extraire jusqu'à atteindre ~50% du travail total, puis TEST VISUEL UNIQUE

8. **OrderRepository**
   - COUPER: Méthodes `_loadMenu()`, `_loadExistingOrder()`, `_saveOrderIdToTable()`
   - COLLER dans: `services/order_repository.dart`
   - REMPLACER par appels au repository
   - VÉRIFIER: ~340 lignes supprimées

9. **OrderSocketService**
   - COUPER: Méthode `_setupSocketListeners()` complète + dispose socket
   - COLLER dans: `services/order_socket_service.dart`
   - REMPLACER par: service.setup(...)
   - VÉRIFIER: ~70 lignes supprimées

**🎯 À CE POINT (~50% du travail)**: 
- Widgets extraits: (nombre à déterminer après analyse)
- Services extraits: 2 fichiers (OrderRepository + OrderSocketService)
- **TOTAL extrait**: (à calculer après extraction)
- **ACTION**: TEST VISUEL UNIQUE - Hot reload et tester toutes les fonctionnalités

**⚠️ Le pourcentage exact sera calculé après avoir analysé réellement le fichier et identifié TOUS les éléments à extraire**

10. **NoteActions** (après test visuel)
    - COUPER: Méthodes `_addItem()`, `_updateQuantity()`, `_deleteLine()`, `_saveHistoryState()`, `_undoLastAction()`
    - COLLER dans: `services/note_actions.dart`
    - REMPLACER par appels au service
    - VÉRIFIER: ~200 lignes supprimées

11. **TransferService** (optionnel, complexe)
    - COUPER: Toutes les méthodes `_showTransfer*` et `_transfer*`
    - COLLER dans: `services/transfer_service.dart`
    - VÉRIFIER: ~800 lignes supprimées

### PHASE 3: State/Controller (2 fichiers)
**Règle**: Centraliser l'état

12. **OrderState** (ChangeNotifier)
    - Extraire: `mainNote`, `subNotes`, `activeNoteId`, `activeOrderId`, `menu`, `loadingMenu`, etc.
    - Créer getters/setters

13. **OrderController**
    - Orchestrer les appels aux services et state

## RÈGLES CRITIQUES

### ✅ À FAIRE
- **TOUJOURS** couper le code, ne jamais le copier
- **TOUJOURS** vérifier le nombre de lignes après chaque extraction
- **TOUJOURS** tester visuellement (hot reload) UNE SEULE FOIS après ~50% du travail total (widgets + services partiels)
- **TOUJOURS** supprimer TOUT le bloc (méthode/classe complète), pas juste une partie
- **TOUJOURS** adapter les imports après chaque extraction

### ❌ À NE PAS FAIRE
- ❌ Copier au lieu de couper
- ❌ Laisser du code dupliqué dans PosOrderPage_refactor
- ❌ Extraire plusieurs fichiers en même temps (sauf si petits)
- ❌ Oublier de remplacer l'ancien code par l'appel

## VÉRIFICATION

### Après chaque extraction individuelle:
1. Compter les lignes: le fichier doit rétrécir
2. Vérifier les imports: aucun import manquant
3. Pas de duplication: chercher le nom de la classe/méthode dans PosOrderPage_refactor (grep)

### Après ~50% du travail total (widgets + services partiels):
1. **TEST VISUEL UNIQUE**: hot reload, tester toutes les fonctionnalités extraites
2. Vérifier compilation: aucune erreur
3. Compter lignes totales: le fichier doit avoir rétréci significativement (~40-50%)

## EXEMPLE CONCRET (AddNoteDialog)

**AVANT** (dans PosOrderPage_refactor.dart):
```dart
void _showAddNoteDialog() {
  final nameController = TextEditingController();
  int noteCovers = 1;
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        // ... 70 lignes de code ...
      ),
    ),
  );
}
```

**ÉTAPE 1**: COUPER ces 75 lignes de PosOrderPage_refactor.dart

**ÉTAPE 2**: COLLER dans `widgets/AddNoteDialog.dart`:
```dart
class AddNoteDialog extends StatefulWidget {
  final Function(String, int) onCreateNote;
  // ... code collé ...
}
```

**ÉTAPE 3**: REMPLACER dans PosOrderPage_refactor.dart:
```dart
void _showAddNoteDialog() {
  showDialog(
    context: context,
    builder: (context) => AddNoteDialog(
      onCreateNote: (name, covers) => _createSubNote(name, covers),
    ),
  );
}
```

**ÉTAPE 4**: VÉRIFIER
- PosOrderPage_refactor: 4099 → 4024 lignes (-75) ✅
- Import ajouté: `import 'widgets/AddNoteDialog.dart';` ✅
- Test visuel: Hot reload, tester création note ✅

## DÉTECTION DES DUPLICATIONS - Comment savoir si un code est utilisé ou obsolète?

### Méthode de vérification AVANT d'extraire un bloc:

1. **Chercher les appels/utilisations**:
   ```bash
   grep -n "nom_de_la_methode\|nom_de_la_classe" PosOrderPage_refactor.dart
   ```
   
2. **Règles de décision**:
   - ✅ **UTILISÉ**: La méthode/classe apparaît dans `build()`, `initState()`, ou comme callback `onPressed:`, `onTap:`, etc.
   - ✅ **ACTIF**: Référencé via `widget.nom` ou `this.nom`
   - ⚠️ **OBSOLÈTE**: La méthode/classe existe mais n'est JAMAIS appelée/referencée
   - ⚠️ **DUPLIQUÉ**: La même fonctionnalité existe en plusieurs endroits avec des noms différents

3. **Exemple pratique**:
   ```dart
   // Si je trouve:
   onPressed: _showAddNoteDialog,  // ✅ UTILISÉ → À extraire
   void _showAddNoteDialog() { ... }  // ✅ ACTIF → À extraire
   
   // Mais si je trouve:
   void _ancienneMethodeObsolete() { ... }  // ⚠️ Jamais appelée → NE PAS extraire (code mort)
   
   // Ou si je trouve deux fois:
   void _showAddNoteDialog() { ... }  // ✅ Version 1
   void _showAddNoteDialogOld() { ... }  // ⚠️ Version ancienne → Vérifier laquelle est utilisée
   ```

4. **Processus de vérification avant extraction**:
   - ÉTAPE 1: Chercher toutes les occurrences du nom dans le fichier
   - ÉTAPE 2: Vérifier si elle est appelée (dans build, callbacks, etc.)
   - ÉTAPE 3: Si utilisée → EXTRAIRE. Si obsolète → SUPPRIMER sans extraire
   - ÉTAPE 4: Si duplication → Extraire seulement la version UTILISÉE

### Exemples concrets:

**Cas 1: Méthode utilisée (À EXTRAIRE)**
```dart
// Dans build():
IconButton(onPressed: _showCoversDialog, ...)
// → ✅ _showCoversDialog est utilisée → EXTRAIRE

// Dans la méthode:
void _showCoversDialog() { ... }  // → COUPER et EXTRAIRE
```

**Cas 2: Méthode obsolète (À SUPPRIMER, pas extraire)**
```dart
// Aucune référence trouvée dans build(), callbacks, etc.
void _ancienneMethode() { ... }  // → ⚠️ Jamais appelée
// → SUPPRIMER du fichier, ne pas extraire (code mort)
```

**Cas 3: Duplication (Extraire seulement la version active)**
```dart
// Version 1 (utilisée):
onPressed: _showAddNoteDialog,  // ✅ Cette version est utilisée

void _showAddNoteDialog() { ... }  // → EXTRAIRE celle-ci

// Version 2 (obsolète):
void _showAddNoteDialogOld() { ... }  // ⚠️ Jamais appelée
// → SUPPRIMER celle-ci (ne pas extraire)
```

### ⚠️ EXEMPLE RÉEL: Problème actuel dans PosOrderPage_refactor.dart

**Grep montre**:
```
Ligne 19: import 'widgets/DebtSettlementDialog.dart';  // ✅ Import OK
Ligne 3117: DebtSettlementDialog()  // ✅ Utilisation OK
Ligne 3159: // Classes extraites...  // ✅ Commentaire OK
Ligne 3307: class _DebtSettlementDialog extends StatefulWidget { ... }  // ⚠️ DUPLICATION!
Ligne 3308: class _DebtSettlementDialogState extends State { ... }  // ⚠️ DUPLICATION!
```

**Analyse**:
- ✅ Ligne 3117: `DebtSettlementDialog()` → **Version EXTRAITE utilisée** (OK)
- ⚠️ Lignes 3307-3315: `class _DebtSettlementDialog` → **Version ORIGINALE encore présente** (DUPLICATION!)

**Action à faire**:
1. ✅ Garder: Ligne 3117 (utilisation de la version extraite)
2. ❌ SUPPRIMER: Lignes 3307-3315 (classe originale dupliquée - code mort)

**Même problème pour**:
- `_DebtPaymentDialog` (ligne 3307) → SUPPRIMER
- `_TransferServerDialog` (ligne 3649) → SUPPRIMER

**Méthode de vérification après extraction**:
```bash
# Si le grep montre:
# 1. L'import du widget → ✅ OK
# 2. L'utilisation du widget (DebtSettlementDialog()) → ✅ OK  
# 3. La définition de la classe originale (_DebtSettlementDialog) → ⚠️ SUPPRIMER!
```

## PROMPT POUR L'ASSISTANT

**Quand tu démarres** (après undo manuel):
- Lire automatiquement ce document (REFACTORING_POS_ORDER_METHOD.md)
- Suivre strictement l'ordre d'extraction
- Extraire widgets + services jusqu'à ~50% puis faire le TEST VISUEL UNIQUE

**AVANT chaque extraction (vérification)**:
1. Chercher toutes les occurrences: `grep "nom_methode\|nom_classe" PosOrderPage_refactor.dart`
2. Vérifier si utilisé: dans build(), callbacks, initState(), etc.
3. Décider: UTILISÉ → Extraire | OBSOLÈTE → Supprimer | DUPLIQUÉ → Extraire version active seulement

**PENDANT extraction**:
1. Lit le bloc complet dans PosOrderPage_refactor.dart
2. **COUPE-le** (supprime-le de PosOrderPage_refactor - pas de copie!)
3. CRÉE le nouveau fichier avec ce code (adapté)
4. REMPLACE dans PosOrderPage_refactor par l'appel/widget
5. AJOUTE l'import nécessaire
6. VÉRIFIE: le fichier a rétréci et il n'y a plus de duplication (grep pour confirmer)

**APRÈS chaque extraction**:
- Compter lignes: fichier rétréci
- Grep: plus d'occurrence de la classe/méthode (sauf l'appel)

**APRÈS ~50% du travail (widgets + 2 services)**:
- **TEST VISUEL UNIQUE**: Hot reload et tester toutes les fonctionnalités
- Vérifier compilation: aucune erreur
- Continuer avec le reste après validation

**Ne passe pas à l'extraction suivante tant que**:
- Le fichier n'a pas rétréci (lignes supprimées)
- Grep confirme qu'il n'y a plus de duplication
- Pas d'erreur de compilation (après ~50%)

