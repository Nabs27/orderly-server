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

// 🆕 Collecter les textes avec leur contexte
function deepCollectTextsWithContext(menu) {
	const texts = new Set();
	const textContexts = new Map(); // Map texte → contexte
	
	if (menu.restaurant?.name) {
		const name = String(menu.restaurant.name);
		texts.add(name);
		textContexts.set(name, 'restaurant'); // Contexte restaurant
	}
	
	for (const cat of menu.categories || []) {
		const group = cat.group || 'food';
		// 🆕 Déterminer le contexte selon le groupe
		let context = 'dish'; // Par défaut (plat)
		if (group === 'drinks' || group === 'spirits') {
			context = 'drink'; // Contexte "boisson"
		} else if (cat.name?.toLowerCase().includes('dessert')) {
			context = 'dessert'; // Contexte "dessert"
		}
		
		// Ajouter le nom de catégorie avec contexte
		if (cat.name) {
			const name = String(cat.name);
			texts.add(name);
			textContexts.set(name, context);
		}
		
		// Ajouter les noms d'articles avec contexte
		for (const it of cat.items || []) {
			if (it.name) {
				const name = String(it.name);
				texts.add(name);
				textContexts.set(name, context);
			}
			if (it.type) {
				const type = String(it.type);
				texts.add(type);
				textContexts.set(type, context);
			}
		}
	}
	
	return { texts: Array.from(texts), contexts: textContexts };
}

async function translateBatch(texts, targetLang, key, contexts = null) {
	const mapping = {};
	const endpoint = key.endsWith(':fx') ? 'https://api-free.deepl.com/v2/translate' : 'https://api.deepl.com/v2/translate';
	const batchSize = 40;
	
	// 🆕 Si des contextes sont fournis, grouper par contexte pour optimiser
	if (contexts && contexts.size > 0) {
		const byContext = new Map();
		texts.forEach(text => {
			const ctx = contexts.get(text) || 'dish';
			if (!byContext.has(ctx)) byContext.set(ctx, []);
			byContext.get(ctx).push(text);
		});
		
		// Traduire chaque groupe avec son contexte
		for (const [context, groupTexts] of byContext) {
			const groupMapping = await translateBatchWithContext(groupTexts, targetLang, key, context);
			Object.assign(mapping, groupMapping);
		}
		return mapping;
	}
	
	// Ancien code sans contexte (pour compatibilité)
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

// 🆕 Nouvelle fonction avec contexte (utilise des préfixes dans le texte pour DeepL)
async function translateBatchWithContext(texts, targetLang, key, context) {
	const mapping = {};
	const endpoint = key.endsWith(':fx') ? 'https://api-free.deepl.com/v2/translate' : 'https://api.deepl.com/v2/translate';
	const batchSize = 40;
	
	// 🆕 Mapper les contextes vers des préfixes explicites pour DeepL
	const contextPrefixes = {
		'drink': 'boisson:',
		'dish': 'plat:',
		'dessert': 'dessert:',
		'restaurant': 'restaurant:'
	};
	const prefix = contextPrefixes[context] || '';
	
	for (let i = 0; i < texts.length; i += batchSize) {
		const slice = texts.slice(i, i + batchSize);
		const body = new URLSearchParams();
		body.append('auth_key', key);
		body.append('target_lang', targetLang);
		body.append('source_lang', 'FR');
		body.append('preserve_formatting', '1');
		body.append('split_sentences', 'nonewlines');
		
		// 🆕 Ajouter le préfixe de contexte au texte pour DeepL
		for (const t of slice) {
			const textWithContext = prefix ? `${prefix}${t}` : t;
			body.append('text', textWithContext);
		}
		
		console.log(`[deepl] POST ${endpoint} batch ${i}-${i+slice.length-1} (context: ${context})`);
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
			let trg = translations[j]?.text || src;
			// 🆕 Retirer le préfixe de la traduction si présent
			if (prefix && trg.startsWith(prefix)) {
				trg = trg.substring(prefix.length);
			}
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
	// 🆕 Support de TOUTES les langues DeepL (~30 langues)
	// 🆕 Support de TOUTES les langues DeepL (~30 langues)
	const targetMap = {
		// Européennes
		'en': 'EN', 'de': 'DE', 'fr': 'FR', 'es': 'ES', 'it': 'IT',
		'pt': 'PT', 'nl': 'NL', 'pl': 'PL', 'ru': 'RU', 'cs': 'CS',
		'da': 'DA', 'sv': 'SV', 'no': 'NO', 'fi': 'FI', 'el': 'EL',
		'hu': 'HU', 'sk': 'SK', 'sl': 'SL', 'et': 'ET', 'lv': 'LV',
		'lt': 'LT', 'bg': 'BG',
		// Asiatiques
		'ja': 'JA', 'zh': 'ZH', 'ko': 'KO',
		// Moyen-Orient & Afrique
		'ar': 'AR', 'he': 'HE', 'tr': 'TR', 'hi': 'HI',
		// Asie du Sud-Est
		'id': 'ID', 'ms': 'MS', 'th': 'TH',
		// Autres
		'uk': 'UK', 'vi': 'VI'
	};

	const targetLang = targetMap[lng.toLowerCase()];

	// 🆕 Fallback élégant : si langue non supportée → anglais
	if (!targetLang) {
		console.log(`[deepl] Langue '${lng}' non supportée par DeepL, fallback vers anglais`);
		return translateMenu(menu, 'en');
	}
	if (!DEEPL_KEY) {
		console.warn('[deepl] DEEPL_KEY is missing; returning FR menu');
		return menu;
	}
	
	// 🆕 Collecter les textes avec leur contexte
	const { texts: uniqueTexts, contexts: textContexts } = deepCollectTextsWithContext(menu);
	console.log(`[deepl] translating ${uniqueTexts.length} unique texts to ${targetLang} (${lng}) with context`);
	
	// 🆕 Traduire avec contexte
	const mapping = await translateBatch(uniqueTexts, targetLang, DEEPL_KEY, textContexts);
	
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
	deepCollectTextsWithContext, // 🆕 Export de la nouvelle fonction
	translateBatch,
	translateBatchWithContext, // 🆕 Export de la nouvelle fonction
	augmentWithOriginal,
	filterAvailableItems,
	translateMenu,
	getTranslatedMenuWithCache
};

