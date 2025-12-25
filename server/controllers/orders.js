// 📦 Contrôleur des commandes
// Gère toutes les opérations CRUD sur les commandes

const dataStore = require('../data');
const fileManager = require('../utils/fileManager');
const { getIO } = require('../utils/socket');
const dbManager = require('../utils/dbManager');

// Créer une commande
async function createOrder(req, res) {
	const io = getIO();
	console.log('[orders] POST /orders - Body:', JSON.stringify(req.body, null, 2));
	const { table, items, notes, server, covers, noteId, noteName } = req.body || {};
	if (!table || !Array.isArray(items) || items.length === 0) {
		console.log('[orders] Erreur: table ou items manquants');
		return res.status(400).json({ error: 'Requête invalide: table et items requis' });
	}
	
	// 🆕 Détecter si c'est une commande client
	// Critères : pas de serveur fourni ET pas de noteId fourni
	const isClientOrder = !server && !noteId;
	
	// 🆕 Assigner automatiquement le serveur pour les commandes client
	const { assignServerByTable } = require('../utils/serverAssignment');
	const assignedServer = isClientOrder 
		? assignServerByTable(table)
		: (server || 'unknown');
	
	const total = items.reduce((sum, it) => sum + (Number(it.price) * Number(it.quantity || 1)), 0);
	
	// 🆕 BONNE PRATIQUE : Seul le POS peut donner un ID à une commande
	// Les commandes client n'ont pas d'ID jusqu'à acceptation par le POS
	// Utiliser un ID temporaire unique pour les commandes client (timestamp + random)
	const tempId = isClientOrder 
		? `temp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
		: null;
	
	// Nouvelle structure avec support des sous-notes
	const newOrder = {
		id: isClientOrder ? null : dataStore.nextOrderId++, // 🆕 Pas d'ID pour commandes client
		tempId: tempId, // 🆕 ID temporaire unique pour commandes client (avant acceptation)
		table,
		server: assignedServer, // 🆕 Serveur assigné automatiquement pour les commandes client
		covers: covers || 1,
		notes: notes || '',
		status: isClientOrder ? 'pending_server_confirmation' : 'nouvelle', // 🆕 Statut différent pour commandes client
		source: isClientOrder ? 'client' : 'pos', // 🆕 Source de la commande
		serverConfirmed: !isClientOrder, // 🆕 Les commandes POS sont confirmées par défaut
		consumptionConfirmed: false,
		createdAt: new Date().toISOString(),
		// 🆕 Historique des paiements
		paymentHistory: [],
		// 🆕 Historique des actions (création de notes, ajouts d'articles)
		orderHistory: [],
		// Structure des notes
		mainNote: {
			id: 'main',
			name: 'Note Principale',
			covers: covers || 1,
			items: noteId === 'main' || !noteId ? items : [],
			total: noteId === 'main' || !noteId ? total : 0,
			paid: false
		},
		subNotes: noteId && noteId !== 'main' ? [{
			id: noteId,
			name: noteName || 'Client',
			covers: 1,
			items: items,
			total: total,
			paid: false,
			createdAt: new Date().toISOString()
		}] : [],
		total
	};
	
	// 🆕 Enregistrer l'état initial dans l'historique
	if (noteId === 'main' || !noteId) {
		newOrder.orderHistory.push({
			timestamp: new Date().toISOString(),
			action: 'order_created',
			noteId: 'main',
			noteName: 'Note Principale',
			items: items.map(it => ({ ...it })), // 🆕 Copier les articles pour éviter les références
			details: 'Création commande initiale'
		});
	} else {
		// 🆕 CORRECTION : Même méthode pour les sous-notes créées directement
		newOrder.orderHistory.push({
			timestamp: new Date().toISOString(),
			action: 'subnote_created',
			noteId: noteId,
			noteName: noteName || 'Client',
			items: items.map(it => ({ ...it })), // 🆕 Copier les articles pour éviter les références
			total: total,
			details: `Création sous-note "${noteName || 'Client'}" lors de la création de la commande`
		});
	}
	
	// 🆕 ARCHITECTURE "BOÎTE AUX LETTRES" : Le Cloud est muet, le Local est le patron
	if (isClientOrder) {
		// 🆕 CORRECTION : Si MongoDB est disponible, TOUJOURS insérer dans MongoDB
		// Peu importe isCloud - si MongoDB existe, c'est qu'on peut déposer la commande
		// Cela corrige le cas où Railway a isCloud=false mais doit quand même déposer dans MongoDB
		if (dbManager.db) {
			try {
				const orderToSave = { 
					...newOrder,
					waitingForPos: true, // 🆕 Marqueur : en attente du POS local
					processedByPos: false, // 🆕 Pas encore traitée par le POS
					id: null // 🆕 FORCER id à null (le POS local donnera l'ID)
				};
				delete orderToSave._id;

				await dbManager.orders.insertOne(orderToSave);
				console.log(`[orders] 📬 Commande client reçue. Déposée dans la boîte aux lettres (waitingForPos: true, tempId: ${newOrder.tempId})`);
			} catch (e) {
				console.error('[orders] ❌ Erreur dépôt MongoDB:', e.message);
				return res.status(500).json({ error: 'Erreur lors de la création de la commande' });
			}
		} else {
			// SERVEUR LOCAL SANS MONGODB : Ne devrait jamais arriver en production
			// Les commandes client arrivent normalement via MongoDB (aspirées par pullFromMailbox)
			console.warn('[orders] ⚠️ Commande client reçue sur serveur local SANS MongoDB - mode dégradé');
			dataStore.orders.push(newOrder);
			fileManager.savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
		}

		console.log('[orders] 🆕 Commande CLIENT créée (sans ID - en attente POS):', newOrder.tempId, 'pour table', table, 'serveur assigné:', assignedServer, 'total:', total, 'status:', newOrder.status);
	} else {
		// TOUJOURS ajouter au datastore local pour les commandes POS
		dataStore.orders.push(newOrder);
		console.log('[orders] Commande POS créée:', newOrder.id, 'pour table', table, 'serveur:', assignedServer, 'total:', total, 'note:', noteId || 'main');

		// Sauvegarder automatiquement (JSON local + MongoDB)
		fileManager.savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
	}
	
	// 📊 Récupérer TOUTES les commandes actives de la table pour l'état complet
	// Cela permet à l'app client de voir immédiatement toutes les commandes (POS + client) de la table
	const tableOrders = dataStore.orders.filter(o => 
		String(o.table) === String(table) && o.status !== 'archived'
	);
	
	// Calculer le total cumulé de toutes les commandes de la table
	const totalTableAmount = tableOrders.reduce((sum, o) => {
		// Calculer le total non payé de chaque commande
		let orderUnpaidTotal = 0;
		
		// Total note principale
		if (o.mainNote && o.mainNote.items) {
			for (const item of o.mainNote.items) {
				const paidQty = item.paidQuantity || 0;
				const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
				orderUnpaidTotal += (item.price || 0) * unpaidQty;
			}
		}
		
		// Total sous-notes
		if (o.subNotes) {
			for (const subNote of o.subNotes) {
				if (subNote.items && !subNote.paid) {
					for (const item of subNote.items) {
						const paidQty = item.paidQuantity || 0;
						const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
						orderUnpaidTotal += (item.price || 0) * unpaidQty;
					}
				}
			}
		}
		
		return sum + orderUnpaidTotal;
	}, 0);
	
	// 🔔 Notifier via Socket.IO
	io.emit('order:new', newOrder);
	
	// ✅ Retourner la nouvelle commande + état complet de la table
	// Format compatible avec l'ancien (retourne toujours la commande)
	// + nouvelles données pour synchronisation
	return res.status(201).json({
		// Compatibilité : retourner la commande directement (pour le POS)
		...newOrder,
		// 🆕 Nouvelles données pour synchronisation (pour l'app client)
		orderId: newOrder.id || newOrder.tempId, // ID ou tempId pour commandes client
		tempId: newOrder.tempId, // 🆕 ID temporaire pour commandes client (avant acceptation POS)
		tableState: {
			table: table,
			orders: tableOrders, // Toutes les commandes actives de la table
			totalOrders: tableOrders.length,
			totalAmount: totalTableAmount, // Total cumulé non payé
			lastUpdated: new Date().toISOString()
		}
	});
}

// Lister les commandes
async function getAllOrders(req, res) {
	const { table } = req.query;
	
	// 🆕 CORRECTION : Le serveur local est la source de vérité unique
	// Ne JAMAIS écraser dataStore.orders avec MongoDB dans getAllOrders
	// MongoDB sert uniquement de passerelle pour les commandes client
	// La synchronisation périodique (server-new.js) ajoute les nouvelles commandes client
	
	// Filtrer les commandes archivées
	const activeOrders = dataStore.orders.filter(o => o.status !== 'archived');
	const list = table ? activeOrders.filter(o => String(o.table) === String(table)) : activeOrders;
	
	// 🆕 Log pour debug : compter les commandes client
	const clientOrders = list.filter(o => o.source === 'client');
	if (clientOrders.length > 0) {
		console.log(`[orders] GET /orders: ${list.length} commandes actives, dont ${clientOrders.length} commande(s) client`);
		for (const order of clientOrders) {
			// 🆕 CORRECTION : Afficher tempId si id est null (commandes client sans ID officiel)
			const identifier = order.id ?? order.tempId ?? 'sans ID';
			console.log(`[orders]   - Commande client ${identifier}: table=${order.table}, status=${order.status}, server=${order.server}, serverConfirmed=${order.serverConfirmed}`);
		}
	} else {
		console.log(`[orders] GET /orders: ${list.length} commandes actives (aucune commande client)`);
		// 🆕 Log toutes les commandes pour debug
		if (list.length > 0) {
			console.log(`[orders]   Détail des commandes:`);
			for (const order of list) {
				// 🆕 CORRECTION : Afficher tempId si id est null (commandes client sans ID officiel)
				const identifier = order.id ?? order.tempId ?? 'sans ID';
				console.log(`[orders]     - ${identifier}: table=${order.table}, source=${order.source || 'undefined'}, status=${order.status}, server=${order.server}`);
			}
		}
	}
	
	return res.json(list);
}

// Récupérer une commande
function getOrderById(req, res) {
	const idOrTempId = req.params.id;
	
	// 🆕 BONNE PRATIQUE : Chercher par tempId si c'est une commande client, sinon par ID
	// Les commandes client ont tempId (string) avant acceptation, les commandes POS ont id (number)
	const order = dataStore.orders.find(o => 
		o.tempId === idOrTempId || o.id === Number(idOrTempId)
	);
	
	if (!order) return res.status(404).json({ error: 'Commande introuvable' });
	return res.json(order);
}

// Marquer une commande traitée
function updateOrder(req, res) {
	const io = getIO();
	const id = Number(req.params.id);
	const order = dataStore.orders.find(o => o.id === id);
	if (!order) return res.status(404).json({ error: 'Commande introuvable' });
	order.status = 'traitee';
	order.updatedAt = new Date().toISOString();
	fileManager.savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
	io.emit('order:updated', order);
	return res.json(order);
}

// Confirmation de consommation par le client
function confirmOrder(req, res) {
	const io = getIO();
	const id = Number(req.params.id);
	const order = dataStore.orders.find(o => o.id === id);
	if (!order) return res.status(404).json({ error: 'Commande introuvable' });
	order.consumptionConfirmed = true;
	order.updatedAt = new Date().toISOString();
	io.emit('order:confirmed', order);
	return res.json(order);
}

// 🆕 Confirmation d'une commande client par le serveur
async function confirmOrderByServer(req, res) {
	const io = getIO();
	const tempIdOrId = req.params.id; // Peut être un tempId (string) ou un ID (number)
	
	// 🆕 BONNE PRATIQUE : Chercher par tempId si c'est une commande client, sinon par ID
	const order = dataStore.orders.find(o => 
		o.tempId === tempIdOrId || o.id === Number(tempIdOrId)
	);
	
	if (!order) {
		return res.status(404).json({ error: 'Commande introuvable' });
	}
	
	// Vérifier que c'est une commande client
	if (order.source !== 'client') {
		return res.status(400).json({ error: 'Cette commande n\'est pas une commande client' });
	}
	
	// Vérifier qu'elle n'est pas déjà confirmée
	if (order.serverConfirmed) {
		return res.status(400).json({ error: 'Commande déjà confirmée par le serveur' });
	}
	
	// Vérifier que le statut est en attente
	if (order.status !== 'pending_server_confirmation') {
		return res.status(400).json({ error: 'Cette commande n\'est pas en attente de confirmation' });
	}
	
	// 🆕 BONNE PRATIQUE : Le POS donne maintenant un ID officiel à la commande client
	// Seul le POS peut donner un ID - c'est la source de vérité unique
	const oldTempId = order.tempId;
	const oldId = order.id;
	order.id = dataStore.nextOrderId++; // 🆕 ID officiel généré par le POS
	delete order.tempId; // 🆕 Supprimer l'ID temporaire
	order.originalTempId = oldTempId; // 🆕 Conserver pour supprimer l'ancienne entrée MongoDB
	
	// 🆕 CORRECTION : Convertir la commande client en commande POS normale
	// Selon les bonnes pratiques POS : une fois acceptée, elle devient une commande standard
	// On garde originalSource pour la traçabilité (rapports, analytics)
	const originalSource = order.source; // Sauvegarder l'origine pour traçabilité
	order.source = 'pos'; // 🆕 Devenir une commande POS normale (comportement identique)
	order.originalSource = originalSource; // 🆕 Traçabilité pour rapports/analytics
	order.serverConfirmed = true;
	order.status = 'nouvelle'; // Passer au statut normal
	order.confirmedAt = new Date().toISOString();
	order.confirmedBy = req.body.server || order.server; // Serveur qui confirme
	order.updatedAt = new Date().toISOString();
	
	// Initialiser orderHistory si absent
	if (!order.orderHistory) {
		order.orderHistory = [];
	}

	// 🆕 CORRECTION : Normaliser tous les événements existants dans orderHistory
	// pour qu'ils soient cohérents avec le nouvel ID et la nouvelle structure
	for (const event of order.orderHistory) {
		// Ajouter orderId si manquant (normalise tous les événements)
		if (!event.orderId) {
			event.orderId = order.id;
		}

		// Mettre à jour les références dans les détails si elles pointent vers l'ancien ID
		if (event.details && typeof event.details === 'string') {
			event.details = event.details
				.replace(new RegExp(oldTempId, 'g'), order.id.toString())
				.replace(new RegExp(oldId?.toString() || '', 'g'), order.id.toString());
		}

		// S'assurer que tous les événements ont la bonne structure
		if (!event.timestamp) {
			event.timestamp = event.createdAt || order.createdAt || new Date().toISOString();
		}

		// Nettoyer les champs obsolètes
		delete event.tempId;
		delete event._id;
	}

	// Enregistrer dans l'historique
	order.orderHistory.push({
		timestamp: new Date().toISOString(),
		action: 'server_confirmed',
		server: order.confirmedBy,
		orderId: order.id,
		details: `Commande client confirmée et convertie en commande POS par le serveur ${order.confirmedBy}`
	});

	// 🆕 AJOUTER UN ÉVÉNEMENT DE CORRECTION pour tracer les changements
	order.orderHistory.push({
		timestamp: new Date().toISOString(),
		action: 'order_normalized',
		orderId: order.id,
		details: `Événements orderHistory normalisés après confirmation (ancien tempId: ${oldTempId}, nouvel ID: ${order.id})`
	});
	
	console.log('[orders] ✅ Commande client (tempId: ' + oldTempId + ', ancien ID: ' + (oldId || 'null') + ') confirmée et reçoit ID officiel #' + order.id + ' par serveur:', order.confirmedBy, 'table:', order.table);
	console.log('[orders] ✅ Commande maintenant traitée comme commande POS normale (id=' + order.id + ', source=pos, originalSource=' + originalSource + ')');
	
	// 🆕 ARCHITECTURE "BOÎTE AUX LETTRES" : Supprimer de MongoDB après confirmation
	// Une commande confirmée n'a plus sa place dans MongoDB (gérée uniquement par le serveur local)
	// MongoDB ne doit contenir QUE les commandes client EN ATTENTE (waitingForPos=true)
	if (dbManager.db) {
		try {
			const deleteResult = await dbManager.orders.deleteMany({
				$or: [
					{ tempId: oldTempId },
					{ id: order.id }, // Supprimer si elle existe avec le nouvel ID
					{ tempId: oldTempId, waitingForPos: true } // Supprimer de la boîte aux lettres
				]
			});
			if (deleteResult.deletedCount > 0) {
				console.log(`[orders] 🗑️ Commande ${oldTempId} → #${order.id} SUPPRIMÉE de MongoDB (confirmée, gérée localement)`);
			}
		} catch (e) {
			console.error(`[orders] ⚠️ Erreur suppression MongoDB: ${e.message}`);
		}
	}

	// 🆕 SERVEUR LOCAL : Sauvegarde JSON uniquement (MongoDB déjà nettoyé)
	// La commande confirmée est maintenant UNIQUEMENT dans le JSON local (source de vérité)
	if (!dbManager.isCloud) {
		await fileManager.savePersistedData();
		console.log(`[orders] 💾 Commande #${order.id} sauvegardée en JSON local (source de vérité)`);
	}
	// 🆕 SERVEUR CLOUD : Ne PAS sauvegarder les commandes confirmées dans MongoDB
	// Car elles sont gérées par le serveur local (source de vérité)
	// Le serveur cloud est stateless et ne garde que les commandes en attente
	
	// 🆕 CORRECTION : Émettre order:new pour apparition dynamique dans le POS
	// Cela permet à la commande d'apparaître immédiatement dans le plan de table et la page Order
	io.emit('order:new', order);
	io.emit('order:updated', order);
	io.emit('order:server-confirmed', order);
	
	console.log('[orders] 📢 Commande notifiée via Socket.IO (order:new) pour apparition dynamique dans le POS');
	
	return res.json(order);
}

// 🆕 Décliner une commande client par le serveur
function declineOrderByServer(req, res) {
	const io = getIO();
	const tempIdOrId = req.params.id; // Peut être un tempId (string) ou un ID (number)
	const { reason } = req.body || {}; // Raison optionnelle du refus
	
	// 🆕 BONNE PRATIQUE : Chercher par tempId si c'est une commande client, sinon par ID
	const order = dataStore.orders.find(o => 
		o.tempId === tempIdOrId || o.id === Number(tempIdOrId)
	);
	
	if (!order) {
		return res.status(404).json({ error: 'Commande introuvable' });
	}
	
	// Vérifier que c'est une commande client
	if (order.source !== 'client') {
		return res.status(400).json({ error: 'Cette commande n\'est pas une commande client' });
	}
	
	// Vérifier qu'elle n'est pas déjà confirmée ou déclinée
	if (order.serverConfirmed) {
		return res.status(400).json({ error: 'Commande déjà confirmée par le serveur' });
	}
	
	if (order.status === 'declined') {
		return res.status(400).json({ error: 'Commande déjà déclinée' });
	}
	
	// Marquer comme déclinée
	order.status = 'declined';
	order.declinedAt = new Date().toISOString();
	order.declinedBy = req.body.server || order.server;
	order.declineReason = reason || 'Refusée par le serveur';
	order.updatedAt = new Date().toISOString();
	
	// Initialiser orderHistory si absent
	if (!order.orderHistory) {
		order.orderHistory = [];
	}
	
	// Enregistrer dans l'historique
	order.orderHistory.push({
		timestamp: new Date().toISOString(),
		action: 'server_declined',
		server: order.declinedBy,
		reason: order.declineReason,
		details: `Commande client déclinée par le serveur ${order.declinedBy}${reason ? ': ' + reason : ''}`
	});
	
	// Archiver immédiatement (ne pas garder dans les commandes actives)
	// 🆕 CORRECTION : Chercher par tempId si id est null (commandes client sans ID officiel)
	const idx = dataStore.orders.findIndex(o => 
		(order.id !== null && o.id === order.id) || 
		(order.tempId && o.tempId === order.tempId)
	);
	let archived;
	if (idx !== -1) {
		dataStore.orders.splice(idx, 1);
		archived = { 
			...order, 
			archivedAt: new Date().toISOString(),
			archivedReason: 'declined_by_server'
		};
		dataStore.archivedOrders.push(archived);
	} else {
		archived = order;
	}
	
	const identifier = order.tempId || order.id || 'sans ID';
	console.log('[orders] ❌ Commande client ' + identifier + ' déclinée par serveur:', order.declinedBy, 'table:', order.table, 'raison:', reason || 'Aucune');
	
	// Sauvegarder
	fileManager.savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
	
	// Synchroniser avec MongoDB si cloud activé
	if (dbManager.isCloud && dbManager.db) {
		(async () => {
			try {
				const orderToSave = { ...archived };
				delete orderToSave._id; // Éviter erreur MongoDB
				// 🆕 CORRECTION : Utiliser tempId si id est null pour MongoDB (commandes client sans ID officiel)
				const query = archived.id ? { id: archived.id } : { tempId: archived.tempId };
				await dbManager.orders.replaceOne(
					query,
					orderToSave,
					{ upsert: true }
				);
				const archivedIdentifier = archived.id ?? archived.tempId ?? 'sans ID';
				console.log(`[orders] ✅ Commande ${archivedIdentifier} synchronisée avec MongoDB après déclinaison`);
			} catch (e) {
				console.error(`[orders] ⚠️ Erreur synchronisation MongoDB: ${e.message}`);
			}
		})();
	}
	
	// Notifier via Socket.IO
	io.emit('order:declined', { orderId: archived.id, table: archived.table, reason: archived.declineReason });
	io.emit('order:archived', { orderId: archived.id, table: archived.table });
	
	return res.json({
		success: true,
		message: 'Commande déclinée avec succès',
		order: archived
	});
}

// Créer une sous-note
function createSubNote(req, res) {
	const io = getIO();
	const id = Number(req.params.id);
	const order = dataStore.orders.find(o => o.id === id);
	if (!order) return res.status(404).json({ error: 'Commande introuvable' });
	
	const { name, covers, items } = req.body || {};
	if (!name) return res.status(400).json({ error: 'Nom de la note requis' });
	
	// Initialiser subNotes si nécessaire (pour anciennes commandes)
	if (!order.subNotes) order.subNotes = [];
	
	const total = (items || []).reduce((sum, it) => sum + (Number(it.price) * Number(it.quantity || 1)), 0);
	const subNote = {
		id: `sub_${Date.now()}`,
		name,
		covers: covers || 1,
		items: items || [],
		total,
		paid: false,
		createdAt: new Date().toISOString()
	};
	
	order.subNotes.push(subNote);
	order.total += total;
	order.updatedAt = new Date().toISOString();
	
	// 🆕 Initialiser orderHistory si absent
	if (!order.orderHistory) {
		order.orderHistory = [];
	}
	
	// 🆕 Enregistrer la création de sous-note dans l'historique
	order.orderHistory.push({
		timestamp: new Date().toISOString(),
		action: 'subnote_created',
		noteId: subNote.id,
		noteName: name,
		items: (items || []).map(it => ({ ...it })), // 🆕 Copier les articles pour éviter les références
		total: total,
		details: `Création sous-note "${name}"`
	});
	
	console.log('[orders] Sous-note créée:', subNote.id, 'pour commande', id, 'nom:', name);
	console.log('[orders] ✅ Historique enregistré:', order.orderHistory[order.orderHistory.length - 1]);
	
	fileManager.savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
	io.emit('order:updated', order);
	return res.status(201).json({ ok: true, subNote, order });
}

// Ajouter des articles à une note spécifique
function addItemsToNote(req, res) {
	const io = getIO();
	const id = Number(req.params.id);
	const noteId = req.params.noteId;
	const order = dataStore.orders.find(o => o.id === id);
	if (!order) return res.status(404).json({ error: 'Commande introuvable' });
	
	const { items } = req.body || {};
	if (!items || !Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'Articles requis' });
	}
	
	// Initialiser les structures si nécessaire
	if (!order.mainNote) order.mainNote = { id: 'main', name: 'Note Principale', covers: order.covers || 1, items: [], total: 0, paid: false };
	if (!order.subNotes) order.subNotes = [];
	
	let targetNote;
	if (noteId === 'main') {
		targetNote = order.mainNote;
	} else {
		targetNote = order.subNotes.find(n => n.id === noteId);
	}
	
	if (!targetNote) return res.status(404).json({ error: 'Note introuvable' });
	
	// 🆕 Calculer le total des nouveaux articles ajoutés (pour l'historique)
	const itemsTotal = items.reduce((sum, it) => sum + (Number(it.price) * Number(it.quantity || 1)), 0);
	
	// 🆕 Ajouter les nouveaux articles (sans paidQuantity car ils ne sont pas encore payés)
	targetNote.items = targetNote.items || [];
	targetNote.items.push(...items);
	
	// 🆕 Recalculer targetNote.total depuis scratch : somme de tous les articles non payés
	let noteUnpaidTotal = 0;
	for (const item of targetNote.items) {
		const paidQty = item.paidQuantity || 0;
		const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
		noteUnpaidTotal += (item.price || 0) * unpaidQty;
	}
	targetNote.total = noteUnpaidTotal;
	
	// 🆕 Recalculer order.total depuis scratch : somme de tous les articles non payés de toutes les notes
	let orderUnpaidTotal = 0;
	
	// Total note principale
	if (order.mainNote && order.mainNote.items) {
		for (const item of order.mainNote.items) {
			const paidQty = item.paidQuantity || 0;
			const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
			orderUnpaidTotal += (item.price || 0) * unpaidQty;
		}
	}
	
	// Total sous-notes
	if (order.subNotes) {
		for (const subNote of order.subNotes) {
			if (subNote.items) {
				for (const item of subNote.items) {
					const paidQty = item.paidQuantity || 0;
					const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
					orderUnpaidTotal += (item.price || 0) * unpaidQty;
				}
			}
		}
	}
	
	order.total = orderUnpaidTotal;
	order.updatedAt = new Date().toISOString();
	
	// 🆕 Initialiser orderHistory si absent
	if (!order.orderHistory) {
		order.orderHistory = [];
	}
	
	// 🆕 Enregistrer l'ajout d'articles dans l'historique
	order.orderHistory.push({
		timestamp: new Date().toISOString(),
		action: 'items_added',
		noteId: noteId === 'main' ? 'main' : noteId,
		noteName: targetNote.name || 'Note Principale',
		items: items.map(it => ({ ...it })), // 🆕 Copier les articles pour éviter les références
		total: itemsTotal,
		details: `Ajout de ${items.length} article(s)`
	});
	
	console.log('[orders] Articles ajoutés à note', noteId, 'de commande', id, 'total:', itemsTotal);
	console.log('[orders] ✅ Historique enregistré:', order.orderHistory[order.orderHistory.length - 1]);
	
	// Sauvegarder
	fileManager.savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
	
	io.emit('order:updated', order);
	return res.json({ ok: true, order });
}

module.exports = {
	createOrder,
	getAllOrders,
	getOrderById,
	updateOrder,
	confirmOrder,
	confirmOrderByServer, // 🆕 Nouvelle fonction
	declineOrderByServer, // 🆕 Décliner une commande client
	createSubNote,
	addItemsToNote
};

