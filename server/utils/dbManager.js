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
			// Créer les index (les collections seront créées automatiquement si elles n'existent pas)
			await this.db.collection('orders').createIndex({ id: 1 }, { unique: true }).catch(() => {});
			await this.db.collection('bills').createIndex({ id: 1 }, { unique: true }).catch(() => {});
			await this.db.collection('client_credits').createIndex({ id: 1 }, { unique: true }).catch(() => {});
			await this.db.collection('menus').createIndex({ restaurantId: 1 }, { unique: true }).catch(() => {});
			await this.db.collection('server_permissions').createIndex({ id: 1 }, { unique: true }).catch(() => {});
			console.log('[DB] ✅ Index créés/vérifiés pour les collections principales');
		} catch (e) {
			console.log('[DB] ⚠️ Note: Erreur lors de la création des index (peut être normal si collections n\'existent pas encore):', e.message);
		}
	}

	// 🆕 Méthode publique pour recréer les index après un drop()
	async recreateIndexes() {
		return this._ensureIndexes();
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

