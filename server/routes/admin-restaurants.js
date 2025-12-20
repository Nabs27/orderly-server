// 📂 Routes Admin - Gestion Restaurants
// CRUD des restaurants (GET, POST)

const express = require('express');
const router = express.Router();
const fsp = require('fs').promises;
const path = require('path');
const { authAdmin } = require('../middleware/auth');
const fileManager = require('../utils/fileManager');
const { listRestaurants, saveMenu, loadMenu } = require('../utils/menuSync');

const { ensureDir } = fileManager;

// Liste des restaurants
router.get('/restaurants', authAdmin, async (req, res) => {
	try {
		const restaurants = await listRestaurants();
		return res.json(restaurants);
	} catch (e) {
		console.error('[admin] list restaurants error', e);
		return res.status(500).json({ error: 'Erreur serveur' });
	}
});

// Créer un restaurant
router.post('/restaurants', authAdmin, async (req, res) => {
	try {
		const { id, name, currency } = req.body || {};
		if (!id || !name) return res.status(400).json({ error: 'ID et nom requis' });
		// Vérifier si le restaurant existe déjà
		const existing = await loadMenu(id);
		if (existing) return res.status(409).json({ error: 'Restaurant déjà existant' });
		const newMenu = {
			restaurant: { id, name, currency: currency || 'TND' },
			categories: []
		};
		await saveMenu(id, newMenu);
		console.log(`[admin] created restaurant ${id}`);
		return res.status(201).json({ ok: true, id });
	} catch (e) {
		console.error('[admin] create restaurant error', e);
		return res.status(500).json({ error: 'Erreur création restaurant' });
	}
});

module.exports = router;

