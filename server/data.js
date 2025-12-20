// 📊 Variables globales du serveur
// Utilise un singleton pour garantir une seule instance des données

const fs = require('fs');
const path = require('path');

class DataStore {
	constructor() {
		// Variables globales pour le menu
		this.MENU_ITEMS = [];
		this.MENU_BY_NAME = new Map();
		
		// Variables globales pour le système de crédit client
		this.clientCredits = [];
		this.nextClientId = 1;
		
		// Variables globales pour les commandes
		this.orders = [];
		this.archivedOrders = [];
		this.nextOrderId = 1;
		
		// Variables globales pour les factures
		this.bills = [];
		this.archivedBills = [];
		this.nextBillId = 1;
		
		// Variables globales pour les demandes de service
		this.serviceRequests = [];
		this.nextServiceId = 1;
		
		// Variables globales pour le suivi des pertes (waste tracking)
		this.wasteRecords = [];
		
		// Mot de passe admin
		this.ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';
		
		// Chemins des fichiers de données
		this.DATA_DIR = path.join(__dirname, '..', 'data', 'pos');
		this.ORDERS_FILE = path.join(this.DATA_DIR, 'orders.json');
		this.ARCHIVED_ORDERS_FILE = path.join(this.DATA_DIR, 'archived_orders.json');
		this.BILLS_FILE = path.join(this.DATA_DIR, 'bills.json');
		this.ARCHIVED_BILLS_FILE = path.join(this.DATA_DIR, 'archived_bills.json');
		this.SERVICES_FILE = path.join(this.DATA_DIR, 'services.json');
		this.COUNTERS_FILE = path.join(this.DATA_DIR, 'counters.json');
		this.CLIENT_CREDITS_FILE = path.join(this.DATA_DIR, 'client_credits.json');
		this.SERVER_PERMISSIONS_FILE = path.join(this.DATA_DIR, 'server_permissions.json');
	}
	
	// Fonction pour construire l'index du menu
	async buildMenuIndex() {
		try {
			// Utiliser menuSync pour charger depuis MongoDB ou JSON local
			const { loadMenu } = require('./utils/menuSync');
			const menu = await loadMenu('les-emirs');
			
			if (menu) {
				const cats = Array.isArray(menu.categories) ? menu.categories : [];
				for (const cat of cats) {
					const items = Array.isArray(cat.items) ? cat.items : [];
					for (const it of items) {
						const obj = {
							id: (it.id != null ? it.id : it.code) || Math.floor(Math.random() * 1e7),
							name: it.name || it.label || '',
							price: typeof it.price === 'number' ? it.price : (typeof it.unitPrice === 'number' ? it.unitPrice : 0),
							type: (it.type || it.originalType || cat.group || '').toString()
						};
						if (obj.name) {
							this.MENU_ITEMS.push(obj);
							this.MENU_BY_NAME.set(obj.name.toLowerCase(), obj);
						}
					}
				}
				console.log(`[menu] Index construit: ${this.MENU_ITEMS.length} articles, ${this.MENU_BY_NAME.size} entrées`);
			} else {
				console.log('[menu] Menu les-emirs non trouvé');
			}
		} catch (e) {
			console.log(`[menu] Erreur construction index: ${e.message}`);
		}
	}
}

// Singleton - une seule instance pour toute l'application
const dataStore = new DataStore();

module.exports = dataStore;
