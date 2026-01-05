// 🚀 Serveur refactorisé
// Ce fichier utilise les modules créés dans le dossier server/

// Charger les variables d'environnement depuis .env (si le fichier existe)
require('dotenv').config();

const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');

// Importer les données globales
const dataStore = require('./server/data');
const fileManager = require('./server/utils/fileManager');
const socketManager = require('./server/utils/socket');
const dbManager = require('./server/utils/dbManager');

// Importer les routes
const baseRoutes = require('./server/routes/base');
const clientRoutes = require('./server/routes/client');
const { router: sharedRoutes, setIO: setSharedIO } = require('./server/routes/shared');
const { router: posRoutes, setIO: setPosIO } = require('./server/routes/pos');
const adminRoutes = require('./server/routes/admin'); // ✅ Routes admin combinées (structure découpée)

const app = express();
const server = http.createServer(app);

// ⚙️ Socket.IO keepalive tunables
const SOCKET_PING_INTERVAL = parseInt(process.env.SOCKET_PING_INTERVAL || '30000', 10);
const SOCKET_PING_TIMEOUT = parseInt(process.env.SOCKET_PING_TIMEOUT || '20000', 10);
const io = new Server(server, {
	cors: { origin: '*', methods: ['GET', 'POST', 'PATCH'] },
	pingInterval: SOCKET_PING_INTERVAL,
	pingTimeout: SOCKET_PING_TIMEOUT,
});
console.log(`[socket] pingInterval=${SOCKET_PING_INTERVAL}ms, pingTimeout=${SOCKET_PING_TIMEOUT}ms`);

// Enregistrer l'instance Socket.IO globalement
socketManager.setIO(io);

// Injecter io dans les routes partagées et POS
setSharedIO(io);
setPosIO(io);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Injecter io dans l'app pour les routes qui en ont besoin
app.set('io', io);

// Routes
app.use('/', baseRoutes);
app.use('/', clientRoutes);
app.use('/', sharedRoutes);
app.use('/', posRoutes);
app.use('/api/admin', adminRoutes); // ✅ Préfixe /api/admin pour toutes les routes admin

// Construire l'index du menu au démarrage (async)
dataStore.buildMenuIndex().catch(e => {
	console.error('[server] Erreur construction index menu:', e);
});

// Charger les données persistantes (détecte Cloud vs Local)
dbManager.connect().then(() => {
	return fileManager.loadPersistedData();
}).then(() => {
	console.log('[server] Données initialisées');
	
	// 🆕 ARCHITECTURE "BOÎTE AUX LETTRES" : Polling périodique pour aspirer les commandes
	// Le serveur local vérifie la boîte aux lettres MongoDB toutes les 5 secondes
	// Cela permet de recevoir les commandes client rapidement sans redémarrer le serveur
	const isLocalServer = !dbManager.isCloud;
	if (isLocalServer && dbManager.db) {
		const POLLING_INTERVAL = 5000; // Vérifier toutes les 5 secondes
		
		// 🆕 SYNCHRONISATION PÉRIODIQUE : Synchroniser les commandes actives vers MongoDB
		// pour que le dashboard admin en ligne puisse voir les tables non payées
		const SYNC_INTERVAL = 10000; // Synchroniser toutes les 10 secondes
		
		setInterval(async () => {
			try {
				const processedCount = await fileManager.pullFromMailbox();
				if (processedCount > 0) {
					// Notifier via Socket.IO les nouvelles commandes
					const { getIO } = require('./server/utils/socket');
					const io = getIO();
					
					// Émettre un événement pour rafraîchir les tables
					io.emit('orders:sync', { timestamp: new Date().toISOString() });
					console.log(`[sync] 📡 Notification Socket.IO envoyée pour ${processedCount} nouvelle(s) commande(s)`);
				}
			} catch (e) {
				console.error('[sync] ⚠️ Erreur polling boîte aux lettres:', e.message);
			}
		}, POLLING_INTERVAL);
		
		// 🆕 Synchroniser les commandes actives vers MongoDB périodiquement
		setInterval(async () => {
			try {
				const activeOrders = dataStore.orders.filter(o => o.status !== 'archived');
				if (activeOrders.length > 0) {
					// Synchroniser uniquement les commandes actives (via saveToMongoDB)
					// On appelle directement saveToMongoDB pour éviter de sauvegarder le JSON
					const fileManager = require('./server/utils/fileManager');
					await fileManager.savePersistedData();
					console.log(`[sync] 🔄 ${activeOrders.length} commande(s) active(s) synchronisée(s) vers MongoDB`);
				}
			} catch (e) {
				console.error('[sync] ⚠️ Erreur synchronisation commandes actives:', e.message);
			}
		}, SYNC_INTERVAL);
		
		console.log(`[server] 📬 Polling boîte aux lettres activé (toutes les ${POLLING_INTERVAL/1000}s)`);
		console.log(`[server] 🔄 Synchronisation commandes actives activée (toutes les ${SYNC_INTERVAL/1000}s)`);
	} else if (dbManager.isCloud && dbManager.db && !isLocalServer) {
		// 🆕 DÉTECTION RESET pour serveur cloud : vérifier périodiquement si reset détecté
		const CLOUD_RESET_CHECK_INTERVAL = 5000; // Vérifier toutes les 5 secondes
		
		setInterval(async () => {
			try {
				const countersDoc = await dbManager.counters.findOne({ type: 'global' });
				if (countersDoc && countersDoc.nextOrderId === 1) {
					// Vérifier si nous avons des commandes avec des IDs élevés en mémoire
					const maxOrderId = dataStore.orders.length > 0 
						? Math.max(...dataStore.orders.map(o => o.id || 0))
						: 0;
					
					// 🆕 Vérifier aussi si MongoDB contient des commandes avec des IDs élevés
					const mongoOrders = await dbManager.orders.find({}).toArray();
					const maxMongoOrderId = mongoOrders.length > 0
						? Math.max(...mongoOrders.map(o => o.id || 0))
						: 0;
					
					if (maxOrderId > 1 || maxMongoOrderId > 1) {
						console.log(`[server] 🔄 RESET DÉTECTÉ sur serveur cloud : Compteur MongoDB à 1 mais ${dataStore.orders.length} commande(s) en mémoire (max ID: ${maxOrderId}) et ${mongoOrders.length} dans MongoDB (max ID: ${maxMongoOrderId})`);
						console.log('[server] 🔄 Vidage mémoire et nettoyage MongoDB...');
						
						// 🆕 Supprimer toutes les commandes de MongoDB si le compteur est à 1
						if (maxMongoOrderId > 1) {
							const deleteResult = await dbManager.orders.deleteMany({});
							console.log(`[server] 🗑️ ${deleteResult.deletedCount} commande(s) supprimée(s) de MongoDB (reset détecté)`);
						}
						
						// Vider la mémoire et recharger depuis MongoDB (qui sera vide)
						await fileManager.loadFromMongoDB();
						
						console.log(`[server] ✅ Mémoire serveur cloud synchronisée après reset : ${dataStore.orders.length} commande(s) chargée(s)`);
					}
				}
			} catch (e) {
				console.error('[server] ⚠️ Erreur vérification reset serveur cloud:', e.message);
			}
		}, CLOUD_RESET_CHECK_INTERVAL);
		
		console.log(`[server] ☁️ Serveur cloud détecté (port ${process.env.PORT || 3000}), vérification reset activée (toutes les ${CLOUD_RESET_CHECK_INTERVAL/1000}s)`);
	}
}).catch(err => {
	console.error('[server] ❌ Erreur initialisation données:', err);
});

// Gestion des connexions Socket.IO
io.on('connection', (socket) => {
	console.log('[socket] Client connecté:', socket.id);
	socket.on('disconnect', () => {
		console.log('[socket] Client déconnecté:', socket.id);
	});
	// Endpoint de reset (TEST uniquement)
	socket.on('dev:reset', () => {
		dataStore.orders = [];
		dataStore.nextOrderId = 1;
		dataStore.bills = [];
		dataStore.nextBillId = 1;
		dataStore.serviceRequests = [];
		dataStore.nextServiceId = 1;
		console.log('[dev] État serveur réinitialisé');
	});
});

// Démarrer le serveur
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
	console.log(`[server] ✅ Serveur refactorisé démarré sur le port ${PORT}`);
	console.log('[server] 📁 Structure modulaire: routes/, controllers/, utils/');
	console.log('[server] ✅ Toutes les routes extraites et intégrées');
	console.log('[server] 💾 Backup disponible: server.backup.js');
	console.log('[server] 🎯 Routes admin: structure découpée en modules spécialisés (auth, restaurants, menu, archive, system, parse, invoice)');
	console.log('');
	console.log('[server] 💡 Pour arrêter: Appuyez sur Ctrl+C');
	console.log('[server] 💡 Pour redémarrer: Appuyez sur Ctrl+C puis relancez "npm start"');
	console.log('');
});

// 🆕 Gestion gracieuse de l'arrêt (Ctrl+C)
let isShuttingDown = false;

const gracefulShutdown = (signal) => {
	if (isShuttingDown) {
		console.log(`[server] ⚠️ Arrêt forcé (${signal})`);
		process.exit(1);
		return;
	}
	
	isShuttingDown = true;
	console.log(`\n[server] 📴 Signal ${signal} reçu, arrêt gracieux en cours...`);
	
	// Fermer le serveur HTTP
	server.close(() => {
		console.log('[server] ✅ Serveur HTTP fermé');
		
		// Fermer Socket.IO
		io.close(() => {
			console.log('[server] ✅ Socket.IO fermé');
			
			// Sauvegarder les données avant de quitter
			fileManager.savePersistedData().then(() => {
				console.log('[server] ✅ Données sauvegardées');
				console.log('[server] 👋 Arrêt complet');
				process.exit(0);
			}).catch((err) => {
				console.error('[server] ❌ Erreur lors de la sauvegarde:', err);
				process.exit(1);
			});
		});
	});
	
	// Forcer l'arrêt après 10 secondes si nécessaire
	setTimeout(() => {
		console.log('[server] ⚠️ Arrêt forcé après timeout');
		process.exit(1);
	}, 10000);
};

// Gérer les signaux d'arrêt
process.on('SIGINT', () => gracefulShutdown('SIGINT')); // Ctrl+C
process.on('SIGTERM', () => gracefulShutdown('SIGTERM')); // Arrêt système

// Gérer les erreurs non capturées
process.on('uncaughtException', (err) => {
	console.error('[server] ❌ Erreur non capturée:', err);
	gracefulShutdown('uncaughtException');
});

process.on('unhandledRejection', (reason, promise) => {
	console.error('[server] ❌ Promesse rejetée non gérée:', reason);
	gracefulShutdown('unhandledRejection');
});
