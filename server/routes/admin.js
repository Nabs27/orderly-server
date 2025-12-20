// 🎯 Routes Admin - Fichier principal combinant tous les modules
// Ce fichier combine toutes les routes admin découpées pour une utilisation simplifiée

const express = require('express');
const router = express.Router();

// Importer tous les modules admin
const adminAuth = require('./admin-auth');
const adminRestaurants = require('./admin-restaurants');
const adminMenu = require('./admin-menu');
const adminArchive = require('./admin-archive');
const adminSystem = require('./admin-system');
const adminSimulation = require('./admin-simulation');
const adminParse = require('./admin-parse');
const adminInvoice = require('./admin-invoice');
const adminReportX = require('./admin-report-x');
const adminServers = require('./admin-servers');

// Combiner toutes les routes
router.use('/', adminAuth);        // Login
router.use('/', adminRestaurants); // Restaurants (GET, POST)
router.use('/', adminMenu);        // Menu CRUD (GET, PATCH, POST categories/items, DELETE)
router.use('/', adminArchive);     // Archives (GET archived-orders, archived-bills)
router.use('/', adminSystem);      // Système & Reset (cleanup, clear-table, full-reset, reset-system, credit/reset)
router.use('/', adminSimulation);  // Simulation (POST simulate-data)
router.use('/', adminParse);       // Parse Menu (POST parse-menu)
router.use('/', adminInvoice);     // Génération PDF (POST generate-invoice)
router.use('/', adminReportX);     // Rapport X (GET report-x)
router.use('/', adminServers);     // Profils serveurs & permissions

module.exports = router;
