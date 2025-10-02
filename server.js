const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const fs = require('fs');
const path = require('path');
const fsp = fs.promises;
const multer = require('multer');
const pdfParse = require('pdf-parse');
const OpenAI = require('openai');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
	cors: { origin: '*', methods: ['GET', 'POST', 'PATCH'] }
});

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Racine: simple ping texte pour API
app.get('/', (req, res) => res.send('API OK'));

// Healthcheck simple
app.get('/health', (req, res) => res.send('ok'));

// Route courte QR → client avec table préremplie
app.get('/t/:table', (req, res) => {
    const t = encodeURIComponent(req.params.table);
    const r = req.query.r ? `&r=${encodeURIComponent(req.query.r)}` : '';
    res.redirect(`/client/?table=${t}${r}`);
});

// QR avec restaurant explicite
app.get('/r/:restaurantId/t/:table', (req, res) => {
    const t = encodeURIComponent(req.params.table);
    const r = encodeURIComponent(req.params.restaurantId);
    res.redirect(`/client/?table=${t}&r=${r}`);
});

// Charger le menu (avec traduction/caching si ?lng=de|en|ar)
app.get('/menu/:restaurantId', async (req, res) => {
    try {
        const restaurantId = req.params.restaurantId;
        const lng = String(req.query.lng || 'fr').toLowerCase();
        console.log(`[menu] restaurantId=${restaurantId} lng=${lng}`);
        const forceRefresh = String(req.query.refresh || '0') === '1';
        const menuPath = path.join(__dirname, 'data', 'restaurants', restaurantId, 'menu.json');
        const src = await fsp.readFile(menuPath, 'utf8').catch(() => null);
        if (!src) return res.status(404).json({ error: 'Menu introuvable' });
        const stat = await fsp.stat(menuPath);
        const sourceMTime = stat.mtimeMs;
        const menu = JSON.parse(src);
        if (lng === 'fr') {
            console.log('[menu] lng=fr, return source menu without translation');
            return res.json(filterAvailableItems(augmentWithOriginal(menu)));
        }

        const translated = await getTranslatedMenuWithCache(menu, restaurantId, lng, sourceMTime, forceRefresh);
        console.log('[menu] translated menu served');
        return res.json(filterAvailableItems(translated));
    } catch (e) {
        console.error('menu translate error', e);
        return res.status(500).json({ error: 'Erreur chargement menu' });
    }
});

const translationsDir = path.join(__dirname, 'data', 'translations');
async function ensureDir(p) { try { await fsp.mkdir(p, { recursive: true }); } catch {}
}

async function getTranslatedMenuWithCache(menu, restaurantId, lng, sourceMTime, forceRefresh) {
    if (!process.env.DEEPL_KEY) {
        console.warn('[menu-cache] DEEPL_KEY missing → return FR without caching');
        return menu;
    }
    await ensureDir(translationsDir);
    const cachePath = path.join(translationsDir, `${restaurantId}_${lng}.json`);
    const cacheRaw = forceRefresh ? null : await fsp.readFile(cachePath, 'utf8').catch(() => null);
    if (cacheRaw && !forceRefresh) {
        try {
            const cache = JSON.parse(cacheRaw);
            if (cache.sourceMTime === sourceMTime && cache.menu) {
                console.log(`[menu-cache] HIT ${cachePath}`);
                return cache.menu;
            }
            console.log(`[menu-cache] STALE or invalid ${cachePath} (sourceMTime changed)`);
        } catch {}
    }
    console.log('[menu-cache] MISS, translating via DeepL');
    const translatedMenu = await translateMenu(menu, lng);
    await fsp.writeFile(cachePath, JSON.stringify({ sourceMTime, menu: translatedMenu }, null, 2), 'utf8');
    console.log(`[menu-cache] SAVED ${cachePath}`);
    return translatedMenu;
}

function deepCollectTexts(menu) {
    const texts = new Set();
    if (menu.restaurant?.name) texts.add(String(menu.restaurant.name));
    for (const cat of menu.categories || []) {
        if (cat.name) texts.add(String(cat.name));
        for (const it of cat.items || []) {
            if (it.name) texts.add(String(it.name));
            if (it.type) texts.add(String(it.type));
        }
    }
    return Array.from(texts);
}

async function translateMenu(menu, lng) {
    const DEEPL_KEY = process.env.DEEPL_KEY || '';
    const targetMap = { en: 'EN', de: 'DE', ar: 'AR' };
    const targetLang = targetMap[lng] || 'EN';
    if (!DEEPL_KEY) {
        // Pas de clé: retourner le FR tel quel (fallback silencieux)
        console.warn('[deepl] DEEPL_KEY is missing; returning FR menu');
        return menu;
    }
    const uniqueTexts = deepCollectTexts(menu);
    console.log(`[deepl] translating ${uniqueTexts.length} unique texts to ${targetLang}`);
    const mapping = await translateBatch(uniqueTexts, targetLang, DEEPL_KEY);
    // Reconstruire
    const out = augmentWithOriginal(menu);
    if (out.restaurant?.name && mapping[out.restaurant.name]) out.restaurant.name = mapping[out.restaurant.originalName] || mapping[out.restaurant.name] || out.restaurant.name;
    for (const cat of out.categories || []) {
        const srcCatName = cat.originalName || cat.name;
        if (mapping[srcCatName]) cat.name = mapping[srcCatName];
        for (const it of cat.items || []) {
            const srcItemName = it.originalName || it.name;
            const srcItemType = it.originalType || it.type;
            if (mapping[srcItemName]) it.name = mapping[srcItemName];
            if (mapping[srcItemType]) it.type = mapping[srcItemType];
        }
    }
    return out;
}

async function translateBatch(texts, targetLang, key) {
    const mapping = {};
    const endpoint = key.endsWith(':fx') ? 'https://api-free.deepl.com/v2/translate' : 'https://api.deepl.com/v2/translate';
    const batchSize = 40;
    for (let i = 0; i < texts.length; i += batchSize) {
        const slice = texts.slice(i, i + batchSize);
        const body = new URLSearchParams();
        body.append('auth_key', key);
        body.append('target_lang', targetLang);
        body.append('source_lang', 'FR');
        body.append('preserve_formatting', '1');
        body.append('split_sentences', 'nonewlines');
        for (const t of slice) body.append('text', t);
        console.log(`[deepl] POST ${endpoint} batch ${i}-${i+slice.length-1}`);
        const resp = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
        if (!resp.ok) {
            const errText = await resp.text().catch(()=> '');
            console.error('[deepl] error', resp.status, errText);
            // En cas d'erreur, retourner mapping vide pour cette tranche
            continue;
        }
        const json = await resp.json();
        const translations = json.translations || [];
        console.log(`[deepl] ok batch size=${translations.length}`);
        for (let j = 0; j < translations.length; j++) {
            const src = slice[j];
            const trg = translations[j]?.text || src;
            mapping[src] = trg;
        }
    }
    return mapping;
}

function augmentWithOriginal(menu) {
    const out = JSON.parse(JSON.stringify(menu));
    if (out.restaurant) {
        out.restaurant.originalName = out.restaurant.name;
    }
    for (const cat of out.categories || []) {
        cat.originalName = cat.name;
        for (const it of cat.items || []) {
            it.originalName = it.name;
            it.originalType = it.type;
        }
    }
    return out;
}

// Filtrer les items non disponibles (available: false)
function filterAvailableItems(menu) {
    const filtered = JSON.parse(JSON.stringify(menu));
    for (const cat of filtered.categories || []) {
        cat.items = (cat.items || []).filter(it => it.available !== false);
    }
    // Retirer les catégories vides
    filtered.categories = (filtered.categories || []).filter(cat => (cat.items || []).length > 0);
    return filtered;
}

// In-memory storage
let orders = [];
let nextOrderId = 1;
let bills = [];
let nextBillId = 1;
let serviceRequests = [];
let nextServiceId = 1;

// Créer une commande
app.post('/orders', (req, res) => {
	const { table, items, notes } = req.body || {};
	if (!table || !Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'Requête invalide: table et items requis' });
	}
	const total = items.reduce((sum, it) => sum + (Number(it.price) * Number(it.quantity || 1)), 0);
	const newOrder = {
		id: nextOrderId++,
		table,
		items,
		notes: notes || '',
		status: 'nouvelle',
		total,
		consumptionConfirmed: false,
		createdAt: new Date().toISOString()
	};
	orders.push(newOrder);
	io.emit('order:new', newOrder);
	return res.status(201).json(newOrder);
});

// Lister commandes (option table=...)
app.get('/orders', (req, res) => {
	const { table } = req.query;
	const list = table ? orders.filter(o => String(o.table) === String(table)) : orders;
	return res.json(list);
});

// Récupérer une commande
app.get('/orders/:id', (req, res) => {
	const id = Number(req.params.id);
	const order = orders.find(o => o.id === id);
	if (!order) return res.status(404).json({ error: 'Commande introuvable' });
	return res.json(order);
});

// Marquer une commande traitée
app.patch('/orders/:id', (req, res) => {
	const id = Number(req.params.id);
	const order = orders.find(o => o.id === id);
	if (!order) return res.status(404).json({ error: 'Commande introuvable' });
	order.status = 'traitee';
	order.updatedAt = new Date().toISOString();
	io.emit('order:updated', order);
	return res.json(order);
});

// Confirmation de consommation par le client
app.patch('/orders/:id/confirm', (req, res) => {
	const id = Number(req.params.id);
	const order = orders.find(o => o.id === id);
	if (!order) return res.status(404).json({ error: 'Commande introuvable' });
	order.consumptionConfirmed = true;
	order.updatedAt = new Date().toISOString();
	io.emit('order:confirmed', order);
	return res.json(order);
});

// Créer une facture pour une table
app.post('/bills', (req, res) => {
	const { table } = req.body || {};
	if (!table) return res.status(400).json({ error: 'Table requise' });
	const tableOrders = orders.filter(o => String(o.table) === String(table));
	if (tableOrders.length === 0) return res.status(404).json({ error: 'Aucune commande pour cette table' });
	const total = tableOrders.reduce((s,o)=> s + Number(o.total||0), 0);
	const bill = { id: nextBillId++, table, orderIds: tableOrders.map(o=>o.id), total, payments: [], createdAt: new Date().toISOString() };
	bills.push(bill);
	io.emit('bill:new', bill);
	return res.status(201).json(bill);
});

// Lister factures (option table=...)
app.get('/bills', (req, res) => {
	const { table } = req.query;
	const list = table ? bills.filter(b => String(b.table) === String(table)) : bills;
	return res.json(list);
});

// Détail facture avec calcul paid/remaining
app.get('/bills/:id', (req, res) => {
	const id = Number(req.params.id);
	const bill = bills.find(b => b.id === id);
	if (!bill) return res.status(404).json({ error: 'Facture introuvable' });
	const billOrders = orders.filter(o => bill.orderIds.includes(o.id));
	const paid = (bill.payments||[]).reduce((s,p)=> s + Number(p.amount||0) + Number(p.tip||0), 0);
	const remaining = Math.max(0, Number(bill.total) - paid);
	return res.json({ ...bill, orders: billOrders, paid, remaining });
});

// Paiement partiel avec pourboire
app.post('/bills/:id/pay', (req, res) => {
	const id = Number(req.params.id);
	const bill = bills.find(b => b.id === id);
	if (!bill) return res.status(404).json({ error: 'Facture introuvable' });
	const { items, tip } = req.body || {};
	if (!Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'Sélection d\'articles requise' });
	}
	const billOrders = orders.filter(o => bill.orderIds.includes(o.id));
	let amount = 0;
	for (const sel of items) {
		const { orderId, itemId, quantity } = sel;
		const order = billOrders.find(o => o.id === Number(orderId));
		if (!order) continue;
		const line = order.items.find(i => Number(i.id) === Number(itemId));
		if (!line) continue;
		const qty = Math.max(0, Math.min(Number(quantity)||0, Number(line.quantity)||0));
		amount += qty * Number(line.price);
	}
	const tipAmount = Math.max(0, Number(tip) || 0);
	const payment = { id: `${bill.id}-${(bill.payments?.length||0)+1}`, amount, tip: tipAmount, items, createdAt: new Date().toISOString() };
	bill.payments = bill.payments || [];
	bill.payments.push(payment);
	const paid = bill.payments.reduce((s,p)=> s + Number(p.amount||0) + Number(p.tip||0), 0);
	const remaining = Math.max(0, Number(bill.total) - paid);
	io.emit('bill:paid', { billId: bill.id, table: bill.table, amount, tip: tipAmount, paid, remaining, paymentId: payment.id });
	return res.status(201).json({ payment, paid, remaining });
});

// Services: POST /service-requests { table, type, notes }
app.post('/service-requests', (req, res) => {
    const { table, type, notes } = req.body || {};
    if (!table || !type) return res.status(400).json({ error: 'Table et type requis' });
    const reqObj = { id: nextServiceId++, table, type, notes: notes || '', status: 'nouveau', createdAt: new Date().toISOString() };
    serviceRequests.push(reqObj);
    io.emit('service:new', reqObj);
    return res.status(201).json(reqObj);
});

// Services: PATCH /service-requests/:id traiter
app.patch('/service-requests/:id', (req, res) => {
    const id = Number(req.params.id);
    const r = serviceRequests.find(s => s.id === id);
    if (!r) return res.status(404).json({ error: 'Demande introuvable' });
    r.status = 'traitee';
    r.updatedAt = new Date().toISOString();
    io.emit('service:updated', r);
    return res.json(r);
});

io.on('connection', (socket) => {
	console.log('Socket connecté:', socket.id);
	socket.on('disconnect', () => {
		console.log('Socket déconnecté:', socket.id);
	});
	// Endpoint de reset (TEST uniquement)
	socket.on('dev:reset', () => {
		orders = []; nextOrderId = 1; bills = []; nextBillId = 1; serviceRequests = []; nextServiceId = 1;
		console.log('[dev] état serveur réinitialisé');
	});
});

// HTTP reset pour tests automatisés (non production)
app.post('/dev/reset', (req, res) => {
    const allowHeaderKey = (process.env.DEV_RESET_KEY && req.headers['x-reset-key'] === process.env.DEV_RESET_KEY);
    const allowEnv = String(process.env.ALLOW_DEV_RESET || '') === '1';
    const allow = (process.env.NODE_ENV !== 'production') || allowEnv || allowHeaderKey;
    if (!allow) {
        return res.status(403).json({ error: 'Forbidden in production' });
    }
    orders = []; nextOrderId = 1; bills = []; nextBillId = 1; serviceRequests = []; nextServiceId = 1;
    console.log('[dev] état serveur réinitialisé via HTTP');
    return res.json({ ok: true });
});

// ========================================
// 🔐 ADMIN API - Authentication simple
// ========================================
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123'; // À changer en production !

function authAdmin(req, res, next) {
	const token = req.headers['x-admin-token'];
	if (token !== ADMIN_PASSWORD) {
		return res.status(401).json({ error: 'Non autorisé' });
	}
	next();
}

app.post('/api/admin/login', (req, res) => {
	const { password } = req.body || {};
	if (password === ADMIN_PASSWORD) {
		return res.json({ token: ADMIN_PASSWORD, ok: true });
	}
	return res.status(401).json({ error: 'Mot de passe incorrect' });
});

// ========================================
// 📂 ADMIN API - Gestion Restaurants
// ========================================
app.get('/api/admin/restaurants', authAdmin, async (req, res) => {
	try {
		const restaurantsDir = path.join(__dirname, 'data', 'restaurants');
		await ensureDir(restaurantsDir);
		const dirs = await fsp.readdir(restaurantsDir, { withFileTypes: true });
		const restaurants = [];
		for (const dir of dirs) {
			if (!dir.isDirectory()) continue;
			const menuPath = path.join(restaurantsDir, dir.name, 'menu.json');
			try {
				const content = await fsp.readFile(menuPath, 'utf8');
				const menu = JSON.parse(content);
				restaurants.push({
					id: dir.name,
					name: menu.restaurant?.name || dir.name,
					currency: menu.restaurant?.currency || 'TND',
					categoriesCount: (menu.categories || []).length,
					itemsCount: (menu.categories || []).reduce((sum, cat) => sum + (cat.items || []).length, 0)
				});
			} catch {}
		}
		return res.json(restaurants);
	} catch (e) {
		console.error('[admin] list restaurants error', e);
		return res.status(500).json({ error: 'Erreur serveur' });
	}
});

app.post('/api/admin/restaurants', authAdmin, async (req, res) => {
	try {
		const { id, name, currency } = req.body || {};
		if (!id || !name) return res.status(400).json({ error: 'ID et nom requis' });
		const restaurantDir = path.join(__dirname, 'data', 'restaurants', id);
		await ensureDir(restaurantDir);
		const menuPath = path.join(restaurantDir, 'menu.json');
		const exists = await fsp.access(menuPath).then(() => true).catch(() => false);
		if (exists) return res.status(409).json({ error: 'Restaurant déjà existant' });
		const newMenu = {
			restaurant: { id, name, currency: currency || 'TND' },
			categories: []
		};
		await fsp.writeFile(menuPath, JSON.stringify(newMenu, null, 2), 'utf8');
		console.log(`[admin] created restaurant ${id}`);
		return res.status(201).json({ ok: true, id });
	} catch (e) {
		console.error('[admin] create restaurant error', e);
		return res.status(500).json({ error: 'Erreur création restaurant' });
	}
});

// ========================================
// 📝 ADMIN API - Gestion Menu (CRUD)
// ========================================
app.get('/api/admin/menu/:restaurantId', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const menuPath = path.join(__dirname, 'data', 'restaurants', restaurantId, 'menu.json');
		const content = await fsp.readFile(menuPath, 'utf8').catch(() => null);
		if (!content) return res.status(404).json({ error: 'Menu introuvable' });
		const menu = JSON.parse(content);
		return res.json(menu);
	} catch (e) {
		console.error('[admin] get menu error', e);
		return res.status(500).json({ error: 'Erreur chargement menu' });
	}
});

app.patch('/api/admin/menu/:restaurantId', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const { menu } = req.body || {};
		if (!menu) return res.status(400).json({ error: 'Menu requis' });
		const menuPath = path.join(__dirname, 'data', 'restaurants', restaurantId, 'menu.json');
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
app.post('/api/admin/menu/:restaurantId/categories', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const { name, group } = req.body || {};
		if (!name) return res.status(400).json({ error: 'Nom requis' });
		const menuPath = path.join(__dirname, 'data', 'restaurants', restaurantId, 'menu.json');
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
app.delete('/api/admin/menu/:restaurantId/categories/:categoryName', authAdmin, async (req, res) => {
	try {
		const { restaurantId, categoryName } = req.params;
		const menuPath = path.join(__dirname, 'data', 'restaurants', restaurantId, 'menu.json');
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
app.post('/api/admin/menu/:restaurantId/items', authAdmin, async (req, res) => {
	try {
		const { restaurantId } = req.params;
		const { categoryName, name, price, type } = req.body || {};
		if (!categoryName || !name || price == null) {
			return res.status(400).json({ error: 'Catégorie, nom et prix requis' });
		}
		const menuPath = path.join(__dirname, 'data', 'restaurants', restaurantId, 'menu.json');
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
app.patch('/api/admin/menu/:restaurantId/items/:itemId', authAdmin, async (req, res) => {
	try {
		const { restaurantId, itemId } = req.params;
		const updates = req.body || {};
		const menuPath = path.join(__dirname, 'data', 'restaurants', restaurantId, 'menu.json');
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
				found = true;
				break;
			}
		}
		if (!found) return res.status(404).json({ error: 'Article introuvable' });
		await fsp.writeFile(menuPath, JSON.stringify(menu, null, 2), 'utf8');
		await clearTranslationsCache(restaurantId);
		
		// 🔥 Émettre événement Socket.IO pour mise à jour temps réel
		io.emit('menu:updated', { restaurantId, itemId, updates });
		console.log(`[menu] item ${itemId} updated, event emitted`);
		
		return res.json({ ok: true });
	} catch (e) {
		console.error('[admin] update item error', e);
		return res.status(500).json({ error: 'Erreur modification article' });
	}
});

// Supprimer un item
app.delete('/api/admin/menu/:restaurantId/items/:itemId', authAdmin, async (req, res) => {
	try {
		const { restaurantId, itemId } = req.params;
		const menuPath = path.join(__dirname, 'data', 'restaurants', restaurantId, 'menu.json');
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

async function clearTranslationsCache(restaurantId) {
	try {
		const translationsDir = path.join(__dirname, 'data', 'translations');
		const files = await fsp.readdir(translationsDir).catch(() => []);
		for (const f of files) {
			if (f.startsWith(`${restaurantId}_`)) {
				await fsp.unlink(path.join(translationsDir, f)).catch(() => {});
			}
		}
		console.log(`[admin] cleared translations cache for ${restaurantId}`);
	} catch {}
}

// ========================================
// 📤 ADMIN API - Upload & Parsing (PDF/Image → JSON)
// ========================================
const upload = multer({
	storage: multer.memoryStorage(),
	limits: { fileSize: 10 * 1024 * 1024 }, // 10MB max
	fileFilter: (req, file, cb) => {
		const allowed = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg'];
		if (allowed.includes(file.mimetype)) {
			cb(null, true);
		} else {
			cb(new Error('Format non supporté (PDF, JPG, PNG uniquement)'));
		}
	}
});

app.post('/api/admin/parse-menu', authAdmin, upload.single('file'), async (req, res) => {
	try {
		if (!req.file) return res.status(400).json({ error: 'Fichier requis' });
		const { restaurantId, restaurantName, currency } = req.body || {};
		if (!restaurantId || !restaurantName) {
			return res.status(400).json({ error: 'restaurantId et restaurantName requis' });
		}

		console.log(`[admin] parsing menu file: ${req.file.originalname} (${req.file.mimetype})`);
		
		let extractedText = '';
		
		// Si PDF: extraction avec pdf-parse
		if (req.file.mimetype === 'application/pdf') {
			const data = await pdfParse(req.file.buffer);
			extractedText = data.text;
		} 
		// Si image: pour l'instant juste une simulation (OCR nécessiterait Tesseract.js ou Vision API)
		else {
			return res.status(501).json({ 
				error: 'OCR image pas encore implémenté. Utilisez un PDF ou implémentez Tesseract.js/Google Vision',
				hint: 'Pour images, ajouter tesseract.js ou appeler Google Vision API'
			});
		}

		if (!extractedText || extractedText.trim().length < 10) {
			return res.status(400).json({ error: 'Aucun texte extrait du fichier' });
		}

		console.log(`[admin] extracted ${extractedText.length} chars, calling DeepSeek for parsing...`);

		// Appel à DeepSeek V3.1 via OpenAI SDK (compatible avec openrouter.ai)
		const openai = new OpenAI({
			baseURL: 'https://openrouter.ai/api/v1',
			apiKey: process.env.OPENROUTER_API_KEY || '', // Clé OpenRouter pour DeepSeek
			defaultHeaders: {
				'HTTP-Referer': 'https://orderly-server.app',
				'X-Title': 'Orderly Menu Parser'
			}
		});

		const prompt = `Tu es un expert en parsing de menus de restaurant. Transforme le texte ci-dessous en JSON structuré selon ce format EXACT (respecte la structure, les noms de champs et les types) :

{
  "restaurant": {
    "id": "${restaurantId}",
    "name": "${restaurantName}",
    "currency": "${currency || 'TND'}"
  },
  "categories": [
    {
      "name": "Nom de la catégorie",
      "group": "food",
      "items": [
        {
          "id": 1001,
          "name": "Nom du plat",
          "price": 12.50,
          "type": "Type du plat",
          "available": true
        }
      ]
    }
  ]
}

RÈGLES IMPORTANTES :
1. "group" peut être : "food" (plats), "drinks" (boissons soft), ou "spirits" (alcools)
2. Les IDs doivent commencer à 1001 et s'incrémenter (1002, 1003...)
3. "type" décrit la sous-catégorie (ex: "Entrée froide", "Plat tunisien", "Boisson froide")
4. "available" est toujours true par défaut
5. Conserve les noms EXACTS des plats du menu (ne traduis pas, ne modifie pas)
6. Si le prix n'est pas clair, mets 0
7. IMPORTANT: Si un article a des variantes séparées par " / " (ex: "Coca / Fanta / Sprite"), crée un article SÉPARÉ pour chaque variante avec le même prix
8. Exemples de séparation :
   - "Coca / Fanta / Sprite" → 3 articles: "Coca", "Fanta", "Sprite"
   - "Jus (Orange / Citron)" → 2 articles: "Jus Orange", "Jus Citron"
   - "Pastis 51 / Ricard" → 2 articles: "Pastis 51", "Ricard"
9. Retourne UNIQUEMENT le JSON valide, sans texte avant/après

TEXTE DU MENU :
${extractedText}`;

		const completion = await openai.chat.completions.create({
			model: 'deepseek/deepseek-chat-v3.1:free',
			messages: [{ role: 'user', content: prompt }],
			temperature: 0.1, // Faible pour précision
			max_tokens: 8000
		});

		const responseText = completion.choices[0]?.message?.content || '';
		console.log(`[admin] DeepSeek response length: ${responseText.length}`);

		// Extraire le JSON (parfois il y a du texte avant/après)
		const jsonMatch = responseText.match(/\{[\s\S]*\}/);
		if (!jsonMatch) {
			console.error('[admin] No JSON found in response:', responseText.substring(0, 200));
			return res.status(500).json({ error: 'Impossible d\'extraire le JSON de la réponse IA' });
		}

		const parsedMenu = JSON.parse(jsonMatch[0]);
		
		// Validation basique
		if (!parsedMenu.restaurant || !parsedMenu.categories) {
			return res.status(500).json({ error: 'JSON invalide (structure incorrecte)' });
		}

		console.log(`[admin] Successfully parsed menu with ${parsedMenu.categories.length} categories`);
		return res.json({ ok: true, menu: parsedMenu });
	} catch (e) {
		console.error('[admin] parse menu error', e);
		return res.status(500).json({ error: e.message || 'Erreur parsing menu' });
	}
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
	console.log(`Serveur démarré sur http://localhost:${PORT}`);
});


