// 🎲 Routes Admin - Simulation de données
// Génération de données de test pour le système POS

const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const { authAdmin } = require('../middleware/auth');
const dataStore = require('../data');
const fileManager = require('../utils/fileManager');
const { getIO } = require('../utils/socket');

function shuffleArray(items) {
	const array = [...items];
	for (let i = array.length - 1; i > 0; i--) {
		const j = Math.floor(Math.random() * (i + 1));
		[array[i], array[j]] = [array[j], array[i]];
	}
	return array;
}

function cloneItems(items = []) {
	return (items || []).map(item => ({ ...item }));
}

function buildOrderHistoryEntries(mainItems, subNote, createdAt, tableNumber, serverName) {
	const history = [];
	if (mainItems && mainItems.length > 0) {
		history.push({
			timestamp: createdAt.toISOString(),
			action: 'order_created',
			noteId: 'main',
			noteName: 'Note Principale',
			items: cloneItems(mainItems),
			details: `Commande simulée sur table ${tableNumber} (${serverName})`
		});
	}
	if (subNote && Array.isArray(subNote.items) && subNote.items.length > 0) {
		history.push({
			timestamp: new Date(createdAt.getTime() + 30000).toISOString(),
			action: 'subnote_created',
			noteId: subNote.id,
			noteName: subNote.name,
			items: cloneItems(subNote.items),
			details: `Sous-note ${subNote.name} simulée`
		});
	}
	return history;
}

// 🎲 Simulation de données pour tests
router.post('/simulate-data', authAdmin, async (req, res) => {
	try {
		const {
			mode = 'once',
			servers = ['MOHAMED', 'ALI', 'FATIMA'],
			progressive = false
		} = req.body;
		
		const normalizedServers = servers.map(server => {
			if (typeof server === 'string' && server.toUpperCase() === 'FATMA') {
				return 'FATIMA';
			}
			return server;
		});
		
		console.log(`[simulation] Démarrage simulation mode: ${mode}, serveurs: ${normalizedServers.join(', ')}`);
		
		// 🔁 Remise à zéro des crédits clients au DÉBUT pour cohérence
		dataStore.clientCredits = [];
		dataStore.nextClientId = 1;
		console.log('[simulation] Crédit clients remis à zéro au début');
		
		// Charger le menu
		const menuPath = path.join(__dirname, '..', '..', 'data', 'restaurants', 'les-emirs', 'menu.json');
		if (!fs.existsSync(menuPath)) {
			return res.status(400).json({ error: 'Menu non trouvé. Créez d\'abord un menu.' });
		}
		
		const menuRaw = fs.readFileSync(menuPath, 'utf8');
		const menu = JSON.parse(menuRaw);
		
		// Organiser les articles par catégorie pour une sélection cohérente
		const itemsByCategory = {};
		const allMenuItems = [];
		
		(menu.categories || []).forEach(cat => {
			const categoryName = (cat.name || '').toLowerCase();
			if (!itemsByCategory[categoryName]) {
				itemsByCategory[categoryName] = [];
			}
			
			(cat.items || []).forEach(item => {
				const itemData = {
					id: item.id || item.code,
					name: item.name || item.label,
					price: typeof item.price === 'number' ? item.price : (typeof item.unitPrice === 'number' ? item.unitPrice : 0),
					category: categoryName
				};
				allMenuItems.push(itemData);
				itemsByCategory[categoryName].push(itemData);
			});
		});
		
		if (allMenuItems.length === 0) {
			return res.status(400).json({ error: 'Aucun article dans le menu' });
		}
		
		// Identifier les catégories de type repas (entrées, plats, desserts)
		const getCategoryType = (catName) => {
			const name = catName.toLowerCase();
			if (name.includes('entrée') || name.includes('entree') || name.includes('hors') || name.includes('salade') || name.includes('soupe')) {
				return 'entree';
			}
			if (name.includes('plat') || name.includes('principal') || name.includes('viande') || name.includes('poisson') || name.includes('poulet')) {
				return 'plat';
			}
			if (name.includes('dessert') || name.includes('patisserie') || name.includes('glace')) {
				return 'dessert';
			}
			if (name.includes('boisson') || name.includes('eau') || name.includes('soda') || name.includes('jus') || name.includes('café') || name.includes('the')) {
				return 'boisson';
			}
			return 'autre';
		};
		
		// Organiser par type
		const itemsByType = { entree: [], plat: [], dessert: [], boisson: [], autre: [] };
		Object.keys(itemsByCategory).forEach(catName => {
			const type = getCategoryType(catName);
			itemsByCategory[catName].forEach(item => {
				itemsByType[type].push(item);
			});
		});
		
		// Noms de clients pour sous-notes
		const clientNames = ['Nabil', 'Selim', 'Selima', 'Karim', 'Amira', 'Youssef', 'Lina', 'Omar', 'Sara', 'Mehdi'];
		
		// Modes de paiement (incluant CREDIT)
		const paymentModes = ['ESPECE', 'CARTE', 'CHEQUE', 'CREDIT'];
		
		// Compteur pour limiter les paiements à crédit (1-2 sur toutes les commandes)
		let creditPaymentCount = 0;
		const maxCreditPayments = Math.floor(Math.random() * 2) + 1; // 1 ou 2 paiements à crédit
		
		// Générer les commandes
		const now = new Date();
		const startTime = new Date(now);
		startTime.setHours(now.getHours() - 5); // 5h d'ouverture
		
		const generatedOrders = []; // Contient les commandes (order objects)
		const tablesUsed = new Set();
		let totalTables = 0;
		const pendingCreditTransactions = [];

	function clonePaymentItems(items = []) {
		return (items || []).map(item => ({
			id: item.id,
			name: item.name,
			price: item.price,
			quantity: item.quantity,
		}));
	}
		const ACTIVE_TABLES_RATIO = 0.2;
		
		// Fonction utilitaire pour choisir un élément avec fallback
		const pickItem = (pool, fallback) => {
			if (pool.length > 0) {
				return pool.pop();
			}
			if (fallback && fallback.length > 0) {
				return fallback[Math.floor(Math.random() * fallback.length)];
			}
			if (allMenuItems.length > 0) {
				return allMenuItems[Math.floor(Math.random() * allMenuItems.length)];
			}
			return null;
		};
		
		// Fonction pour générer une commande
		const generateOrder = (server, tableNum, timestamp) => {
			const orderId = dataStore.nextOrderId++;
			const aggregatedItems = new Map();
			let subtotal = 0;
			
			// Nombre de couverts (1-6 personnes)
			let covers = Math.floor(Math.random() * 6) + 1;
			if (Math.random() < 0.2) {
				covers = Math.floor(Math.random() * 6) + 7; // 7 à 12 couverts
			}
			covers = Math.min(covers, 12);
			
			const addItem = (menuItem, quantity = 1) => {
				if (!menuItem || typeof menuItem.price !== 'number') return;
				const key = menuItem.id || menuItem.name;
				if (!key) return;
				const total = menuItem.price * quantity;
				const existing = aggregatedItems.get(key);
				if (existing) {
					existing.quantity += quantity;
					existing.total += total;
				} else {
					aggregatedItems.set(key, {
						id: menuItem.id,
						name: menuItem.name,
						price: menuItem.price,
						quantity,
						total
					});
				}
				subtotal += total;
			};
			
			const mealThemes = [
				{ name: 'terre', keywords: ['boeuf', 'steak', 'agneau', 'veau', 'poulet', 'canard'] },
				{ name: 'mer', keywords: ['poisson', 'mer', 'saumon', 'thon', 'crevette', 'dorade', 'pêcheur'] },
				{ name: 'mixte', keywords: [] }
			];
			const theme = mealThemes[Math.floor(Math.random() * mealThemes.length)];
			
			const entreePool = shuffleArray(itemsByType.entree);
			const platPool = shuffleArray(itemsByType.plat);
			let themedPlatPool = platPool.filter(item =>
				theme.keywords.some(keyword => (item.name || '').toLowerCase().includes(keyword))
			);
			if (themedPlatPool.length < Math.min(6, covers)) {
				themedPlatPool = platPool;
			}
			const dessertPool = shuffleArray(itemsByType.dessert);
			const beveragePool = shuffleArray(itemsByType.boisson);
			
			const coversWithEntree = Math.max(0, Math.round(covers * 0.6));
			const coversWithDessert = Math.max(0, Math.round(covers * 0.2));
			const totalDrinks = Math.max(covers, Math.ceil(covers * 1.3));
			const maxCocktails = Math.max(1, Math.floor(covers * 0.3));
			let cocktailsCount = 0;
			const cocktailRegex = /(mojito|smirnoff|vodka|gin|whisky|whiskey|rhum|cocktail|tequila|bière|beer|vin)/i;
			
			for (let i = 0; i < covers; i++) {
				if (i < coversWithEntree) {
					const entree = pickItem(entreePool, itemsByType.entree);
					if (entree) addItem(entree, 1);
				}
				
				let plat = pickItem(themedPlatPool, itemsByType.plat);
				if (!plat) {
					plat = pickItem(platPool, itemsByType.plat);
				}
				if (plat) addItem(plat, 1);
				
				if (i < coversWithDessert) {
					const dessert = pickItem(dessertPool, itemsByType.dessert);
					if (dessert) addItem(dessert, 1);
				}
			}
			
			for (let i = 0; i < totalDrinks; i++) {
				const beverage = pickItem(beveragePool, itemsByType.boisson);
				if (!beverage) break;
				const isCocktail = cocktailRegex.test((beverage.name || '').toLowerCase());
				if (isCocktail) {
					if (cocktailsCount >= maxCocktails) {
						continue;
					}
					cocktailsCount++;
				}
				addItem(beverage, 1);
			}
			
			if (aggregatedItems.size === 0 && allMenuItems.length > 0) {
				const fallbackItem = allMenuItems[Math.floor(Math.random() * allMenuItems.length)];
				addItem(fallbackItem, covers);
			}
			
			const items = Array.from(aggregatedItems.values());
			
			// 30% de chance d'avoir une sous-note
			const hasSubNote = Math.random() < 0.3;
			const subNotes = [];
			let subNoteClient = null; // 🆕 Déclarer en dehors du bloc pour être accessible partout
			
			if (hasSubNote) {
				subNoteClient = clientNames[Math.floor(Math.random() * clientNames.length)];
				const subNoteItems = items.slice(0, Math.floor(items.length / 2));
				const subNoteTotal = subNoteItems.reduce((sum, it) => sum + it.total, 0);
				
				subNotes.push({
					id: `sub_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
					name: subNoteClient,
					items: subNoteItems,
					total: subNoteTotal,
					paidQuantity: 0,
					totalQuantity: subNoteItems.reduce((sum, it) => sum + it.quantity, 0)
				});
			}
			
			// Appliquer une remise (15% uniquement) – toujours en pourcentage
			const hasDiscount = Math.random() < 0.2;
			let discount = 0;
			let discountAmount = 0;
			let isPercentDiscount = false;
			
			if (hasDiscount) {
				isPercentDiscount = true;
				discount = 15; // 15% fixe pour refléter la politique du restaurant
				discountAmount = (subtotal * discount) / 100;
			}
			
			const finalAmount = subtotal - discountAmount;
			const creditEntries = [];
			
			// Déterminer le mode de paiement (limiter les paiements à crédit)
			let paymentMode;
			let creditClientName = null;
			if (creditPaymentCount < maxCreditPayments && Math.random() < 0.15) {
				// 15% de chance si on n'a pas encore atteint le max
				paymentMode = 'CREDIT';
				creditPaymentCount++;
				// Sélectionner un nom de client pour le crédit
				creditClientName = clientNames[Math.floor(Math.random() * clientNames.length)];
			} else {
				// Exclure CREDIT des modes normaux
				const normalModes = paymentModes.filter(m => m !== 'CREDIT');
				paymentMode = normalModes[Math.floor(Math.random() * normalModes.length)];
			}
			
			// Créer le paiement principal
			const mainPayment = {
				id: `payment_${orderId}_${Date.now()}`,
				type: 'payment',
				timestamp: timestamp.toISOString(),
				table: tableNum,
				server: server,
				noteId: 'main',
				noteName: 'Note Principale',
				items: hasSubNote ? items.filter(it => !subNotes[0].items.some(sn => sn.id === it.id)) : items,
				subtotal: hasSubNote ? subtotal - subNotes[0].total : subtotal,
				discount: discount,
				discountAmount: discountAmount,
				isPercentDiscount: isPercentDiscount,
				hasDiscount: hasDiscount,
				amount: hasSubNote ? finalAmount - subNotes[0].total : finalAmount,
				paymentMode: paymentMode,
				covers: covers
			};
			if (paymentMode === 'CREDIT') {
				creditEntries.push({
					clientName: creditClientName,
					amount: mainPayment.amount,
					table: tableNum,
					orderId,
					timestamp,
					server,
					items: clonePaymentItems(mainPayment.items),
					subtotal: mainPayment.subtotal,
					discount: mainPayment.discountAmount,
					isPercentDiscount: mainPayment.isPercentDiscount,
				});
			}
			
			// Construire l'historique des paiements
			const paymentHistory = [mainPayment];
			
			// Si sous-note, créer un paiement séparé pour elle
			if (hasSubNote && subNotes.length > 0) {
				let subNotePaymentMode;
				let subNoteCreditClientName = null;
				if (creditPaymentCount < maxCreditPayments && Math.random() < 0.15) {
					subNotePaymentMode = 'CREDIT';
					subNoteCreditClientName = subNoteClient;
					creditPaymentCount++;
				} else {
					const subNotePaymentModes = paymentModes.filter(m => m !== 'CREDIT');
					subNotePaymentMode = subNotePaymentModes[Math.floor(Math.random() * subNotePaymentModes.length)];
				}
				
				const subNotePayment = {
					id: `payment_${orderId}_sub_${Date.now()}`,
					type: 'payment',
					timestamp: new Date(timestamp.getTime() + 60000).toISOString(), // 1 min après
					table: tableNum,
					server: server,
					noteId: subNotes[0].id,
					noteName: subNotes[0].name,
					items: subNotes[0].items,
					subtotal: subNotes[0].total,
					discount: 0,
					discountAmount: 0,
					isPercentDiscount: false,
					hasDiscount: false,
					amount: subNotes[0].total,
					paymentMode: subNotePaymentMode,
					covers: 1
				};
				paymentHistory.push(subNotePayment);
				
				if (subNotePaymentMode === 'CREDIT') {
					creditEntries.push({
						clientName: subNoteCreditClientName || subNoteClient,
						amount: subNotes[0].total,
						table: tableNum,
						orderId,
						timestamp: new Date(timestamp.getTime() + 60000),
						server,
						items: clonePaymentItems(subNotes[0].items),
						subtotal: subNotes[0].total,
						discount: 0,
						isPercentDiscount: false,
					});
				}
			}
			
			const mainNoteItems = hasSubNote
				? items.filter(it => !subNotes[0].items.some(sn => sn.id === it.id))
				: items;
			const orderCreatedAt = new Date(timestamp.getTime() - 3600000);
			const orderHistory = buildOrderHistoryEntries(
				mainNoteItems,
				hasSubNote ? subNotes[0] : null,
				orderCreatedAt,
				tableNum,
				server
			);
			
			const mainNoteTotalQuantity = mainNoteItems.reduce((sum, it) => sum + (it.quantity || 0), 0);
			
			const order = {
				id: orderId,
				table: tableNum,
				server: server,
				status: 'archived',
				archivedAt: timestamp.toISOString(),
				createdAt: orderCreatedAt.toISOString(), // 1h avant
				mainNote: {
					id: 'main',
					name: 'Note Principale',
					items: mainNoteItems,
					total: hasSubNote ? subtotal - subNotes[0].total : subtotal,
					paidQuantity: mainNoteTotalQuantity,
					totalQuantity: mainNoteTotalQuantity,
					covers: covers
				},
				subNotes: subNotes,
				paymentHistory: paymentHistory,
				orderHistory: orderHistory,
				creditClientName: creditClientName // Stocker le nom du client pour crédit
			};
			
			return { order, creditEntries };
		};
		
		// Mode "en une fois" : générer toutes les commandes immédiatement
		if (mode === 'once' || !progressive) {
			for (const server of normalizedServers) {
				for (let t = 1; t <= 10; t++) {
					const tableNum = `${server}_${t}`;
					tablesUsed.add(tableNum);
					
					// Générer 1-3 commandes par table
					const numOrders = Math.floor(Math.random() * 3) + 1;
					for (let o = 0; o < numOrders; o++) {
						const timeOffset = Math.random() * 5 * 3600000; // 0-5h
						const timestamp = new Date(startTime.getTime() + timeOffset);
						const result = generateOrder(server, tableNum, timestamp);
						generatedOrders.push(result.order);
						
						if (result.creditEntries && result.creditEntries.length > 0) {
							for (const entry of result.creditEntries) {
								pendingCreditTransactions.push(entry);
							}
						}
					}
				}
			}
			totalTables = tablesUsed.size;
		} else {
			// Mode progressif : générer progressivement (simulation)
			// Pour l'instant, on génère tout mais on pourrait implémenter un système de délai
			for (const server of normalizedServers) {
				for (let t = 1; t <= 10; t++) {
					const tableNum = `${server}_${t}`;
					tablesUsed.add(tableNum);
					
					const numOrders = Math.floor(Math.random() * 3) + 1;
					for (let o = 0; o < numOrders; o++) {
						const timeOffset = Math.random() * 5 * 3600000;
						const timestamp = new Date(startTime.getTime() + timeOffset);
						const result = generateOrder(server, tableNum, timestamp);
						generatedOrders.push(result.order);
						
						if (result.creditEntries && result.creditEntries.length > 0) {
							for (const entry of result.creditEntries) {
								pendingCreditTransactions.push(entry);
							}
						}
					}
				}
			}
			totalTables = tablesUsed.size;
		}
		
		// Organiser les commandes par table pour sélectionner des tables actives
		const ordersByTable = {};
		for (const order of generatedOrders) {
			if (!order) continue;
			if (!ordersByTable[order.table]) {
				ordersByTable[order.table] = [];
			}
			ordersByTable[order.table].push(order);
		}
		
		const tableList = Object.keys(ordersByTable);
		const desiredActiveTables = Math.max(1, Math.round(tableList.length * ACTIVE_TABLES_RATIO));
		const selectedActiveTables = new Set(shuffleArray(tableList).slice(0, desiredActiveTables));
		
		const activeOrders = [];
		const archivedOrdersFinal = [];

		const recalcNoteTotal = (note) => {
			if (!note || !note.items) return 0;
			let total = 0;
			for (const item of note.items) {
				const qty = item.quantity || 0;
				item.paidQuantity = 0;
				total += (item.price || 0) * qty;
			}
			note.total = total;
			return total;
		};
		
		for (const tableId of tableList) {
			const tableOrders = ordersByTable[tableId]
				.slice()
				.sort((a, b) => {
					const dateA = a.archivedAt ? new Date(a.archivedAt) : new Date(0);
					const dateB = b.archivedAt ? new Date(b.archivedAt) : new Date(0);
					return dateA - dateB;
				});
			
			if (selectedActiveTables.has(tableId) && tableOrders.length > 0) {
				const latestOrder = tableOrders.pop();
				if (latestOrder) {
					const activeOrder = JSON.parse(JSON.stringify(latestOrder));
					activeOrder.status = 'open';
					activeOrder.archivedAt = null;
					delete activeOrder.creditClientName;
					activeOrder.paymentHistory = [];
					if (activeOrder.mainNote) {
						const totalQty = (activeOrder.mainNote.items || []).reduce((sum, item) => sum + (item.quantity || 0), 0);
						activeOrder.mainNote.paidQuantity = 0;
						activeOrder.mainNote.totalQuantity = totalQty;
						recalcNoteTotal(activeOrder.mainNote);
					}
					if (Array.isArray(activeOrder.subNotes)) {
						activeOrder.subNotes = activeOrder.subNotes.map(subNote => {
							const totalQty = (subNote.items || []).reduce((sum, item) => sum + (item.quantity || 0), 0);
							return {
								...subNote,
								paidQuantity: 0,
								totalQuantity: totalQty
							};
						});
					}
					const subNotesTotals = activeOrder.subNotes
						? activeOrder.subNotes.map(note => recalcNoteTotal(note)).reduce((a, b) => a + b, 0)
						: 0;
					const mainTotal = activeOrder.mainNote ? activeOrder.mainNote.total || 0 : 0;
					activeOrder.total = (mainTotal || 0) + (subNotesTotals || 0);
					activeOrder.orderHistory = activeOrder.orderHistory || [];
					activeOrder.orderHistory.push({
						timestamp: new Date().toISOString(),
						action: 'simulation',
						details: 'Table laissée active pour tests'
					});
					activeOrders.push(activeOrder);
				}
			}
			
			archivedOrdersFinal.push(...tableOrders);
		}
		
		const activeOrderIds = new Set(activeOrders.map(order => order.id));
		
		// Appliquer les transactions de crédit uniquement pour les commandes archivées
		let creditPaymentsCount = 0;
		for (const pendingTx of pendingCreditTransactions) {
			if (activeOrderIds.has(pendingTx.orderId)) {
				continue;
			}
			
			let client = dataStore.clientCredits.find(c => 
				c.name.toLowerCase().trim() === pendingTx.clientName.toLowerCase().trim()
			);
			
			if (!client) {
				client = {
					id: dataStore.nextClientId++,
					name: pendingTx.clientName,
					phone: `+216${Math.floor(Math.random() * 90000000) + 10000000}`,
					transactions: []
				};
				dataStore.clientCredits.push(client);
				console.log(`[simulation] Client créé pour crédit: ${client.name} (ID: ${client.id})`);
			}
			
			client.transactions.push({
				id: Date.now() + Math.random(),
				type: 'DEBIT',
				amount: pendingTx.amount,
				description: `Commande table ${pendingTx.table} - paiement à crédit`,
				date: pendingTx.timestamp.toISOString(),
				orderId: pendingTx.orderId,
				paymentMode: 'CREDIT',
				server: pendingTx.server || 'SIMULATION',
				table: pendingTx.table,
				ticket: {
					table: pendingTx.table,
					date: pendingTx.timestamp.toISOString(),
					items: clonePaymentItems(pendingTx.items || []),
					total: pendingTx.amount,
					subtotal: pendingTx.subtotal || pendingTx.amount,
					discount: pendingTx.discount || 0,
					isPercentDiscount: pendingTx.isPercentDiscount || false,
					server: pendingTx.server || 'SIMULATION',
				},
			});
			creditPaymentsCount++;
		}
		
		// Ajouter aux stocks de données
		dataStore.archivedOrders.push(...archivedOrdersFinal);
		dataStore.orders = activeOrders;
		
		// Sauvegarder
		await fileManager.savePersistedData();
		
		// Émettre événement Socket.IO
		const io = getIO();
		io.emit('system:simulation-complete', {
			orders: generatedOrders.length,
			tables: totalTables,
			mode: mode,
			creditPayments: creditPaymentsCount,
			activeTables: activeOrders.length
		});
		
		console.log(`[simulation] ✅ Simulation terminée: ${generatedOrders.length} commandes, ${totalTables} tables, ${creditPaymentsCount} paiement(s) à crédit, ${activeOrders.length} table(s) active(s)`);
		
		return res.json({
			ok: true,
			generated: {
				orders: generatedOrders.length,
				totalTables: totalTables,
				servers: servers.length,
				activeTables: activeOrders.length
			},
			mode: mode
		});
		
	} catch (e) {
		console.error('[simulation] Erreur:', e);
		return res.status(500).json({ error: 'Erreur simulation: ' + e.message });
	}
});

module.exports = router;

