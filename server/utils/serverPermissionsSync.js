// 👥 Synchronisation des permissions serveurs entre JSON local et MongoDB
// Permet la synchronisation bidirectionnelle des profils serveurs

const fs = require('fs');
const fsp = require('fs').promises;
const path = require('path');
const dbManager = require('./dbManager');
const dataStore = require('../data');

const PERMISSIONS_FILE = dataStore.SERVER_PERMISSIONS_FILE;

// 🚀 Cache en mémoire pour éviter les requêtes MongoDB répétées
let permissionsCache = null;
let permissionsCacheTimestamp = 0;
let permissionsFileMTime = 0;
const CACHE_TTL = 10000; // 10 secondes de cache (réduit pour détecter les modifications plus rapidement)

// Sauvegarder les profils serveurs (JSON local + MongoDB si configuré)
async function saveServerProfiles(profiles) {
	try {
		// 1. Sauvegarder en JSON local
		await fsp.mkdir(path.dirname(PERMISSIONS_FILE), { recursive: true });
		await fsp.writeFile(PERMISSIONS_FILE, JSON.stringify(profiles, null, 2), 'utf8');
		console.log(`[permissions-sync] 🏠 ${profiles.length} profils serveurs sauvegardés en JSON local`);
		
		// 2. Mettre à jour le cache avec le timestamp du fichier
		permissionsCache = profiles;
		permissionsCacheTimestamp = Date.now();
		try {
			const stats = await fsp.stat(PERMISSIONS_FILE);
			permissionsFileMTime = stats.mtimeMs;
		} catch (e) {
			permissionsFileMTime = 0;
		}
		
		// 3. Synchroniser vers MongoDB si configuré (asynchrone, non-bloquant)
		if (dbManager.isCloud && dbManager.db) {
			dbManager.serverPermissions.deleteMany({}).then(() => {
				if (profiles.length > 0) {
					return dbManager.serverPermissions.insertMany(
						profiles.map(p => ({ ...p, lastSynced: new Date().toISOString() }))
					);
				}
			}).then(() => {
				console.log(`[permissions-sync] ☁️ ${profiles.length} profils serveurs synchronisés vers MongoDB`);
			}).catch(e => {
				console.error(`[permissions-sync] ⚠️ Erreur sync vers MongoDB:`, e.message);
			});
		}
	} catch (e) {
		console.error('[permissions-sync] ❌ Erreur sauvegarde profils serveurs:', e);
		throw e;
	}
}

// Charger les profils serveurs (avec cache en mémoire et vérification de timestamp)
async function loadServerProfiles() {
	try {
		const fileExists = fs.existsSync(PERMISSIONS_FILE);
		
		// 1. Vérifier le cache en mémoire (seulement si fichier existe)
		if (fileExists && permissionsCache) {
			const cacheAge = Date.now() - permissionsCacheTimestamp;
			if (cacheAge < CACHE_TTL) {
				// Vérifier si le fichier a été modifié depuis le cache
				try {
					const stats = await fsp.stat(PERMISSIONS_FILE);
					if (permissionsFileMTime && stats.mtimeMs === permissionsFileMTime) {
						// Fichier non modifié, cache toujours valide
						return permissionsCache;
					}
				} catch (e) {
					// Erreur de stat, on recharge
				}
			}
		}
		
		// 2. Charger depuis JSON local (toujours la source de vérité si le fichier existe)
		if (fileExists) {
			const content = await fsp.readFile(PERMISSIONS_FILE, 'utf8');
			const profiles = JSON.parse(content);
			const result = Array.isArray(profiles) ? profiles : [];
			const stats = await fsp.stat(PERMISSIONS_FILE);
			
			// Mettre à jour le cache avec le timestamp du fichier
			permissionsCache = result;
			permissionsCacheTimestamp = Date.now();
			permissionsFileMTime = stats.mtimeMs;
			
			// Synchroniser vers MongoDB si configuré (asynchrone, non-bloquant)
			if (dbManager.isCloud && dbManager.db && result.length > 0) {
				dbManager.serverPermissions.deleteMany({}).then(() => {
					return dbManager.serverPermissions.insertMany(
						result.map(p => ({ ...p, lastSynced: new Date().toISOString() }))
					);
				}).catch(e => console.error(`[permissions-sync] ⚠️ Erreur sync vers MongoDB:`, e.message));
			}
			
			return result;
		}
		
		// 3. Si fichier local n'existe pas (Railway ou premier démarrage), charger depuis MongoDB
		if (dbManager.isCloud && dbManager.db) {
			const profiles = await dbManager.serverPermissions.find({}).toArray();
			if (profiles.length > 0) {
				const cleaned = profiles.map(({ lastSynced, ...rest }) => rest);
				
				// Sauvegarder en JSON local pour cohérence (si possible)
				try {
					await fsp.mkdir(path.dirname(PERMISSIONS_FILE), { recursive: true });
					await fsp.writeFile(PERMISSIONS_FILE, JSON.stringify(cleaned, null, 2), 'utf8');
					const stats = await fsp.stat(PERMISSIONS_FILE);
					permissionsFileMTime = stats.mtimeMs;
				} catch (e) {
					// Sur Railway, l'écriture peut échouer (pas de stockage persistant)
					permissionsFileMTime = 0;
				}
				
				permissionsCache = cleaned;
				permissionsCacheTimestamp = Date.now();
				
				return cleaned;
			}
		}
		
		// 4. Créer le fichier vide si inexistant
		try {
			await fsp.mkdir(path.dirname(PERMISSIONS_FILE), { recursive: true });
			await fsp.writeFile(PERMISSIONS_FILE, '[]', 'utf8');
			const stats = await fsp.stat(PERMISSIONS_FILE);
			permissionsFileMTime = stats.mtimeMs;
		} catch (e) {
			permissionsFileMTime = 0;
		}
		
		permissionsCache = [];
		permissionsCacheTimestamp = Date.now();
		return [];
	} catch (e) {
		console.error('[permissions-sync] ❌ Erreur chargement profils serveurs:', e);
		return [];
	}
}

module.exports = {
	saveServerProfiles,
	loadServerProfiles
};

