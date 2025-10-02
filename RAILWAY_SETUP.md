# 🚂 Déploiement Railway — Dashboard Admin

## Variables d'environnement à configurer

Sur Railway, allez dans votre service → Variables et ajoutez :

```bash
# Clé DeepL pour traductions (FR → EN/DE/AR)
DEEPL_KEY=votre_cle_deepl:fx

# Clé OpenRouter pour DeepSeek (parsing PDF → JSON)
# Gratuit ! Créez un compte sur https://openrouter.ai/
OPENROUTER_API_KEY=sk-or-v1-xxxxxxxxxxxxx

# Mot de passe admin (IMPORTANT : changez-le !)
ADMIN_PASSWORD=un_mot_de_passe_securise_unique

# Optionnel : autoriser reset en production (pour tests)
ALLOW_DEV_RESET=1

# Optionnel : port (Railway le définit automatiquement)
PORT=3000
```

## Étapes de déploiement

### 1. Commit et push

```bash
git add .
git commit -m "feat: dashboard admin avec parsing PDF/IA"
git push origin main
```

### 2. Railway auto-deploy

Railway détectera automatiquement :
- `package.json` → Build Node.js
- `npm start` → Commande de lancement

### 3. Tester l'API

```bash
# Remplacez YOUR-RAILWAY-URL par votre URL Railway
curl -X POST https://YOUR-RAILWAY-URL.up.railway.app/api/admin/login \
  -H "Content-Type: application/json" \
  -d '{"password":"votre_mot_de_passe"}'

# Si succès : {"token":"...","ok":true}
```

### 4. Configurer Flutter pour utiliser Railway

Dans `flutter_les_emirs/.env` :

```bash
API_BASE_URL=https://YOUR-RAILWAY-URL.up.railway.app
```

## 🔒 Sécurité

**IMPORTANT :** Railway est public par défaut !

1. **Ne jamais commit .env** (déjà dans `.gitignore`)
2. **Utiliser un mot de passe fort** pour `ADMIN_PASSWORD`
3. **Activer HTTPS** (Railway le fait automatiquement)
4. Considérer un rate limiter (ajouter `express-rate-limit`)

## 🐛 Troubleshooting

### Erreur 502 Bad Gateway
- Vérifier que `PORT` est lu depuis `process.env.PORT`
- Railway assigne un port dynamique

### Upload PDF timeout
- Railway a une limite de 500MB et timeout de 100s
- Pour gros PDF, augmenter `multer` limits ou découper

### DeepSeek rate limit
- OpenRouter free tier : ~20 requêtes/min
- Si dépassé, attendre ou upgrade plan

### Traductions ne fonctionnent pas
- Vérifier `DEEPL_KEY` est correcte
- Free plan DeepL : 500,000 chars/mois

## 📊 Monitoring

Railway fournit :
- Logs en temps réel
- Métriques CPU/RAM
- Alertes

Accédez via : Dashboard → Service → Metrics

---

**Besoin d'aide ?** Consultez : https://docs.railway.app/

