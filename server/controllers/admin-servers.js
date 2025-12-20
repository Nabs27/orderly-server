const fs = require('fs').promises;
const path = require('path');
const dataStore = require('../data');
const { ensureDir } = require('../utils/fileManager');
const { loadServerProfiles, saveServerProfiles } = require('../utils/serverPermissionsSync');

const DEFAULT_PERMISSIONS = {
	canTransferNote: true,
	canTransferTable: true,
	canTransferServer: true,
	canCancelItems: true,
	canEditCovers: true,
	canOpenDebt: true,
	canOpenPayment: true,
};

function getPermissionsFilePath() {
	return dataStore.SERVER_PERMISSIONS_FILE || path.join(__dirname, '..', 'data', 'pos', 'server_permissions.json');
}

async function ensurePermissionsFile() {
	await ensureDir(dataStore.DATA_DIR);
	const filePath = getPermissionsFilePath();
	try {
		await fs.access(filePath);
	} catch {
		await fs.writeFile(filePath, '[]', 'utf8');
	}
	return filePath;
}

async function readProfiles() {
	const profiles = await loadServerProfiles();
	// 🆕 Initialiser le profil ADMIN par défaut s'il n'existe pas
	const updated = await ensureAdminProfile(profiles);
	return updated;
}

async function ensureAdminProfile(profiles) {
	const hasAdmin = profiles.some((p) => p.name && p.name.toUpperCase() === 'ADMIN');
	if (!hasAdmin) {
		const adminProfile = {
			id: 'srv-admin-default',
			name: 'ADMIN',
			pin: 'admin123',
			role: 'Manager',
			permissions: {
				canTransferNote: true,
				canTransferTable: true,
				canTransferServer: true,
				canCancelItems: true,
				canEditCovers: true,
				canOpenDebt: true,
				canOpenPayment: true,
			},
		};
		profiles.push(adminProfile);
		await writeProfiles(profiles);
		console.log('[admin-servers] ✅ Profil ADMIN créé par défaut');
	}
	return profiles;
}

async function writeProfiles(profiles) {
	await saveServerProfiles(profiles);
}

function sanitizeProfile(profile, options = {}) {
	const { includePin = false } = options;
	const { pin, ...rest } = profile;
	return includePin ? profile : rest;
}

function normalizePermissions(perms = {}) {
	return {
		...DEFAULT_PERMISSIONS,
		...perms,
	};
}

async function getServerProfiles(req, res) {
	try {
		const profiles = await readProfiles();
		res.json(profiles);
	} catch (e) {
		console.error('[admin-servers] Erreur lecture profils:', e);
		res.status(500).json({ error: 'Erreur lors de la récupération des profils serveurs' });
	}
}

async function getServerById(req, res) {
	try {
		const profiles = await readProfiles();
		const profile = profiles.find((p) => p.id === req.params.id);
		if (!profile) {
			return res.status(404).json({ error: 'Profil introuvable' });
		}
		res.json(profile);
	} catch (e) {
		console.error('[admin-servers] Erreur get profil:', e);
		res.status(500).json({ error: 'Erreur serveur' });
	}
}

async function createServerProfile(req, res) {
	try {
		const { name, pin, role = 'Serveur', permissions = {} } = req.body || {};
		if (!name || !pin) {
			return res.status(400).json({ error: 'Nom et PIN requis' });
		}

		const profiles = await readProfiles();
		if (profiles.some((p) => p.name.toUpperCase() === name.toUpperCase())) {
			return res.status(409).json({ error: 'Un serveur avec ce nom existe déjà' });
		}

		const profile = {
			id: `srv-${Date.now()}`,
			name: name.toUpperCase(),
			pin: pin.trim(),
			role,
			permissions: normalizePermissions(permissions),
		};

		profiles.push(profile);
		await writeProfiles(profiles);
		res.status(201).json(profile);
	} catch (e) {
		console.error('[admin-servers] Erreur création profil:', e);
		res.status(500).json({ error: 'Erreur lors de la création du profil' });
	}
}

async function updateServerProfile(req, res) {
	try {
		const profiles = await readProfiles();
		const index = profiles.findIndex((p) => p.id === req.params.id);
		if (index === -1) {
			return res.status(404).json({ error: 'Profil introuvable' });
		}

		const profile = profiles[index];
		const { name, pin, role, permissions } = req.body || {};

		if (name) {
			profile.name = name.toUpperCase();
		}
		if (pin) {
			profile.pin = pin.trim();
		}
		if (role) {
			profile.role = role;
		}
		if (permissions) {
			profile.permissions = normalizePermissions({
				...profile.permissions,
				...permissions,
			});
		}

		profiles[index] = profile;
		await writeProfiles(profiles);
		res.json(profile);
	} catch (e) {
		console.error('[admin-servers] Erreur mise à jour profil:', e);
		res.status(500).json({ error: 'Erreur lors de la mise à jour du profil' });
	}
}

async function deleteServerProfile(req, res) {
	try {
		const profiles = await readProfiles();
		const index = profiles.findIndex((p) => p.id === req.params.id);
		if (index === -1) {
			return res.status(404).json({ error: 'Profil introuvable' });
		}

		profiles.splice(index, 1);
		await writeProfiles(profiles);
		res.json({ ok: true });
	} catch (e) {
		console.error('[admin-servers] Erreur suppression profil:', e);
		res.status(500).json({ error: 'Erreur lors de la suppression du profil' });
	}
}

async function getPublicProfiles(req, res) {
	try {
		const profiles = await readProfiles();
		const sanitized = profiles.map((p) => ({
			id: p.id,
			name: p.name,
			role: p.role || 'Serveur',
			permissions: normalizePermissions(p.permissions),
		}));
		res.json(sanitized);
	} catch (e) {
		console.error('[admin-servers] Erreur lecture publique:', e);
		res.status(500).json({ error: 'Erreur lors de la récupération des profils serveurs: ' + e.message });
	}
}

async function getPermissionsForServer(req, res) {
	try {
		const serverName = (req.params.name || '').toUpperCase();
		const profiles = await readProfiles();
		const profile = profiles.find((p) => p.id === req.params.name || p.name === serverName);
		if (!profile) {
			return res.status(404).json({ error: 'Profil introuvable' });
		}

		res.json({
			id: profile.id,
			name: profile.name,
			role: profile.role,
			permissions: normalizePermissions(profile.permissions),
		});
	} catch (e) {
		console.error('[admin-servers] Erreur permissions serveur:', e);
		res.status(500).json({ error: 'Erreur lors de la récupération des permissions' });
	}
}

async function verifyOverride(req, res) {
	try {
		const { pin } = req.body || {};
		if (!pin) {
			return res.status(400).json({ error: 'PIN requis' });
		}
		const profiles = await readProfiles();
		const profile = profiles.find((p) => p.pin === pin.trim());
		if (!profile) {
			return res.status(401).json({ error: 'PIN invalide' });
		}
		const allowedRoles = ['Manager', 'Caissier'];
		if (!allowedRoles.includes((profile.role || 'Serveur').toString())) {
			return res.status(403).json({ error: 'Utilisateur non autorisé pour override' });
		}
		res.json({
			id: profile.id,
			name: profile.name,
			role: profile.role,
			permissions: normalizePermissions(profile.permissions),
		});
	} catch (e) {
		console.error('[admin-servers] Erreur override PIN:', e);
		res.status(500).json({ error: 'Erreur lors de la vérification du PIN' });
	}
}

module.exports = {
	getServerProfiles,
	getServerById,
	createServerProfile,
	updateServerProfile,
	deleteServerProfile,
	getPublicProfiles,
	getPermissionsForServer,
	verifyOverride,
};

