# 📊 Application Dashboard Admin - Les Emirs

Application Flutter Android dédiée **uniquement aux patrons de restaurants** pour gérer leur établissement, consulter les rapports et les statistiques.

## 🎯 Fonctionnalités

- ✅ **Dashboard Admin** : Vue d'ensemble avec KPI (Chiffre d'affaires, remises, crédits, etc.)
- ✅ **Rapport X** : Génération et consultation des rapports X
- ✅ **Historique** : Consultation de l'historique des encaissements
- ✅ **Gestion des crédits** : Suivi des crédits clients
- ✅ **Gestion des serveurs** : Configuration des serveurs et permissions
- ✅ **Édition du menu** : Modification du menu du restaurant

## 🚀 Installation

### Prérequis

- Flutter SDK installé
- Android Studio ou VS Code avec extensions Flutter

### Configuration

1. **Le fichier `.env`** est déjà créé avec l'URL du serveur cloud :
   ```env
   API_BASE_URL=https://orderly-server-production.up.railway.app
   ```
   
   **Note** : L'application est configurée pour utiliser le serveur cloud par défaut, ce qui permet de l'utiliser depuis n'importe où dans le monde. Pour un développement local, vous pouvez modifier cette URL.

2. **Installer les dépendances** :
   ```bash
   cd flutter_admin_app
   flutter pub get
   ```

### Construire l'APK Android

```bash
flutter build apk --release
```

L'APK sera créé dans :
```
build/app/outputs/flutter-apk/app-release.apk
```

### Installer sur le téléphone

1. Transférez l'APK sur votre téléphone Android
2. Activez "Sources inconnues" dans les paramètres
3. Installez l'APK

## 📦 Structure

```
lib/
├── core/              # Services de base (API client)
├── features/
│   └── admin/         # Toutes les fonctionnalités admin
│       ├── admin_dashboard_page.dart
│       ├── admin_login_page.dart
│       ├── admin_credit_page.dart
│       ├── admin_servers_page.dart
│       ├── report_x_page.dart
│       ├── models/    # Modèles de données
│       ├── pages/     # Pages de détails (KPI, historique, etc.)
│       ├── services/  # Services API
│       └── widgets/   # Widgets réutilisables
└── main.dart          # Point d'entrée de l'application
```

## 🔧 Développement

```bash
# Installer les dépendances
flutter pub get

# Lancer en mode debug
flutter run

# Analyser le code
flutter analyze

# Construire pour Android
flutter build apk --release
```

## 📝 Notes

- Cette application est **uniquement pour les patrons/admin**
- Elle ne contient **pas** le POS ni l'app client
- L'application est légère et se concentre sur la gestion et les rapports
- Elle se connecte au même backend que le POS via l'API

## 🔐 Connexion

L'application démarre sur la page de connexion. Utilisez le mot de passe admin configuré dans le backend.
