@echo off
echo ========================================
echo 🚀 Démarrage du serveur + POS Flutter
echo ========================================
echo.

REM Démarrer le serveur Node.js en arrière-plan
echo [1/2] Démarrage du serveur Node.js...
start "Serveur REST" cmd /k "npm start"
timeout /t 3 /nobreak >nul

REM Attendre que le serveur soit prêt
echo [2/2] Démarrage de l'application Flutter (POS)...
REM 🆕 Utiliser -d windows pour lancer automatiquement sur Windows sans demander de choix
start "POS Flutter" cmd /k "cd flutter_les_emirs && flutter run -d windows --dart-define=INITIAL_ROUTE=/pos"

echo.
echo ✅ Les deux services sont en cours de démarrage !
echo.
echo 📌 Pour arrêter:
echo    - Fermez les fenêtres de commande
echo    - Ou utilisez Ctrl+C dans chaque fenêtre
echo.
pause

