#!/bin/bash

echo "========================================"
echo "🚀 Démarrage du serveur + POS Flutter"
echo "========================================"
echo ""

# Démarrer le serveur Node.js en arrière-plan
echo "[1/2] Démarrage du serveur Node.js..."
npm start &
SERVER_PID=$!

# Attendre que le serveur soit prêt
sleep 3

# Démarrer l'application Flutter
echo "[2/2] Démarrage de l'application Flutter (POS)..."
cd flutter_les_emirs
flutter run --dart-define=INITIAL_ROUTE=/pos &
FLUTTER_PID=$!

echo ""
echo "✅ Les deux services sont en cours de démarrage !"
echo ""
echo "📌 Pour arrêter:"
echo "   kill $SERVER_PID $FLUTTER_PID"
echo ""

# Attendre la fin des processus
wait

