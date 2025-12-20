// 📦 Controller POS - Archives
// Gère la consultation des notes archivées

const dataStore = require('../data');
const historyProcessor = require('../utils/history-processor');

// Récupérer les notes archivées
async function getArchivedNotes(req, res) {
	const { table, orderId, dateFrom, dateTo } = req.query;
	
	// Filtrer les notes archivées (exclure les éléments undefined/null)
	const archived = dataStore.archivedOrders.filter(o => {
		if (!o) return false;
		if (table && String(o.table) !== String(table)) return false;
		if (orderId && o.id !== Number(orderId)) return false;
		return true;
	});
	
	return res.json(archived);
}

// Récupérer les commandes archivées par serveur (pour historique POS)
async function getArchivedOrdersByServer(req, res) {
	try {
		const { server } = req.query;
		
		console.log(`[history] Requête historique pour serveur: ${server}`);
		
		if (!server) {
			return res.status(400).json({ error: 'Paramètre server requis' });
		}
		
		// Filtrer les commandes archivées par serveur (exclure les éléments undefined/null)
		let result = dataStore.archivedOrders.filter(o => {
			return o && o.server && String(o.server).toUpperCase() === String(server).toUpperCase();
		});
		
		// Grouper par table d'abord
		const groupedByTable = {};
		for (const order of result) {
			const tableNumber = String(order.table || '?');
			if (!groupedByTable[tableNumber]) {
				groupedByTable[tableNumber] = [];
			}
			groupedByTable[tableNumber].push(order);
		}
		
		// Pour chaque table, grouper par service et traiter les sessions
		const processedTables = {};
		for (const [tableNumber, sessions] of Object.entries(groupedByTable)) {
			console.log(`[history] Table ${tableNumber}: ${sessions.length} commande(s) archivée(s)`);
			
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
		
		console.log(`[history] Commandes archivées pour serveur ${server}: ${result.length} trouvées`);
		
		return res.json({
			orders: result,
			processedTables: processedTables,
			total: result.length,
			server: server,
		});
	} catch (e) {
		console.error('[history] Erreur récupération commandes archivées:', e);
		return res.status(500).json({ error: 'Erreur lors de la récupération des commandes archivées' });
	}
}

module.exports = {
	getArchivedNotes,
	getArchivedOrdersByServer
};

