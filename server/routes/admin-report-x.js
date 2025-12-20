// 📊 Routes Admin - Rapport X
// Génération du rapport X (rapport financier de fin de service)

const express = require('express');
const router = express.Router();
const { authAdmin } = require('../middleware/auth');
const reportXController = require('../controllers/pos-report-x');

// Générer le rapport X
router.get('/report-x', authAdmin, reportXController.generateReportX);

// 🖨️ Générer le rapport X au format ticket de caisse (texte)
// Accepte l'authentification via header ou query param pour faciliter l'impression
router.get('/report-x-ticket', (req, res, next) => {
	// Accepter le token dans l'URL pour faciliter l'impression
	const tokenFromQuery = req.query['x-admin-token'];
	const tokenFromHeader = req.headers['x-admin-token'];
	const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';
	
	if (tokenFromQuery === ADMIN_PASSWORD || tokenFromHeader === ADMIN_PASSWORD) {
		return next();
	}
	return res.status(401).send('Non autorisé');
}, reportXController.generateReportXTicket);

// 📄 Etat des crédits clients (JSON)
router.get('/credit-report', authAdmin, reportXController.generateCreditReport);

// 🖨️ Etat des crédits clients au format ticket
router.get('/credit-report-ticket', (req, res, next) => {
	const tokenFromQuery = req.query['x-admin-token'];
 	const tokenFromHeader = req.headers['x-admin-token'];
	const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';
	
	if (tokenFromQuery === ADMIN_PASSWORD || tokenFromHeader === ADMIN_PASSWORD) {
		return next();
	}
	return res.status(401).send('Non autorisé');
}, reportXController.generateCreditReportTicket);

module.exports = router;

