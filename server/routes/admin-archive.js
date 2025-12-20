// 📦 Routes Admin - Archives
// Gestion des commandes et factures archivées (GET)

const express = require('express');
const router = express.Router();
const { authAdmin } = require('../middleware/auth');
const dataStore = require('../data');

const archivedOrders = dataStore.archivedOrders;
const archivedBills = dataStore.archivedBills;

// Liste des commandes archivées
router.get('/archived-orders', authAdmin, (req, res) => {
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

// Liste des factures archivées
router.get('/archived-bills', authAdmin, (req, res) => {
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

module.exports = router;

