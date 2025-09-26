const params = new URLSearchParams(window.location.search);
const id = Number(params.get('id'));
const CURRENCY = 'TND';
function formatPrice(amount) { return `${amount.toFixed(2)} ${CURRENCY}`; }

const billMeta = document.getElementById('bill-meta');
const billItems = document.getElementById('bill-items');
const billTotal = document.getElementById('bill-total');
const paySelect = document.getElementById('pay-select');
const tipInput = document.getElementById('tip-input');
const payAmount = document.getElementById('pay-amount');
const payBtn = document.getElementById('pay-btn');
const payFeedback = document.getElementById('pay-feedback');
const billStatus = document.getElementById('bill-status');

let currentBill = null;
let selectableItems = [];
async function loadBill() {
	if (!id) {
		billMeta.textContent = 'Facture introuvable';
		return;
	}
	const res = await fetch(`/bills/${id}`);
	if (!res.ok) {
		billMeta.textContent = 'Facture introuvable';
		return;
	}
    const bill = await res.json();
    currentBill = bill;
	billMeta.textContent = `Facture #${bill.id} — Table ${bill.table} — ${new Date(bill.createdAt).toLocaleString()}`;
    const items = bill.orders.flatMap(o => o.items.map(i => ({...i, orderId: o.id })));
    billItems.innerHTML = items.map(i => `
        <li class="line-item">
            <div class="info"><div class="name">#${i.orderId} • ${i.name} × ${i.quantity}</div></div>
            <div class="price">${formatPrice(i.price * i.quantity)}</div>
            <div class="qty"></div>
            <div class="actions"></div>
        </li>
    `).join('');
	billTotal.textContent = formatPrice(bill.total);
    billStatus.textContent = `Déjà payé: ${formatPrice(bill.paid||0)} — Restant: ${formatPrice(bill.remaining||0)}`;

    // Construire la sélection pour paiement partiel
    selectableItems = items.map(i => ({ orderId: i.orderId, itemId: i.id, name: i.name, price: i.price, maxQty: i.quantity, qty: 0 }));
    renderPaySelect();
}

loadBill();

function renderPaySelect() {
    paySelect.innerHTML = selectableItems.map((it, idx) => `
        <div class="row">
            <span class="info">#${it.orderId} • ${it.name} — ${formatPrice(it.price)} (max ${it.maxQty})</span>
            <div class="qty">
                <button data-delta="-1" data-idx="${idx}">-</button>
                <span>${it.qty}</span>
                <button data-delta="1" data-idx="${idx}">+</button>
            </div>
        </div>
    `).join('');
    // bind plus/minus
    paySelect.querySelectorAll('button').forEach(btn => {
        btn.addEventListener('click', () => {
            const idx = Number(btn.getAttribute('data-idx'));
            const delta = Number(btn.getAttribute('data-delta'));
            const next = Math.max(0, Math.min((selectableItems[idx].qty || 0) + delta, selectableItems[idx].maxQty));
            selectableItems[idx].qty = next;
            renderPaySelect();
            updatePayAmount();
        });
    });
    tipInput.addEventListener('input', updatePayAmount);
    updatePayAmount();
}

function updatePayAmount() {
    const itemsTotal = selectableItems.reduce((s,it)=> s + (it.qty * it.price), 0);
    const tip = Math.max(0, Number(tipInput.value)||0);
    payAmount.textContent = formatPrice(itemsTotal + tip);
}

async function paySelection() {
    const selected = selectableItems.filter(it => it.qty > 0).map(it => ({ orderId: it.orderId, itemId: it.itemId, quantity: it.qty }));
    if (selected.length === 0) {
        payFeedback.textContent = 'Sélection vide';
        payFeedback.className = 'feedback error';
        return;
    }
    try {
        const res = await fetch(`/bills/${currentBill.id}/pay`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ items: selected, tip: Number(tipInput.value)||0 })
        });
        if (!res.ok) {
            const err = await res.json().catch(()=>({}));
            throw new Error(err.error || 'Erreur de paiement');
        }
        await loadBill();
        payFeedback.textContent = 'Paiement enregistré.';
        payFeedback.className = 'feedback success';
        // reset quantités
        selectableItems.forEach(it => it.qty = 0);
        renderPaySelect();
    } catch (e) {
        payFeedback.textContent = e.message;
        payFeedback.className = 'feedback error';
    }
}
payBtn.addEventListener('click', paySelection);


