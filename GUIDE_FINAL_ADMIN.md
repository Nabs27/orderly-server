# 🎯 Guide Complet Dashboard Admin — Orderly

## ✅ Ce qui a été fait

### 1. **Menu Optimisé** 
- ✅ **Variantes séparées** : "Coca / Fanta / Boga" → 3 articles distincts
- ✅ **176 articles** → maintenant **gérable individuellement**
- ✅ Backup automatique créé : `menu.backup.json`

### 2. **Interface Admin Améliorée**
- ✅ **Navigation à 2 niveaux** (comme l'app client) :
  - **Niveau 1** : 🥤 Boissons / 🍷 Spiritueux / 🍽️ Plats
  - **Niveau 2** : Boisson froide / Boisson chaude / Apéritif / etc.
- ✅ **Recherche instantanée**
- ✅ **Toggle disponibilité en 1 clic** (icône 👁️)
- ✅ Articles indisponibles : fond gris + texte barré

### 3. **Parser IA Intelligent**
- ✅ **DeepSeek V3.1** séparera automatiquement les variantes lors de l'upload PDF
- ✅ Détection intelligente : "Coca / Fanta" → 2 articles

### 4. **API Backend Complète**
- ✅ CRUD menu complet
- ✅ Filtrage automatique items `available: false`
- ✅ Upload PDF → JSON (avec clé OpenRouter)
- ✅ Déployé sur Railway

---

## 🚀 Comment Utiliser

### **A. Gérer la Disponibilité (Usage Principal)**

#### Exemple 1 : Plus de Boga disponible

1. **Lancez l'app Admin** :
   ```bash
   cd flutter_les_emirs
   flutter run -d chrome --dart-define=INITIAL_ROUTE=/admin
   ```

2. **Connexion** : `admin123`

3. **Navigation** :
   - Cliquez sur "Les Emirs"
   - Sélectionnez 🥤 **Boissons**
   - Sélectionnez **Boisson froide**

4. **Vous voyez maintenant** :
   - Coca ✅
   - Fanta ✅
   - Boga ✅
   - Sprite ✅
   - (séparés !)

5. **Masquer Boga** :
   - Cliquez sur l'icône 👁️ à gauche de "Boga"
   - ✅ **Boga disparaît immédiatement du menu client !**

6. **Vérifier** :
   - Ouvrez l'app client Flutter
   - Boissons → Boisson froide
   - **Boga n'apparaît plus** ✅

#### Exemple 2 : Plus de Mérou Grillé

1. Groupe : 🍽️ **Plats**
2. Type : **Poisson**
3. Chercher "Mérou" (barre de recherche)
4. Cliquer 👁️ sur "Mérou Grillé ou avec des Pâtes prix"
5. ✅ **Masqué !**

---

### **B. Modifier un Prix**

1. Naviguer jusqu'à l'article
2. Cliquer sur l'icône **crayon** ✏️
3. Modifier le prix
4. **Enregistrer**
5. ✅ Changement instantané (traductions vidées automatiquement)

---

### **C. Ajouter un Nouvel Article**

1. Naviguer jusqu'à la catégorie (ex: "Boissons — Soft")
2. Cliquer sur **+ vert** dans l'en-tête
3. Remplir :
   - **Nom** : "Schweppes Citron"
   - **Prix** : 6
   - **Type** : "Boisson froide"
4. **Ajouter**
5. ✅ Article créé avec ID auto

---

### **D. Upload PDF pour Créer un Nouveau Restaurant**

**Important** : Ajoutez d'abord la clé OpenRouter sur Railway !

#### Sur Railway :

1. Allez dans **Variables**
2. Ajoutez :
   ```
   OPENROUTER_API_KEY=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
   ```
3. Le service redémarrera (~30s)

#### Dans Flutter Admin :

1. Cliquez sur **"Upload PDF/Image"** (bouton orange)
2. Remplir :
   - **ID** : `pizzeria-test`
   - **Nom** : `Pizzeria Roma`
   - **Devise** : `EUR`
3. Sélectionner un PDF de menu
4. **Attendre le parsing** (~10-30s selon la taille)
5. ✅ Menu créé automatiquement avec variantes séparées !

---

## 📊 Structure du Menu Optimisé

### Avant :
```json
{
  "id": 9301,
  "name": "Coca / Fanta / Boga / Sprite",
  "price": 5,
  "type": "Boisson froide"
}
```

### Après :
```json
{
  "id": 10000,
  "name": "Coca",
  "price": 5,
  "type": "Boisson froide",
  "available": true
},
{
  "id": 10001,
  "name": "Fanta",
  "price": 5,
  "type": "Boisson froide",
  "available": true
},
{
  "id": 10002,
  "name": "Boga",
  "price": 5,
  "type": "Boisson froide",
  "available": true
},
{
  "id": 10003,
  "name": "Sprite",
  "price": 5,
  "type": "Boisson froide",
  "available": true
}
```

**Avantages** :
- ✅ Gestion individuelle de chaque variante
- ✅ Toggle disponibilité séparé
- ✅ Prix différenciés possibles
- ✅ Statistiques précises

---

## 🔧 Commandes Utiles

### Optimiser un autre menu
```bash
# Modifier optimize-menu.js pour pointer vers un autre restaurant
node optimize-menu.js
```

### Tester l'API localement
```bash
node test-railway-api.js
```

### Build APK Admin
```bash
cd flutter_les_emirs
flutter build apk --release --dart-define=INITIAL_ROUTE=/admin
# APK: build/app/outputs/flutter-apk/app-release.apk
```

### Restaurer le backup
```bash
cp data/restaurants/les-emirs/menu.backup.json data/restaurants/les-emirs/menu.json
```

---

## 📝 Notes Importantes

### 1. **Disponibilité vs Suppression**

- **Disponibilité** (👁️) : Masque temporairement l'article
  - ✅ Gardez les données (prix, stats)
  - ✅ Réactivez en 1 clic
  - ✅ Recommandé pour ruptures de stock

- **Suppression** (🗑️) : Efface définitivement
  - ❌ Données perdues
  - ❌ ID supprimé
  - ⚠️ À utiliser uniquement pour articles obsolètes

### 2. **Traductions Automatiques**

Quand vous modifiez un menu :
- Le cache DeepL est **vidé automatiquement**
- Les clients verront les nouvelles traductions à leur prochaine visite
- Pas besoin d'action manuelle

### 3. **IDs Auto**

- Articles existants : 1001-9999
- Nouveaux articles (script) : 10000+
- Articles créés via API : calculés automatiquement (max ID + 1)

### 4. **Parser PDF Intelligent**

Le parser DeepSeek détecte automatiquement :
- ✅ "Coca / Fanta" → 2 articles
- ✅ "Jus (Orange / Citron)" → "Jus Orange", "Jus Citron"
- ✅ Groupes (drinks, spirits, food)
- ✅ Types (Boisson froide, Entrée chaude, etc.)

---

## 🎯 Workflow Recommandé

### Gestion Quotidienne

**Matin** :
1. Ouvrir Admin Flutter
2. Vérifier disponibilités
3. Masquer items en rupture de stock

**Soir** :
1. Réactiver les items réapprovisionnés
2. Ajuster les prix si besoin
3. Vérifier les stats (Dashboard Staff)

### Changement de Carte

1. **Option A** : Modifier via l'interface
   - Ajouter/Supprimer manuellement
   - Modifier les catégories

2. **Option B** : Upload nouveau PDF
   - Créer un nouveau restaurant
   - Copier les prix ajustés
   - Basculer les clients

---

## 🔒 Sécurité

### Production

**OBLIGATOIRE** :
1. Changer `ADMIN_PASSWORD` (Railway Variables)
2. Utiliser un mot de passe fort (min 16 caractères)
3. Ne jamais partager la clé OpenRouter

**Recommandé** :
- Activer les logs Railway
- Surveiller les modifications menu
- Backup réguliers (automatiques via Git)

---

## 🆘 Troubleshooting

### "Erreur 401 Non autorisé"
→ Vérifier `ADMIN_PASSWORD` sur Railway

### "Upload PDF timeout"
→ PDF trop lourd (>10MB) ou trop de pages
→ Découper le PDF ou augmenter le timeout

### "Variantes non séparées"
→ Parser a peut-être mal compris
→ Éditer manuellement ou ajuster le prompt DeepSeek

### "Article masqué toujours visible"
→ Client a peut-être le cache
→ Attendre 1-2 min ou forcer le refresh (F5)

---

## 📞 Support

- **Documentation API** : `ADMIN_GUIDE.md`
- **Déploiement Railway** : `RAILWAY_SETUP.md`
- **Tests** : `test-railway-api.js`

---

**Créé avec ❤️ pour Les Emirs Port El Kantaoui**
**Optimisé pour gérer facilement les ruptures de stock et les variantes** 🎉

