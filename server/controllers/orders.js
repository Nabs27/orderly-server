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
	
	const total = items.reduce((sum, it) => sum + (Number(it.price) * Number(it.quantity || 1)), 0);
	
	// Nouvelle structure avec support des sous-notes
	const newOrder = {
		id: dataStore.nextOrderId++,
		table,
		server: server || 'unknown',
		covers: covers || 1,
		notes: notes || '',
		status: 'nouvelle',
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
	console.log('[orders] Commande créée:', newOrder.id, 'pour table', table, 'total:', total, 'note:', noteId || 'main');
	
	// 💾 Sauvegarder automatiquement
	fileManager.savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
	
	io.emit('order:new', newOrder);
	return res.status(201).json(newOrder);
}

// Lister les commandes
function getAllOrders(req, res) {
	const { table } = req.query;
	// Filtrer les commandes archivées
	const activeOrders = dataStore.orders.filter(o => o.status !== 'archived');
	const list = table ? activeOrders.filter(o => String(o.table) === String(table)) : activeOrders;
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
	createSubNote,
	addItemsToNote
};

