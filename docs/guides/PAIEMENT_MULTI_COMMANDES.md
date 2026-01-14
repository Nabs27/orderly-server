# 🎯 Paiement Multi-Commandes

## 📋 Description

Système permettant de payer des **articles de plusieurs commandes différentes** en une **seule transaction**.

**Exemple d'usage** :
- Commande #1 : 2 Celtia + 1 Eau
- Commande #2 : 1 Poulet
- Commande #3 : 1 Filet de Bœuf

Le client veut payer uniquement : **1 Celtia (#1) + 1 Poulet (#2)**

## 🆕 Nouveau Endpoint

### `POST /api/pos/pay-multi-orders`

Payer des articles de plusieurs commandes en une seule transaction.

#### **Body** :
```json
{
  "table": "6",
  "paymentMode": "ESPECE",
  "items": [
    {
      "orderId": 1,
      "noteId": "main",
      "items": [
        { "id": 9501, "name": "Celtia", "price": 6.8, "quantity": 1 }
      ]
    },
    {
      "orderId": 2,
      "noteId": "main",
      "items": [
        { "id": 1404, "name": "Poulet Bebère au Romarin", "price": 33, "quantity": 1 }
      ]
    }
  ]
}
```

#### **Réponse** :
```json
{
  "ok": true,
  "totalPaid": 39.8,
  "processedOrders": 2,
  "archivedOrders": [],
  "details": [
    {
      "orderId": 1,
      "noteId": "main",
      "items": 1,
      "amount": 6.8
    },
    {
      "orderId": 2,
      "noteId": "main",
      "items": 1,
      "amount": 33
    }
  ]
}
```

## ✅ Fonctionnalités

1. **Paiement partiel** : Payer uniquement certains articles de certaines commandes
2. **Historique complet** : Chaque commande enregistre son propre historique de paiement
3. **Archivage automatique** : Les commandes vides sont automatiquement archivées
4. **Temps réel** : Événements Socket.IO émis pour synchronisation
5. **Traçabilité** : Chaque paiement est enregistré avec timestamp et mode de paiement

## 🔄 Événements Socket.IO

- `order:updated` : Pour chaque commande mise à jour
- `order:archived` : Pour chaque commande archivée (si complètement payée)
- `table:payment` : Événement global pour la table

## 📝 Exemple Complet

### **Scénario** :
Table 6, 3 commandes :
- **Commande 1** : Eau (4 TND) + Coca (5 TND) + Sprite (5 TND) = **14 TND**
- **Commande 2** : Beck's x2 (14.8 TND) = **14.8 TND**
- **Commande 3** : Poulet (33 TND) + Filet (65 TND) = **98 TND**

### **Paiement** :
Le client veut payer uniquement : **1 Sprite de la commande 1 + 1 Beck's de la commande 2**

### **Requête** :
```javascript
POST /api/pos/pay-multi-orders
{
  "table": "6",
  "paymentMode": "ESPECE",
  "items": [
    {
      "orderId": 1,
      "noteId": "main",
      "items": [
        { "id": 10003, "name": "Sprite", "price": 5, "quantity": 1 }
      ]
    },
    {
      "orderId": 2,
      "noteId": "main",
      "items": [
        { "id": 9502, "name": "Beck's", "price": 7.4, "quantity": 1 }
      ]
    }
  ]
}
```

### **Résultat** :
- **Total payé** : 12.4 TND (5 + 7.4)
- **Historique** : 
  - Commande 1 : 1 paiement (Sprite 5 TND)
  - Commande 2 : 1 paiement (Beck's 7.4 TND)
- **Reste** :
  - Commande 1 : Eau (4) + Coca (5) = **9 TND**
  - Commande 2 : Beck's x1 = **7.4 TND**
  - Commande 3 : Inchangé = **98 TND**

## 🚀 Prochaines Étapes

1. ✅ Endpoint serveur créé
2. ✅ Route API ajoutée
3. ✅ Intégré dans le POS Flutter
4. ✅ Interface de sélection d'articles multi-commandes

## ✅ Intégration Flutter

Le POS Flutter a été mis à jour pour :
- Récupérer toutes les commandes de la table lors de l'ouverture de la page de paiement
- Afficher tous les articles de toutes les commandes dans la sélection partielle
- Envoyer les articles sélectionnés avec leur `orderId` et `noteId` au nouvel endpoint
- Le serveur traite automatiquement le paiement multi-commandes en une seule transaction

## 📌 Notes Techniques

- Les commandes sont identifiées par leur `id` unique
- Les articles sont identifiés par `(id, name)`
- Le paiement partiel est géré au niveau de la quantité
- Les commandes vides sont automatiquement archivées avec `archivedAt`
- L'historique de paiement est préservé pour l'audit
