// 📊 Controller POS - Rapport X
// Génère le rapport X (rapport financier de fin de service)

const dataStore = require('../data');
const fs = require('fs');
const path = require('path');
const { loadMenu } = require('../utils/menuSync');
// 🆕 Import du processeur de paiements commun (source de vérité unique)
const paymentProcessor = require('../utils/payment-processor');

// Charger le menu et créer un mapping itemId → categoryName
async function loadMenuAndCreateMapping(restaurantId = 'les-emirs') {
	try {
		const menu = await loadMenu(restaurantId);
		if (!menu) {
			console.log(`[report-x] Menu non trouvé: ${restaurantId}`);
			return {};
		}

		const categories = Array.isArray(menu.categories) ? menu.categories : [];
		const itemIdToCategory = {};

		for (const category of categories) {
			const categoryName = category.name || '';
			const items = Array.isArray(category.items) ? category.items : [];

			for (const item of items) {
				const itemId = item.id != null ? item.id : item.code;
				if (itemId != null) {
					itemIdToCategory[itemId] = categoryName;
				}
			}
		}

		console.log(`[report-x] Mapping créé: ${Object.keys(itemIdToCategory).length} articles mappés`);
		return itemIdToCategory;
	} catch (e) {
		console.error(`[report-x] Erreur chargement menu: ${e.message}`);
		return {};
	}
}

// Filtrer les commandes par période
function filterOrdersByPeriod(orders, period, dateFrom, dateTo) {
	// Filtrer d'abord les éléments undefined/null
	let filtered = [...orders].filter(order => order != null);

	// Filtrer par dates si fournies
	if (dateFrom || dateTo) {
		filtered = filtered.filter(order => {
			const archivedAt = order && order.archivedAt ? new Date(order.archivedAt) : null;
			if (!archivedAt) return false;

			if (dateFrom) {
				const fromDate = new Date(dateFrom);
				// 🆕 Normaliser les dates pour comparer seulement la date (sans l'heure)
				const archivedAtOnly = new Date(archivedAt.getFullYear(), archivedAt.getMonth(), archivedAt.getDate());
				const fromDateOnly = new Date(fromDate.getFullYear(), fromDate.getMonth(), fromDate.getDate());
				if (archivedAtOnly < fromDateOnly) return false;
			}

			if (dateTo) {
				const toDate = new Date(dateTo);
				// 🆕 Normaliser les dates pour comparer seulement la date (sans l'heure)
				const archivedAtOnly = new Date(archivedAt.getFullYear(), archivedAt.getMonth(), archivedAt.getDate());
				const toDateOnly = new Date(toDate.getFullYear(), toDate.getMonth(), toDate.getDate());
				if (archivedAtOnly > toDateOnly) return false;
			}

			return true;
		});
	}

	// Filtrer par période (MIDI/SOIR)
	if (period && period !== 'ALL') {
		filtered = filtered.filter(order => {
			const archivedAt = order.archivedAt ? new Date(order.archivedAt) : null;
			if (!archivedAt) return false;

			const hour = archivedAt.getHours();

			if (period === 'MIDI') {
				return hour < 15; // Avant 15h00
			} else if (period === 'SOIR') {
				return hour >= 15; // À partir de 15h00
			}

			return true;
		});
	}

	return filtered;
}

// Enrichir les articles avec leur catégorie
function enrichItemsWithCategory(items, itemIdToCategory) {
	return items.map(item => {
		const itemId = item.id;
		const categoryName = itemIdToCategory[itemId] || 'NON CATÉGORISÉ';
		return {
			...item,
			categoryName: categoryName
		};
	});
}

// Regrouper les articles par catégorie
function groupItemsByCategory(allItems) {
	const grouped = {};

	for (const item of allItems) {
		const categoryName = item.categoryName || 'NON CATÉGORISÉ';

		if (!grouped[categoryName]) {
			grouped[categoryName] = {
				items: [],
				totalQuantity: 0,
				totalValue: 0
			};
		}

		// Chercher si l'article existe déjà (même ID et nom)
		const existingIndex = grouped[categoryName].items.findIndex(
			i => i.id === item.id && i.name === item.name
		);

		if (existingIndex !== -1) {
			// Agréger les quantités
			const existing = grouped[categoryName].items[existingIndex];
			existing.quantity = (existing.quantity || 0) + (item.quantity || 0);
			existing.total = (existing.price || 0) * existing.quantity;
		} else {
			// Nouvel article
			grouped[categoryName].items.push({
				id: Number(item.id) || item.id, // 🆕 S'assurer que id est un nombre si possible
				name: item.name,
				price: Number(item.price) || 0,
				quantity: Number(item.quantity) || 0,
				total: (Number(item.price) || 0) * (Number(item.quantity) || 0)
			});
		}

		// Mettre à jour les totaux de la catégorie
		const itemTotal = (item.price || 0) * (item.quantity || 0);
		grouped[categoryName].totalQuantity += (item.quantity || 0);
		grouped[categoryName].totalValue += itemTotal;
	}

	// Calculer les totaux finaux pour chaque catégorie
	for (const categoryName in grouped) {
		const category = grouped[categoryName];
		category.totalQuantity = category.items.reduce((sum, item) => sum + (item.quantity || 0), 0);
		category.totalValue = category.items.reduce((sum, item) => sum + (item.total || 0), 0);
	}

	return grouped;
}

function collectCreditPayments({ server, period, dateFrom, dateTo }) {
	const transactions = [];
	const clientsMap = {};
	let totalDebit = 0;
	let totalCredit = 0;
	const normalizeServer = (value) => (value ? String(value).trim().toUpperCase() : null);
	const targetServer = normalizeServer(server);
	const orderServerCache = new Map();

	const resolveServerFromOrderId = (orderId) => {
		if (orderId === null || orderId === undefined) return null;
		const numericId = Number(orderId);
		if (!Number.isFinite(numericId)) return null;
		if (orderServerCache.has(numericId)) {
			return orderServerCache.get(numericId);
		}
		let match = dataStore.orders.find(o => Number(o.id) === numericId);
		if (!match && Array.isArray(dataStore.archivedOrders)) {
			match = dataStore.archivedOrders.find(o => Number(o.id) === numericId);
		}
		const serverName = match && match.server ? normalizeServer(match.server) : null;
		orderServerCache.set(numericId, serverName);
		return serverName;
	};

	const resolveTransactionServer = (transaction) => {
		const fromField = normalizeServer(transaction.server);
		if (fromField) return fromField;
		if (transaction.orderId !== null && transaction.orderId !== undefined) {
			const found = resolveServerFromOrderId(transaction.orderId);
			if (found) return found;
		}
		if (transaction.orderIds && Array.isArray(transaction.orderIds)) {
			for (const oid of transaction.orderIds) {
				const found = resolveServerFromOrderId(oid);
				if (found) return found;
			}
		}
		if (transaction.ticket && transaction.ticket.server) {
			return normalizeServer(transaction.ticket.server);
		}
		return null;
	};

	const isInFilters = (date) => {
		if (!date) return false;
		const txDate = new Date(date);
		if (Number.isNaN(txDate.getTime())) return false;

		if (dateFrom) {
			const fromDate = new Date(dateFrom);
			// 🆕 Normaliser les dates pour comparer seulement la date (sans l'heure)
			const txDateOnly = new Date(txDate.getFullYear(), txDate.getMonth(), txDate.getDate());
			const fromDateOnly = new Date(fromDate.getFullYear(), fromDate.getMonth(), fromDate.getDate());
			if (txDateOnly < fromDateOnly) return false;
		}
		if (dateTo) {
			const toDate = new Date(dateTo);
			// 🆕 Normaliser les dates pour comparer seulement la date (sans l'heure)
			const txDateOnly = new Date(txDate.getFullYear(), txDate.getMonth(), txDate.getDate());
			const toDateOnly = new Date(toDate.getFullYear(), toDate.getMonth(), toDate.getDate());
			if (txDateOnly > toDateOnly) return false;
		}
		if (period && period !== 'ALL') {
			const hour = txDate.getHours();
			if (period === 'MIDI' && hour >= 15) return false;
			if (period === 'SOIR' && hour < 15) return false;
		}
		return true;
	};

	if (dataStore.clientCredits && Array.isArray(dataStore.clientCredits)) {
		for (const client of dataStore.clientCredits) {
			if (!client.transactions || !Array.isArray(client.transactions)) continue;

			for (const transaction of client.transactions) {
				if (!transaction.date || !isInFilters(transaction.date)) continue;
				if (transaction.type !== 'DEBIT' && transaction.type !== 'CREDIT') continue;

				const amount = Number(transaction.amount) || 0;
				const clientId = client.id || client.clientId || transaction.clientId || null;
				const clientName = client.name || transaction.clientName || 'N/A';
				const transactionServer = resolveTransactionServer(transaction);
				if (targetServer && (!transactionServer || transactionServer !== targetServer)) {
					continue;
				}

				const entry = {
					clientId,
					clientName,
					type: transaction.type,
					amount,
					date: transaction.date,
					description: transaction.description || '',
					paymentMode: transaction.paymentMode ||
						(transaction.description?.includes('ESPECE') ? 'ESPECE' :
							transaction.description?.includes('CARTE') ? 'CARTE' :
								transaction.description?.includes('CHEQUE') ? 'CHEQUE' : 'CREDIT'),
					server: transactionServer
				};
				transactions.push(entry);

				const clientKey = clientId || clientName;
				if (!clientsMap[clientKey]) {
					clientsMap[clientKey] = {
						clientId,
						clientName,
						debitTotal: 0,
						creditTotal: 0,
						balance: 0,
						transactionsCount: 0,
						lastTransaction: transaction.date
					};
				}

				const clientInfo = clientsMap[clientKey];
				if (transaction.type === 'DEBIT') {
					clientInfo.debitTotal += amount;
					totalDebit += amount;
				} else {
					clientInfo.creditTotal += amount;
					totalCredit += amount;
				}
				clientInfo.balance = clientInfo.debitTotal - clientInfo.creditTotal;
				clientInfo.transactionsCount += 1;
				if (new Date(transaction.date) > new Date(clientInfo.lastTransaction)) {
					clientInfo.lastTransaction = transaction.date;
				}
			}
		}
	}

	transactions.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
	const clients = Object.values(clientsMap).sort((a, b) => (b.balance || 0) - (a.balance || 0));
	const totalBalance = totalDebit - totalCredit;

	return {
		summary: {
			totalAmount: totalBalance, // compat rétro
			totalBalance,
			totalDebit,
			totalCredit,
			transactionsCount: transactions.length,
			clients
		},
		details: transactions
	};
}

// Helper pour extraire et normaliser les paiements d'une commande
function extractPaymentsFromOrder(order, server, period, dateFrom, dateTo) {
	const payments = [];

	if (!order.paymentHistory || !Array.isArray(order.paymentHistory)) {
		return payments;
	}

	for (const payment of order.paymentHistory) {
		// Filtrer par serveur si fourni
		if (server) {
			const paymentServer = payment.server || order.server;
			if (!paymentServer || String(paymentServer).toUpperCase() !== String(server).toUpperCase()) {
				continue;
			}
		}

		// Filtrer par période si fournie (basé sur le timestamp du paiement)
		if (payment.timestamp) {
			const paymentDate = new Date(payment.timestamp);

			if (dateFrom) {
				const fromDate = new Date(dateFrom);
				// 🆕 Normaliser les dates pour comparer seulement la date (sans l'heure)
				const paymentDateOnly = new Date(paymentDate.getFullYear(), paymentDate.getMonth(), paymentDate.getDate());
				const fromDateOnly = new Date(fromDate.getFullYear(), fromDate.getMonth(), fromDate.getDate());
				if (paymentDateOnly < fromDateOnly) continue;
			}
			if (dateTo) {
				const toDate = new Date(dateTo);
				// 🆕 Normaliser les dates pour comparer seulement la date (sans l'heure)
				const paymentDateOnly = new Date(paymentDate.getFullYear(), paymentDate.getMonth(), paymentDate.getDate());
				const toDateOnly = new Date(toDate.getFullYear(), toDate.getMonth(), toDate.getDate());
				if (paymentDateOnly > toDateOnly) continue;
			}
			if (period && period !== 'ALL') {
				const hour = paymentDate.getHours();
				if (period === 'MIDI' && hour >= 15) continue;
				if (period === 'SOIR' && hour < 15) continue;
			}
		}

		const paymentNormalized = {
			...payment,
			type: payment.type || 'payment',
			subtotal: payment.subtotal || payment.amount || 0,
			amount: payment.amount || 0,
			// 🆕 PRÉSERVER les champs pourboire (enteredAmount, excessAmount, hasCashInPayment)
			enteredAmount: payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0),
			allocatedAmount: payment.allocatedAmount != null ? payment.allocatedAmount : (payment.amount || 0),
			excessAmount: payment.excessAmount != null ? payment.excessAmount : 0,
			hasCashInPayment: payment.hasCashInPayment != null ? payment.hasCashInPayment : false,
			discount: payment.discount || 0,
			isPercentDiscount: payment.isPercentDiscount === true,
			discountAmount: payment.discountAmount != null
				? payment.discountAmount
				: ((payment.subtotal || payment.amount || 0) - (payment.amount || 0)),
			hasDiscount: payment.hasDiscount != null
				? payment.hasDiscount
				: ((payment.subtotal || payment.amount || 0) > (payment.amount || 0) || (payment.discount && payment.discount > 0)),
			table: payment.table || order.table,
			server: payment.server || order.server || 'unknown',
			noteId: payment.noteId || 'main',
			noteName: payment.noteName || 'Note Principale',
			discountClientName: payment.discountClientName || null,
			covers: payment.covers || order.covers || 1, // 🆕 Inclure les couverts
			orderId: order.id // 🆕 Conserver l'ID de la commande pour traçabilité
		};
		payments.push(paymentNormalized);
	}

	return payments;
}

async function buildReportData({ server, period, dateFrom, dateTo, restaurantId }) {
	const itemIdToCategory = await loadMenuAndCreateMapping(restaurantId || 'les-emirs');

	// 🆕 CORRECTION : Recharger les archives ET les commandes actives depuis MongoDB si serveur cloud
	// Le serveur cloud charge les données uniquement au démarrage, donc il faut recharger
	// les données à chaque génération de rapport pour avoir les données à jour (notamment pour les tables non payées)
	const dbManager = require('../utils/dbManager');
	if (dbManager.isCloud && dbManager.db) {
		try {
			// 🆕 RAPPORTS CLOUD : Voir TOUTES les données synchronisées (pas de filtre)
			// Les données sont taggées à la sauvegarde pour éviter les conflits,
			// mais en lecture pour rapports, le cloud voit tout
			console.log(`[report-x] ☁️ Rechargement complet des données pour rapports cloud`);

			// Recharger TOUTES les commandes synchronisées (avec ou sans serverIdentifier pour compatibilité)
			const archived = await dbManager.archivedOrders.find({
				$or: [
					{ serverIdentifier: { $exists: true } }, // Nouvelles données taggées
					{ serverIdentifier: { $exists: false } } // Anciennes données non taggées (commandes client)
				]
			}).toArray();
			dataStore.archivedOrders.length = 0;
			dataStore.archivedOrders.push(...archived);
			console.log(`[report-x] ☁️ ${dataStore.archivedOrders.length} commandes archivées rechargées depuis MongoDB`);

			// 🆕 Recharger TOUTES les commandes actives synchronisées (avec ou sans serverIdentifier)
			const orders = await dbManager.orders.find({
				$or: [
					{ serverIdentifier: { $exists: true } }, // Nouvelles données taggées
					{ serverIdentifier: { $exists: false } } // Anciennes données non taggées (commandes client)
				]
			}).toArray();

			// 🆕 Filtrer uniquement les commandes avec status !== 'archived' (comme getAllOrders)
			// Les commandes archivées sont dans archivedOrders, pas dans orders
			const activeOrders = orders.filter(o => {
				// Exclure les commandes archivées
				if (o.status === 'archived') {
					return false;
				}
				// Exclure les commandes client en attente (waitingForPos: true, pas encore confirmées)
				// Ces commandes n'ont pas encore d'ID et ne sont pas encore actives
				if (o.waitingForPos === true && (!o.id || o.id === null) && o.source === 'client') {
					return false;
				}
				return true;
			});

			dataStore.orders.length = 0;
			dataStore.orders.push(...activeOrders);
			console.log(`[report-x] ☁️ ${dataStore.orders.length} commandes actives rechargées depuis MongoDB (sur ${orders.length} total)`);

			// 🆕 IMPORTANT : Recharger aussi les clients crédit, sinon le KPI crédit peut être faux sur cloud
			// Les tickets montrent bien les paiements CREDIT car ils viennent de paymentHistory des commandes,
			// mais le KPI "Crédit client" lit dataStore.clientCredits qui n'était pas rechargé depuis MongoDB
			const clients = await dbManager.clientCredits.find({}).toArray();
			dataStore.clientCredits.length = 0;
			dataStore.clientCredits.push(...clients);
			console.log(`[report-x] ☁️ ${dataStore.clientCredits.length} clients crédit rechargés depuis MongoDB`);
		} catch (e) {
			console.error('[report-x] ⚠️ Erreur rechargement données:', e.message);
		}
	}

	// 🆕 SOURCE DE VÉRITÉ UNIQUE : Définir des valeurs par défaut cohérentes
	// Si aucune date n'est fournie, utiliser aujourd'hui par défaut
	if (!dateFrom || !dateTo) {
		const now = new Date();
		const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
		const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

		dateFrom = dateFrom || todayStart.toISOString();
		dateTo = dateTo || todayEnd.toISOString();
	}

	// Normaliser period si non fourni
	period = period || 'ALL';

	// 🆕 Parcourir les commandes archivées ET actives
	let filteredArchivedOrders = dataStore.archivedOrders || [];
	let filteredActiveOrders = dataStore.orders || [];

	// Filtrer par serveur
	if (server) {
		filteredArchivedOrders = filteredArchivedOrders.filter(order => {
			return order.server && String(order.server).toUpperCase() === String(server).toUpperCase();
		});
		filteredActiveOrders = filteredActiveOrders.filter(order => {
			return order.server && String(order.server).toUpperCase() === String(server).toUpperCase();
		});
	}

	// Filtrer par période (pour les commandes archivées, on utilise archivedAt)
	filteredArchivedOrders = filterOrdersByPeriod(filteredArchivedOrders, period, dateFrom, dateTo);

	// Pour les commandes actives, on filtre sur createdAt ou updatedAt (mais les paiements seront filtrés individuellement)
	// On garde toutes les commandes actives, le filtrage se fera au niveau des paiements

	const allPayments = [];
	// 🆕 NE PAS collecter les articles ici : ils seront collectés depuis paidPayments après regroupement
	// Cela évite de compter les articles plusieurs fois pour les paiements divisés

	// Extraire les paiements des commandes archivées
	for (const order of filteredArchivedOrders) {
		const payments = extractPaymentsFromOrder(order, server, period, dateFrom, dateTo);
		allPayments.push(...payments);
	}

	// 🆕 Extraire les paiements des commandes actives (tables encore ouvertes)
	for (const order of filteredActiveOrders) {
		const payments = extractPaymentsFromOrder(order, server, period, dateFrom, dateTo);
		allPayments.push(...payments);
	}

	// 🆕 Pour calculateTotals, on combine les deux listes de commandes
	const allOrdersForTotals = [...filteredArchivedOrders, ...filteredActiveOrders];

	// 🆕 NOTE: totals et itemsByCategory seront créés APRÈS la création de paidPayments
	// pour éviter de compter les articles plusieurs fois pour les paiements divisés
	// ⚠️ CORRECTION: Utiliser le module commun payment-processor pour la déduplication
	// Cela garantit que History, KPI et X Report utilisent la même logique
	const paymentsByMode = paymentProcessor.calculatePaymentsByMode(allPayments);
	// totals sera calculé après paidPayments
	const unpaidTables = calculateUnpaidTables(server);

	if (unpaidTables.total > 0 && unpaidTables.byMode) {
		for (const [mode, data] of Object.entries(unpaidTables.byMode)) {
			if (!paymentsByMode[mode]) {
				paymentsByMode[mode] = { total: 0, count: 0, payers: [] };
			}
			paymentsByMode[mode].total += data.total;
			paymentsByMode[mode].count += data.count;
		}
	}

	// 🆕 Filtrer les remises par période (même logique que pour les crédits)
	// Si dateFrom/dateTo ne sont pas définis, on filtre par date du jour
	let effectiveDateFromForDiscounts = dateFrom;
	let effectiveDateToForDiscounts = dateTo;
	if (!effectiveDateFromForDiscounts || !effectiveDateToForDiscounts) {
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		effectiveDateFromForDiscounts = today.toISOString();
		today.setHours(23, 59, 59, 999);
		effectiveDateToForDiscounts = today.toISOString();
	}

	const discountPaymentsByAct = {};
	for (const payment of allPayments) {
		const hasRealDiscount = payment.hasDiscount && (payment.discountAmount || 0) > 0.01;
		if (!hasRealDiscount) continue;

		// 🆕 Filtrer par période : vérifier que le paiement est dans la période
		if (payment.timestamp) {
			const paymentDate = new Date(payment.timestamp);
			const fromDate = new Date(effectiveDateFromForDiscounts);
			const toDate = new Date(effectiveDateToForDiscounts);
			if (paymentDate < fromDate || paymentDate > toDate) {
				continue; // Ignorer les remises en dehors de la période
			}
		}

		// 🆕 Si c'est un paiement divisé, utiliser splitPaymentId directement pour regrouper tous les modes ensemble
		let actKey;
		if (payment.isSplitPayment && payment.splitPaymentId) {
			// Utiliser directement le splitPaymentId (format: split_TIMESTAMP) pour regrouper tous les modes
			actKey = `${payment.table || 'N/A'}_${payment.splitPaymentId}_${payment.discount || 0}_${payment.isPercentDiscount ? 'PCT' : 'FIX'}`;
		} else {
			const timestampKey = payment.timestamp ? new Date(payment.timestamp).toISOString().slice(0, 19) : '';
			actKey = `${payment.table || 'N/A'}_${timestampKey}_${payment.paymentMode || 'N/A'}_${payment.discount || 0}_${payment.isPercentDiscount ? 'PCT' : 'FIX'}`;
		}

		if (!discountPaymentsByAct[actKey]) {
			discountPaymentsByAct[actKey] = {
				timestamp: payment.timestamp || '',
				table: payment.table || 'N/A',
				server: payment.server || 'unknown',
				paymentMode: payment.paymentMode || 'N/A', // 🆕 Sera remplacé par "MIXTE" si plusieurs modes différents
				discount: payment.discount || 0,
				isPercentDiscount: payment.isPercentDiscount === true,
				isSplitPayment: payment.isSplitPayment || false, // 🆕 Ajouter le flag
				splitPaymentId: payment.splitPaymentId || null, // 🆕 Ajouter l'ID
				payments: []
			};
		}
		discountPaymentsByAct[actKey].payments.push(payment);
	}

	const discountDetails = [];
	for (const act of Object.values(discountPaymentsByAct)) {
		const payments = act.payments;
		const allActItems = [];
		const noteNames = new Set();
		const noteIds = new Set();
		let discountClientName = null; // 🆕 Nom du client pour justifier la remise

		// 🆕 Pour les paiements divisés, dédupliquer par mode + enteredAmount
		// Car chaque transaction apparaît N fois (une par commande)
		const processedTransactions = new Set();

		// 🆕 ÉTAPE 1: Consolider tous les articles (comme dans history-processor.js et paidPayments)
		for (const payment of payments) {
			// 🆕 Dédupliquer les transactions de paiements divisés pour éviter de compter les articles plusieurs fois
			if (act.isSplitPayment && act.splitPaymentId) {
				const enteredAmount = payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0);
				const transactionKey = `${payment.paymentMode}_${enteredAmount.toFixed(3)}`;
				if (processedTransactions.has(transactionKey)) {
					continue; // Transaction déjà comptée
				}
				processedTransactions.add(transactionKey);
			}

			if (payment.noteName) noteNames.add(payment.noteName);
			if (payment.noteId) noteIds.add(payment.noteId);

			// 🆕 Collecter discountClientName (prendre le premier non-null trouvé)
			if (payment.discountClientName && !discountClientName) {
				discountClientName = payment.discountClientName;
			}

			if (payment.items && Array.isArray(payment.items)) {
				for (const item of payment.items) {
					const existingIndex = allActItems.findIndex(i => i.id === item.id && i.name === item.name);
					if (existingIndex !== -1) {
						allActItems[existingIndex].quantity = (allActItems[existingIndex].quantity || 0) + (item.quantity || 0);
					} else {
						// 🆕 S'assurer que id, price et quantity sont des nombres
						allActItems.push({
							...item,
							id: Number(item.id) || item.id,
							price: Number(item.price) || 0,
							quantity: Number(item.quantity) || 0
						});
					}
				}
			}
		}

		// 🆕 ÉTAPE 2: Recalculer le subtotal depuis les articles consolidés (comme dans history-processor.js et paidPayments)
		// Cela évite les erreurs pour les paiements divisés où chaque mode a son propre subtotal
		const totalSubtotal = allActItems.reduce((sum, item) => {
			const price = Number(item.price || 0);
			const quantity = Number(item.quantity || 0);
			return sum + (price * quantity);
		}, 0);

		// 🆕 ÉTAPE 3: Recalculer la remise depuis le taux du premier paiement (comme dans paidPayments ligne 836)
		// car la remise est appliquée au ticket global, pas à chaque transaction
		let totalDiscountAmount = 0;
		if (act.isPercentDiscount && act.discount > 0) {
			totalDiscountAmount = totalSubtotal * (act.discount / 100);
		} else if (act.discount > 0) {
			totalDiscountAmount = act.discount; // Remise fixe
		}

		// 🆕 ÉTAPE 4: Le total du ticket = subtotal - remise (comme dans history-processor.js ligne 649)
		const totalAmount = totalSubtotal - totalDiscountAmount;

		const primaryNoteName = Array.from(noteNames).find(name => name !== 'Note Principale') || 'Note Principale';
		const primaryNoteId = Array.from(noteIds).find(id => id.startsWith('sub_')) || Array.from(noteIds).find(id => id === 'main') || 'main';
		const isSubNote = primaryNoteId.startsWith('sub_');
		const isMainNote = primaryNoteId === 'main';
		const isPartial = isMainNote && allActItems.length > 0 && allActItems.length < 20;

		// 🆕 Pour paiement divisé, déterminer le mode de paiement affiché
		let paymentModeDisplay = act.paymentMode;
		if (act.isSplitPayment && payments.length > 1) {
			const modes = [...new Set(payments.map(p => p.paymentMode).filter(m => m && m !== 'CREDIT'))];
			if (modes.length === 0) {
				paymentModeDisplay = 'CREDIT';
			} else if (modes.length === 1) {
				paymentModeDisplay = modes[0];
			} else {
				paymentModeDisplay = modes.join(' + ');
			}
		}

		discountDetails.push({
			timestamp: act.timestamp,
			table: act.table,
			server: act.server,
			noteName: primaryNoteName,
			noteId: primaryNoteId,
			subtotal: totalSubtotal,
			discountAmount: totalDiscountAmount,
			discount: act.discount,
			isPercentDiscount: act.isPercentDiscount,
			amount: totalAmount,
			paymentMode: paymentModeDisplay, // 🆕 Utiliser le mode calculé pour paiement divisé
			isSplitPayment: act.isSplitPayment || false, // 🆕 Ajouter le flag
			splitPaymentId: act.splitPaymentId || null, // 🆕 Ajouter l'ID
			itemsCount: allActItems.reduce((sum, item) => sum + (item.quantity || 0), 0),
			items: allActItems,
			isSubNote,
			isMainNote,
			isPartial,
			discountClientName: discountClientName // 🆕 Nom du client pour justifier la remise
		});
	}

	discountDetails.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

	const cancellations = collectCancellations(allOrdersForTotals, period, dateFrom, dateTo); // 🆕 Filtrer par période
	const creditData = collectCreditPayments({ server, period, dateFrom, dateTo });
	// 🆕 NOTE: totalRecetteWithCredits sera calculé APRÈS la création de totals

	// 🆕 Pour le chiffre d'affaire du jour, on ne compte QUE les dettes CRÉÉES dans la période (DEBIT)
	// Les soldes de la veille ne font pas partie du chiffre d'affaire du jour
	// ⚠️ IMPORTANT : creditData.details contient déjà les transactions filtrées par période
	// Mais on doit s'assurer qu'on ne compte QUE les DEBIT de la période, pas les soldes totaux des clients

	// 🆕 Filtrer explicitement les DEBIT par période (double vérification)
	// Si dateFrom/dateTo ne sont pas définis, on filtre par date du jour
	let effectiveDateFrom = dateFrom;
	let effectiveDateTo = dateTo;
	if (!effectiveDateFrom || !effectiveDateTo) {
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		effectiveDateFrom = today.toISOString();
		today.setHours(23, 59, 59, 999);
		effectiveDateTo = today.toISOString();
	}

	const debitsInPeriod = creditData.details.filter(tx => {
		if (tx.type !== 'DEBIT') return false;
		// Double vérification du filtre de date
		if (tx.date) {
			const txDate = new Date(tx.date);
			const fromDate = new Date(effectiveDateFrom);
			const toDate = new Date(effectiveDateTo);
			if (txDate < fromDate || txDate > toDate) return false;
		}
		return true;
	});
	const totalDebitsInPeriod = debitsInPeriod.reduce((sum, tx) => sum + (tx.amount || 0), 0);

	// 🆕 Le montant CREDIT = seulement les dettes créées dans la période (pas les soldes de la veille)
	// On utilise directement totalDebitsInPeriod qui est la somme des DEBIT dans creditData.details (déjà filtrés)
	if (totalDebitsInPeriod > 0.0001) {
		// 🆕 Extraire les noms des clients uniques qui ont eu un DEBIT dans la période
		const creditPayers = [...new Set(debitsInPeriod.map(tx => tx.clientName || tx.clientId || 'Client'))];

		paymentsByMode['CREDIT'] = {
			total: totalDebitsInPeriod, // 🆕 Seulement les DEBIT de la période (déjà filtrés par collectCreditPayments)
			count: creditPayers.length,
			payers: creditPayers,
		};
	} else if (paymentsByMode['CREDIT']) {
		delete paymentsByMode['CREDIT'];
	}

	const reportId = `X-${new Date().toISOString().split('T')[0]}-${period || 'ALL'}-${Date.now().toString().slice(-3)}`;

	// 🆕 Filtrer les paiements encaissés (exclure seulement NON PAYÉ)
	// ⚠️ IMPORTANT : Inclure CREDIT pour qu'il apparaisse dans l'historique et les tickets
	// même s'il n'est pas comptabilisé dans "encaissé" (c'est une dette différée)
	const filteredPaidPayments = allPayments.filter(payment => {
		return payment.type === 'payment' &&
			payment.paymentMode &&
			payment.paymentMode !== 'NON PAYÉ';
		// 🆕 CREDIT est maintenant inclus pour affichage dans l'historique
	});

	// 🆕 Regrouper les paiements par acte de paiement (même timestamp à la seconde, même table, mode, remise)
	// Cela permet de fusionner les paiements créés par payMultiOrders (1 paiement par commande) en un seul acte visible
	// ⚠️ IMPORTANT : On inclut la table dans la clé pour éviter de regrouper des paiements de tables différentes
	// 🆕 Pour les paiements divisés, utiliser splitPaymentId pour regrouper tous les modes ensemble
	const paymentsByAct = {};
	for (const payment of filteredPaidPayments) {
		let timestampKey;
		try {
			const roundedTimestamp = new Date(payment.timestamp).toISOString().substring(0, 19);
			const tableKey = String(payment.table || 'N/A');

			// 🆕 Si c'est un paiement divisé, utiliser splitPaymentId directement pour regrouper tous les modes ensemble
			if (payment.isSplitPayment && payment.splitPaymentId) {
				// Utiliser directement le splitPaymentId (format: split_TIMESTAMP) pour regrouper tous les modes
				timestampKey = `${tableKey}_${payment.splitPaymentId}_${payment.discount || 0}_${payment.isPercentDiscount || false}`;
			} else {
				// Paiement normal : regroupement par timestamp + mode + remise
				timestampKey = `${tableKey}_${roundedTimestamp}_${payment.paymentMode}_${payment.discount || 0}_${payment.isPercentDiscount || false}`;
			}
		} catch (e) {
			const tableKey = String(payment.table || 'N/A');
			if (payment.isSplitPayment && payment.splitPaymentId) {
				// Utiliser directement le splitPaymentId pour regrouper tous les modes
				timestampKey = `${tableKey}_${payment.splitPaymentId}_${payment.discount || 0}_${payment.isPercentDiscount ? 'PCT' : 'FIX'}`;
			} else {
				timestampKey = `${tableKey}_${payment.timestamp}_${payment.paymentMode}_${payment.discount || 0}_${payment.isPercentDiscount ? 'PCT' : 'FIX'}`;
			}
		}

		if (!paymentsByAct[timestampKey]) {
			paymentsByAct[timestampKey] = {
				timestamp: payment.timestamp,
				paymentMode: payment.paymentMode, // 🆕 Sera remplacé par "MIXTE" si plusieurs modes différents
				discount: payment.discount || 0,
				isPercentDiscount: payment.isPercentDiscount || false,
				hasDiscount: payment.hasDiscount || false,
				isSplitPayment: payment.isSplitPayment || false, // 🆕 Ajouter le flag
				splitPaymentId: payment.splitPaymentId || null, // 🆕 Ajouter l'ID
				payments: [],
			};
		}
		paymentsByAct[timestampKey].payments.push(payment);
	}


	// 🆕 Créer les paiements finaux (regroupés par acte)
	const paidPayments = [];
	for (const act of Object.values(paymentsByAct)) {
		const payments = act.payments;

		if (payments.length > 1) {
			// Fusionner plusieurs paiements en un seul acte
			const allItems = [];
			// 🆕 Détecter si c'est un paiement divisé
			const isSplitPayment = payments[0].isSplitPayment === true && payments[0].splitPaymentId != null;

			if (isSplitPayment) {
				// 🆕 CORRECTION: Pour paiement divisé avec plusieurs commandes, collecter les articles de TOUTES les commandes
				// Chaque commande a ses propres articles, et chaque mode d'une même commande répète ces articles
				// Donc on doit : 1) prendre les articles une seule fois par commande, 2) fusionner toutes les commandes

				// Étape 1: Grouper les paiements par orderId pour éviter les doublons entre modes
				const itemsByOrderId = new Map(); // orderId -> Set d'items (clé: "id-name")

				for (const payment of payments) {
					const orderId = payment.orderId;
					if (!orderId) continue;

					// Si on n'a pas encore vu cette commande, créer un Set pour ses articles
					if (!itemsByOrderId.has(orderId)) {
						itemsByOrderId.set(orderId, new Map()); // Map pour stocker les articles de cette commande
					}

					const orderItems = itemsByOrderId.get(orderId);

					// Ajouter les articles de ce paiement (même si c'est un autre mode, les articles sont les mêmes)
					for (const item of payment.items || []) {
						const itemKey = `${item.id}-${item.name}`;
						if (!orderItems.has(itemKey)) {
							// Premier mode de cette commande qui contient cet article : l'ajouter
							// 🆕 S'assurer que id, price et quantity sont des nombres
							orderItems.set(itemKey, {
								...item,
								id: Number(item.id) || item.id,
								price: Number(item.price) || 0,
								quantity: Number(item.quantity) || 0
							});
						}
						// Si déjà présent, ignorer (c'est le même article répété pour un autre mode)
					}
				}

				// Étape 2: Fusionner les articles de toutes les commandes en dédupliquant par (id, name)
				const finalItems = new Map(); // Clé: "id-name" -> item avec quantité totale

				for (const orderItemsMap of itemsByOrderId.values()) {
					for (const item of orderItemsMap.values()) {
						const itemKey = `${item.id}-${item.name}`;
						if (finalItems.has(itemKey)) {
							// Article déjà vu dans une autre commande : additionner les quantités
							const existing = finalItems.get(itemKey);
							existing.quantity = (existing.quantity || 0) + (item.quantity || 0);
						} else {
							// Nouvel article : l'ajouter
							finalItems.set(itemKey, { ...item });
						}
					}
				}

				// Convertir en liste
				for (const item of finalItems.values()) {
					// 🆕 S'assurer que id, price et quantity sont des nombres avant d'ajouter à allItems
					allItems.push({
						...item,
						id: Number(item.id) || item.id,
						price: Number(item.price) || 0,
						quantity: Number(item.quantity) || 0
					});
				}
			} else {
				// 🆕 Paiement normal : fusionner les articles de tous les paiements
				for (const payment of payments) {
					for (const item of payment.items || []) {
						const existingIndex = allItems.findIndex(i => i.id === item.id && i.name === item.name);
						if (existingIndex !== -1) {
							allItems[existingIndex].quantity = (allItems[existingIndex].quantity || 0) + (item.quantity || 0);
						} else {
							// 🆕 S'assurer que id, price et quantity sont des nombres
							allItems.push({
								...item,
								id: Number(item.id) || item.id,
								price: Number(item.price) || 0,
								quantity: Number(item.quantity) || 0
							});
						}
					}
				}
			}

			// 🆕 RÈGLE 2.1 .cursorrules: Pour paiements divisés, dédupliquer les transactions
			let totalAmount = 0;
			let totalSubtotal = 0;
			let totalDiscountAmount = 0;

			if (act.isSplitPayment) {
				// 🆕 CORRECTION: Calculer le subtotal depuis les articles dédupliqués (comme dans history-processor.js)
				// au lieu de sommer les allocatedAmount (qui sont proportionnels)
				totalSubtotal = allItems.reduce((sum, item) => {
					const price = Number(item.price || 0);
					const qty = Number(item.quantity || 0);
					return sum + (price * qty);
				}, 0);

				// 🆕 CORRECTION: Recalculer la remise depuis le totalSubtotal et le taux (comme dans discountDetails)
				// car payments[0].discountAmount est proportionnel (part de la remise pour une seule commande)
				// La remise est appliquée au ticket global, donc on doit la recalculer depuis le totalSubtotal
				if (act.isPercentDiscount && act.discount > 0) {
					totalDiscountAmount = totalSubtotal * (act.discount / 100);
				} else if (act.discount > 0) {
					totalDiscountAmount = act.discount; // Remise fixe
				} else {
					totalDiscountAmount = 0;
				}

				// 🆕 Le totalAmount doit être totalSubtotal - totalDiscountAmount (montant du ticket après remise)
				totalAmount = totalSubtotal - totalDiscountAmount;
			} else {
				totalAmount = payments.reduce((sum, p) => sum + (p.amount || 0), 0);
				totalSubtotal = payments.reduce((sum, p) => sum + (p.subtotal || p.amount || 0), 0);
				// 🆕 CORRECTION: Utiliser discountAmount directement (calculé à la source)
				totalDiscountAmount = payments.reduce((sum, p) => sum + (p.discountAmount || 0), 0);
			}
			const noteIds = new Set(payments.map(p => p.noteId));
			const noteNames = new Set(payments.map(p => p.noteName));
			const primaryNoteId = Array.from(noteIds).find(id => id === 'main') || Array.from(noteIds)[0] || 'main';
			const primaryNoteName = Array.from(noteNames).find(name => name === 'Note Principale') || Array.from(noteNames)[0] || 'Note Principale';
			const server = payments[0].server || 'unknown';
			const table = payments[0].table;
			const covers = payments[0].covers || 1;
			// 🆕 Conserver les orderIds pour traçabilité (savoir quelles commandes ont été payées ensemble)
			const orderIds = [...new Set(payments.map(p => p.orderId).filter(id => id !== null && id !== undefined))];

			// 🆕 Pour paiement divisé, déterminer le mode de paiement affiché
			let paymentModeDisplay = act.paymentMode;
			if (act.isSplitPayment) {
				const modes = [...new Set(payments.map(p => p.paymentMode).filter(m => m && m !== 'CREDIT'))];
				if (modes.length === 0) {
					paymentModeDisplay = 'CREDIT';
				} else if (modes.length === 1) {
					paymentModeDisplay = modes[0];
				} else {
					paymentModeDisplay = modes.join(' + ');
				}
			}

			// 🆕 Calculer les totaux pourboire pour paiement divisé
			// ⚠️ RÈGLE 2.1 .cursorrules: Dédupliquer les transactions (chaque transaction apparaît N fois par commande)
			// ⚠️ RÈGLE 3.1 .cursorrules: Utiliser la même logique que payment-processor.js (source de vérité unique)
			let totalEnteredAmount = 0;
			let totalAllocatedAmount = 0;
			const hasCashInPayment = payments.some(p => p.hasCashInPayment === true);

			if (act.isSplitPayment) {
				// 🆕 CORRECTION: Utiliser la même logique que payment-processor.js
				// Compter les occurrences de chaque mode + enteredAmount, puis diviser par nbOrders
				const distinctOrderIds = new Set(payments.map(p => p.orderId || p.sessionId)).size;
				const nbOrders = distinctOrderIds > 0 ? distinctOrderIds : 1;
				
				// Compter les occurrences de chaque transaction
				const txCounts = {};
				for (const p of payments) {
					const enteredAmount = p.enteredAmount != null ? p.enteredAmount : (p.amount || 0);
					const allocatedAmount = p.allocatedAmount != null ? p.allocatedAmount : (p.amount || 0);
					const txKey = `${p.paymentMode}_${enteredAmount.toFixed(3)}`;
					
					if (!txCounts[txKey]) {
						txCounts[txKey] = {
							count: 0,
							enteredAmount: enteredAmount,
							allocatedSum: 0
						};
					}
					txCounts[txKey].count++;
					txCounts[txKey].allocatedSum += allocatedAmount;
				}
				
				// Calculer les totaux en tenant compte du nombre réel de transactions
				for (const txKey in txCounts) {
					const tx = txCounts[txKey];
					const numTransactions = Math.round(tx.count / nbOrders);
					totalEnteredAmount += tx.enteredAmount * numTransactions;
					totalAllocatedAmount += tx.allocatedSum; // allocatedSum est déjà la somme de toutes les commandes
				}
			} else {
				totalEnteredAmount = payments.reduce((sum, p) => sum + (p.enteredAmount != null ? p.enteredAmount : (p.amount || 0)), 0);
				totalAllocatedAmount = payments.reduce((sum, p) => sum + (p.allocatedAmount != null ? p.allocatedAmount : (p.amount || 0)), 0);
			}

			// Pourboire = enteredAmount - allocatedAmount (si pas de cash)
			const totalExcessAmount = (!hasCashInPayment && totalEnteredAmount > totalAllocatedAmount)
				? (totalEnteredAmount - totalAllocatedAmount)
				: 0;

			paidPayments.push({
				id: `payment_act_${act.timestamp}_${Math.random().toString(36).substr(2, 9)}`,
				timestamp: act.timestamp,
				table: table,
				server: server,
				noteId: primaryNoteId,
				noteName: primaryNoteName,
				paymentMode: paymentModeDisplay, // 🆕 Utiliser le mode calculé pour paiement divisé
				isSplitPayment: act.isSplitPayment || false, // 🆕 Ajouter le flag
				splitPaymentId: act.splitPaymentId || null, // 🆕 Ajouter l'ID
				subtotal: totalSubtotal,
				discount: act.discount,
				discountAmount: totalDiscountAmount,
				isPercentDiscount: act.isPercentDiscount,
				hasDiscount: act.hasDiscount,
				amount: totalAmount,
				// 🆕 PRÉSERVER les champs pourboire pour paiement divisé
				enteredAmount: totalEnteredAmount,
				allocatedAmount: totalAllocatedAmount,
				excessAmount: totalExcessAmount,
				hasCashInPayment: hasCashInPayment,
				items: allItems,
				covers: covers,
				orderIds: orderIds.length > 0 ? orderIds : undefined, // 🆕 IDs des commandes regroupées (si plusieurs)
				// 🆕 Informations sur le paiement divisé (pour traçabilité)
				// Dédupliquer par mode + enteredAmount pour éviter les doublons (chaque transaction apparaît N fois par commande)
				splitPaymentModes: act.isSplitPayment ? [...new Set(payments.map(p => p.paymentMode))] : undefined,
				splitPaymentAmounts: act.isSplitPayment ? (() => {
					// 🆕 CORRECTION : Utiliser la même logique de déduplication que paymentDetails
					// Clé : splitPaymentId + mode + enteredAmount (selon .cursorrules 3.1)
					const processedPayments = new Set();
					const uniqueAmounts = [];

					for (const p of payments) {
						if (p.paymentMode === 'CREDIT' && !p.hasCashInPayment) continue; // Exclure CREDIT pur

						const enteredAmount = p.enteredAmount != null ? p.enteredAmount : (p.amount || 0);
						// 🆕 Clé de déduplication identique à paymentDetails
						const paymentKey = `${p.splitPaymentId || 'no-split'}_${p.paymentMode}_${enteredAmount.toFixed(3)}`;

						if (!processedPayments.has(paymentKey)) {
							processedPayments.add(paymentKey);
							const detail = { mode: p.paymentMode, amount: enteredAmount };
							if (p.paymentMode === 'CREDIT' && p.creditClientName) {
								detail.clientName = p.creditClientName;
							}
							uniqueAmounts.push(detail);
						}
					}
					return uniqueAmounts;
				})() : undefined,
				// 🆕 Ticket encaissé (format ticket de caisse)
				ticket: (() => {
					// 🆕 Calculer le montant total encaissé (exclut CREDIT car c'est une dette différée)
					// ⚠️ RÈGLE 3.1 .cursorrules: Utiliser la même logique que payment-processor.js
					const totalAmountEncaisse = act.isSplitPayment ? (() => {
						// Utiliser la même logique que pour totalEnteredAmount (dédupliquer correctement)
						const distinctOrderIds = new Set(payments.map(p => p.orderId || p.sessionId)).size;
						const nbOrders = distinctOrderIds > 0 ? distinctOrderIds : 1;
						
						const txCounts = {};
						for (const p of payments) {
							// Exclure CREDIT du montant encaissé
							if (p.paymentMode === 'CREDIT') continue;
							const enteredAmount = p.enteredAmount != null ? p.enteredAmount : (p.amount || 0);
							const txKey = `${p.paymentMode}_${enteredAmount.toFixed(3)}`;
							
							if (!txCounts[txKey]) {
								txCounts[txKey] = {
									count: 0,
									enteredAmount: enteredAmount
								};
							}
							txCounts[txKey].count++;
						}
						
						let total = 0;
						for (const txKey in txCounts) {
							const tx = txCounts[txKey];
							const numTransactions = Math.round(tx.count / nbOrders);
							total += tx.enteredAmount * numTransactions;
						}
						return total;
					})() : (payments[0].paymentMode === 'CREDIT' ? 0 : totalEnteredAmount);

					return {
						table: table,
						date: act.timestamp || new Date().toISOString(),
						items: allItems.map(item => ({
							name: item.name,
							quantity: item.quantity || 0,
							price: item.price || 0,
							subtotal: (item.price || 0) * (item.quantity || 0)
						})),
						subtotal: totalSubtotal,
						discount: act.discount || 0,
						discountAmount: totalDiscountAmount,
						total: totalAmount,
						paymentMode: paymentModeDisplay, // 🆕 Utiliser le mode calculé
						isSplitPayment: act.isSplitPayment || false, // 🆕 Ajouter le flag
						covers: covers,
						server: server,
						// 🆕 Ajouter les détails des paiements et le montant total encaissé
						// ⚠️ RÈGLE .cursorrules 3.1: Utiliser payment-processor.js comme source de vérité unique
						// DÉDUPLICATION selon splitPaymentId + mode + enteredAmount
						paymentDetails: (() => {
							const processedPayments = new Set();
							const uniquePayments = [];

							for (const p of payments) {
								if (p.paymentMode === 'CREDIT' && !p.hasCashInPayment) continue; // Exclure CREDIT pur

								const enteredAmount = p.enteredAmount != null ? p.enteredAmount : (p.amount || 0);
								// 🆕 Clé de déduplication selon .cursorrules 3.1
								const paymentKey = `${p.splitPaymentId || 'no-split'}_${p.paymentMode}_${enteredAmount.toFixed(3)}`;

								if (!processedPayments.has(paymentKey)) {
									processedPayments.add(paymentKey);
									uniquePayments.push({
										mode: p.paymentMode || 'INCONNU',
										amount: enteredAmount,
										...(p.paymentMode === 'CREDIT' && p.creditClientName ? { clientName: p.creditClientName } : {})
									});
								}
							}

							return uniquePayments;
						})(),
						totalAmount: totalAmountEncaisse > 0.01 ? totalAmountEncaisse : undefined, // 🆕 Montant total encaissé (exclut CREDIT)
						excessAmount: totalExcessAmount > 0.01 ? totalExcessAmount : undefined // 🆕 Pourboire
					};
				})()
			});
		} else {
			// Un seul paiement
			const payment = payments[0];
			paidPayments.push({
				id: payment.id || `payment_${Date.now()}_${Math.random()}`,
				timestamp: payment.timestamp,
				table: payment.table,
				server: payment.server,
				noteId: payment.noteId,
				noteName: payment.noteName,
				paymentMode: payment.paymentMode,
				isSplitPayment: payment.isSplitPayment || false, // 🆕 Ajouter le flag
				splitPaymentId: payment.splitPaymentId || null, // 🆕 Ajouter l'ID
				subtotal: payment.subtotal || 0,
				discount: payment.discount || 0,
				discountAmount: payment.discountAmount || 0,
				isPercentDiscount: payment.isPercentDiscount || false,
				hasDiscount: payment.hasDiscount || false,
				amount: payment.amount || 0,
				// 🆕 PRÉSERVER les champs pourboire pour paiement simple
				enteredAmount: payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0),
				allocatedAmount: payment.allocatedAmount != null ? payment.allocatedAmount : (payment.amount || 0),
				excessAmount: payment.excessAmount != null ? payment.excessAmount : 0,
				hasCashInPayment: payment.hasCashInPayment != null ? payment.hasCashInPayment : false,
				items: (payment.items || []).map(item => ({
					...item,
					id: Number(item.id) || item.id,
					price: Number(item.price) || 0,
					quantity: Number(item.quantity) || 0
				})),
				covers: payment.covers || 1,
				// 🆕 Ticket encaissé (format ticket de caisse)
				ticket: (() => {
					// 🆕 Calculer le montant total encaissé (exclut CREDIT car c'est une dette différée)
					const totalAmountEncaisse = payment.paymentMode === 'CREDIT' ? 0 :
						(payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0));

					return {
						table: payment.table,
						date: payment.timestamp || new Date().toISOString(),
						items: (payment.items || []).map(item => ({
							name: item.name,
							quantity: item.quantity || 0,
							price: item.price || 0,
							subtotal: (item.price || 0) * (item.quantity || 0)
						})),
						subtotal: payment.subtotal || 0,
						discount: payment.discount || 0,
						discountAmount: payment.discountAmount || 0,
						total: payment.amount || 0,
						paymentMode: payment.paymentMode,
						isSplitPayment: payment.isSplitPayment || false, // 🆕 Ajouter le flag
						covers: payment.covers || 1,
						server: payment.server,
						// 🆕 Ajouter les détails des paiements et le montant total encaissé
						paymentDetails: [{
							mode: payment.paymentMode,
							amount: payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0),
							...(payment.paymentMode === 'CREDIT' && payment.creditClientName ? { clientName: payment.creditClientName } : {})
						}],
						totalAmount: totalAmountEncaisse > 0.01 ? totalAmountEncaisse : undefined, // 🆕 Montant total encaissé (exclut CREDIT)
						excessAmount: payment.excessAmount != null && payment.excessAmount > 0.01 ? payment.excessAmount : undefined // 🆕 Pourboire
					};
				})()
			});
		}
	}

	// Trier les paiements encaissés par date (plus récent en premier)
	paidPayments.sort((a, b) => {
		const dateA = new Date(a.timestamp || 0);
		const dateB = new Date(b.timestamp || 0);
		return dateB - dateA;
	});


	// 🆕 Créer un map pour retrouver les tickets par actKey (après construction de paidPayments)
	// Cela garantit que le ticket de remise = ticket exact de l'acte (comme dans paidPayments)
	const ticketByActKey = {};
	for (const payment of paidPayments) {
		if (payment.ticket) {
			let actKey;
			if (payment.isSplitPayment && payment.splitPaymentId) {
				actKey = `${payment.table || 'N/A'}_${payment.splitPaymentId}_${payment.discount || 0}_${payment.isPercentDiscount ? 'PCT' : 'FIX'}`;
			} else {
				const timestampKey = payment.timestamp ? new Date(payment.timestamp).toISOString().slice(0, 19) : '';
				actKey = `${payment.table || 'N/A'}_${timestampKey}_${payment.paymentMode || 'N/A'}_${payment.discount || 0}_${payment.isPercentDiscount ? 'PCT' : 'FIX'}`;
			}
			ticketByActKey[actKey] = payment.ticket;
		}
	}

	// 🆕 Utiliser le ticket sauvegardé dans paidPayments pour chaque remise
	// Cela garantit que le ticket de remise = ticket exact payé (cohérent avec historique et KPI)
	for (const discount of discountDetails) {
		let actKey;
		if (discount.isSplitPayment && discount.splitPaymentId) {
			actKey = `${discount.table || 'N/A'}_${discount.splitPaymentId}_${discount.discount || 0}_${discount.isPercentDiscount ? 'PCT' : 'FIX'}`;
		} else {
			const timestampKey = discount.timestamp ? new Date(discount.timestamp).toISOString().slice(0, 19) : '';
			actKey = `${discount.table || 'N/A'}_${timestampKey}_${discount.paymentMode || 'N/A'}_${discount.discount || 0}_${discount.isPercentDiscount ? 'PCT' : 'FIX'}`;
		}

		// Utiliser le ticket sauvegardé si disponible, sinon garder les items pour compatibilité
		const savedTicket = ticketByActKey[actKey];
		if (savedTicket) {
			discount.ticket = savedTicket;
			// 🆕 Mettre à jour les valeurs de discount avec celles du ticket (source de vérité unique)
			// Cela garantit que le X Report et la liste KPI affichent les mêmes valeurs que le ticket
			discount.subtotal = savedTicket.subtotal || discount.subtotal;
			discount.discountAmount = savedTicket.discountAmount || discount.discountAmount;
			discount.amount = savedTicket.total || discount.amount;
		} else {
			// Fallback : créer le ticket depuis les items (cas rare où le ticket n'existe pas)
			discount.ticket = {
				table: discount.table,
				date: discount.timestamp || new Date().toISOString(),
				items: discount.items.map(item => ({
					name: item.name,
					quantity: item.quantity || 0,
					price: item.price || 0,
					subtotal: (item.price || 0) * (item.quantity || 0)
				})),
				subtotal: discount.subtotal,
				discount: discount.discount || 0,
				discountAmount: discount.discountAmount,
				total: discount.amount,
				paymentMode: discount.paymentMode,
				isSplitPayment: discount.isSplitPayment || false,
				covers: discount.covers || 1,
				server: discount.server
			};
		}
	}

	// 🆕 CORRECTION: Reconstruire allItems depuis paidPayments (qui a déjà la logique de fusion correcte)
	// Cela évite de compter les articles plusieurs fois pour les paiements divisés
	const allItems = [];
	const itemsMap = new Map(); // Clé: "id-name" -> item avec quantité totale

	for (const payment of paidPayments) {
		if (!payment.items || !Array.isArray(payment.items)) continue;

		for (const item of payment.items) {
			const itemKey = `${item.id}-${item.name}`;
			if (itemsMap.has(itemKey)) {
				// Article déjà vu : additionner les quantités
				const existing = itemsMap.get(itemKey);
				existing.quantity = (existing.quantity || 0) + (item.quantity || 0);
			} else {
				// Nouvel article : l'ajouter
				itemsMap.set(itemKey, {
					...item,
					id: Number(item.id) || item.id,
					price: Number(item.price) || 0,
					quantity: Number(item.quantity) || 0
				});
			}
		}
	}

	// Convertir la Map en liste
	for (const item of itemsMap.values()) {
		allItems.push(item);
	}

	// 🆕 Maintenant créer itemsByCategory depuis allItems (qui contient les articles dédupliqués)
	const enrichedItems = enrichItemsWithCategory(allItems, itemIdToCategory);
	const itemsByCategory = groupItemsByCategory(enrichedItems);

	// 🆕 CORRECTION: Utiliser le module commun payment-processor pour calculer les totaux
	// Cela garantit que History, KPI et X Report utilisent la même logique de déduplication
	// ⚠️ RÈGLE .cursorrules 2.1: allPayments contient les paiements bruts (N fois par commande pour split)
	const processedData = paymentProcessor.deduplicateAndCalculate(allPayments);

	// 🆕 CORRECTION: Utiliser discountDetails (remises recalculées correctement) comme source de vérité pour totalRemises
	// car paymentProcessor additionne les discountAmount proportionnels sans les recalculer depuis totalSubtotal
	const totalRemisesFromDiscounts = discountDetails.reduce((sum, d) => sum + (d.discountAmount || 0), 0);
	const nombreRemisesFromDiscounts = discountDetails.length;

	// Extraire les totaux du module commun
	const totals = {
		chiffreAffaire: processedData.totals.chiffreAffaire,
		totalRecette: processedData.totals.totalRecette,
		totalRemises: totalRemisesFromDiscounts, // 🆕 Utiliser les remises recalculées depuis discountDetails
		nombreRemises: nombreRemisesFromDiscounts, // 🆕 Utiliser le nombre depuis discountDetails
		// Calculer nombreCouverts et nombreArticles depuis paidPayments (déjà regroupés)
		nombreCouverts: paidPayments.reduce((sum, p) => sum + (p.covers || 0), 0),
		nombreArticles: paidPayments.reduce((sum, p) => {
			return sum + (p.items || []).reduce((itemSum, item) => itemSum + (item.quantity || 0), 0);
		}, 0),
		// 🆕 Pourboires calculés par le module commun
		totalPourboires: processedData.totals.totalPourboires,
		tipsByServer: processedData.tipsByServer
	};

	// 🆕 Ajouter les paiements reçus pour régler les crédits au TOTAL RECETTE
	// Dans un Rapport X, les règlements de dettes clients sont des encaissements supplémentaires
	const creditTotalCredit = creditData.summary.totalCredit || 0;
	const totalRecetteWithCredits = totals.totalRecette + creditTotalCredit;

	const chiffreAffaire = totals.chiffreAffaire + (unpaidTables.total || 0);

	const report = {
		reportId,
		period: period || 'ALL',
		dateFrom: dateFrom || null,
		dateTo: dateTo || null,
		generatedAt: new Date().toISOString(),
		server: server || 'TOUS',
		summary: {
			chiffreAffaire,
			totalRecette: totalRecetteWithCredits, // 🆕 Inclure les règlements de crédits
			totalRemises: totals.totalRemises,
			nombreRemises: totals.nombreRemises,
			nombreCouverts: totals.nombreCouverts,
			nombreArticles: totals.nombreArticles,
			nombreTickets: paidPayments.length // 🆕 Nombre de tickets = nombre d'actes de paiement (regroupe les paiements divisés)
		},
		itemsByCategory,
		paymentsByMode,
		unpaidTables,
		paidPayments, // 🆕 Liste complète des paiements encaissés avec tickets
		discountDetails,
		cancellations,
		creditSummary: {
			totalAmount: totalDebitsInPeriod > 0.0001 ? totalDebitsInPeriod : 0, // 🆕 Pour le KPI : seulement les dettes créées dans la période
			totalBalance: creditData.summary.totalBalance, // Solde total (pour référence, peut être négatif)
			totalDebit: creditData.summary.totalDebit, // Total DEBIT de la période
			totalCredit: creditData.summary.totalCredit, // Total CREDIT de la période
			totalDebitsInPeriod: totalDebitsInPeriod, // 🆕 Dettes créées dans la période (pour le KPI)
			transactionsCount: creditData.summary.transactionsCount,
			clients: creditData.summary.clients,
			recentTransactions: creditData.details.slice(0, 20)
		}
	};

	return {
		report,
		creditDetails: creditData.details
	};
}

// Regrouper les paiements par mode
function groupPaymentsByMode(payments) {
	const grouped = {};
	const tipsByServer = {}; // 🆕 Regrouper les pourboires par serveur

	// 🆕 ÉTAPE 1: Regrouper les paiements divisés par splitPaymentId pour calculer le pourboire global
	// Car les excessAmount individuels sont proportionnels et peuvent être incorrects
	const splitPaymentGroups = {};
	const processedSplitPayments = new Set(); // Pour éviter de traiter plusieurs fois le même split

	for (const payment of payments) {
		if (payment.isSplitPayment && payment.splitPaymentId) {
			if (!splitPaymentGroups[payment.splitPaymentId]) {
				splitPaymentGroups[payment.splitPaymentId] = [];
			}
			splitPaymentGroups[payment.splitPaymentId].push(payment);
		}
	}

	// 🆕 Set pour éviter de compter plusieurs fois les transactions de paiements divisés
	// Clé = splitPaymentId + mode + enteredAmount
	const processedSplitTransactions = new Set();

	for (const payment of payments) {
		// 🆕 Ignorer les remboursements (type: 'refund')
		if (payment.type === 'refund') {
			continue;
		}

		// 🆕 Exclure les paiements avec paymentMode === 'CREDIT' de groupPaymentsByMode
		// Ils seront réinjectés après via creditData pour garantir un total cohérent
		if (payment.paymentMode === 'CREDIT') {
			continue; // Ignorer les paiements CREDIT ici
		}

		const mode = payment.paymentMode || 'INCONNU';
		const noteName = payment.noteName || null; // 🆕 Nom du payeur (sous-note ou "Note Principale")

		if (!grouped[mode]) {
			grouped[mode] = {
				total: 0,
				totalEntered: 0, // 🆕 Total des montants réellement entrés (avec pourboire)
				count: 0,
				payers: [] // 🆕 Liste des payeurs (pour éviter les doublons)
			};
		}

		// 🆕 Pour les paiements divisés, dédupliquer par splitPaymentId + mode + enteredAmount
		// Car chaque transaction apparaît N fois (une par commande) avec le même enteredAmount
		const enteredAmount = payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0);

		if (payment.isSplitPayment && payment.splitPaymentId) {
			const transactionKey = `${payment.splitPaymentId}_${mode}_${enteredAmount.toFixed(3)}`;
			if (processedSplitTransactions.has(transactionKey)) {
				// Transaction déjà comptée, passer à la suivante
				continue;
			}
			processedSplitTransactions.add(transactionKey);
		}

		// 🆕 Utiliser enteredAmount si disponible (montant réel), sinon amount (rétrocompatibilité)
		// ⚠️ IMPORTANT: Pour CARTE/TPE/CHEQUE, enteredAmount contient le montant réellement encaissé (avec pourboire)
		grouped[mode].total += enteredAmount;
		grouped[mode].totalEntered += enteredAmount; // 🆕 Total réellement encaissé
		grouped[mode].count += 1;

		// 🆕 Calculer les pourboires à récupérer par serveur
		// ⚠️ IMPORTANT: Pour les paiements divisés, calculer le pourboire global (pas par paiement individuel)
		if ((mode === 'TPE' || mode === 'CHEQUE' || mode === 'CARTE')) {
			const serverName = payment.server || 'unknown';

			// 🆕 Pour les paiements divisés, calculer le pourboire au niveau du groupe
			if (payment.isSplitPayment && payment.splitPaymentId) {
				// Ne traiter qu'une seule fois par splitPaymentId
				if (!processedSplitPayments.has(payment.splitPaymentId)) {
					processedSplitPayments.add(payment.splitPaymentId);

					const groupPayments = splitPaymentGroups[payment.splitPaymentId] || [];
					const hasCash = groupPayments.some(p => p.hasCashInPayment === true);

					if (!hasCash && serverName && serverName !== 'unknown') {
						// 🆕 Recalculer le pourboire global pour ce split payment
						// Total encaissé (pour les modes scripturaux) - Total ticket (allocatedAmount)
						// Regrouper par mode+enteredAmount pour dédupliquer les transactions
						const transactionsByKey = {};
						for (const p of groupPayments) {
							if (p.paymentMode === 'TPE' || p.paymentMode === 'CHEQUE' || p.paymentMode === 'CARTE') {
								const enteredAmount = p.enteredAmount != null ? p.enteredAmount : (p.amount || 0);
								const key = `${p.paymentMode}_${enteredAmount.toFixed(3)}`;
								if (!transactionsByKey[key]) {
									transactionsByKey[key] = {
										enteredAmount: enteredAmount,
										allocatedAmounts: [],
									};
								}
								transactionsByKey[key].allocatedAmounts.push(p.allocatedAmount || p.amount || 0);
							}
						}

						// Calculer le total encaissé et le total ticket
						let totalEntered = 0;
						let totalAllocated = 0;
						for (const [key, transaction] of Object.entries(transactionsByKey)) {
							totalEntered += transaction.enteredAmount;
							// 🆕 CORRECTION : Le total allocatedAmount pour une transaction = somme de tous les allocatedAmounts
							// Chaque commande a déjà son allocatedAmount proportionnel, donc on additionne simplement
							// Ne PAS diviser par nbOrders car cela donnerait un montant incorrect
							const sumAllocated = transaction.allocatedAmounts.reduce((sum, a) => sum + a, 0);
							totalAllocated += sumAllocated;
						}

						const tipAmount = Math.max(0, totalEntered - totalAllocated);
						if (tipAmount > 0.01) {
							if (!tipsByServer[serverName]) {
								tipsByServer[serverName] = 0;
							}
							tipsByServer[serverName] += tipAmount;
							console.log(`[X-REPORT] ✅ Pourboire split: splitId=${payment.splitPaymentId}, serveur=${serverName}, totalEntered=${totalEntered}, totalAllocated=${totalAllocated}, tip=${tipAmount}`);
						}
					}
				}
			} else {
				// Paiement simple (non divisé)
				if (payment.excessAmount != null &&
					payment.excessAmount > 0.001 &&
					payment.hasCashInPayment === false) {
					if (serverName && serverName !== 'unknown') {
						if (!tipsByServer[serverName]) {
							tipsByServer[serverName] = 0;
						}
						tipsByServer[serverName] += payment.excessAmount;
						console.log(`[X-REPORT] ✅ Pourboire simple: serveur=${serverName}, excessAmount=${payment.excessAmount}, total=${tipsByServer[serverName]}`);
					}
				}
			}
		}

		// 🆕 Ajouter le nom du payeur si disponible et pas déjà dans la liste
		if (noteName && noteName !== 'Note Principale' && !grouped[mode].payers.includes(noteName)) {
			grouped[mode].payers.push(noteName);
		}
	}

	// 🆕 Ajouter les pourboires par serveur dans le groupe
	if (Object.keys(tipsByServer).length > 0) {
		grouped['_tipsByServer'] = tipsByServer;
		console.log(`[X-REPORT] Pourboires par serveur:`, tipsByServer);
	} else {
		console.log(`[X-REPORT] Aucun pourboire trouvé.`);
	}

	return grouped;
}

// Calculer les totaux généraux
// 🆕 CORRECTION: payments peut être allPayments (paiements individuels) ou paidPayments (paiements regroupés)
// Si c'est paidPayments, les articles sont déjà dédupliqués pour les paiements divisés
function calculateTotals(payments, orders) {
	let chiffreAffaire = 0;
	let totalRecette = 0; // 🆕 Recette réellement encaissée (sans les dettes différées)
	let totalRemises = 0;
	let nombreRemises = 0;
	let nombreCouverts = 0;
	let nombreArticles = 0;

	// 🆕 Créer un Set pour identifier les articles annulés (pour exclusion du calcul)
	// ⚠️ IMPORTANT : On ne doit exclure que les articles annulés dans la période
	// Les annulations de la veille ne doivent pas affecter le calcul du jour
	const cancelledItemKeys = new Set();
	// Note: Les articles annulés sont identifiés depuis les commandes, mais comme les commandes
	// sont déjà filtrées par période (via allOrdersForTotals), seules les annulations de la période
	// seront prises en compte. Cependant, pour être sûr, on pourrait aussi filtrer par timestamp
	// mais cela nécessiterait de passer period/dateFrom/dateTo à calculateTotals.
	// Pour l'instant, on fait confiance au fait que allOrdersForTotals est déjà filtré.
	for (const order of orders) {
		if (order.orderHistory && Array.isArray(order.orderHistory)) {
			for (const event of order.orderHistory) {
				if (event.action === 'items_cancelled' && event.items) {
					for (const item of event.items) {
						// Créer une clé unique : orderId_itemId pour identifier les articles annulés
						const key = `${order.id}_${item.id}_${item.name}`;
						cancelledItemKeys.add(key);
					}
				}
			}
		}
	}

	// Parcourir tous les paiements
	const discountActs = new Set(); // Pour compter les actes de remise uniques (par ticket, pas par commande)

	// 🆕 Set pour dédupliquer les transactions de paiements divisés (multi-commandes)
	// ⚠️ RÈGLE 2.1 .cursorrules: Une table peut avoir plusieurs commandes, chaque transaction apparaît N fois
	const processedSplitTransactions = new Set();

	for (const payment of payments) {
		// 🆕 Ignorer les remboursements (type: 'refund') pour le chiffre d'affaire
		if (payment.type === 'refund') {
			// Soustraire les remboursements du totalRecette
			totalRecette += payment.amount || 0; // amount est négatif pour les remboursements
			continue;
		}

		// 🆕 Pour les paiements divisés, dédupliquer par splitPaymentId + mode + enteredAmount
		// Car chaque transaction apparaît N fois (une par commande) avec le même enteredAmount
		const enteredAmount = payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0);
		const subtotal = payment.subtotal || payment.amount || 0;
		const amount = payment.amount || 0;

		if (payment.isSplitPayment && payment.splitPaymentId) {
			const transactionKey = `${payment.splitPaymentId}_${payment.paymentMode}_${enteredAmount.toFixed(3)}`;
			if (processedSplitTransactions.has(transactionKey)) {
				// Transaction déjà comptée, passer à la suivante
				continue;
			}
			processedSplitTransactions.add(transactionKey);
		}

		// ✅ Chiffre d'affaire : inclut TOUS les paiements (y compris les dettes différées)
		// 🆕 Pour les paiements divisés dédupliqués, utiliser allocatedAmount (montant nécessaire sans pourboire)
		// Pour les paiements simples, utiliser subtotal (montant avant remise)
		if (payment.isSplitPayment) {
			// Pour les paiements divisés, allocatedAmount = part du ticket pour cette transaction
			const allocatedAmount = payment.allocatedAmount != null ? payment.allocatedAmount : amount;
			chiffreAffaire += allocatedAmount;
		} else {
			chiffreAffaire += subtotal;
		}

		// ✅ Recette réellement encaissée : seulement les paiements réels (ESPECE, CARTE, etc.)
		// Exclure les dettes différées (paymentMode === 'CREDIT') qui sont payées plus tard
		if (payment.paymentMode !== 'CREDIT') {
			// 🆕 CORRECTION: Si du liquide est présent dans le paiement, le pourboire scriptural est purement indicatif
			// et ne doit pas être comptabilisé dans la recette. Utiliser allocatedAmount (sans pourboire) au lieu de enteredAmount.
			// Si pas de liquide, utiliser enteredAmount (avec pourboire) car le pourboire doit être récupéré en liquide.
			let realAmount;
			if (payment.hasCashInPayment === true) {
				// 🆕 Utiliser allocatedAmount (sans pourboire) quand il y a du liquide dans le paiement
				realAmount = payment.allocatedAmount != null ? payment.allocatedAmount : amount;
			} else {
				// 🆕 Utiliser enteredAmount (avec pourboire) quand il n'y a pas de liquide
				// Le pourboire sera récupéré en liquide à la fin du service
				realAmount = enteredAmount;
			}
			totalRecette += realAmount;
		}

		// 🆕 Utiliser discountAmount directement (calculé à la source dans pos-payment.js)
		// Rétrocompatibilité : calculer si discountAmount n'existe pas (anciennes données)
		let discountAmount = payment.discountAmount;
		if (discountAmount == null || discountAmount === undefined) {
			// Calculer pour les anciennes données
			if (subtotal > amount) {
				discountAmount = subtotal - amount;
			} else if (payment.discount && payment.discount > 0) {
				if (payment.isPercentDiscount) {
					discountAmount = subtotal * (payment.discount / 100);
				} else {
					discountAmount = payment.discount;
				}
			} else {
				discountAmount = 0;
			}
		}

		// Utiliser hasDiscount directement ou calculer
		const hasDiscount = payment.hasDiscount != null
			? payment.hasDiscount
			: (discountAmount > 0.01);

		// 🆕 Compter uniquement les remises réelles (pas les différences dues aux arrondis)
		// et regrouper les paiements multiples d'une même remise (même acte de paiement)
		if (hasDiscount && discountAmount > 0.01) {
			totalRemises += discountAmount;

			// 🆕 Créer une clé unique pour l'ACTE DE PAIEMENT (pas le montant de remise)
			// Regrouper par: table + timestamp exact + mode de paiement + taux de remise
			// Cela permet de regrouper les paiements multiples d'une même table au même moment avec la même remise
			// 🆕 Pour paiement divisé, utiliser splitPaymentId directement pour regrouper tous les modes ensemble
			let discountKey;
			if (payment.isSplitPayment && payment.splitPaymentId) {
				// Utiliser directement le splitPaymentId (format: split_TIMESTAMP) pour regrouper tous les modes
				discountKey = `${payment.table || 'N/A'}_${payment.splitPaymentId}_${payment.discount || 0}_${payment.isPercentDiscount ? 'PCT' : 'FIX'}`;
			} else {
				discountKey = `${payment.table || 'N/A'}_${payment.timestamp || ''}_${payment.paymentMode || 'N/A'}_${payment.discount || 0}_${payment.isPercentDiscount ? 'PCT' : 'FIX'}`;
			}
			if (!discountActs.has(discountKey)) {
				discountActs.add(discountKey);
				nombreRemises += 1;
			}
		}
	}

	// 🆕 Détecter si payments est paidPayments (paiements regroupés) ou allPayments (paiements individuels)
	// paidPayments a une propriété 'items' directement, tandis que allPayments vient de order.paymentHistory
	const isPaidPayments = payments.length > 0 && payments[0].items && typeof payments[0].items === 'object' && Array.isArray(payments[0].items);

	if (isPaidPayments) {
		// 🆕 CORRECTION: Compter depuis paidPayments (articles déjà dédupliqués pour paiements divisés)
		for (const payment of payments) {
			if (!payment.items || !Array.isArray(payment.items)) continue;

			for (const item of payment.items) {
				// 🆕 Vérifier si cet article a été annulé (si on a l'orderId)
				// Pour paidPayments, on ne peut pas facilement vérifier les annulations car on n'a pas l'orderId direct
				// Mais comme les commandes sont déjà filtrées par période, les annulations hors période ne sont pas incluses
				nombreArticles += item.quantity || 0;
			}

			// Couverts depuis le paiement
			if (payment.covers) {
				nombreCouverts += payment.covers || 0;
			}
		}
	} else {
		// Cas normal : compter depuis order.paymentHistory (pour compatibilité)
		for (const order of orders) {
			// Couverts
			if (order.mainNote && order.mainNote.covers) {
				nombreCouverts += order.mainNote.covers || 0;
			}
			if (order.subNotes) {
				for (const subNote of order.subNotes) {
					nombreCouverts += subNote.covers || 0;
				}
			}

			// Articles (depuis paymentHistory) - 🆕 EXCLURE les articles annulés
			if (order.paymentHistory) {
				for (const payment of order.paymentHistory) {
					// 🆕 Ignorer les remboursements
					if (payment.type === 'refund') {
						continue;
					}

					if (payment.items) {
						for (const item of payment.items) {
							// 🆕 Vérifier si cet article a été annulé
							const key = `${order.id}_${item.id}_${item.name}`;
							if (!cancelledItemKeys.has(key)) {
								// Article non annulé : compter dans nombreArticles
								nombreArticles += item.quantity || 0;
							}
						}
					}
				}
			}
		}
	}

	return {
		chiffreAffaire,
		totalRecette,
		totalRemises,
		nombreRemises,
		nombreCouverts,
		nombreArticles
	};
}

// 🆕 Collecter toutes les annulations depuis orderHistory (filtrées par période)
function collectCancellations(orders, period, dateFrom, dateTo) {
	const cancellations = [];

	// 🆕 Définir les dates effectives pour le filtrage (date du jour si non fournies)
	let effectiveDateFrom = dateFrom;
	let effectiveDateTo = dateTo;
	if (!effectiveDateFrom || !effectiveDateTo) {
		const today = new Date();
		today.setHours(0, 0, 0, 0);
		effectiveDateFrom = today.toISOString();
		today.setHours(23, 59, 59, 999);
		effectiveDateTo = today.toISOString();
	}

	// 🆕 Fonction pour vérifier si une date est dans la période
	const isInPeriod = (date) => {
		if (!date) return false;
		const eventDate = new Date(date);
		if (Number.isNaN(eventDate.getTime())) return false;

		const fromDate = new Date(effectiveDateFrom);
		const toDate = new Date(effectiveDateTo);
		if (eventDate < fromDate || eventDate > toDate) return false;

		if (period && period !== 'ALL') {
			const hour = eventDate.getHours();
			if (period === 'MIDI' && hour >= 15) return false;
			if (period === 'SOIR' && hour < 15) return false;
		}

		return true;
	};

	for (const order of orders) {
		if (!order.orderHistory || !Array.isArray(order.orderHistory)) {
			continue;
		}

		// 🆕 Trouver le timestamp de création de la commande
		let orderCreatedAt = order.createdAt || null;
		const orderCreatedEvent = order.orderHistory.find(e =>
			e.action === 'order_created' || e.action === 'order_created_from_transfer'
		);
		if (orderCreatedEvent && orderCreatedEvent.timestamp) {
			orderCreatedAt = orderCreatedEvent.timestamp;
		}

		for (const event of order.orderHistory) {
			if (event.action === 'items_cancelled' && event.items && event.items.length > 0) {
				// 🆕 Filtrer par période : ne garder que les annulations dans la période
				const cancellationTimestamp = event.timestamp || new Date().toISOString();
				if (!isInPeriod(cancellationTimestamp)) {
					continue; // Ignorer les annulations en dehors de la période
				}

				const details = event.cancellationDetails || {};

				// Calculer le total des articles annulés
				const itemsTotal = event.items.reduce((sum, item) => {
					return sum + ((item.price || 0) * (item.quantity || 0));
				}, 0);

				cancellations.push({
					timestamp: cancellationTimestamp, // 🆕 Temps de l'annulation
					orderCreatedAt: orderCreatedAt, // 🆕 Temps de création de la commande
					table: event.table || order.table || 'N/A',
					server: event.handledBy || order.server || 'unknown',
					orderId: event.orderId || order.id,
					noteId: event.noteId || 'main',
					noteName: event.noteName || 'Note Principale',
					items: event.items.map(item => ({
						id: Number(item.id) || item.id, // 🆕 S'assurer que id est un nombre si possible
						name: item.name,
						price: Number(item.price) || 0,
						quantity: Number(item.quantity) || 0,
						total: (Number(item.price) || 0) * (Number(item.quantity) || 0)
					})),
					itemsTotal: itemsTotal,
					state: details.state || 'not_prepared',
					reason: details.reason || 'other',
					description: details.description || '',
					action: details.action || 'cancel',
					refundAmount: details.refundAmount || 0,
					wasteCost: details.wasteCost || 0,
					reassignment: details.reassignment || null
				});
			}
		}
	}

	// Trier par timestamp décroissant (plus récent en premier)
	cancellations.sort((a, b) => {
		const timeA = new Date(a.timestamp).getTime();
		const timeB = new Date(b.timestamp).getTime();
		return timeB - timeA;
	});

	// Calculer les totaux
	const summary = {
		nombreAnnulations: cancellations.length,
		montantTotalRembourse: cancellations.reduce((sum, c) => sum + (c.refundAmount || 0), 0),
		coutTotalPertes: cancellations.reduce((sum, c) => sum + (c.wasteCost || 0), 0),
		nombreReaffectations: cancellations.filter(c => c.reassignment !== null).length,
		nombreRemakes: cancellations.filter(c => c.action === 'remake').length // 🆕 Nombre de remakes
	};

	return {
		details: cancellations,
		summary: summary
	};
}

// Calculer les tables non payées avec détails complets
function calculateUnpaidTables(server) {
	// 🆕 Utiliser la même logique que le POS : vérifier mainNote.paid et subNote.paid
	// Le POS n'affiche que les tables avec des notes non payées, pas celles avec order.total > 0
	// 🆕 CORRECTION : Filtrer aussi les commandes archivées (comme getAllOrders)
	const unpaidOrders = dataStore.orders.filter(order => {
		// 🆕 Exclure les commandes archivées (comme getAllOrders)
		if (order.status === 'archived') {
			return false;
		}

		// Filtrer par serveur si fourni
		if (server && order.server) {
			if (String(order.server).toUpperCase() !== String(server).toUpperCase()) {
				return false;
			}
		}

		// 🆕 Vérifier s'il y a des notes non payées (comme le fait le POS)
		// Le POS vérifie mainNote.paid et subNote.paid, pas order.total
		if (order.mainNote) {
			const mainPaid = order.mainNote.paid || false;
			const mainTotal = order.mainNote.total || 0;

			// Si la note principale n'est pas payée et a un total > 0, inclure la commande
			if (!mainPaid && mainTotal > 0) {
				return true;
			}

			// Vérifier les sous-notes non payées
			const subNotes = order.subNotes || [];
			for (const subNote of subNotes) {
				const isPaid = subNote.paid || false;
				const subTotal = subNote.total || 0;
				if (!isPaid && subTotal > 0) {
					return true;
				}
			}
		} else {
			// Ancienne structure sans mainNote : utiliser order.total
			if (order.total && order.total > 0) {
				return true;
			}
		}

		return false;
	});

	// 🆕 Regrouper par mode de paiement prévu (si disponible) ou "NON PAYÉ"
	// Calculer le total réel à partir des notes non payées (comme le fait le POS)
	const unpaidByMode = {};
	let totalUnpaid = 0;

	for (const order of unpaidOrders) {
		// 🆕 Calculer le total réel des notes non payées (comme le fait le POS)
		let orderUnpaidTotal = 0;

		if (order.mainNote) {
			const mainPaid = order.mainNote.paid || false;
			const mainTotal = order.mainNote.total || 0;
			if (!mainPaid && mainTotal > 0) {
				orderUnpaidTotal += mainTotal;
			}

			const subNotes = order.subNotes || [];
			for (const subNote of subNotes) {
				const isPaid = subNote.paid || false;
				const subTotal = subNote.total || 0;
				if (!isPaid && subTotal > 0) {
					orderUnpaidTotal += subTotal;
				}
			}
		} else {
			// Ancienne structure sans mainNote
			orderUnpaidTotal = order.total || 0;
		}

		if (orderUnpaidTotal > 0) {
			totalUnpaid += orderUnpaidTotal;

			const mode = 'NON PAYÉ';
			if (!unpaidByMode[mode]) {
				unpaidByMode[mode] = {
					total: 0,
					count: 0
				};
			}
			unpaidByMode[mode].total += orderUnpaidTotal;
			unpaidByMode[mode].count += 1;
		}
	}

	// 🆕 Regrouper les commandes par table et créer un seul ticket provisoire par table
	const tablesMap = {};

	for (const order of unpaidOrders) {
		const tableNumber = String(order.table || '?');

		if (!tablesMap[tableNumber]) {
			tablesMap[tableNumber] = {
				table: tableNumber,
				server: order.server || 'unknown',
				orders: [],
				allItems: [],
				total: 0,
				covers: order.covers || 1,
				openedAt: order.createdAt,
				lastOrderAt: order.updatedAt || order.createdAt,
			};
		}

		const tableData = tablesMap[tableNumber];
		tableData.orders.push(order);

		// 🆕 Calculer le total réel des notes non payées (comme le fait le POS)
		let orderUnpaidTotal = 0;
		if (order.mainNote) {
			const mainPaid = order.mainNote.paid || false;
			const mainTotal = order.mainNote.total || 0;
			if (!mainPaid && mainTotal > 0) {
				orderUnpaidTotal += mainTotal;
			}

			const subNotes = order.subNotes || [];
			for (const subNote of subNotes) {
				const isPaid = subNote.paid || false;
				const subTotal = subNote.total || 0;
				if (!isPaid && subTotal > 0) {
					orderUnpaidTotal += subTotal;
				}
			}
		} else {
			// Ancienne structure sans mainNote
			orderUnpaidTotal = order.total || 0;
		}

		tableData.total += orderUnpaidTotal;

		// Mettre à jour la date d'ouverture (la plus ancienne)
		if (order.createdAt && (!tableData.openedAt || new Date(order.createdAt) < new Date(tableData.openedAt))) {
			tableData.openedAt = order.createdAt;
		}

		// Mettre à jour la dernière commande (la plus récente)
		if (order.updatedAt && (!tableData.lastOrderAt || new Date(order.updatedAt) > new Date(tableData.lastOrderAt))) {
			tableData.lastOrderAt = order.updatedAt;
		}

		// 🆕 Collecter tous les articles non payés de cette commande
		// Ne collecter que si la note principale n'est pas payée (comme le fait le POS)
		if (order.mainNote && order.mainNote.items) {
			const mainPaid = order.mainNote.paid || false;
			const mainTotal = order.mainNote.total || 0;

			// 🆕 Inclure la note principale seulement si elle n'est pas payée (comme le fait le POS)
			if (!mainPaid && mainTotal > 0) {
				for (const item of order.mainNote.items) {
					const paidQty = item.paidQuantity || 0;
					const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
					if (unpaidQty > 0) {
						// Chercher si l'article existe déjà (même ID et nom)
						const existingIndex = tableData.allItems.findIndex(i => i.id === item.id && i.name === item.name);
						if (existingIndex !== -1) {
							// Agréger les quantités
							tableData.allItems[existingIndex].quantity += unpaidQty;
							tableData.allItems[existingIndex].subtotal = tableData.allItems[existingIndex].price * tableData.allItems[existingIndex].quantity;
						} else {
							// Nouvel article
							tableData.allItems.push({
								id: Number(item.id) || item.id, // 🆕 S'assurer que id est un nombre si possible
								name: item.name,
								price: Number(item.price) || 0,
								quantity: Number(unpaidQty) || 0,
								subtotal: (Number(item.price) || 0) * (Number(unpaidQty) || 0)
							});
						}
					}
				}
			}
		}

		// 🆕 Collecter les articles des sous-notes non payées (comme le fait le POS)
		if (order.subNotes) {
			for (const subNote of order.subNotes) {
				const isPaid = subNote.paid || false;
				const subTotal = subNote.total || 0;

				// 🆕 Inclure la sous-note seulement si elle n'est pas payée (comme le fait le POS)
				if (!isPaid && subTotal > 0 && subNote.items) {
					for (const item of subNote.items) {
						const paidQty = item.paidQuantity || 0;
						const unpaidQty = Math.max(0, (item.quantity || 0) - paidQty);
						if (unpaidQty > 0) {
							// Chercher si l'article existe déjà (même ID et nom)
							const existingIndex = tableData.allItems.findIndex(i => i.id === item.id && i.name === item.name);
							if (existingIndex !== -1) {
								// Agréger les quantités
								tableData.allItems[existingIndex].quantity += unpaidQty;
								tableData.allItems[existingIndex].subtotal = tableData.allItems[existingIndex].price * tableData.allItems[existingIndex].quantity;
							} else {
								// Nouvel article
								tableData.allItems.push({
									id: Number(item.id) || item.id, // 🆕 S'assurer que id est un nombre si possible
									name: item.name,
									price: Number(item.price) || 0,
									quantity: Number(unpaidQty) || 0,
									subtotal: (Number(item.price) || 0) * (Number(unpaidQty) || 0)
								});
							}
						}
					}
				}
			}
		}
	}

	// Créer les détails avec un seul ticket provisoire par table
	const unpaidTablesDetails = Object.values(tablesMap).map(tableData => {
		// Construire le ticket provisoire consolidé
		const provisionalTicket = {
			table: tableData.table,
			date: tableData.lastOrderAt || new Date().toISOString(),
			items: tableData.allItems,
			subtotal: tableData.total,
			discount: 0,
			discountAmount: 0,
			total: tableData.total,
			covers: tableData.covers,
			server: tableData.server
		};

		return {
			table: tableData.table,
			server: tableData.server,
			orderIds: tableData.orders.map(o => o.id),
			total: tableData.total,
			covers: tableData.covers,
			openedAt: tableData.openedAt,
			lastOrderAt: tableData.lastOrderAt,
			items: tableData.allItems,
			provisionalTicket: provisionalTicket
		};
	});

	return {
		total: totalUnpaid,
		count: unpaidTablesDetails.length, // 🆕 Nombre de tables uniques (pas le nombre de commandes)
		byMode: unpaidByMode,
		details: unpaidTablesDetails // 🆕 Détails complets avec tickets provisoires
	};
}

// Générer le rapport X
// GÃ©nÃ©rer le rapport X
async function generateReportX(req, res) {
	try {
		const { server, period, dateFrom, dateTo, restaurantId } = req.query;
		const { report } = await buildReportData({ server, period, dateFrom, dateTo, restaurantId });
		return res.json(report);
	} catch (e) {
		console.error('[report-x] Erreur gÃ©nÃ©ration rapport X:', e);
		return res.status(500).json({ error: 'Erreur lors de la gÃ©nÃ©ration du rapport X', details: e.message });
	}
}

async function generateReportXTicket(req, res) {
	try {
		const { server, period, dateFrom, dateTo, restaurantId } = req.query;
		const { report, creditDetails } = await buildReportData({ server, period, dateFrom, dateTo, restaurantId });

		const {
			summary,
			itemsByCategory,
			paymentsByMode,
			unpaidTables,
			discountDetails,
			cancellations,
			creditSummary
		} = report;

		const totals = summary;
		const chiffreAffaire = summary.chiffreAffaire;
		const creditTotalBalance = creditSummary?.totalBalance ?? creditSummary?.totalAmount ?? 0;
		const creditTotalDebit = creditSummary?.totalDebit || 0;
		const creditTotalCredit = creditSummary?.totalCredit || 0;
		const creditClients = creditSummary?.clients || [];
		const creditTransactionsPreview = creditSummary?.recentTransactions || [];

		const now = new Date();
		const dateStr = now.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
		const timeStr = now.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });

		// Générer le ticket texte
		let ticket = '';
		const lineWidth = 48; // Largeur standard ticket de caisse

		// Fonction pour centrer le texte
		const center = (text) => {
			const padding = Math.max(0, Math.floor((lineWidth - text.length) / 2));
			return ' '.repeat(padding) + text;
		};

		// Fonction pour aligner à droite
		const right = (text, width = lineWidth) => {
			return text.padStart(width);
		};

		// Fonction pour ligne de séparation
		const separator = (char = '-') => char.repeat(lineWidth);

		// En-tête
		ticket += center('LES EMIRS') + '\n';
		ticket += center('RESTAURANT') + '\n';
		ticket += center('TEL: 73 348 700') + '\n';
		ticket += center('RAPPORT FINANCIER (X)') + '\n';
		ticket += '\n';

		// Date et heure
		ticket += dateStr.padEnd(lineWidth - timeStr.length) + timeStr + '\n';
		ticket += '\n';

		// Caisse
		// 🆕 Afficher le nom du serveur si spécifié, sinon "Toutes les caisses"
		const caisseLabel = server ? `Caisse : ${server.toUpperCase()}` : 'Caisse : Toutes les caisses';
		ticket += caisseLabel + '\n';
		ticket += separator('=') + '\n';
		ticket += '\n';

		// Largeurs fixes pour tout le ticket (cohérentes)
		const labelWidth = 28; // Largeur fixe pour tous les labels
		const valueWidth = 20; // Largeur fixe pour toutes les valeurs (alignées à droite)

		// Chiffre d'affaire et recette
		const ca = (chiffreAffaire || 0);
		const recette = (totals && totals.totalRecette) || 0;
		ticket += 'CHIFFRE D\'AFFAIRE'.padEnd(labelWidth) + ca.toFixed(3).replace('.', ',').padStart(valueWidth) + '\n';
		ticket += 'TOTAL RECETTE'.padEnd(labelWidth) + recette.toFixed(3).replace('.', ',').padStart(valueWidth) + '\n';
		ticket += '\n';

		// Modes de paiement
		ticket += separator('-') + '\n';

		if (paymentsByMode && typeof paymentsByMode === 'object') {
			for (const [mode, data] of Object.entries(paymentsByMode)) {
				if (!data || typeof data !== 'object') continue;
				// 🆕 Ignorer les clés spéciales pour les pourboires (seront affichées séparément)
				if (mode === '_tipsToRecover' || mode === '_tipsByServer') continue;

				const modeLabel = mode === 'ESPECE' ? 'ESPECE' :
					mode === 'CHEQUE' ? `CHEQUE(${data.count || 0})` :
						mode === 'TPE' ? `TPE(${data.count || 0})` :
							mode === 'CARTE' ? `CARTE(${data.count || 0})` : // 🆕 Ajout de CARTE
								mode === 'OFFRE' ? 'OFFRE' :
									mode.toUpperCase();

				// 🆕 Utiliser totalEntered si disponible (montant réellement encaissé), sinon total
				const amountToDisplay = data.totalEntered != null ? data.totalEntered : (data.total || 0);
				const valueStr = amountToDisplay.toFixed(3).replace('.', ',');
				ticket += modeLabel.padEnd(labelWidth) + valueStr.padStart(valueWidth) + '\n';
			}
		}
		ticket += separator('-') + '\n';
		// 🆕 Les pourboires seront affichés en bas du récapitulatif pour plus de clarté
		ticket += '\n';

		// Remises et autres informations
		if (totals && totals.totalRemises > 0) {
			const valueStr = totals.totalRemises.toFixed(3).replace('.', ',');
			ticket += 'REMISE'.padEnd(labelWidth) + valueStr.padStart(valueWidth) + '\n';
		}
		// TOUR - non utilisé pour l'instant
		// ticket += 'TOUR'.padEnd(labelWidth) + '0,000'.padStart(valueWidth) + '\n';

		// 🆕 "Reglement Clients" = paiements reçus pour régler les crédits (pas le solde)
		if (creditTotalCredit > 0) {
			const valueStr = creditTotalCredit.toFixed(3).replace('.', ',');
			ticket += 'Reglement Clients'.padEnd(labelWidth) + valueStr.padStart(valueWidth) + '\n';
		}
		ticket += 'Avoir Emis'.padEnd(labelWidth) + '0,000'.padStart(valueWidth) + '\n';
		ticket += separator('-') + '\n';
		ticket += '\n';

		// Statistiques
		if (totals) {
			ticket += 'NOMBRE DE COUVERTS'.padEnd(labelWidth) + (totals.nombreCouverts || 0).toString().padStart(valueWidth) + '\n';
			ticket += 'NOMBRE D\'ARTICLES'.padEnd(labelWidth) + (totals.nombreArticles || 0).toString().padStart(valueWidth) + '\n';
		}
		ticket += '\n';

		// Articles par catégorie (format simplifié)
		if (itemsByCategory && typeof itemsByCategory === 'object' && Object.keys(itemsByCategory).length > 0) {
			ticket += separator('=') + '\n';
			ticket += center('LECTURE DES VENTES PAR ARTICLE') + '\n';
			ticket += separator('=') + '\n';
			ticket += '\n';

			for (const [categoryName, categoryData] of Object.entries(itemsByCategory)) {
				// categoryData est un objet avec { items: [], totalQuantity: 0, totalValue: 0 }
				const items = categoryData.items || [];

				ticket += categoryName.toUpperCase() + '\n';
				let categoryQty = 0;
				let categoryValue = 0;

				// Largeurs fixes pour l'alignement (cohérentes avec le reste du ticket)
				const itemNameWidth = 26; // Largeur max pour le nom d'article
				const qtyWidth = 10; // Largeur pour la quantité (alignée à droite)
				const itemValueWidth = 12; // Largeur pour la valeur (alignée à droite)

				for (const item of items) {
					const qty = item.quantity || 0;
					const price = item.price || 0;
					const value = qty * price;
					categoryQty += qty;
					categoryValue += value;

					let itemName = (item.name || 'N/A').toUpperCase();
					// Tronquer le nom si trop long
					if (itemName.length > itemNameWidth) {
						itemName = itemName.substring(0, itemNameWidth - 3) + '...';
					}

					const qtyStr = qty.toFixed(3).replace('.', ',');
					const valueStr = value.toFixed(3).replace('.', ',');

					// Alignement strict : nom (26), quantité (10), valeur (12)
					// Total = 26 + 10 + 12 = 48 caractères (largeur du ticket)
					ticket += '  ' + itemName.padEnd(itemNameWidth) + qtyStr.padStart(qtyWidth) + '  ' + valueStr.padStart(itemValueWidth) + '\n';
				}

				// Aligner le "Total Famille" avec les mêmes colonnes
				const totalQtyStr = categoryQty.toFixed(3).replace('.', ',');
				const totalValueStr = categoryValue.toFixed(3).replace('.', ',');
				// "Total Famille:" fait 14 caractères, on le pad à itemNameWidth
				ticket += '  Total Famille:'.padEnd(itemNameWidth + 2) + totalQtyStr.padStart(qtyWidth) + '  ' + totalValueStr.padStart(itemValueWidth) + '\n';
				ticket += '\n';
			}
		}

		// Remises détaillées (si présentes) - organisées par serveur
		if (discountDetails && discountDetails.length > 0) {
			ticket += separator('=') + '\n';
			ticket += center('DETAILS DES REMISES') + '\n';
			ticket += separator('=') + '\n';
			ticket += '\n';

			// Grouper par serveur
			const discountsByServer = {};
			for (const discount of discountDetails) {
				const serverName = discount.server || 'INCONNU';
				if (!discountsByServer[serverName]) {
					discountsByServer[serverName] = [];
				}
				discountsByServer[serverName].push(discount);
			}

			// Trier les serveurs par ordre alphabétique
			const sortedServers = Object.keys(discountsByServer).sort();

			for (const serverName of sortedServers) {
				const serverDiscounts = discountsByServer[serverName];

				// Trier du plus récent au plus vieux (déjà trié, mais on s'assure)
				serverDiscounts.sort((a, b) => {
					const timeA = new Date(a.timestamp).getTime();
					const timeB = new Date(b.timestamp).getTime();
					return timeB - timeA; // Plus récent en premier
				});

				// Calculer le nombre et le total des remises pour ce serveur
				const nombreRemises = serverDiscounts.length;
				const totalRemisesServeur = serverDiscounts.reduce((sum, d) => sum + (d.discountAmount || 0), 0);

				ticket += `SERVEUR: ${serverName.toUpperCase()}\n`;
				ticket += `Nombre: ${nombreRemises} | Total: ${totalRemisesServeur.toFixed(3).replace('.', ',')} TND\n`;
				ticket += separator('-') + '\n';

				for (const discount of serverDiscounts) {
					const date = new Date(discount.timestamp);
					const dateStr = date.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
					const timeStr = date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });

					ticket += `Table ${discount.table || 'N/A'} - ${dateStr} ${timeStr}\n`;
					if (discount.noteName && discount.noteName !== 'Note Principale') {
						ticket += `Note: ${discount.noteName}\n`;
					}
					// 🆕 Afficher le nom du client si présent
					if (discount.discountClientName) {
						ticket += `Client: ${discount.discountClientName}\n`;
					}
					ticket += `Avant remise: ${discount.subtotal.toFixed(3).replace('.', ',')} TND\n`;
					const discountRate = discount.isPercentDiscount
						? `${discount.discount}%`
						: `${discount.discount} TND`;
					ticket += `Remise: ${discountRate}\n`;
					ticket += `Montant: ${discount.amount.toFixed(3).replace('.', ',')} TND\n`;
					ticket += `Mode: ${discount.paymentMode || 'N/A'}\n`;
					ticket += separator('-') + '\n';
				}
				ticket += '\n';
			}
		}

		// Annulations détaillées (si présentes)
		if (cancellations && cancellations.details && cancellations.details.length > 0) {
			ticket += separator('=') + '\n';
			ticket += center('ANNULATIONS ET RETOURS') + '\n';
			ticket += separator('=') + '\n';
			const cancellationSummary = cancellations?.summary || {};
			ticket += 'Nombre total: ' + (cancellationSummary.nombreAnnulations || 0) + '\n';
			if ((cancellationSummary.montantTotalRembourse || 0) > 0) {
				ticket += 'Total rembourse: ' + cancellationSummary.montantTotalRembourse.toFixed(3).replace('.', ',') + ' TND\n';
			}
			if ((cancellationSummary.coutTotalPertes || 0) > 0) {
				ticket += 'Total pertes: ' + cancellationSummary.coutTotalPertes.toFixed(3).replace('.', ',') + ' TND\n';
			}
			ticket += '\n';

			// 🆕 Détails de toutes les annulations (pas seulement les remboursements)
			for (const cancellation of cancellations.details) {
				const cancelDate = new Date(cancellation.timestamp);
				const cancelDateStr = cancelDate.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
				const cancelTimeStr = cancelDate.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });

				// 🆕 Heure de création de la commande
				let orderCreatedStr = '';
				if (cancellation.orderCreatedAt) {
					try {
						const orderCreatedDate = new Date(cancellation.orderCreatedAt);
						const orderDateStr = orderCreatedDate.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
						const orderTimeStr = orderCreatedDate.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
						orderCreatedStr = `Commande: ${orderDateStr} ${orderTimeStr}`;
					} catch (e) {
						orderCreatedStr = `Commande: ${cancellation.orderCreatedAt}`;
					}
				}

				ticket += `Table ${cancellation.table || 'N/A'} - ${cancelDateStr} ${cancelTimeStr}\n`;
				if (orderCreatedStr) {
					ticket += `${orderCreatedStr}\n`;
				}
				if (cancellation.noteName && cancellation.noteName !== 'Note Principale') {
					ticket += `Note: ${cancellation.noteName}\n`;
				}
				ticket += `Serveur: ${cancellation.server || 'unknown'}\n`;

				// Articles annulés
				if (cancellation.items && cancellation.items.length > 0) {
					for (const item of cancellation.items) {
						const itemName = (item.name || 'N/A').toUpperCase();
						const qty = item.quantity || 0;
						const price = (item.price || 0).toFixed(3).replace('.', ',');
						if (itemName.length > 25) {
							ticket += `  ${itemName.substring(0, 22)}... x${qty} - ${price} TND\n`;
						} else {
							ticket += `  ${itemName} x${qty} - ${price} TND\n`;
						}
					}
				}

				// État, raison, action
				const stateLabels = {
					'not_prepared': 'Non préparé',
					'prepared_not_served': 'Préparé non servi',
					'served_untouched': 'Servi non entamé',
					'served_touched': 'Servi entamé',
				};
				const reasonLabels = {
					'non_conformity': 'Non-conformité',
					'quality': 'Qualité/Goût',
					'delay': 'Délai',
					'order_error': 'Erreur commande',
					'client_dissatisfied': 'Client insatisfait',
					'other': 'Autre',
				};
				const actionLabels = {
					'cancel': 'Annulation',
					'refund': 'Remboursement',
					'replace': 'Remplacement',
					'remake': 'Refaire',
					'reassign': 'Réaffectation',
				};

				const state = stateLabels[cancellation.state] || cancellation.state || 'N/A';
				const reason = reasonLabels[cancellation.reason] || cancellation.reason || 'N/A';
				const action = actionLabels[cancellation.action] || cancellation.action || 'N/A';

				ticket += `Etat: ${state} | Raison: ${reason} | Action: ${action}\n`;

				if (cancellation.description) {
					const desc = cancellation.description.length > 40 ? `${cancellation.description.substring(0, 37)}...` : cancellation.description;
					ticket += `Description: ${desc}\n`;
				}

				if ((cancellation.refundAmount || 0) > 0) {
					ticket += `Remboursement: ${cancellation.refundAmount.toFixed(3).replace('.', ',')} TND\n`;
				}
				if ((cancellation.wasteCost || 0) > 0) {
					ticket += `Cout perte: ${cancellation.wasteCost.toFixed(3).replace('.', ',')} TND\n`;
				}
				if (cancellation.reassignment) {
					ticket += `Reaffecte vers: Table ${cancellation.reassignment.table || 'N/A'}\n`;
				}

				ticket += separator('-') + '\n';
			}
			ticket += '\n';
		}

		// 🆕 Etat des crédits clients (aligné sur l'admin)
		const hasCreditData = (creditSummary?.transactionsCount || 0) > 0 || Math.abs(creditTotalBalance) > 0.0001;
		if (hasCreditData) {
			ticket += separator('=') + '\n';
			ticket += center('ETAT DES CREDITS CLIENT') + '\n';
			ticket += separator('=') + '\n';
			ticket += `Dettes émises : ${creditTotalDebit.toFixed(3).replace('.', ',')} TND\n`;
			ticket += `Paiements reçus: ${creditTotalCredit.toFixed(3).replace('.', ',')} TND\n`;
			ticket += `Solde en cours : ${creditTotalBalance.toFixed(3).replace('.', ',')} TND\n`;
			ticket += `Transactions période: ${creditSummary?.transactionsCount || 0}\n`;
			ticket += '\n';

			if (creditClients.length > 0) {
				ticket += 'TOP CLIENTS:\n';
				const topClients = creditClients.slice(0, 5);
				for (const client of topClients) {
					const line = `${client.clientName || 'N/A'}`.toUpperCase();
					const debitStr = (client.debitTotal || 0).toFixed(3).replace('.', ',');
					const creditStr = (client.creditTotal || 0).toFixed(3).replace('.', ',');
					const balanceStr = (client.balance || 0).toFixed(3).replace('.', ',');
					ticket += `${line}\nDette: ${debitStr} TND | Paiement: ${creditStr} TND\n`;
					ticket += `Solde: ${balanceStr} TND (${client.transactionsCount || 0} tr.)\n`;
					if (client.lastTransaction) {
						const date = new Date(client.lastTransaction);
						const dateStr = date.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
						ticket += `Dernier: ${dateStr}\n`;
					}
					ticket += separator('-') + '\n';
				}
				if (creditClients.length > topClients.length) {
					ticket += `... ${creditClients.length - topClients.length} client(s) supplémentaire(s)\n`;
				}
				ticket += '\n';
			}

			if (creditTransactionsPreview.length > 0) {
				ticket += 'DERNIERS MOUVEMENTS:\n';
				const latestTransactions = creditTransactionsPreview.slice(0, 10);
				for (const tx of latestTransactions) {
					const date = new Date(tx.date);
					const dateStr = date.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
					const timeStr = date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
					const amountStr = (tx.amount || 0).toFixed(3).replace('.', ',');
					const typeLabel = tx.type === 'DEBIT' ? 'DETTE' : 'PAIEMENT';
					const sign = tx.type === 'DEBIT' ? '+' : '-';
					ticket += `${dateStr} ${timeStr} - ${(tx.clientName || 'N/A').toUpperCase()}\n`;
					ticket += `${typeLabel}: ${sign}${amountStr} TND (${tx.paymentMode || '-'})\n`;
					if (tx.description) {
						const desc = tx.description.length > 40 ? `${tx.description.substring(0, 37)}...` : tx.description;
						ticket += `${desc}\n`;
					}
					ticket += separator('-') + '\n';
				}
				if ((creditSummary?.transactionsCount || 0) > latestTransactions.length) {
					ticket += `... ${creditSummary.transactionsCount - latestTransactions.length} mouvement(s) supplémentaire(s)\n`;
				}
				ticket += '\n';
			}
		}

		// 🆕 REGLEMENTS DE DETTES (paiements reçus pour régler les crédits)
		// Filtrer uniquement les transactions CREDIT (paiements reçus, pas les dettes créées)
		// Utiliser creditDetails (tous) au lieu de creditTransactionsPreview (limité à 20)
		const creditPaymentsReceived = (creditDetails || []).filter(tx => tx.type === 'CREDIT');
		if (creditPaymentsReceived.length > 0) {
			ticket += separator('=') + '\n';
			ticket += center('REGLEMENTS DE DETTES') + '\n';
			ticket += separator('=') + '\n';
			ticket += '\n';

			// Total des règlements (doit correspondre à creditTotalCredit)
			const totalReglements = creditPaymentsReceived.reduce((sum, tx) => sum + (tx.amount || 0), 0);
			ticket += `Total règlements: ${totalReglements.toFixed(3).replace('.', ',')} TND\n`;
			ticket += `Nombre de règlements: ${creditPaymentsReceived.length}\n`;
			ticket += '\n';
			ticket += separator('-') + '\n';
			ticket += '\n';

			// Détails des règlements (tous les paiements reçus)
			for (const tx of creditPaymentsReceived) {
				const date = new Date(tx.date);
				const dateStr = date.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
				const timeStr = date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
				const amountStr = (tx.amount || 0).toFixed(3).replace('.', ',');
				const clientName = (tx.clientName || 'N/A').toUpperCase();
				const paymentMode = tx.paymentMode || 'ESPECE';

				ticket += `${dateStr} ${timeStr}\n`;
				ticket += `Client: ${clientName}\n`;
				ticket += `Montant: ${amountStr} TND\n`;
				ticket += `Mode: ${paymentMode}\n`;
				if (tx.description) {
					const desc = tx.description.length > 44 ? `${tx.description.substring(0, 41)}...` : tx.description;
					ticket += `${desc}\n`;
				}
				ticket += separator('-') + '\n';
			}
			ticket += '\n';
		}

		// 🆕 RECAPITULATIF FINAL (ajout des règlements de dettes anciennes à la recette)
		// Dans un Rapport X, on distingue :
		// - CA du jour : toutes les ventes (y compris les dettes créées comme mode de paiement)
		// - Recette encaissée du jour : paiements réels (ESPECE, CARTE, etc.) sans les dettes différées
		// - Règlements de dettes : paiements reçus pour régler des dettes créées précédemment
		ticket += separator('=') + '\n';
		ticket += center('RECAPITULATIF') + '\n';
		ticket += separator('=') + '\n';
		ticket += '\n';

		// CA du jour = chiffre d'affaire de toutes les ventes (y compris les dettes différées)
		const caDuJour = ca;

		// 🆕 Calculer le total des pourboires (pour les soustraire de la recette)
		let totalPourboires = 0;
		if (paymentsByMode && paymentsByMode['_tipsByServer'] && typeof paymentsByMode['_tipsByServer'] === 'object') {
			const tipsByServer = paymentsByMode['_tipsByServer'];
			for (const [serverName, tipAmount] of Object.entries(tipsByServer)) {
				if (tipAmount > 0.01) {
					totalPourboires += tipAmount;
				}
			}
		}

		// Recette encaissée du jour = paiements réels reçus aujourd'hui (sans les dettes différées, SANS les pourboires)
		// 🆕 BONNE PRATIQUE: Afficher la recette opérationnelle (sans pourboire) pour plus de clarté
		const recetteDuJourSansPourboire = recette - totalPourboires;
		// Règlements de dettes = paiements reçus pour régler des dettes créées précédemment
		const reglementsDettes = creditTotalCredit || 0;
		// TOTAL RECETTE ENCAISSÉE = Recette du jour (sans pourboire) + Pourboires + Règlements de dettes anciennes
		const totalRecetteEncaissée = recetteDuJourSansPourboire + totalPourboires + reglementsDettes;

		ticket += 'Chiffre d\'affaire du jour'.padEnd(labelWidth) + caDuJour.toFixed(3).replace('.', ',').padStart(valueWidth) + '\n';
		ticket += 'Recette encaissee du jour'.padEnd(labelWidth) + recetteDuJourSansPourboire.toFixed(3).replace('.', ',').padStart(valueWidth) + '\n';

		// 🆕 Afficher les pourboires par serveur en bas du récapitulatif (bonne pratique)
		if (totalPourboires > 0.01 && paymentsByMode && paymentsByMode['_tipsByServer'] && typeof paymentsByMode['_tipsByServer'] === 'object') {
			const tipsByServer = paymentsByMode['_tipsByServer'];
			for (const [serverName, tipAmount] of Object.entries(tipsByServer)) {
				if (tipAmount > 0.01) {
					const tipValueStr = tipAmount.toFixed(3).replace('.', ',');
					const tipLabel = `POURBOIRE ${serverName.toUpperCase()}`;
					ticket += tipLabel.padEnd(labelWidth) + tipValueStr.padStart(valueWidth) + '\n';
				}
			}
		}

		if (reglementsDettes > 0) {
			ticket += 'Reglements de dettes'.padEnd(labelWidth) + reglementsDettes.toFixed(3).replace('.', ',').padStart(valueWidth) + '\n';
		}
		ticket += separator('-') + '\n';
		ticket += 'TOTAL RECETTE ENCAISSEE'.padEnd(labelWidth) + totalRecetteEncaissée.toFixed(3).replace('.', ',').padStart(valueWidth) + '\n';
		ticket += '\n';

		// 🆕 TABLES NON PAYÉES (Recette non encaissée)
		if (unpaidTables && unpaidTables.total > 0) {
			ticket += separator('=') + '\n';
			ticket += center('RECETTE NON ENCAISSEE') + '\n';
			ticket += separator('=') + '\n';
			ticket += '\n';

			const unpaidTotal = unpaidTables.total || 0;
			const unpaidCount = unpaidTables.count || 0;
			ticket += `Total non encaisse: ${unpaidTotal.toFixed(3).replace('.', ',')} TND\n`;
			ticket += `Nombre de tables: ${unpaidCount}\n`;
			ticket += '\n';

			// Détails par table
			if (unpaidTables.details && unpaidTables.details.length > 0) {
				ticket += 'DETAIL PAR TABLE:\n';
				ticket += separator('-') + '\n';

				for (const table of unpaidTables.details) {
					const tableNumber = table.table || 'N/A';
					const server = table.server || 'unknown';
					const total = (table.total || 0).toFixed(3).replace('.', ',');
					const covers = table.covers || 1;

					ticket += `Table ${tableNumber} - Serveur: ${server.toUpperCase()}\n`;
					ticket += `Couverts: ${covers} | Total: ${total} TND\n`;

					// Articles
					if (table.items && table.items.length > 0) {
						const itemsToShow = table.items.slice(0, 5); // Limiter à 5 articles pour ne pas surcharger
						for (const item of itemsToShow) {
							const itemName = (item.name || 'N/A').toUpperCase();
							const qty = item.quantity || 0;
							const price = (item.price || 0).toFixed(3).replace('.', ',');
							const subtotal = ((item.price || 0) * (item.quantity || 0)).toFixed(3).replace('.', ',');

							if (itemName.length > 25) {
								ticket += `  ${itemName.substring(0, 22)}... x${qty} - ${price} TND = ${subtotal} TND\n`;
							} else {
								ticket += `  ${itemName} x${qty} - ${price} TND = ${subtotal} TND\n`;
							}
						}
						if (table.items.length > 5) {
							ticket += `  ... ${table.items.length - 5} article(s) supplémentaire(s)\n`;
						}
					}

					ticket += separator('-') + '\n';
				}
				ticket += '\n';
			}
		}

		// Pied de page
		ticket += separator('=') + '\n';
		ticket += center('Merci !') + '\n';
		ticket += '\n';

		// Définir le type de contenu comme texte brut
		res.setHeader('Content-Type', 'text/plain; charset=utf-8');
		res.setHeader('Content-Disposition', 'inline; filename="rapport-x.txt"');
		return res.send(ticket);

	} catch (e) {
		console.error('[report-x] Erreur génération ticket:', e);
		return res.status(500).send('Erreur lors de la génération du ticket: ' + e.message);
	}
}

async function generateCreditReport(req, res) {
	try {
		const { server, period, dateFrom, dateTo, restaurantId } = req.query;
		const { report, creditDetails } = await buildReportData({ server, period, dateFrom, dateTo, restaurantId });
		return res.json({
			summary: report.creditSummary,
			transactions: creditDetails
		});
	} catch (e) {
		console.error('[credit-report] Erreur génération état crédits:', e);
		return res.status(500).json({ error: 'Erreur lors de la génération de l\'état des crédits', details: e.message });
	}
}

async function generateCreditReportTicket(req, res) {
	try {
		const { server, period, dateFrom, dateTo, restaurantId } = req.query;
		const { report, creditDetails } = await buildReportData({ server, period, dateFrom, dateTo, restaurantId });
		const creditSummary = report.creditSummary || {};
		const creditTotal = creditSummary.totalBalance ?? creditSummary.totalAmount ?? 0;
		const creditClients = creditSummary.clients || [];
		const creditTotalDebit = creditSummary.totalDebit || 0;
		const creditTotalCredit = creditSummary.totalCredit || 0;

		let ticket = '';
		const lineWidth = 48;
		const separatorLine = (char = '=') => char.repeat(lineWidth);
		const centerLine = (text) => {
			const padding = Math.max(0, Math.floor((lineWidth - text.length) / 2));
			return ' '.repeat(padding) + text;
		};

		const now = new Date();
		const dateStr = now.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
		const timeStr = now.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });

		ticket += centerLine('LES EMIRS RESTAURANT') + '\n';
		ticket += centerLine('ETAT DES CREDITS CLIENT') + '\n';
		ticket += separatorLine() + '\n';
		ticket += `Date: ${dateStr} ${timeStr}\n`;
		ticket += `Filtre serveur: ${server || 'TOUS'}\n`;
		ticket += `Période: ${period || 'ALL'}\n`;
		if (dateFrom) ticket += `Du: ${dateFrom}\n`;
		if (dateTo) ticket += `Au: ${dateTo}\n`;
		ticket += separatorLine('-') + '\n';

		ticket += `Dettes émises : ${creditTotalDebit.toFixed(3).replace('.', ',')} TND\n`;
		ticket += `Paiements reçus: ${creditTotalCredit.toFixed(3).replace('.', ',')} TND\n`;
		ticket += `Solde en cours : ${creditTotal.toFixed(3).replace('.', ',')} TND\n`;
		ticket += `Transactions sur période: ${(creditSummary.transactionsCount || 0)}\n`;
		ticket += '\n';

		if (creditClients.length > 0) {
			ticket += separatorLine() + '\n';
			ticket += centerLine('DETAIL PAR CLIENT') + '\n';
			ticket += separatorLine() + '\n';

			for (const client of creditClients) {
				const debitStr = (client.debitTotal || 0).toFixed(3).replace('.', ',');
				const creditStr = (client.creditTotal || 0).toFixed(3).replace('.', ',');
				const balanceStr = (client.balance || 0).toFixed(3).replace('.', ',');
				ticket += `${(client.clientName || 'N/A').toUpperCase()}\n`;
				ticket += `Dette: ${debitStr} | Paiement: ${creditStr} | Solde: ${balanceStr} TND\n`;
				ticket += `Mouvements: ${client.transactionsCount || 0}\n`;
				if (client.lastTransaction) {
					const date = new Date(client.lastTransaction);
					const clientDate = date.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
					ticket += `Dernier: ${clientDate}\n`;
				}
				ticket += separatorLine('-') + '\n';
			}
			ticket += '\n';
		} else {
			ticket += 'Aucun crédit enregistré.\n\n';
		}

		ticket += separatorLine() + '\n';
		ticket += centerLine('MOUVEMENTS DETAILLES') + '\n';
		ticket += separatorLine() + '\n';

		if (creditDetails.length === 0) {
			ticket += 'Aucun mouvement sur la période.\n';
		} else {
			for (const tx of creditDetails) {
				const date = new Date(tx.date);
				const txDate = date.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });
				const txTime = date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
				const amountStr = (tx.amount || 0).toFixed(3).replace('.', ',');
				const sign = tx.type === 'DEBIT' ? '+' : '-';
				const typeLabel = tx.type === 'DEBIT' ? 'DETTE' : 'PAIEMENT';
				ticket += `${txDate} ${txTime} - ${(tx.clientName || 'N/A').toUpperCase()}\n`;
				ticket += `${typeLabel}: ${sign}${amountStr} TND (${tx.paymentMode || '-'})\n`;
				if (tx.description) {
					const desc = tx.description.length > 48 ? `${tx.description.substring(0, 45)}...` : tx.description;
					ticket += `${desc}\n`;
				}
				ticket += separatorLine('-') + '\n';
			}
		}

		ticket += '\n' + centerLine('Fin de l\'état') + '\n';

		res.setHeader('Content-Type', 'text/plain; charset=utf-8');
		res.setHeader('Content-Disposition', 'inline; filename=\"credit-report.txt\"');
		return res.send(ticket);

	} catch (e) {
		console.error('[credit-report] Erreur génération ticket crédits:', e);
		return res.status(500).send('Erreur lors de la génération du ticket crédits: ' + e.message);
	}
}

module.exports = {
	generateReportX,
	generateReportXTicket,
	generateCreditReport,
	generateCreditReportTicket
};

