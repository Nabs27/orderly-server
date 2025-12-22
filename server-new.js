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
	
	// 🆕 CORRECTION : Synchronisation périodique depuis MongoDB si mode cloud
	// Cela permet au serveur local de voir les commandes créées par le serveur cloud (app client)
	// 🆕 Vérifier si c'est le serveur local (port 3000) et non le cloud (port 8080)
	const isLocalServer = (process.env.PORT || 3000) == 3000;
	if (dbManager.isCloud && dbManager.db && isLocalServer) {
		const SYNC_INTERVAL = 3000; // Synchroniser toutes les 3 secondes
		let lastSyncTime = Date.now();
		
		setInterval(async () => {
			try {
				const syncStartTime = Date.now();
				
				// Recharger les commandes depuis MongoDB
				const cloudOrders = await dbManager.orders.find({}).toArray();
				const cloudArchived = await dbManager.archivedOrders.find({}).toArray();
				
				// 🆕 CORRECTION : Filtrer les commandes confirmées lors de la synchronisation
				// Ne pas inclure les commandes déjà confirmées (status=nouvelle + serverConfirmed=true)
				// car elles ne doivent plus apparaître comme "en attente"
				const activeCloudOrders = cloudOrders.filter(o => {
					const isConfirmed = o.source === 'client' && 
					                   o.status === 'nouvelle' && 
					                   o.serverConfirmed === true;
					return !isConfirmed; // Exclure les commandes confirmées
				});
				
				// Comparer avec les données locales pour détecter les nouvelles commandes
				const localOrderIds = new Set(dataStore.orders.map(o => o.id));
				const newOrders = activeCloudOrders.filter(o => !localOrderIds.has(o.id));
				
				// Mettre à jour les commandes existantes (en cas de modification, sauf si confirmée)
				const updatedOrders = [];
				for (const cloudOrder of activeCloudOrders) {
					const localIndex = dataStore.orders.findIndex(o => o.id === cloudOrder.id);
					if (localIndex !== -1) {
						// Vérifier si la commande locale est confirmée mais pas dans cloud
						const localOrder = dataStore.orders[localIndex];
						const localIsConfirmed = localOrder.source === 'client' && 
						                        localOrder.status === 'nouvelle' && 
						                        localOrder.serverConfirmed === true;
						
						// Ne pas mettre à jour si la commande locale est confirmée
						if (!localIsConfirmed) {
							dataStore.orders[localIndex] = cloudOrder;
							updatedOrders.push(cloudOrder.id);
						}
					}
				}
				
				// Ajouter les nouvelles commandes
				if (newOrders.length > 0) {
					console.log(`[sync] 🔄 ${newOrders.length} nouvelle(s) commande(s) détectée(s) depuis MongoDB`);
					dataStore.orders.push(...newOrders);
					
					// Notifier via Socket.IO les nouvelles commandes
					const { getIO } = require('./server/utils/socket');
					const io = getIO();
					for (const newOrder of newOrders) {
						io.emit('order:new', newOrder);
						console.log(`[sync] 📢 Commande #${newOrder.id} (table ${newOrder.table}) notifiée via Socket.IO`);
					}
				}
				
				// Retirer les commandes confirmées de la liste locale
				// (elles ne doivent plus apparaître comme "en attente")
				const beforeFilter = dataStore.orders.length;
				dataStore.orders = dataStore.orders.filter(o => {
					const isConfirmed = o.source === 'client' && 
					                   o.status === 'nouvelle' && 
					                   o.serverConfirmed === true;
					return !isConfirmed;
				});
				const removedCount = beforeFilter - dataStore.orders.length;
				if (removedCount > 0) {
					console.log(`[sync] 🧹 ${removedCount} commande(s) confirmée(s) retirée(s) de la liste`);
				}
				
				// Mettre à jour les archives
				dataStore.archivedOrders.length = 0;
				dataStore.archivedOrders.push(...cloudArchived);
				
				// Mettre à jour les compteurs
				const countersDoc = await dbManager.counters.findOne({ type: 'global' });
				if (countersDoc) {
					dataStore.nextOrderId = Math.max(dataStore.nextOrderId, countersDoc.nextOrderId || 1);
					dataStore.nextBillId = Math.max(dataStore.nextBillId, countersDoc.nextBillId || 1);
					dataStore.nextServiceId = Math.max(dataStore.nextServiceId, countersDoc.nextServiceId || 1);
					dataStore.nextClientId = Math.max(dataStore.nextClientId, countersDoc.nextClientId || 1);
				}
				
				const syncDuration = Date.now() - syncStartTime;
				if (newOrders.length > 0 || updatedOrders.length > 0 || removedCount > 0) {
					console.log(`[sync] ✅ Synchronisation terminée en ${syncDuration}ms (${newOrders.length} nouvelles, ${updatedOrders.length} mises à jour, ${removedCount} retirées)`);
				}
				lastSyncTime = Date.now();
			} catch (e) {
				console.error('[sync] ⚠️ Erreur synchronisation périodique:', e.message);
				console.error('[sync] Stack:', e.stack);
			}
		}, SYNC_INTERVAL);
		
		console.log(`[server] 🔄 Synchronisation périodique MongoDB activée (toutes les ${SYNC_INTERVAL/1000}s) pour serveur local`);
	} else if (dbManager.isCloud && dbManager.db && !isLocalServer) {
		console.log(`[server] ☁️ Serveur cloud détecté (port ${process.env.PORT || 3000}), synchronisation périodique désactivée`);
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
