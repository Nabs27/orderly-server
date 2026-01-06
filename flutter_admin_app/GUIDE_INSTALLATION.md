# 📱 Guide d'Installation - Application Dashboard Admin

## 🚀 Installation Rapide

### 1. Prérequis

- Flutter SDK installé (version 3.9.2 ou supérieure)
- Android Studio ou VS Code avec extensions Flutter
- Un téléphone Android ou un émulateur

### 2. Configuration

1. **Le fichier `.env`** est déjà créé avec l'URL du serveur cloud :
   ```env
   API_BASE_URL=https://orderly-server-production.up.railway.app
   ```
   
   **Note** : L'application est configurée pour utiliser le serveur cloud par défaut, ce qui permet de l'utiliser depuis n'importe où dans le monde. Pour un développement local, vous pouvez modifier cette URL vers `http://localhost:3000`.

2. **Installer les dépendances** :
   ```bash
   cd flutter_admin_app
   flutter pub get
   ```

### 3. Construire l'APK Android

```bash
flutter build apk --release
```

L'APK sera créé dans :
```
build/app/outputs/flutter-apk/app-release.apk
```

### 4. Installer sur le téléphone

1. Transférez l'APK sur votre téléphone Android (via USB, email, etc.)
2. Activez "Sources inconnues" dans les paramètres Android :
   - Paramètres → Sécurité → Sources inconnues
3. Ouvrez l'APK et installez-le

## 🔧 Développement

### Lancer en mode debug

```bash
flutter run
```

### Analyser le code

```bash
flutter analyze
```

### Nettoyer le build

```bash
flutter clean
flutter pub get
```

## 📝 Notes Importantes

- Cette application est **indépendante** du POS principal
- Elle se connecte au **même backend** via l'API
- L'application est **légère** et contient uniquement les fonctionnalités admin
- Le mot de passe admin est configuré dans le backend

## 🐛 Dépannage

### Erreur : "Fichier .env non trouvé"
- Créez le fichier `.env` à la racine de `flutter_admin_app/`
- Vérifiez que le fichier contient `API_BASE_URL=...`

### Erreur : "Connection refused"
- Vérifiez que le serveur cloud est accessible
- Vérifiez l'URL dans le fichier `.env` (doit être `https://orderly-server-production.up.railway.app`)
- Vérifiez votre connexion Internet

### Erreur de build Android
- Vérifiez que vous avez installé Android SDK
- Exécutez `flutter doctor` pour vérifier la configuration


