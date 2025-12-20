// 💳 Contrôleur du système de crédit
// Gère les clients et leurs crédits/dettes

const dataStore = require('../data');
const fileManager = require('../utils/fileManager');
const { getIO } = require('../utils/socket');

function normalizeServerName(value) {
	if (!value) return null;
	return String(value).trim();
}

function findServerForOrder(orderId) {
	if (orderId === null || orderId === undefined) return null;
	const numericId = Number(orderId);
	if (!Number.isFinite(numericId)) return null;
	const match = dataStore.orders.find(o => Number(o.id) === numericId) ||
		(dataStore.archivedOrders || []).find(o => Number(o.id) === numericId);
	if (match && match.server) {
		return normalizeServerName(match.server);
	}
	return null;
}

function inferServerFromSources({ server, orderId, orderIds, ticket }) {
	let resolved = normalizeServerName(server);
	if (resolved) return resolved;
	const ids = [];
	if (orderId !== null && orderId !== undefined) ids.push(orderId);
	if (Array.isArray(orderIds)) ids.push(...orderIds);
	for (const id of ids) {
		const found = findServerForOrder(id);
		if (found) return found;
	}
	if (ticket && ticket.server) {
		resolved = normalizeServerName(ticket.server);
		if (resolved) return resolved;
	}
	return null;
}

// Récupérer tous les clients avec leur solde
function getAllClients(req, res) {
	try {
		const clientsWithBalance = dataStore.clientCredits.map(client => {
			const debits = client.transactions.filter(t => t.type === 'DEBIT').reduce((sum, t) => sum + t.amount, 0);
			const credits = client.transactions.filter(t => t.type === 'CREDIT').reduce((sum, t) => sum + t.amount, 0);
			const balance = debits - credits;
			
			return {
				id: client.id,
				name: client.name,
				phone: client.phone,
				balance: balance,
				lastTransaction: client.transactions.length > 0 ? client.transactions[client.transactions.length - 1].date : null
			};
		});
		
		// Trier par solde décroissant (plus gros dettes en premier)
		clientsWithBalance.sort((a, b) => b.balance - a.balance);
		
		res.json(clientsWithBalance);
	} catch (e) {
		console.error('[credit] Erreur récupération clients:', e);
		res.status(500).json({ error: 'Erreur serveur' });
	}
}

// Récupérer un client spécifique avec son historique
function getClientById(req, res) {
	try {
		const clientId = parseInt(req.params.id);
		const client = dataStore.clientCredits.find(c => c.id === clientId);
		
		if (!client) {
			return res.status(404).json({ error: 'Client introuvable' });
		}
		
		const debits = client.transactions.filter(t => t.type === 'DEBIT').reduce((sum, t) => sum + t.amount, 0);
		const credits = client.transactions.filter(t => t.type === 'CREDIT').reduce((sum, t) => sum + t.amount, 0);
		const balance = debits - credits;
		
		// 🆕 Trier les transactions par date croissante (plus anciennes en premier) pour calculer soldes intermédiaires
		const sortedTransactions = [...client.transactions].sort((a, b) => new Date(a.date) - new Date(b.date));
		
		// 🆕 Calculer le solde progressif après chaque transaction (soldes intermédiaires)
		let runningBalance = 0;
		const transactionsWithBalance = sortedTransactions.map(transaction => {
			if (transaction.type === 'DEBIT') {
				runningBalance += transaction.amount;
			} else if (transaction.type === 'CREDIT') {
				runningBalance -= transaction.amount;
			}
			// Retourner la transaction avec son solde intermédiaire
			return {
				...transaction,
				runningBalance: parseFloat(runningBalance.toFixed(2))
			};
		});
		
		// 🆕 Retourner dans l'ordre chronologique décroissant (plus récentes en premier) pour l'affichage
		transactionsWithBalance.sort((a, b) => new Date(b.date) - new Date(a.date));
		
		res.json({
			id: client.id,
			name: client.name,
			phone: client.phone,
			balance: balance,
			transactions: transactionsWithBalance
		});
	} catch (e) {
		console.error('[credit] Erreur récupération client:', e);
		res.status(500).json({ error: 'Erreur serveur' });
	}
}

// Créer un nouveau client
function createClient(req, res) {
	try {
		const { name, phone } = req.body || {};
		
		if (!name || !phone) {
			return res.status(400).json({ error: 'Nom et téléphone requis' });
		}
		
		// Validation du nom (trim et longueur)
		const trimmedName = name.trim();
		if (trimmedName.length === 0) {
			return res.status(400).json({ error: 'Le nom ne peut pas être vide' });
		}
		if (trimmedName.length > 100) {
			return res.status(400).json({ error: 'Le nom est trop long (max 100 caractères)' });
		}
		
		// Validation du téléphone (format basique)
		const trimmedPhone = phone.trim();
		if (trimmedPhone.length === 0) {
			return res.status(400).json({ error: 'Le téléphone ne peut pas être vide' });
		}
		if (trimmedPhone.length > 20) {
			return res.status(400).json({ error: 'Le numéro de téléphone est trop long (max 20 caractères)' });
		}
		
		// Vérifier si le client existe déjà
		const existingClient = dataStore.clientCredits.find(c => 
			c.name.toLowerCase().trim() === trimmedName.toLowerCase() || c.phone.trim() === trimmedPhone
		);
		
		if (existingClient) {
			console.log('[credit] Tentative création client existant:', {
				nomSaisi: trimmedName,
				telephoneSaisi: trimmedPhone,
				clientExistant: {
					id: existingClient.id,
					nom: existingClient.name,
					telephone: existingClient.phone
				},
				matchNom: existingClient.name.toLowerCase().trim() === trimmedName.toLowerCase(),
				matchTelephone: existingClient.phone.trim() === trimmedPhone
			});
			return res.status(409).json({ 
				error: 'Client déjà existant',
				details: `Un client avec le nom "${existingClient.name}" ou le téléphone "${existingClient.phone}" existe déjà (ID: ${existingClient.id})`
			});
		}
		
		const newClient = {
			id: dataStore.nextClientId++,
			name: trimmedName,
			phone: trimmedPhone,
			transactions: []
		};
		
	dataStore.clientCredits.push(newClient);
	console.log('[credit] Client créé:', newClient.id, newClient.name);
	
	// Sauvegarder après création
	fileManager.savePersistedData().catch(e => console.error('[credit] Erreur sauvegarde client:', e));
	
	// Émettre l'événement pour notifier tous les clients (POS + Admin)
	const io = getIO();
	io.emit('client:new', newClient);
	
	res.status(201).json(newClient);
	} catch (e) {
		console.error('[credit] Erreur création client:', e);
		res.status(500).json({ error: 'Erreur serveur' });
	}
}

// Ajouter une transaction (DÉBIT ou CREDIT)
function addTransaction(req, res) {
	try {
		const clientId = parseInt(req.params.id);
		const { type, amount, description, orderId, orderIds, ticket, server } = req.body || {};
		
		console.log('[credit] POST /api/credit/clients/:id/transactions', { clientId, type, amount, description, hasOrderIds: !!orderIds, hasTicket: !!ticket });
		
		if (!type || !amount || !description) {
			return res.status(400).json({ error: 'Type, montant et description requis' });
		}
		
		if (type !== 'DEBIT' && type !== 'CREDIT') {
			return res.status(400).json({ error: 'Type doit être DEBIT ou CREDIT' });
		}
		
		// Validation du montant
		const parsedAmount = parseFloat(amount);
		if (isNaN(parsedAmount) || !isFinite(parsedAmount) || parsedAmount <= 0) {
			return res.status(400).json({ error: 'Montant invalide (doit être un nombre positif)' });
		}
		
		// Validation de la description
		if (description.trim().length === 0) {
			return res.status(400).json({ error: 'Description ne peut pas être vide' });
		}
		if (description.trim().length > 500) {
			return res.status(400).json({ error: 'Description trop longue (max 500 caractères)' });
		}
		
		const client = dataStore.clientCredits.find(c => c.id === clientId);
		if (!client) {
			console.error('[credit] Client introuvable:', clientId);
			return res.status(404).json({ error: 'Client introuvable' });
		}
		
		const inferredServer = inferServerFromSources({ server, orderId, orderIds, ticket }) || 'UNKNOWN';
		
		const normalizedTicket = ticket && typeof ticket === 'object' ? { ...ticket } : null;
		if (normalizedTicket) {
			if (!normalizedTicket.table) {
				normalizedTicket.table = orderId || (orderIds && orderIds.length > 0 ? orderIds[0] : '-');
			}
			if (!normalizedTicket.items || !Array.isArray(normalizedTicket.items)) {
				normalizedTicket.items = [];
			}
			normalizedTicket.server = normalizeServerName(normalizedTicket.server) || inferredServer;
			normalizedTicket.subtotal = normalizedTicket.subtotal ?? parsedAmount;
			normalizedTicket.total = normalizedTicket.total ?? parsedAmount;
			normalizedTicket.discount = normalizedTicket.discount ?? 0;
			normalizedTicket.isPercentDiscount = normalizedTicket.isPercentDiscount === true;
		}
		
		const transaction = {
			id: Date.now(),
			type: type,
			amount: parsedAmount,
			description: description.trim(),
			date: new Date().toISOString(),
			orderId: orderId || null,
			orderIds: orderIds || null,
			ticket: normalizedTicket,
			server: inferredServer
		};
		
		client.transactions.push(transaction);
		console.log('[credit] Transaction ajoutée:', { id: transaction.id, type, amount, clientId, clientName: client.name });
		
		// 🆕 Historiser ce paiement dans chaque commande concernée si orderIds fourni
		if (orderIds && Array.isArray(orderIds) && orderIds.length > 0) {
		  for (const oid of orderIds) {
		    const order = dataStore.orders.find(o => o.id === Number(oid));
		    if (order) {
		      order.orderHistory = order.orderHistory || [];
		      order.orderHistory.push({
		        timestamp: new Date().toISOString(),
		        action: 'credit_payment',
		        details: `Paiement à crédit affecté à cette commande (client: ${client.name || ''}, montant: ${amount})`,
		        transactionId: transaction.id,
		        amount: parseFloat(amount),
		        clientId: client.id,
		        clientName: client.name,
		        server: inferredServer,
		      });
		    }
		  }
		}
		
		// ⚠️ IMPORTANT : Sauvegarder TOUJOURS après chaque transaction, pas seulement si orderIds
		fileManager.savePersistedData().catch(e => console.error('[credit] Erreur sauvegarde transaction:', e));
		
		// Calculer le nouveau solde
		const debits = client.transactions.filter(t => t.type === 'DEBIT').reduce((sum, t) => sum + t.amount, 0);
		const credits = client.transactions.filter(t => t.type === 'CREDIT').reduce((sum, t) => sum + t.amount, 0);
		const balance = debits - credits;
		
		console.log('[credit] Solde calculé:', { clientId, debits, credits, balance, transactionsCount: client.transactions.length });
		
		// Émettre l'événement pour notifier tous les clients (POS + Admin)
		const io = getIO();
		if (io) {
			io.emit('client:transaction-added', { clientId, transaction, balance });
			console.log('[credit] Événement socket émis: client:transaction-added', { clientId, balance });
		} else {
			console.warn('[credit] Socket.IO non disponible, événement non émis');
		}
		
		res.status(201).json({
			transaction: transaction,
			balance: balance
		});
	} catch (e) {
		console.error('[credit] Erreur ajout transaction:', e);
		console.error('[credit] Stack:', e.stack);
		res.status(500).json({ error: 'Erreur serveur', details: e.message });
	}
}

// Paiement automatique sur la commande la plus ancienne
function payOldestDebt(req, res) {
	try {
		const clientId = parseInt(req.params.id);
		const { amount, paymentMode = 'CREDIT', server } = req.body || {};
		
		if (!amount) {
			return res.status(400).json({ error: 'Montant requis' });
		}
		
		// Validation du montant
		const paymentAmount = parseFloat(amount);
		if (isNaN(paymentAmount) || !isFinite(paymentAmount) || paymentAmount <= 0) {
			return res.status(400).json({ error: 'Montant invalide (doit être un nombre positif)' });
		}
		
		const client = dataStore.clientCredits.find(c => c.id === clientId);
		if (!client) {
			return res.status(404).json({ error: 'Client introuvable' });
		}
		
		// Lister les DEBIT chronologiquement
		const debitsChrono = client.transactions
			.filter(t => t.type === 'DEBIT')
			.sort((a, b) => new Date(a.date) - new Date(b.date));
		
		// Trouver le premier DEBIT non soldé (en tenant compte des CREDIT déjà enregistrés)
		let targetDebit = null;
		let remainingForTarget = 0;
		for (const debit of debitsChrono) {
			const alreadyPaid = client.transactions
				.filter(t => t.type === 'CREDIT' && t.orderId && debit.orderId && Number(t.orderId) === Number(debit.orderId))
				.reduce((sum, t) => sum + Number(t.amount || 0), 0);
			const remaining = Number(debit.amount) - alreadyPaid;
			if (remaining > 0.0001) { // tolérance flottante
				targetDebit = debit;
				remainingForTarget = remaining;
				break;
			}
		}
		
		if (!targetDebit) {
			return res.status(400).json({ error: 'Aucune dette à payer' });
		}
		
		const finalPaymentAmount = Math.min(paymentAmount, remainingForTarget);
		
		// Déterminer si c'est un paiement complet ou partiel
		// On vérifie si le montant payé correspond exactement au reste dû (avec tolérance pour les erreurs de virgule flottante)
		const remainingAfterPayment = remainingForTarget - finalPaymentAmount;
		const isFullPayment = remainingAfterPayment <= 0.0001 || Math.abs(finalPaymentAmount - remainingForTarget) < 0.0001;
		
		console.log('[credit] Détection paiement complet:', {
			remainingForTarget,
			finalPaymentAmount,
			remainingAfterPayment,
			isFullPayment,
			paymentAmount,
			comparison: Math.abs(finalPaymentAmount - remainingForTarget)
		});
		
		// Créer la transaction de paiement
		const paymentServer = normalizeServerName(server) || targetDebit.server || findServerForOrder(targetDebit.orderId) || 'UNKNOWN';
		
		const paymentTransaction = {
			id: Date.now(),
			type: 'CREDIT',
			amount: finalPaymentAmount,
			description: isFullPayment 
				? `Paiement complet - ${paymentMode} (${targetDebit.description})`
				: `Paiement partiel - ${paymentMode} (${targetDebit.description})`,
			date: new Date().toISOString(),
			orderId: targetDebit.orderId,
			server: paymentServer
		};
		if (targetDebit.ticket) {
			paymentTransaction.ticket = { ...targetDebit.ticket };
			paymentTransaction.ticket.paymentMode = paymentMode;
			paymentTransaction.ticket.server = paymentServer;
			paymentTransaction.ticket.total = paymentTransaction.ticket.total ?? finalPaymentAmount;
		}
		
		client.transactions.push(paymentTransaction);
		
		// ⚠️ IMPORTANT : Sauvegarder après chaque paiement
		fileManager.savePersistedData().catch(e => console.error('[credit] Erreur sauvegarde paiement:', e));
		
		// Recalculer solde global
		const debits = client.transactions.filter(t => t.type === 'DEBIT').reduce((sum, t) => sum + t.amount, 0);
		const credits = client.transactions.filter(t => t.type === 'CREDIT').reduce((sum, t) => sum + t.amount, 0);
		const balance = debits - credits;
		
		console.log('[credit] Paiement effectué:', { clientId, amount: paymentAmount, balance, remainingDebt: remainingForTarget - paymentAmount });
		
		const io = getIO();
		if (io) {
			io.emit('client:payment-added', { clientId, payment: paymentTransaction, balance });
			console.log('[credit] Événement socket émis: client:payment-added', { clientId, balance });
		} else {
			console.warn('[credit] Socket.IO non disponible, événement non émis');
		}
		
		res.status(201).json({
			payment: paymentTransaction,
			remainingDebt: (remainingForTarget - finalPaymentAmount),
			balance: balance,
			message: isFullPayment ? 'Dette entièrement payée' : 'Paiement partiel effectué'
		});
	} catch (e) {
		console.error('[credit] Erreur paiement automatique:', e);
		res.status(500).json({ error: 'Erreur serveur' });
	}
}

module.exports = {
	getAllClients,
	getClientById,
	createClient,
	addTransaction,
	payOldestDebt
};

