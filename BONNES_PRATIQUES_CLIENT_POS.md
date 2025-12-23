# 📋 Bonnes Pratiques : Système Client → POS

## 🎯 Principes Fondamentaux

### 1. **Source de Vérité Unique**
- **Le POS est la source de vérité** pour les IDs de commandes
- Les commandes client n'ont **pas d'ID officiel** jusqu'à acceptation par le POS
- Utiliser des **IDs temporaires uniques** (`tempId`) pour les commandes client en attente

### 2. **États de Commande Clairs**
- `pending_server_confirmation` : Commande client en attente d'acceptation POS
- `nouvelle` : Commande acceptée par le POS (devient une commande POS normale)
- `declined` : Commande refusée par le POS
- `archived` : Commande terminée/payée

### 3. **Synchronisation Unidirectionnelle**
- **Client → Cloud** : Les commandes client sont créées sur le serveur cloud
- **Cloud → POS Local** : Le POS local synchronise les nouvelles commandes client depuis MongoDB
- **POS Local → Cloud** : Le POS local synchronise les confirmations/déclinaisons vers MongoDB
- **Ne JAMAIS écraser** les commandes POS locales (source de vérité)

## 🔄 Flux de Commande Standard

### Étape 1 : Création Commande Client
```
App Client → Serveur Cloud (MongoDB)
- Crée commande avec tempId unique
- Status: pending_server_confirmation
- Source: client
- ID: null
```

### Étape 2 : Synchronisation vers POS Local
```
Serveur Cloud (MongoDB) → POS Local
- POS local synchronise périodiquement depuis MongoDB
- Ajoute uniquement les nouvelles commandes client
- Vérifie que la commande n'existe pas déjà (par tempId)
```

### Étape 3 : Confirmation par le POS
```
POS Local → Serveur Cloud (MongoDB)
- POS assigne un ID officiel unique
- Supprime tempId
- Change source: 'pos', originalSource: 'client'
- Status: 'nouvelle'
- Supprime immédiatement l'ancienne entrée MongoDB avec tempId
```

### Étape 4 : Synchronisation Post-Confirmation
```
POS Local → Serveur Cloud (MongoDB)
- Synchronise la commande confirmée avec son nouvel ID
- La synchronisation périodique ignore les commandes déjà confirmées
```

## ✅ Vérifications Anti-Doublons

### Lors de la Synchronisation Périodique
1. ✅ Vérifier par `tempId` si la commande existe déjà localement
2. ✅ Vérifier si la commande a été confirmée (chercher `originalTempId` dans les commandes POS)
3. ✅ Vérifier le statut (`pending_server_confirmation` uniquement)
4. ✅ Vérifier si la commande est archivée localement
5. ✅ Ne jamais réintroduire une commande confirmée

### Lors de la Confirmation
1. ✅ Supprimer immédiatement l'ancienne entrée MongoDB avec `tempId`
2. ✅ Créer la nouvelle entrée avec l'ID officiel
3. ✅ Changer `source` de 'client' à 'pos'
4. ✅ Conserver `originalTempId` pour traçabilité

## 🗄️ Gestion MongoDB

### Index Partiels
```javascript
// Index unique partiel sur id (ignore les valeurs null)
{ id: 1 }, { unique: true, partialFilterExpression: { id: { $ne: null } } }

// Index unique partiel sur tempId (pour commandes client)
{ tempId: 1 }, { unique: true, partialFilterExpression: { tempId: { $ne: null } } }
```

### Clés de Recherche
- **Commandes avec ID** : Chercher par `{ id: order.id }`
- **Commandes client sans ID** : Chercher par `{ tempId: order.tempId }`
- **Commandes confirmées** : Supprimer l'ancienne entrée avec `tempId` avant d'insérer avec `id`

## 🚫 Erreurs à Éviter

1. ❌ **Ne pas utiliser `id: null` comme clé de recherche** (violation index unique)
2. ❌ **Ne pas réintroduire les commandes confirmées** depuis MongoDB
3. ❌ **Ne pas écraser les commandes POS locales** lors de la synchronisation
4. ❌ **Ne pas archiver les commandes en attente** (`pending_server_confirmation`)
5. ❌ **Ne pas permettre plusieurs confirmations** de la même commande

## 🔍 Logs et Debugging

### Logs Importants
- `[orders] 🆕 Commande CLIENT créée` : Création commande client
- `[orders] ✅ Commande client confirmée` : Confirmation par POS
- `[sync] 🗑️ Ancienne commande avec tempId supprimée` : Suppression ancienne entrée
- `[sync] ⏭️ Commande client ignorée: déjà confirmée` : Prévention doublon

### Vérifications de Debug
- Vérifier que `tempId` est unique pour chaque commande client
- Vérifier que les commandes confirmées ont `source: 'pos'` et `originalSource: 'client'`
- Vérifier que MongoDB ne contient pas d'anciennes entrées avec `tempId` après confirmation

## 📊 Exemple de Structure

### Commande Client (Avant Confirmation)
```json
{
  "id": null,
  "tempId": "temp_1766502635339_y6fhry9q4",
  "table": "2",
  "source": "client",
  "status": "pending_server_confirmation",
  "serverConfirmed": false
}
```

### Commande Confirmée (Après Acceptation POS)
```json
{
  "id": 5,
  "originalTempId": "temp_1766502635339_y6fhry9q4",
  "table": "2",
  "source": "pos",
  "originalSource": "client",
  "status": "nouvelle",
  "serverConfirmed": true,
  "confirmedAt": "2024-01-20T10:30:00.000Z"
}
```

## 🎓 Références

- [MongoDB Partial Indexes](https://www.mongodb.com/docs/manual/core/index-partial/)
- [Restaurant POS Best Practices](https://www.szzcs.com/fr/News/what-are-the-top-features-of-modern-android-pos-systems.html)
- [Mobile Ordering Integration](https://starmicronics.com/fr/blog/application-de-commande-mobile-avantages-pour-le-restaurant/)

