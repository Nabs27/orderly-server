# 📱 Guide d'Installation - App Client Android

## ✅ Application créée avec succès !

L'application client séparée a été créée dans :
```
C:\Users\ngafs\Desktop\restau\flutter_client_app\
```

---

## 🏗️ Étape 1 : Construire l'APK

Ouvrez PowerShell dans le dossier du projet :

```powershell
cd C:\Users\ngafs\Desktop\restau\flutter_client_app
flutter build apk --release
```

**Temps estimé** : 2-5 minutes

**Résultat** : L'APK sera créé dans :
```
flutter_client_app\build\app\outputs\flutter-apk\app-release.apk
```

---

## 📲 Étape 2 : Préparer le téléphone

1. **Activer le mode développeur** :
   - Paramètres → À propos → Appuyez 7 fois sur "Numéro de build"

2. **Activer le débogage USB** :
   - Paramètres → Options pour les développeurs → Activez "Débogage USB"

3. **Autoriser l'installation depuis des sources inconnues** :
   - Paramètres → Sécurité → Activez "Sources inconnues"

---

## 📥 Étape 3 : Transférer l'APK

### Option A : Via USB (Recommandé)

1. Connectez le téléphone à l'ordinateur avec un câble USB
2. Sur le téléphone, sélectionnez **"Transfert de fichiers"**
3. Ouvrez l'**Explorateur de fichiers** Windows
4. Dans **"Ce PC"**, ouvrez votre téléphone
5. Allez dans **"Téléchargements"** ou **"Download"**
6. **Copiez** le fichier `app-release.apk` depuis :
   ```
   C:\Users\ngafs\Desktop\restau\flutter_client_app\build\app\outputs\flutter-apk\app-release.apk
   ```
7. **Collez** dans le dossier Téléchargements du téléphone

### Option B : Via Bluetooth ou Email

Envoyez le fichier `app-release.apk` par Bluetooth ou email et téléchargez-le sur le téléphone.

---

## 📱 Étape 4 : Installer l'APK

1. Sur le téléphone, ouvrez l'**application Fichiers**
2. Allez dans **Téléchargements**
3. **Touchez** le fichier `app-release.apk`
4. Si un message de sécurité apparaît, appuyez sur **"Installer quand même"**
5. Attendez la fin de l'installation
6. Appuyez sur **"Ouvrir"** ou trouvez l'icône **"flutter_client_app"** dans le menu

---

## ⚙️ Configuration de l'API

Par défaut, l'app se connecte à `http://localhost:3000`.

Pour utiliser le serveur cloud Railway, modifiez le fichier `.env` :

```env
API_BASE_URL=https://orderly-server-production.up.railway.app
```

Puis reconstruisez l'APK :
```powershell
flutter build apk --release
```

---

## ✅ Vérification

Une fois installée, l'app devrait afficher :
- **Page d'accueil** avec sélection de langue
- **Menu** du restaurant
- **Panier** pour gérer les commandes
- **Confirmation** de commande
- **Historique** des commandes

---

## 🔄 Mise à jour

Pour mettre à jour l'app :

1. Reconstruisez l'APK :
   ```powershell
   flutter build apk --release
   ```

2. Transférez et installez le nouvel APK
   - L'ancienne version sera automatiquement remplacée

---

## 📝 Notes

- **Taille de l'APK** : Environ 25-35 MB (plus léger que l'app complète)
- **Version** : 1.0.0+1
- **Permissions** : Internet (pour l'API)

---

**L'application client est prête ! 🚀**










