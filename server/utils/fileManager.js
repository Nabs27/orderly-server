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
		// 🆕 SERVEUR CLOUD : STATELESS - Charger UNIQUEMENT depuis MongoDB
		// Pas de datastore local persistant pour éviter les conflits
		return loadFromMongoDB();
	} else {
		// SERVEUR LOCAL : État full local + sync MongoDB
		await loadFromJSON();
		if (dbManager.db) {
			await mergeFromMongoDB();
		}
	}
}

// 💾 Sauvegarder les données (Cloud = Stateless, Local = Statefull)
async function savePersistedData() {
	if (dbManager.isCloud) {
		// 🆕 SERVEUR CLOUD : STATELESS - PAS de sauvegarde JSON locale
		// MAIS sauvegarde quand même dans MongoDB pour les données reçues
		if (dbManager.db) {
			saveToMongoDB().catch(e => {
				console.error('[sync] ⚠️ Erreur sync MongoDB cloud:', e.message);
			});
		}
		return;
	} else {
		// SERVEUR LOCAL : Sauvegarde JSON locale + sync MongoDB
		try {
			await saveToJSON();
		} catch (e) {
			console.error('[persistence] ❌ Erreur sauvegarde JSON local:', e.message);
		}

		// Sync vers MongoDB (non-bloquant)
		if (dbManager.db) {
			saveToMongoDB().catch(e => {
				console.error('[sync] ⚠️ Erreur sync MongoDB:', e.message);
			});
		}
	}
}

// Fonction supprimée - le serveur cloud est maintenant stateless

// --- LOGIQUE MONGODB (CLOUD) ---

async function loadFromMongoDB() {
	try {
		console.log('[persistence] ☁️ Chargement des données depuis MongoDB...');
		
		// Charger les commandes
		const orders = await dbManager.orders.find({}).toArray();

		// 🆕 SOLUTION : Identifier les commandes confirmées par leur originalTempId
		const confirmedTempIds = new Set(
			orders
				.filter(o => o.id && o.originalTempId && o.source === 'pos')
				.map(o => o.originalTempId)
		);

		// 🆕 Filtrer : exclure les commandes client qui ont déjà été confirmées
		const filteredOrders = orders.filter(o => {
			// Si c'est une commande client avec tempId mais sans id, vérifier si elle a été confirmée
			if (o.tempId && (!o.id || o.id === null) && o.source === 'client') {
				if (confirmedTempIds.has(o.tempId)) {
					console.log(`[persistence] 🧹 Commande client ${o.tempId} ignorée: déjà confirmée (ID #${orders.find(oo => oo.originalTempId === o.tempId && oo.id)?.id})`);
					// Supprimer de MongoDB aussi
					dbManager.orders.deleteMany({ tempId: o.tempId }).catch(e =>
						console.error(`[persistence] ⚠️ Erreur suppression doublon: ${e.message}`)
					);
					return false;
				}
			}
			return true;
		});

		dataStore.orders.length = 0;
		dataStore.orders.push(...filteredOrders);
		
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
		
		// Charger les compteurs (un seul doc)
		const countersDoc = await dbManager.counters.findOne({ type: 'global' });
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
		
		// 🆕 SYNCHRONISATION INTELLIGENTE : Gérer les resets de compteur intelligemment
		const countersDoc = await dbManager.counters.findOne({ type: 'global' });
		if (countersDoc && countersDoc.nextOrderId === 1) {
			// Calculer le max ID existant dans mémoire et MongoDB
			const maxOrderId = dataStore.orders.length > 0
				? Math.max(...dataStore.orders.map(o => o.id || 0))
				: 0;

			const mongoOrders = await dbManager.orders.find({}).toArray();
			const maxMongoOrderId = mongoOrders.length > 0
				? Math.max(...mongoOrders.map(o => o.id || 0))
				: 0;

			const globalMaxId = Math.max(maxOrderId, maxMongoOrderId);

			if (globalMaxId > 0) {
				// 🆕 CAS NORMAL : Synchroniser le compteur au lieu de reset destructeur
				console.log(`[sync] 🔄 SYNC COMPTEUR : nextOrderId 1 → ${globalMaxId + 1} (max ID trouvé: ${globalMaxId})`);
				await dbManager.counters.updateOne(
					{ type: 'global' },
					{ $set: { nextOrderId: globalMaxId + 1 } }
				);
				dataStore.nextOrderId = globalMaxId + 1;

				// 🆕 Nettoyer automatiquement les anciennes entrées tempId des commandes confirmées
				const confirmedTempIds = new Set(
					[...dataStore.orders, ...mongoOrders]
						.filter(o => o.id && o.originalTempId && o.source === 'pos')
						.map(o => o.originalTempId)
				);

				if (confirmedTempIds.size > 0) {
					console.log(`[sync] 🧹 Nettoyage automatique : ${confirmedTempIds.size} ancienne(s) entrée(s) tempId confirmée(s)`);
					let cleanedCount = 0;
					for (const tempId of confirmedTempIds) {
						const deleteResult = await dbManager.orders.deleteMany({
							tempId: tempId,
							$or: [{ id: null }, { id: { $exists: false } }] // Supprimer seulement les entrées sans ID officiel
						});
						cleanedCount += deleteResult.deletedCount || 0;
					}
					console.log(`[sync] 🗑️ ${cleanedCount} ancienne(s) entrée(s) tempId supprimée(s)`);
				}

				console.log(`[sync] ✅ Synchronisation intelligente terminée - Commandes préservées`);
				return; // Pas de sync normale, on vient de synchroniser intelligemment
			}
		}
		
		console.log('[sync] ☁️ Synchronisation vers MongoDB (backup)...');
		
		// Synchroniser les commandes (upsert par ID pour éviter les doublons)
		if (dataStore.orders.length > 0) {
			for (const order of dataStore.orders) {
				// 🆕 CORRECTION : Supprimer _id MongoDB avant replaceOne pour éviter l'erreur "immutable field"
				// MongoDB génère automatiquement _id lors du chargement, mais on ne doit pas le modifier
				const orderToSave = { ...order };
				delete orderToSave._id;
				
				// 🆕 CORRECTION DOUBLE CONFIRMATION : Si la commande a un ID officiel mais avait un tempId,
				// supprimer l'ancienne entrée MongoDB avec tempId pour éviter les doublons
				if (order.id && order.originalTempId) {
					const deleteResult = await dbManager.orders.deleteMany({
						$or: [
							{ tempId: order.originalTempId },
							{ id: null, tempId: order.originalTempId }
						]
					});
					if (deleteResult.deletedCount > 0) {
						console.log(`[sync] 🗑️ Ancienne commande avec tempId ${order.originalTempId} supprimée de MongoDB (confirmée avec ID #${order.id})`);
					}
				}
				
				// 🆕 SOLUTION : Utiliser tempId pour les commandes client, id pour les commandes POS
				// Plus d'index unique sur id, donc pas de conflit
				let query;
				if (order.tempId) {
					// Commande client : utiliser tempId (unique)
					query = { tempId: order.tempId };
				} else if (order.id) {
					// Commande POS : utiliser id (non-unique)
					query = { id: order.id };
				} else {
					// Fallback : utiliser createdAt + table
					console.warn(`[sync] ⚠️ Commande sans ID ni tempId détectée, utilisation createdAt comme fallback`);
					query = { createdAt: order.createdAt, table: order.table };
				}
				
				await dbManager.orders.replaceOne(
					query,
					orderToSave,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.orders.length} commandes synchronisées`);
		}
		
		// Synchroniser les commandes archivées
		if (dataStore.archivedOrders.length > 0) {
			for (const order of dataStore.archivedOrders) {
				// 🆕 CORRECTION : Supprimer _id MongoDB avant replaceOne
				const orderToSave = { ...order };
				delete orderToSave._id;
				
				await dbManager.archivedOrders.replaceOne(
					{ id: order.id },
					orderToSave,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.archivedOrders.length} commandes archivées synchronisées`);
		}
		
		// Synchroniser les factures
		if (dataStore.bills.length > 0) {
			for (const bill of dataStore.bills) {
				// 🆕 CORRECTION : Supprimer _id MongoDB avant replaceOne
				const billToSave = { ...bill };
				delete billToSave._id;
				
				await dbManager.bills.replaceOne(
					{ id: bill.id },
					billToSave,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.bills.length} factures synchronisées`);
		}
		
		// Synchroniser les factures archivées
		if (dataStore.archivedBills.length > 0) {
			for (const bill of dataStore.archivedBills) {
				// 🆕 CORRECTION : Supprimer _id MongoDB avant replaceOne
				const billToSave = { ...bill };
				delete billToSave._id;
				
				await dbManager.archivedBills.replaceOne(
					{ id: bill.id },
					billToSave,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.archivedBills.length} factures archivées synchronisées`);
		}
		
		// Synchroniser les demandes de service
		if (dataStore.serviceRequests.length > 0) {
			for (const service of dataStore.serviceRequests) {
				// 🆕 CORRECTION : Supprimer _id MongoDB avant replaceOne
				const serviceToSave = { ...service };
				delete serviceToSave._id;
				
				await dbManager.services.replaceOne(
					{ id: service.id },
					serviceToSave,
					{ upsert: true }
				);
			}
			console.log(`[sync] ☁️ ${dataStore.serviceRequests.length} services synchronisés`);
		}
		
		// Synchroniser les clients crédit
		if (dataStore.clientCredits.length > 0) {
			for (const client of dataStore.clientCredits) {
				// 🆕 CORRECTION : Supprimer _id MongoDB avant replaceOne
				const clientToSave = { ...client };
				delete clientToSave._id;
				
				await dbManager.clientCredits.replaceOne(
					{ id: client.id },
					clientToSave,
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
	savePersistedData,
	loadFromMongoDB // 🆕 Export pour détection reset serveur cloud
};
