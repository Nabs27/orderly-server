// 🔄 Controller POS - Transferts
// Gère les transferts d'articles, de tables et de serveurs

const dataStore = require('../data');
const fileManager = require('../utils/fileManager');
const { getIO } = require('../utils/socket');

// Transfert d'articles entre notes ou tables
async function transferItems(req, res) {
	const io = getIO();
	const { fromTable, fromOrderId, fromNoteId, toTable, toOrderId, toNoteId, items, createNote, noteName, createTable, tableNumber, covers } = req.body || {};
	
	if (!fromTable || !items || !Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'Paramètres manquants' });
	}
	
	console.log('[transfer] Transfert:', items.length, 'articles de table', fromTable, 'note', fromNoteId, 'vers table', toTable || 'nouvelle table', 'createNote:', createNote, 'noteName:', noteName);
	
	// Trouver la commande source
	const fromOrder = dataStore.orders.find(o => String(o.table) === String(fromTable) && (fromOrderId ? o.id === Number(fromOrderId) : true));
	if (!fromOrder) return res.status(404).json({ error: 'Commande source introuvable' });
	
	// Initialiser structures si nécessaire
	if (!fromOrder.mainNote) fromOrder.mainNote = { id: 'main', name: 'Note Principale', covers: fromOrder.covers || 1, items: fromOrder.items || [], total: fromOrder.total || 0, paid: false };
	if (!fromOrder.subNotes) fromOrder.subNotes = [];
	if (!fromOrder.orderHistory) fromOrder.orderHistory = [];
	
	// Trouver la note source
	let fromNote;
	if (!fromNoteId || fromNoteId === 'main') {
		fromNote = fromOrder.mainNote;
	} else {
		fromNote = fromOrder.subNotes.find(n => n.id === fromNoteId);
	}
	if (!fromNote) return res.status(404).json({ error: 'Note source introuvable' });
	
	// 🆕 Préparer les articles à transférer en vérifiant paidQuantity
	// On ne peut transférer que les quantités NON PAYÉES
	const itemsToTransfer = [];
	let transferTotal = 0;
	
	items.forEach(transferItem => {
		const idx = fromNote.items.findIndex(it => 
			it.id === transferItem.id && it.name === transferItem.name
		);
		if (idx !== -1) {
			const existing = fromNote.items[idx];
			const requestedQuantity = Number(transferItem.quantity || 1);
			
			// 🆕 Calculer la quantité non payée disponible
			const paidQty = existing.paidQuantity || 0;
			const totalQty = existing.quantity || 0;
			const unpaidQty = Math.max(0, totalQty - paidQty);
			
			// 🆕 Ne transférer que la quantité non payée
			const quantityToTransfer = Math.min(requestedQuantity, unpaidQty);
			
			if (quantityToTransfer > 0) {
				// Créer un nouvel article pour le transfert (sans paidQuantity car non payé dans la nouvelle note)
				itemsToTransfer.push({
					id: existing.id,
					name: existing.name,
					price: existing.price,
					quantity: quantityToTransfer,
					// paidQuantity n'est pas inclus - les articles transférés sont non payés
				});
				
				transferTotal += Number(existing.price) * quantityToTransfer;
				
				// 🆕 Retirer la quantité transférée de la note source
				if (quantityToTransfer < unpaidQty) {
					// Réduire seulement la quantité non payée (on garde paidQuantity intact)
					existing.quantity = totalQty - quantityToTransfer;
				} else {
					// Tout le non payé est transféré, on retire l'article seulement si totalQty == quantityToTransfer
					// Mais si paidQuantity > 0, on doit garder l'article avec seulement paidQuantity
					if (paidQty > 0) {
						// Il reste des articles payés, on garde seulement ceux-ci
						existing.quantity = paidQty;
						existing.paidQuantity = paidQty; // Maintenir paidQuantity
					} else {
						// Rien n'est payé, on peut retirer complètement l'article
						fromNote.items.splice(idx, 1);
					}
				}
			}
		}
	});
	
	// 🆕 Recalculer les totaux depuis scratch (comme dans addItemsToNote)
	// Total note source
	let fromNoteUnpaidTotal = 0;
	for (const item of fromNote.items) {
		const paidQty = item.paidQuantity || 0;
		const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
		fromNoteUnpaidTotal += (item.price || 0) * unpaidQty;
	}
	fromNote.total = fromNoteUnpaidTotal;
	
	// Total commande source
	let fromOrderUnpaidTotal = 0;
	if (fromOrder.mainNote && fromOrder.mainNote.items) {
		for (const item of fromOrder.mainNote.items) {
			const paidQty = item.paidQuantity || 0;
			const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
			fromOrderUnpaidTotal += (item.price || 0) * unpaidQty;
		}
	}
	if (fromOrder.subNotes) {
		for (const subNote of fromOrder.subNotes) {
			if (subNote.items) {
				for (const item of subNote.items) {
					const paidQty = item.paidQuantity || 0;
					const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
					fromOrderUnpaidTotal += (item.price || 0) * unpaidQty;
				}
			}
		}
	}
	fromOrder.total = fromOrderUnpaidTotal;
	
	// Utiliser itemsToTransfer au lieu de items pour la suite
	if (itemsToTransfer.length === 0) {
		return res.status(400).json({ error: 'Aucun article non payé à transférer' });
	}
	
	// 🆕 Enregistrer le transfert dans l'historique de la commande source
	const transferTimestamp = new Date().toISOString();
	const transferTarget = toTable ? `table ${toTable}` : (createTable ? `nouvelle table ${tableNumber}` : `note ${toNoteId}`);
	fromOrder.orderHistory.push({
		timestamp: transferTimestamp,
		action: 'items_transferred',
		noteId: fromNoteId === 'main' ? 'main' : fromNoteId,
		noteName: fromNote.name || 'Note Principale',
		items: items.map(it => ({
			id: it.id,
			name: it.name,
			price: it.price,
			quantity: it.quantity || 1
		})),
		details: `${itemsToTransfer.length} article(s) transféré(s) vers ${transferTarget} (${transferTotal.toFixed(2)} TND)`,
		transferTo: {
			table: toTable || tableNumber,
			orderId: toOrderId ? Number(toOrderId) : null,
			noteId: toNoteId,
			total: transferTotal
		}
	});
	
	// Créer ou trouver la commande destination
	let toOrder;
	if (createTable && tableNumber) {
		// Créer une nouvelle table/commande
		toOrder = {
			id: dataStore.nextOrderId++,
			table: tableNumber,
			server: fromOrder.server,
			covers: covers || 1,
			notes: '',
			status: 'nouvelle',
			consumptionConfirmed: false,
			createdAt: new Date().toISOString(),
			mainNote: {
				id: 'main',
				name: 'Note Principale',
				covers: covers || 1,
				items: createNote ? [] : itemsToTransfer.map(it => ({ ...it })), // 🆕 Copier sans paidQuantity
				total: createNote ? 0 : transferTotal,
				paid: false
			},
			subNotes: createNote ? [{
				id: `sub_${Date.now()}`,
				name: noteName || 'Client',
				covers: 1,
				items: itemsToTransfer.map(it => ({ ...it })), // 🆕 Copier sans paidQuantity
				total: transferTotal,
				paid: false,
				createdAt: new Date().toISOString()
			}] : [],
			total: transferTotal,
			paymentHistory: [],
			orderHistory: []
		};
		
		// 🆕 Enregistrer dans l'historique de la nouvelle commande
		toOrder.orderHistory.push({
			timestamp: transferTimestamp,
			action: 'order_created_from_transfer',
			noteId: createNote ? (toOrder.subNotes[0]?.id || 'main') : 'main',
			noteName: createNote ? (noteName || 'Client') : 'Note Principale',
				items: itemsToTransfer.map(it => ({
					id: it.id,
					name: it.name,
					price: it.price,
					quantity: it.quantity || 1
				})),
			details: `Commande créée par transfert de table ${fromTable} (${itemsToTransfer.length} article(s), ${transferTotal.toFixed(2)} TND)`,
			transferFrom: {
				table: fromTable,
				orderId: fromOrder.id,
				noteId: fromNoteId
			}
		});
		
		dataStore.orders.push(toOrder);
		console.log('[transfer] Nouvelle table créée:', tableNumber);
		
		// Émettre événement pour notifier le plan de table
		const tableCreatedEvent = {
			tableNumber: tableNumber,
			server: fromOrder.server,
			covers: covers,
			orderId: toOrder.id,
			total: transferTotal
		};
		console.log('[transfer] Émission événement table:created:', tableCreatedEvent);
		io.emit('table:created', tableCreatedEvent);
	} else {
		// Trouver ou créer la commande destination
		toOrder = dataStore.orders.find(o => String(o.table) === String(toTable) && (toOrderId ? o.id === Number(toOrderId) : true));
		
		if (!toOrder) {
			// Créer une nouvelle commande pour la table destination
			toOrder = {
				id: dataStore.nextOrderId++,
				table: toTable,
				server: fromOrder.server,
				covers: 1,
				notes: '',
				status: 'nouvelle',
				consumptionConfirmed: false,
				createdAt: new Date().toISOString(),
				mainNote: {
					id: 'main',
					name: 'Note Principale',
					covers: 1,
					items: createNote ? [] : itemsToTransfer.map(it => ({ ...it })), // 🆕 Copier sans paidQuantity
					total: createNote ? 0 : transferTotal,
					paid: false
				},
				subNotes: createNote ? [{
					id: `sub_${Date.now()}`,
					name: noteName || 'Client',
					covers: 1,
					items: itemsToTransfer.map(it => ({ ...it })), // 🆕 Copier sans paidQuantity
					total: transferTotal,
					paid: false,
					createdAt: new Date().toISOString()
				}] : [],
				total: transferTotal,
				paymentHistory: [],
				orderHistory: []
			};
			
			// 🆕 Enregistrer dans l'historique de la nouvelle commande
			toOrder.orderHistory.push({
				timestamp: transferTimestamp,
				action: 'order_created_from_transfer',
				noteId: createNote ? (toOrder.subNotes[0]?.id || 'main') : 'main',
				noteName: createNote ? (noteName || 'Client') : 'Note Principale',
			items: itemsToTransfer.map(it => ({
				id: it.id,
				name: it.name,
				price: it.price,
				quantity: it.quantity || 1
			})),
			details: `Commande créée par transfert de table ${fromTable} (${itemsToTransfer.length} article(s), ${transferTotal.toFixed(2)} TND)`,
				transferFrom: {
					table: fromTable,
					orderId: fromOrder.id,
					noteId: fromNoteId
				}
			});
			
			dataStore.orders.push(toOrder);
			console.log('[transfer] Nouvelle commande créée pour table', toTable);
		} else {
			// Initialiser structures si nécessaire
			if (!toOrder.mainNote) toOrder.mainNote = { id: 'main', name: 'Note Principale', covers: toOrder.covers || 1, items: [], total: 0, paid: false };
			if (!toOrder.subNotes) toOrder.subNotes = [];
			if (!toOrder.orderHistory) toOrder.orderHistory = [];
			
			// Trouver ou créer la note destination
			let toNote;
			if (!toNoteId || toNoteId === 'main') {
				toNote = toOrder.mainNote;
			} else {
				toNote = toOrder.subNotes.find(n => n.id === toNoteId);
				if (!toNote && createNote) {
					toNote = {
						id: toNoteId,
						name: noteName || 'Client',
						covers: 1,
						items: [],
						total: 0,
						paid: false,
						createdAt: new Date().toISOString()
					};
					toOrder.subNotes.push(toNote);
				}
			}
			
			if (!toNote) return res.status(404).json({ error: 'Note destination introuvable' });
			
			// 🆕 Ajouter les articles à la note destination (sans paidQuantity car non payés)
			itemsToTransfer.forEach(transferItem => {
				const existingIdx = toNote.items.findIndex(it => it.id === transferItem.id && it.name === transferItem.name);
				if (existingIdx !== -1) {
					// Fusionner avec l'article existant (ajouter la quantité)
					toNote.items[existingIdx].quantity += transferItem.quantity;
					// Si l'article existant avait un paidQuantity, on le garde (les nouveaux articles sont non payés)
				} else {
					// Nouvel article : copier sans paidQuantity (par défaut undefined = 0)
					toNote.items.push({
						id: transferItem.id,
						name: transferItem.name,
						price: transferItem.price,
						quantity: transferItem.quantity,
						// paidQuantity non inclus = 0 par défaut
					});
				}
			});
			
			// 🆕 Recalculer les totaux depuis scratch (comme dans addItemsToNote)
			// Total note destination
			let toNoteUnpaidTotal = 0;
			for (const item of toNote.items) {
				const paidQty = item.paidQuantity || 0;
				const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
				toNoteUnpaidTotal += (item.price || 0) * unpaidQty;
			}
			toNote.total = toNoteUnpaidTotal;
			
			// Total commande destination
			let toOrderUnpaidTotal = 0;
			if (toOrder.mainNote && toOrder.mainNote.items) {
				for (const item of toOrder.mainNote.items) {
					const paidQty = item.paidQuantity || 0;
					const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
					toOrderUnpaidTotal += (item.price || 0) * unpaidQty;
				}
			}
			if (toOrder.subNotes) {
				for (const subNote of toOrder.subNotes) {
					if (subNote.items) {
						for (const item of subNote.items) {
							const paidQty = item.paidQuantity || 0;
							const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
							toOrderUnpaidTotal += (item.price || 0) * unpaidQty;
						}
					}
				}
			}
			toOrder.total = toOrderUnpaidTotal;
			
			// 🆕 Enregistrer le transfert dans l'historique de la commande destination
			toOrder.orderHistory.push({
				timestamp: transferTimestamp,
				action: 'items_transferred_in',
				noteId: toNoteId === 'main' ? 'main' : toNoteId,
				noteName: toNote.name || 'Note Principale',
				items: itemsToTransfer.map(it => ({
					id: it.id,
					name: it.name,
					price: it.price,
					quantity: it.quantity || 1
				})),
				details: `${itemsToTransfer.length} article(s) reçu(s) depuis table ${fromTable} (${transferTotal.toFixed(2)} TND)`,
				transferFrom: {
					table: fromTable,
					orderId: fromOrder.id,
					noteId: fromNoteId
				}
			});
		}
	}
	
	// Sauvegarder
	await fileManager.savePersistedData();
	
	// Émettre événements pour synchronisation temps réel
	io.emit('order:updated', fromOrder);
	if (toOrder) {
		io.emit('order:updated', toOrder);
	}
	
	return res.json({ 
		ok: true, 
		fromOrder, 
		toOrder,
		transferred: { items: itemsToTransfer.length, total: transferTotal }
	});
}

// Transfert complet de table
async function transferCompleteTable(req, res) {
	const io = getIO();
	const { fromTable, toTable, server, createTable, covers } = req.body || {};
	
	if (!fromTable || !toTable) {
		return res.status(400).json({ error: 'Tables source et destination requises' });
	}
	
	if (fromTable === toTable) {
		return res.status(400).json({ error: 'Les tables source et destination doivent être différentes' });
	}
	
	console.log('[transfer-complete] Transfert COMPLET de table', fromTable, 'vers', toTable, 'createTable:', createTable);
	
	// Récupérer toutes les commandes de la table source
	const fromOrders = dataStore.orders.filter(o => String(o.table) === String(fromTable));
	
	if (fromOrders.length === 0) {
		return res.status(404).json({ error: 'Aucune commande sur la table source' });
	}
	
	// Calculer le total global
	const totalAmount = fromOrders.reduce((sum, o) => sum + Number(o.total || 0), 0);
	
	const transferTimestamp = new Date().toISOString();
	
	// Changer simplement le numéro de table pour toutes les commandes et enregistrer dans l'historique
	fromOrders.forEach(order => {
		order.table = toTable;
		order.updatedAt = transferTimestamp;
		
		// 🆕 Initialiser orderHistory si absent
		if (!order.orderHistory) {
			order.orderHistory = [];
		}
		
		// 🆕 Enregistrer le transfert complet de table dans l'historique
		order.orderHistory.push({
			timestamp: transferTimestamp,
			action: 'table_transferred',
			noteId: 'main',
			noteName: 'Note Principale',
			items: [],
			details: `Table transférée de ${fromTable} vers ${toTable} (transfert complet avec ${fromOrders.length} commande(s), ${totalAmount.toFixed(2)} TND)`,
			transferInfo: {
				fromTable,
				toTable,
				ordersCount: fromOrders.length,
				total: totalAmount
			}
		});
		
		console.log('[transfer-complete] Commande', order.id, 'transférée de table', fromTable, 'vers', toTable);
	});
	
	console.log(`[transfer-complete] ${fromOrders.length} commande(s) transférée(s)`);
	
	// Sauvegarder
	await fileManager.savePersistedData();
	
	// Émettre événements pour mise à jour en temps réel
	fromOrders.forEach(order => io.emit('order:updated', order));
	io.emit('table:transferred', { 
		fromTable, 
		toTable, 
		ordersCount: fromOrders.length,
		server: server,
		covers: covers || 1,
		total: totalAmount,
		createTable: createTable
	});
	
	return res.json({ 
		ok: true, 
		message: `Table ${fromTable} transférée vers ${toTable}`,
		ordersTransferred: fromOrders.length,
		orders: fromOrders
	});
}

// Transfert de serveur
async function transferServer(req, res) {
	const io = getIO();
	const { table, newServer } = req.body || {};
	
	if (!table || !newServer) {
		return res.status(400).json({ error: 'Table et nouveau serveur requis' });
	}
	
	console.log('[transfer-server] Changement serveur table', table, 'vers', newServer);
	
	// Récupérer toutes les commandes de la table
	const tableOrders = dataStore.orders.filter(o => String(o.table) === String(table));
	
	if (tableOrders.length === 0) {
		return res.status(404).json({ error: 'Aucune commande sur cette table' });
	}
	
	const transferTimestamp = new Date().toISOString();
	const oldServer = tableOrders[0]?.server || 'INCONNU';
	
	// Mettre à jour le serveur pour toutes les commandes et enregistrer dans l'historique
	tableOrders.forEach(order => {
		const previousServer = order.server;
		order.server = newServer;
		order.updatedAt = transferTimestamp;
		
		// 🆕 Initialiser orderHistory si absent
		if (!order.orderHistory) {
			order.orderHistory = [];
		}
		
		// 🆕 Enregistrer le transfert de serveur dans l'historique
		order.orderHistory.push({
			timestamp: transferTimestamp,
			action: 'server_transferred',
			noteId: 'main',
			noteName: 'Note Principale',
			items: [],
			details: `Serveur changé de ${previousServer} vers ${newServer}`,
			transferInfo: {
				fromServer: previousServer,
				toServer: newServer,
				table
			}
		});
	});
	
	console.log(`[transfer-server] ${tableOrders.length} commande(s) réassignée(s) à`, newServer);
	
	// Sauvegarder
	await fileManager.savePersistedData();
	
	// Émettre événement pour mise à jour en temps réel
	io.emit('server:transferred', { table, newServer, ordersCount: tableOrders.length });
	
	return res.json({ 
		ok: true, 
		message: `Table ${table} transférée au serveur ${newServer}`,
		ordersUpdated: tableOrders.length
	});
}

module.exports = {
	transferItems,
	transferCompleteTable,
	transferServer
};

