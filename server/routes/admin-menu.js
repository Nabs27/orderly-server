// 📝 Routes Admin - Gestion Menu (CRUD)
// Gère toutes les opérations sur les menus (GET, PATCH, POST categories/items, DELETE)

const express = require('express');
const router = express.Router();
const fsp = require('fs').promises;
const path = require('path');
const { authAdmin } = require('../middleware/auth');

// Fonction utilitaire pour vider le cache des traductions
async function clearTranslationsCache(restaurantId) {
	try {
		const translationsDir = path.join(__dirname, '..', '..', 'data', 'translations');
		const files = await fsp.readdir(translationsDir).catch(() => []);
		for (const f of files) {
			if (f.startsWith(`${restaurantId}_`)) {
				await fsp.unlink(path.join(translationsDir, f)).catch(() => {});
			}
		}
		console.log(`[admin] cleared translations cache for ${restaurantId}`);
	} catch {}
}

// Récupérer un menu
router.get('/menu/:restaurantId', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const menuPath = path.join(__dirname, '..', '..', 'data', 'restaurants', restaurantId, 'menu.json');
		const content = await fsp.readFile(menuPath, 'utf8').catch(() => null);
		if (!content) return res.status(404).json({ error: 'Menu introuvable' });
		const menu = JSON.parse(content);
		return res.json(menu);
	} catch (e) {
		console.error('[admin] get menu error', e);
		return res.status(500).json({ error: 'Erreur chargement menu' });
	}
});

// Modifier un menu complet
router.patch('/menu/:restaurantId', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const { menu } = req.body || {};
		if (!menu) return res.status(400).json({ error: 'Menu requis' });
		const menuPath = path.join(__dirname, '..', '..', 'data', 'restaurants', restaurantId, 'menu.json');
		await fsp.writeFile(menuPath, JSON.stringify(menu, null, 2), 'utf8');
		console.log(`[admin] updated menu for ${restaurantId}`);
		// Vider les traductions en cache pour forcer une retraduction
		await clearTranslationsCache(restaurantId);
		return res.json({ ok: true });
	} catch (e) {
		console.error('[admin] update menu error', e);
		return res.status(500).json({ error: 'Erreur sauvegarde menu' });
	}
});

// Ajouter une catégorie
router.post('/menu/:restaurantId/categories', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const { name, group } = req.body || {};
		if (!name) return res.status(400).json({ error: 'Nom requis' });
		const menuPath = path.join(__dirname, '..', '..', 'data', 'restaurants', restaurantId, 'menu.json');
		const content = await fsp.readFile(menuPath, 'utf8');
		const menu = JSON.parse(content);
		const exists = (menu.categories || []).find(c => c.name === name);
		if (exists) return res.status(409).json({ error: 'Catégorie déjà existante' });
		menu.categories = menu.categories || [];
		menu.categories.push({ name, group: group || 'food', items: [] });
		await fsp.writeFile(menuPath, JSON.stringify(menu, null, 2), 'utf8');
		await clearTranslationsCache(restaurantId);
		return res.status(201).json({ ok: true });
	} catch (e) {
		console.error('[admin] add category error', e);
		return res.status(500).json({ error: 'Erreur ajout catégorie' });
	}
});

// Supprimer une catégorie
router.delete('/menu/:restaurantId/categories/:categoryName', authAdmin, async (req, res) => {
	try {
		const { restaurantId, categoryName } = req.params;
		const menuPath = path.join(__dirname, '..', '..', 'data', 'restaurants', restaurantId, 'menu.json');
		const content = await fsp.readFile(menuPath, 'utf8');
		const menu = JSON.parse(content);
		menu.categories = (menu.categories || []).filter(c => c.name !== decodeURIComponent(categoryName));
		await fsp.writeFile(menuPath, JSON.stringify(menu, null, 2), 'utf8');
		await clearTranslationsCache(restaurantId);
		return res.json({ ok: true });
	} catch (e) {
		console.error('[admin] delete category error', e);
		return res.status(500).json({ error: 'Erreur suppression catégorie' });
	}
});

// Ajouter un item
router.post('/menu/:restaurantId/items', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const { categoryName, name, price, type } = req.body || {};
		if (!categoryName || !name || price == null) {
			return res.status(400).json({ error: 'Catégorie, nom et prix requis' });
		}
		const menuPath = path.join(__dirname, '..', '..', 'data', 'restaurants', restaurantId, 'menu.json');
		const content = await fsp.readFile(menuPath, 'utf8');
		const menu = JSON.parse(content);
		const cat = (menu.categories || []).find(c => c.name === categoryName);
		if (!cat) return res.status(404).json({ error: 'Catégorie introuvable' });
		// Générer un ID unique (max ID + 1)
		const allIds = (menu.categories || []).flatMap(c => (c.items || []).map(i => i.id || 0));
		const maxId = allIds.length > 0 ? Math.max(...allIds) : 1000;
		const newId = maxId + 1;
		cat.items = cat.items || [];
		cat.items.push({
			id: newId,
			name,
			price: Number(price),
			type: type || cat.name,
			available: true // Par défaut disponible
		});
		await fsp.writeFile(menuPath, JSON.stringify(menu, null, 2), 'utf8');
		await clearTranslationsCache(restaurantId);
		return res.status(201).json({ ok: true, id: newId });
	} catch (e) {
		console.error('[admin] add item error', e);
		return res.status(500).json({ error: 'Erreur ajout article' });
	}
});

// Modifier un item
router.patch('/menu/:restaurantId/items/:itemId', authAdmin, async (req, res) => {
	try {
		const { restaurantId, itemId } = req.params;
		const updates = req.body || {};
		const menuPath = path.join(__dirname, '..', '..', 'data', 'restaurants', restaurantId, 'menu.json');
		const content = await fsp.readFile(menuPath, 'utf8');
		const menu = JSON.parse(content);
		let found = false;
		for (const cat of (menu.categories || [])) {
			const item = (cat.items || []).find(i => String(i.id) === String(itemId));
			if (item) {
				if (updates.name != null) item.name = updates.name;
				if (updates.price != null) item.price = Number(updates.price);
				if (updates.type != null) item.type = updates.type;
				if (updates.available != null) item.available = Boolean(updates.available);
				if (updates.hidden != null) item.hidden = Boolean(updates.hidden);
				found = true;
				break;
			}
		}
		if (!found) return res.status(404).json({ error: 'Article introuvable' });
		await fsp.writeFile(menuPath, JSON.stringify(menu, null, 2), 'utf8');
		await clearTranslationsCache(restaurantId);
		
		console.log(`[menu] item ${itemId} updated`);
		
		return res.json({ ok: true });
	} catch (e) {
		console.error('[admin] update item error', e);
		return res.status(500).json({ error: 'Erreur modification article' });
	}
});

// Supprimer un item
router.delete('/menu/:restaurantId/items/:itemId', authAdmin, async (req, res) => {
	try {
		const { restaurantId, itemId } = req.params;
		const menuPath = path.join(__dirname, '..', '..', 'data', 'restaurants', restaurantId, 'menu.json');
		const content = await fsp.readFile(menuPath, 'utf8');
		const menu = JSON.parse(content);
		for (const cat of (menu.categories || [])) {
			cat.items = (cat.items || []).filter(i => String(i.id) !== String(itemId));
		}
		await fsp.writeFile(menuPath, JSON.stringify(menu, null, 2), 'utf8');
		await clearTranslationsCache(restaurantId);
		return res.json({ ok: true });
	} catch (e) {
		console.error('[admin] delete item error', e);
		return res.status(500).json({ error: 'Erreur suppression article' });
	}
});

module.exports = router;

