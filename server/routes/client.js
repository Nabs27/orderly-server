// 📱 Routes pour l'application client
// Menu, commandes publiques, factures client

const express = require('express');
const router = express.Router();
const fs = require('fs');
const fsp = fs.promises;
const path = require('path');
const { filterAvailableItems, augmentWithOriginal, getTranslatedMenuWithCache } = require('../utils/translation');

// Charger le menu (avec traduction/caching si ?lng=de|en|ar)
router.get('/menu/:restaurantId', async (req, res) => {
	try {
		const restaurantId = req.params.restaurantId;
		const lng = String(req.query.lng || 'fr').toLowerCase();
		console.log(`[menu] restaurantId=${restaurantId} lng=${lng}`);
		const forceRefresh = String(req.query.refresh || '0') === '1';
		const menuPath = path.join(__dirname, '..', '..', 'data', 'restaurants', restaurantId, 'menu.json');
		const src = await fsp.readFile(menuPath, 'utf8').catch(() => null);
		if (!src) return res.status(404).json({ error: 'Menu introuvable' });
		const stat = await fsp.stat(menuPath);
		const sourceMTime = stat.mtimeMs;
		const menu = JSON.parse(src);
		if (lng === 'fr') {
			console.log('[menu] lng=fr, return source menu without translation');
			return res.json(filterAvailableItems(augmentWithOriginal(menu)));
		}
		
		const translated = await getTranslatedMenuWithCache(menu, restaurantId, lng, sourceMTime, forceRefresh);
		console.log('[menu] translated menu served');
		return res.json(filterAvailableItems(translated));
	} catch (e) {
		console.error('menu translate error', e);
		return res.status(500).json({ error: 'Erreur chargement menu' });
	}
});

module.exports = router;

