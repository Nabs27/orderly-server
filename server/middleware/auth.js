// 🔐 Middleware d'authentification admin
// Protège les routes admin

const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123'; // À changer en production !

function authAdmin(req, res, next) {
	const token = req.headers['x-admin-token'];
	if (token !== ADMIN_PASSWORD) {
		return res.status(401).json({ error: 'Non autorisé' });
	}
	next();
}

module.exports = { authAdmin };

