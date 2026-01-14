# 📁 Documentation POS Restaurant

Ce dossier contient toute la documentation du système POS (Point of Sale) pour restaurant Les Emirs.

## 📂 Organisation

```
docs/
├── README.md                    # Ce fichier
├── STRUCTURE_POS.md            # 🏠 Carte principale - Vue d'ensemble
├── STRUCTURE_POS_ADMIN.md      # 👑 Dashboard Admin (KPI, historique, rapport X)
├── STRUCTURE_POS_CLIENT.md     # 📱 Application Client Mobile
├── STRUCTURE_POS_CUISINE.md    # 🍳 Dashboard Cuisine / Stations
├── STRUCTURE_POS_HOME.md       # 🏠 Module Home (plan de table)
├── STRUCTURE_POS_ORDER.md      # 📝 Module Order (commandes)
├── STRUCTURE_POS_PAYMENT.md    # 💰 Module Payment (caisse)
├── STRUCTURE_SERVEUR.md        # ⚙️ Backend & API
├── guides/                     # 📖 Guides pratiques actifs
│   ├── BONNES_PRATIQUES_CLIENT_POS.md
│   ├── BONNES_PRATIQUES_COMPTABLES.md
│   ├── CAISSE_TACTILE_GUIDE.md
│   ├── GUIDE_CONSOLIDE.md
│   ├── GUIDE_INSTALLATION_ANDROID.md
│   ├── PAIEMENT_MULTI_COMMANDES.md
│   ├── POS_PAYMENT_REFERENCE_GUIDE.md
│   ├── RAILWAY_DEPLOYMENT_GUIDE.md
│   └── SERVER_IDENTIFIER_CONFIG.md
└── archive/                    # 🗂️ Anciens fichiers (octobre 2025 et avant)
    ├── ANALYSE_COMPLETE_POS_ORDER.md
    ├── DASHBOARD_FEATURES_ANALYSIS.md
    ├── EXPLICATION_DETECTION_VS_REACTION.md
    ├── INVENTAIRE_EXTRACTION_POS_ORDER.md
    ├── LISTE_EXTRACTION_REELLE.md
    ├── NOTES_SOUS_TABLES_IMPLEMENTATION.md
    └── REFACTORING_POS_ORDER_METHOD.md
```

## 🚀 Démarrage rapide

- **Première lecture** : `STRUCTURE_POS.md` (vue d'ensemble)
- **Installation** : `guides/GUIDE_CONSOLIDE.md`
- **Pratiques comptables** : `guides/BONNES_PRATIQUES_COMPTABLES.md`
- **Interface tactile** : `guides/CAISSE_TACTILE_GUIDE.md`

## 📚 Contenu par module

| Module | Documentation | Description |
|--------|---------------|-------------|
| 🏠 **Home** | `STRUCTURE_POS_HOME.md` | Plan de table, synchronisation, historique |
| 📝 **Order** | `STRUCTURE_POS_ORDER.md` | Gestion commandes, transferts, annulations |
| 💰 **Payment** | `STRUCTURE_POS_PAYMENT.md` | Caisse, paiements, remises, crédits |
| 👑 **Admin** | `STRUCTURE_POS_ADMIN.md` | KPI, historique enrichi, rapport X |
| 📱 **Client** | `STRUCTURE_POS_CLIENT.md` | App mobile client |
| 🍳 **Cuisine** | `STRUCTURE_POS_CUISINE.md` | Dashboard cuisine multi-stations |
| ⚙️ **Serveur** | `STRUCTURE_SERVEUR.md` | Backend Node.js, API, base de données |

## 🏗️ Architecture technique

- **Frontend** : Flutter (POS principal + Admin + Client)
- **Backend** : Node.js + Express + MongoDB
- **Temps réel** : Socket.IO
- **Déploiement** : Railway (auto-déploiement GitHub)

## 📋 Dernière mise à jour

**2025-01-13** : Réorganisation de la documentation
- Création du dossier `docs/` pour centraliser toute la documentation
- Séparation guides actifs / archives
- Nettoyage du répertoire racine

---

**⚠️ Important** : Les fichiers dans `archive/` sont des versions anciennes et peuvent contenir des informations obsolètes.