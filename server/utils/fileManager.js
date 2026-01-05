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
	console.log('[persistence] 🔄 Chargement des données persistées...');

	if (dbManager.isCloud) {
		// 🆕 SERVEUR CLOUD : Charger UNIQUEMENT depuis MongoDB (stateless)
		if (dbManager.db) {
			console.log('[persistence] ☁️ Serveur cloud détecté - Chargement depuis MongoDB...');
			await loadFromMongoDB();
			console.log('[persistence] ✅ Données chargées depuis MongoDB');
		} else {
			console.log('[persistence] ⚠️ Serveur cloud mais MongoDB non disponible - Données vides');
		}
	} else {
		// 🆕 SERVEUR LOCAL = SOURCE DE VERITE : TOUJOURS charger depuis JSON local d'abord
		await loadFromJSON();
		console.log('[persistence] ✅ Données chargées depuis fichiers locaux');

		// Puis synchroniser intelligemment avec MongoDB si disponible (pour commandes clients + backup)
		if (dbManager.db) {
			console.log('[persistence] ☁️ Synchronisation intelligente avec MongoDB...');
			await smartSyncWithMongoDB();
			console.log('[persistence] ✅ Synchronisation terminée');
		} else {
			console.log('[persistence] ℹ️ MongoDB non disponible - fonctionnement en mode local seulement');
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
		console.log(`[persistence] ☁️ ${dataStore.archivedOrders.length} commandes archivées chargées depuis MongoDB`);
		
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

// 🆕 FONCTION D'ASPIRATION : Récupère les commandes de la boîte aux lettres MongoDB
// Peut être appelée au démarrage ET périodiquement (polling)
async function pullFromMailbox() {
	if (!dbManager.db) {
		return 0; // MongoDB non disponible
	}

	try {
		// 1. SCAN de la boîte aux lettres MongoDB
		const waitingOrders = await dbManager.orders.find({
			waitingForPos: true,
			processedByPos: { $ne: true }, // Pas encore traitées
			$or: [{ id: null }, { id: { $exists: false } }], // Pas d'ID officiel
			source: 'client'
		}).toArray();

		if (waitingOrders.length === 0) {
			return 0; // Boîte aux lettres vide
		}

		console.log(`[sync] 🔍 Scan de la boîte aux lettres MongoDB...`);
		console.log(`[sync] 📬 ${waitingOrders.length} nouvelle(s) commande(s) trouvée(s)`);

		// 2. TRAITER chaque commande : lui donner un ID local et la marquer comme traitée
		let processedCount = 0;
		for (const mongoOrder of waitingOrders) {
			// 🆕 VÉRIFICATION ANTI-DOUBLON : Vérifier si cette commande existe déjà localement
			// Protection contre les micro-coupures réseau ou redémarrages
			const existingLocal = dataStore.orders.find(o =>
				o.tempId === mongoOrder.tempId ||
				(o.id && o.id === mongoOrder.id) ||
				(o.tempId && mongoOrder.tempId && o.tempId === mongoOrder.tempId)
			);

			if (existingLocal) {
				console.log(`[sync] ⏭️ Commande ${mongoOrder.tempId} déjà présente localement (ID: ${existingLocal.id || 'N/A'}), ignorée`);
				// Marquer quand même comme traitée dans MongoDB si elle a déjà un ID
				if (existingLocal.id) {
					try {
						await dbManager.orders.updateOne(
							{ tempId: mongoOrder.tempId },
							{ 
								$set: { 
									id: existingLocal.id,
									processedByPos: true,
									waitingForPos: false
								}
							}
						);
					} catch (e) {
						// Ignorer les erreurs de mise à jour
					}
				}
				continue;
			}

			// 🆕 LE POS LOCAL DONNE L'ID (source de vérité)
			const localId = dataStore.nextOrderId++;
			mongoOrder.id = localId;
			mongoOrder.waitingForPos = false; // Plus en attente
			mongoOrder.processedByPos = true; // Traitée par le POS
			delete mongoOrder._id; // Supprimer _id MongoDB avant ajout local

			// Ajouter au datastore local
			dataStore.orders.push(mongoOrder);
			processedCount++;
			
			console.log(`[sync] ✍️ Attribution ID #${localId} à ${mongoOrder.tempId}. Enregistré localement.`);
			
			// 🆕 DOUBLE VALIDATION MONGODB : Marquer comme traitée avec les 3 champs requis
			try {
				const updateResult = await dbManager.orders.updateOne(
					{ tempId: mongoOrder.tempId },
					{ 
						$set: { 
							id: localId, // ID définitif du POS
							processedByPos: true, // Traitée par le POS
							waitingForPos: false // Plus en attente
						}
					}
				);
				if (updateResult.modifiedCount > 0) {
					console.log(`[sync] ✉️ Boîte aux lettres : Commande ${mongoOrder.tempId} marquée comme traitée (ID #${localId})`);
				}
			} catch (e) {
				console.error(`[sync] ⚠️ Erreur marquage commande ${mongoOrder.tempId} comme traitée:`, e.message);
			}
		}

		// Sauvegarder les nouvelles commandes dans le JSON local
		if (processedCount > 0) {
			try {
				await saveToJSON();
				console.log(`[sync] 💾 ${processedCount} commande(s) sauvegardée(s) en JSON local`);
			} catch (e) {
				console.error(`[sync] ⚠️ Erreur sauvegarde JSON:`, e.message);
			}
		}

		return processedCount;
	} catch (e) {
		console.error('[sync] ❌ Erreur aspiration boîte aux lettres:', e);
		return 0;
	}
}

// 🆕 SYNCHRONISATION INTELLIGENTE : Ne pas écraser l'état local
async function smartSyncWithMongoDB() {
	try {
		// 1. ASPIRER les commandes de la boîte aux lettres (au démarrage)
		const processedCount = await pullFromMailbox();

		// 🆕 Le serveur local est la SEULE source de vérité
		// On ne récupère PAS les commandes depuis MongoDB (sauf commandes client en attente)
		// Si les fichiers JSON disent "0 commandes", alors il y a 0 commandes

		// 3. Synchroniser les compteurs si nécessaire
		const countersDoc = await dbManager.counters.findOne({ type: 'global' });
		if (countersDoc) {
			// Utiliser le max entre local et cloud
			const localMaxId = dataStore.orders.length > 0
				? Math.max(...dataStore.orders.map(o => o.id || 0))
				: 0;
			const cloudMaxId = countersDoc.nextOrderId || 1;

			dataStore.nextOrderId = Math.max(localMaxId + 1, cloudMaxId);
			dataStore.nextBillId = Math.max(dataStore.nextBillId, countersDoc.nextBillId || 1);
			dataStore.nextServiceId = Math.max(dataStore.nextServiceId, countersDoc.nextServiceId || 1);
			dataStore.nextClientId = Math.max(dataStore.nextClientId, countersDoc.nextClientId || 1);

			console.log(`[sync] 🔢 Compteurs synchronisés: nextOrderId=${dataStore.nextOrderId}`);
		}

		// 4. Charger les clients crédit (backup)
		const clients = await dbManager.clientCredits.find({}).toArray();
		if (clients.length > 0) {
			// Merger sans écraser
			for (const client of clients) {
				const existing = dataStore.clientCredits.find(c => c.id === client.id);
				if (!existing) {
					dataStore.clientCredits.push(client);
					console.log(`[sync] 👤 Client ${client.name} ajouté depuis MongoDB`);
				}
			}
		}

		// 🆕 PAS DE NETTOYAGE AUTOMATIQUE : Les commandes dans MongoDB sont soit :
		// - En attente (waitingForPos=true) → seront aspirées par le POS
		// - Traitées (processedByPos=true) → peuvent rester comme backup
		// Le POS local est la source de vérité, MongoDB est juste la boîte aux lettres + backup

		console.log(`[sync] ✅ Synchronisation terminée: ${processedCount} commande(s) aspirée(s) et traitée(s)`);

	} catch (e) {
		console.error('[sync] ❌ Erreur synchronisation intelligente:', e);
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
		
		// 🆕 ARCHITECTURE "BOÎTE AUX LETTRES" : Le serveur local NE sauvegarde PAS les commandes client dans MongoDB
		// Les commandes client arrivent via le serveur cloud et sont aspirées par smartSyncWithMongoDB()
		// Une fois traitées (ID attribué), elles restent UNIQUEMENT dans le JSON local (source de vérité)
		// MongoDB ne contient QUE :
		// 1. Commandes client EN ATTENTE (déposées par le serveur cloud, waitingForPos=true)
		// 2. Backups archivées (pour dashboard)
		// 3. 🆕 Commandes actives (pour que le dashboard admin en ligne puisse voir les tables non payées)
		
		// 🆕 CORRECTION : Synchroniser aussi les commandes actives pour le dashboard admin en ligne
		// Le serveur cloud a besoin de voir les commandes actives pour calculer les tables non payées
		if (dataStore.orders.length > 0) {
			const activeOrders = dataStore.orders.filter(o => o.status !== 'archived');
			console.log(`[sync] 🔍 DEBUG: ${dataStore.orders.length} commandes totales, ${activeOrders.length} actives (status !== 'archived')`);
			
			let syncedCount = 0;
			let skippedCount = 0;
			
			for (const order of activeOrders) {
				// 🆕 DEBUG: Log chaque commande avant synchronisation
				console.log(`[sync] 🔍 DEBUG: Commande id=${order.id || 'NULL'}, table=${order.table}, status=${order.status}, source=${order.source || 'undefined'}`);
				
				// 🆕 CORRECTION : Vérifier que la commande a un ID valide
				if (!order.id || order.id === null) {
					console.warn(`[sync] ⚠️ Commande ignorée (pas d'ID): table=${order.table}, tempId=${order.tempId || 'N/A'}, source=${order.source || 'undefined'}, status=${order.status}`);
					skippedCount++;
					continue; // Ignorer les commandes sans ID (commandes client en attente)
				}
				
				// 🆕 CORRECTION : Supprimer _id MongoDB avant replaceOne
				const orderToSave = { ...order };
				delete orderToSave._id;
				
				try {
					const result = await dbManager.orders.replaceOne(
						{ id: order.id },
						orderToSave,
						{ upsert: true }
					);
					syncedCount++;
					console.log(`[sync] ✅ Commande ${order.id} (table ${order.table}) synchronisée: ${result.upsertedCount > 0 ? 'créée' : 'mise à jour'}`);
				} catch (e) {
					console.error(`[sync] ❌ Erreur synchronisation commande ${order.id} (table ${order.table}):`, e.message);
					console.error(`[sync] ❌ Stack:`, e.stack);
				}
			}
			console.log(`[sync] ☁️ ${syncedCount} commandes actives synchronisées vers MongoDB, ${skippedCount} ignorées (pas d'ID)`);
		} else {
			// 🆕 Si le tableau est vide, supprimer toutes les commandes actives de MongoDB
			// (mais garder les commandes client en attente avec waitingForPos=true)
			const deleteResult = await dbManager.orders.deleteMany({
				status: { $ne: 'archived' },
				waitingForPos: { $ne: true } // Ne pas supprimer les commandes client en attente
			});
			if (deleteResult.deletedCount > 0) {
				console.log(`[sync] 🗑️ ${deleteResult.deletedCount} commande(s) active(s) supprimée(s) de MongoDB (état vide synchronisé)`);
			}
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
		} else {
			// 🆕 Si le tableau est vide (après reset), supprimer toutes les archives de MongoDB
			// pour garantir que l'état vide est bien synchronisé
			const deleteResult = await dbManager.archivedOrders.deleteMany({});
			if (deleteResult.deletedCount > 0) {
				console.log(`[sync] 🗑️ ${deleteResult.deletedCount} commande(s) archivée(s) supprimée(s) de MongoDB (état vide synchronisé)`);
			}

			// 🆕 SUPPRIMER les commandes archivées de la collection orders principale
			// pour éviter qu'elles réapparaissent au redémarrage
			if (dataStore.archivedOrders.length > 0) {
				const archivedIds = dataStore.archivedOrders.map(o => o.id);
				const deleteResult = await dbManager.orders.deleteMany({
					id: { $in: archivedIds }
				});
				console.log(`[sync] 🗑️ ${deleteResult.deletedCount} commande(s) supprimée(s) de orders (maintenant archivées)`);
			}
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
		} else {
			// 🆕 Si le tableau est vide (après reset), supprimer tous les crédits de MongoDB
			// pour garantir que l'état vide est bien synchronisé
			const deleteResult = await dbManager.clientCredits.deleteMany({});
			if (deleteResult.deletedCount > 0) {
				console.log(`[sync] 🗑️ ${deleteResult.deletedCount} crédit(s) client(s) supprimé(s) de MongoDB (état vide synchronisé)`);
			}
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
	loadFromMongoDB, // Pour compatibilité serveur cloud
	smartSyncWithMongoDB, // 🆕 Synchronisation intelligente
	pullFromMailbox // 🆕 Fonction d'aspiration pour polling périodique
};
