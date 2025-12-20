// 🔐 Routes Admin - Authentification
// Gère uniquement le login admin

const express = require('express');
const router = express.Router();
const dataStore = require('../data');

const ADMIN_PASSWORD = dataStore.ADMIN_PASSWORD;

// Route de login
router.post('/login', (req, res) => {
	const { password } = req.body || {};
	if (password === ADMIN_PASSWORD) {
		return res.json({ token: ADMIN_PASSWORD, ok: true });
	}
	return res.status(401).json({ error: 'Mot de passe incorrect' });
});

module.exports = router;

