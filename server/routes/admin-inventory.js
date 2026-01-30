// 📦 Routes Admin - Inventaire (stock) par restaurant
// GET inventory, PATCH item stock, POST init depuis menu (tous groupes boissons)
// Aligné sur admin-menu.js et plan stock (STRUCTURE_POS, .cursorrules)

const express = require('express');
const router = express.Router();
const { authAdmin } = require('../middleware/auth');
const {
	loadInventory,
	loadInventoryHistory,
	initInventoryFromMenu,
	enrichInventoryWithMenu,
	buildMenuDrinkCategories,
	adjustStock,
	setAllStocks,
} = require('../utils/inventorySync');
const { loadMenu } = require('../utils/menuSync');
const socketManager = require('../utils/socket');

// Récupérer l'inventaire + structure menu boissons (pour navigation comme éditeur de menu)
router.get('/inventory/:restaurantId', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const inv = await loadInventory(restaurantId);
		if (!inv) {
			return res.status(404).json({
				error: 'Inventaire introuvable',
				hint: 'Exécutez POST /api/admin/inventory/:restaurantId/init pour initialiser depuis le menu (boissons).',
			});
		}
		const menu = await loadMenu(restaurantId);
		const enriched = enrichInventoryWithMenu(inv, menu);
		const menuDrinkCategories = buildMenuDrinkCategories(menu);
		return res.json({ ...enriched, menuDrinkCategories });
	} catch (e) {
		console.error('[admin-inventory] GET error', e);
		return res.status(500).json({ error: 'Erreur chargement inventaire' });
	}
});

// Initialiser l'inventaire depuis le menu (tous groupes boissons : drinks, spirits, alcohol, beers, wines)
router.post('/inventory/:restaurantId/init', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const overwrite = req.body?.overwrite === true;
		const { created, items } = await initInventoryFromMenu(restaurantId, { overwrite });
		const io = socketManager.getIO();
		if (io) {
			io.emit('inventory:updated', { restaurantId, timestamp: new Date().toISOString() });
		}
		return res.status(201).json({ ok: true, created, count: items.length });
	} catch (e) {
		console.error('[admin-inventory] POST init error', e);
		return res.status(500).json({ error: e.message || 'Erreur initialisation inventaire' });
	}
});

// Ajuster le stock d'un article (delta ou currentStock)
// Body: { delta?: number } ou { currentStock?: number }, optionnel: { stockThreshold?, unit?, userId? }
router.patch('/inventory/:restaurantId/items/:itemId', authAdmin, async (req, res) => {
	try {
		const { restaurantId, itemId } = req.params;
		const { delta, currentStock, stockThreshold, unit, userId } = req.body || {};
		if (delta == null && currentStock == null) {
			return res.status(400).json({ error: 'Indiquez delta ou currentStock' });
		}
		const { item } = await adjustStock(
			restaurantId,
			itemId,
			{ delta, currentStock, stockThreshold, unit },
			{ userId, type: 'manual' }
		);
		const io = socketManager.getIO();
		if (io) {
			io.emit('inventory:updated', {
				restaurantId,
				itemId: Number(itemId),
				currentStock: item.currentStock,
				timestamp: new Date().toISOString(),
			});
		}
		return res.json({ ok: true, item });
	} catch (e) {
		console.error('[admin-inventory] PATCH error', e);
		return res.status(400).json({ error: e.message || 'Erreur mise à jour stock' });
	}
});

// Mettre tous les stocks à une valeur (test / remplissage rapide)
router.post('/inventory/:restaurantId/set-all-stock', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const value = req.body?.value != null ? Number(req.body.value) : null;
		if (value == null || value < 0) {
			return res.status(400).json({ error: 'Indiquez value (nombre >= 0)' });
		}
		const { count } = await setAllStocks(restaurantId, value);
		const io = socketManager.getIO();
		if (io) io.emit('inventory:updated', { restaurantId, timestamp: new Date().toISOString() });
		return res.json({ ok: true, count });
	} catch (e) {
		console.error('[admin-inventory] POST set-all-stock error', e);
		return res.status(500).json({ error: e.message || 'Erreur' });
	}
});

// Historique des mouvements (optionnel, pour écran traçabilité)
router.get('/inventory/:restaurantId/history', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const history = await loadInventoryHistory(restaurantId);
		return res.json(history);
	} catch (e) {
		console.error('[admin-inventory] GET history error', e);
		return res.status(500).json({ error: 'Erreur chargement historique' });
	}
});

module.exports = router;
