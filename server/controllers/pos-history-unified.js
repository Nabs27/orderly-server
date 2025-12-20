// 📦 Controller POS - Historique Unifié
// Gère l'historique détaillé incluant les tables actives avec paiements partiels
// Utilise la même logique que pos-archive.js mais inclut aussi dataStore.orders

const dataStore = require('../data');
const historyProcessor = require('../utils/history-processor');

// Récupérer l'historique unifié (archivées + actives) par serveur
async function getUnifiedHistoryByServer(req, res) {
	try {
		const { server } = req.query;
		
		console.log(`[history-unified] Requête historique unifié pour serveur: ${server}`);
		
		if (!server) {
			return res.status(400).json({ error: 'Paramètre server requis' });
		}
		
		// 🆕 Filtrer les commandes archivées ET actives par serveur
		const archivedOrders = dataStore.archivedOrders.filter(o => {
			return o && o.server && String(o.server).toUpperCase() === String(server).toUpperCase();
		});
		
		const activeOrders = dataStore.orders.filter(o => {
			return o && o.server && String(o.server).toUpperCase() === String(server).toUpperCase();
		});
		
		// 🆕 Combiner les deux listes (archivées + actives)
		// Pour les actives, on ne garde que celles qui ont au moins un paiement
		const activeOrdersWithPayments = activeOrders.filter(o => {
			return o.paymentHistory && Array.isArray(o.paymentHistory) && o.paymentHistory.length > 0;
		});
		
		const allOrders = [...archivedOrders, ...activeOrdersWithPayments];
		
		// Grouper par table
		const groupedByTable = {};
		for (const order of allOrders) {
			const tableNumber = String(order.table || '?');
			if (!groupedByTable[tableNumber]) {
				groupedByTable[tableNumber] = [];
			}
			groupedByTable[tableNumber].push(order);
		}
		
		// Pour chaque table, grouper par service et traiter les sessions
		const processedTables = {};
		for (const [tableNumber, sessions] of Object.entries(groupedByTable)) {
			console.log(`[history-unified] Table ${tableNumber}: ${sessions.length} commande(s) (${archivedOrders.filter(o => String(o.table) === tableNumber).length} archivées, ${activeOrdersWithPayments.filter(o => String(o.table) === tableNumber).length} actives)`);
			
			// Grouper par service en utilisant la fonction partagée
			const services = historyProcessor.groupOrdersByService(sessions);
			
			// Traiter chaque service
			const processedServices = {};
			for (const [serviceIndex, serviceSessions] of Object.entries(services)) {
				processedServices[serviceIndex] = historyProcessor.processServiceSessions(serviceSessions);
			}
			
			processedTables[tableNumber] = {
				sessions: sessions,
				services: processedServices,
			};
		}
		
		console.log(`[history-unified] Historique unifié pour serveur ${server}: ${allOrders.length} commandes trouvées (${archivedOrders.length} archivées, ${activeOrdersWithPayments.length} actives avec paiements)`);
		
		return res.json({
			orders: allOrders,
			processedTables: processedTables,
			total: allOrders.length,
			server: server,
			archivedCount: archivedOrders.length,
			activeCount: activeOrdersWithPayments.length,
		});
	} catch (e) {
		console.error('[history-unified] Erreur récupération historique unifié:', e);
		return res.status(500).json({ error: 'Erreur lors de la récupération de l\'historique unifié' });
	}
}

module.exports = {
	getUnifiedHistoryByServer,
};

