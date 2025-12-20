// 👥 Synchronisation des permissions serveurs entre JSON local et MongoDB
// Permet la synchronisation bidirectionnelle des profils serveurs

const fs = require('fs');
const fsp = require('fs').promises;
const path = require('path');
const dbManager = require('./dbManager');
const dataStore = require('../data');

const PERMISSIONS_FILE = dataStore.SERVER_PERMISSIONS_FILE;

// Sauvegarder les profils serveurs (JSON local + MongoDB si configuré)
async function saveServerProfiles(profiles) {
	try {
		// 1. Sauvegarder en JSON local
		await fsp.mkdir(path.dirname(PERMISSIONS_FILE), { recursive: true });
		await fsp.writeFile(PERMISSIONS_FILE, JSON.stringify(profiles, null, 2), 'utf8');
		console.log(`[permissions-sync] 🏠 ${profiles.length} profils serveurs sauvegardés en JSON local`);
		
		// 2. Synchroniser vers MongoDB si configuré
		if (dbManager.isCloud && dbManager.db) {
			// Supprimer tous les profils existants et les remplacer
			await dbManager.serverPermissions.deleteMany({});
			if (profiles.length > 0) {
				await dbManager.serverPermissions.insertMany(
					profiles.map(p => ({ ...p, lastSynced: new Date().toISOString() }))
				);
			}
			console.log(`[permissions-sync] ☁️ ${profiles.length} profils serveurs synchronisés vers MongoDB`);
		}
	} catch (e) {
		console.error('[permissions-sync] ❌ Erreur sauvegarde profils serveurs:', e);
		throw e;
	}
}

// Charger les profils serveurs (MongoDB si disponible, sinon JSON local)
async function loadServerProfiles() {
	try {
		// 1. Essayer de charger depuis MongoDB si configuré
		if (dbManager.isCloud && dbManager.db) {
			const profiles = await dbManager.serverPermissions.find({}).toArray();
			if (profiles.length > 0) {
				// Retirer lastSynced avant de retourner
				const cleaned = profiles.map(({ lastSynced, ...rest }) => rest);
				console.log(`[permissions-sync] ☁️ ${cleaned.length} profils serveurs chargés depuis MongoDB`);
				// Synchroniser vers JSON local pour cohérence
				await fsp.mkdir(path.dirname(PERMISSIONS_FILE), { recursive: true });
				await fsp.writeFile(PERMISSIONS_FILE, JSON.stringify(cleaned, null, 2), 'utf8');
				return cleaned;
			}
		}
		
		// 2. Charger depuis JSON local
		if (fs.existsSync(PERMISSIONS_FILE)) {
			const content = await fsp.readFile(PERMISSIONS_FILE, 'utf8');
			const profiles = JSON.parse(content);
			console.log(`[permissions-sync] 🏠 ${profiles.length} profils serveurs chargés depuis JSON local`);
			
			// Synchroniser vers MongoDB si configuré (backup)
			if (dbManager.isCloud && dbManager.db && profiles.length > 0) {
				await dbManager.serverPermissions.deleteMany({});
				await dbManager.serverPermissions.insertMany(
					profiles.map(p => ({ ...p, lastSynced: new Date().toISOString() }))
				).catch(e => console.error(`[permissions-sync] ⚠️ Erreur sync vers MongoDB:`, e.message));
			}
			
			return Array.isArray(profiles) ? profiles : [];
		}
		
		// 3. Créer le fichier vide si inexistant
		await fsp.mkdir(path.dirname(PERMISSIONS_FILE), { recursive: true });
		await fsp.writeFile(PERMISSIONS_FILE, '[]', 'utf8');
		console.log('[permissions-sync] 🏠 Fichier permissions créé (vide)');
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

