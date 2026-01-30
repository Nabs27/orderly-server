#!/usr/bin/env node
// Script d'initialisation de l'inventaire à partir du menu (tous groupes boissons : drinks, spirits, alcohol, beers, wines)
// Usage : node server/scripts/init-inventory.js <restaurantId>
// Exemple : node server/scripts/init-inventory.js les-emirs

const { initInventoryFromMenu } = require('../utils/inventorySync');

const restaurantId = process.argv[2] || 'les-emirs';

async function main() {
	try {
		console.log(`[init-inventory] Initialisation pour ${restaurantId}...`);
		const { created, items } = await initInventoryFromMenu(restaurantId, { overwrite: false });
		console.log(`[init-inventory] ✅ Terminé : ${items.length} article(s) en stock, ${created} nouveau(x).`);
		process.exit(0);
	} catch (e) {
		console.error('[init-inventory] ❌', e.message);
		process.exit(1);
	}
}

main();
