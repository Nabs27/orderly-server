// Script de test rapide pour l'API Admin
// Usage: node test-admin-api.js

const BASE_URL = 'http://localhost:3000';
const PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';

async function testAdminAPI() {
    console.log('🧪 Test de l\'API Admin...\n');

    // 1. Login
    console.log('1️⃣  Test Login...');
    const loginRes = await fetch(`${BASE_URL}/api/admin/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: PASSWORD })
    });
    const loginData = await loginRes.json();
    if (!loginData.ok || !loginData.token) {
        console.error('❌ Échec login:', loginData);
        return;
    }
    console.log('✅ Login réussi. Token:', loginData.token.substring(0, 10) + '...\n');
    const token = loginData.token;

    // 2. Liste restaurants
    console.log('2️⃣  Test Liste Restaurants...');
    const listRes = await fetch(`${BASE_URL}/api/admin/restaurants`, {
        headers: { 'x-admin-token': token }
    });
    const restaurants = await listRes.json();
    console.log(`✅ ${restaurants.length} restaurant(s) trouvé(s):`);
    restaurants.forEach(r => {
        console.log(`   - ${r.name} (${r.id}) : ${r.itemsCount} articles\n`);
    });

    // 3. Lire le menu "les-emirs"
    if (restaurants.length > 0) {
        const restaurantId = restaurants[0].id;
        console.log(`3️⃣  Test Lecture Menu (${restaurantId})...`);
        const menuRes = await fetch(`${BASE_URL}/api/admin/menu/${restaurantId}`, {
            headers: { 'x-admin-token': token }
        });
        const menu = await menuRes.json();
        console.log(`✅ Menu chargé: ${menu.categories?.length || 0} catégories\n`);

        // 4. Ajouter un article test
        const testCategoryName = menu.categories?.[0]?.name;
        if (testCategoryName) {
            console.log('4️⃣  Test Ajout Article...');
            const addRes = await fetch(`${BASE_URL}/api/admin/menu/${restaurantId}/items`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'x-admin-token': token
                },
                body: JSON.stringify({
                    categoryName: testCategoryName,
                    name: 'Article Test IA',
                    price: 99.99,
                    type: 'Test'
                })
            });
            const addData = await addRes.json();
            if (addData.ok) {
                console.log(`✅ Article ajouté avec ID: ${addData.id}`);
                
                // 5. Modifier l'article (le rendre indisponible)
                console.log('5️⃣  Test Modification Article (disponible = false)...');
                const updateRes = await fetch(`${BASE_URL}/api/admin/menu/${restaurantId}/items/${addData.id}`, {
                    method: 'PATCH',
                    headers: {
                        'Content-Type': 'application/json',
                        'x-admin-token': token
                    },
                    body: JSON.stringify({ available: false, price: 0.01 })
                });
                const updateData = await updateRes.json();
                console.log(updateData.ok ? '✅ Article modifié\n' : '❌ Échec modification\n');

                // 6. Supprimer l'article
                console.log('6️⃣  Test Suppression Article...');
                const deleteRes = await fetch(`${BASE_URL}/api/admin/menu/${restaurantId}/items/${addData.id}`, {
                    method: 'DELETE',
                    headers: { 'x-admin-token': token }
                });
                const deleteData = await deleteRes.json();
                console.log(deleteData.ok ? '✅ Article supprimé\n' : '❌ Échec suppression\n');
            } else {
                console.log('❌ Échec ajout article\n');
            }
        }
    }

    console.log('🎉 Tests terminés !');
    console.log('\n📝 Notes :');
    console.log('   - Pour tester l\'upload PDF, utilisez l\'app Flutter Admin');
    console.log('   - Assurez-vous d\'avoir OPENROUTER_API_KEY dans .env pour le parsing IA');
}

// Lancer les tests
testAdminAPI().catch(err => {
    console.error('❌ Erreur:', err.message);
    console.log('\n💡 Assurez-vous que le serveur est lancé (npm start)');
});

