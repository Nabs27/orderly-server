const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const fs = require('fs');
const path = require('path');
const fsp = fs.promises;

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
            return res.json(augmentWithOriginal(menu));
        }

        const translated = await getTranslatedMenuWithCache(menu, restaurantId, lng, sourceMTime, forceRefresh);
        console.log('[menu] translated menu served');
        return res.json(translated);
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

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
	console.log(`Serveur démarré sur http://localhost:${PORT}`);
});


