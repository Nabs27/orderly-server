// 🗄️ Gestionnaire de base de données MongoDB
// Détecte automatiquement si on est en mode Cloud (MongoDB) ou Local (JSON)

const { MongoClient } = require('mongodb');

class DatabaseManager {
	constructor() {
		this.client = null;
		this.db = null;
		// 🆕 CORRECTION : isCloud = true UNIQUEMENT si IS_CLOUD_SERVER=true
		// Le serveur local peut avoir MONGODB_URI pour backup sans être "cloud"
		// Le serveur cloud (Render) doit avoir IS_CLOUD_SERVER=true dans ses variables d'environnement
		this.isCloud = process.env.IS_CLOUD_SERVER === 'true';
		this.dbName = process.env.MONGODB_DB_NAME || 'restaurant_pos';
		
		// Log pour debug
		console.log(`[DB] Mode: ${this.isCloud ? '☁️ CLOUD (stateless)' : '🏠 LOCAL (source de vérité)'}`);
		console.log(`[DB] MONGODB_URI: ${process.env.MONGODB_URI ? 'défini' : 'non défini'}`);
	}

	async connect() {
		// 🆕 CORRECTION : Le serveur local peut aussi se connecter à MongoDB (pour backup/sync)
		// On ne bloque la connexion que si MONGODB_URI n'est pas défini
		if (!process.env.MONGODB_URI) {
			console.log('[DB] 🏠 Mode Local sans MongoDB : utilisation des fichiers JSON uniquement.');
			return;
		}

		try {
			const uri = process.env.MONGODB_URI;
			this.client = new MongoClient(uri);
			await this.client.connect();
			this.db = this.client.db(this.dbName);
			
			if (this.isCloud) {
				console.log(`[DB] ☁️ ✅ Connecté à MongoDB Cloud (Base: ${this.dbName}) - Mode CLOUD`);
			} else {
				console.log(`[DB] ☁️ ✅ Connecté à MongoDB Cloud (Base: ${this.dbName}) - Pour backup/sync`);
			}
			
			// Créer les index nécessaires si besoin
			await this._ensureIndexes();
		} catch (error) {
			console.error('[DB] ❌ Erreur de connexion MongoDB:', error.message);
			// En cas d'erreur de connexion au Cloud, on ne bascule pas en local par sécurité
			// car les données pourraient être désynchronisées.
			throw error;
		}
	}

	async _ensureIndexes() {
		if (!this.db) return;
		try {
			const ordersCollection = this.db.collection('orders');
			
			// 🆕 CORRECTION INDEX UNIQUE : Lister et supprimer TOUS les index sur id et tempId
			// Cela évite les conflits avec les anciens index
			try {
				const indexes = await ordersCollection.indexes();
				const indexesToDrop = [];
				
				for (const index of indexes) {
					const indexKeys = Object.keys(index.key || {});
					const indexName = index.name;
					
					// Supprimer tous les index sur id (sauf _id qui est l'index par défaut)
					if (indexKeys.includes('id') && indexName !== '_id_') {
						indexesToDrop.push(indexName);
					}
					// Supprimer tous les index sur tempId
					if (indexKeys.includes('tempId') && indexName !== '_id_') {
						indexesToDrop.push(indexName);
					}
				}
				
				// Supprimer les index trouvés
				for (const indexName of indexesToDrop) {
					try {
						await ordersCollection.dropIndex(indexName);
						console.log(`[DB] 🗑️ Ancien index ${indexName} supprimé`);
					} catch (dropError) {
						if (dropError.code !== 27 && dropError.codeName !== 'IndexNotFound') {
							console.log(`[DB] ⚠️ Erreur suppression index ${indexName}:`, dropError.message);
						}
					}
				}
			} catch (listError) {
				console.log('[DB] ⚠️ Erreur lors de la liste des index:', listError.message);
			}
			
			// 🆕 CORRECTION : Supprimer l'index sparse qui cause les doublons
			// L'index sparse unique sur tempId ne permet qu'une seule valeur null
			// Mais les commandes POS confirmées ont toutes tempId: null
			try {
				await ordersCollection.dropIndex('tempId_1_sparse');
				console.log('[DB] 🗑️ Index tempId sparse supprimé (causait les erreurs de doublons)');
			} catch (dropError) {
				// Index peut ne pas exister, c'est OK
				if (dropError.code !== 27) {
					console.log('[DB] ℹ️ Index tempId sparse non trouvé ou déjà supprimé');
				}
			}

			// Créer un index non-unique sur tempId pour les performances
			try {
				await ordersCollection.createIndex(
					{ tempId: 1 },
					{ name: 'tempId_1' } // Non-unique
				);
				console.log('[DB] ✅ Index tempId non-unique créé');
			} catch (tempIdError) {
				if (tempIdError.code !== 85 && tempIdError.codeName !== 'IndexOptionsConflict') {
					console.log('[DB] ⚠️ Erreur création index tempId:', tempIdError.message);
				}
			}

			// Index non-unique sur id pour les performances
			try {
				await ordersCollection.createIndex(
					{ id: 1 },
					{ name: 'id_1' }
				);
				console.log('[DB] ✅ Index id non-unique créé');
			} catch (idError) {
				if (idError.code !== 85 && idError.codeName !== 'IndexOptionsConflict') {
					console.log('[DB] ⚠️ Erreur création index id:', idError.message);
				}
			}
			
			await this.db.collection('bills').createIndex({ id: 1 }, { unique: true });
			await this.db.collection('client_credits').createIndex({ id: 1 }, { unique: true });
			await this.db.collection('menus').createIndex({ restaurantId: 1 }, { unique: true });
			await this.db.collection('server_permissions').createIndex({ id: 1 }, { unique: true });
		} catch (e) {
			console.log('[DB] ⚠️ Note: Les index existent déjà ou erreur mineure d\'indexation:', e.message);
		}
	}

	// Helpers pour accéder aux collections
	getCollection(name) {
		if (!this.db) return null;
		return this.db.collection(name);
	}

	// Accès rapide aux collections principales
	get orders() { return this.getCollection('orders'); }
	get archivedOrders() { return this.getCollection('archived_orders'); }
	get bills() { return this.getCollection('bills'); }
	get archivedBills() { return this.getCollection('archived_bills'); }
	get clientCredits() { return this.getCollection('client_credits'); }
	get services() { return this.getCollection('services'); }
	get counters() { return this.getCollection('counters'); }
	get serverPermissions() { return this.getCollection('server_permissions'); }
	get menus() { return this.getCollection('menus'); }
}

// Singleton
const dbManager = new DatabaseManager();

module.exports = dbManager;

