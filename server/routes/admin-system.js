// 🧹 Routes Admin - Système & Reset
// Gestion du nettoyage, reset système, cleanup et crédit

const express = require('express');
const router = express.Router();
const fs = require('fs');
const fsp = require('fs').promises;
const path = require('path');
const { exec } = require('child_process');
const { authAdmin } = require('../middleware/auth');
const dataStore = require('../data');
const fileManager = require('../utils/fileManager');
const { getIO } = require('../utils/socket');
const dbManager = require('../utils/dbManager'); // 🆕 Pour nettoyer MongoDB Cloud

// Variables depuis data.js
const orders = dataStore.orders;
const archivedOrders = dataStore.archivedOrders;
const bills = dataStore.bills;
const archivedBills = dataStore.archivedBills;
const serviceRequests = dataStore.serviceRequests;
const ORDERS_FILE = dataStore.ORDERS_FILE;
const ARCHIVED_ORDERS_FILE = dataStore.ARCHIVED_ORDERS_FILE;
const BILLS_FILE = dataStore.BILLS_FILE;
const ARCHIVED_BILLS_FILE = dataStore.ARCHIVED_BILLS_FILE;
const SERVICES_FILE = dataStore.SERVICES_FILE;
const COUNTERS_FILE = dataStore.COUNTERS_FILE;
const CLIENT_CREDITS_FILE = dataStore.CLIENT_CREDITS_FILE;

// Nettoyer les doublons de sous-notes
router.post('/cleanup-duplicate-notes', authAdmin, (req, res) => {
	try {
		const { table } = req.body || {};
		if (!table) return res.status(400).json({ error: 'Table requise' });
		
		const tableOrders = orders.filter(o => String(o.table) === String(table));
		let cleanedCount = 0;
		
		for (const order of tableOrders) {
			if (order.subNotes && Array.isArray(order.subNotes)) {
				// Créer une map pour éviter les doublons par ID
				const uniqueSubNotes = new Map();
				
				for (const subNote of order.subNotes) {
					if (!uniqueSubNotes.has(subNote.id)) {
						uniqueSubNotes.set(subNote.id, subNote);
					} else {
						// Fusionner les items des doublons
						const existing = uniqueSubNotes.get(subNote.id);
						existing.items = existing.items.concat(subNote.items || []);
						existing.total = (existing.total || 0) + (subNote.total || 0);
						cleanedCount++;
					}
				}
				
				// Remplacer par les sous-notes uniques
				order.subNotes = Array.from(uniqueSubNotes.values());
			}
		}
		
		console.log(`[admin] Nettoyage doublons table ${table}: ${cleanedCount} doublons supprimés`);
		fileManager.savePersistedData().catch(e => console.error('[admin] Erreur sauvegarde:', e));
		
		return res.json({ 
			ok: true, 
			message: `Nettoyage terminé pour table ${table}`,
			duplicatesRemoved: cleanedCount
		});
	} catch (e) {
		console.error('[admin] cleanup duplicate notes error', e);
		return res.status(500).json({ error: 'Erreur nettoyage doublons' });
	}
});

// Archiver la consommation d'une table
router.post('/clear-table-consumption', authAdmin, (req, res) => {
	try {
		const { table } = req.body || {};
		if (!table) return res.status(400).json({ error: 'Table requise' });
		
		// Compter les éléments avant archivage
		const ordersBefore = dataStore.orders.length;
		const billsBefore = dataStore.bills.length;
		const servicesBefore = dataStore.serviceRequests.length;
		
		// Archiver les commandes et factures au lieu de les supprimer
		const tableOrders = dataStore.orders.filter(o => String(o.table) === String(table));
		const tableBills = dataStore.bills.filter(b => String(b.table) === String(table));
		
		// 🆕 Enregistrer la fermeture de la table dans l'historique de chaque commande
		const closeTimestamp = new Date().toISOString();
		tableOrders.forEach(o => {
			o.status = 'archived';
			o.archivedAt = closeTimestamp;
			
			// 🆕 Ajouter l'événement de fermeture de table dans orderHistory
			if (!o.orderHistory) {
				o.orderHistory = [];
			}
			o.orderHistory.push({
				timestamp: closeTimestamp,
				action: 'table_closed',
				noteId: 'main',
				noteName: 'Note Principale',
				items: [],
				details: `Table ${table} fermée et archivée`
			});
		});
		tableBills.forEach(b => {
			b.status = 'archived';
			b.archivedAt = new Date().toISOString();
		});
		
		// Déplacer vers les archives
		dataStore.archivedOrders.push(...tableOrders);
		dataStore.archivedBills.push(...tableBills);
		
		// Retirer des listes actives
		dataStore.orders = dataStore.orders.filter(o => String(o.table) !== String(table));
		dataStore.bills = dataStore.bills.filter(b => String(b.table) !== String(table));
		dataStore.serviceRequests = dataStore.serviceRequests.filter(s => String(s.table) !== String(table));
		
		const ordersArchived = ordersBefore - dataStore.orders.length;
		const billsArchived = billsBefore - dataStore.bills.length;
		const servicesRemoved = servicesBefore - dataStore.serviceRequests.length;
		
		console.log(`[admin] archived consumption for table ${table}: ${ordersArchived} orders, ${billsArchived} bills, ${servicesRemoved} services`);
		console.log(`[admin] total archived: ${dataStore.archivedOrders.length} orders, ${dataStore.archivedBills.length} bills`);
		
		// 💾 Sauvegarder l'archivage
		fileManager.savePersistedData().catch(e => console.error('[admin] Erreur sauvegarde:', e));
		
		// ✅ Émettre événement Socket.IO
		const io = getIO();
		io.emit('table:cleared', { table, ordersArchived, billsArchived, servicesRemoved });
		
		return res.json({ 
			ok: true, 
			message: `Consommation table ${table} archivée`,
			archived: { orders: ordersArchived, bills: billsArchived, services: servicesRemoved },
			totalArchived: { orders: archivedOrders.length, bills: archivedBills.length }
		});
	} catch (e) {
		console.error('[admin] archive table consumption error', e);
		return res.status(500).json({ error: 'Erreur archivage table' });
	}
});

// Reset complet du système (suppression fichiers)
router.post('/full-reset', authAdmin, async (req, res) => {
	try {
		console.log('[admin] 🧹 Demande de nettoyage complet du système');
		
		// 🆕 CORRECTION : Nettoyer aussi MongoDB si connecté (même en mode hybride)
		// Si MongoDB est connecté, il faut le nettoyer même si isCloud est false
		// car le serveur peut charger depuis MongoDB au démarrage
		let cloudDeleted = { orders: 0, archivedOrders: 0, bills: 0, archivedBills: 0, services: 0, clientCredits: 0 };
		
		if (dbManager.db) { // 🆕 Nettoyer MongoDB si connecté, peu importe isCloud
			console.log('[admin] ☁️ Nettoyage MongoDB Cloud...');
			try {
				// Supprimer toutes les commandes (POS + Client)
				const ordersResult = await dbManager.orders.deleteMany({});
				cloudDeleted.orders = ordersResult.deletedCount || 0;
				console.log(`[admin] ☁️ ${cloudDeleted.orders} commandes supprimées de MongoDB`);
				
				// Supprimer les commandes archivées
				const archivedOrdersResult = await dbManager.archivedOrders.deleteMany({});
				cloudDeleted.archivedOrders = archivedOrdersResult.deletedCount || 0;
				console.log(`[admin] ☁️ ${cloudDeleted.archivedOrders} commandes archivées supprimées de MongoDB`);
				
				// Supprimer les factures
				const billsResult = await dbManager.bills.deleteMany({});
				cloudDeleted.bills = billsResult.deletedCount || 0;
				console.log(`[admin] ☁️ ${cloudDeleted.bills} factures supprimées de MongoDB`);
				
				// Supprimer les factures archivées
				const archivedBillsResult = await dbManager.archivedBills.deleteMany({});
				cloudDeleted.archivedBills = archivedBillsResult.deletedCount || 0;
				console.log(`[admin] ☁️ ${cloudDeleted.archivedBills} factures archivées supprimées de MongoDB`);
				
				// Supprimer les services
				const servicesResult = await dbManager.services.deleteMany({});
				cloudDeleted.services = servicesResult.deletedCount || 0;
				console.log(`[admin] ☁️ ${cloudDeleted.services} services supprimés de MongoDB`);
				
				// Supprimer les crédits clients
				const creditsResult = await dbManager.clientCredits.deleteMany({});
				cloudDeleted.clientCredits = creditsResult.deletedCount || 0;
				console.log(`[admin] ☁️ ${cloudDeleted.clientCredits} crédits clients supprimés de MongoDB`);
				
				// Réinitialiser les compteurs dans MongoDB
				await dbManager.counters.updateOne(
					{ type: 'global' },
					{ 
						$set: { 
							nextOrderId: 1,
							nextBillId: 1,
							nextServiceId: 1,
							nextClientId: 1,
							lastSynced: new Date().toISOString()
						} 
					},
					{ upsert: true }
				);
				console.log('[admin] ☁️ Compteurs MongoDB réinitialisés');
			} catch (cloudError) {
				console.error('[admin] ⚠️ Erreur nettoyage MongoDB Cloud:', cloudError.message);
				// Continuer même en cas d'erreur cloud
			}
		}
		
		// Supprimer les fichiers de persistance locale
		const filesToDelete = [
			ORDERS_FILE,
			ARCHIVED_ORDERS_FILE,
			BILLS_FILE,
			ARCHIVED_BILLS_FILE,
			SERVICES_FILE,
			COUNTERS_FILE,
			CLIENT_CREDITS_FILE
		];
		
		let deletedFiles = 0;
		filesToDelete.forEach(filePath => {
			try {
				if (fs.existsSync(filePath)) {
					fs.unlinkSync(filePath);
					deletedFiles++;
					console.log(`[admin] 🏠 Fichier local supprimé: ${filePath}`);
				}
			} catch (e) {
				console.error(`[admin] Erreur suppression ${filePath}:`, e.message);
			}
		});
		
		// Réinitialiser les tableaux en mémoire
		dataStore.orders = [];
		dataStore.archivedOrders = [];
		dataStore.bills = [];
		dataStore.archivedBills = [];
		dataStore.serviceRequests = [];
		dataStore.clientCredits = [];
		
		// Réinitialiser les compteurs
		dataStore.nextOrderId = 1;
		dataStore.nextBillId = 1;
		dataStore.nextServiceId = 1;
		dataStore.nextClientId = 1;
		
		// ✅ Émettre événement Socket.IO
		const io = getIO();
		io.emit('system:reset', { 
			message: 'Système réinitialisé complètement (local + cloud)',
			timestamp: new Date().toISOString()
		});
		
		console.log(`[admin] 🧹 Nettoyage complet terminé: ${dataStore.orders.length} commandes locales, ${cloudDeleted.orders} commandes cloud supprimées`);
		
		return res.json({ 
			ok: true, 
			message: 'Nettoyage complet terminé avec succès (local + cloud)',
			deleted: {
				local: {
					orders: 0,
					archivedOrders: 0,
					bills: 0,
					archivedBills: 0,
					services: 0,
					files: deletedFiles
				},
				cloud: cloudDeleted // 🆕 Inclure les données supprimées du cloud
			},
			reset: { 
				orders: 0, 
				bills: 0, 
				services: 0, 
				counters: { nextOrderId: 1, nextBillId: 1, nextServiceId: 1 } 
			}
		});
	} catch (e) {
		console.error('[admin] Erreur nettoyage complet:', e);
		return res.status(500).json({ error: 'Erreur lors du nettoyage complet: ' + e.message });
	}
});

// Reset système (vider mémoire uniquement)
router.post('/reset-system', authAdmin, async (req, res) => {
	try {
		console.log('[admin] Remise à zéro du système demandée');
		
		// Vider toutes les données via dataStore
		dataStore.orders.length = 0;
		dataStore.bills.length = 0;
		dataStore.serviceRequests.length = 0;
		dataStore.archivedOrders.length = 0; // 🆕 Historique vidé
		dataStore.archivedBills.length = 0; // 🆕 Historique factures vidé
		dataStore.clientCredits.length = 0;
		
		// Remettre les compteurs à zéro
		dataStore.nextOrderId = 1;
		dataStore.nextBillId = 1;
		dataStore.nextClientId = 1;
		
		// Nettoyer les fichiers de données persistantes
		try {
			const dataDir = path.join(__dirname, '..', '..', 'data', 'pos');
			const files = ['orders.json', 'bills.json', 'serviceRequests.json', 'archivedOrders.json', 'archivedBills.json', 'client_credits.json'];
			
			for (const file of files) {
				const filePath = path.join(dataDir, file);
				if (fs.existsSync(filePath)) {
					fs.unlinkSync(filePath);
					console.log(`[admin] Fichier supprimé: ${file}`);
				}
			}
		} catch (fileError) {
			console.warn('[admin] Erreur lors de la suppression des fichiers:', fileError);
		}
		
		// 💾 Sauvegarder pour garantir que les données vidées sont persistées
		await fileManager.savePersistedData();
		
		// ✅ Émettre événement Socket.IO
		const io = getIO();
		io.emit('system:reset', { 
			message: 'Système remis à zéro',
			timestamp: new Date().toISOString()
		});
		
		console.log('[admin] Système remis à zéro avec succès (historique inclus)');
		
		return res.json({
			ok: true,
			message: 'Système remis à zéro avec succès (historique inclus)',
			reset: {
				orders: 0,
				bills: 0,
				serviceRequests: 0,
				archivedOrders: 0, // Historique vidé
				archivedBills: 0, // Historique factures vidé
				nextOrderId: 1,
				nextBillId: 1
			}
		});
		
	} catch (e) {
		console.error('[admin] Erreur remise à zéro:', e);
		return res.status(500).json({ error: 'Erreur lors de la remise à zéro' });
	}
});

// Reset crédit clients
router.post('/credit/reset', authAdmin, (req, res) => {
	try {
		const { clearClients = false } = req.body || {};
		if (clearClients) {
			dataStore.clientCredits = [];
			dataStore.nextClientId = 1;
			console.log('[credit] Tous les clients et dettes ont été supprimés');
			return res.json({ ok: true, clients: 0, clearedClients: true });
		}
		// Effacer uniquement les dettes (transactions) et conserver les clients
		dataStore.clientCredits.forEach(c => c.transactions = []);
		console.log(`[credit] Dettes réinitialisées pour ${dataStore.clientCredits.length} client(s)`);
		return res.json({ ok: true, clients: dataStore.clientCredits.length, clearedClients: false });
	} catch (e) {
		console.error('[credit] reset error', e);
		return res.status(500).json({ error: 'Erreur reset crédit' });
	}
});

// 🆕 Redémarrer les services (serveur Node.js + POS Flutter)
router.post('/restart-services', authAdmin, (req, res) => {
	try {
		console.log('[admin] 🔄 Demande de redémarrage des services');
		
		// Trouver le chemin du script restart-services.bat (à la racine du projet)
		const projectRoot = path.join(__dirname, '..', '..');
		const restartScript = path.join(projectRoot, 'restart-services.bat');
		
		// Vérifier que le script existe
		if (!fs.existsSync(restartScript)) {
			console.error('[admin] Script restart-services.bat introuvable:', restartScript);
			return res.status(500).json({ error: 'Script de redémarrage introuvable' });
		}
		
		// 🆕 CRITIQUE : Utiliser spawn avec detached pour que le script survive à la fermeture du serveur Node.js
		// Le script batch va tuer le serveur Node.js, donc il doit être détaché pour continuer à s'exécuter
		const { spawn } = require('child_process');
		
		// 🆕 CORRECTION : Construire la commande complète comme une chaîne unique
		// Convertir le chemin en format Windows avec des backslashes
		const restartScriptNormalized = restartScript.replace(/\//g, '\\');
		
		// Construire la commande complète pour éviter les problèmes de parsing des guillemets
		const command = `start "Redémarrage Services" cmd /k "${restartScriptNormalized}"`;
		
		console.log('[admin] Commande de redémarrage:', command);
		console.log('[admin] Chemin du script:', restartScriptNormalized);
		
		// Lancer le script dans une nouvelle fenêtre cmd détachée
		const batProcess = spawn('cmd.exe', ['/c', command], {
			cwd: projectRoot,
			detached: true,
			stdio: 'ignore',
			windowsHide: false,
			shell: true // 🆕 Utiliser shell pour gérer correctement les chemins Windows
		});
		
		// Détacher complètement le processus pour qu'il survive à la fermeture du parent
		batProcess.unref();
		
		// Répondre immédiatement (le redémarrage se fait en arrière-plan)
		return res.json({
			ok: true,
			message: 'Redémarrage des services lancé. Les fenêtres vont se fermer et se rouvrir automatiquement.',
			note: 'Le serveur va redémarrer dans quelques secondes. Rafraîchissez la page après le redémarrage.'
		});
		
		// Ancien code avec exec (ne fonctionne pas car le processus parent est tué)
		/*
		const command = `start "Redémarrage Services" cmd /k "${restartScript}"`;
		
		exec(command, { cwd: projectRoot, windowsHide: false }, (error, stdout, stderr) => {
			if (error) {
				console.error('[admin] Erreur lors du redémarrage:', error);
				return res.status(500).json({ error: 'Erreur lors du redémarrage: ' + error.message });
			}
			
			console.log('[admin] ✅ Redémarrage des services lancé');
			console.log('[admin] stdout:', stdout);
			if (stderr) console.log('[admin] stderr:', stderr);
			
			// Répondre immédiatement (le redémarrage se fait en arrière-plan)
			return res.json({
				ok: true,
				message: 'Redémarrage des services lancé. Les fenêtres vont se fermer et se rouvrir automatiquement.',
				note: 'Le serveur va redémarrer dans quelques secondes. Rafraîchissez la page après le redémarrage.'
			});
		});
		*/
		
	} catch (e) {
		console.error('[admin] Erreur redémarrage services:', e);
		return res.status(500).json({ error: 'Erreur lors du redémarrage: ' + e.message });
	}
});

module.exports = router;

