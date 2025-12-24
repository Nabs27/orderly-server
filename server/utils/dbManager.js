// 🗄️ Gestionnaire de base de données MongoDB
// Détecte automatiquement si on est en mode Cloud (MongoDB) ou Local (JSON)

const { MongoClient } = require('mongodb');

class DatabaseManager {
	constructor() {
		this.client = null;
		this.db = null;
		this.isCloud = !!process.env.MONGODB_URI;
		this.dbName = process.env.MONGODB_DB_NAME || 'restaurant_pos';
	}

	async connect() {
		if (!this.isCloud) {
			console.log('[DB] 🏠 Mode Local détecté : utilisation des fichiers JSON.');
			return;
		}

		try {
			const uri = process.env.MONGODB_URI;
			this.client = new MongoClient(uri);
			await this.client.connect();
			this.db = this.client.db(this.dbName);
			console.log(`[DB] ☁️ ✅ Connecté à MongoDB Cloud (Base: ${this.dbName})`);
			
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
			
			// 🆕 SOLUTION FINALE : Utiliser SPARSE INDEX au lieu de partial index
			// Un sparse index ignore automatiquement les documents où le champ est null ou absent
			// Cela permet plusieurs commandes avec id: null sans violation d'unicité
			// C'est la méthode recommandée par MongoDB pour ce cas d'usage
			try {
				await ordersCollection.createIndex(
					{ id: 1 }, 
					{ unique: true, sparse: true, name: 'id_1_sparse' }
				);
				console.log('[DB] ✅ Index sparse unique id créé (ignore automatiquement les valeurs null)');
			} catch (idError) {
				// Si l'index existe déjà avec les mêmes options, c'est OK
				if (idError.code !== 85 && idError.codeName !== 'IndexOptionsConflict') {
					console.log('[DB] ⚠️ Erreur création index id:', idError.message);
				}
			}
			
			// Index sparse unique sur tempId pour les commandes client sans ID
			try {
				await ordersCollection.createIndex(
					{ tempId: 1 }, 
					{ unique: true, sparse: true, name: 'tempId_1_sparse' }
				);
				console.log('[DB] ✅ Index sparse unique tempId créé (ignore automatiquement les valeurs null)');
			} catch (tempIdError) {
				// Si l'index existe déjà avec les mêmes options, c'est OK
				if (tempIdError.code !== 85 && tempIdError.codeName !== 'IndexOptionsConflict') {
					console.log('[DB] ⚠️ Erreur création index tempId:', tempIdError.message);
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

