// 📂 Routes Admin - Gestion Restaurants
// CRUD des restaurants (GET, POST)

const express = require('express');
const router = express.Router();
const fsp = require('fs').promises;
const path = require('path');
const { authAdmin } = require('../middleware/auth');
const fileManager = require('../utils/fileManager');

const { ensureDir } = fileManager;

// Liste des restaurants
router.get('/restaurants', authAdmin, async (req, res) => {
	try {
		const restaurantsDir = path.join(__dirname, '..', '..', 'data', 'restaurants');
		await ensureDir(restaurantsDir);
		const dirs = await fsp.readdir(restaurantsDir, { withFileTypes: true });
		const restaurants = [];
		for (const dir of dirs) {
			if (!dir.isDirectory()) continue;
			const menuPath = path.join(restaurantsDir, dir.name, 'menu.json');
			try {
				const content = await fsp.readFile(menuPath, 'utf8');
				const menu = JSON.parse(content);
				// compter masqués/indisponibles
				let hiddenCount = 0, unavailableCount = 0, itemsCount = 0;
				for (const cat of (menu.categories || [])) {
					for (const it of (cat.items || [])) {
						itemsCount++;
						if (it.hidden === true) hiddenCount++;
						if (it.available === false) unavailableCount++;
					}
				}
				restaurants.push({
					id: dir.name,
					name: menu.restaurant?.name || dir.name,
					currency: menu.restaurant?.currency || 'TND',
					categoriesCount: (menu.categories || []).length,
					itemsCount,
					hiddenCount,
					unavailableCount
				});
			} catch (e) {}
		}
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
		const restaurantDir = path.join(__dirname, '..', '..', 'data', 'restaurants', id);
		await ensureDir(restaurantDir);
		const menuPath = path.join(restaurantDir, 'menu.json');
		const exists = await fsp.access(menuPath).then(() => true).catch(() => false);
		if (exists) return res.status(409).json({ error: 'Restaurant déjà existant' });
		const newMenu = {
			restaurant: { id, name, currency: currency || 'TND' },
			categories: []
		};
		await fsp.writeFile(menuPath, JSON.stringify(newMenu, null, 2), 'utf8');
		console.log(`[admin] created restaurant ${id}`);
		return res.status(201).json({ ok: true, id });
	} catch (e) {
		console.error('[admin] create restaurant error', e);
		return res.status(500).json({ error: 'Erreur création restaurant' });
	}
});

module.exports = router;

