// 🍽️ Synchronisation des menus entre JSON local et MongoDB
// Permet la synchronisation bidirectionnelle des menus

const fs = require('fs');
const fsp = require('fs').promises;
const path = require('path');
const dbManager = require('./dbManager');

const RESTAURANTS_DIR = path.join(__dirname, '..', '..', 'data', 'restaurants');

// 🚀 Cache en mémoire pour éviter les requêtes MongoDB répétées
const menuCache = new Map(); // restaurantId -> { menu, timestamp, fileMTime }
const CACHE_TTL = 10000; // 10 secondes de cache (réduit pour détecter les modifications plus rapidement)

// 🆕 Vider le cache du menu
function clearMenuCache(restaurantId) {
	if (restaurantId) {
		menuCache.delete(restaurantId);
		console.log(`[menu-sync] 🧹 Cache vidé pour ${restaurantId}`);
	} else {
		menuCache.clear();
		console.log('[menu-sync] 🧹 Cache global vidé');
	}
}

// Sauvegarder un menu (JSON local + MongoDB si configuré)
async function saveMenu(restaurantId, menu) {
	try {
		// 🆕 CORRECTION : Pour serveur cloud, sauvegarder directement dans MongoDB (source de vérité)
		// Le JSON local peut ne pas être persistant sur Railway
		if (dbManager.isCloud && dbManager.db) {
			// Serveur cloud : MongoDB est la source de vérité
			await dbManager.menus.replaceOne(
				{ restaurantId },
				{ restaurantId, menu, lastSynced: new Date().toISOString() },
				{ upsert: true }
			);
			console.log(`[menu-sync] ☁️ Menu ${restaurantId} sauvegardé dans MongoDB`);

			// Mettre à jour le cache
			menuCache.set(restaurantId, {
				menu,
				timestamp: Date.now(),
				fileMTime: null // Pas de fichier sur serveur cloud
			});

			// Essayer de sauvegarder en JSON local si possible (non-bloquant)
			try {
				const restaurantDir = path.join(RESTAURANTS_DIR, restaurantId);
				await fsp.mkdir(restaurantDir, { recursive: true });
				const menuPath = path.join(restaurantDir, 'menu.json');
				await fsp.writeFile(menuPath, JSON.stringify(menu, null, 2), 'utf8');
				console.log(`[menu-sync] 🏠 Menu ${restaurantId} aussi sauvegardé en JSON local`);
			} catch (e) {
				// Sur Railway, l'écriture peut échouer (pas de stockage persistant) - c'est normal
				console.log(`[menu-sync] ⚠️ Impossible de sauvegarder en JSON local (normal sur serveur cloud)`);
			}
		} else {
			// Serveur local : JSON local est la source de vérité
			const restaurantDir = path.join(RESTAURANTS_DIR, restaurantId);
			await fsp.mkdir(restaurantDir, { recursive: true });
			const menuPath = path.join(restaurantDir, 'menu.json');
			await fsp.writeFile(menuPath, JSON.stringify(menu, null, 2), 'utf8');
			console.log(`[menu-sync] 🏠 Menu ${restaurantId} sauvegardé en JSON local`);

			// Mettre à jour le cache avec le timestamp du fichier
			try {
				const stats = await fsp.stat(menuPath);
				menuCache.set(restaurantId, {
					menu,
					timestamp: Date.now(),
					fileMTime: stats.mtimeMs
				});
			} catch (e) {
				menuCache.set(restaurantId, {
					menu,
					timestamp: Date.now(),
					fileMTime: null
				});
			}

			// Synchroniser vers MongoDB si configuré (asynchrone, non-bloquant)
			if (dbManager.db) {
				dbManager.menus.replaceOne(
					{ restaurantId },
					{ restaurantId, menu, lastSynced: new Date().toISOString() },
					{ upsert: true }
				).then(() => {
					console.log(`[menu-sync] ☁️ Menu ${restaurantId} synchronisé vers MongoDB`);
				}).catch(e => {
					console.error(`[menu-sync] ⚠️ Erreur sync menu vers MongoDB:`, e.message);
				});
			}
		}
	} catch (e) {
		console.error(`[menu-sync] ❌ Erreur sauvegarde menu ${restaurantId}:`, e);
		throw e;
	}
}

// Charger un menu (avec cache en mémoire et vérification de timestamp)
async function loadMenu(restaurantId) {
	try {
		const menuPath = path.join(RESTAURANTS_DIR, restaurantId, 'menu.json');
		const fileExists = fs.existsSync(menuPath);

		// 1. Vérifier le cache en mémoire
		// 🆕 On ignore le cache sur le Cloud pour éviter les désynchronisations avec l'app Admin
		if (!dbManager.isCloud && fileExists) {
			const cached = menuCache.get(restaurantId);
			if (cached) {
				// Vérifier si le cache est encore valide (TTL)
				const cacheAge = Date.now() - cached.timestamp;
				if (cacheAge < CACHE_TTL) {
					// Vérifier si le fichier a été modifié depuis le cache
					try {
						const stats = await fsp.stat(menuPath);
						if (cached.fileMTime && stats.mtimeMs === cached.fileMTime) {
							// Fichier non modifié, cache toujours valide
							return cached.menu;
						}
					} catch (e) {
						// Erreur de stat, on recharge
					}
				}
			}
		}

		// 2. Charger depuis JSON local (toujours la source de vérité si le fichier existe)
		if (fileExists) {
			const content = await fsp.readFile(menuPath, 'utf8');
			const menu = JSON.parse(content);
			const stats = await fsp.stat(menuPath);

			// Mettre à jour le cache avec le timestamp du fichier
			menuCache.set(restaurantId, {
				menu,
				timestamp: Date.now(),
				fileMTime: stats.mtimeMs
			});

			// Synchroniser vers MongoDB si configuré (asynchrone, non-bloquant)
			if (dbManager.isCloud && dbManager.db) {
				dbManager.menus.replaceOne(
					{ restaurantId },
					{ restaurantId, menu, lastSynced: new Date().toISOString() },
					{ upsert: true }
				).catch(e => console.error(`[menu-sync] ⚠️ Erreur sync menu vers MongoDB:`, e.message));
			}

			return menu;
		}

		// 3. Si fichier local n'existe pas (Railway ou premier démarrage), charger depuis MongoDB
		if (dbManager.isCloud && dbManager.db) {
			const menuDoc = await dbManager.menus.findOne({ restaurantId });
			if (menuDoc && menuDoc.menu) {
				// Sauvegarder en JSON local pour cohérence (si possible, sinon juste mettre en cache)
				try {
					const restaurantDir = path.join(RESTAURANTS_DIR, restaurantId);
					await fsp.mkdir(restaurantDir, { recursive: true });
					const menuPath = path.join(restaurantDir, 'menu.json');
					await fsp.writeFile(menuPath, JSON.stringify(menuDoc.menu, null, 2), 'utf8');
					const stats = await fsp.stat(menuPath);
					menuCache.set(restaurantId, {
						menu: menuDoc.menu,
						timestamp: Date.now(),
						fileMTime: stats.mtimeMs
					});
				} catch (e) {
					// Sur Railway, l'écriture peut échouer (pas de stockage persistant)
					// On met quand même en cache
					menuCache.set(restaurantId, {
						menu: menuDoc.menu,
						timestamp: Date.now(),
						fileMTime: null // Pas de fichier
					});
				}

				return menuDoc.menu;
			}
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
			} catch (e) { }
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
	listRestaurants,
	clearMenuCache
};

