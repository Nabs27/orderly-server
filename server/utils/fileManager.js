// 📁 Gestionnaire de fichiers JSON
// Gère la sauvegarde et le chargement des données persistantes

const fs = require('fs');
const fsp = fs.promises;
const dataStore = require('../data');
const dbManager = require('./dbManager');

// Créer un dossier s'il n'existe pas
async function ensureDir(p) {
	try {
		await fsp.mkdir(p, { recursive: true });
	} catch (e) {
		// Dossier existe déjà, ignore
	}
}

// 💾 Charger les données persistantes (détecte Cloud vs Local)
async function loadPersistedData() {
	if (dbManager.isCloud) {
		return loadFromMongoDB();
	} else {
		return loadFromJSON();
	}
}

// 💾 Sauvegarder les données (Mode Hybride : Local + Backup Cloud)
async function savePersistedData() {
	// 1. Sauvegarder en JSON local (source de vérité, rapide, fonctionne sans internet)
	// Sur Railway (cloud), cette sauvegarde peut échouer (pas de fichiers persistants), c'est normal
	try {
		await saveToJSON();
	} catch (e) {
		// Sur Railway ou si erreur d'écriture, on continue avec MongoDB
	if (dbManager.isCloud) {
			console.log('[persistence] ⚠️ Sauvegarde JSON ignorée (mode cloud)');
	} else {
			console.error('[persistence] ❌ Erreur sauvegarde JSON:', e.message);
		}
	}
	
	// 2. Si MongoDB est configuré, synchroniser vers le cloud (backup)
	// La synchronisation est asynchrone et non-bloquante pour ne pas ralentir le POS
	if (dbManager.isCloud && dbManager.db) {
		// Ne pas attendre la fin de la synchronisation cloud (non-bloquant)
		saveToMongoDB().catch(e => {
			console.error('[sync] ⚠️ Erreur synchronisation cloud (non bloquant):', e.message);
			// Ne pas bloquer le POS en cas d'erreur cloud
		});
	}
}

// --- LOGIQUE MONGODB (CLOUD) ---

async function loadFromMongoDB() {
	try {
		console.log('[persistence] ☁️ Chargement des données depuis MongoDB...');
		
		// 🆕 CORRECTION : Vérifier si un reset a été fait récemment
		// Si oui, s'assurer que MongoDB est vraiment vide avant de charger
		// Charger les compteurs (un seul doc) - on le charge en premier pour vérifier le reset
		const countersDoc = await dbManager.counters.findOne({ type: 'global' });
		console.log('[persistence] 🔍 Vérification reset: countersDoc existe?', !!countersDoc, 'lastReset?', countersDoc?.lastReset);
		
		if (countersDoc && countersDoc.lastReset) {
			const lastReset = new Date(countersDoc.lastReset);
			const now = new Date();
			const timeSinceReset = now - lastReset;
			console.log('[persistence] 🧹 Reset détecté il y a ' + Math.round(timeSinceReset / 1000) + 's');
			
			// 🆕 CORRECTION : Augmenter la fenêtre de temps à 30 minutes au lieu de 5
			// Car le serveur peut être redémarré plus tard après le reset
			if (timeSinceReset < 30 * 60 * 1000) {
				console.log('[persistence] 🧹 Reset récent détecté (il y a ' + Math.round(timeSinceReset / 1000) + 's), vérification MongoDB...');
				const ordersCount = await dbManager.orders.countDocuments({});
				console.log('[persistence] 📊 Nombre de commandes dans MongoDB:', ordersCount);
				
				if (ordersCount > 0) {
					console.log('[persistence] ⚠️ ATTENTION: ' + ordersCount + ' commande(s) encore présente(s) dans MongoDB après reset !');
					console.log('[persistence] 🧹 Nettoyage automatique de MongoDB...');
					const deletedOrders = await dbManager.orders.deleteMany({});
					const deletedArchived = await dbManager.archivedOrders.deleteMany({});
					const deletedBills = await dbManager.bills.deleteMany({});
					const deletedArchivedBills = await dbManager.archivedBills.deleteMany({});
					const deletedServices = await dbManager.services.deleteMany({});
					const deletedCredits = await dbManager.clientCredits.deleteMany({});
					console.log('[persistence] ✅ MongoDB nettoyé automatiquement:', {
						orders: deletedOrders.deletedCount,
						archivedOrders: deletedArchived.deletedCount,
						bills: deletedBills.deletedCount,
						archivedBills: deletedArchivedBills.deletedCount,
						services: deletedServices.deletedCount,
						credits: deletedCredits.deletedCount
					});
				} else {
					console.log('[persistence] ✅ MongoDB est déjà vide après reset');
				}
			} else {
				console.log('[persistence] ℹ️ Reset trop ancien (' + Math.round(timeSinceReset / 60000) + ' min), pas de nettoyage automatique');
			}
		} else {
			console.log('[persistence] ℹ️ Aucun reset récent détecté, chargement normal depuis MongoDB');
		}
		
		// Charger les commandes
		const orders = await dbManager.orders.find({}).toArray();
		dataStore.orders.length = 0;
		dataStore.orders.push(...orders);
		
		// Charger les archives
		const archived = await dbManager.archivedOrders.find({}).toArray();
		dataStore.archivedOrders.length = 0;
		dataStore.archivedOrders.push(...archived);
		
		// Charger les factures
		const bills = await dbManager.bills.find({}).toArray();
		dataStore.bills.length = 0;
		dataStore.bills.push(...bills);
		
		const archivedBills = await dbManager.archivedBills.find({}).toArray();
		dataStore.archivedBills.length = 0;
		dataStore.archivedBills.push(...archivedBills);
		
		// Charger les services
		const services = await dbManager.services.find({}).toArray();
		dataStore.serviceRequests.length = 0;
		dataStore.serviceRequests.push(...services);
		
		// Utiliser countersDoc déjà chargé plus haut
		if (countersDoc) {
			dataStore.nextOrderId = countersDoc.nextOrderId || 1;
			dataStore.nextBillId = countersDoc.nextBillId || 1;
			dataStore.nextServiceId = countersDoc.nextServiceId || 1;
			dataStore.nextClientId = countersDoc.nextClientId || 1;
		}
		
		// Charger les clients crédit
		const clients = await dbManager.clientCredits.find({}).toArray();
		dataStore.clientCredits.length = 0;
		dataStore.clientCredits.push(...clients);
		
		console.log(`[persistence] ☁️ ✅ ${dataStore.orders.length} commandes et ${dataStore.clientCredits.length} clients chargés depuis MongoDB`);
	} catch (e) {
		console.error('[persistence] ❌ Erreur chargement MongoDB:', e);
	}
}

async function saveToMongoDB() {
	try {
		if (!dbManager.db) {
			console.log('[sync] ⚠️ MongoDB non connecté, synchronisation ignorée');
			return;
		}
		
		console.log('[sync] ☁️ Synchronisation vers MongoDB (backup)...');
		
		// Synchroniser les commandes (upsert par ID pour éviter les doublons)
		if (dataStore.orders.length > 0) {
			for (const order of dataStore.orders) {
				await dbManager.orders.replaceOne(
					{ id: order.id },
					order,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.orders.length} commandes synchronisées`);
		}
		
		// Synchroniser les commandes archivées
		if (dataStore.archivedOrders.length > 0) {
			for (const order of dataStore.archivedOrders) {
				await dbManager.archivedOrders.replaceOne(
					{ id: order.id },
					order,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.archivedOrders.length} commandes archivées synchronisées`);
		}
		
		// Synchroniser les factures
		if (dataStore.bills.length > 0) {
			for (const bill of dataStore.bills) {
				await dbManager.bills.replaceOne(
					{ id: bill.id },
					bill,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.bills.length} factures synchronisées`);
		}
		
		// Synchroniser les factures archivées
		if (dataStore.archivedBills.length > 0) {
			for (const bill of dataStore.archivedBills) {
				await dbManager.archivedBills.replaceOne(
					{ id: bill.id },
					bill,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.archivedBills.length} factures archivées synchronisées`);
		}
		
		// Synchroniser les demandes de service
		if (dataStore.serviceRequests.length > 0) {
			for (const service of dataStore.serviceRequests) {
				await dbManager.services.replaceOne(
					{ id: service.id },
					service,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.serviceRequests.length} services synchronisés`);
		}
		
		// Synchroniser les clients crédit
		if (dataStore.clientCredits.length > 0) {
			for (const client of dataStore.clientCredits) {
				await dbManager.clientCredits.replaceOne(
					{ id: client.id },
					client,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.clientCredits.length} clients crédit synchronisés`);
		}
		
		// Mise à jour des compteurs
		await dbManager.counters.updateOne(
			{ type: 'global' },
			{ 
				$set: { 
					nextOrderId: dataStore.nextOrderId,
					nextBillId: dataStore.nextBillId,
					nextServiceId: dataStore.nextServiceId,
					nextClientId: dataStore.nextClientId,
					lastSynced: new Date().toISOString()
				} 
			},
			{ upsert: true }
		);

		console.log('[sync] ☁️ ✅ Synchronisation MongoDB terminée');
	} catch (e) {
		console.error('[sync] ❌ Erreur synchronisation MongoDB:', e);
		// Ne pas bloquer le POS en cas d'erreur cloud
		throw e; // Re-lancer pour que le catch dans savePersistedData le gère
	}
}

// --- LOGIQUE JSON (LOCAL) ---

async function loadFromJSON() {
	try {
		await ensureDir(dataStore.DATA_DIR);
		
		// Charger les commandes
		if (fs.existsSync(dataStore.ORDERS_FILE)) {
			const data = await fsp.readFile(dataStore.ORDERS_FILE, 'utf8');
			const loadedOrders = JSON.parse(data);
			dataStore.orders.length = 0;
			dataStore.orders.push(...loadedOrders);
			console.log(`[persistence] 🏠 ${dataStore.orders.length} commandes chargées`);
		}
		
		// Charger les commandes archivées
		if (fs.existsSync(dataStore.ARCHIVED_ORDERS_FILE)) {
			const data = await fsp.readFile(dataStore.ARCHIVED_ORDERS_FILE, 'utf8');
			const loadedArchived = JSON.parse(data);
			dataStore.archivedOrders.length = 0;
			dataStore.archivedOrders.push(...loadedArchived);
			console.log(`[persistence] 🏠 ${dataStore.archivedOrders.length} commandes archivées chargées`);
		}
		
		// Charger les factures
		if (fs.existsSync(dataStore.BILLS_FILE)) {
			const data = await fsp.readFile(dataStore.BILLS_FILE, 'utf8');
			const loadedBills = JSON.parse(data);
			dataStore.bills.length = 0;
			dataStore.bills.push(...loadedBills);
			console.log(`[persistence] 🏠 ${dataStore.bills.length} factures chargées`);
		}
		
		// Charger les factures archivées
		if (fs.existsSync(dataStore.ARCHIVED_BILLS_FILE)) {
			const data = await fsp.readFile(dataStore.ARCHIVED_BILLS_FILE, 'utf8');
			const loadedArchivedBills = JSON.parse(data);
			dataStore.archivedBills.length = 0;
			dataStore.archivedBills.push(...loadedArchivedBills);
			console.log(`[persistence] 🏠 ${dataStore.archivedBills.length} factures archivées chargées`);
		}
		
		// Charger les demandes de service
		if (fs.existsSync(dataStore.SERVICES_FILE)) {
			const data = await fsp.readFile(dataStore.SERVICES_FILE, 'utf8');
			const loadedServices = JSON.parse(data);
			dataStore.serviceRequests.length = 0;
			dataStore.serviceRequests.push(...loadedServices);
			console.log(`[persistence] 🏠 ${dataStore.serviceRequests.length} demandes de service chargées`);
		}
		
		// Charger les compteurs
		if (fs.existsSync(dataStore.COUNTERS_FILE)) {
			const data = await fsp.readFile(dataStore.COUNTERS_FILE, 'utf8');
			const counters = JSON.parse(data);
			dataStore.nextOrderId = counters.nextOrderId || 1;
			dataStore.nextBillId = counters.nextBillId || 1;
			dataStore.nextServiceId = counters.nextServiceId || 1;
			dataStore.nextClientId = counters.nextClientId || 1;
			console.log(`[persistence] 🏠 Compteurs chargés: orderId=${dataStore.nextOrderId}, billId=${dataStore.nextBillId}, serviceId=${dataStore.nextServiceId}, clientId=${dataStore.nextClientId}`);
		}
		
		// Charger les clients crédit
		if (fs.existsSync(dataStore.CLIENT_CREDITS_FILE)) {
			const data = await fsp.readFile(dataStore.CLIENT_CREDITS_FILE, 'utf8');
			const loadedClients = JSON.parse(data);
			dataStore.clientCredits.length = 0;
			dataStore.clientCredits.push(...loadedClients);
			console.log(`[persistence] 🏠 ${dataStore.clientCredits.length} clients crédit chargés`);
		} else {
			// Créer le fichier vide si inexistant
			await fsp.writeFile(dataStore.CLIENT_CREDITS_FILE, '[]', 'utf8');
			console.log(`[persistence] 🏠 Fichier client_credits.json créé (vide)`);
		}
	} catch (e) {
		console.error('[persistence] 🏠 Erreur chargement données JSON:', e);
	}
}

async function saveToJSON() {
	try {
		await ensureDir(dataStore.DATA_DIR);
		
		// Sauvegarder les commandes
		await fsp.writeFile(dataStore.ORDERS_FILE, JSON.stringify(dataStore.orders, null, 2), 'utf8');
		
		// Sauvegarder les commandes archivées
		await fsp.writeFile(dataStore.ARCHIVED_ORDERS_FILE, JSON.stringify(dataStore.archivedOrders, null, 2), 'utf8');
		
		// Sauvegarder les factures
		await fsp.writeFile(dataStore.BILLS_FILE, JSON.stringify(dataStore.bills, null, 2), 'utf8');
		
		// Sauvegarder les factures archivées
		await fsp.writeFile(dataStore.ARCHIVED_BILLS_FILE, JSON.stringify(dataStore.archivedBills, null, 2), 'utf8');
		
		// Sauvegarder les demandes de service
		await fsp.writeFile(dataStore.SERVICES_FILE, JSON.stringify(dataStore.serviceRequests, null, 2), 'utf8');
		
		// Sauvegarder les compteurs
		const counters = {
			nextOrderId: dataStore.nextOrderId,
			nextBillId: dataStore.nextBillId,
			nextServiceId: dataStore.nextServiceId,
			nextClientId: dataStore.nextClientId,
			lastSaved: new Date().toISOString()
		};
		await fsp.writeFile(dataStore.COUNTERS_FILE, JSON.stringify(counters, null, 2), 'utf8');
		
		// Sauvegarder les clients crédit
		await fsp.writeFile(dataStore.CLIENT_CREDITS_FILE, JSON.stringify(dataStore.clientCredits, null, 2), 'utf8');
		
		console.log(`[persistence] 🏠 Données sauvegardées: ${dataStore.orders.length} commandes, ${dataStore.bills.length} factures, ${dataStore.clientCredits.length} clients crédit`);
	} catch (e) {
		console.error('[persistence] 🏠 Erreur sauvegarde données JSON:', e);
	}
}

module.exports = {
	ensureDir,
	loadPersistedData,
	savePersistedData
};
