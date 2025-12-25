// 🔧 Utilitaires pour le traitement de l'historique
// Fonctions communes partagées entre pos-archive.js et pos-history-unified.js

const dataStore = require('../data');

// Reconstruire les événements depuis paymentHistory (uniquement pour compatibilité avec anciennes données)
function reconstructOrderEventsFromPayments(session) {
	const orderHistory = session.orderHistory || [];
	if (orderHistory.length > 0) {
		return orderHistory; // Les nouvelles données ont toujours orderHistory complet
	}
	
	// Fallback pour anciennes données : reconstruire depuis paymentHistory
	const paymentHistory = session.paymentHistory || [];
	if (paymentHistory.length === 0) {
		return [];
	}
	
	// Reconstruire depuis paymentHistory pour anciennes données
	const paymentsByNote = {};
	for (const payment of paymentHistory) {
		const noteId = payment.noteId || 'main';
		if (!paymentsByNote[noteId]) paymentsByNote[noteId] = [];
		paymentsByNote[noteId].push(payment);
	}
	
	const reconstructedEvents = [];
	for (const [noteId, payments] of Object.entries(paymentsByNote)) {
		const firstPayment = payments[0];
		const allItems = payments.flatMap(p => p.items || []);
		
		if (allItems.length > 0) {
			reconstructedEvents.push({
				timestamp: firstPayment.timestamp || session.createdAt || new Date().toISOString(),
				action: 'order_created',
				noteId: noteId,
				noteName: firstPayment.noteName || 'Note Principale',
				items: allItems,
				details: 'Reconstruit depuis paiements (anciennes données)',
				reconstructed: true,
			});
		}
	}
	
	return reconstructedEvents;
}

// Fusionner les événements de commande par timestamp (même seconde, orderId et noteId)
function mergeOrderEvents(allOrderEvents) {
	const mergedEventsMap = {};
	
	for (const event of allOrderEvents) {
		const timestamp = event.timestamp || '';
		const noteId = event.noteId || 'main';
		const orderId = event.orderId;
		const action = event.action;
		
		if (!timestamp || !orderId) continue;
		
		// 🆕 CORRECTION : Pour order_created et subnote_created, chaque commande est UNIQUE
		// Ne JAMAIS fusionner entre commandes différentes (orderId différent = événement séparé)
		// Pour items_added, on peut fusionner si même commande + même timestamp (arrondi)
		let timestampKey;
		if (action === 'order_created' || action === 'subnote_created') {
			// Clé unique basée sur orderId + noteId + action (chaque commande = événement séparé)
			// Le timestamp n'est pas utilisé pour éviter les fusions accidentelles
			timestampKey = `${orderId}_${noteId}_${action}`;
		} else {
			// Pour items_added : fusionner si même commande + même timestamp (arrondi)
			try {
				const roundedTimestamp = new Date(timestamp).toISOString().substring(0, 19);
				timestampKey = `${roundedTimestamp}_${orderId}_${noteId}`;
			} catch (e) {
				timestampKey = `${timestamp}_${orderId}_${noteId}`;
			}
		}
		
		if (!mergedEventsMap[timestampKey]) {
			mergedEventsMap[timestampKey] = {
				timestamp: timestamp,
				action: action,
				noteId: noteId,
				noteName: event.noteName || 'Note Principale',
				orderId: orderId,
				items: (event.items || []).map(item => ({ ...item })),
			};
		} else {
			// Fusionner les articles SEULEMENT pour items_added de la même commande
			// Les order_created et subnote_created ne devraient jamais arriver ici
			const existingItems = mergedEventsMap[timestampKey].items;
			for (const newItem of event.items || []) {
				const existingIndex = existingItems.findIndex(i => i.id === newItem.id && i.name === newItem.name);
				if (existingIndex !== -1) {
					// Préserver le flag cancelled si l'article est annulé
					const isCancelled = newItem.cancelled === true || existingItems[existingIndex].cancelled === true;
					existingItems[existingIndex].quantity = (existingItems[existingIndex].quantity || 0) + (newItem.quantity || 0);
					if (isCancelled) {
						existingItems[existingIndex].cancelled = true;
						existingItems[existingIndex].cancellationDetails = newItem.cancellationDetails || existingItems[existingIndex].cancellationDetails;
					}
				} else {
					existingItems.push({ ...newItem });
				}
			}
		}
	}
	
	return Object.values(mergedEventsMap).sort((a, b) => {
		return new Date(a.timestamp || 0) - new Date(b.timestamp || 0);
	});
}

// Regrouper les paiements par acte de paiement (même timestamp à la seconde, mode et remise)
function groupPaymentsByTimestamp(sessions) {
	// Collecter tous les paiements
	const allPayments = [];
	for (const session of sessions) {
		for (const payment of session.paymentHistory || []) {
			// Utiliser discountAmount et hasDiscount directement s'ils existent, sinon calculer (rétrocompatibilité)
			const discountAmount = payment.discountAmount != null 
				? payment.discountAmount 
				: ((payment.subtotal || payment.amount || 0) - (payment.amount || 0));
			const hasDiscount = payment.hasDiscount != null 
				? payment.hasDiscount 
				: (discountAmount > 0.01 || (payment.discount && payment.discount > 0));
			
			// 🆕 Si c'est un paiement CREDIT sans creditClientName, essayer de le récupérer depuis les transactions CREDIT
			let creditClientName = payment.creditClientName || null;
			if (!creditClientName && payment.paymentMode === 'CREDIT') {
				// Chercher dans les transactions CREDIT des clients pour trouver une transaction correspondante
				const paymentTimestamp = payment.timestamp || '';
				const paymentAmount = payment.amount || 0;
				const paymentTable = payment.table || session.table;
				const sessionId = session.id;
				
				// Chercher dans tous les clients
				for (const client of (dataStore.clientCredits || [])) {
					if (!client.transactions || !Array.isArray(client.transactions)) continue;
					
					// Chercher une transaction DEBIT correspondante
					for (const transaction of client.transactions) {
						if (transaction.type === 'DEBIT' && 
							transaction.paymentMode === 'CREDIT') {
							
							// Vérifier le montant (tolérance 0.01)
							const transactionAmount = transaction.amount || 0;
							const amountMatch = Math.abs(transactionAmount - paymentAmount) < 0.01;
							
							// Vérifier la table
							const transactionTable = transaction.ticket?.table || transaction.table;
							const tableMatch = transactionTable === paymentTable;
							
							// Vérifier l'orderId ou orderIds
							const orderIdMatch = (transaction.orderId === sessionId) || 
								(transaction.orderIds && Array.isArray(transaction.orderIds) && transaction.orderIds.includes(sessionId));
							
							// Vérifier le timestamp (même jour/heure, tolérance 1 heure)
							let timestampMatch = false;
							if (paymentTimestamp && transaction.date) {
								try {
									const paymentDate = new Date(paymentTimestamp);
									const transactionDate = new Date(transaction.date);
									const timeDiff = Math.abs(paymentDate.getTime() - transactionDate.getTime());
									timestampMatch = timeDiff < 3600000; // 1 heure de tolérance
								} catch (e) {
									// Ignorer les erreurs de parsing
								}
							}
							
							// Si au moins 2 critères correspondent, c'est probablement la bonne transaction
							const matchCount = [amountMatch, tableMatch, orderIdMatch, timestampMatch].filter(Boolean).length;
							if (matchCount >= 2) {
								creditClientName = client.name || null;
								console.log(`[history-processor] ✅ Nom client CREDIT trouvé: ${creditClientName} (${matchCount} critères correspondants)`);
								break;
							}
						}
					}
					if (creditClientName) break;
				}
			}
			
			allPayments.push({
				timestamp: payment.timestamp || '',
				paymentMode: payment.paymentMode || 'N/A',
				discount: payment.discount || 0,
				isPercentDiscount: payment.isPercentDiscount === true,
				hasDiscount: hasDiscount,
				discountAmount: discountAmount,
				noteId: payment.noteId || 'main',
				noteName: payment.noteName || 'Note Principale',
				server: payment.server || session.server || 'unknown',
				table: payment.table || session.table,
				sessionId: session.id,
				amount: payment.amount || 0,
				subtotal: payment.subtotal || payment.amount || 0,
				items: (payment.items || []).map(item => ({ ...item })),
				type: payment.type || 'payment',
				reason: payment.reason || '',
				description: payment.description || '',
				// 🆕 Préserver les informations de paiement divisé
				isSplitPayment: payment.isSplitPayment === true,
				splitPaymentId: payment.splitPaymentId || null,
				// 🆕 Préserver le nom du client CREDIT et isCompletePayment (enrichi si manquant)
				creditClientName: creditClientName,
				isCompletePayment: payment.isCompletePayment === true,
			});
		}
	}
	
	// 🆕 ÉTAPE 1: Séparer les paiements divisés des paiements réguliers
	const splitPayments = []; // Paiements divisés
	const regularPayments = []; // Paiements non divisés
	
	for (const payment of allPayments) {
		if (payment.isSplitPayment) {
			splitPayments.push(payment);
		} else {
			regularPayments.push(payment);
		}
	}
	
	// 🆕 ÉTAPE 2: Regrouper les paiements divisés par timestamp (arrondi à la seconde)
	// Tous les paiements divisés avec le même timestamp font partie du même acte de paiement
	const splitPaymentsByTimestamp = {}; // timestamp (arrondi) -> [payments]
	
	for (const payment of splitPayments) {
		let timestampKey;
		try {
			// Arrondir le timestamp à la seconde pour regrouper
			const roundedTimestamp = new Date(payment.timestamp).toISOString().substring(0, 19);
			timestampKey = roundedTimestamp;
		} catch (e) {
			timestampKey = payment.timestamp;
		}
		
		if (!splitPaymentsByTimestamp[timestampKey]) {
			splitPaymentsByTimestamp[timestampKey] = [];
		}
		splitPaymentsByTimestamp[timestampKey].push(payment);
	}
	
	// 🆕 ÉTAPE 3: Fusionner les paiements divisés par timestamp et regrouper par mode
	const groupedSplitPayments = [];
	for (const [timestampKey, payments] of Object.entries(splitPaymentsByTimestamp)) {
		// Regrouper par mode de paiement pour calculer les totaux par mode
		const paymentsByMode = {};
		for (const payment of payments) {
			const mode = payment.paymentMode || 'N/A';
			if (!paymentsByMode[mode]) {
				paymentsByMode[mode] = [];
			}
			paymentsByMode[mode].push(payment);
		}
		
		// Pour chaque mode, fusionner les paiements de toutes les commandes
		const splitPaymentModes = [];
		const splitPaymentAmounts = [];
		const allItems = [];
		const allOrderIds = [];
		const noteIds = new Set();
		// 🆕 Set pour éviter de collecter les articles plusieurs fois pour la même commande
		const processedOrderNotePairs = new Set();
		
		for (const [mode, modePayments] of Object.entries(paymentsByMode)) {
			// Fusionner les paiements de ce mode (de toutes les commandes)
			const totalAmountForMode = modePayments.reduce((sum, p) => sum + p.amount, 0);
			const totalSubtotalForMode = modePayments.reduce((sum, p) => sum + p.subtotal, 0);
			
			splitPaymentModes.push(mode);
			splitPaymentAmounts.push({ mode: mode, amount: totalAmountForMode });
			
			// 🆕 Collecter les orderIds et noteIds (sans doublons)
			for (const p of modePayments) {
				// 🆕 Convertir sessionId en int pour éviter les erreurs de type côté Flutter
				const orderId = typeof p.sessionId === 'number' ? p.sessionId : (typeof p.sessionId === 'string' ? parseInt(p.sessionId, 10) : null);
				if (orderId != null && !isNaN(orderId)) {
					allOrderIds.push(orderId);
				}
				noteIds.add(p.noteId || 'main');
			}
		}
		
		// 🆕 Collecter les articles UNE SEULE FOIS par commande/note (pas par mode)
		// Tous les paiements divisés d'une même commande contiennent les mêmes articles
		for (const payment of payments) {
			const orderId = typeof payment.sessionId === 'number' ? payment.sessionId : (typeof payment.sessionId === 'string' ? parseInt(payment.sessionId, 10) : null);
			const noteId = payment.noteId || 'main';
			const orderNoteKey = `${orderId}_${noteId}`;
			
			// Ne collecter les articles qu'une seule fois par commande/note
			if (!processedOrderNotePairs.has(orderNoteKey) && payment.items && payment.items.length > 0) {
				allItems.push(...payment.items);
				processedOrderNotePairs.add(orderNoteKey);
			}
		}
		
		// 🆕 Dédupliquer les articles (même id et name) en additionnant les quantités
		// Cela permet de consolider les articles de plusieurs commandes différentes
		const uniqueItems = [];
		const itemsMap = {};
		for (const item of allItems) {
			const key = `${item.id}_${item.name}`;
			if (!itemsMap[key]) {
				itemsMap[key] = { ...item, quantity: 0 };
			}
			itemsMap[key].quantity += (item.quantity || 0);
		}
		uniqueItems.push(...Object.values(itemsMap));
		
		// Calculer les totaux globaux (montant, sous-total, remise)
		const totalAmount = splitPaymentAmounts.reduce((sum, s) => sum + s.amount, 0);
		// 🛡️ Sous-total affichage : recalculer depuis les articles dédupliqués (fiable pour l’historique)
		const itemsSubtotal = uniqueItems.reduce((sum, it) => {
			const price = Number(it.price || 0);
			const qty = Number(it.quantity || 0);
			return sum + price * qty;
		}, 0);
		// Conserver l’ancien calcul au cas où (ex: rétro-compat), mais privilégier itemsSubtotal
		const totalSubtotal = itemsSubtotal > 0.0001
			? itemsSubtotal
			: payments.reduce((sum, p) => sum + (p.subtotal || 0), 0);
		const totalDiscountAmount = payments.reduce((sum, p) => sum + (p.discountAmount || 0), 0);
		
		// Utiliser les infos du premier paiement
		const firstPayment = payments[0];
		const primaryNoteId = Array.from(noteIds).find(id => id === 'main') || Array.from(noteIds)[0] || 'main';
		const primaryNoteName = firstPayment.noteName || 'Note Principale';
		
		// 🆕 Récupérer le nom du client CREDIT si présent
		const creditPayment = payments.find(p => p.paymentMode === 'CREDIT');
		const creditClientName = creditPayment?.creditClientName || null;
		
		// 🆕 Déterminer si c'est un paiement complet (tous les paiements doivent avoir isCompletePayment: true)
		const isCompletePayment = payments.every(p => p.isCompletePayment === true);
		// 🆕 Premier paiement avec remise (pour récupérer le taux/type si disponible)
		const firstPaymentWithDiscount = payments.find(p => (p.discountAmount || 0) > 0.01 || p.hasDiscount);
		
		groupedSplitPayments.push({
			timestamp: firstPayment.timestamp,
			amount: totalAmount,
			subtotal: totalSubtotal,
			paymentMode: splitPaymentModes.join(' + '), // Afficher tous les modes
			splitPaymentModes: splitPaymentModes, // Liste des modes pour l'affichage
			splitPaymentAmounts: splitPaymentAmounts.map(s => ({
				mode: s.mode,
				amount: s.amount,
				// 🆕 Ajouter le nom du client si mode CREDIT
				clientName: s.mode === 'CREDIT' ? creditClientName : null,
			})), // Montants totaux par mode (fusionnés de toutes les commandes)
			items: uniqueItems, // Articles dédupliqués
			orderIds: [...new Set(allOrderIds)], // OrderIds uniques
			noteId: primaryNoteId,
			noteName: primaryNoteName,
			server: firstPayment.server || 'unknown',
			table: firstPayment.table,
			isSubNote: primaryNoteId.startsWith('sub_'),
			isMainNote: primaryNoteId === 'main',
			isPartial: !isCompletePayment, // 🆕 Utiliser isCompletePayment au lieu de la logique basée sur le nombre d'articles
			hasDiscount: totalDiscountAmount > 0.01,
			discount: firstPaymentWithDiscount?.discount ?? firstPayment.discount,
			isPercentDiscount: firstPaymentWithDiscount?.isPercentDiscount ?? firstPayment.isPercentDiscount,
			discountAmount: totalDiscountAmount,
			// 🆕 Flag pour indiquer que c'est un paiement divisé
			isSplitPayment: true,
			splitPaymentId: `split_${timestampKey}`,
			// 🆕 Nom du client CREDIT
			creditClientName: creditClientName,
		});
	}
	
	// 🆕 ÉTAPE 3: Regrouper les paiements réguliers par acte de paiement (même timestamp à la seconde, mode, remise)
	const paymentsByAct = {};
	for (const payment of regularPayments) {
		let timestampKey;
		try {
			const roundedTimestamp = new Date(payment.timestamp).toISOString().substring(0, 19);
			timestampKey = `${roundedTimestamp}_${payment.paymentMode}_${payment.discount}_${payment.isPercentDiscount}`;
		} catch (e) {
			timestampKey = `${payment.timestamp}_${payment.paymentMode}_${payment.discount}_${payment.isPercentDiscount}`;
		}
		
		if (!paymentsByAct[timestampKey]) {
			paymentsByAct[timestampKey] = {
				timestamp: payment.timestamp,
				paymentMode: payment.paymentMode,
				discount: payment.discount,
				isPercentDiscount: payment.isPercentDiscount,
				hasDiscount: payment.hasDiscount,
				payments: [],
			};
		}
		paymentsByAct[timestampKey].payments.push(payment);
	}
	
	// 🆕 ÉTAPE 4: Créer les paiements finaux (regroupés par acte)
	// D'abord ajouter les paiements divisés
	const realPayments = [...groupedSplitPayments];
	
	// Ensuite ajouter les paiements réguliers
	for (const act of Object.values(paymentsByAct)) {
		const payments = act.payments;
		
		if (payments.length > 1) {
			// Fusionner plusieurs paiements en un seul acte
			const allItems = payments.flatMap(p => p.items);
			const totalAmount = payments.reduce((sum, p) => sum + p.amount, 0);
			const totalSubtotal = payments.reduce((sum, p) => sum + p.subtotal, 0);
			const totalDiscountAmount = payments.reduce((sum, p) => sum + (p.discountAmount || 0), 0);
			// 🆕 Convertir sessionId en int pour éviter les erreurs de type côté Flutter
			const orderIds = payments.map(p => {
				const id = p.sessionId;
				return typeof id === 'number' ? id : (typeof id === 'string' ? parseInt(id, 10) : null);
			}).filter(id => id != null && !isNaN(id));
			const noteIds = new Set(payments.map(p => p.noteId));
			const primaryNoteId = Array.from(noteIds).find(id => id === 'main') || Array.from(noteIds)[0] || 'main';
			const primaryNoteName = payments[0].noteName || 'Note Principale';
			const server = payments[0].server || 'unknown';
			const table = payments[0].table;
			
			// 🆕 Déterminer si c'est un paiement complet
			const isCompletePayment = payments.every(p => p.isCompletePayment === true);
			// 🆕 Premier paiement avec remise pour récupérer le taux/type si disponible
			const firstPaymentWithDiscount = payments.find(p => (p.discountAmount || 0) > 0.01 || p.hasDiscount);
			// 🆕 Récupérer le nom du client CREDIT si présent
			const creditPayment = payments.find(p => p.paymentMode === 'CREDIT');
			const creditClientName = creditPayment?.creditClientName || null;
			
			realPayments.push({
				timestamp: act.timestamp,
				amount: totalAmount,
				subtotal: totalSubtotal,
				paymentMode: act.paymentMode,
				items: allItems,
				orderIds: orderIds,
				noteId: primaryNoteId,
				noteName: primaryNoteName,
				server: server,
				table: table,
				isSubNote: primaryNoteId.startsWith('sub_'),
				isMainNote: primaryNoteId === 'main',
				isPartial: !isCompletePayment, // 🆕 Utiliser isCompletePayment
				hasDiscount: totalDiscountAmount > 0.01,
				discount: firstPaymentWithDiscount?.discount ?? act.discount,
				isPercentDiscount: firstPaymentWithDiscount?.isPercentDiscount ?? act.isPercentDiscount,
				discountAmount: totalDiscountAmount,
				isSplitPayment: false, // Paiement régulier
				creditClientName: creditClientName, // 🆕 Nom du client CREDIT
			});
		} else {
			// Un seul paiement
			const payment = payments[0];
			realPayments.push({
				timestamp: payment.timestamp,
				amount: payment.amount,
				subtotal: payment.subtotal,
				paymentMode: payment.paymentMode,
				items: payment.items,
				orderIds: (() => {
					const id = payment.sessionId;
					const orderId = typeof id === 'number' ? id : (typeof id === 'string' ? parseInt(id, 10) : null);
					return orderId != null && !isNaN(orderId) ? [orderId] : [];
				})(),
				noteId: payment.noteId,
				noteName: payment.noteName,
				server: payment.server || 'unknown',
				table: payment.table,
				isSubNote: payment.noteId.startsWith('sub_'),
				isMainNote: payment.noteId === 'main',
				isPartial: !(payment.isCompletePayment === true), // 🆕 Utiliser isCompletePayment
				hasDiscount: payment.hasDiscount,
				discount: payment.discount,
				isPercentDiscount: payment.isPercentDiscount,
				discountAmount: payment.discountAmount,
				isSplitPayment: false, // Paiement régulier
				creditClientName: payment.creditClientName || null, // 🆕 Nom du client CREDIT
			});
		}
	}
	
	// Trier par timestamp (plus récent en premier)
	return realPayments.sort((a, b) => new Date(b.timestamp || 0) - new Date(a.timestamp || 0));
}

// Créer un ticket principal depuis les paiements
function createMainTicket(mergedOrderEvents, groupedPayments) {
	if (groupedPayments.length === 0) {
		// Fallback : calculer depuis les commandes si aucun paiement
		const allItems = [];
		let totalFromOrders = 0;
		for (const event of mergedOrderEvents) {
			for (const item of event.items || []) {
				totalFromOrders += (item.price || 0) * (item.quantity || 0);
				const existingIndex = allItems.findIndex(i => i.id === item.id);
				if (existingIndex !== -1) {
					allItems[existingIndex].quantity += (item.quantity || 0);
				} else {
					allItems.push({ ...item });
				}
			}
		}
		const server = mergedOrderEvents[0]?.server || 'unknown';
		const table = mergedOrderEvents[0]?.table;
		
		return {
			type: 'main_ticket',
			timestamp: mergedOrderEvents[0]?.timestamp || new Date().toISOString(),
			total: totalFromOrders,
			subtotal: totalFromOrders,
			items: allItems,
			orderIds: [...new Set(mergedOrderEvents.map(e => e.orderId))],
			server: server,
			table: table,
			description: 'Ticket principal - Total de toutes les commandes',
			hasDiscount: false,
			discount: 0,
			isPercentDiscount: false,
			discountAmount: 0,
			hasMultipleDiscountRates: false,
			discountDetails: [],
		};
	}
	
	// Calculer depuis les paiements
	const totalFromPayments = groupedPayments.reduce((sum, p) => sum + (p.amount || 0), 0);
	
	// 🆕 Collecter tous les articles d'abord
	const allItems = [];
	for (const payment of groupedPayments) {
		for (const item of payment.items || []) {
			const existingIndex = allItems.findIndex(i => i.id === item.id && i.name === item.name);
			if (existingIndex !== -1) {
				allItems[existingIndex].quantity = (allItems[existingIndex].quantity || 0) + (item.quantity || 0);
			} else {
				allItems.push({ ...item });
			}
		}
	}
	
	// 🆕 Calculer le sous-total DIRECTEMENT depuis les articles consolidés (pas depuis les subtotal des paiements)
	// Cela évite les erreurs pour les paiements divisés où chaque mode a son propre subtotal
	const subtotalFromItems = allItems.reduce((sum, item) => {
		const price = Number(item.price || 0);
		const quantity = Number(item.quantity || 0);
		return sum + (price * quantity);
	}, 0);
	
	// 🆕 Détecter les remises RÉELLES (pas calculées comme différence)
	const discountDetails = [];
	const discountRates = new Set();
	let totalRealDiscount = 0;
	for (const payment of groupedPayments) {
		if (payment.hasDiscount && (payment.discountAmount || 0) > 0) {
			const paymentDiscount = payment.discountAmount || 0;
			totalRealDiscount += paymentDiscount;
			const rate = payment.isPercentDiscount ? `${payment.discount}%` : `${payment.discount} TND`;
			discountRates.add(rate);
			discountDetails.push({ rate, amount: paymentDiscount, isPercent: payment.isPercentDiscount });
		}
	}
	
	const firstPaymentWithDiscount = groupedPayments.find(p => p.hasDiscount);
	const server = groupedPayments[0]?.server || 'unknown';
	const table = groupedPayments[0]?.table;
	
	// 🆕 Utiliser le sous-total calculé depuis les articles et la remise réelle
	return {
		type: 'main_ticket',
		timestamp: groupedPayments[0]?.timestamp || mergedOrderEvents[0]?.timestamp || new Date().toISOString(),
		total: totalFromPayments,
		subtotal: subtotalFromItems, // 🆕 Sous-total calculé depuis les articles
		items: allItems,
		orderIds: [...new Set(groupedPayments.flatMap(p => p.orderIds || []))],
		server: server,
		table: table,
		description: 'Ticket principal - Total de toutes les commandes',
		hasDiscount: totalRealDiscount > 0.01, // 🆕 Utiliser la remise réelle, pas la différence
		discount: firstPaymentWithDiscount?.discount || 0,
		isPercentDiscount: firstPaymentWithDiscount?.isPercentDiscount || false,
		discountAmount: totalRealDiscount, // 🆕 Utiliser la remise réelle
		hasMultipleDiscountRates: discountRates.size > 1,
		discountDetails: discountDetails,
	};
}

// Traiter les sessions d'un service et retourner les données formatées
function processServiceSessions(sessions) {
	let totalSubNotes = 0;
	const allOrderEvents = [];
	const allCancellationEvents = [];
	
	for (const session of sessions) {
		totalSubNotes += (session.subNotes || []).length;
		const orderHistory = reconstructOrderEventsFromPayments(session);
		
		for (const event of orderHistory) {
			if (event.action === 'order_created' || event.action === 'items_added' || event.action === 'subnote_created') {
				// 🆕 CORRECTION : Filtrer les événements sans articles pour éviter les commandes vides dans l'historique
				const items = event.items || [];
				const hasItems = items.length > 0;

				// 🆕 CORRECTION : Logique spécifique pour subnote_created
				if (event.action === 'subnote_created') {
					// Vérifier si cette commande a été payée (peu importe le noteId)
					// Car une sous-note envoyée séparément a ses paiements dans mainNote
					const noteId = event.noteId;
					const hasAnyPayments = (session.paymentHistory || []).length > 0;
					const subNoteStillExists = (session.subNotes || []).some(sn => sn.id === noteId && !sn.paid);

					// ✅ Inclure si : elle a des articles OU a été payée OU existe encore (non payée)
					if (!hasItems && !hasAnyPayments && !subNoteStillExists) {
						continue; // Ignorer seulement si elle n'a RIEN du tout
					}
				} else if (event.action === 'order_created' && !hasItems) {
					// Garder la logique originale pour order_created
					continue;
				}

				allOrderEvents.push({
					...event,
					orderId: session.id,
					server: session.server || 'unknown',
					table: session.table
				});
			} else if (event.action === 'items_cancelled') {
				allCancellationEvents.push({
					...event,
					orderId: event.orderId || session.id,
					server: event.handledBy || session.server || 'unknown',
					table: event.table || session.table
				});
			}
		}
	}
	
	const mergedOrderEvents = mergeOrderEvents(allOrderEvents);
	
	// Marquer les articles annulés dans les événements fusionnés
	const cancelledItemsMap = new Map();
	for (const cancellationEvent of allCancellationEvents) {
		const orderId = cancellationEvent.orderId;
		const noteId = cancellationEvent.noteId || 'main';
		for (const item of cancellationEvent.items || []) {
			const key = `${orderId}_${noteId}_${item.id}_${item.name}`;
			if (!cancelledItemsMap.has(key)) {
				cancelledItemsMap.set(key, []);
			}
			cancelledItemsMap.get(key).push({
				quantity: item.quantity || 0,
				cancellationDetails: cancellationEvent.cancellationDetails || {}
			});
		}
	}
	
	for (const event of mergedOrderEvents) {
		const orderId = event.orderId;
		const noteId = event.noteId || 'main';
		
		if (event.items) {
			event.items = event.items.map(item => {
				const key = `${orderId}_${noteId}_${item.id}_${item.name}`;
				const cancelledInfo = cancelledItemsMap.get(key);
				
				if (cancelledInfo && cancelledInfo.length > 0) {
					const totalCancelledQty = cancelledInfo.reduce((sum, c) => sum + (c.quantity || 0), 0);
					const itemQty = item.quantity || 0;
					
					if (totalCancelledQty >= itemQty) {
						return {
							...item,
							cancelled: true,
							cancellationDetails: cancelledInfo[0].cancellationDetails
						};
					}
					if (totalCancelledQty >= itemQty / 2) {
						return {
							...item,
							cancelled: true,
							cancellationDetails: cancelledInfo[0].cancellationDetails
						};
					}
				}
				return item;
			});
		}
	}
	
	const groupedPayments = groupPaymentsByTimestamp(sessions);
	const totalAmount = groupedPayments.reduce((sum, p) => sum + (p.amount || 0), 0);
	const mainTicket = createMainTicket(mergedOrderEvents, groupedPayments);
	
	return {
		sessions: sessions,
		mergedOrderEvents: mergedOrderEvents,
		cancellationEvents: allCancellationEvents,
		groupedPayments: groupedPayments,
		mainTicket: mainTicket,
		stats: {
			totalOrders: mergedOrderEvents.length,
			totalSubNotes: totalSubNotes,
			totalPayments: groupedPayments.length,
			totalAmount: totalAmount,
		},
	};
}

// Grouper les commandes par service (détection basée sur les dates de création/archivage)
function groupOrdersByService(sessions) {
	if (sessions.length === 0) return {};
	
	// Trier les commandes par date de création CROISSANTE (plus ancien en premier)
	sessions.sort((a, b) => {
		const dateA = new Date(a.createdAt || a.archivedAt || 0);
		const dateB = new Date(b.createdAt || b.archivedAt || 0);
		return dateA - dateB;
	});
	
	const services = {};
	let currentServiceIndex = 0;
	
	// Parcourir les commandes dans l'ordre chronologique
	for (let i = 0; i < sessions.length; i++) {
		const session = sessions[i];
		const createdAt = session.createdAt ? new Date(session.createdAt) : null;
		
		// Déterminer si c'est un nouveau service
		let isNewService = false;
		
		if (i === 0) {
			// Première commande = premier service
			isNewService = true;
		} else if (createdAt) {
			// DÉTECTION : trouver la dernière date d'archivage de toutes les commandes précédentes
			let tableEmptyAt = null;
			
			for (let j = 0; j < i; j++) {
				const prevSession = sessions[j];
				const prevArchivedAt = prevSession.archivedAt ? new Date(prevSession.archivedAt) : null;
				
				// Si une commande précédente n'est pas archivée, la table n'est pas encore vide
				if (!prevArchivedAt) {
					tableEmptyAt = null;
					break;
				}
				
				// Garder la date d'archivage la plus récente
				if (tableEmptyAt === null || prevArchivedAt > tableEmptyAt) {
					tableEmptyAt = prevArchivedAt;
				}
			}
			
			// Nouveau service si la table était vide ET que cette commande est créée APRÈS ce moment
			if (tableEmptyAt && createdAt > tableEmptyAt) {
				isNewService = true;
			}
		}
		
		if (isNewService) {
			currentServiceIndex++;
			services[currentServiceIndex] = [];
		}
		
		services[currentServiceIndex].push(session);
	}
	
	return services;
}

module.exports = {
	reconstructOrderEventsFromPayments,
	mergeOrderEvents,
	groupPaymentsByTimestamp,
	createMainTicket,
	processServiceSessions,
	groupOrdersByService,
};

