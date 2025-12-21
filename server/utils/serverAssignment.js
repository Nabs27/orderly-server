// 👤 Assignation automatique des serveurs selon les tables
// Utilisé pour les commandes client qui n'ont pas de serveur assigné

/**
 * Assigne automatiquement un serveur selon le numéro de table
 * @param {string|number} tableNumber - Numéro de table
 * @returns {string} - Nom du serveur assigné
 */
function assignServerByTable(tableNumber) {
	// Convertir en nombre
	const table = typeof tableNumber === 'string' ? parseInt(tableNumber, 10) : tableNumber;
	
	// Si ce n'est pas un nombre valide, retourner 'unknown'
	if (isNaN(table) || table <= 0) {
		return 'unknown';
	}
	
	// Assignation selon les plages de tables
	if (table >= 1 && table <= 10) {
		return 'ALI';
	} else if (table >= 11 && table <= 20) {
		return 'MOHAMED';
	} else if (table >= 21 && table <= 30) {
		return 'FATIMA';
	}
	
	// Table hors plage définie
	return 'unknown';
}

module.exports = { assignServerByTable };

