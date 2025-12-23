// 🔄 Routes partagées
// Routes utilisées à la fois par client et POS

const express = require('express');
const router = express.Router();
const orderController = require('../controllers/orders');
const billController = require('../controllers/bills');
const creditController = require('../controllers/credit');
const adminServersController = require('../controllers/admin-servers');

// ⚠️ Note: io est maintenant récupéré directement dans les controllers via getIO()
// Plus besoin de middleware complexe !

// Fonction pour compatibilité (ne fait rien, mais gardée pour la compatibilité)
function setIO(io) {
	// Ne fait rien, juste pour éviter les erreurs
}

// ✅ Routes API (avec /api)
// Créer une commande
router.post('/api/orders', orderController.createOrder);

// Lister commandes
router.get('/api/orders', orderController.getAllOrders);

// Récupérer une commande
router.get('/api/orders/:id', orderController.getOrderById);

// Marquer une commande traitée
router.patch('/api/orders/:id', orderController.updateOrder);

// Confirmation de consommation
router.patch('/api/orders/:id/confirm', orderController.confirmOrder);

// 🆕 Confirmation d'une commande client par le serveur
router.patch('/api/orders/:id/confirm-by-server', orderController.confirmOrderByServer);

// 🆕 Décliner une commande client par le serveur
router.patch('/api/orders/:id/decline-by-server', orderController.declineOrderByServer);

// Créer une sous-note
router.post('/api/orders/:id/subnotes', orderController.createSubNote);

// Ajouter des articles à une note spécifique
router.post('/api/orders/:id/notes/:noteId/items', orderController.addItemsToNote);

// Créer une facture
router.post('/api/bills', billController.createBill);

// Lister factures
router.get('/api/bills', billController.getAllBills);

// Récupérer une facture
router.get('/api/bills/:id', billController.getBillById);

// Payer une facture
router.post('/api/bills/:id/pay', billController.payBill);

// Routes crédit client
router.get('/api/credit/clients', creditController.getAllClients);
router.get('/api/credit/clients/:id', creditController.getClientById);
router.post('/api/credit/clients', creditController.createClient);
router.post('/api/credit/clients/:id/transactions', creditController.addTransaction);
router.post('/api/credit/clients/:id/pay-oldest', creditController.payOldestDebt);

// Profils serveurs (accès POS)
router.get('/api/server-profiles', adminServersController.getPublicProfiles);
router.get('/api/server-permissions/:name', adminServersController.getPermissionsForServer);
router.post('/api/server-override', adminServersController.verifyOverride);

// ✅ Routes compatibilité (sans /api) - À supprimer plus tard
router.post('/orders', orderController.createOrder);
router.get('/orders', orderController.getAllOrders);
router.get('/orders/:id', orderController.getOrderById);
router.patch('/orders/:id', orderController.updateOrder);
router.patch('/orders/:id/confirm', orderController.confirmOrder);

// 🆕 Confirmation d'une commande client par le serveur (route compatibilité)
router.patch('/orders/:id/confirm-by-server', orderController.confirmOrderByServer);

// 🆕 Décliner une commande client par le serveur (route compatibilité)
router.patch('/orders/:id/decline-by-server', orderController.declineOrderByServer);

router.post('/orders/:id/subnotes', orderController.createSubNote);

router.post('/orders/:id/notes/:noteId/items', orderController.addItemsToNote);

router.post('/bills', billController.createBill);
router.get('/bills', billController.getAllBills);
router.get('/bills/:id', billController.getBillById);
router.post('/bills/:id/pay', billController.payBill);

router.get('/credit/clients', creditController.getAllClients);
router.get('/credit/clients/:id', creditController.getClientById);
router.post('/credit/clients', creditController.createClient);
router.post('/credit/clients/:id/transactions', creditController.addTransaction);
router.post('/credit/clients/:id/pay-oldest', creditController.payOldestDebt);

module.exports = { router, setIO };

