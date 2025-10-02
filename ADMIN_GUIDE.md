# 🔐 Guide Dashboard Admin — Orderly

## 📌 Vue d'ensemble

Le **Dashboard Admin** permet de gérer les restaurants et leurs menus :
- **CRUD complet** : Créer/Modifier/Supprimer restaurants, catégories et articles
- **Upload PDF/Image** : Parsing automatique via DeepSeek V3.1 (IA)
- **Gestion disponibilité** : Activer/Désactiver des articles en temps réel
- **Multi-restaurant** : Support de plusieurs établissements

---

## 🚀 Installation

### 1. Backend (Node.js)

```bash
# Installer les nouvelles dépendances
npm install

# Créer un fichier .env à la racine du projet
DEEPL_KEY=votre_cle_deepl:fx
OPENROUTER_API_KEY=sk-or-v1-xxxxx  # Clé OpenRouter pour DeepSeek
ADMIN_PASSWORD=votre_mot_de_passe_securise
```

**Obtenir les clés API :**
- **DeepL** : https://www.deepl.com/pro-api (gratuit 500K chars/mois)
- **OpenRouter** : https://openrouter.ai/ (DeepSeek V3.1 est GRATUIT !)

### 2. Flutter Admin

```bash
cd flutter_les_emirs
flutter pub get

# Tester en mode web
flutter run -d chrome --dart-define=INITIAL_ROUTE=/admin

# Build APK Android
flutter build apk --release --dart-define=INITIAL_ROUTE=/admin --target-platform android-arm64
# L'APK sera dans: build/app/outputs/flutter-apk/app-release.apk
```

---

## 📱 Utilisation

### Lancer le serveur

```bash
npm run dev  # Mode développement avec nodemon
# OU
npm start    # Mode production
```

### Accéder au Dashboard Admin

**Option 1 : Flutter App (Recommandé pour tablette)**
1. Build APK avec `--dart-define=INITIAL_ROUTE=/admin`
2. Installer l'APK sur tablette
3. Se connecter avec le mot de passe admin

**Option 2 : Flutter Web**
```bash
flutter run -d chrome --dart-define=INITIAL_ROUTE=/admin
```

---

## 🎯 Fonctionnalités

### 1. Créer un Restaurant Manuellement

1. Cliquer sur **"Nouveau Restaurant"** (FAB bleu)
2. Remplir :
   - **ID** : identifiant unique (ex: `pizzeria-roma`)
   - **Nom** : nom affiché (ex: `Pizzeria Roma`)
   - **Devise** : code devise (ex: `EUR`, `TND`)
3. Cliquer "Créer"

### 2. Upload PDF/Image (Parsing IA)

1. Cliquer sur **"Upload PDF/Image"** (FAB orange)
2. Remplir les infos du restaurant
3. Sélectionner un fichier :
   - **PDF** : Menu PDF (recommandé, meilleure extraction)
   - **Images** : JPG/PNG (nécessite OCR - à implémenter)
4. L'IA DeepSeek parse automatiquement le menu
5. Le menu est créé et prêt à éditer

**Formats supportés :**
- ✅ PDF (testé et fonctionnel)
- ⚠️ Images (nécessite Tesseract.js ou Google Vision API)

### 3. Éditer un Menu

1. Cliquer sur un restaurant dans la liste
2. **Ajouter une catégorie** :
   - Cliquer sur le FAB "Ajouter Catégorie"
   - Choisir le groupe : `food`, `drinks`, ou `spirits`
3. **Ajouter un article** :
   - Cliquer sur "+" à côté d'une catégorie
   - Remplir : Nom, Prix, Type
4. **Modifier un article** :
   - Cliquer sur l'icône "Éditer" (crayon)
   - Modifier les champs
   - **Toggle "Disponible"** pour masquer/afficher dans le menu client
5. **Supprimer** : Icône poubelle rouge

---

## 🔧 API Admin (Routes)

### Authentification

```bash
POST /api/admin/login
Body: { "password": "admin123" }
Response: { "token": "admin123", "ok": true }

# Toutes les routes admin nécessitent le header:
x-admin-token: <token>
```

### Gestion Restaurants

```bash
GET    /api/admin/restaurants          # Liste
POST   /api/admin/restaurants          # Créer
Body: { "id": "les-emirs", "name": "Les Emirs", "currency": "TND" }
```

### Gestion Menu

```bash
GET    /api/admin/menu/:restaurantId                    # Lire menu
PATCH  /api/admin/menu/:restaurantId                    # Sauvegarder tout le menu
POST   /api/admin/menu/:restaurantId/categories         # Ajouter catégorie
DELETE /api/admin/menu/:restaurantId/categories/:name   # Supprimer catégorie
POST   /api/admin/menu/:restaurantId/items              # Ajouter article
PATCH  /api/admin/menu/:restaurantId/items/:id          # Modifier article
DELETE /api/admin/menu/:restaurantId/items/:id          # Supprimer article
```

### Upload & Parsing

```bash
POST /api/admin/parse-menu
Content-Type: multipart/form-data
Fields:
  - file: <PDF/Image>
  - restaurantId: "pizzeria-roma"
  - restaurantName: "Pizzeria Roma"
  - currency: "EUR"
```

---

## 📐 Structure JSON du Menu

```json
{
  "restaurant": {
    "id": "les-emirs",
    "name": "Les Emirs",
    "currency": "TND"
  },
  "categories": [
    {
      "name": "Entrées froides",
      "group": "food",
      "items": [
        {
          "id": 1001,
          "name": "Salade Méchouia",
          "price": 16,
          "type": "Entrée froide",
          "available": true
        }
      ]
    }
  ]
}
```

**Champs obligatoires :**
- `id` : numérique unique (auto-généré si ajout via API)
- `name` : nom de l'article
- `price` : prix (number)
- `type` : sous-catégorie
- `available` : true/false (si false, caché dans menu client)

---

## 🎨 Build APK Séparés

### App Client (Menu)
```bash
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

### App Dashboard Staff (Cuisine/Bar)
```bash
flutter build apk --release --dart-define=INITIAL_ROUTE=/dashboard
# Renommer: dashboard-staff.apk
```

### App Admin (Gestion Menu)
```bash
flutter build apk --release --dart-define=INITIAL_ROUTE=/admin
# Renommer: admin.apk
```

---

## 🐛 Troubleshooting

### Erreur 401 "Non autorisé"
- Vérifier que `ADMIN_PASSWORD` est défini dans `.env`
- Vérifier le header `x-admin-token` dans les requêtes

### PDF ne parse pas correctement
- Le PDF doit contenir du texte extractible (pas une image scannée)
- Vérifier que `OPENROUTER_API_KEY` est valide

### Items ne disparaissent pas du menu client
- Vérifier que `available: false` est bien enregistré
- Le filtre s'applique côté serveur dans `filterAvailableItems()`

### Traductions ne se mettent pas à jour
- Les traductions sont cachées (performance)
- Modifier un menu vide automatiquement le cache

---

## 📝 TODO / Améliorations Futures

- [ ] OCR images (Tesseract.js ou Google Vision API)
- [ ] Drag & drop pour réorganiser catégories/items
- [ ] Upload logo restaurant
- [ ] Export menu en PDF
- [ ] Analytics (articles les plus vendus)
- [ ] Multi-utilisateurs admin (rôles)
- [ ] Historique des modifications

---

## 🔒 Sécurité Production

**IMPORTANT :** Avant de déployer en production :

1. **Changer le mot de passe admin** :
   ```bash
   ADMIN_PASSWORD=un_mot_de_passe_tres_securise
   ```

2. **Utiliser HTTPS** (obligatoire pour production)

3. **Rate limiting** (ajouter express-rate-limit)

4. **Validation stricte** des uploads (taille, type MIME)

---

## 💡 Support

Pour toute question, contactez l'équipe de développement.

**Créé avec ❤️ pour Les Emirs Port El Kantaoui**

