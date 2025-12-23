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
			// 🆕 CORRECTION INDEX UNIQUE : Supprimer l'ancien index sur id s'il existe
			// L'ancien index unique bloque les valeurs null multiples
			try {
				await this.db.collection('orders').dropIndex('id_1');
				console.log('[DB] 🗑️ Ancien index id_1 supprimé');
			} catch (dropError) {
				// L'index n'existe pas ou a déjà été supprimé, c'est OK
				if (dropError.code !== 27 && dropError.codeName !== 'IndexNotFound') {
					console.log('[DB] ⚠️ Erreur lors de la suppression de l\'ancien index:', dropError.message);
				}
			}
			
			// 🆕 CORRECTION INDEX UNIQUE : Index partiel pour id qui ignore les valeurs null
			// MongoDB ne supporte pas $ne: null dans les index partiels, utiliser $exists: true
			// Cela permet plusieurs commandes client avec id: null (elles utilisent tempId comme clé unique)
			await this.db.collection('orders').createIndex(
				{ id: 1 }, 
				{ unique: true, partialFilterExpression: { id: { $exists: true } }, name: 'id_1_partial' }
			);
			console.log('[DB] ✅ Index partiel id_1 créé (ignore les valeurs null)');
			
			// Index unique sur tempId pour les commandes client sans ID
			try {
				await this.db.collection('orders').createIndex(
					{ tempId: 1 }, 
					{ unique: true, partialFilterExpression: { tempId: { $exists: true } }, name: 'tempId_1_partial' }
				);
				console.log('[DB] ✅ Index partiel tempId_1 créé');
			} catch (tempIdError) {
				// L'index existe peut-être déjà, c'est OK
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

