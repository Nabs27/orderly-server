let CURRENCY = 'TND';
const cartList = document.getElementById('cart-list');
const totalPriceEl = document.getElementById('total-price');
const tableInput = document.getElementById('table-input');
const notesInput = document.getElementById('notes');
const submitBtn = document.getElementById('submit-order');
const feedback = document.getElementById('feedback');
const requestBillBtn = document.getElementById('request-bill');

const cart = new Map();
function formatPrice(amount) { return `${amount.toFixed(2)} ${CURRENCY}`; }

function loadCart() {
  try {
    const arr = JSON.parse(localStorage.getItem('cart') || '[]');
    arr.forEach(i => cart.set(i.id, i));
  } catch {}
}
function saveCart() {
  const arr = Array.from(cart.values());
  localStorage.setItem('cart', JSON.stringify(arr));
}

function renderCart() {
  cartList.innerHTML = '';
  let total = 0;
  for (const [, item] of cart.entries()) {
    total += item.price * item.quantity;
    const li = document.createElement('li');
    li.className = 'line-item';
    li.innerHTML = `
      <div class="info"><div class="name">${item.name}</div></div>
      <div class="price">${formatPrice(item.price)}</div>
      <div class="qty">
        <button data-delta="-1" data-id="${item.id}">-</button>
        <span>${item.quantity}</span>
        <button data-delta="1" data-id="${item.id}">+</button>
      </div>
      <div class="actions"><button class="remove" data-id="${item.id}">✕</button></div>
    `;
    li.querySelectorAll('.qty button').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = Number(btn.getAttribute('data-id'));
        const delta = Number(btn.getAttribute('data-delta'));
        const ex = cart.get(id);
        if (!ex) return;
        ex.quantity += delta;
        if (ex.quantity <= 0) cart.delete(id); else cart.set(id, ex);
        saveCart();
        renderCart();
      });
    });
    li.querySelector('.remove').addEventListener('click', () => {
      cart.delete(item.id);
      saveCart();
      renderCart();
    });
    cartList.appendChild(li);
  }
  totalPriceEl.textContent = formatPrice(total);
}

async function submitOrder() {
  const table = tableInput.value.trim();
  if (!table) {
    feedback.textContent = 'Veuillez indiquer le numéro de table.';
    feedback.className = 'feedback error';
    return;
  }
  const items = Array.from(cart.values()).map(i => ({ id: i.id, name: i.name, price: i.price, quantity: i.quantity }));
  if (items.length === 0) {
    feedback.textContent = 'Votre panier est vide.';
    feedback.className = 'feedback error';
    return;
  }
  const payload = { table, items, notes: notesInput.value.trim() };
  try {
    const res = await fetch('/orders', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
    if (!res.ok) {
      const err = await res.json().catch(()=>({}));
      throw new Error(err.error || 'Erreur lors de l\'envoi de la commande');
    }
    const data = await res.json();
    localStorage.setItem('lastOrder', JSON.stringify({ id: data.id, table: data.table, total: data.total, createdAt: data.createdAt }));
    window.location.href = `/client/confirm.html?id=${data.id}`;
  } catch (e) {
    feedback.textContent = e.message;
    feedback.className = 'feedback error';
  }
}

async function requestBill() {
  const table = tableInput.value.trim();
  if (!table) return;
  try {
    const res = await fetch('/bills', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ table }) });
    if (!res.ok) return;
    const bill = await res.json();
    window.location.href = `/client/bill.html?id=${bill.id}`;
  } catch {}
}

// bootstrap
const params = new URLSearchParams(window.location.search);
const presetTable = params.get('table');
if (presetTable) tableInput.value = presetTable;
loadCart();
renderCart();
submitBtn.addEventListener('click', submitOrder);
if (requestBillBtn) requestBillBtn.addEventListener('click', requestBill);





