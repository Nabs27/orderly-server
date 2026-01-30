// 📄 Controller POS - Pré-additions
// Gère la création, modification et suppression des pré-additions (tickets de paiement partiel)

const dataStore = require('../data');
const fileManager = require('../utils/fileManager');
const { getIO } = require('../utils/socket');

// Créer une pré-addition
async function createPreaddition(req, res) {
	const io = getIO();
	const { orderId } = req.params;
	const {
		noteId, // 'main', 'sub_xxx', ou 'partial'
		items, // Liste des articles sélectionnés
		total,
		discount = 0,
		isPercentDiscount = false,
		discountClientName = null,
		selectedPartialQuantities = {} // Map itemId -> quantity pour paiement partiel
	} = req.body;

	console.log('[preaddition] POST /orders/:orderId/preadditions - orderId:', orderId);
	console.log('[preaddition] Body:', JSON.stringify(req.body, null, 2));

	if (!orderId || !items || !Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'orderId et items requis' });
	}

	const order = dataStore.orders.find(o => o.id === Number(orderId));
	if (!order) {
		return res.status(404).json({ error: 'Commande introuvable' });
	}

	// Initialiser pendingPreadditions si nécessaire
	if (!order.pendingPreadditions) {
		order.pendingPreadditions = [];
	}

	// Créer la pré-addition
	const preaddition = {
		id: `preadd_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
		createdAt: new Date().toISOString(),
		noteId: noteId || 'partial',
		items: items.map(it => ({ ...it })), // Copier pour éviter les références
		total: Number(total) || 0,
		discount: Number(discount) || 0,
		isPercentDiscount: Boolean(isPercentDiscount),
		discountClientName: discountClientName || null,
		selectedPartialQuantities: selectedPartialQuantities || {},
		server: order.server || 'unknown',
		table: order.table
	};

	order.pendingPreadditions.push(preaddition);
	order.updatedAt = new Date().toISOString();

	// Enregistrer dans l'historique
	if (!order.orderHistory) {
		order.orderHistory = [];
	}
	order.orderHistory.push({
		timestamp: new Date().toISOString(),
		action: 'preaddition_created',
		noteId: noteId || 'partial',
		items: items.map(it => ({ ...it })),
		total: preaddition.total,
		details: `Pré-addition créée (${items.length} article(s), ${preaddition.total.toFixed(2)} TND)`
	});

	// Sauvegarder
	await fileManager.savePersistedData();

	console.log('[preaddition] ✅ Pré-addition créée:', preaddition.id);

	// Émettre événement
	io.emit('order:updated', order);

	return res.json({
		ok: true,
		preaddition: preaddition,
		order: order
	});
}

// Supprimer une pré-addition
async function deletePreaddition(req, res) {
	const io = getIO();
	const { orderId, preadditionId } = req.params;

	console.log('[preaddition] DELETE /orders/:orderId/preadditions/:preadditionId');
	console.log('[preaddition] orderId:', orderId, 'preadditionId:', preadditionId);

	const order = dataStore.orders.find(o => o.id === Number(orderId));
	if (!order) {
		return res.status(404).json({ error: 'Commande introuvable' });
	}

	if (!order.pendingPreadditions || !Array.isArray(order.pendingPreadditions)) {
		return res.status(404).json({ error: 'Aucune pré-addition trouvée' });
	}

	const index = order.pendingPreadditions.findIndex(p => p.id === preadditionId);
	if (index === -1) {
		return res.status(404).json({ error: 'Pré-addition introuvable' });
	}

	const deleted = order.pendingPreadditions.splice(index, 1)[0];
	order.updatedAt = new Date().toISOString();

	// Enregistrer dans l'historique
	if (!order.orderHistory) {
		order.orderHistory = [];
	}
	order.orderHistory.push({
		timestamp: new Date().toISOString(),
		action: 'preaddition_deleted',
		noteId: deleted.noteId,
		details: `Pré-addition supprimée (${deleted.total.toFixed(2)} TND)`
	});

	// Sauvegarder
	await fileManager.savePersistedData();

	console.log('[preaddition] ✅ Pré-addition supprimée:', preadditionId);

	// Émettre événement
	io.emit('order:updated', order);

	return res.json({
		ok: true,
		message: 'Pré-addition supprimée',
		order: order
	});
}

// Modifier une pré-addition
async function updatePreaddition(req, res) {
	const io = getIO();
	const { orderId, preadditionId } = req.params;
	const {
		items,
		total,
		discount,
		isPercentDiscount,
		discountClientName,
		selectedPartialQuantities
	} = req.body;

	console.log('[preaddition] PUT /orders/:orderId/preadditions/:preadditionId');
	console.log('[preaddition] orderId:', orderId, 'preadditionId:', preadditionId);

	const order = dataStore.orders.find(o => o.id === Number(orderId));
	if (!order) {
		return res.status(404).json({ error: 'Commande introuvable' });
	}

	if (!order.pendingPreadditions || !Array.isArray(order.pendingPreadditions)) {
		return res.status(404).json({ error: 'Aucune pré-addition trouvée' });
	}

	const preaddition = order.pendingPreadditions.find(p => p.id === preadditionId);
	if (!preaddition) {
		return res.status(404).json({ error: 'Pré-addition introuvable' });
	}

	// Mettre à jour les champs fournis
	if (items !== undefined) {
		preaddition.items = items.map(it => ({ ...it }));
	}
	if (total !== undefined) {
		preaddition.total = Number(total);
	}
	if (discount !== undefined) {
		preaddition.discount = Number(discount);
	}
	if (isPercentDiscount !== undefined) {
		preaddition.isPercentDiscount = Boolean(isPercentDiscount);
	}
	if (discountClientName !== undefined) {
		preaddition.discountClientName = discountClientName;
	}
	if (selectedPartialQuantities !== undefined) {
		preaddition.selectedPartialQuantities = selectedPartialQuantities;
	}

	preaddition.updatedAt = new Date().toISOString();
	order.updatedAt = new Date().toISOString();

	// Enregistrer dans l'historique
	if (!order.orderHistory) {
		order.orderHistory = [];
	}
	order.orderHistory.push({
		timestamp: new Date().toISOString(),
		action: 'preaddition_updated',
		noteId: preaddition.noteId,
		items: preaddition.items.map(it => ({ ...it })),
		total: preaddition.total,
		details: `Pré-addition modifiée (${preaddition.items.length} article(s), ${preaddition.total.toFixed(2)} TND)`
	});

	// Sauvegarder
	await fileManager.savePersistedData();

	console.log('[preaddition] ✅ Pré-addition modifiée:', preadditionId);

	// Émettre événement
	io.emit('order:updated', order);

	return res.json({
		ok: true,
		preaddition: preaddition,
		order: order
	});
}

module.exports = {
	createPreaddition,
	deletePreaddition,
	updatePreaddition
};
