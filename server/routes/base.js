// 🏠 Routes de base
// Routes simples pour santé de l'API et redirections

const express = require('express');
const router = express.Router();
const dataStore = require('../data');
const fileManager = require('../utils/fileManager');

// Racine: simple ping texte pour API
router.get('/', (req, res) => res.send('API OK'));

// Healthcheck simple
router.get('/health', (req, res) => res.send('ok'));

// Route courte QR → client avec table préremplie
router.get('/t/:table', (req, res) => {
	const t = encodeURIComponent(req.params.table);
	const r = req.query.r ? `&r=${encodeURIComponent(req.query.r)}` : '';
	res.redirect(`/client/?table=${t}${r}`);
});

// QR avec restaurant explicite
router.get('/r/:restaurantId/t/:table', (req, res) => {
	const t = encodeURIComponent(req.params.table);
	const r = encodeURIComponent(req.params.restaurantId);
	res.redirect(`/client/?table=${t}&r=${r}`);
});

// Route de reset pour développement
router.post('/dev/reset', async (req, res) => {
	try {
		// Réinitialiser toutes les données
		dataStore.orders = [];
		dataStore.archivedOrders = [];
		dataStore.bills = [];
		dataStore.archivedBills = [];
		dataStore.serviceRequests = [];
		dataStore.nextOrderId = 1;
		dataStore.nextBillId = 1;
		dataStore.nextServiceId = 1;
		
		// Sauvegarder
		await fileManager.savePersistedData();
		
		console.log('[dev] Reset effectué');
		res.json({ ok: true, message: 'Reset effectué' });
	} catch (e) {
		console.error('[dev] Erreur reset:', e);
		res.status(500).json({ error: 'Erreur reset' });
	}
});

module.exports = router;

