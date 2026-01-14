# 🔑 Configuration SERVER_IDENTIFIER - Anti-doublons MongoDB

## 🎯 Problème résolu
Évite les articles fantômes (salade + carpaccio) causés par des données mélangées entre serveurs.

## ⚙️ Configuration requise

### Serveur Local
Dans votre fichier `.env` local :
```bash
SERVER_IDENTIFIER=local-pos-les-emirs
```

### Serveur Cloud
Dans votre fichier `.env` cloud :
```bash
SERVER_IDENTIFIER=cloud-pos-les-emirs
```

## 🔧 Comment ça marche

1. **Sauvegarde** : Chaque serveur tag ses données avec son `SERVER_IDENTIFIER`
2. **Chargement** : Chaque serveur ne lit que ses propres données
3. **Upsert** : `updateOne` avec `upsert: true` garantit UNE SEULE entrée par commande

## 📁 Structure MongoDB après correction

```
orders/
├── { id: 7, serverIdentifier: "local-pos-les-emirs", ... }
├── { id: 8, serverIdentifier: "local-pos-les-emirs", ... }
└── { id: 9, serverIdentifier: "cloud-pos-les-emirs", ... }

archivedOrders/
├── { id: 7, serverIdentifier: "local-pos-les-emirs", ... }
└── { id: 8, serverIdentifier: "cloud-pos-les-emirs", ... }
```

## ✅ Résultat

- ❌ **Plus de salade/carpaccio fantômes**
- ✅ **Données séparées par serveur**
- ✅ **Pas de mélange Local ↔ Cloud**

## 🚀 Déploiement

1. Ajouter `SERVER_IDENTIFIER` dans vos variables d'environnement
2. Redémarrer les serveurs
3. La synchronisation se fera automatiquement avec les nouvelles données