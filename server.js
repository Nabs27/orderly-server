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
const PDFDocument = require('pdfkit');

const app = express();
const server = http.createServer(app);
// ⚙️ Socket.IO keepalive tunables (réduire trafic idle pour sleep Railway)
const SOCKET_PING_INTERVAL = parseInt(process.env.SOCKET_PING_INTERVAL || '30000', 10); // 30s
const SOCKET_PING_TIMEOUT = parseInt(process.env.SOCKET_PING_TIMEOUT || '20000', 10);   // 20s
const io = new Server(server, {
	cors: { origin: '*', methods: ['GET', 'POST', 'PATCH'] },
	pingInterval: SOCKET_PING_INTERVAL,
	pingTimeout: SOCKET_PING_TIMEOUT,
});
console.log(`[socket] pingInterval=${SOCKET_PING_INTERVAL}ms, pingTimeout=${SOCKET_PING_TIMEOUT}ms`);

// Variables globales pour l'index du menu
var MENU_ITEMS = [];
var MENU_BY_NAME = new Map();

// Variables globales pour le système de crédit client
let clientCredits = [];
let nextClientId = 1;

// 🆕 Base de clients vide - prêt pour les vrais clients
// Plus de clients fictifs pour les tests réels

// Fonction pour construire l'index du menu
function buildMenuIndex(){
	try {
		const menuPath = path.join(__dirname, 'data', 'restaurants', 'les-emirs', 'menu.json');
		if (fs.existsSync(menuPath)) {
			const raw = fs.readFileSync(menuPath, 'utf8');
			const json = JSON.parse(raw);
			const cats = Array.isArray(json.categories) ? json.categories : [];
			for (const cat of cats) {
				const items = Array.isArray(cat.items) ? cat.items : [];
				for (const it of items) {
					const obj = {
						id: (it.id != null ? it.id : it.code) || Math.floor(Math.random()*1e7),
						name: it.name || it.label || '',
						price: typeof it.price === 'number' ? it.price : (typeof it.unitPrice === 'number' ? it.unitPrice : 0),
						type: (it.type || it.originalType || cat.group || '').toString()
					};
					if (obj.name) {
						MENU_ITEMS.push(obj);
						MENU_BY_NAME.set(obj.name.toLowerCase(), obj);
					}
				}
			}
			console.log(`[menu] Index construit: ${MENU_ITEMS.length} articles, ${MENU_BY_NAME.size} entrées`);
		} else {
			console.log('[menu] Fichier menu.json non trouvé, utilisation de POPULAR_ITEMS');
		}
	} catch (e) {
		console.log(`[menu] Erreur construction index: ${e.message}, utilisation de POPULAR_ITEMS`);
	}
}

// Construire l'index au démarrage du serveur
buildMenuIndex();

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

// Filtrer uniquement les produits MASQUÉS (hidden=true). Les indisponibles restent visibles.
function filterAvailableItems(menu) {
    const out = JSON.parse(JSON.stringify(menu));
    for (const cat of out.categories || []) {
        cat.items = (cat.items || []).filter(it => it.hidden !== true);
    }
    out.categories = (out.categories || []).filter(cat => (cat.items || []).length > 0);
    return out;
}

// In-memory storage (avec persistance automatique)
let orders = [];
let archivedOrders = []; // Commandes archivées après paiement total
let nextOrderId = 1;
let bills = [];
let archivedBills = []; // Factures archivées
let nextBillId = 1;
let serviceRequests = [];
let nextServiceId = 1;

// 💾 Chemins de persistance
const DATA_DIR = path.join(__dirname, 'data', 'pos');
const ORDERS_FILE = path.join(DATA_DIR, 'orders.json');
const ARCHIVED_ORDERS_FILE = path.join(DATA_DIR, 'archived_orders.json');
const BILLS_FILE = path.join(DATA_DIR, 'bills.json');
const ARCHIVED_BILLS_FILE = path.join(DATA_DIR, 'archived_bills.json');
const SERVICES_FILE = path.join(DATA_DIR, 'services.json');
const COUNTERS_FILE = path.join(DATA_DIR, 'counters.json');

// 💾 Charger les données au démarrage
async function loadPersistedData() {
	try {
		await ensureDir(DATA_DIR);
		
		// Charger les commandes
		if (fs.existsSync(ORDERS_FILE)) {
			const data = await fsp.readFile(ORDERS_FILE, 'utf8');
			orders = JSON.parse(data);
			console.log(`[persistence] ${orders.length} commandes chargées`);
		}
		
		// Charger les commandes archivées
		if (fs.existsSync(ARCHIVED_ORDERS_FILE)) {
			const data = await fsp.readFile(ARCHIVED_ORDERS_FILE, 'utf8');
			archivedOrders = JSON.parse(data);
			console.log(`[persistence] ${archivedOrders.length} commandes archivées chargées`);
		}
		
		// Charger les factures
		if (fs.existsSync(BILLS_FILE)) {
			const data = await fsp.readFile(BILLS_FILE, 'utf8');
			bills = JSON.parse(data);
			console.log(`[persistence] ${bills.length} factures chargées`);
		}
		
		// Charger les factures archivées
		if (fs.existsSync(ARCHIVED_BILLS_FILE)) {
			const data = await fsp.readFile(ARCHIVED_BILLS_FILE, 'utf8');
			archivedBills = JSON.parse(data);
			console.log(`[persistence] ${archivedBills.length} factures archivées chargées`);
		}
		
		// Charger les demandes de service
		if (fs.existsSync(SERVICES_FILE)) {
			const data = await fsp.readFile(SERVICES_FILE, 'utf8');
			serviceRequests = JSON.parse(data);
			console.log(`[persistence] ${serviceRequests.length} demandes de service chargées`);
		}
		
		// Charger les compteurs
		if (fs.existsSync(COUNTERS_FILE)) {
			const data = await fsp.readFile(COUNTERS_FILE, 'utf8');
			const counters = JSON.parse(data);
			nextOrderId = counters.nextOrderId || 1;
			nextBillId = counters.nextBillId || 1;
			nextServiceId = counters.nextServiceId || 1;
			console.log(`[persistence] Compteurs chargés: orderId=${nextOrderId}, billId=${nextBillId}, serviceId=${nextServiceId}`);
		}
	} catch (e) {
		console.error('[persistence] Erreur chargement données:', e);
	}
}

// 💾 Sauvegarder les données
async function savePersistedData() {
	try {
		await ensureDir(DATA_DIR);
		
		// Sauvegarder les commandes
		await fsp.writeFile(ORDERS_FILE, JSON.stringify(orders, null, 2), 'utf8');
		
		// Sauvegarder les commandes archivées
		await fsp.writeFile(ARCHIVED_ORDERS_FILE, JSON.stringify(archivedOrders, null, 2), 'utf8');
		
		// Sauvegarder les factures
		await fsp.writeFile(BILLS_FILE, JSON.stringify(bills, null, 2), 'utf8');
		
		// Sauvegarder les factures archivées
		await fsp.writeFile(ARCHIVED_BILLS_FILE, JSON.stringify(archivedBills, null, 2), 'utf8');
		
		// Sauvegarder les demandes de service
		await fsp.writeFile(SERVICES_FILE, JSON.stringify(serviceRequests, null, 2), 'utf8');
		
		// Sauvegarder les compteurs
		const counters = {
			nextOrderId,
			nextBillId,
			nextServiceId,
			lastSaved: new Date().toISOString()
		};
		await fsp.writeFile(COUNTERS_FILE, JSON.stringify(counters, null, 2), 'utf8');
		
		console.log(`[persistence] Données sauvegardées: ${orders.length} commandes, ${bills.length} factures`);
	} catch (e) {
		console.error('[persistence] Erreur sauvegarde données:', e);
	}
}

// Créer une commande (avec support des sous-notes)
app.post('/orders', (req, res) => {
	console.log('[orders] POST /orders - Body:', JSON.stringify(req.body, null, 2));
	const { table, items, notes, server, covers, noteId, noteName } = req.body || {};
	if (!table || !Array.isArray(items) || items.length === 0) {
		console.log('[orders] Erreur: table ou items manquants');
		return res.status(400).json({ error: 'Requête invalide: table et items requis' });
	}
	
	// 🆕 CORRECTION: Vérifier s'il existe déjà une commande pour cette table
	const existingOrder = orders.find(o => o.table === table && !o.consumptionConfirmed);
	
	if (existingOrder) {
		// Ajouter les articles à la commande existante
		console.log('[orders] Commande existante trouvée:', existingOrder.id, 'pour table', table);
		
		// Initialiser les structures si nécessaire
		if (!existingOrder.mainNote) existingOrder.mainNote = { id: 'main', name: 'Note Principale', covers: existingOrder.covers || 1, items: [], total: 0, paid: false };
		if (!existingOrder.subNotes) existingOrder.subNotes = [];
		
		const itemsTotal = items.reduce((sum, it) => sum + (Number(it.price) * Number(it.quantity || 1)), 0);
		
		if (noteId === 'main' || !noteId) {
			// Ajouter à la note principale
			existingOrder.mainNote.items.push(...items);
			existingOrder.mainNote.total += itemsTotal;
		} else {
			// Ajouter à une sous-note existante ou créer une nouvelle
			let targetSubNote = existingOrder.subNotes.find(n => n.id === noteId);
			if (!targetSubNote) {
				targetSubNote = {
					id: noteId,
					name: noteName || 'Client',
					covers: 1,
					items: [],
					total: 0,
					paid: false,
					createdAt: new Date().toISOString()
				};
				existingOrder.subNotes.push(targetSubNote);
			}
			targetSubNote.items.push(...items);
			targetSubNote.total += itemsTotal;
		}
		
		existingOrder.total += itemsTotal;
		existingOrder.updatedAt = new Date().toISOString();
		
		console.log('[orders] Articles ajoutés à commande existante:', existingOrder.id, 'total:', itemsTotal);
		
		// 💾 Sauvegarder automatiquement
		savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
		
		io.emit('order:updated', existingOrder);
		return res.status(200).json(existingOrder);
	}
	
	// Créer une nouvelle commande seulement si aucune n'existe
	const total = items.reduce((sum, it) => sum + (Number(it.price) * Number(it.quantity || 1)), 0);
	
	const newOrder = {
		id: nextOrderId++,
		table,
		server: server || 'unknown',
		covers: covers || 1,
		notes: notes || '',
		status: 'nouvelle',
		consumptionConfirmed: false,
		createdAt: new Date().toISOString(),
		// Structure des notes
		mainNote: {
			id: 'main',
			name: 'Note Principale',
			covers: covers || 1,
			items: noteId === 'main' || !noteId ? items : [],
			total: noteId === 'main' || !noteId ? total : 0,
			paid: false
		},
		subNotes: noteId && noteId !== 'main' ? [{
			id: noteId,
			name: noteName || 'Client',
			covers: 1,
			items: items,
			total: total,
			paid: false,
			createdAt: new Date().toISOString()
		}] : [],
		total
	};
	
	orders.push(newOrder);
	console.log('[orders] Nouvelle commande créée:', newOrder.id, 'pour table', table, 'total:', total, 'note:', noteId || 'main');
	
	// 💾 Sauvegarder automatiquement
	savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
	
	io.emit('order:new', newOrder);
	return res.status(201).json(newOrder);
});

// Lister commandes (option table=...)
app.get('/orders', (req, res) => {
	const { table } = req.query;
	// 🆕 Filtrer les commandes archivées
	const activeOrders = orders.filter(o => o.status !== 'archived');
	const list = table ? activeOrders.filter(o => String(o.table) === String(table)) : activeOrders;
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
	savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
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

// Ajouter une sous-note à une commande existante
app.post('/orders/:id/subnotes', (req, res) => {
	const id = Number(req.params.id);
	const order = orders.find(o => o.id === id);
	if (!order) return res.status(404).json({ error: 'Commande introuvable' });
	
	const { name, covers, items } = req.body || {};
	if (!name) return res.status(400).json({ error: 'Nom de la note requis' });
	
	// Initialiser subNotes si nécessaire (pour anciennes commandes)
	if (!order.subNotes) order.subNotes = [];
	
	const total = (items || []).reduce((sum, it) => sum + (Number(it.price) * Number(it.quantity || 1)), 0);
	const subNote = {
		id: `sub_${Date.now()}`,
		name,
		covers: covers || 1,
		items: items || [],
		total,
		paid: false,
		createdAt: new Date().toISOString()
	};
	
	order.subNotes.push(subNote);
	order.total += total;
	order.updatedAt = new Date().toISOString();
	
	console.log('[orders] Sous-note créée:', subNote.id, 'pour commande', id, 'nom:', name);
	savePersistedData().catch(e => console.error('[orders] Erreur sauvegarde:', e));
	io.emit('order:updated', order);
	return res.status(201).json({ ok: true, subNote, order });
});

// Ajouter des articles à une note spécifique
app.post('/orders/:id/notes/:noteId/items', (req, res) => {
	const id = Number(req.params.id);
	const noteId = req.params.noteId;
	const order = orders.find(o => o.id === id);
	if (!order) return res.status(404).json({ error: 'Commande introuvable' });
	
	const { items } = req.body || {};
	if (!items || !Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'Articles requis' });
	}
	
	// Initialiser les structures si nécessaire
	if (!order.mainNote) order.mainNote = { id: 'main', name: 'Note Principale', covers: order.covers || 1, items: [], total: 0, paid: false };
	if (!order.subNotes) order.subNotes = [];
	
	let targetNote;
	if (noteId === 'main') {
		targetNote = order.mainNote;
	} else {
		targetNote = order.subNotes.find(n => n.id === noteId);
	}
	
	if (!targetNote) return res.status(404).json({ error: 'Note introuvable' });
	
	const itemsTotal = items.reduce((sum, it) => sum + (Number(it.price) * Number(it.quantity || 1)), 0);
	targetNote.items = targetNote.items || [];
	targetNote.items.push(...items);
	targetNote.total = (targetNote.total || 0) + itemsTotal;
	order.total += itemsTotal;
	order.updatedAt = new Date().toISOString();
	
	console.log('[orders] Articles ajoutés à note', noteId, 'de commande', id, 'total:', itemsTotal);
	io.emit('order:updated', order);
	return res.json({ ok: true, order });
});

// Transférer des articles entre notes/tables
app.post('/api/pos/transfer-items', (req, res) => {
	const { fromTable, fromOrderId, fromNoteId, toTable, toOrderId, toNoteId, items, createNote, noteName, createTable, tableNumber, covers } = req.body || {};
	
	if (!fromTable || !items || !Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'Paramètres manquants' });
	}
	
	console.log('[transfer] Transfert:', items.length, 'articles de table', fromTable, 'note', fromNoteId, 'vers table', toTable || 'nouvelle table', 'createNote:', createNote, 'noteName:', noteName);
	
	// Trouver la commande source
	const fromOrder = orders.find(o => String(o.table) === String(fromTable) && (fromOrderId ? o.id === Number(fromOrderId) : true));
	if (!fromOrder) return res.status(404).json({ error: 'Commande source introuvable' });
	
	// Initialiser structures si nécessaire
	if (!fromOrder.mainNote) fromOrder.mainNote = { id: 'main', name: 'Note Principale', covers: fromOrder.covers || 1, items: fromOrder.items || [], total: fromOrder.total || 0, paid: false };
	if (!fromOrder.subNotes) fromOrder.subNotes = [];
	
	// Trouver la note source
	let fromNote;
	if (!fromNoteId || fromNoteId === 'main') {
		fromNote = fromOrder.mainNote;
	} else {
		fromNote = fromOrder.subNotes.find(n => n.id === fromNoteId);
	}
	if (!fromNote) return res.status(404).json({ error: 'Note source introuvable' });
	
	// Calculer le total des articles à transférer
	const transferTotal = items.reduce((sum, it) => sum + (Number(it.price) * Number(it.quantity || 1)), 0);
	
	// Retirer les articles de la note source
	items.forEach(transferItem => {
		const idx = fromNote.items.findIndex(it => 
			it.id === transferItem.id && it.name === transferItem.name
		);
		if (idx !== -1) {
			const existing = fromNote.items[idx];
			if (existing.quantity > transferItem.quantity) {
				existing.quantity -= transferItem.quantity;
			} else {
				fromNote.items.splice(idx, 1);
			}
		}
	});
	fromNote.total -= transferTotal;
	fromOrder.total -= transferTotal;
	
	// Créer ou trouver la commande destination
	let toOrder;
	if (createTable && tableNumber) {
		// Créer une nouvelle table/commande
		toOrder = {
			id: nextOrderId++,
			table: tableNumber,
			server: fromOrder.server,
			covers: covers || 1,
			notes: '',
			status: 'nouvelle',
			consumptionConfirmed: false,
			createdAt: new Date().toISOString(),
			mainNote: {
				id: 'main',
				name: 'Note Principale',
				covers: covers || 1,
				items: createNote ? [] : items,
				total: createNote ? 0 : transferTotal,
				paid: false
			},
			subNotes: createNote ? [{
				id: `sub_${Date.now()}`,
				name: noteName || 'Client',
				covers: 1,
				items: items,
				total: transferTotal,
				paid: false,
				createdAt: new Date().toISOString()
			}] : [],
			total: transferTotal
		};
		orders.push(toOrder);
		console.log('[transfer] Nouvelle table créée:', tableNumber);
		
		// Émettre événement pour notifier le plan de table
		const tableCreatedEvent = {
			tableNumber: tableNumber,
			server: fromOrder.server,
			covers: covers,
			orderId: toOrder.id,
			total: transferTotal
		};
		console.log('[transfer] Émission événement table:created:', tableCreatedEvent);
		io.emit('table:created', tableCreatedEvent);
	} else {
		// Utiliser table existante
		console.log(`[transfer] Recherche commande pour table ${toTable}, toOrderId: ${toOrderId}`);
		console.log(`[transfer] Commandes disponibles: ${orders.map(o => `table:${o.table}, id:${o.id}`).join(', ')}`);
		
		toOrder = orders.find(o => String(o.table) === String(toTable) && (toOrderId ? o.id === Number(toOrderId) : true));
		
		if (!toOrder) {
			console.log(`[transfer] ERREUR: Aucune commande trouvée pour table ${toTable}`);
			return res.status(404).json({ error: 'Table destination introuvable' });
		}
		
		console.log(`[transfer] Commande trouvée: ID ${toOrder.id}, table ${toOrder.table}`);
		
		// Initialiser structures si nécessaire
		if (!toOrder.mainNote) toOrder.mainNote = { id: 'main', name: 'Note Principale', covers: toOrder.covers || 1, items: [], total: 0, paid: false };
		if (!toOrder.subNotes) toOrder.subNotes = [];
		
		// Trouver ou créer la note destination
		let toNote;
		
		// 🔥 DÉTECTION AUTOMATIQUE : Si on transfère depuis une sous-note vers une autre table,
		// créer automatiquement une sous-note dans la destination (sauf si noteName est fourni)
		const transferringFromSubNote = fromNoteId && fromNoteId !== 'main';
		const shouldAutoCreateNote = transferringFromSubNote && !createNote && !noteName && !toNoteId;
		
		if (shouldAutoCreateNote) {
			// Récupérer le nom de la note source
			const fromNote = fromOrder.subNotes?.find(n => n.id === fromNoteId);
			const autoNoteName = fromNote?.name || 'Client';
			
			toNote = {
				id: `sub_${Date.now()}`,
				name: autoNoteName,
				covers: fromNote?.covers || 1,
				items: items,
				total: transferTotal,
				paid: false,
				createdAt: new Date().toISOString()
			};
			toOrder.subNotes.push(toNote);
			console.log('[transfer] ✨ Sous-note auto-créée:', autoNoteName, '(détection transfert de sous-note)');
		} else if (createNote && noteName) {
			// Créer une nouvelle sous-note (demandée explicitement)
			toNote = {
				id: `sub_${Date.now()}`,
				name: noteName,
				covers: 1,
				items: items,
				total: transferTotal,
				paid: false,
				createdAt: new Date().toISOString()
			};
			toOrder.subNotes.push(toNote);
			console.log('[transfer] Nouvelle sous-note créée:', noteName);
		} else {
			// Utiliser note existante
			if (!toNoteId || toNoteId === 'main') {
				toNote = toOrder.mainNote;
			} else {
				console.log('[transfer] Recherche note destination:', toNoteId, 'dans', toOrder.subNotes.map(n => n.id));
				toNote = toOrder.subNotes.find(n => n.id === toNoteId);
			}
			if (!toNote) {
				console.log('[transfer] ERREUR: Note destination introuvable:', toNoteId);
				console.log('[transfer] Notes disponibles:', toOrder.subNotes.map(n => ({ id: n.id, name: n.name })));
				return res.status(404).json({ error: 'Note destination introuvable' });
			}
			
			// Ajouter les articles
			toNote.items = toNote.items || [];
			toNote.items.push(...items);
			toNote.total += transferTotal;
		}
		
		toOrder.total += transferTotal;
	}
	
	// 🧹 Nettoyer : Supprimer les sous-notes vides après transfert
	if (fromOrder.subNotes && fromOrder.subNotes.length > 0) {
		const beforeCount = fromOrder.subNotes.length;
		fromOrder.subNotes = fromOrder.subNotes.filter(note => 
			note.items && note.items.length > 0
		);
		const afterCount = fromOrder.subNotes.length;
		if (beforeCount > afterCount) {
			console.log('[transfer] 🧹 Nettoyage: ${beforeCount - afterCount} sous-note(s) vide(s) supprimée(s)');
		}
	}
	
	fromOrder.updatedAt = new Date().toISOString();
	toOrder.updatedAt = new Date().toISOString();
	
	console.log('[transfer] Transfert réussi:', items.length, 'articles -', transferTotal, 'TND');
	savePersistedData().catch(e => console.error('[transfer] Erreur sauvegarde:', e));
	io.emit('order:updated', fromOrder);
	io.emit('order:updated', toOrder);
	
	return res.json({ 
		ok: true, 
		fromOrder, 
		toOrder,
		transferred: { items: items.length, total: transferTotal }
	});
});

// 🆕 Endpoint dédié pour supprimer des articles d'une note spécifique (pour les paiements)
app.delete('/api/pos/orders/:orderId/notes/:noteId/items', async (req, res) => {
	console.log('[DEBUG] DELETE endpoint appelé:', req.url);
	console.log('[DEBUG] Params:', req.params);
	console.log('[DEBUG] Body:', req.body);
	
	const { orderId, noteId } = req.params;
	const { items } = req.body || {};
	
	if (!items || !Array.isArray(items) || items.length === 0) {
		console.log('[DEBUG] Erreur: Articles manquants');
		return res.status(400).json({ error: 'Articles à supprimer manquants' });
	}
	
	console.log('[payment] Suppression:', items.length, 'articles de commande', orderId, 'note', noteId);
	
	// Trouver la commande
	console.log('[DEBUG] Recherche commande ID:', orderId, 'dans', orders.length, 'commandes');
	const order = orders.find(o => o.id === Number(orderId));
	if (!order) {
		console.log('[DEBUG] Commande introuvable:', orderId);
		return res.status(404).json({ error: 'Commande introuvable' });
	}
	console.log('[DEBUG] Commande trouvée:', order.id, 'table:', order.table);
	
	// Initialiser structures si nécessaire
	if (!order.mainNote) order.mainNote = { id: 'main', name: 'Note Principale', covers: order.covers || 1, items: order.items || [], total: order.total || 0, paid: false };
	if (!order.subNotes) order.subNotes = [];
	
	// Trouver la note
	let targetNote;
	if (!noteId || noteId === 'main') {
		targetNote = order.mainNote;
		console.log('[DEBUG] Note principale trouvée:', targetNote?.id, 'articles:', targetNote?.items?.length);
	} else {
		targetNote = order.subNotes.find(n => n.id === noteId);
		console.log('[DEBUG] Recherche sous-note:', noteId, 'dans', order.subNotes.length, 'sous-notes');
		console.log('[DEBUG] Sous-notes disponibles:', order.subNotes.map(n => ({id: n.id, name: n.name, items: n.items?.length})));
	}
	if (!targetNote) {
		console.log('[DEBUG] Note introuvable:', noteId);
		return res.status(404).json({ error: 'Note introuvable' });
	}
	console.log('[DEBUG] Note trouvée:', targetNote.id, 'articles avant suppression:', targetNote.items?.length);
	
	// Calculer le total des articles à supprimer
	let removedTotal = 0;
	
	// Supprimer les articles de la note
	console.log('[DEBUG] Articles à supprimer:', items.length);
	items.forEach((itemToRemove, index) => {
		console.log('[DEBUG] Suppression article', index + 1, ':', itemToRemove);
		const idx = targetNote.items.findIndex(it => 
			it.id === itemToRemove.id && it.name === itemToRemove.name
		);
		console.log('[DEBUG] Index trouvé:', idx, 'dans', targetNote.items.length, 'articles');
		
		if (idx !== -1) {
			const existing = targetNote.items[idx];
			const quantityToRemove = Number(itemToRemove.quantity || 1);
			const itemTotal = Number(existing.price) * quantityToRemove;
			
			console.log('[DEBUG] Avant suppression - Qté existante:', existing.quantity, 'Qté à supprimer:', quantityToRemove);
			
			if (existing.quantity > quantityToRemove) {
				existing.quantity -= quantityToRemove;
				console.log('[DEBUG] Qté réduite à:', existing.quantity);
			} else {
				targetNote.items.splice(idx, 1);
				console.log('[DEBUG] Article complètement supprimé');
			}
			
			removedTotal += itemTotal;
			console.log('[payment] Article supprimé:', existing.name, 'qté:', quantityToRemove, 'total:', itemTotal);
		} else {
			console.log('[DEBUG] Article non trouvé:', itemToRemove);
		}
	});
	console.log('[DEBUG] Articles après suppression:', targetNote.items?.length);
	
	// Recalculer les totaux
	targetNote.total = Math.max(0, targetNote.total - removedTotal);
	order.total = Math.max(0, order.total - removedTotal);
	order.updatedAt = new Date().toISOString();
	
	console.log('[payment] Articles supprimés de la note', noteId, 'total retiré:', removedTotal);
	console.log('[payment] Nouveau total note:', targetNote.total, 'Nouveau total commande:', order.total);
	
	// 🆕 Si la note est maintenant vide (total = 0), la supprimer complètement
	let noteRemoved = false;
	if (targetNote.total === 0 && noteId !== 'main') {
		// Supprimer la sous-note de la liste
		const noteIndex = order.subNotes.findIndex(n => n.id === noteId);
		if (noteIndex !== -1) {
			const removedNote = order.subNotes.splice(noteIndex, 1)[0];
			console.log('[payment] Sous-note supprimée complètement:', noteId, 'Nom:', removedNote.name);
			noteRemoved = true;
			
			// 🆕 Archiver la note dans l'historique des factures (asynchrone)
			(async () => {
				try {
					const archivedNote = {
						...removedNote,
						archivedAt: new Date().toISOString(),
						table: order.table,
						orderId: order.id,
						paymentStatus: 'paid'
					};
					
					// Sauvegarder dans l'historique (on peut utiliser un fichier JSON séparé)
					const historyPath = path.join(__dirname, 'data', 'pos', 'archived_notes.json');
					let archivedNotes = [];
					try {
						const historyData = await fsp.readFile(historyPath, 'utf8');
						archivedNotes = JSON.parse(historyData);
					} catch (e) {
						// Fichier n'existe pas encore, créer un tableau vide
						archivedNotes = [];
					}
					
					archivedNotes.push(archivedNote);
					await fsp.writeFile(historyPath, JSON.stringify(archivedNotes, null, 2));
					console.log('[payment] Note archivée dans l\'historique:', noteId);
				} catch (e) {
					console.error('[payment] Erreur archivage note:', e);
					// Ne pas faire échouer le paiement pour cette erreur
				}
			})();
		}
	}
	
	// 🆕 Si la commande est maintenant complètement vide, l'archiver
	let orderArchived = false;
	if (order.mainNote.total === 0 && order.subNotes.length === 0) {
		console.log('[payment] Commande vide, archivage automatique:', order.id);
		
		// Marquer comme archivée
		order.status = 'archived';
		order.archivedAt = new Date().toISOString();
		
		// Déplacer vers les archives
		archivedOrders.push(order);
		
		// Retirer de la liste active
		const orderIndex = orders.findIndex(o => o.id === order.id);
		if (orderIndex !== -1) {
			orders.splice(orderIndex, 1);
			orderArchived = true;
		}
		
		// Sauvegarder
		savePersistedData().catch(e => console.error('[payment] Erreur sauvegarde:', e));
		
		console.log('[payment] Commande archivée:', order.id, 'table:', order.table);
	}
	
	// Émettre événement pour synchronisation temps réel
	if (orderArchived) {
		io.emit('order:archived', { orderId: order.id, table: order.table });
	} else {
		io.emit('order:updated', order);
	}
	
	return res.json({ 
		ok: true, 
		order: orderArchived ? null : order,
		removedItems: items.length,
		removedTotal: removedTotal,
		noteRemoved: noteRemoved,
		orderArchived: orderArchived
	});
});

// 🆕 Endpoint pour consulter l'historique des notes archivées
app.get('/api/pos/archived-notes', async (req, res) => {
	const { table, orderId, dateFrom, dateTo } = req.query;
	
	try {
		const historyPath = path.join(__dirname, 'data', 'pos', 'archived_notes.json');
		let archivedNotes = [];
		
		try {
			const historyData = await fsp.readFile(historyPath, 'utf8');
			archivedNotes = JSON.parse(historyData);
		} catch (e) {
			// Fichier n'existe pas encore
			return res.json({ archivedNotes: [] });
		}
		
		// Filtrer selon les paramètres
		let filteredNotes = archivedNotes;
		
		if (table) {
			filteredNotes = filteredNotes.filter(note => String(note.table) === String(table));
		}
		
		if (orderId) {
			filteredNotes = filteredNotes.filter(note => note.orderId === Number(orderId));
		}
		
		if (dateFrom) {
			const fromDate = new Date(dateFrom);
			filteredNotes = filteredNotes.filter(note => new Date(note.archivedAt) >= fromDate);
		}
		
		if (dateTo) {
			const toDate = new Date(dateTo);
			filteredNotes = filteredNotes.filter(note => new Date(note.archivedAt) <= toDate);
		}
		
		// Trier par date d'archivage (plus récent en premier)
		filteredNotes.sort((a, b) => new Date(b.archivedAt) - new Date(a.archivedAt));
		
		console.log('[history] Consultation historique:', filteredNotes.length, 'notes trouvées');
		
		return res.json({ 
			archivedNotes: filteredNotes,
			total: filteredNotes.length
		});
	} catch (e) {
		console.error('[history] Erreur consultation historique:', e);
		return res.status(500).json({ error: 'Erreur lors de la consultation de l\'historique' });
	}
});

// 🆕 Transférer une table COMPLÈTE vers une autre table
app.post('/api/pos/transfer-complete-table', (req, res) => {
	const { fromTable, toTable, server, createTable, covers } = req.body || {};
	
	if (!fromTable || !toTable) {
		return res.status(400).json({ error: 'Tables source et destination requises' });
	}
	
	if (fromTable === toTable) {
		return res.status(400).json({ error: 'Les tables source et destination doivent être différentes' });
	}
	
	console.log('[transfer-complete] Transfert COMPLET de table', fromTable, 'vers', toTable, 'createTable:', createTable);
	
	// Récupérer toutes les commandes de la table source
	const fromOrders = orders.filter(o => String(o.table) === String(fromTable));
	
	if (fromOrders.length === 0) {
		return res.status(404).json({ error: 'Aucune commande sur la table source' });
	}
	
	// Calculer le total global
	const totalAmount = fromOrders.reduce((sum, o) => sum + Number(o.total || 0), 0);
	
	// Changer simplement le numéro de table pour toutes les commandes
	fromOrders.forEach(order => {
		order.table = toTable;
		order.updatedAt = new Date().toISOString();
		console.log('[transfer-complete] Commande', order.id, 'transférée de table', fromTable, 'vers', toTable);
	});
	
	console.log('[transfer-complete] ${fromOrders.length} commande(s) transférée(s)');
	savePersistedData().catch(e => console.error('[transfer-complete] Erreur sauvegarde:', e));
	
	// Émettre événements pour mise à jour en temps réel
	fromOrders.forEach(order => io.emit('order:updated', order));
	io.emit('table:transferred', { 
		fromTable, 
		toTable, 
		ordersCount: fromOrders.length,
		server: server,
		covers: covers || 1,
		total: totalAmount,
		createTable: createTable
	});
	
	return res.json({ 
		ok: true, 
		message: `Table ${fromTable} transférée vers ${toTable}`,
		ordersTransferred: fromOrders.length,
		orders: fromOrders
	});
});

// 🆕 Transférer la responsabilité d'une table à un autre serveur
app.post('/api/pos/transfer-server', (req, res) => {
	const { table, newServer } = req.body || {};
	
	if (!table || !newServer) {
		return res.status(400).json({ error: 'Table et nouveau serveur requis' });
	}
	
	console.log('[transfer-server] Changement serveur table', table, 'vers', newServer);
	
	// Récupérer toutes les commandes de la table
	const tableOrders = orders.filter(o => String(o.table) === String(table));
	
	if (tableOrders.length === 0) {
		return res.status(404).json({ error: 'Aucune commande sur cette table' });
	}
	
	// Mettre à jour le serveur pour toutes les commandes
	tableOrders.forEach(order => {
		order.server = newServer;
		order.updatedAt = new Date().toISOString();
	});
	
	console.log('[transfer-server] ${tableOrders.length} commande(s) réassignée(s) à', newServer);
	savePersistedData().catch(e => console.error('[transfer-server] Erreur sauvegarde:', e));
	
	// Émettre événement pour mise à jour en temps réel
	io.emit('server:transferred', { table, newServer, ordersCount: tableOrders.length });
	
	return res.json({ 
		ok: true, 
		message: `Table ${table} transférée au serveur ${newServer}`,
		ordersUpdated: tableOrders.length
	});
});

// Créer une facture pour une table
app.post('/bills', (req, res) => {
	console.log('[bills] POST /bills - Body:', JSON.stringify(req.body, null, 2));
	const { table } = req.body || {};
	if (!table) {
		console.log('[bills] Erreur: table manquante');
		return res.status(400).json({ error: 'Table requise' });
	}
	const tableOrders = orders.filter(o => String(o.table) === String(table));
	console.log('[bills] Commandes trouvées pour table', table, ':', tableOrders.length);
	if (tableOrders.length === 0) {
		console.log('[bills] Erreur: aucune commande pour table', table);
		return res.status(404).json({ error: 'Aucune commande pour cette table' });
	}
	const total = tableOrders.reduce((s,o)=> s + Number(o.total||0), 0);
	const bill = { id: nextBillId++, table, orderIds: tableOrders.map(o=>o.id), total, payments: [], createdAt: new Date().toISOString() };
	bills.push(bill);
	console.log('[bills] Facture créée:', bill.id, 'pour table', table, 'total:', total);
	savePersistedData().catch(e => console.error('[bills] Erreur sauvegarde:', e));
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
	console.log('[bills] POST /bills/' + req.params.id + '/pay - Body:', JSON.stringify(req.body, null, 2));
	const id = Number(req.params.id);
	const bill = bills.find(b => b.id === id);
	if (!bill) {
		console.log('[bills] Erreur: facture', id, 'introuvable');
		return res.status(404).json({ error: 'Facture introuvable' });
	}
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
		
		// 🔥 Compatibilité avec nouvelle structure (mainNote + subNotes)
		let allItems = [];
		if (order.items && Array.isArray(order.items)) {
			// Ancienne structure
			allItems = order.items;
		} else {
			// Nouvelle structure : fusionner mainNote + subNotes
			if (order.mainNote && order.mainNote.items) {
				allItems.push(...order.mainNote.items);
			}
			if (order.subNotes && Array.isArray(order.subNotes)) {
				order.subNotes.forEach(note => {
					if (note.items) allItems.push(...note.items);
				});
			}
		}
		
		const line = allItems.find(i => Number(i.id) === Number(itemId));
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
	console.log('[bills] Paiement enregistré:', payment.id, 'montant:', amount, 'pourboire:', tipAmount);
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
// ⚠️ NE SUPPRIME JAMAIS LES COMMANDES - Archive seulement
app.post('/dev/reset', (req, res) => {
    // Permettre en local pour les tests
    const allow = (process.env.NODE_ENV !== 'production') || String(process.env.ALLOW_DEV_RESET || '') === '1';
    if (!allow) {
        return res.status(403).json({ error: 'Forbidden in production' });
    }
    
    const { table, clearConsumption, forceFullReset, fullClean } = req.body || {};
    
    if (fullClean === true) {
        // Nettoyage complet : supprimer tous les fichiers de persistance
        console.warn('[dev] 🧹 NETTOYAGE COMPLET - Suppression de tous les fichiers de persistance !');
        
        // Supprimer les fichiers de persistance
        const filesToDelete = [
            ORDERS_FILE,
            ARCHIVED_ORDERS_FILE,
            BILLS_FILE,
            ARCHIVED_BILLS_FILE,
            SERVICES_FILE,
            COUNTERS_FILE
        ];
        
        filesToDelete.forEach(filePath => {
            try {
                if (fs.existsSync(filePath)) {
                    fs.unlinkSync(filePath);
                    console.log(`[dev] Fichier supprimé: ${filePath}`);
                }
            } catch (e) {
                console.error(`[dev] Erreur suppression ${filePath}:`, e.message);
            }
        });
        
        // Réinitialiser les tableaux en mémoire
        orders = [];
        archivedOrders = [];
        bills = [];
        archivedBills = [];
        serviceRequests = [];
        
        // Réinitialiser les compteurs
        nextOrderId = 1;
        nextBillId = 1;
        nextServiceId = 1;
        
        // Émettre événement Socket.IO pour notifier les clients
        io.emit('system:reset', { 
            message: 'Système réinitialisé complètement',
            timestamp: new Date().toISOString()
        });
        
        console.log('[dev] 🧹 Nettoyage complet terminé - Système réinitialisé');
        return res.json({ 
            ok: true, 
            message: 'Nettoyage complet terminé',
            reset: { orders: 0, bills: 0, services: 0, counters: { nextOrderId: 1, nextBillId: 1, nextServiceId: 1 } }
        });
    } else if (clearConsumption && table) {
        // Archiver seulement la consommation d'une table spécifique
        const tableOrders = orders.filter(o => String(o.table) === String(table));
        const tableBills = bills.filter(b => String(b.table) === String(table));
        
        // Marquer comme archivées
        tableOrders.forEach(o => { o.status = 'archived'; o.archivedAt = new Date().toISOString(); });
        tableBills.forEach(b => { b.status = 'archived'; b.archivedAt = new Date().toISOString(); });
        
        // Déplacer vers archives
        archivedOrders.push(...tableOrders);
        archivedBills.push(...tableBills);
        
        orders = orders.filter(o => String(o.table) !== String(table));
        bills = bills.filter(b => String(b.table) !== String(table));
        serviceRequests = serviceRequests.filter(s => String(s.table) !== String(table));
        
        console.log(`[dev] consommation table ${table} archivée (${tableOrders.length} commandes)`);
        return res.json({ ok: true, message: `Consommation table ${table} archivée`, archived: tableOrders.length });
    } else if (forceFullReset === true) {
        // Reset complet SEULEMENT si explicitement demandé avec forceFullReset: true
        console.warn('[dev] ⚠️ RESET COMPLET FORCÉ - Toutes les données seront perdues !');
        orders = []; archivedOrders = []; nextOrderId = 1; 
        bills = []; archivedBills = []; nextBillId = 1; 
        serviceRequests = []; nextServiceId = 1;
        console.log('[dev] état serveur complètement réinitialisé');
        return res.json({ ok: true, warning: 'Toutes les données ont été supprimées' });
    } else {
        // Reset partiel (services seulement, préserve commandes et factures)
        const orderCount = orders.length;
        const billCount = bills.length;
        serviceRequests = []; nextServiceId = 1;
        console.log(`[dev] services réinitialisés (${orderCount} commandes et ${billCount} factures préservées)`);
        return res.json({ 
            ok: true, 
            message: 'Services réinitialisés, commandes préservées',
            preserved: { orders: orderCount, bills: billCount }
        });
    }
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

// ==================== API CRÉDIT CLIENT ====================

// Récupérer tous les clients avec leur solde
app.get('/api/credit/clients', (req, res) => {
	try {
		const clientsWithBalance = clientCredits.map(client => {
			const debits = client.transactions.filter(t => t.type === 'DEBIT').reduce((sum, t) => sum + t.amount, 0);
			const credits = client.transactions.filter(t => t.type === 'CREDIT').reduce((sum, t) => sum + t.amount, 0);
			const balance = debits - credits;
			
			return {
				id: client.id,
				name: client.name,
				phone: client.phone,
				balance: balance,
				lastTransaction: client.transactions.length > 0 ? client.transactions[client.transactions.length - 1].date : null
			};
		});
		
		// Trier par solde décroissant (plus gros dettes en premier)
		clientsWithBalance.sort((a, b) => b.balance - a.balance);
		
		res.json(clientsWithBalance);
	} catch (e) {
		console.error('[credit] Erreur récupération clients:', e);
		res.status(500).json({ error: 'Erreur serveur' });
	}
});

// Récupérer un client spécifique avec son historique
app.get('/api/credit/clients/:id', (req, res) => {
	try {
		const clientId = parseInt(req.params.id);
		const client = clientCredits.find(c => c.id === clientId);
		
		if (!client) {
			return res.status(404).json({ error: 'Client introuvable' });
		}
		
		const debits = client.transactions.filter(t => t.type === 'DEBIT').reduce((sum, t) => sum + t.amount, 0);
		const credits = client.transactions.filter(t => t.type === 'CREDIT').reduce((sum, t) => sum + t.amount, 0);
		const balance = debits - credits;
		
		// Trier les transactions par date décroissante
		const sortedTransactions = [...client.transactions].sort((a, b) => new Date(b.date) - new Date(a.date));
		
		res.json({
			id: client.id,
			name: client.name,
			phone: client.phone,
			balance: balance,
			transactions: sortedTransactions
		});
	} catch (e) {
		console.error('[credit] Erreur récupération client:', e);
		res.status(500).json({ error: 'Erreur serveur' });
	}
});

// Créer un nouveau client
app.post('/api/credit/clients', (req, res) => {
	try {
		const { name, phone } = req.body || {};
		
		if (!name || !phone) {
			return res.status(400).json({ error: 'Nom et téléphone requis' });
		}
		
		// Vérifier si le client existe déjà
		const existingClient = clientCredits.find(c => 
			c.name.toLowerCase() === name.toLowerCase() || c.phone === phone
		);
		
		if (existingClient) {
			return res.status(409).json({ error: 'Client déjà existant' });
		}
		
		const newClient = {
			id: nextClientId++,
			name: name.trim(),
			phone: phone.trim(),
			transactions: []
		};
		
		clientCredits.push(newClient);
		
		res.status(201).json(newClient);
	} catch (e) {
		console.error('[credit] Erreur création client:', e);
		res.status(500).json({ error: 'Erreur serveur' });
	}
});

// Ajouter une transaction (DÉBIT ou CREDIT)
app.post('/api/credit/clients/:id/transactions', (req, res) => {
	try {
		const clientId = parseInt(req.params.id);
    const { type, amount, description, orderId, ticket } = req.body || {};
    try { console.log('[credit] POST transaction', { type, amount, hasTicket: !!ticket, items: Array.isArray(ticket?.items) ? ticket.items.length : 0 }); } catch {}
		
		if (!type || !amount || !description) {
			return res.status(400).json({ error: 'Type, montant et description requis' });
		}
		
		if (type !== 'DEBIT' && type !== 'CREDIT') {
			return res.status(400).json({ error: 'Type doit être DEBIT ou CREDIT' });
		}
		
		const client = clientCredits.find(c => c.id === clientId);
		if (!client) {
			return res.status(404).json({ error: 'Client introuvable' });
		}
		
    const transaction = {
			id: Date.now(), // ID simple basé sur timestamp
			type: type,
			amount: parseFloat(amount),
			description: description.trim(),
			date: new Date().toISOString(),
      orderId: orderId || null,
      // 🆕 Pièce jointe ticket (pré-addition) pour les dettes
      ticket: ticket || null
		};
		
    client.transactions.push(transaction);
    try { console.log('[credit] saved transaction', { id: transaction.id, hasTicket: !!transaction.ticket, items: Array.isArray(transaction.ticket?.items) ? transaction.ticket.items.length : 0 }); } catch {}
		
		// Calculer le nouveau solde
		const debits = client.transactions.filter(t => t.type === 'DEBIT').reduce((sum, t) => sum + t.amount, 0);
		const credits = client.transactions.filter(t => t.type === 'CREDIT').reduce((sum, t) => sum + t.amount, 0);
		const balance = debits - credits;
		
		res.status(201).json({
			transaction: transaction,
			balance: balance
		});
	} catch (e) {
		console.error('[credit] Erreur ajout transaction:', e);
		res.status(500).json({ error: 'Erreur serveur' });
	}
});

// Paiement automatique sur la commande la plus ancienne
app.post('/api/credit/clients/:id/pay-oldest', (req, res) => {
	try {
		const clientId = parseInt(req.params.id);
		const { amount, paymentMode = 'CREDIT' } = req.body || {};
		
		if (!amount) {
			return res.status(400).json({ error: 'Montant requis' });
		}
		
		const client = clientCredits.find(c => c.id === clientId);
		if (!client) {
			return res.status(404).json({ error: 'Client introuvable' });
		}
		
		// Trouver la transaction DEBIT la plus ancienne non payée
		const unpaidDebits = client.transactions
			.filter(t => t.type === 'DEBIT')
			.sort((a, b) => new Date(a.date) - new Date(b.date)); // Plus ancien en premier
		
		if (unpaidDebits.length === 0) {
			return res.status(400).json({ error: 'Aucune dette à payer' });
		}
		
		const oldestDebit = unpaidDebits[0];
		const paymentAmount = Math.min(parseFloat(amount), oldestDebit.amount);
		
		// Créer la transaction de paiement
		const paymentTransaction = {
			id: Date.now(),
			type: 'CREDIT',
			amount: paymentAmount,
			description: `Paiement partiel - ${paymentMode} (${oldestDebit.description})`,
			date: new Date().toISOString(),
			orderId: oldestDebit.orderId
		};
		
		client.transactions.push(paymentTransaction);
		
		// Calculer le nouveau solde
		const debits = client.transactions.filter(t => t.type === 'DEBIT').reduce((sum, t) => sum + t.amount, 0);
		const credits = client.transactions.filter(t => t.type === 'CREDIT').reduce((sum, t) => sum + t.amount, 0);
		const balance = debits - credits;
		
		res.status(201).json({
			payment: paymentTransaction,
			remainingDebt: oldestDebit.amount - paymentAmount,
			balance: balance,
			message: paymentAmount >= oldestDebit.amount ? 'Dette entièrement payée' : 'Paiement partiel effectué'
		});
	} catch (e) {
		console.error('[credit] Erreur paiement automatique:', e);
		res.status(500).json({ error: 'Erreur serveur' });
	}
});

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
				// compter masqués/indisponibles
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
				if (updates.hidden != null) item.hidden = Boolean(updates.hidden);
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

// ========================================
// 📄 ADMIN API - Génération Factures PDF
// ========================================
app.post('/api/admin/generate-invoice', async (req, res) => {
	console.log('[invoice] POST /api/admin/generate-invoice - Body:', JSON.stringify(req.body, null, 2));
	try {
		const { billId, company, items, total, amountPerPerson, covers, paymentMode, date } = req.body || {};
		
		if (!company?.name || !items || !Array.isArray(items)) {
			return res.status(400).json({ error: 'Données facture incomplètes' });
		}

		console.log(`[invoice] Génération facture PDF pour bill ${billId}, société: ${company.name}`);

		// Créer le dossier invoices s'il n'existe pas
		const invoicesDir = path.join(__dirname, 'public', 'invoices');
		await ensureDir(invoicesDir);

		// Générer le nom du fichier PDF
		const timestamp = Date.now();
		const filename = `facture_${billId}_${timestamp}.pdf`;
		const filepath = path.join(invoicesDir, filename);

		// Créer le PDF
		const doc = new PDFDocument({ margin: 50 });
		const stream = fs.createWriteStream(filepath);
		doc.pipe(stream);

		// En-tête restaurant avec style professionnel
		doc.fontSize(24).text('LES EMIRS', { align: 'center' });
		doc.fontSize(16).text('PORT EL KANTAOUI', { align: 'center' });
		doc.fontSize(12).text('RESTAURANT & BAR', { align: 'center' });
		doc.moveDown(1);
		
		// Ligne de séparation
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(1);
		
		// Informations facture
		doc.fontSize(18).text('FACTURE', { align: 'center' });
		doc.fontSize(12).text(`N° ${billId}`, { align: 'center' });
		doc.fontSize(10).text(`Date: ${new Date(date).toLocaleDateString('fr-FR')}`, { align: 'center' });
		doc.moveDown(2);

		// Informations client
		doc.fontSize(12).text('FACTURÉ À:', { underline: true });
		doc.fontSize(11).text(company.name);
		if (company.address) doc.fontSize(10).text(company.address);
		if (company.phone) doc.fontSize(10).text(`Tél: ${company.phone}`);
		if (company.email) doc.fontSize(10).text(`Email: ${company.email}`);
		if (company.taxNumber) doc.fontSize(10).text(`N° Fiscal: ${company.taxNumber}`);
		doc.moveDown(2);

		// Calculs TVA - logique claire
		const totalHT = total / 1.19; // Total HT (TVA 19%)
		const tva = total - totalHT; // Montant TVA
		const timbreFiscal = 1.0; // Timbre fiscal fixe
		const totalTTC = total; // Total TTC (sans timbre fiscal)
		const totalFinal = totalTTC + timbreFiscal; // Total final avec timbre fiscal

		// Tableau des articles avec alignement parfait
		doc.fontSize(12).text('DÉTAIL DE LA CONSOMMATION:', { underline: true });
		doc.moveDown(0.5);
		
		// En-tête du tableau avec alignement précis
		doc.fontSize(10).text('DÉSIGNATION', 50);
		doc.text('QUANTITÉ', 320, doc.y - 12); // Aligné verticalement
		doc.text('PRIX UNIT. HT', 400, doc.y - 12);
		doc.text('TOTAL HT', 480, doc.y - 12);
		doc.moveDown(0.3);
		
		// Ligne de séparation
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(0.3);
		
		// Article principal avec alignement parfait
		const prixUnitaireHT = totalHT / covers;
		doc.fontSize(11).text(`Menu Restaurant (${covers} personne${covers > 1 ? 's' : ''})`, 50);
		doc.text(`${covers}`, 320, doc.y - 11); // Aligné avec l'en-tête
		doc.text(`${prixUnitaireHT.toFixed(2)} TND`, 400, doc.y - 11);
		doc.text(`${totalHT.toFixed(2)} TND`, 480, doc.y - 11);
		doc.moveDown(0.5);
		
		// Ligne de séparation
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(0.5);

		// Totaux détaillés - alignement à droite
		doc.fontSize(11).text('SOUS-TOTAL HT:', 350);
		doc.text(`${totalHT.toFixed(2)} TND`, 480, doc.y - 11);
		doc.moveDown(0.3);
		
		doc.text('TVA (19%):', 350);
		doc.text(`${tva.toFixed(2)} TND`, 480, doc.y - 11);
		doc.moveDown(0.3);
		
		doc.text('TOTAL TTC:', 350);
		doc.text(`${total.toFixed(2)} TND`, 480, doc.y - 11);
		doc.moveDown(0.3);
		
		doc.text('TIMBRE FISCAL:', 350);
		doc.text(`${timbreFiscal.toFixed(2)} TND`, 480, doc.y - 11);
		doc.moveDown(0.5);
		
		// Ligne de séparation finale
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(0.5);
		
		// Total final en gras - alignement parfait
		doc.fontSize(14).text('TOTAL À PAYER:', 350);
		doc.fontSize(14).text(`${totalFinal.toFixed(2)} TND`, 480, doc.y - 14);

		doc.moveDown(2);

		// Mode de paiement
		doc.moveDown(1);
		doc.fontSize(11).text(`Mode de paiement: ${paymentMode}`, { align: 'center' });
		doc.moveDown(2);

		// Ligne de séparation avant "Merci pour votre visite !"
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(1);
		
		// Message de remerciement
		doc.fontSize(10).text('Merci pour votre visite !', { align: 'center' });
		doc.moveDown(1);
		
		// Ligne de séparation avant les données des Emirs
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(1);
		
		// Données des Emirs étalées sur toute la largeur avec gestion du débordement
		const pageWidth = 500; // Largeur disponible (550 - 50 marges)
		
		// Nom du restaurant
		doc.fontSize(9).text('RESTAURANT LES EMIRS - PORT EL KANTAOUI', 50, doc.y, { 
			width: pageWidth, 
			align: 'center',
			lineGap: 2
		});
		doc.moveDown(0.3);
		
		// Adresse
		doc.fontSize(8).text('Port El Kantaoui, Sousse, Tunisie', 50, doc.y, { 
			width: pageWidth, 
			align: 'center',
			lineGap: 2
		});
		doc.moveDown(0.3);
		
		// Contact et fiscal - divisé en plusieurs lignes si nécessaire
		const contactText = 'Tél: +216 73 240 000 | Email: contact@lesemirs.tn | N° Fiscal: 12345678/A/M/000';
		
		// Vérifier si le texte est trop long et le diviser
		const maxCharsPerLine = 60; // Nombre de caractères par ligne
		if (contactText.length > maxCharsPerLine) {
			// Diviser le texte en plusieurs lignes
			const parts = contactText.split(' | ');
			for (let i = 0; i < parts.length; i++) {
				doc.fontSize(8).text(parts[i], 50, doc.y, { 
					width: pageWidth, 
					align: 'center',
					lineGap: 2
				});
				if (i < parts.length - 1) {
					doc.moveDown(0.2);
				}
			}
		} else {
			// Texte court, affichage normal
			doc.fontSize(8).text(contactText, 50, doc.y, { 
				width: pageWidth, 
				align: 'center',
				lineGap: 2
			});
		}

		// Finaliser le PDF
		doc.end();

		// Attendre que le fichier soit écrit
		await new Promise((resolve, reject) => {
			stream.on('finish', resolve);
			stream.on('error', reject);
		});

		const invoiceData = {
			billId,
			company,
			items,
			total,
			amountPerPerson,
			covers,
			paymentMode,
			date,
			pdfGenerated: true,
			pdfUrl: `/invoices/${filename}`,
			pdfPath: filepath
		};

		console.log(`[invoice] Facture PDF générée: ${filename}`);
		return res.json({ ok: true, invoice: invoiceData });
	} catch (e) {
		console.error('[invoice] Erreur génération facture:', e);
		return res.status(500).json({ error: 'Erreur génération facture' });
	}
});

// Endpoint pour consulter les commandes archivées
app.get('/api/admin/archived-orders', authAdmin, (req, res) => {
	const { table, limit } = req.query;
	let result = archivedOrders;
	
	// Filtrer par table si spécifié
	if (table) {
		result = result.filter(o => String(o.table) === String(table));
	}
	
	// Trier par date (plus récent en premier)
	result = result.sort((a, b) => new Date(b.archivedAt || b.createdAt) - new Date(a.archivedAt || a.createdAt));
	
	// Limiter le nombre de résultats si spécifié
	if (limit) {
		result = result.slice(0, Number(limit));
	}
	
	return res.json({ 
		orders: result, 
		total: archivedOrders.length,
		filtered: result.length 
	});
});

// Endpoint pour consulter les factures archivées
app.get('/api/admin/archived-bills', authAdmin, (req, res) => {
	const { table, limit } = req.query;
	let result = archivedBills;
	
	// Filtrer par table si spécifié
	if (table) {
		result = result.filter(b => String(b.table) === String(table));
	}
	
	// Trier par date (plus récent en premier)
	result = result.sort((a, b) => new Date(b.archivedAt || b.createdAt) - new Date(a.archivedAt || a.createdAt));
	
	// Limiter le nombre de résultats si spécifié
	if (limit) {
		result = result.slice(0, Number(limit));
	}
	
	return res.json({ 
		bills: result, 
		total: archivedBills.length,
		filtered: result.length 
	});
});

// Endpoint pour nettoyer les doublons de sous-notes
app.post('/api/admin/cleanup-duplicate-notes', authAdmin, (req, res) => {
	try {
		const { table } = req.body || {};
		if (!table) return res.status(400).json({ error: 'Table requise' });
		
		const tableOrders = orders.filter(o => String(o.table) === String(table));
		let cleanedCount = 0;
		
		for (const order of tableOrders) {
			if (order.subNotes && Array.isArray(order.subNotes)) {
				// Créer une map pour éviter les doublons par ID
				const uniqueSubNotes = new Map();
				
				for (const subNote of order.subNotes) {
					if (!uniqueSubNotes.has(subNote.id)) {
						uniqueSubNotes.set(subNote.id, subNote);
					} else {
						// Fusionner les items des doublons
						const existing = uniqueSubNotes.get(subNote.id);
						existing.items = existing.items.concat(subNote.items || []);
						existing.total = (existing.total || 0) + (subNote.total || 0);
						cleanedCount++;
					}
				}
				
				// Remplacer par les sous-notes uniques
				order.subNotes = Array.from(uniqueSubNotes.values());
			}
		}
		
		console.log(`[admin] Nettoyage doublons table ${table}: ${cleanedCount} doublons supprimés`);
		savePersistedData().catch(e => console.error('[admin] Erreur sauvegarde:', e));
		
		return res.json({ 
			ok: true, 
			message: `Nettoyage terminé pour table ${table}`,
			duplicatesRemoved: cleanedCount
		});
	} catch (e) {
		console.error('[admin] cleanup duplicate notes error', e);
		return res.status(500).json({ error: 'Erreur nettoyage doublons' });
	}
});

// Endpoint pour nettoyage complet du système (admin uniquement)
app.post('/api/admin/full-reset', authAdmin, (req, res) => {
	try {
		console.log('[admin] 🧹 Demande de nettoyage complet du système');
		
		// Supprimer les fichiers de persistance
		const filesToDelete = [
			ORDERS_FILE,
			ARCHIVED_ORDERS_FILE,
			BILLS_FILE,
			ARCHIVED_BILLS_FILE,
			SERVICES_FILE,
			COUNTERS_FILE
		];
		
		let deletedFiles = 0;
		filesToDelete.forEach(filePath => {
			try {
				if (fs.existsSync(filePath)) {
					fs.unlinkSync(filePath);
					deletedFiles++;
					console.log(`[admin] Fichier supprimé: ${filePath}`);
				}
			} catch (e) {
				console.error(`[admin] Erreur suppression ${filePath}:`, e.message);
			}
		});
		
		// Compter les données avant suppression
		const ordersCount = orders.length;
		const archivedOrdersCount = archivedOrders.length;
		const billsCount = bills.length;
		const archivedBillsCount = archivedBills.length;
		const servicesCount = serviceRequests.length;
		
		// Réinitialiser les tableaux en mémoire
		orders = [];
		archivedOrders = [];
		bills = [];
		archivedBills = [];
		serviceRequests = [];
		
		// Réinitialiser les compteurs
		nextOrderId = 1;
		nextBillId = 1;
		nextServiceId = 1;
		
		// Émettre événement Socket.IO pour notifier les clients
		io.emit('system:reset', { 
			message: 'Système réinitialisé complètement par admin',
			timestamp: new Date().toISOString(),
			deleted: {
				orders: ordersCount,
				archivedOrders: archivedOrdersCount,
				bills: billsCount,
				archivedBills: archivedBillsCount,
				services: servicesCount,
				files: deletedFiles
			}
		});
		
		console.log(`[admin] 🧹 Nettoyage complet terminé: ${ordersCount} commandes, ${billsCount} factures, ${servicesCount} services supprimés`);
		
		return res.json({ 
			ok: true, 
			message: 'Nettoyage complet terminé avec succès',
			deleted: {
				orders: ordersCount,
				archivedOrders: archivedOrdersCount,
				bills: billsCount,
				archivedBills: archivedBillsCount,
				services: servicesCount,
				files: deletedFiles
			},
			reset: { 
				orders: 0, 
				bills: 0, 
				services: 0, 
				counters: { nextOrderId: 1, nextBillId: 1, nextServiceId: 1 } 
			}
		});
	} catch (e) {
		console.error('[admin] Erreur nettoyage complet:', e);
		return res.status(500).json({ error: 'Erreur lors du nettoyage complet' });
	}
});

// 🆕 Endpoint pour remettre à zéro le système (bouton "Remettre à zéro")
app.post('/api/admin/reset-system', authAdmin, async (req, res) => {
	try {
		console.log('[admin] Remise à zéro du système demandée');
		
		// Vider toutes les données
		orders.length = 0;
		bills.length = 0;
		serviceRequests.length = 0;
		archivedOrders.length = 0;
		archivedBills.length = 0;
		
		// Remettre les compteurs à zéro
		nextOrderId = 1;
		nextBillId = 1;
		
		// Nettoyer les fichiers de données persistantes
		try {
			const dataDir = path.join(__dirname, 'data');
			const files = ['orders.json', 'bills.json', 'serviceRequests.json', 'archivedOrders.json', 'archivedBills.json'];
			
			for (const file of files) {
				const filePath = path.join(dataDir, file);
				if (fs.existsSync(filePath)) {
					fs.unlinkSync(filePath);
					console.log(`[admin] Fichier supprimé: ${file}`);
				}
			}
		} catch (fileError) {
			console.warn('[admin] Erreur lors de la suppression des fichiers:', fileError);
		}
		
		// Émettre un événement de reset pour tous les clients connectés
		io.emit('system:reset', { 
			message: 'Système remis à zéro',
			timestamp: new Date().toISOString()
		});
		
		console.log('[admin] Système remis à zéro avec succès');
		
		return res.json({
			ok: true,
			message: 'Système remis à zéro avec succès',
			reset: {
				orders: 0,
				bills: 0,
				serviceRequests: 0,
				archivedOrders: 0,
				archivedBills: 0,
				nextOrderId: 1,
				nextBillId: 1
			}
		});
		
	} catch (e) {
		console.error('[admin] Erreur remise à zéro:', e);
		return res.status(500).json({ error: 'Erreur lors de la remise à zéro' });
	}
});

// 🆕 ADMIN - Réinitialiser le système de crédit client
app.post('/api/admin/credit/reset', authAdmin, (req, res) => {
    try {
        const { clearClients = false } = req.body || {};
        if (clearClients) {
            clientCredits = [];
            nextClientId = 1;
            console.log('[credit] Tous les clients et dettes ont été supprimés');
            return res.json({ ok: true, clients: 0, clearedClients: true });
        }
        // Effacer uniquement les dettes (transactions) et conserver les clients
        clientCredits.forEach(c => c.transactions = []);
        console.log(`[credit] Dettes réinitialisées pour ${clientCredits.length} client(s)`);
        return res.json({ ok: true, clients: clientCredits.length, clearedClients: false });
    } catch (e) {
        console.error('[credit] reset error', e);
        return res.status(500).json({ error: 'Erreur reset crédit' });
	}
});

// Endpoint pour simulation de données réalistes
app.post('/api/admin/simulate-data', authAdmin, (req, res) => {
	try {
		const { mode = 'once', servers = ['ALI', 'FATIMA'], progressive = false } = req.body || {};
		
		// 🎯 Normaliser les noms de serveurs (FATMA -> FATIMA)
		const normalizedServers = servers.map(server => 
			server.toUpperCase() === 'FATMA' ? 'FATIMA' : server.toUpperCase()
		);
		
		console.log(`[simulation] Démarrage simulation mode: ${mode}, serveurs: ${normalizedServers.join(', ')}, progressive: ${progressive}`);
		
		// 🧹 NETTOYER LES ANCIENNES DONNÉES AVANT LA SIMULATION
		console.log('[simulation] Nettoyage des anciennes données...');
		orders.length = 0; // Vider le tableau des commandes
		bills.length = 0; // Vider le tableau des factures
		serviceRequests.length = 0; // Vider les demandes de service
		archivedOrders.length = 0; // Vider les archives
		archivedBills.length = 0; // Vider les archives factures
		nextOrderId = 1; // Remettre à zéro l'ID des commandes
		nextBillId = 1; // Remettre à zéro l'ID des factures
		
		console.log('[simulation] Anciennes données supprimées, démarrage de la nouvelle simulation');
		
		// 🎯 Configuration simulation réaliste avec scénarios prédéfinis
		const SIMULATION_CONFIG = {
			servers: normalizedServers,
			tablesPerServer: [6, 7, 3], // ALI: 6 tables, FATIMA: 7 tables, MOHAMED: 3 tables
			restaurantOpenHours: 4, // Restaurant ouvert depuis 19h (4h de simulation)
			timeSpread: 4 * 60 * 60 * 1000, // 4h en millisecondes (19h-23h)
			// 🆕 Durées de service variables (en minutes)
			serviceDuration: { min: 60, max: 180 }, // 1h à 3h
			// 🆕 Probabilité d'occupation selon l'heure (soirée)
			occupationRates: {
				evening: 0.85  // 85% occupation le soir (21h-24h)
			}
		};
		
		// 🎯 Scénarios de tables prédéfinis pour ALI, FATIMA et MOHAMED (COMMANDES LOGIQUES PAR PERSONNE)
		const TABLE_SCENARIOS = {
			'ALI': [
				{ 
					table: 1, name: 'Soirée Bière', covers: 6, subNotes: 3,
					subNotesData: [
						{ name: 'Ahmed', items: ['Beck\'s', 'Eau Minérale', 'Salade César', 'Entrecôte Maître d\'Hôtel'] },
						{ name: 'Fatma', items: ['Celtia', 'Eau Minérale', 'Carpaccio de Bœuf à l\'Huile de Truffe', 'Seiches Grillées'] },
						{ name: 'Mohamed', items: ['Beck\'s', 'Coca', 'Salade Méchouia', 'Brochettes Mixtes au Romarin'] }
					]
				},
				{ 
					table: 3, name: 'Soirée Cocktails', covers: 4, subNotes: 2,
					subNotesData: [
						{ name: 'Ahmed', items: ['Pastis', 'Eau Minérale', 'Carpaccio de Bœuf à l\'Huile de Truffe'] },
						{ name: 'Fatma', items: ['Pastis', 'Eau Minérale', 'Seiches Grillées', 'Tiramisu'] }
					]
				},
				{ 
					table: 5, name: 'Couple Romantique', covers: 2, subNotes: 2,
					subNotesData: [
						{ name: 'Ahmed', items: ['Coca', 'Eau Minérale', 'Salade Méchouia', 'Ojja au Merguez'] },
						{ name: 'Fatma', items: ['Eau Minérale', 'Salade César', 'Filet de Bœuf au Poivre ou aux Champignons de Paris', 'Tiramisu'] }
					]
				},
				{ 
					table: 7, name: 'Groupe Business', covers: 4, subNotes: 2,
					subNotesData: [
						{ name: 'Ahmed', items: ['Beck\'s', 'Eau Minérale', 'Salade César', 'Médaillons de Filet aux Duo Sauces'] },
						{ name: 'Fatma', items: ['Coca', 'Eau Minérale', 'Salade Méchouia', 'Tiramisu'] }
					]
				},
				{ 
					table: 9, name: 'Famille', covers: 5, subNotes: 3,
					subNotesData: [
						{ name: 'Ahmed', items: ['Coca', 'Eau Minérale', 'Salade Méchouia', 'Ojja aux Crevettes'] },
						{ name: 'Fatma', items: ['Fanta', 'Eau Minérale', 'Salade César', 'Filet de Bœuf au Poivre ou aux Champignons de Paris'] },
						{ name: 'Mohamed', items: ['Coca', 'Eau Minérale', 'Chocolate Moelleux'] }
					]
				},
				{ 
					table: 11, name: 'Amis', covers: 6, subNotes: 3,
					subNotesData: [
						{ name: 'Ahmed', items: ['Beck\'s', 'Eau Minérale', 'Salade César', 'Seiches Grillées'] },
						{ name: 'Fatma', items: ['Celtia', 'Eau Minérale', 'Carpaccio de Bœuf à l\'Huile de Truffe', 'Côte à l\'OS'] },
						{ name: 'Mohamed', items: ['Coca', 'Eau Minérale', 'Salade Méchouia', 'Brochettes Mixtes au Romarin'] }
					]
				}
			],
			'FATIMA': [
				{ 
					table: 2, name: 'Groupe d\'Amis - Paiement Séparé', covers: 8, subNotes: 4,
					subNotesData: [
						{ name: 'Ahmed', items: ['Coca', 'Eau Minérale', 'Salade Méchouia', 'Ojja au Merguez'] },
						{ name: 'Fatma', items: ['Fanta', 'Eau Minérale', 'Carpaccio de Bœuf à l\'Huile de Truffe', 'Mérou Grillé ou avec des Pâtes prix'] },
						{ name: 'Mohamed', items: ['Beck\'s', 'Eau Minérale', 'Salade César', 'Seiches Grillées'] },
						{ name: 'Aicha', items: ['Coca', 'Eau Minérale', 'Tiramisu'] }
					]
				},
				{ 
					table: 4, name: 'Grand Groupe', covers: 10, subNotes: 5,
					subNotesData: [
						{ name: 'Ahmed', items: ['Coca', 'Eau Minérale', 'Salade Méchouia', 'Ojja au Merguez'] },
						{ name: 'Fatma', items: ['Coca', 'Eau Minérale', 'Salade César', 'Émincé de Bœuf Stroganoff & Riz Pilaf'] },
						{ name: 'Mohamed', items: ['Fanta', 'Eau Minérale', 'Côte à l\'OS', 'Tiramisu'] },
						{ name: 'Aicha', items: ['Beck\'s', 'Eau Minérale', 'Salade Méchouia', 'Chocolate Moelleux'] },
						{ name: 'Ali', items: ['Celtia', 'Eau Minérale', 'Salade César', 'Seiches Grillées'] }
					]
				},
				{ 
					table: 6, name: 'Soirée Vin', covers: 4, subNotes: 2,
					subNotesData: [
						{ name: 'Ahmed', items: ['Pastis', 'Eau Minérale', 'Carpaccio de Bœuf à l\'Huile de Truffe'] },
						{ name: 'Fatma', items: ['Pastis', 'Eau Minérale', 'Filet de Loup Sauce au Citron & Œufs de Lompe', 'Tiramisu'] }
					]
				},
				{ 
					table: 8, name: 'Couple + Amis', covers: 6, subNotes: 3,
					subNotesData: [
						{ name: 'Ahmed', items: ['Coca', 'Eau Minérale', 'Salade Méchouia', 'Ojja aux Crevettes'] },
						{ name: 'Fatma', items: ['Fanta', 'Eau Minérale', 'Salade César', 'Filet de Reine et sa Sauce aux Fruits de Mer'] },
						{ name: 'Mohamed', items: ['Coca', 'Eau Minérale', 'Chocolate Moelleux'] }
					]
				},
				{ 
					table: 10, name: 'Groupe Mixte', covers: 7, subNotes: 4,
					subNotesData: [
						{ name: 'Ahmed', items: ['Coca', 'Eau Minérale', 'Salade César', 'Ojja au Merguez'] },
						{ name: 'Fatma', items: ['Beck\'s', 'Eau Minérale', 'Salade Méchouia', 'Seiches Grillées'] },
						{ name: 'Mohamed', items: ['Coca', 'Eau Minérale', 'Brochettes Mixtes au Romarin', 'Tiramisu'] },
						{ name: 'Aicha', items: ['Eau Minérale', 'Salade César', 'Chocolate Moelleux'] }
					]
				},
				{ 
					table: 12, name: 'Soirée Whisky', covers: 5, subNotes: 3,
					subNotesData: [
						{ name: 'Ahmed', items: ['Pastis', 'Eau Minérale', 'Carpaccio de Bœuf à l\'Huile de Truffe', 'Entrecôte Maître d\'Hôtel'] },
						{ name: 'Fatma', items: ['Pastis', 'Eau Minérale', 'Salade César', 'Seiches Grillées', 'Tiramisu'] },
						{ name: 'Mohamed', items: ['Eau Minérale', 'Salade Méchouia', 'Chocolate Moelleux'] }
					]
				},
				{ 
					table: 14, name: 'Famille + Amis', covers: 8, subNotes: 4,
					subNotesData: [
						{ name: 'Ahmed', items: ['Coca', 'Eau Minérale', 'Salade Méchouia', 'Ojja aux Crevettes'] },
						{ name: 'Fatma', items: ['Fanta', 'Eau Minérale', 'Salade César', 'Médaillons de Filet aux Duo Sauces'] },
						{ name: 'Mohamed', items: ['Beck\'s', 'Eau Minérale', 'Seiches Grillées', 'Tiramisu'] },
						{ name: 'Aicha', items: ['Coca', 'Eau Minérale', 'Chocolate Moelleux'] }
					]
				}
			],
			'MOHAMED': [
				{ 
					table: 13, name: 'Groupe VIP', covers: 4, subNotes: 2,
					subNotesData: [
						{ name: 'Ahmed', items: ['Beck\'s', 'Eau Minérale', 'Salade César', 'Entrecôte Maître d\'Hôtel'] },
						{ name: 'Fatma', items: ['Coca', 'Eau Minérale', 'Carpaccio de Bœuf à l\'Huile de Truffe', 'Seiches Grillées'] }
					]
				},
				{ 
					table: 15, name: 'Soirée Privée', covers: 6, subNotes: 3,
					subNotesData: [
						{ name: 'Ahmed', items: ['Pastis', 'Eau Minérale', 'Salade Méchouia', 'Ojja au Merguez', 'Tiramisu'] },
						{ name: 'Fatma', items: ['Fanta', 'Eau Minérale', 'Salade César', 'Médaillons de Filet aux Duo Sauces', 'Chocolate Moelleux'] },
						{ name: 'Mohamed', items: ['Coca', 'Eau Minérale', 'Brochettes Mixtes au Romarin', 'Tiramisu'] }
					]
				},
				{ 
					table: 17, name: 'Réunion Business', covers: 5, subNotes: 2,
					subNotesData: [
						{ name: 'Ahmed', items: ['Beck\'s', 'Eau Minérale', 'Salade César', 'Filet de Bœuf au Poivre ou aux Champignons de Paris'] },
						{ name: 'Fatma', items: ['Coca', 'Eau Minérale', 'Carpaccio de Bœuf à l\'Huile de Truffe', 'Tiramisu'] }
					]
				}
			]
		};
		
		// 🎯 Fonction pour obtenir une quantité réaliste selon le type d'item
		function getRealisticQuantity(item, covers) {
			// Eau: 2-3 bouteilles pour 4-6 personnes
			if (item.name.includes('Eau')) {
				return Math.max(2, Math.ceil(covers / 3));
			}
			
			// Boissons: 1 par personne en moyenne
			if (item.type === 'Boisson froide') {
				return Math.max(1, Math.ceil(covers * 0.8));
			}
			
			// Alcool: 30% de consommation en plus pour le réalisme
			if (item.type === 'Bière') {
				return Math.max(1, Math.ceil(covers * 0.65)); // 65% au lieu de 50%
			}
			
			// Entrées: 1 pour 2 personnes
			if (item.type.includes('Entrée')) {
				return Math.max(1, Math.ceil(covers / 2));
			}
			
			// Plats: 1 par personne
			if (item.type.includes('Plat') || item.type === 'Viande' || item.type === 'Poisson' || item.type === 'Plat tunisien') {
				return Math.max(1, Math.ceil(covers * 0.9));
			}
			
			// Desserts: 1 pour 2 personnes
			if (item.type === 'Dessert') {
				return Math.max(1, Math.ceil(covers / 2));
			}
			
			return Math.max(1, Math.ceil(covers / 2));
		}
		
		// Articles populaires du menu pour simulation réaliste
		const POPULAR_ITEMS = [
			{ id: 10000, name: "Eau Minérale", price: 4, type: "Boisson froide" },
			{ id: 10001, name: "Coca", price: 5, type: "Boisson froide" },
			{ id: 10002, name: "Fanta", price: 5, type: "Boisson froide" },
			{ id: 9502, name: "Beck's", price: 6.8, type: "Bière" },
			{ id: 9503, name: "Celtia", price: 6.8, type: "Bière" },
			{ id: 9504, name: "Pastis", price: 8, type: "Alcool" },
			{ id: 1001, name: "Salade Méchouia", price: 12, type: "Entrée froide" },
			{ id: 1002, name: "Salade César", price: 15, type: "Entrée froide" },
			{ id: 1003, name: "Carpaccio de Bœuf à l'Huile de Truffe", price: 35, type: "Entrée froide" },
			{ id: 1201, name: "Ojja au Merguez", price: 18, type: "Plat tunisien" },
			{ id: 1206, name: "Couscous à l'Agneau", price: 60, type: "Plat tunisien" },
			{ id: 1301, name: "Seiches Grillées", price: 40, type: "Poisson" },
			{ id: 1501, name: "Côte à l'OS à La Plancha", price: 62, type: "Viande" },
			{ id: 1502, name: "Poulet Bebère au Romarin", price: 33, type: "Viande" },
			{ id: 4002, name: "Tiramisu", price: 12, type: "Dessert" },
			{ id: 4003, name: "Chocolate Moelleux", price: 14, type: "Dessert" }
		];
		
		// Noms de clients pour sous-notes
		const CLIENT_NAMES = [
			'Ahmed', 'Fatma', 'Mohamed', 'Aicha', 'Ali', 'Salma', 'Omar', 'Khadija',
			'Youssef', 'Amina', 'Hassan', 'Zineb', 'Karim', 'Nour', 'Brahim', 'Lina',
			'Khalil', 'Rania', 'Sami', 'Donia', 'Tarek', 'Mariem', 'Nabil', 'Sonia'
		];
		
		let simulationCount = 0;
		
		// 🎯 Mode progressif : créer les tables progressivement dans le temps
		if (progressive) {
			console.log('[simulation] Mode progressif activé - génération échelonnée');
			
			let globalTableIndex = 0;
			
			normalizedServers.forEach((server, serverIndex) => {
				const scenarios = TABLE_SCENARIOS[server] || [];
				
				scenarios.forEach((scenario, scenarioIndex) => {
					// 🕐 Arrivée échelonnée réaliste sur 4h (19h-23h)
					const baseTimeMinutes = 19 * 60; // 19h00 en minutes
					const tableDelayMinutes = (globalTableIndex * 15) + (Math.random() * 10 - 5); // 15min entre tables ±5min
					const totalMinutes = baseTimeMinutes + tableDelayMinutes;
					
					const arrivalTime = new Date();
					arrivalTime.setHours(Math.floor(totalMinutes / 60), totalMinutes % 60, 0, 0);
					
					// Ajuster pour que ce soit dans le passé (simulation de soirée)
					const now = new Date();
					if (arrivalTime.getTime() > now.getTime()) {
						arrivalTime.setDate(arrivalTime.getDate() - 1);
					}
					
					// Calculer le délai pour le mode progressif (accéléré pour démo)
					const delayMinutes = Math.max(2, tableDelayMinutes / 20); // Accélérer 20x pour démo
					const delayMs = delayMinutes * 60 * 1000;
					
					console.log(`[simulation] Table ${scenario.table} (${scenario.name}) - ${server}: Arrivée à ${arrivalTime.toLocaleTimeString()}, délai: ${delayMinutes.toFixed(1)}min`);
					
					setTimeout(() => {
						generateTableFromScenario(server, scenario, arrivalTime);
					}, delayMs);
					
					globalTableIndex++;
				});
			});
			
			return res.json({
				message: 'Simulation progressive démarrée', 
				tables: 'Génération échelonnée en cours...',
				mode: 'progressive',
				totalTables: globalTableIndex
			});
		}
		
		// 🎯 Mode normal: générer toutes les tables avec timestamps échelonnés
		let globalTableIndex = 0;
		
		normalizedServers.forEach((server, serverIndex) => {
			const scenarios = TABLE_SCENARIOS[server] || [];
			
			scenarios.forEach((scenario, scenarioIndex) => {
				// 🕐 Arrivée échelonnée réaliste sur 4h (19h-23h)
				// Base: 19h00 + (index global * 15min) + variation aléatoire (±5min)
				const baseTimeMinutes = 19 * 60; // 19h00 en minutes
				const tableDelayMinutes = (globalTableIndex * 15) + (Math.random() * 10 - 5); // 15min entre tables ±5min
				const totalMinutes = baseTimeMinutes + tableDelayMinutes;
				
				// Créer un timestamp réaliste (il y a quelques heures)
				const arrivalTime = new Date();
				arrivalTime.setHours(Math.floor(totalMinutes / 60), totalMinutes % 60, 0, 0);
				
				// Ajuster pour que ce soit dans le passé (simulation de soirée)
				const now = new Date();
				if (arrivalTime.getTime() > now.getTime()) {
					// Si l'heure calculée est dans le futur, reculer d'un jour
					arrivalTime.setDate(arrivalTime.getDate() - 1);
				}
				
				console.log(`[simulation] Table ${scenario.table} (${scenario.name}) - ${server}: Arrivée prévue à ${arrivalTime.toLocaleTimeString()}`);
				generateTableFromScenario(server, scenario, arrivalTime);
				globalTableIndex++;
			});
		});
		
		// === Helpers simulation (panier/couvert et max sous-notes) ===
		function isBusinessScenario(scenario) {
			const name = (scenario.name || '').toLowerCase();
			return name.includes('business') || name.includes('réunion');
		}

		function findItemInMain(order, name) {
			return order.mainNote.items.find(i => i.name === name);
		}

		// Les variables MENU_ITEMS et MENU_BY_NAME sont maintenant globales

		function resolveMenuItemByName(name) {
			if (!name) return null;
			if (!MENU_BY_NAME || MENU_BY_NAME.size === 0) {
				buildMenuIndex();
				// Si toujours pas d'index après reconstruction, utiliser POPULAR_ITEMS
				if (!MENU_BY_NAME || MENU_BY_NAME.size === 0) {
					const pop = POPULAR_ITEMS.find(x => x.name.toLowerCase() === name.toLowerCase());
					return pop || null;
				}
			}
			const hit = MENU_BY_NAME.get(name.toLowerCase());
			if (hit) return hit;
			const pop = POPULAR_ITEMS.find(x => x.name.toLowerCase() === name.toLowerCase());
			return pop || null;
		}

		function addItemToMain(order, itemName, qty) {
			const menuItem = resolveMenuItemByName(itemName);
			if (!menuItem || !qty || qty <= 0) return;
			const existing = findItemInMain(order, itemName);
			if (existing) {
				existing.quantity += qty;
			} else {
				order.mainNote.items.push({ id: menuItem.id, name: menuItem.name, price: menuItem.price, quantity: qty });
			}
			recalcMainTotal(order);
		}

		function recalcMainTotal(order) {
			order.mainNote.total = order.mainNote.items.reduce((s, it) => s + (it.price * it.quantity), 0);
		}

		function recalcSubNoteTotal(subNote) {
			subNote.total = subNote.items.reduce((s, it) => s + (it.price * it.quantity), 0);
		}

		function computeOrderTotal(order) {
			let t = order.mainNote.total;
			for (const sn of order.subNotes) t += sn.total;
			return t;
		}

		function enforceMaxSubNotes(order, maxSubNotes) {
			if (!order.subNotes || order.subNotes.length <= maxSubNotes) return;
			const keep = order.subNotes.slice(0, maxSubNotes);
			const toMerge = order.subNotes.slice(maxSubNotes);
			// Fusionner les sous-notes excédentaires dans la note principale
			for (const sn of toMerge) {
				for (const it of sn.items) {
					addItemToMain(order, it.name, it.quantity);
				}
			}
			order.subNotes = keep;
			// Recalcul des sous-notes conservées
			for (const sn of order.subNotes) recalcSubNoteTotal(sn);
		}

		function addBeerRound(order, covers) {
			// 60-70% des convives prennent une bière par round, moitié Beck's moitié Celtia
			const totalBeers = Math.max(1, Math.ceil(covers * 0.65));
			const becks = Math.floor(totalBeers / 2);
			const celtia = totalBeers - becks;
			if (becks > 0) addItemToMain(order, "Beck's", becks);
			if (celtia > 0) addItemToMain(order, 'Celtia', celtia);
		}

		function pickRandomWineItem() {
			// Chercher un item vin bouteille dans le menu populaire
			const source = (MENU_ITEMS && MENU_ITEMS.length > 0) ? MENU_ITEMS : POPULAR_ITEMS;
			if (!source || !Array.isArray(source)) return null;
			
			const candidates = source.filter(it => {
				if (!it) return false;
				const n = (it.name || '').toLowerCase();
				const t = (it.type || '').toLowerCase();
				return n.includes('vin') || n.includes('bouteille') || t.includes('vin') || t.includes('wine');
			});
			if (candidates.length === 0) return null;
			return candidates[Math.floor(Math.random() * candidates.length)];
		}

		function addWineBottlesRound(order, covers) {
			const wineItem = pickRandomWineItem();
			if (!wineItem) return;
			// 1 bouteille pour ~4 personnes par round
			const bottles = Math.max(1, Math.round(covers / 4));
			addItemToMain(order, wineItem.name, bottles);
		}

		function addCocktailRound(order, covers, ratio = 0.3) {
			// Pastis en apéritif pour ~30% des convives (ou ajouté au besoin)
			const qty = Math.max(0, Math.round(covers * ratio));
			if (qty > 0) addItemToMain(order, 'Pastis', qty);
		}

		function addHeavyDrinkerExtras(order, covers) {
			// 30-50% de buveurs "intenses" ajoutent 2–4 boissons chacun
			const heavyCount = Math.max(0, Math.round(covers * (0.3 + Math.random() * 0.2)));
			for (let i = 0; i < heavyCount; i++) {
				const extra = 2 + Math.floor(Math.random() * 3); // 2..4
				// 70% bières, 30% cocktails
				if (Math.random() < 0.7) {
					addItemToMain(order, "Beck's", Math.ceil(extra / 2));
					addItemToMain(order, 'Celtia', Math.floor(extra / 2));
				} else {
					addCocktailRound(order, 1, 1); // 1 cocktail
				}
			}
		}

		function maybeAddDesserts(order, covers, ratio = 0.5) {
			// 50% par défaut prennent un dessert (alternance Tiramisu/Chocolate)
			const totalDesserts = Math.max(0, Math.round(covers * ratio));
			if (totalDesserts <= 0) return;
			const tiramisu = Math.floor(totalDesserts / 2);
			const moelleux = totalDesserts - tiramisu;
			if (tiramisu > 0) addItemToMain(order, 'Tiramisu', tiramisu);
			if (moelleux > 0) addItemToMain(order, 'Chocolate Moelleux', moelleux);
		}

		function tuneOrderTotals(order, scenario) {
			const covers = scenario.covers || 1;
			const business = isBusinessScenario(scenario);
			const targetMin = business ? 90 : 70; // TND / couvert
			const targetMax = business ? 140 : 90;
			let total = computeOrderTotal(order);
			let avg = total / covers;
			let safety = 0;
			while (avg < targetMin && safety < 12) {
				// Ajouter un round boisson
				addBeerRound(order, covers);
				// Business: ajouter un pastis par ~30% des convives
				if (business) {
					const extraSpirits = Math.max(0, Math.round(covers * 0.3));
					if (extraSpirits > 0) addItemToMain(order, 'Pastis', extraSpirits);
				}
				// Parfois un round de vin en bouteilles
				if (Math.random() < (business ? 0.7 : 0.4)) addWineBottlesRound(order, covers);
				// Desserts si encore sous le seuil
				maybeAddDesserts(order, covers, business ? 0.6 : 0.4);
				// Recalcul
				for (const sn of order.subNotes) recalcSubNoteTotal(sn);
				recalcMainTotal(order);
				total = computeOrderTotal(order);
				avg = total / covers;
				safety++;
				if (avg >= targetMax) break;
			}

			// Ajout "loisir" après cible atteinte: 0–2 rounds bières/cocktails + heavy drinkers
			const extraRounds = Math.floor(Math.random() * 3); // 0..2
			for (let r = 0; r < extraRounds; r++) {
				addBeerRound(order, covers);
				if (Math.random() < 0.5) addCocktailRound(order, covers, business ? 0.35 : 0.25);
				if (Math.random() < 0.5) addWineBottlesRound(order, covers);
			}
			addHeavyDrinkerExtras(order, covers);
			// Recalcul final
			for (const sn of order.subNotes) recalcSubNoteTotal(sn);
			recalcMainTotal(order);
		}

		// 🎯 Fonction pour générer une table à partir d'un scénario prédéfini
		function generateTableFromScenario(server, scenario, arrivalTime) {
			console.log(`[simulation] Génération table ${scenario.table} (${scenario.name}) pour ${server} - ${scenario.covers} couverts`);
			
			// Créer une commande avec scénario prédéfini
			const order = {
								id: nextOrderId++,
				table: scenario.table.toString(),
								server: server,
				covers: scenario.covers,
								notes: '',
				status: 'active',
				consumptionConfirmed: false,
				createdAt: arrivalTime.toISOString(),
								mainNote: {
									id: 'main',
									name: 'Note Principale',
					covers: scenario.covers,
					items: [],
					total: 0,
					paid: false,
					createdAt: arrivalTime.toISOString()
				},
				subNotes: [],
				total: 0
			};
			
			// 🎯 Générer les articles selon le scénario (LOGIQUE CORRIGÉE)
			if (scenario.subNotesData) {
				// Mode avec sous-notes prédéfinies par personne
				console.log(`[simulation] Génération de ${scenario.subNotes} sous-notes avec commandes logiques pour table ${scenario.table}`);
				
				// 1. Créer d'abord les sous-notes (avec boissons supplémentaires par personne)
				const usedNames = new Set();
				scenario.subNotesData.forEach((subNoteData, i) => {
					const subNoteId = `sub_${Date.now()}_${i}`;
					const subNoteItems = [];
					let subNoteTotal = 0;
					
					// Nom aléatoire (évite répétition Ahmed/Fatma)
					const randName = (() => {
						const pool = CLIENT_NAMES && Array.isArray(CLIENT_NAMES) ? CLIENT_NAMES : ['Ahmed','Fatma','Amina','Youssef','Sami','Khalil','Leila','Salma','Nabil','Karim','Sara','Omar','Amine','Noura'];
						let pick = pool[Math.floor(Math.random()*pool.length)];
						let guard = 0;
						while (usedNames.has(pick) && guard < 50) { pick = pool[Math.floor(Math.random()*pool.length)]; guard++; }
						usedNames.add(pick);
						return pick;
					})();
					
					// Générer les articles de base pour cette personne
					subNoteData.items.forEach(itemName => {
						const menuItem = resolveMenuItemByName(itemName);
						if (menuItem) {
							subNoteItems.push({
								id: menuItem.id,
								name: menuItem.name,
								price: menuItem.price,
								quantity: 1
							});
							
							subNoteTotal += menuItem.price;
						}
					});
					
					// Ajouter des boissons supplémentaires pour cette personne (2–5), avec marque cohérente
					const business = isBusinessScenario(scenario);
					const extraDrinks = (business ? 2 : 1) + Math.floor(Math.random()*4); // business 2..5, casual 1..4
					let becks = 0, celtia = 0, pastis = 0;
					// Déterminer préférence bière de la sous-note (marque unique)
					const preferBecks = Math.random() < 0.5; 
					for (let d=0; d<extraDrinks; d++) {
						if (Math.random() < 0.7) { // bière
							(preferBecks ? becks++ : celtia++);
						} else {
							pastis++;
						}
					}
					const pushDrink = (name, qty) => {
						if (qty <= 0) return;
						const mi = resolveMenuItemByName(name);
						if (!mi) return;
						const exist = subNoteItems.find(it => it.name === name);
						if (exist) exist.quantity += qty; else subNoteItems.push({ id: mi.id, name: mi.name, price: mi.price, quantity: qty });
						subNoteTotal += mi.price * qty;
					};
					pushDrink("Beck's", becks);
					pushDrink('Celtia', celtia);
					pushDrink('Pastis', pastis);
					
					console.log(`[simulation] ${randName}: ${subNoteItems.length} articles, total: ${subNoteTotal.toFixed(2)} TND`);
					
					order.subNotes.push({
						id: subNoteId,
						name: randName,
						covers: Math.ceil(scenario.covers / scenario.subNotes),
						items: subNoteItems,
						total: subNoteTotal,
						paid: false,
						createdAt: new Date(arrivalTime.getTime() + (i * 60000)).toISOString()
					});
				});
				// 2. Agréger toutes les sous-notes dans la note principale (somme des items)
				const aggregate = new Map();
				for (const sn of order.subNotes) {
					for (const it of sn.items) {
						const key = it.name;
						if (!aggregate.has(key)) aggregate.set(key, { id: it.id, name: it.name, price: it.price, quantity: 0 });
						aggregate.get(key).quantity += it.quantity;
					}
				}
				order.mainNote.items = Array.from(aggregate.values());
				recalcMainTotal(order);
				
				// Respecter la règle: max 3 sous-notes par table, le reste en note principale
				enforceMaxSubNotes(order, 3);
				// Ajuster le panier/couvert vers la cible (casual/business)
				tuneOrderTotals(order, scenario);
				// Total global = main + sous-notes
				order.total = computeOrderTotal(order);
				console.log(`[simulation] ${order.subNotes.length} sous-notes (max 3) générées pour table ${scenario.table} - Note principale: ${order.mainNote.items.length} articles, Total: ${order.total.toFixed(2)} TND`);
				
			} else {
				// Mode classique sans sous-notes (pour table 5 par exemple)
				scenario.items.forEach(itemName => {
					const menuItem = resolveMenuItemByName(itemName);
					if (menuItem) {
						let quantity = getRealisticQuantity(menuItem, scenario.covers);
						
						order.mainNote.items.push({
							id: menuItem.id,
							name: menuItem.name,
							price: menuItem.price,
							quantity: quantity
						});
						
						order.mainNote.total += menuItem.price * quantity;
					}
				});
				// Ajuster le panier/couvert
				tuneOrderTotals(order, scenario);
				order.total = computeOrderTotal(order);
			}
			
			// Sauvegarder la commande
			orders.push(order);
							simulationCount++;
							
			// Émettre l'événement Socket.IO
			io.emit('order:new', { order, table: scenario.table.toString() });
			
			console.log(`[simulation] Table ${scenario.table} générée: ${order.mainNote.items.length} articles, ${order.subNotes.length} sous-notes`);
		}
		
		// Sauvegarder les données générées
		savePersistedData().catch(e => console.error('[simulation] Erreur sauvegarde:', e));
		
		console.log(`[simulation] Simulation terminée: ${simulationCount} commandes générées`);
		
		return res.json({
			ok: true,
			message: `Simulation terminée: ${simulationCount} commandes générées avec scénarios réalistes`,
			generated: {
				orders: simulationCount,
				servers: normalizedServers,
				tablesPerServer: SIMULATION_CONFIG.tablesPerServer,
				totalTables: SIMULATION_CONFIG.tablesPerServer.reduce((sum, count) => sum + count, 0),
				scenarios: TABLE_SCENARIOS
			}
		});
		
	} catch (e) {
		console.error('[simulation] Erreur simulation:', e);
		return res.status(500).json({ error: 'Erreur lors de la simulation' });
	}
});

// Endpoint pour archiver la consommation d'une table spécifique (après paiement complet)
app.post('/api/admin/clear-table-consumption', authAdmin, (req, res) => {
	try {
		const { table } = req.body || {};
		if (!table) return res.status(400).json({ error: 'Table requise' });
		
		// Compter les éléments avant archivage
		const ordersBefore = orders.length;
		const billsBefore = bills.length;
		const servicesBefore = serviceRequests.length;
		
		// Archiver les commandes et factures au lieu de les supprimer
		const tableOrders = orders.filter(o => String(o.table) === String(table));
		const tableBills = bills.filter(b => String(b.table) === String(table));
		
		// Marquer comme archivées
		tableOrders.forEach(o => {
			o.status = 'archived';
			o.archivedAt = new Date().toISOString();
		});
		tableBills.forEach(b => {
			b.status = 'archived';
			b.archivedAt = new Date().toISOString();
		});
		
		// Déplacer vers les archives
		archivedOrders.push(...tableOrders);
		archivedBills.push(...tableBills);
		
		// Retirer des listes actives
		orders = orders.filter(o => String(o.table) !== String(table));
		bills = bills.filter(b => String(b.table) !== String(table));
		serviceRequests = serviceRequests.filter(s => String(s.table) !== String(table));
		
		const ordersArchived = ordersBefore - orders.length;
		const billsArchived = billsBefore - bills.length;
		const servicesRemoved = servicesBefore - serviceRequests.length;
		
		console.log(`[admin] archived consumption for table ${table}: ${ordersArchived} orders, ${billsArchived} bills, ${servicesRemoved} services`);
		console.log(`[admin] total archived: ${archivedOrders.length} orders, ${archivedBills.length} bills`);
		
		// 💾 Sauvegarder l'archivage
		savePersistedData().catch(e => console.error('[admin] Erreur sauvegarde:', e));
		
		// Émettre un événement Socket.IO pour notifier les clients
		io.emit('table:cleared', { table, ordersArchived, billsArchived, servicesRemoved });
		
		return res.json({ 
			ok: true, 
			message: `Consommation table ${table} archivée`,
			archived: { orders: ordersArchived, bills: billsArchived, services: servicesRemoved },
			totalArchived: { orders: archivedOrders.length, bills: archivedBills.length }
		});
	} catch (e) {
		console.error('[admin] archive table consumption error', e);
		return res.status(500).json({ error: 'Erreur archivage table' });
	}
});

const PORT = process.env.PORT || 3000;

// 💾 Charger les données au démarrage puis démarrer le serveur
loadPersistedData().then(() => {
	server.listen(PORT, () => {
		console.log(`Serveur démarré sur http://localhost:${PORT}`);
		console.log(`💾 Persistance activée: ${orders.length} commandes, ${archivedOrders.length} archivées`);
	});
}).catch(e => {
	console.error('[startup] Erreur chargement données:', e);
	server.listen(PORT, () => {
		console.log(`Serveur démarré sur http://localhost:${PORT} (sans données persistées)`);
	});
});


