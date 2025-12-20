// 🌍 Service de traduction DeepL
// Gère les traductions du menu avec cache

const fs = require('fs');
const fsp = fs.promises;
const path = require('path');

const translationsDir = path.join(__dirname, '..', '..', 'data', 'translations');

async function ensureDir(p) {
	try {
		await fsp.mkdir(p, { recursive: true });
	} catch (e) {
		// Dossier existe déjà
	}
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
			const errText = await resp.text().catch(() => '');
			console.error('[deepl] error', resp.status, errText);
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

function filterAvailableItems(menu) {
	const out = JSON.parse(JSON.stringify(menu));
	for (const cat of out.categories || []) {
		cat.items = (cat.items || []).filter(it => it.hidden !== true);
	}
	out.categories = (out.categories || []).filter(cat => (cat.items || []).length > 0);
	return out;
}

async function translateMenu(menu, lng) {
	const DEEPL_KEY = process.env.DEEPL_KEY || '';
	const targetMap = { en: 'EN', de: 'DE', ar: 'AR' };
	const targetLang = targetMap[lng] || 'EN';
	if (!DEEPL_KEY) {
		console.warn('[deepl] DEEPL_KEY is missing; returning FR menu');
		return menu;
	}
	const uniqueTexts = deepCollectTexts(menu);
	console.log(`[deepl] translating ${uniqueTexts.length} unique texts to ${targetLang}`);
	const mapping = await translateBatch(uniqueTexts, targetLang, DEEPL_KEY);
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
		} catch (e) {}
	}
	console.log('[menu-cache] MISS, translating via DeepL');
	const translatedMenu = await translateMenu(menu, lng);
	await fsp.writeFile(cachePath, JSON.stringify({ sourceMTime, menu: translatedMenu }, null, 2), 'utf8');
	console.log(`[menu-cache] SAVED ${cachePath}`);
	return translatedMenu;
}

module.exports = {
	deepCollectTexts,
	translateBatch,
	augmentWithOriginal,
	filterAvailableItems,
	translateMenu,
	getTranslatedMenuWithCache
};

