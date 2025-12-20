// 🚫 Controller POS - Annulations et retours de plats
// Gère les annulations d'articles avec réaffectation, remboursements et pertes

const dataStore = require('../data');
const fileManager = require('../utils/fileManager');
const { getIO } = require('../utils/socket');

// Annuler des articles d'une note
async function cancelItems(req, res) {
	const io = getIO();
	const { orderId, noteId } = req.params;
	const { items, cancellationDetails } = req.body || {};
	
	if (!items || !Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'Articles à annuler manquants' });
	}
	
	if (!cancellationDetails) {
		return res.status(400).json({ error: 'Détails d\'annulation requis' });
	}
	
	console.log('[cancellation] Annulation:', items.length, 'articles de commande', orderId, 'note', noteId);
	console.log('[cancellation] État:', cancellationDetails.state, 'Raison:', cancellationDetails.reason, 'Action:', cancellationDetails.action);
	console.log('[cancellation] Articles reçus:', JSON.stringify(items, null, 2));
	console.log('[cancellation] Détails reçus:', JSON.stringify(cancellationDetails, null, 2));
	
	// Trouver la commande
	const order = dataStore.orders.find(o => o.id === Number(orderId));
	if (!order) {
		console.log('[cancellation] ❌ Commande introuvable:', orderId, 'Commandes disponibles:', dataStore.orders.map(o => o.id));
		return res.status(404).json({ error: 'Commande introuvable' });
	}
	
	console.log('[cancellation] ✅ Commande trouvée:', order.id, 'table:', order.table);
	
	// Initialiser structures si nécessaire
	if (!order.mainNote) order.mainNote = { id: 'main', name: 'Note Principale', covers: order.covers || 1, items: [], total: 0, paid: false };
	if (!order.subNotes) order.subNotes = [];
	if (!order.orderHistory) order.orderHistory = [];
	
	// Trouver la note
	let targetNote;
	if (!noteId || noteId === 'main') {
		targetNote = order.mainNote;
	} else {
		targetNote = order.subNotes.find(n => n.id === noteId);
	}
	if (!targetNote) {
		return res.status(404).json({ error: 'Note introuvable' });
	}
	
	// Liste des articles annulés pour l'historique
	const cancelledItems = [];
	let cancelledTotal = 0;
	let paidCancelledTotal = 0; // 🆕 Total des articles payés qui sont annulés (pour remboursement)
	
	// 🆕 Détecter si l'action est "remake" - dans ce cas, on ne supprime PAS l'article
	const isRemake = cancellationDetails.action === 'remake';
	
	// Retirer les articles de la note (sauf pour "remake")
	items.forEach(itemToCancel => {
		const itemId = Number(itemToCancel.id);
		const itemName = String(itemToCancel.name || '').trim();
		console.log('[cancellation] Recherche article: id=', itemId, 'name=', itemName, 'dans note', noteId);
		console.log('[cancellation] Articles dans la note:', targetNote.items.map(it => ({ id: it.id, name: it.name, quantity: it.quantity, paidQuantity: it.paidQuantity || 0 })));
		
		// Rechercher l'article (comparaison flexible pour les noms)
		const idx = targetNote.items.findIndex(it => {
			const itId = Number(it.id);
			const itName = String(it.name || '').trim();
			const matchId = itId === itemId;
			// Comparaison flexible des noms (insensible à la casse et aux espaces)
			const matchName = itName.toLowerCase() === itemName.toLowerCase();
			const match = matchId && matchName;
			
			if (!match && matchId) {
				// Même ID mais nom différent - log pour debug
				console.log('[cancellation] ⚠️ ID correspond mais nom différent:', { itId, itemId, itName, itemName });
			}
			
			return match;
		});
		
		if (idx === -1) {
			console.log('[cancellation] ⚠️ Article non trouvé dans la note.');
			console.log('[cancellation] Recherché: id=', itemId, 'name=', itemName);
			console.log('[cancellation] Articles disponibles:', targetNote.items.map(it => ({ id: it.id, name: it.name, typeId: typeof it.id, typeName: typeof it.name })));
			return; // Passer au suivant
		} else {
			const existing = targetNote.items[idx];
			const requestedQuantity = Number(itemToCancel.quantity || 1);
			
			console.log('[cancellation] ✅ Article trouvé:', existing.name, 'qté totale:', existing.quantity, 'qté payée:', existing.paidQuantity || 0);
			
			// Calculer les quantités
			const paidQty = existing.paidQuantity || 0;
			const totalQty = existing.quantity || 0;
			const unpaidQty = Math.max(0, totalQty - paidQty);
			
			console.log('[cancellation] Quantités: totale=', totalQty, 'payée=', paidQty, 'non payée=', unpaidQty, 'demandée=', requestedQuantity);
			
			// 🆕 On peut annuler n'importe quelle quantité (payée ou non payée)
			// Mais on ne peut pas annuler plus que ce qui existe
			const actualQuantityToCancel = Math.min(requestedQuantity, totalQty);
			
			if (actualQuantityToCancel <= 0) {
				console.log(`[cancellation] ⚠️ Aucune quantité disponible pour article ${existing.name}`);
				return; // Passer au suivant
			}
			
			const itemTotal = Number(existing.price) * actualQuantityToCancel;
			cancelledTotal += itemTotal;
			
			// 🆕 Calculer la quantité payée parmi celle qui est annulée
			// Si on annule 2 articles et qu'il y a 1 article payé, on rembourse seulement 1
			// Si on annule 1 article et qu'il y a 2 articles payés, on rembourse 1
			// Si on annule 3 articles et qu'il y a 1 article payé, on rembourse 1
			const paidQtyInCancelled = Math.min(actualQuantityToCancel, paidQty);
			const paidItemTotal = Number(existing.price) * paidQtyInCancelled;
			paidCancelledTotal += paidItemTotal;
			
			console.log('[cancellation] Quantité annulée:', actualQuantityToCancel, 'dont payée:', paidQtyInCancelled, '→ remboursement:', paidItemTotal, 'TND');
			
			// Enregistrer pour l'historique
			cancelledItems.push({
				id: existing.id,
				name: existing.name,
				price: existing.price,
				quantity: actualQuantityToCancel,
				total: itemTotal,
				paidQuantity: paidQtyInCancelled // 🆕 Quantité payée parmi celle annulée
			});
			
			// 🆕 Pour "remake", on garde l'article en place (ne pas le supprimer)
			if (isRemake) {
				console.log('[cancellation] 🔄 Action "remake" - Article gardé en place:', existing.name, 'qté:', totalQty);
				// L'article reste dans la note, on ne fait rien
			} else {
				// Retirer l'article de la note (pour les autres actions)
				if (actualQuantityToCancel >= totalQty) {
					// Supprimer complètement l'article
					targetNote.items.splice(idx, 1);
				} else {
					// Réduire la quantité
					existing.quantity = totalQty - actualQuantityToCancel;
					// 🆕 Ajuster paidQuantity : réduire de la quantité payée annulée
					if (paidQtyInCancelled > 0) {
						existing.paidQuantity = Math.max(0, paidQty - paidQtyInCancelled);
					}
					// S'assurer que paidQuantity ne dépasse pas la nouvelle quantity
					if (existing.paidQuantity > existing.quantity) {
						existing.paidQuantity = existing.quantity;
					}
				}
				console.log('[cancellation] Article annulé:', existing.name, 'qté annulée:', actualQuantityToCancel, 'dont payée:', paidQtyInCancelled, '/ total était:', totalQty);
			}
		}
	});
	
	if (cancelledItems.length === 0) {
		console.log('[cancellation] ❌ Aucun article annulable trouvé.');
		console.log('[cancellation] Articles dans la note:', targetNote.items.map(it => ({ id: it.id, name: it.name, quantity: it.quantity, paidQuantity: it.paidQuantity || 0 })));
		console.log('[cancellation] Articles demandés:', items.map(it => ({ id: it.id, name: it.name, quantity: it.quantity })));
		return res.status(400).json({ 
			error: 'Aucun article annulable trouvé. Vérifiez que les articles existent dans la note et ne sont pas déjà payés.',
			details: {
				requestedItems: items,
				availableItems: targetNote.items.map(it => ({ id: it.id, name: it.name, quantity: it.quantity, paidQuantity: it.paidQuantity || 0 }))
			}
		});
	}
	
	// Gérer les cas spéciaux selon l'action
	let refundAmount = 0;
	let wasteCost = 0;
	let reassignmentInfo = null;
	
	if (cancellationDetails.action === 'refund') {
		// 🆕 Remboursement : créer entrée dans paymentHistory SEULEMENT si l'article a été payé
		// Si l'article n'a pas été payé, c'est juste une annulation (VOID), pas un remboursement
		if (paidCancelledTotal > 0) {
			// Il y a des articles payés à rembourser
			refundAmount = paidCancelledTotal;
			if (!order.paymentHistory) {
				order.paymentHistory = [];
			}
			// 🆕 Filtrer seulement les articles payés pour le remboursement
			const paidCancelledItems = cancelledItems.filter(item => (item.paidQuantity || 0) > 0);
			
			order.paymentHistory.push({
				type: 'refund',
				timestamp: new Date().toISOString(),
				amount: -refundAmount, // Négatif pour remboursement
				noteId: noteId === 'main' ? 'main' : noteId,
				noteName: targetNote.name || 'Note Principale',
				items: paidCancelledItems.map(it => ({
					id: it.id,
					name: it.name,
					price: it.price,
					quantity: it.paidQuantity || 0, // 🆕 Seulement la quantité payée
					total: (it.price || 0) * (it.paidQuantity || 0)
				})),
				reason: cancellationDetails.reason || 'Annulation',
				description: cancellationDetails.description || '',
				server: order.server || 'unknown',
				table: order.table
			});
			console.log('[cancellation] 💰 Remboursement créé:', refundAmount, 'TND (articles payés)');
		} else {
			// Aucun article payé → annulation simple (VOID), pas de remboursement financier
			console.log('[cancellation] ✅ Annulation simple (VOID) - aucun article payé, pas de remboursement financier');
		}
	} else if (cancellationDetails.action === 'reassign') {
		// Réaffectation : ajouter articles à table/note destination
		const { toTable, toOrderId, toNoteId } = cancellationDetails.reassignment || {};
		if (!toTable || !toOrderId || !toNoteId) {
			return res.status(400).json({ error: 'Paramètres de réaffectation incomplets' });
		}
		
		// Trouver la commande destination
		const toOrder = dataStore.orders.find(o => o.id === Number(toOrderId));
		if (!toOrder) {
			return res.status(404).json({ error: 'Commande destination introuvable' });
		}
		
		// Initialiser structures destination si nécessaire
		if (!toOrder.mainNote) toOrder.mainNote = { id: 'main', name: 'Note Principale', covers: toOrder.covers || 1, items: [], total: 0, paid: false };
		if (!toOrder.subNotes) toOrder.subNotes = [];
		if (!toOrder.orderHistory) toOrder.orderHistory = [];
		
		// Trouver la note destination
		let toNote;
		if (toNoteId === 'main') {
			toNote = toOrder.mainNote;
		} else {
			toNote = toOrder.subNotes.find(n => n.id === toNoteId);
			if (!toNote) {
				// Créer la sous-note si elle n'existe pas
				toNote = {
					id: toNoteId,
					name: cancellationDetails.reassignment.noteName || 'Client',
					covers: 1,
					items: [],
					total: 0,
					paid: false,
					createdAt: new Date().toISOString()
				};
				toOrder.subNotes.push(toNote);
			}
		}
		
		// Ajouter les articles à la note destination (sans paidQuantity car non payés)
		toNote.items = toNote.items || [];
		for (const cancelledItem of cancelledItems) {
			const existingIndex = toNote.items.findIndex(it => it.id === cancelledItem.id && it.name === cancelledItem.name);
			if (existingIndex !== -1) {
				toNote.items[existingIndex].quantity += cancelledItem.quantity;
			} else {
				toNote.items.push({
					id: cancelledItem.id,
					name: cancelledItem.name,
					price: cancelledItem.price,
					quantity: cancelledItem.quantity
					// Pas de paidQuantity car articles non payés
				});
			}
		}
		
		// Recalculer le total de la note destination
		let toNoteTotal = 0;
		for (const item of toNote.items) {
			const paidQty = item.paidQuantity || 0;
			const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
			toNoteTotal += (item.price || 0) * unpaidQty;
		}
		toNote.total = toNoteTotal;
		
		// Recalculer le total de la commande destination
		let toOrderTotal = 0;
		if (toOrder.mainNote && toOrder.mainNote.items) {
			for (const item of toOrder.mainNote.items) {
				const paidQty = item.paidQuantity || 0;
				const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
				toOrderTotal += (item.price || 0) * unpaidQty;
			}
		}
		if (toOrder.subNotes) {
			for (const subNote of toOrder.subNotes) {
				if (subNote.items) {
					for (const item of subNote.items) {
						const paidQty = item.paidQuantity || 0;
						const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
						toOrderTotal += (item.price || 0) * unpaidQty;
					}
				}
			}
		}
		toOrder.total = toOrderTotal;
		toOrder.updatedAt = new Date().toISOString();
		
		// Enregistrer la réaffectation dans l'historique de la commande destination
		toOrder.orderHistory.push({
			timestamp: new Date().toISOString(),
			action: 'items_reassigned_in',
			noteId: toNoteId === 'main' ? 'main' : toNoteId,
			noteName: toNote.name || 'Note Principale',
			items: cancelledItems.map(it => ({ ...it })),
			details: `Articles réaffectés depuis table ${order.table}, commande ${orderId}`,
			reassignmentFrom: {
				table: order.table,
				orderId: order.id,
				noteId: noteId
			}
		});
		
		reassignmentInfo = {
			fromTable: order.table,
			toTable: toTable,
			toOrderId: Number(toOrderId),
			toNoteId: toNoteId
		};
		
		console.log('[cancellation] Articles réaffectés vers table', toTable, 'commande', toOrderId, 'note', toNoteId);
		
		// Émettre événement pour la commande destination
		io.emit('order:updated', toOrder);
	} else if (cancellationDetails.action === 'cancel' && (cancellationDetails.state === 'prepared_not_served' || cancellationDetails.state === 'served_untouched' || cancellationDetails.state === 'served_touched')) {
		// Perte : enregistrer le coût (optionnel, pour analyse)
		wasteCost = cancellationDetails.wasteCost || 0;
		if (wasteCost > 0 && dataStore.wasteRecords) {
			dataStore.wasteRecords.push({
				timestamp: new Date().toISOString(),
				orderId: order.id,
				table: order.table,
				server: order.server || 'unknown',
				items: cancelledItems.map(it => ({ ...it })),
				cost: wasteCost,
				reason: cancellationDetails.reason || 'Annulation',
				state: cancellationDetails.state
			});
		}
	}
	
	// 🆕 Pour "remake", on ne recalcule PAS les totaux car l'article reste en place
	// Pour les autres actions, on recalcule les totaux
	if (!isRemake) {
		// Recalculer les totaux de la note source depuis scratch
		let noteUnpaidTotal = 0;
		for (const item of targetNote.items) {
			const paidQty = item.paidQuantity || 0;
			const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
			noteUnpaidTotal += (item.price || 0) * unpaidQty;
		}
		targetNote.total = noteUnpaidTotal;
	}
	
	// 🆕 Pour "remake", on ne recalcule PAS les totaux de la commande car l'article reste en place
	// Pour les autres actions, on recalcule les totaux
	if (!isRemake) {
		// Recalculer les totaux de la commande source depuis scratch
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
	}
	order.updatedAt = new Date().toISOString();
	
	// Enregistrer l'annulation dans l'historique
	order.orderHistory.push({
		timestamp: new Date().toISOString(),
		action: 'items_cancelled',
		noteId: noteId === 'main' ? 'main' : noteId,
		noteName: targetNote.name || 'Note Principale',
		items: cancelledItems.map(it => ({ ...it })),
		cancellationDetails: {
			state: cancellationDetails.state,
			reason: cancellationDetails.reason,
			description: cancellationDetails.description || '',
			action: cancellationDetails.action,
			refundAmount: refundAmount,
			wasteCost: wasteCost,
			reassignment: reassignmentInfo
		},
		handledBy: order.server || 'unknown',
		table: order.table,
		orderId: order.id
	});
	
	console.log('[cancellation] ✅ Annulation enregistrée dans l\'historique');
	
	// 🆕 Auto-archiver la commande si elle est devenue vide (aucun article restant)
	const hasMainItems = Array.isArray(order.mainNote?.items) && order.mainNote.items.length > 0;
	let hasSubItems = false;
	if (Array.isArray(order.subNotes)) {
		for (const sn of order.subNotes) {
			if (Array.isArray(sn.items) && sn.items.length > 0) { hasSubItems = true; break; }
		}
	}
	const shouldArchive = !hasMainItems && !hasSubItems;
	
	// Sauvegarder
	await fileManager.savePersistedData();
	
	if (shouldArchive) {
		try {
			// Retirer de orders et pousser dans archivedOrders
			const idx = dataStore.orders.findIndex(o => o.id === order.id);
			if (idx !== -1) {
				const archived = { ...order, archivedAt: new Date().toISOString() };
				dataStore.orders.splice(idx, 1);
				dataStore.archivedOrders.push(archived);
				await fileManager.savePersistedData();
				console.log('[cancellation] 🗄️ Commande archivée automatiquement (vide):', order.id, 'table:', order.table);
				// Émettre order:archived pour informer les clients
				getIO().emit('order:archived', { id: order.id, table: order.table });
				return res.json({ ok: true, archived: true, order: archived });
			}
		} catch (e) {
			console.error('[cancellation] ⚠️ Erreur auto-archivage:', e);
		}
	}
	
	// Émettre événement
	io.emit('order:updated', order);
	
	return res.json({
		ok: true,
		message: `${cancelledItems.length} article(s) annulé(s)`,
		cancelledItems: cancelledItems.length,
		cancelledTotal: cancelledTotal,
		refundAmount: refundAmount,
		wasteCost: wasteCost,
		reassigned: reassignmentInfo !== null,
		order: order
	});
}

module.exports = {
	cancelItems
};

