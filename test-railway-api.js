// Test complet de l'API Admin sur Railway
const BASE_URL = 'https://orderly-server-production.up.railway.app';
const PASSWORD = 'admin123';

async function main() {
    console.log('🧪 Test API Admin Railway\n');
    
    // 1. Login
    console.log('1️⃣  Login...');
    const loginRes = await fetch(`${BASE_URL}/api/admin/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: PASSWORD })
    });
    const { token } = await loginRes.json();
    console.log('✅ Token reçu\n');

    // 2. Liste restaurants
    console.log('2️⃣  Liste restaurants...');
    const listRes = await fetch(`${BASE_URL}/api/admin/restaurants`, {
        headers: { 'x-admin-token': token }
    });
    const restaurants = await listRes.json();
    console.log(`✅ ${restaurants.length} restaurant(s):`);
    restaurants.forEach(r => console.log(`   - ${r.name}: ${r.itemsCount} articles`));
    console.log();

    // 3. Lire menu "les-emirs"
    console.log('3️⃣  Lire menu les-emirs...');
    const menuRes = await fetch(`${BASE_URL}/api/admin/menu/les-emirs`, {
        headers: { 'x-admin-token': token }
    });
    const menu = await menuRes.json();
    console.log(`✅ ${menu.categories.length} catégories chargées`);
    console.log(`   Première catégorie: ${menu.categories[0].name} (${menu.categories[0].items.length} items)\n`);

    // 4. Test ajout article
    const testCategory = menu.categories[0].name;
    console.log(`4️⃣  Ajouter article test dans "${testCategory}"...`);
    const addRes = await fetch(`${BASE_URL}/api/admin/menu/les-emirs/items`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-admin-token': token },
        body: JSON.stringify({
            categoryName: testCategory,
            name: 'Article Test API',
            price: 99.99,
            type: 'Test'
        })
    });
    const { id: newId } = await addRes.json();
    console.log(`✅ Article créé, ID: ${newId}\n`);

    // 5. Modifier (rendre indisponible)
    console.log('5️⃣  Rendre l\'article indisponible...');
    await fetch(`${BASE_URL}/api/admin/menu/les-emirs/items/${newId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', 'x-admin-token': token },
        body: JSON.stringify({ available: false })
    });
    console.log('✅ Article masqué du menu client\n');

    // 6. Vérifier qu'il n'apparaît plus dans le menu public
    console.log('6️⃣  Vérifier filtre disponibilité...');
    const publicMenuRes = await fetch(`${BASE_URL}/menu/les-emirs`);
    const publicMenu = await publicMenuRes.json();
    const foundInPublic = publicMenu.categories.some(cat => 
        cat.items.some(it => it.id === newId)
    );
    console.log(foundInPublic ? '❌ ERREUR: Article visible (devrait être masqué)' : '✅ Article bien masqué du menu public\n');

    // 7. Supprimer
    console.log('7️⃣  Supprimer l\'article test...');
    await fetch(`${BASE_URL}/api/admin/menu/les-emirs/items/${newId}`, {
        method: 'DELETE',
        headers: { 'x-admin-token': token }
    });
    console.log('✅ Article supprimé\n');

    console.log('🎉 Tous les tests passés !');
    console.log('\n📝 Note: Pour tester l\'upload PDF, ajoutez OPENROUTER_API_KEY sur Railway');
    console.log('   Variable: OPENROUTER_API_KEY=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');
}

main().catch(err => console.error('❌', err.message));

