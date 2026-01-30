// 📦 Gestion de l'inventaire (stock) par restaurant
// Fichiers : data/restaurants/{restaurantId}/inventory.json et inventory_history.json
// Tous les groupes de boissons (drinks, spirits, alcohol, beers, wines, etc.)

const fs = require('fs');
const fsp = require('fs').promises;
const path = require('path');
const dbManager = require('./dbManager');
const { loadMenu } = require('./menuSync');

const RESTAURANTS_DIR = path.join(__dirname, '..', '..', 'data', 'restaurants');

/** Groupes du menu considérés comme boissons (liquides) pour l'inventaire */
const DRINK_GROUPS = ['drinks', 'spirits', 'alcohol', 'beers', 'wines'];

/** Schéma d'un article en inventaire (aligné sur le plan) */
const DEFAULT_STOCK_THRESHOLD = 10;
const DEFAULT_UNIT = 'unit';

/**
 * Charger inventory.json pour un restaurant
 * @param {string} restaurantId
 * @returns {Promise<{ restaurantId: string, items: Array<{ itemId: number, name?: string, currentStock: number, stockThreshold: number, unit: string }>, updatedAt?: string } | null>}
 */
async function loadInventory(restaurantId) {
	const dir = path.join(RESTAURANTS_DIR, restaurantId);
	const filePath = path.join(dir, 'inventory.json');
	if (!fs.existsSync(filePath)) return null;
	try {
		const content = await fsp.readFile(filePath, 'utf8');
		return JSON.parse(content);
	} catch (e) {
		console.error(`[inventory] Erreur lecture ${restaurantId}:`, e.message);
		return null;
	}
}

/**
 * Sauvegarder inventory.json (local + MongoDB si configuré)
 * @param {string} restaurantId
 * @param {object} data - { restaurantId, items, updatedAt }
 */
async function saveInventory(restaurantId, data) {
	const dir = path.join(RESTAURANTS_DIR, restaurantId);
	await fsp.mkdir(dir, { recursive: true });
	data.updatedAt = new Date().toISOString();
	const filePath = path.join(dir, 'inventory.json');
	await fsp.writeFile(filePath, JSON.stringify(data, null, 2), 'utf8');
	console.log(`[inventory] 💾 ${restaurantId} sauvegardé (${data.items?.length ?? 0} articles)`);

	if (dbManager.db && dbManager.inventory) {
		dbManager.inventory.replaceOne(
			{ restaurantId },
			{ restaurantId, ...data },
			{ upsert: true }
		).then(() => console.log(`[inventory] ☁️ ${restaurantId} synchronisé vers MongoDB`))
			.catch(e => console.error(`[inventory] ⚠️ Sync MongoDB:`, e.message));
	}
}

/**
 * Charger inventory_history.json
 * @param {string} restaurantId
 * @returns {Promise<Array<{ type: string, itemId: number, delta: number, userId?: string, timestamp: string }>>}
 */
async function loadInventoryHistory(restaurantId) {
	const dir = path.join(RESTAURANTS_DIR, restaurantId);
	const filePath = path.join(dir, 'inventory_history.json');
	if (!fs.existsSync(filePath)) return [];
	try {
		const content = await fsp.readFile(filePath, 'utf8');
		return JSON.parse(content);
	} catch (e) {
		return [];
	}
}

/**
 * Ajouter une entrée dans l'historique et sauvegarder
 * @param {string} restaurantId
 * @param {{ type: 'sale'|'manual'|'receipt', itemId: number, delta: number, userId?: string }} entry
 */
async function appendInventoryHistory(restaurantId, entry) {
	const history = await loadInventoryHistory(restaurantId);
	history.push({
		...entry,
		timestamp: new Date().toISOString(),
	});
	const dir = path.join(RESTAURANTS_DIR, restaurantId);
	await fsp.mkdir(dir, { recursive: true });
	const filePath = path.join(dir, 'inventory_history.json');
	await fsp.writeFile(filePath, JSON.stringify(history, null, 2), 'utf8');
}

/**
 * Initialiser inventory.json à partir du menu : tous les groupes de boissons (drinks, spirits, alcohol, beers, wines, etc.)
 * Les itemId sont les id numériques du menu (ex. 10000, 10001)
 * @param {string} restaurantId
 * @param {{ overwrite?: boolean }} options - si overwrite false, ne crée que les articles manquants
 * @returns {Promise<{ created: number, items: Array }>}
 */
async function initInventoryFromMenu(restaurantId, options = {}) {
	const { overwrite = false } = options;
	const menu = await loadMenu(restaurantId);
	if (!menu || !Array.isArray(menu.categories)) {
		throw new Error(`Menu introuvable ou vide pour ${restaurantId}`);
	}

	const existing = await loadInventory(restaurantId);
	const existingByItemId = new Map();
	if (existing && Array.isArray(existing.items)) {
		existing.items.forEach(it => existingByItemId.set(Number(it.itemId), it));
	}

	const items = [];
	let created = 0;
	for (const cat of menu.categories) {
		if (!DRINK_GROUPS.includes(cat.group)) continue;
		for (const item of cat.items || []) {
			const itemId = Number(item.id);
			if (!itemId) continue;
			const prev = existingByItemId.get(itemId);
			if (prev && !overwrite) {
				items.push(prev);
				continue;
			}
			items.push({
				itemId,
				name: item.name,
				currentStock: prev ? prev.currentStock : 0,
				stockThreshold: prev ? prev.stockThreshold : DEFAULT_STOCK_THRESHOLD,
				unit: prev ? prev.unit : DEFAULT_UNIT,
			});
			if (!prev) created++;
		}
	}

	const data = {
		restaurantId,
		items,
		updatedAt: new Date().toISOString(),
	};
	await saveInventory(restaurantId, data);
	return { created, items };
}

/**
 * Enrichir l'inventaire avec categoryName, group et type depuis le menu (pour navigation comme éditeur de menu).
 * @param {object} inv - { restaurantId, items, updatedAt }
 * @param {object} menu - menu chargé (categories avec name, group, items)
 * @returns {object} inv avec items enrichis de categoryName, group, type
 */
function enrichInventoryWithMenu(inv, menu) {
	if (!inv || !Array.isArray(inv.items)) return inv;
	const itemIdToMeta = new Map();
	if (menu && Array.isArray(menu.categories)) {
		for (const cat of menu.categories) {
			if (!DRINK_GROUPS.includes(cat.group)) continue;
			const categoryName = cat.name || cat.group || 'Autres';
			const group = cat.group || '';
			for (const item of cat.items || []) {
				const id = Number(item.id);
				if (id) itemIdToMeta.set(id, { categoryName, group, type: item.type || '' });
			}
		}
	}
	inv.items = inv.items.map(it => {
		const id = Number(it.itemId);
		const meta = itemIdToMeta.get(id) || { categoryName: 'Autres', group: '', type: '' };
		return { ...it, categoryName: meta.categoryName, group: meta.group, type: meta.type };
	});
	return inv;
}

/**
 * Construire la liste des catégories "boissons" du menu pour la navigation stock (miroir éditeur de menu).
 * @param {object} menu - menu chargé
 * @returns {Array<{ name: string, group: string, items: Array<{ id: number, name: string, type: string }> }>}
 */
function buildMenuDrinkCategories(menu) {
	if (!menu || !Array.isArray(menu.categories)) return [];
	return menu.categories
		.filter(cat => DRINK_GROUPS.includes(cat.group))
		.map(cat => ({
			name: cat.name || cat.group || '',
			group: cat.group || '',
			items: (cat.items || []).map(item => ({
				id: Number(item.id),
				name: item.name || '',
				type: item.type || '',
			})).filter(item => item.id),
		}));
}

/**
 * Ajuster le stock d'un article (manuel : boutons +/- ou réception)
 * @param {string} restaurantId
 * @param {number} itemId - ID menu de l'article
 * @param {{ delta?: number, currentStock?: number, stockThreshold?: number, unit?: string }} updates
 * @param {{ userId?: string, type?: 'manual'|'receipt' }} meta - type par défaut 'manual'
 * @returns {Promise<{ item: object, previousStock: number }>}
 */
async function adjustStock(restaurantId, itemId, updates, meta = {}) {
	const { userId, type = 'manual' } = meta;
	const inv = await loadInventory(restaurantId);
	if (!inv || !Array.isArray(inv.items)) {
		throw new Error('Inventaire introuvable. Exécutez d\'abord l\'initialisation (POST /inventory/:restaurantId/init).');
	}
	const itemIdNum = Number(itemId);
	const item = inv.items.find(i => Number(i.itemId) === itemIdNum);
	if (!item) {
		throw new Error(`Article ${itemId} introuvable dans l'inventaire.`);
	}
	const previousStock = Number(item.currentStock) || 0;
	let delta = 0;
	if (updates.delta != null) {
		delta = Number(updates.delta);
		item.currentStock = Math.max(0, previousStock + delta);
	} else if (updates.currentStock != null) {
		const newStock = Math.max(0, Number(updates.currentStock));
		delta = newStock - previousStock;
		item.currentStock = newStock;
	}
	if (updates.stockThreshold != null) item.stockThreshold = Number(updates.stockThreshold);
	if (updates.unit != null) item.unit = String(updates.unit);

	await appendInventoryHistory(restaurantId, { type, itemId: itemIdNum, delta, userId });
	await saveInventory(restaurantId, inv);
	return { item, previousStock };
}

/**
 * Déduire le stock pour une vente (articles payés au POS).
 * Agrège les quantités par itemId et appelle adjustStock avec type 'sale'.
 * Les articles absents de l'inventaire (ex. plats) sont ignorés sans erreur.
 * @param {string} restaurantId
 * @param {Array<{ id: number, quantity: number }>} paidItems - Articles payés (id = itemId menu)
 * @param {{ userId?: string }} meta
 */
async function deductStockForSale(restaurantId, paidItems, meta = {}) {
	const { userId } = meta;
	if (!paidItems || paidItems.length === 0) return;
	const byId = {};
	for (const it of paidItems) {
		const id = Number(it.id);
		if (!id) continue;
		byId[id] = (byId[id] || 0) + (Number(it.quantity) || 0);
	}
	for (const [itemIdStr, qty] of Object.entries(byId)) {
		const itemId = Number(itemIdStr);
		const delta = -Number(qty);
		if (delta >= 0) continue;
		try {
			await adjustStock(restaurantId, itemId, { delta }, { type: 'sale', userId });
		} catch (e) {
			if (!e.message || !e.message.includes('introuvable')) {
				console.error(`[inventory] Erreur déduction vente itemId=${itemId}:`, e.message);
			}
		}
	}
}

/**
 * Mettre tous les stocks à une valeur (test / remplissage rapide). Pas d'historique.
 * @param {string} restaurantId
 * @param {number} value - valeur >= 0
 * @returns {Promise<{ count: number }>}
 */
async function setAllStocks(restaurantId, value) {
	const inv = await loadInventory(restaurantId);
	if (!inv || !Array.isArray(inv.items)) {
		throw new Error('Inventaire introuvable.');
	}
	const v = Math.max(0, Number(value));
	for (const it of inv.items) {
		it.currentStock = v;
	}
	await saveInventory(restaurantId, inv);
	return { count: inv.items.length };
}

module.exports = {
	loadInventory,
	saveInventory,
	loadInventoryHistory,
	appendInventoryHistory,
	initInventoryFromMenu,
	enrichInventoryWithMenu,
	buildMenuDrinkCategories,
	adjustStock,
	deductStockForSale,
	setAllStocks,
	DRINK_GROUPS,
	DEFAULT_STOCK_THRESHOLD,
	DEFAULT_UNIT,
	RESTAURANTS_DIR,
};
