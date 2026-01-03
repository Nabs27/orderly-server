# 📱 Application Client - Les Emirs

Application Flutter dédiée uniquement aux **clients** pour commander en ligne.

## 🎯 Fonctionnalités

- ✅ **Menu** : Parcourir le menu du restaurant
- ✅ **Panier** : Ajouter des articles et gérer la commande
- ✅ **Confirmation** : Valider et suivre les commandes
- ✅ **Historique** : Voir l'historique des commandes par table
- ✅ **Facture** : Consulter les factures

## 🚀 Installation

### Prérequis

- Flutter SDK installé
- Android Studio ou VS Code avec extensions Flutter

### Configuration

1. **Copier le fichier `.env`** :
   ```bash
   cp .env.example .env
   ```

2. **Configurer l'URL de l'API** dans `.env` :
   ```env
   API_BASE_URL=http://localhost:3000
   # Ou pour le serveur cloud :
   # API_BASE_URL=https://orderly-server-production.up.railway.app
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
├── core/              # Services de base (API, panier, traductions)
├── features/
│   ├── menu/         # Page menu
│   ├── cart/         # Page panier
│   ├── confirm/      # Page confirmation de commande
│   ├── history/      # Page historique
│   ├── bill/         # Page facture
│   └── welcome/      # Page d'accueil (sélection langue)
└── main.dart         # Point d'entrée de l'application
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

- Cette application est **uniquement pour les clients**
- Elle ne contient **pas** le POS ni l'Admin
- L'application est plus légère et plus simple que l'app complète
