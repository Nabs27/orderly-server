// 👨‍💼 Controller POS - Fichier principal combinant tous les modules
// Combine toutes les fonctionnalités POS découpées pour une utilisation simplifiée

const posTransfer = require('./pos-transfer');
const posPayment = require('./pos-payment');
const posArchive = require('./pos-archive');
const posCancellation = require('./pos-cancellation');
const posPreaddition = require('./pos-preaddition');

// Exporter toutes les fonctions
module.exports = {
	// Transferts
	transferItems: posTransfer.transferItems,
	transferCompleteTable: posTransfer.transferCompleteTable,
	transferServer: posTransfer.transferServer,
	
	// Paiements
	deleteNoteItems: posPayment.deleteNoteItems,
	payMultiOrders: posPayment.payMultiOrders,
	
	// Archives
	getArchivedNotes: posArchive.getArchivedNotes,
	getArchivedOrdersByServer: posArchive.getArchivedOrdersByServer,
	
	// Annulations
	cancelItems: posCancellation.cancelItems,
	
	// Pré-additions
	createPreaddition: posPreaddition.createPreaddition,
	deletePreaddition: posPreaddition.deletePreaddition,
	updatePreaddition: posPreaddition.updatePreaddition
};
