# 🚀 DÉPLOIEMENT RAILWAY AUTOMATIQUE

## ✅ Code poussé sur GitHub
Le code est maintenant sur : https://github.com/Nabs27/orderly-server.git

## 🚂 Créer le service Railway

### Option 1 : Via l'interface web (RECOMMANDÉ)
1. Allez sur [railway.app](https://railway.app)
2. Cliquez sur "New Project"
3. Sélectionnez "Deploy from GitHub repo"
4. Choisissez le repository `Nabs27/orderly-server`
5. Railway détectera automatiquement le `package.json` et déploiera

### Option 2 : Via CLI (si vous préférez)
```bash
npx @railway/cli login
npx @railway/cli init
npx @railway/cli up
```

## 🗄️ Configuration MongoDB Atlas

### Informations de connexion
- **Cluster** : restaurant-pos-backup
- **Username** : Pos_project
- **Connection String** : `mongodb+srv://Pos_project:yhk44KiqG6ZtGUmP@restaurant-pos-backup.njp7zfi.mongodb.net/?appName=restaurant-pos-backup`

### ⚠️ IMPORTANT : Autoriser Railway dans MongoDB Atlas

1. Allez dans **MongoDB Atlas** → **Network Access** (ou Security → Network Access)
2. Cliquez sur **"Add IP Address"**
3. Ajoutez : `0.0.0.0/0` (toutes les IP) - **Nécessaire pour Railway**
4. Cliquez sur **"Confirm"**

> **Note** : Votre IP locale (196.179.170.216) est déjà autorisée, mais Railway a besoin d'une IP différente. `0.0.0.0/0` autorise toutes les IP (sécurisé si vous utilisez un mot de passe fort).

## 🔧 Variables d'environnement à configurer

Dans Railway Dashboard → Votre service → Variables :

```bash
# === MONGODB (OBLIGATOIRE pour le mode cloud) ===
MONGODB_URI=mongodb+srv://Pos_project:yhk44KiqG6ZtGUmP@restaurant-pos-backup.njp7zfi.mongodb.net/?appName=restaurant-pos-backup
MONGODB_DB_NAME=restaurant_pos

# === VARIABLES PRINCIPALES ===
PORT=3000
ADMIN_TOKEN=admin123
RESTAURANT_ID=les-emirs

# === IA ET TRADUCTIONS ===
DEEPL_KEY=votre_cle_deepl:fx
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxx
ADMIN_PASSWORD=un_mot_de_passe_securise_unique

# === OPTIMISATIONS COÛTS ===
SOCKET_PING_INTERVAL=60000
SOCKET_PING_TIMEOUT=30000
NODE_ENV=production

# === OPTIONNEL ===
ALLOW_DEV_RESET=1
```

## 💰 Configuration Sleep Mode (économies)

Dans Railway Dashboard → Votre service → Settings → Sleep :
- ✅ **Enable Sleep After Inactivity** : `ON`
- ⏰ **Sleep Delay** : `5 minutes`

## 🔑 Récupérer les clés API

### DeepL (Traductions)
1. [deepl.com](https://www.deepl.com) → Compte gratuit
2. Account → API Keys → Copier la clé

### OpenRouter (IA DeepSeek)
1. [openrouter.ai](https://openrouter.ai) → Compte gratuit
2. Keys → Create Key → Copier la clé

## 🧪 Test du déploiement

Une fois déployé, votre URL sera : `https://votre-app.railway.app`

Testez avec :
```bash
curl https://votre-app.railway.app/api/pos/tables
```

## 📱 Configuration Flutter

Dans `flutter_les_emirs/.env` :
```bash
API_BASE_URL=https://votre-app.railway.app
```

## ✅ Fonctionnalités incluses

- Dashboard Admin avec parsing PDF/IA
- Système de crédit complet
- Paiements (complet, partiel, par note)
- Transferts (serveurs, tables, articles)
- Socket.IO temps réel
- Traductions automatiques
- Bouton de contrôle serveur cloud
- Optimisations de coûts Railway

## 💡 Économies attendues

- **Avant** : ~$20-30/mois (24/7)
- **Après** : ~$5-10/mois (sleep mode)
- **Économie** : ~70% de réduction

