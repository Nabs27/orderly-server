const CURRENCY = 'TND';
function formatPrice(amount) { return `${amount.toFixed(2)} ${CURRENCY}`; }
const ordersEl = document.getElementById('orders');
const billsEl = document.getElementById('bills');
const servicesEl = document.getElementById('services');

function renderOrder(order) {
	const li = document.createElement('li');
	li.id = `order-${order.id}`;
	li.className = 'order';
	li.innerHTML = `
		<div class="header">
			<strong>Commande #${order.id}</strong> — Table ${order.table}
			<span class="status ${order.status}">${order.status}</span>
		</div>
		<ul class="items">
			${order.items.map(i => `<li>${i.name} × ${i.quantity} — ${formatPrice(i.price * i.quantity)}</li>`).join('')}
		</ul>
		${order.notes ? `<div class="notes">📝 ${order.notes}</div>` : ''}
		<div><strong>Total:</strong> ${formatPrice(order.total || order.items.reduce((s,i)=>s+i.price*i.quantity,0))}</div>
		<div><strong>Consommation:</strong> ${order.consumptionConfirmed ? 'Confirmée' : 'En attente'}</div>
		<div class="footer">
			<small>${new Date(order.createdAt).toLocaleTimeString()}</small>
			<button data-id="${order.id}" ${order.status === 'traitee' ? 'disabled' : ''}>Marquer traitée</button>
		</div>
	`;
	li.querySelector('button').addEventListener('click', () => markProcessed(order.id));
	return li;
}

function upsertOrder(order) {
	const existing = document.getElementById(`order-${order.id}`);
	const li = renderOrder(order);
	if (existing) {
		existing.replaceWith(li);
	} else {
		ordersEl.prepend(li);
	}
}

async function fetchOrders() {
	const res = await fetch('/orders');
	const data = await res.json();
	ordersEl.innerHTML = '';
	data.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt)).forEach(upsertOrder);
}

async function markProcessed(id) {
	try {
		const res = await fetch(`/orders/${id}`, { method: 'PATCH' });
		if (!res.ok) throw new Error('Erreur MAJ');
		const order = await res.json();
		upsertOrder(order);
	} catch (e) {
		console.error(e);
	}
}

const socket = io();
socket.on('connect', () => console.log('Dashboard connecté'));
socket.on('order:new', upsertOrder);
socket.on('order:updated', upsertOrder);
socket.on('bill:new', bill => {
	const li = document.createElement('li');
	li.textContent = `Facture #${bill.id} — Table ${bill.table} — Total ${formatPrice(bill.total)}`;
	billsEl.prepend(li);
});
socket.on('bill:paid', info => {
	const li = document.createElement('li');
	li.textContent = `Paiement facture #${info.billId} — Table ${info.table} — Montant ${formatPrice(info.amount + info.tip)} — Restant ${formatPrice(info.remaining)}`;
	billsEl.prepend(li);
});
socket.on('service:new', req => {
	const li = document.createElement('li');
	li.textContent = `Service #${req.id} — Table ${req.table} — ${req.type}`;
	servicesEl.prepend(li);
});
socket.on('service:updated', req => {
	const li = document.createElement('li');
	li.textContent = `Service #${req.id} — Table ${req.table} — ${req.type} — ${req.status}`;
	servicesEl.prepend(li);
});

fetchOrders();

async function fetchBills() {
	const res = await fetch('/bills');
	const list = await res.json();
	billsEl.innerHTML = '';
	list.sort((a,b)=>new Date(b.createdAt)-new Date(a.createdAt)).forEach(bill => {
		const li = document.createElement('li');
		li.textContent = `Facture #${bill.id} — Table ${bill.table} — Total ${formatPrice(bill.total)}`;
		billsEl.appendChild(li);
	});
}
fetchBills();


