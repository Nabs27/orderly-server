// 👨‍💼 Routes POS
// Routes spécifiques au POS (transferts, crédit, archives)

const express = require('express');
const router = express.Router();
const posController = require('../controllers/pos');
const posHistoryUnified = require('../controllers/pos-history-unified');

// ⚠️ Note: Plus besoin de middleware ! Les controllers utilisent getIO() directement
function setIO(io) {
	// Ne fait rien, mais gardée pour compatibilité
}

// ✅ Routes API (avec /api)
router.post('/api/pos/transfer-items', posController.transferItems);
router.delete('/api/pos/orders/:orderId/notes/:noteId/items', posController.deleteNoteItems);
router.post('/api/pos/pay-multi-orders', posController.payMultiOrders); // 🆕 Paiement multi-commandes
router.get('/api/pos/archived-notes', posController.getArchivedNotes);
router.get('/api/pos/archived-orders', posController.getArchivedOrdersByServer); // Historique serveur (archivées uniquement)
router.get('/api/pos/history-unified', posHistoryUnified.getUnifiedHistoryByServer); // 🆕 Historique unifié (archivées + actives)
router.post('/api/pos/transfer-complete-table', posController.transferCompleteTable);
router.post('/api/pos/transfer-server', posController.transferServer);
router.post('/api/pos/orders/:orderId/notes/:noteId/cancel-items', posController.cancelItems); // 🆕 Annulation articles
router.post('/api/pos/orders/:orderId/preadditions', posController.createPreaddition); // 🆕 Créer pré-addition
router.delete('/api/pos/orders/:orderId/preadditions/:preadditionId', posController.deletePreaddition); // 🆕 Supprimer pré-addition
router.put('/api/pos/orders/:orderId/preadditions/:preadditionId', posController.updatePreaddition); // 🆕 Modifier pré-addition

// ✅ Routes compatibilité (sans /api) - À supprimer plus tard
router.post('/pos/transfer-items', posController.transferItems);
router.delete('/pos/orders/:orderId/notes/:noteId/items', posController.deleteNoteItems);
router.post('/pos/pay-multi-orders', posController.payMultiOrders); // 🆕 Paiement multi-commandes
router.get('/pos/archived-notes', posController.getArchivedNotes);
router.get('/pos/archived-orders', posController.getArchivedOrdersByServer); // Historique serveur (archivées uniquement)
router.get('/pos/history-unified', posHistoryUnified.getUnifiedHistoryByServer); // 🆕 Historique unifié (archivées + actives)
router.post('/pos/transfer-complete-table', posController.transferCompleteTable);
router.post('/pos/transfer-server', posController.transferServer);
router.post('/pos/orders/:orderId/notes/:noteId/cancel-items', posController.cancelItems); // 🆕 Annulation articles
router.post('/pos/orders/:orderId/preadditions', posController.createPreaddition); // 🆕 Créer pré-addition
router.delete('/pos/orders/:orderId/preadditions/:preadditionId', posController.deletePreaddition); // 🆕 Supprimer pré-addition
router.put('/pos/orders/:orderId/preadditions/:preadditionId', posController.updatePreaddition); // 🆕 Modifier pré-addition

module.exports = { router, setIO };

