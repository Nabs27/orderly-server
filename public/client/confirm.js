const orderInfo = document.getElementById('order-info');
const orderItems = document.getElementById('order-items');
const orderTotal = document.getElementById('order-total');
const confirmBtn = document.getElementById('confirm-consumption');
const feedback = document.getElementById('feedback');
const overlay = document.getElementById('confirm-overlay');

const CURRENCY = 'TND';
function formatPrice(amount) { return `${amount.toFixed(2)} ${CURRENCY}`; }

const params = new URLSearchParams(window.location.search);
const orderId = Number(params.get('id'));

let currentOrder = null;
async function loadOrder() {
	if (!orderId) {
		orderInfo.textContent = 'Commande introuvable.';
		confirmBtn.disabled = true;
		return;
	}
	const res = await fetch(`/orders/${orderId}`);
	if (!res.ok) {
		orderInfo.textContent = 'Commande introuvable.';
		confirmBtn.disabled = true;
		return;
	}
    const order = await res.json();
    currentOrder = order;
    orderInfo.textContent = `Commande #${order.id} — Table ${order.table}`;
orderItems.innerHTML = order.items.map(i => `<li class="line-item"><div class="info"><div class="name">${i.name} × ${i.quantity}</div></div><div class="price">${formatPrice(i.price * i.quantity)}</div><div class="qty"></div><div class="actions"></div></li>`).join('');
    orderTotal.textContent = formatPrice(order.total || order.items.reduce((s,i)=>s+i.price*i.quantity,0));
    if (order.consumptionConfirmed) {
		confirmBtn.disabled = true;
		confirmBtn.textContent = 'Consommation confirmée';
	}
}

async function confirmConsumption() {
	try {
		const res = await fetch(`/orders/${orderId}/confirm`, { method: 'PATCH' });
		if (!res.ok) throw new Error('Erreur de confirmation');
        overlay.classList.remove('hidden');
        confirmBtn.disabled = true;
        confirmBtn.textContent = 'Consommation confirmée';
        setTimeout(() => {
            const table = currentOrder?.table ? encodeURIComponent(currentOrder.table) : '';
            window.location.href = table ? `/t/${table}` : '/client/';
        }, 1600);
	} catch (e) {
		feedback.textContent = e.message;
		feedback.className = 'feedback error';
	}
}

confirmBtn.addEventListener('click', confirmConsumption);
loadOrder();


