// 📦 Contrôleur des commandes
// Gère toutes les opérations CRUD sur les commandes

const dataStore = require('../data');
const fileManager = require('../utils/fileManager');
const { getIO } = require('../utils/socket');

// Créer une commande
function createOrder(req, res) {
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
	
	// Nouvelle structure avec support des sous-notes
	const newOrder = {
		id: dataStore.nextOrderId++,
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
	
	dataStore.orders.push(newOrder);
	
	// 🆕 Log différencié selon la source
	if (isClientOrder) {
		console.log('[orders] 🆕 Commande CLIENT créée:', newOrder.id, 'pour table', table, 'serveur assigné:', assignedServer, 'total:', total, 'status:', newOrder.status, 'source:', newOrder.source);
		console.log('[orders] 🆕 Structure commande client:', JSON.stringify({
			id: newOrder.id,
			table: newOrder.table,
			server: newOrder.server,
			status: newOrder.status,
			source: newOrder.source,
			serverConfirmed: newOrder.serverConfirmed,
			mainNote: { total: newOrder.mainNote.total, items: newOrder.mainNote.items.length }
		}, null, 2));
	} else {
		console.log('[orders] Commande POS créée:', newOrder.id, 'pour table', table, 'serveur:', assignedServer, 'total:', total, 'note:', noteId || 'main');
	}
	
	// 💾 Sauvegarder automatiquement
	fileManager.savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
	
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
		orderId: newOrder.id, // ID généré par le POS (source de vérité unique)
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
	
	// 🆕 CORRECTION : Si on est en mode cloud, recharger depuis MongoDB à chaque requête
	// Cela permet de voir les commandes créées par le serveur cloud (app client)
	const dbManager = require('../utils/dbManager');
	if (dbManager.isCloud && dbManager.db) {
		try {
			// Recharger les commandes depuis MongoDB pour avoir les dernières données
			const cloudOrders = await dbManager.orders.find({}).toArray();
			const cloudArchived = await dbManager.archivedOrders.find({}).toArray();
			
			// Mettre à jour dataStore avec les données MongoDB
			dataStore.orders.length = 0;
			dataStore.orders.push(...cloudOrders);
			dataStore.archivedOrders.length = 0;
			dataStore.archivedOrders.push(...cloudArchived);
			
			// Mettre à jour les compteurs depuis MongoDB
			const countersDoc = await dbManager.counters.findOne({ type: 'global' });
			if (countersDoc) {
				dataStore.nextOrderId = Math.max(dataStore.nextOrderId, countersDoc.nextOrderId || 1);
				dataStore.nextBillId = Math.max(dataStore.nextBillId, countersDoc.nextBillId || 1);
				dataStore.nextServiceId = Math.max(dataStore.nextServiceId, countersDoc.nextServiceId || 1);
				dataStore.nextClientId = Math.max(dataStore.nextClientId, countersDoc.nextClientId || 1);
			}
			
			console.log(`[orders] ☁️ Données rechargées depuis MongoDB: ${cloudOrders.length} commandes actives`);
		} catch (e) {
			console.error('[orders] ⚠️ Erreur rechargement MongoDB:', e.message);
			// Continuer avec les données en mémoire en cas d'erreur
		}
	}
	
	// Filtrer les commandes archivées
	const activeOrders = dataStore.orders.filter(o => o.status !== 'archived');
	const list = table ? activeOrders.filter(o => String(o.table) === String(table)) : activeOrders;
	
	// 🆕 Log pour debug : compter les commandes client
	const clientOrders = list.filter(o => o.source === 'client');
	if (clientOrders.length > 0) {
		console.log(`[orders] GET /orders: ${list.length} commandes actives, dont ${clientOrders.length} commande(s) client`);
		for (const order of clientOrders) {
			console.log(`[orders]   - Commande client #${order.id}: table=${order.table}, status=${order.status}, server=${order.server}, serverConfirmed=${order.serverConfirmed}`);
		}
	} else {
		console.log(`[orders] GET /orders: ${list.length} commandes actives (aucune commande client)`);
		// 🆕 Log toutes les commandes pour debug
		if (list.length > 0) {
			console.log(`[orders]   Détail des commandes:`);
			for (const order of list) {
				console.log(`[orders]     - #${order.id}: table=${order.table}, source=${order.source || 'undefined'}, status=${order.status}, server=${order.server}`);
			}
		}
	}
	
	return res.json(list);
}

// Récupérer une commande
function getOrderById(req, res) {
	const id = Number(req.params.id);
	const order = dataStore.orders.find(o => o.id === id);
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
function confirmOrderByServer(req, res) {
	const io = getIO();
	const id = Number(req.params.id);
	const order = dataStore.orders.find(o => o.id === id);
	
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
	
	// Confirmer la commande
	order.serverConfirmed = true;
	order.status = 'nouvelle'; // Passer au statut normal
	order.confirmedAt = new Date().toISOString();
	order.confirmedBy = req.body.server || order.server; // Serveur qui confirme
	order.updatedAt = new Date().toISOString();
	
	// Initialiser orderHistory si absent
	if (!order.orderHistory) {
		order.orderHistory = [];
	}
	
	// Enregistrer dans l'historique
	order.orderHistory.push({
		timestamp: new Date().toISOString(),
		action: 'server_confirmed',
		server: order.confirmedBy,
		details: `Commande client confirmée par le serveur ${order.confirmedBy}`
	});
	
	console.log('[orders] Commande client confirmée:', id, 'par serveur:', order.confirmedBy, 'table:', order.table);
	
	// Sauvegarder
	fileManager.savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
	
	// Notifier via Socket.IO
	io.emit('order:updated', order);
	io.emit('order:server-confirmed', order);
	
	return res.json(order);
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
	createSubNote,
	addItemsToNote
};

