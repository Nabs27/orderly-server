// 🍽️ Synchronisation des menus entre JSON local et MongoDB
// Permet la synchronisation bidirectionnelle des menus

const fs = require('fs');
const fsp = require('fs').promises;
const path = require('path');
const dbManager = require('./dbManager');

const RESTAURANTS_DIR = path.join(__dirname, '..', '..', 'data', 'restaurants');

// Sauvegarder un menu (JSON local + MongoDB si configuré)
async function saveMenu(restaurantId, menu) {
	try {
		// 1. Sauvegarder en JSON local
		const restaurantDir = path.join(RESTAURANTS_DIR, restaurantId);
		await fsp.mkdir(restaurantDir, { recursive: true });
		const menuPath = path.join(restaurantDir, 'menu.json');
		await fsp.writeFile(menuPath, JSON.stringify(menu, null, 2), 'utf8');
		console.log(`[menu-sync] 🏠 Menu ${restaurantId} sauvegardé en JSON local`);
		
		// 2. Synchroniser vers MongoDB si configuré
		if (dbManager.isCloud && dbManager.db) {
			await dbManager.menus.replaceOne(
				{ restaurantId },
				{ restaurantId, menu, lastSynced: new Date().toISOString() },
				{ upsert: true }
			);
			console.log(`[menu-sync] ☁️ Menu ${restaurantId} synchronisé vers MongoDB`);
		}
	} catch (e) {
		console.error(`[menu-sync] ❌ Erreur sauvegarde menu ${restaurantId}:`, e);
		throw e;
	}
}

// Charger un menu (MongoDB si disponible, sinon JSON local)
async function loadMenu(restaurantId) {
	try {
		// 1. Essayer de charger depuis MongoDB si configuré
		if (dbManager.isCloud && dbManager.db) {
			const menuDoc = await dbManager.menus.findOne({ restaurantId });
			if (menuDoc && menuDoc.menu) {
				console.log(`[menu-sync] ☁️ Menu ${restaurantId} chargé depuis MongoDB`);
				// Synchroniser vers JSON local pour cohérence
				const restaurantDir = path.join(RESTAURANTS_DIR, restaurantId);
				await fsp.mkdir(restaurantDir, { recursive: true });
				const menuPath = path.join(restaurantDir, 'menu.json');
				await fsp.writeFile(menuPath, JSON.stringify(menuDoc.menu, null, 2), 'utf8');
				return menuDoc.menu;
			}
		}
		
		// 2. Charger depuis JSON local
		const menuPath = path.join(RESTAURANTS_DIR, restaurantId, 'menu.json');
		if (fs.existsSync(menuPath)) {
			const content = await fsp.readFile(menuPath, 'utf8');
			const menu = JSON.parse(content);
			console.log(`[menu-sync] 🏠 Menu ${restaurantId} chargé depuis JSON local`);
			
			// Synchroniser vers MongoDB si configuré (backup)
			if (dbManager.isCloud && dbManager.db) {
				await dbManager.menus.replaceOne(
					{ restaurantId },
					{ restaurantId, menu, lastSynced: new Date().toISOString() },
					{ upsert: true }
				).catch(e => console.error(`[menu-sync] ⚠️ Erreur sync menu vers MongoDB:`, e.message));
			}
			
			return menu;
		}
		
		return null;
	} catch (e) {
		console.error(`[menu-sync] ❌ Erreur chargement menu ${restaurantId}:`, e);
		return null;
	}
}

// Lister tous les restaurants (depuis MongoDB ou fichiers)
async function listRestaurants() {
	try {
		const restaurants = [];
		
		// 1. Si MongoDB configuré, charger depuis MongoDB
		if (dbManager.isCloud && dbManager.db) {
			const menuDocs = await dbManager.menus.find({}).toArray();
			for (const doc of menuDocs) {
				if (doc.menu && doc.menu.restaurant) {
					const menu = doc.menu;
					let hiddenCount = 0, unavailableCount = 0, itemsCount = 0;
					for (const cat of (menu.categories || [])) {
						for (const it of (cat.items || [])) {
							itemsCount++;
							if (it.hidden === true) hiddenCount++;
							if (it.available === false) unavailableCount++;
						}
					}
					restaurants.push({
						id: doc.restaurantId,
						name: menu.restaurant?.name || doc.restaurantId,
						currency: menu.restaurant?.currency || 'TND',
						categoriesCount: (menu.categories || []).length,
						itemsCount,
						hiddenCount,
						unavailableCount
					});
				}
			}
			if (restaurants.length > 0) {
				console.log(`[menu-sync] ☁️ ${restaurants.length} restaurants chargés depuis MongoDB`);
				return restaurants;
			}
		}
		
		// 2. Charger depuis fichiers locaux
		await fsp.mkdir(RESTAURANTS_DIR, { recursive: true });
		const dirs = await fsp.readdir(RESTAURANTS_DIR, { withFileTypes: true });
		for (const dir of dirs) {
			if (!dir.isDirectory()) continue;
			const menuPath = path.join(RESTAURANTS_DIR, dir.name, 'menu.json');
			try {
				const content = await fsp.readFile(menuPath, 'utf8');
				const menu = JSON.parse(content);
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
		console.log(`[menu-sync] 🏠 ${restaurants.length} restaurants chargés depuis fichiers locaux`);
		return restaurants;
	} catch (e) {
		console.error('[menu-sync] ❌ Erreur liste restaurants:', e);
		return [];
	}
}

module.exports = {
	saveMenu,
	loadMenu,
	listRestaurants
};

