# 📱 Guide d'Installation Manuelle - App Android

## 📍 Localisation de l'App Client

L'application client se trouve dans le dossier :
```
C:\Users\ngafs\Desktop\restau\flutter_les_emirs\
```

C'est une **application unique** qui contient à la fois :
- L'app **client** (pour les clients qui commandent)
- L'app **POS** (pour les serveurs)
- L'app **Admin/Dashboard**

L'application détecte automatiquement le mode selon la navigation.

---

## 🔧 Étape 1 : Préparer le téléphone

1. **Activer le mode développeur** :
   - Allez dans **Paramètres** → **À propos du téléphone**
   - Trouvez **"Numéro de build"** ou **"Version de build"**
   - **Appuyez 7 fois** dessus
   - Un message confirme que vous êtes développeur

2. **Activer le débogage USB** :
   - Allez dans **Paramètres** → **Options pour les développeurs**
   - Activez **"Débogage USB"**
   - Activez **"Installer via USB"** (si disponible)

3. **Autoriser l'installation depuis des sources inconnues** :
   - Allez dans **Paramètres** → **Sécurité**
   - Activez **"Sources inconnues"** ou **"Installer des applications inconnues"**

---

## 🏗️ Étape 2 : Construire l'APK

Ouvrez un terminal PowerShell dans le dossier du projet et exécutez :

```powershell
cd C:\Users\ngafs\Desktop\restau\flutter_les_emirs
flutter build apk --release
```

**Temps estimé** : 2-5 minutes

**Résultat** : L'APK sera créé dans :
```
flutter_les_emirs\build\app\outputs\flutter-apk\app-release.apk
```

---

## 📲 Étape 3 : Transférer l'APK sur le téléphone

### Option A : Via USB (Recommandé)

1. **Connectez le téléphone** à l'ordinateur avec un câble USB
2. Sur le téléphone, sélectionnez **"Transfert de fichiers"** ou **"MTP"** quand Windows demande
3. Ouvrez l'**Explorateur de fichiers** Windows
4. Dans **"Ce PC"**, vous devriez voir votre téléphone
5. Ouvrez le téléphone et allez dans le dossier **"Téléchargements"** ou **"Download"**
6. **Copiez** le fichier `app-release.apk` depuis :
   ```
   C:\Users\ngafs\Desktop\restau\flutter_les_emirs\build\app\outputs\flutter-apk\app-release.apk
   ```
7. **Collez** dans le dossier Téléchargements du téléphone

### Option B : Via Bluetooth ou Email

1. Envoyez le fichier `app-release.apk` par Bluetooth ou email
2. Téléchargez-le sur le téléphone

---

## 📥 Étape 4 : Installer l'APK sur le téléphone

1. Sur le téléphone, ouvrez l'**application Fichiers** ou **Gestionnaire de fichiers**
2. Allez dans **Téléchargements** ou **Download**
3. **Touchez** le fichier `app-release.apk`
4. Si un message de sécurité apparaît, appuyez sur **"Installer quand même"** ou **"OK"**
5. Attendez la fin de l'installation
6. Appuyez sur **"Ouvrir"** ou trouvez l'icône **"flutter_les_emirs"** dans le menu d'applications

---

## ✅ Étape 5 : Vérifier l'installation

1. L'app devrait s'ouvrir
2. Vous verrez l'écran d'accueil avec les options :
   - **Menu** (pour les clients)
   - **POS** (pour les serveurs)
   - **Admin** (pour les administrateurs)

---

## 🔄 Pour mettre à jour l'app plus tard

1. **Construisez un nouvel APK** :
   ```powershell
   cd C:\Users\ngafs\Desktop\restau\flutter_les_emirs
   flutter build apk --release
   ```

2. **Transférez et installez** comme à l'étape 3 et 4
   - L'ancienne version sera automatiquement remplacée

---

## ⚠️ Dépannage

### Erreur : "Application non installée"
- Vérifiez que **"Sources inconnues"** est activé
- Réessayez l'installation

### Erreur : "Application endommagée"
- Supprimez l'ancienne version si elle existe
- Reconstruisez l'APK et réinstallez

### Le téléphone ne se connecte pas en USB
- Vérifiez que le câble USB fonctionne
- Essayez un autre port USB
- Sur le téléphone, autorisez le débogage USB quand demandé

### L'APK n'apparaît pas dans les fichiers
- Vérifiez que le transfert est terminé
- Cherchez dans d'autres dossiers (Documents, Images, etc.)

---

## 📝 Notes

- **Taille de l'APK** : Environ 30-50 MB
- **Version** : L'app affichera la version dans les paramètres
- **Permissions** : L'app demandera l'accès à Internet (pour l'API)

---

**Bon courage ! 🚀**
















