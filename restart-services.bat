@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
echo ========================================
echo Redemarrage du serveur + POS Flutter
echo ========================================
echo.

REM Arreter les processus existants
echo [1/4] Arret des processus existants...

REM CRITIQUE : Attendre un peu pour que le script batch se detache du processus Node.js parent
echo   - Attente de 2 secondes pour permettre au script de se detacher...
timeout /t 2 /nobreak >nul

REM Arreter Node.js (serveur) - tous les processus EN PREMIER
REM Cela va aussi fermer les fenetres cmd qui executent npm start
echo Arret des processus Node.js...
for /f "tokens=2" %%a in ('tasklist /FI "IMAGENAME eq node.exe" /FO LIST 2^>nul ^| findstr /C:"PID:"') do (
    echo   - Arret du processus Node.js PID: %%a
    taskkill /PID %%a /T /F >nul 2>&1
)

REM Arreter les processus Dart (Flutter run) - CRITIQUE pour flutter run
REM Cela va aussi fermer les fenetres cmd qui executent flutter run
echo Arret des processus Dart (Flutter run)...
for /f "tokens=2" %%a in ('tasklist /FI "IMAGENAME eq dart.exe" /FO LIST 2^>nul ^| findstr /C:"PID:"') do (
    echo   - Arret du processus Dart PID: %%a
    taskkill /PID %%a /T /F >nul 2>&1
)

REM Arreter Flutter (si processus separe existe)
echo Arret des processus Flutter...
for /f "tokens=2" %%a in ('tasklist /FI "IMAGENAME eq flutter.exe" /FO LIST 2^>nul ^| findstr /C:"PID:"') do (
    echo   - Arret du processus Flutter PID: %%a
    taskkill /PID %%a /T /F >nul 2>&1
)

REM Arreter le processus .exe Flutter Windows (flutter_les_emirs.exe) si present
echo Arret du processus Flutter .exe (si present)...
for /f "tokens=2" %%a in ('tasklist /FI "IMAGENAME eq flutter_les_emirs.exe" /FO LIST 2^>nul ^| findstr /C:"PID:"') do (
    echo   - Arret du processus flutter_les_emirs.exe PID: %%a
    taskkill /PID %%a /T /F >nul 2>&1
)

REM Attendre que les processus se terminent
timeout /t 2 /nobreak >nul

REM Maintenant fermer les fenetres cmd restantes avec les titres specifiques
echo Arret des fenetres cmd restantes "Serveur REST" et "POS Flutter"...
REM Essayer plusieurs fois pour etre sur de tout fermer
for /L %%i in (1,1,5) do (
    taskkill /FI "WINDOWTITLE eq Serveur REST*" /T /F >nul 2>&1
    if %errorlevel% == 0 echo   OK Fenetre "Serveur REST" fermee (tentative %%i)
    taskkill /FI "WINDOWTITLE eq POS Flutter*" /T /F >nul 2>&1
    if %errorlevel% == 0 echo   OK Fenetre "POS Flutter" fermee (tentative %%i)
    timeout /t 1 /nobreak >nul
)

REM Arreter les processus Chrome/Edge qui pourraient etre lies a Flutter Web (si utilise)
echo Verification des ports utilises...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":49723" ^| findstr "LISTENING"') do (
    echo   - Arret du processus utilisant le port 49723 (PID: %%a)
    taskkill /PID %%a /T /F >nul 2>&1
)

timeout /t 2 /nobreak >nul

REM Attendre un peu pour que les processus se terminent
echo [2/4] Attente de la liberation des ports...
timeout /t 3 /nobreak >nul

REM Verifier que les ports sont libres
echo [3/4] Verification de la liberation des ports...
:check_ports
netstat -ano | findstr ":3000" | findstr "LISTENING" >nul
if %errorlevel% == 0 (
    echo   - Port 3000 encore utilise, attente supplementaire...
    timeout /t 2 /nobreak >nul
    goto check_ports
)

REM Redemarrer les services
echo [4/4] Redemarrage des services...

REM Obtenir le repertoire courant du script (racine du projet)
pushd "%~dp0"
set "SCRIPT_DIR=%CD%"
popd
REM Enlever le dernier backslash si present
if "%SCRIPT_DIR:~-1%"=="\" (
    set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
)
cd /d "%SCRIPT_DIR%"
echo   Repertoire de travail: %SCRIPT_DIR%
echo   Verification de l'existence du repertoire...
if not exist "%SCRIPT_DIR%\package.json" (
    echo   ATTENTION: package.json introuvable dans %SCRIPT_DIR%
) else (
    echo   OK package.json trouve
)
if not exist "%SCRIPT_DIR%\flutter_les_emirs" (
    echo   ATTENTION: flutter_les_emirs introuvable dans %SCRIPT_DIR%
) else (
    echo   OK flutter_les_emirs trouve
)
echo.

echo   - Demarrage du serveur Node.js...
call start "Serveur REST" cmd /k "cd /d %SCRIPT_DIR% && echo [Serveur REST] Demarrage... && npm start"
if %errorlevel% == 0 (
    echo   OK Commande de demarrage du serveur Node.js envoyee
) else (
    echo   ERREUR lors de l'envoi de la commande (code: %errorlevel%)
)

echo   - Attente de 3 secondes...
timeout /t 3 /nobreak >nul

echo   - Demarrage du POS Flutter...
set "FLUTTER_DIR=%SCRIPT_DIR%\flutter_les_emirs"
call start "POS Flutter" cmd /k "cd /d %FLUTTER_DIR% && echo [POS Flutter] Demarrage... && flutter run -d windows --dart-define=INITIAL_ROUTE=/pos"
if !errorlevel! == 0 (
    echo   OK Commande de demarrage du POS Flutter envoyee
) else (
    echo   ERREUR lors de l'envoi de la commande (code: !errorlevel!)
)

echo.
echo Redemarrage termine !
echo.
echo IMPORTANT :
echo   1. Le serveur Node.js devrait demarrer dans une nouvelle fenetre "Serveur REST"
echo   2. Le POS Flutter devrait demarrer dans une nouvelle fenetre "POS Flutter"
echo   3. L'application Flutter va se fermer et se rouvrir automatiquement
echo   4. Attendez 10-15 secondes que les services redemarrent
echo   5. Verifiez que les fenetres "Serveur REST" et "POS Flutter" sont bien ouvertes
echo.
echo Verification que les services ont demarre...
echo   (Les fenetres peuvent prendre 10-15 secondes a s'ouvrir...)
timeout /t 10 /nobreak >nul

REM Verifier si les fenetres sont ouvertes (plusieurs tentatives)
set "SERVEUR_DETECTE=0"
set "FLUTTER_DETECTE=0"

REM Essayer plusieurs fois car les fenetres peuvent prendre du temps a s'ouvrir
for /L %%i in (1,1,3) do (
    echo   Tentative %%i/3 de detection des fenetres...
    tasklist /FI "WINDOWTITLE eq Serveur REST*" 2>nul | findstr /C:"cmd.exe" >nul
    if %errorlevel% == 0 (
        set "SERVEUR_DETECTE=1"
        echo   OK Fenetre "Serveur REST" detectee
        goto :serveur_ok
    )
    timeout /t 2 /nobreak >nul
)
:serveur_ok

for /L %%i in (1,1,3) do (
    tasklist /FI "WINDOWTITLE eq POS Flutter*" 2>nul | findstr /C:"cmd.exe" >nul
    if %errorlevel% == 0 (
        set "FLUTTER_DETECTE=1"
        echo   OK Fenetre "POS Flutter" detectee
        goto :flutter_ok
    )
    timeout /t 2 /nobreak >nul
)
:flutter_ok

if !SERVEUR_DETECTE! == 0 (
    echo   ATTENTION Fenetre "Serveur REST" non detectee - verifiez manuellement
)
if !FLUTTER_DETECTE! == 0 (
    echo   ATTENTION Fenetre "POS Flutter" non detectee - verifiez manuellement
)

echo.
echo ========================================
echo Redemarrage termine !
echo ========================================
echo.
echo Cette fenetre va rester ouverte pour que vous puissiez voir les logs.
echo Fermez-la manuellement quand vous avez termine.
echo.
echo Les fenetres "Serveur REST" et "POS Flutter" devraient etre ouvertes.
echo Si elles ne le sont pas, verifiez les messages ci-dessus.
echo.
echo Appuyez sur une touche pour fermer cette fenetre...
pause
endlocal
