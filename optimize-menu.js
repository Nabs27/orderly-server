// Script pour optimiser le menu : séparer les variantes en articles distincts
const fs = require('fs');
const path = require('path');

const menuPath = path.join(__dirname, 'data', 'restaurants', 'les-emirs', 'menu.json');
const menu = JSON.parse(fs.readFileSync(menuPath, 'utf8'));

let nextId = 10000; // ID de départ pour les nouveaux articles

function extractVariants(name) {
    // Détecte les variantes séparées par " / "
    const hasSlash = name.includes(' / ');
    const hasParenSlash = name.match(/\(([^)]+)\)/);
    
    if (hasSlash && !hasParenSlash) {
        // Cas: "Coca / Fanta / Boga"
        return name.split(' / ').map(v => v.trim()).filter(v => v);
    }
    
    if (hasParenSlash) {
        const match = name.match(/^([^(]+)\(([^)]+)\)$/);
        if (match) {
            const base = match[1].trim();
            const variants = match[2].split('/').map(v => v.trim()).filter(v => v);
            if (variants.length > 1) {
                // Cas: "Jus (Orange / Citron)" → ["Jus Orange", "Jus Citron"]
                return variants.map(v => `${base} ${v}`);
            }
        }
    }
    
    return [name]; // Pas de variante détectée
}

console.log('🔧 Optimisation du menu Les Emirs...\n');

let totalSplits = 0;
const newCategories = [];

for (const cat of menu.categories) {
    const newItems = [];
    
    for (const item of cat.items) {
        const variants = extractVariants(item.name);
        
        if (variants.length > 1) {
            console.log(`✂️  Séparation: "${item.name}"`);
            variants.forEach(variant => {
                const newItem = {
                    id: nextId++,
                    name: variant,
                    price: item.price,
                    type: item.type,
                    available: true
                };
                newItems.push(newItem);
                console.log(`   → ${variant} (ID: ${newItem.id})`);
            });
            totalSplits++;
        } else {
            // Garder l'article tel quel, mais ajouter "available" si manquant
            newItems.push({
                ...item,
                available: item.available !== undefined ? item.available : true
            });
        }
    }
    
    newCategories.push({
        ...cat,
        items: newItems
    });
}

const optimizedMenu = {
    ...menu,
    categories: newCategories
};

// Sauvegarder l'optimisation
const backupPath = path.join(__dirname, 'data', 'restaurants', 'les-emirs', 'menu.backup.json');
fs.writeFileSync(backupPath, JSON.stringify(menu, null, 2), 'utf8');
console.log(`\n💾 Backup sauvegardé: ${backupPath}`);

fs.writeFileSync(menuPath, JSON.stringify(optimizedMenu, null, 2), 'utf8');
console.log(`✅ Menu optimisé sauvegardé: ${menuPath}`);
console.log(`\n📊 Statistiques:`);
console.log(`   - ${totalSplits} articles avec variantes séparées`);
console.log(`   - ${nextId - 10000} nouveaux articles créés`);
console.log(`\n🎉 Terminé ! Vous pouvez maintenant gérer chaque variante individuellement.`);

