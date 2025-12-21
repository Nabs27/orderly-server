@echo off
chcp 65001 >nul 2>&1
echo ========================================
echo 🔄 Serveur avec redémarrage automatique
echo ========================================
echo.
echo Ce script redémarre automatiquement le serveur après un reset.
echo Pour arrêter complètement, fermez cette fenêtre ou appuyez sur Ctrl+C.
echo.

:loop
echo [%date% %time%] Démarrage du serveur...
echo.

REM Démarrer le serveur Node.js
node server-new.js
EXIT_CODE=%ERRORLEVEL%

echo.
echo [%date% %time%] Serveur arrêté avec le code: %EXIT_CODE%

REM Vérifier si c'est un code de redémarrage (100)
if %EXIT_CODE% EQU 100 (
    echo.
    echo 🔄 Redémarrage automatique détecté (code 100)
    echo ⏳ Attente de 2 secondes avant le redémarrage...
    timeout /t 2 /nobreak >nul
    echo.
    echo ========================================
    echo 🔄 REDÉMARRAGE AUTOMATIQUE
    echo ========================================
    echo.
    goto loop
) else (
    echo.
    echo ⚠️ Arrêt du serveur (code: %EXIT_CODE%)
    echo Le serveur ne redémarrera pas automatiquement.
    echo.
    echo Appuyez sur une touche pour fermer cette fenêtre...
    pause >nul
    exit /b %EXIT_CODE%
)

