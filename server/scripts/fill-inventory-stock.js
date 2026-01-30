#!/usr/bin/env node
// Met tous les stocks à une valeur (test). Modifie inventory.json directement.
// Usage : node server/scripts/fill-inventory-stock.js <restaurantId> [valeur]
// Exemple : node server/scripts/fill-inventory-stock.js les-emirs 50

const path = require('path');
const fsp = require('fs').promises;

const restaurantId = process.argv[2] || 'les-emirs';
const value = Math.max(0, parseInt(process.argv[3] || '50', 10));

const filePath = path.join(__dirname, '..', '..', 'data', 'restaurants', restaurantId, 'inventory.json');

async function main() {
  try {
    const content = await fsp.readFile(filePath, 'utf8');
    const data = JSON.parse(content);
    if (!Array.isArray(data.items)) {
      console.error('[fill-inventory-stock] Pas d’items dans', filePath);
      process.exit(1);
    }
    let count = 0;
    for (const it of data.items) {
      it.currentStock = value;
      count++;
    }
    data.updatedAt = new Date().toISOString();
    await fsp.writeFile(filePath, JSON.stringify(data, null, 2), 'utf8');
    console.log(`[fill-inventory-stock] ✅ ${count} article(s) mis à ${value} pour ${restaurantId}`);
    process.exit(0);
  } catch (e) {
    console.error('[fill-inventory-stock] ❌', e.message);
    process.exit(1);
  }
}

main();
