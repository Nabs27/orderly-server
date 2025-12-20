// 💳 Controller POS - Paiements
// Gère les paiements (suppression d'articles, paiement multi-commandes)

const dataStore = require('../data');
const fileManager = require('../utils/fileManager');
const { getIO } = require('../utils/socket');

// 🆕 Helper pour traiter toutes les instances d'un article dans une note
// ⚠️ CRITIQUE: Traite TOUTES les instances, pas seulement la première
// Retourne: { paidItems: [...], itemUpdates: [...], removedTotal: number }
function processAllItemInstances(targetNote, itemToRemove) {
	const paidItems = [];
	const itemUpdates = [];
	let removedTotal = 0;
	
	const requestedQuantity = Number(itemToRemove.quantity || 1);
	const itemId = itemToRemove.id;
	const itemName = itemToRemove.name || '';
	
	if (requestedQuantity <= 0) {
		return { paidItems, itemUpdates, removedTotal };
	}
	
	// 🆕 Trouver TOUTES les instances de cet article dans la note
	const matchingItems = [];
	for (let idx = 0; idx < targetNote.items.length; idx++) {
		const item = targetNote.items[idx];
		// 🎯 Comparaison robuste : ID obligatoire, Nom indicatif (souple)
		const idMatches = item.id == itemId;
		// Comparaison de nom souple (trim et casse) pour éviter les échecs sur un espace en trop
		const nameMatches = item.name.trim().toLowerCase() === itemName.trim().toLowerCase();

		if (idMatches) {
			if (!nameMatches) {
				console.log(`[payment] ℹ️ ID ${itemId} match mais nom différent: "${item.name}" vs "${itemName}". On accepte.`);
			}
			const paidQty = item.paidQuantity || 0;
			const totalQty = item.quantity || 0;
			const unpaidQty = Math.max(0, totalQty - paidQty);
			
			if (unpaidQty > 0) {
				matchingItems.push({
					index: idx,
					item: item,
					paidQty: paidQty,
					totalQty: totalQty,
					unpaidQty: unpaidQty
				});
			}
		}
	}
	
	if (matchingItems.length === 0) {
		console.log(`[payment] ⚠️ Aucune instance non payée disponible pour article ${itemName} (id: ${itemId})`);
		return { paidItems, itemUpdates, removedTotal };
	}
	
	// 🆕 Répartir la quantité demandée entre toutes les instances disponibles
	let remainingQuantity = requestedQuantity;
	
	for (const match of matchingItems) {
		if (remainingQuantity <= 0) break;
		
		// Calculer combien on peut prendre de cette instance
		const quantityToTake = Math.min(remainingQuantity, match.unpaidQty);
		
		if (quantityToTake > 0) {
			const itemTotal = Number(match.item.price) * quantityToTake;
			
			paidItems.push({
			id: Number(match.item.id) || match.item.id, // 🆕 S'assurer que id est un nombre si possible
			name: match.item.name,
			price: Number(match.item.price) || 0,
			quantity: quantityToTake,
				total: itemTotal
		});
			
			itemUpdates.push({
				itemIndex: match.index,
				previousPaidQuantity: match.paidQty,
				actualQuantityToRemove: quantityToTake,
				newPaidQuantity: match.paidQty + quantityToTake
			});
			
			removedTotal += itemTotal;
			remainingQuantity -= quantityToTake;
			
			console.log(`[payment] ✅ Instance ${match.index} de ${itemName}: qté totale=${match.totalQty}, qté payée avant=${match.paidQty}, qté à payer=${quantityToTake}, qté payée après=${match.paidQty + quantityToTake}`);
		}
	}
	
	if (remainingQuantity > 0) {
		console.log(`[payment] ⚠️ Quantité demandée (${requestedQuantity}) > quantité non payée disponible (${requestedQuantity - remainingQuantity}) pour article ${itemName}`);
	}
	
	return { paidItems, itemUpdates, removedTotal };
}

// 🆕 Helper pour créer une transaction DEBIT dans credit.js
async function createCreditTransaction(clientId, amount, order, table, server, paidItems, discountAmount, discountClientName, orderIds = null) {
	try {
		const client = dataStore.clientCredits.find(c => c.id === Number(clientId));
		if (!client) {
			console.error(`[payment] Client crédit introuvable: ${clientId}`);
			return;
		}
		
		// Construire le ticket détaillé
		const ticket = {
			table: table || order.table || 'N/A',
			date: new Date().toISOString(),
			items: paidItems.map(item => ({
				name: item.name || item.id,
				quantity: item.quantity || 0,
				price: item.price || 0,
				total: (item.price || 0) * (item.quantity || 0)
			})),
			subtotal: paidItems.reduce((sum, item) => sum + ((item.price || 0) * (item.quantity || 0)), 0),
			discount: discountAmount || 0,
			total: amount,
			paymentMode: 'CREDIT',
			server: server || order.server || 'unknown'
		};
		
		// 🆕 Description adaptée selon le nombre de commandes
		const isMultiOrder = orderIds && Array.isArray(orderIds) && orderIds.length > 1;
		const description = isMultiOrder 
			? `CREDIT • Table ${table || order.table || 'N/A'} - Paiement complet (${orderIds.length} commandes)`
			: `CREDIT • Table ${table || order.table || 'N/A'} - Paiement partiel`;
		
		const transaction = {
			id: Date.now(),
			type: 'DEBIT',
			amount: amount,
			description: description,
			date: new Date().toISOString(),
			orderId: orderIds && orderIds.length === 1 ? orderIds[0] : (order.id || null), // 🆕 Si une seule commande, utiliser orderId
			orderIds: orderIds || (order.id ? [order.id] : []), // 🆕 Utiliser orderIds fourni ou créer depuis order
			ticket: ticket,
			server: server || order.server || 'unknown',
			paymentMode: 'CREDIT'
		};
		
		client.transactions.push(transaction);
		console.log(`[payment] ✅ Transaction DEBIT créée pour client ${clientId}: ${amount} TND`);
		
		// Sauvegarder
		await fileManager.savePersistedData();
		
		// Émettre événement socket
		const io = getIO();
		if (io) {
			const debits = client.transactions.filter(t => t.type === 'DEBIT').reduce((sum, t) => sum + t.amount, 0);
			const credits = client.transactions.filter(t => t.type === 'CREDIT').reduce((sum, t) => sum + t.amount, 0);
			const balance = debits - credits;
			io.emit('client:transaction-added', { clientId: client.id, transaction, balance });
		}
	} catch (e) {
		console.error(`[payment] Erreur création transaction CREDIT pour client ${clientId}:`, e);
		// Ne pas bloquer le paiement si la transaction crédit échoue
	}
}

// 🆕 Helper pour trouver toutes les instances d'un article dans TOUTE la table (FIFO)
// Retourne: { paidItems: [...], itemUpdates: [...], removedTotal: number }
function processItemAcrossTable(tableNumber, itemToRemove, preferredNoteId = null) {
	const paidItems = [];
	const allItemUpdates = [];
	let totalRemoved = 0;
	let remainingQuantity = Number(itemToRemove.quantity || 1);
	const itemId = itemToRemove.id;
	const itemName = itemToRemove.name;

	if (remainingQuantity <= 0) return { paidItems, itemUpdates: allItemUpdates, removedTotal: 0 };

	// 1. Trouver toutes les commandes actives de la table, triées par date (FIFO)
	const tableOrders = dataStore.orders
		.filter(o => o.table == tableNumber && o.status !== 'archived')
		.sort((a, b) => new Date(a.createdAt || 0) - new Date(b.createdAt || 0));

	// 2. Parcourir chaque commande et chaque note pour trouver l'article
	for (const order of tableOrders) {
		if (remainingQuantity <= 0) break;

		// 🎯 OPTIMISATION : Ne collecter que les notes pertinentes selon preferredNoteId
		const relevantNotes = [];
		
		if (preferredNoteId) {
			// On cherche une note spécifique : ne prendre que celle-là
			const effectivePreferredId = preferredNoteId === 'null' ? 'main' : preferredNoteId;
			
			if (effectivePreferredId === 'main') {
				// Chercher uniquement dans la note principale
				if (order.mainNote) {
					if (!order.mainNote.id) order.mainNote.id = 'main';
					relevantNotes.push(order.mainNote);
				}
			} else {
				// Chercher uniquement dans la sous-note spécifiée
				if (order.subNotes) {
					const targetSubNote = order.subNotes.find(sub => sub.id === effectivePreferredId);
					if (targetSubNote) {
						relevantNotes.push(targetSubNote);
					}
				}
			}
		} else {
			// Pas de filtre : prendre toutes les notes (comportement actuel pour "Tout Payer")
			if (order.mainNote) {
				if (!order.mainNote.id) order.mainNote.id = 'main';
				relevantNotes.push(order.mainNote);
			}
			if (order.subNotes) {
				relevantNotes.push(...order.subNotes);
			}
		}

		for (const note of relevantNotes) {
			if (remainingQuantity <= 0) break;
			
			const effectiveNoteId = note.id || 'main';

			console.log(`[payment] 🔍 Recherche de ${itemName} (ID: ${itemId}) dans Commande #${order.id}, Note: ${effectiveNoteId}`);
			const result = processAllItemInstances(note, { ...itemToRemove, quantity: remainingQuantity });
			
			if (result.paidItems.length > 0) {
				// 🆕 Enrichir les articles payés avec les métadonnées de commande
				const itemsWithMetadata = result.paidItems.map(it => ({
					...it,
					orderId: order.id,
					noteId: effectiveNoteId,
					noteName: note.name || (effectiveNoteId === 'main' ? 'Note Principale' : 'Sous-Note')
				}));
				
				paidItems.push(...itemsWithMetadata);
				
				// Transformer les mises à jour pour inclure la référence à l'order et la note
				for (const update of result.itemUpdates) {
					allItemUpdates.push({
						orderId: order.id,
						noteId: note.id,
						...update
					});
				}
				totalRemoved += result.removedTotal;
				remainingQuantity -= result.paidItems.reduce((sum, it) => sum + it.quantity, 0);
			}
		}
	}

	return { paidItems, itemUpdates: allItemUpdates, removedTotal: totalRemoved };
}

// Supprimer des articles d'une note (paiement)
async function deleteNoteItems(req, res) {
	const io = getIO();
	const { orderId, noteId } = req.params;
	const { items, finalAmount, discount, isPercentDiscount, discountClientName, splitPayments, paymentMode, table } = req.body || {};
	
	if (!items || !Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'Articles à supprimer manquants' });
	}

	// 🎯 Utiliser la même logique que payMultiOrders pour la cohérence
	// Si orderId et noteId sont fournis, ils seront utilisés par payMultiOrders
	const paymentItems = [{
		orderId: Number(orderId),
		noteId: noteId,
		items: items
	}];

	// On injecte les données dans req.body pour appeler payMultiOrders
	req.body.items = paymentItems;
	req.body.table = table || (dataStore.orders.find(o => o.id === Number(orderId))?.table);

	return payMultiOrders(req, res);
}

// Paiement multi-commandes : payer des articles de plusieurs commandes en une seule transaction
async function payMultiOrders(req, res) {
	const io = getIO();
	const { table, items, paymentMode, finalAmount, discount, isPercentDiscount, discountClientName, splitPayments } = req.body || {};
	
	const isSplitPayment = splitPayments && Array.isArray(splitPayments) && splitPayments.length > 1;
	
	console.log(`[payment-multi] 🚀 Paiement Table ${table}: ${items?.length || 0} groupes d'articles`);
	
	if (!table || !items || !Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'Table et articles requis' });
	}
	
	const sharedTimestamp = new Date().toISOString();
	const splitPaymentBaseId = isSplitPayment ? `split_${sharedTimestamp}` : null;
	
	let totalSubtotal = 0;
	const allPaidItems = [];
	const allItemUpdates = []; // { orderId, noteId, itemIndex, ... }

	// 1. APLATIR LE SAC : Collecter tous les articles à payer
	const updatesByOrder = {};
	const normalizedItems = [];
	for (const entry of items) {
		if (entry.items && Array.isArray(entry.items)) {
			entry.items.forEach(it => normalizedItems.push({ ...it, noteId: entry.noteId }));
		} else {
			normalizedItems.push(entry);
		}
	}

	for (const item of normalizedItems) {
		// 🎯 Chercher l'article dans la table (FIFO)
		const result = processItemAcrossTable(table, item, item.noteId);
		
		if (result.paidItems.length > 0) {
			allPaidItems.push(...result.paidItems);
			allItemUpdates.push(...result.itemUpdates);
			
			// 🆕 Distribuer les articles payés par commande
			result.paidItems.forEach(pi => {
				if (!updatesByOrder[pi.orderId]) updatesByOrder[pi.orderId] = { updates: [], paidItems: [] };
				updatesByOrder[pi.orderId].paidItems.push(pi);
			});

			totalSubtotal += result.removedTotal;
		}
	}

	if (allPaidItems.length === 0) {
		return res.status(404).json({ error: 'Aucun article impayé trouvé pour cette sélection' });
	}

	// 🆕 Remplir les updates dans updatesByOrder (s'ils n'y sont pas déjà par paidItems)
	allItemUpdates.forEach(update => {
		if (!updatesByOrder[update.orderId]) updatesByOrder[update.orderId] = { updates: [], paidItems: [] };
		// Eviter les doublons si on a déjà l'update
		const exists = updatesByOrder[update.orderId].updates.some(u => 
			u.noteId === update.noteId && u.itemIndex === update.itemIndex
		);
		if (!exists) updatesByOrder[update.orderId].updates.push(update);
	});

	console.log(`[payment-multi] ✅ Articles trouvés: ${allPaidItems.length}, Total Brut: ${totalSubtotal.toFixed(3)} TND`);

	// 2. RÉPARTIR LES PAIEMENTS PAR COMMANDE
	// Arrondir le total brut cumulé pour éviter les erreurs de virgule flottante
	totalSubtotal = Math.round(totalSubtotal * 1000) / 1000;
	const actualTotalPaid = finalAmount != null ? Math.round(Number(finalAmount) * 1000) / 1000 : totalSubtotal;
	const totalDiscount = Math.round((totalSubtotal - actualTotalPaid) * 1000) / 1000;

	const ordersToArchive = new Set();
	const serverName = req.body.server || 'unknown';

	// Appliquer les changements commande par commande
	for (const orderId in updatesByOrder) {
		const order = dataStore.orders.find(o => o.id === Number(orderId));
		if (!order) continue;

		const orderInfo = updatesByOrder[orderId];
		const orderSubtotal = orderInfo.paidItems.reduce((sum, it) => sum + (it.price * it.quantity), 0);
		
		// Calculer la part de remise pour cette commande
		const proportion = totalSubtotal > 0 ? orderSubtotal / totalSubtotal : 0;
		const orderAmount = actualTotalPaid * proportion;
		const orderDiscountAmount = totalDiscount * proportion;

		// Mettre à jour les paidQuantity
		orderInfo.updates.forEach(update => {
			const targetNote = update.noteId === 'main' ? order.mainNote : order.subNotes.find(n => n.id === update.noteId);
			if (targetNote && targetNote.items[update.itemIndex]) {
				const item = targetNote.items[update.itemIndex];
				item.paidQuantity = (item.paidQuantity || 0) + update.actualQuantityToRemove;
			}
		});

		// Enregistrer dans l'historique de la commande
		if (!order.paymentHistory) order.paymentHistory = [];

		// 🆕 Flag pour savoir si la commande est terminée (sera ajusté après calcul du total)
		let isCompletePaymentForOrder = false;

		if (isSplitPayment) {
			for (const split of splitPayments) {
				const splitProp = actualTotalPaid > 0 ? split.amount / actualTotalPaid : 0;
				const paymentRecord = {
					id: `pay_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
					timestamp: sharedTimestamp,
					amount: orderAmount * splitProp,
					paymentMode: split.mode,
					items: orderInfo.paidItems,
					subtotal: orderSubtotal * splitProp,
					discount: discount,
					isPercentDiscount: isPercentDiscount,
					discountAmount: orderDiscountAmount * splitProp,
					isSplitPayment: true,
					splitPaymentId: splitPaymentBaseId,
					server: serverName,
					table: table,
					noteId: orderInfo.paidItems[0]?.noteId || 'main',
					noteName: orderInfo.paidItems[0]?.noteName || 'Note Principale',
					creditClientName: split.mode === 'CREDIT' ? (dataStore.clientCredits.find(c => c.id === Number(split.clientId))?.name || `Client #${split.clientId}`) : null,
					isCompletePayment: false // Sera mis à true si archivé
				};
				order.paymentHistory.push(paymentRecord);
			}
		} else {
			const paymentRecord = {
				id: `pay_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
				timestamp: sharedTimestamp,
				amount: orderAmount,
				paymentMode: paymentMode || 'ESPECE',
				items: orderInfo.paidItems,
				subtotal: orderSubtotal,
				discount: discount,
				isPercentDiscount: isPercentDiscount,
				discountAmount: orderDiscountAmount,
				server: serverName,
				table: table,
				noteId: orderInfo.paidItems[0]?.noteId || 'main',
				noteName: orderInfo.paidItems[0]?.noteName || 'Note Principale',
				isCompletePayment: false // Sera mis à true si archivé
			};
			order.paymentHistory.push(paymentRecord);
		}

		// 🆕 Mettre à jour le montant déjà payé sur la commande
		order.paidAmount = (order.paidAmount || 0) + orderAmount;

		// Recalculer le total de la commande
		let remainingTotal = 0;
		const notes = [order.mainNote, ...(order.subNotes || [])];
		notes.forEach(n => {
			if (!n) return;
			let noteUnpaid = 0;
			n.items.forEach(it => {
				const unpaidQty = Math.max(0, it.quantity - (it.paidQuantity || 0));
				noteUnpaid += it.price * unpaidQty;
			});
			// 🎯 Arrondir à 3 décimales (TND) pour éviter les résidus de calcul
			noteUnpaid = Math.round(noteUnpaid * 1000) / 1000;
			n.total = noteUnpaid;
			remainingTotal += noteUnpaid;
			
			// Marquer note comme payée si vide
			if (n.id !== 'main' && noteUnpaid <= 0.001) {
				n.paid = true;
				n.paidAt = new Date().toISOString();
			}
		});
		// 🎯 Arrondir le total final également
		order.total = Math.round(remainingTotal * 1000) / 1000;
		order.updatedAt = new Date().toISOString();
		
		if (order.total <= 0.001) {
			ordersToArchive.add(order);
		} else {
			io.emit('order:updated', order);
		}
	}
	
	// 3. ARCHIVAGE ET RÉPONSE
	const archivedIds = [];
	for (const order of ordersToArchive) {
		order.status = 'archived';
		order.archivedAt = new Date().toISOString();
		order.paid = true;
		
		// Marquer tous les derniers paiements comme complets
		order.paymentHistory.forEach(p => {
			if (p.timestamp === sharedTimestamp) p.isCompletePayment = true;
		});

		dataStore.archivedOrders.push(order);
		const idx = dataStore.orders.findIndex(o => o.id === order.id);
		if (idx !== -1) dataStore.orders.splice(idx, 1);
		archivedIds.push(order.id);
		io.emit('order:archived', { orderId: order.id, table: order.table });
	}

	// Gérer les transactions CREDIT si nécessaire
	if (isSplitPayment) {
		for (const split of splitPayments) {
			if (split.mode === 'CREDIT' && split.clientId) {
				await createCreditTransaction(
					split.clientId, 
					split.amount, 
					{ table, server: discountClientName }, // Approximation serveur
					table, 
					discountClientName, 
					allPaidItems, 
					totalDiscount, 
					discountClientName, 
					Array.from(ordersToArchive).map(o => o.id)
				);
			}
		}
	} else if (paymentMode === 'CREDIT' && req.body.clientId) {
		await createCreditTransaction(
			req.body.clientId, 
			actualTotalPaid, 
			{ table, server: discountClientName }, 
			table, 
			discountClientName, 
			allPaidItems, 
			totalDiscount, 
			discountClientName, 
			Array.from(ordersToArchive).map(o => o.id)
		);
	}

	await fileManager.savePersistedData();
	io.emit('table:payment', { table, totalPaid: actualTotalPaid, archivedOrders: archivedIds });
	
	return res.json({
		ok: true,
		totalPaid: actualTotalPaid,
		archivedOrders: archivedIds
	});
}

module.exports = {
	deleteNoteItems,
	payMultiOrders
};

