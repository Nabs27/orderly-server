# 📱 Comment changer l'icône de l'app Dashboard

## Option 1 : Utiliser flutter_launcher_icons (Recommandé)

1. **Créer une icône** :
   - Créez une image PNG de 1024x1024 pixels
   - Nommez-la `dashboard_icon.png`
   - Placez-la dans `flutter_admin_app/assets/icon/`

2. **Générer les icônes** :
   ```bash
   cd flutter_admin_app
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

3. **Recompiler l'APK** :
   ```bash
   flutter build apk --release
   ```

## Option 2 : Remplacer manuellement les icônes

Remplacez les fichiers dans :
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (72x72)
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (48x48)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (96x96)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (144x144)
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192x192)

## Suggestion d'icône

Pour une icône Dashboard, vous pouvez utiliser :
- 📊 Un graphique/tableau de bord
- 📈 Une courbe statistique
- 🎛️ Un panneau de contrôle
- 📱 Un écran avec des graphiques

Vous pouvez créer l'icône avec :
- [Canva](https://www.canva.com) (gratuit, templates d'icônes)
- [Figma](https://www.figma.com) (gratuit, design vectoriel)
- [IconKitchen](https://icon.kitchen/) (générateur d'icônes adaptatives)

