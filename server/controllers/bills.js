// 💰 Contrôleur des factures
// Gère toutes les opérations sur les factures et paiements

const dataStore = require('../data');
const fileManager = require('../utils/fileManager');
const { getIO } = require('../utils/socket');

// Créer une facture
function createBill(req, res) {
	const io = getIO();
	console.log('[bills] POST /bills - Body:', JSON.stringify(req.body, null, 2));
	const { table } = req.body || {};
	if (!table) {
		console.log('[bills] Erreur: table manquante');
		return res.status(400).json({ error: 'Table requise' });
	}
	const tableOrders = dataStore.orders.filter(o => String(o.table) === String(table));
	console.log('[bills] Commandes trouvées pour table', table, ':', tableOrders.length);
	if (tableOrders.length === 0) {
		console.log('[bills] Erreur: aucune commande pour table', table);
		return res.status(404).json({ error: 'Aucune commande pour cette table' });
	}
	const total = tableOrders.reduce((s, o) => s + Number(o.total || 0), 0);
	const bill = {
		id: dataStore.nextBillId++,
		table,
		orderIds: tableOrders.map(o => o.id),
		total,
		payments: [],
		createdAt: new Date().toISOString()
	};
	dataStore.bills.push(bill);
	console.log('[bills] Facture créée:', bill.id, 'pour table', table, 'total:', total);
	fileManager.savePersistedData().catch(e => console.error('[bills] Erreur sauvegarde:', e));
	io.emit('bill:new', bill);
	return res.status(201).json(bill);
}

// Lister les factures
function getAllBills(req, res) {
	const { table } = req.query;
	const list = table ? dataStore.bills.filter(b => String(b.table) === String(table)) : dataStore.bills;
	return res.json(list);
}

// Récupérer une facture
function getBillById(req, res) {
	const id = Number(req.params.id);
	const bill = dataStore.bills.find(b => b.id === id);
	if (!bill) return res.status(404).json({ error: 'Facture introuvable' });
	const billOrders = dataStore.orders.filter(o => bill.orderIds.includes(o.id));
	const paid = (bill.payments || []).reduce((s, p) => s + Number(p.amount || 0) + Number(p.tip || 0), 0);
	const remaining = Math.max(0, Number(bill.total) - paid);
	return res.json({ ...bill, orders: billOrders, paid, remaining });
}

// Paiement partiel avec pourboire
function payBill(req, res) {
	const io = getIO();
	console.log('[bills] POST /bills/' + req.params.id + '/pay - Body:', JSON.stringify(req.body, null, 2));
	const id = Number(req.params.id);
	const bill = dataStore.bills.find(b => b.id === id);
	if (!bill) {
		console.log('[bills] Erreur: facture', id, 'introuvable');
		return res.status(404).json({ error: 'Facture introuvable' });
	}
	const { items, tip } = req.body || {};
	if (!Array.isArray(items) || items.length === 0) {
		return res.status(400).json({ error: 'Sélection d\'articles requise' });
	}
	const billOrders = dataStore.orders.filter(o => bill.orderIds.includes(o.id));
	let amount = 0;
	for (const sel of items) {
		const { orderId, itemId, quantity } = sel;
		const order = billOrders.find(o => o.id === Number(orderId));
		if (!order) continue;
		
		// Compatibilité avec nouvelle structure (mainNote + subNotes)
		let allItems = [];
		if (order.items && Array.isArray(order.items)) {
			// Ancienne structure
			allItems = order.items;
		} else {
			// Nouvelle structure : fusionner mainNote + subNotes
			if (order.mainNote && order.mainNote.items) {
				allItems.push(...order.mainNote.items);
			}
			if (order.subNotes && Array.isArray(order.subNotes)) {
				order.subNotes.forEach(note => {
					if (note.items) allItems.push(...note.items);
				});
			}
		}
		
		const line = allItems.find(i => Number(i.id) === Number(itemId));
		if (!line) continue;
		const qty = Math.max(0, Math.min(Number(quantity) || 0, Number(line.quantity) || 0));
		amount += qty * Number(line.price);
	}
	const tipAmount = Math.max(0, Number(tip) || 0);
	const payment = {
		id: `${bill.id}-${(bill.payments?.length || 0) + 1}`,
		amount,
		tip: tipAmount,
		items,
		createdAt: new Date().toISOString()
	};
	bill.payments = bill.payments || [];
	bill.payments.push(payment);
	const paid = bill.payments.reduce((s, p) => s + Number(p.amount || 0) + Number(p.tip || 0), 0);
	const remaining = Math.max(0, Number(bill.total) - paid);
	console.log('[bills] Paiement enregistré:', payment.id, 'montant:', amount, 'pourboire:', tipAmount);
	io.emit('bill:paid', { billId: bill.id, table: bill.table, amount, tip: tipAmount, paid, remaining, paymentId: payment.id });
	return res.status(201).json({ payment, paid, remaining });
}

module.exports = {
	createBill,
	getAllBills,
	getBillById,
	payBill
};

