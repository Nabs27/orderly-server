let CURRENCY = 'TND';
// Types de produits pour filtrage (ex: Entrée froide, Entrée chaude, ...)
// Réordonner: Drinks d'abord visuellement via filtres dynamiques par type

let MENU_BY_CATEGORY = {};

const menuSections = document.getElementById('menu-sections');
const typeFilters = document.getElementById('type-filters');
const groupTabs = document.getElementById('group-tabs');
let activeGroup = 'food';
let expandedGroup = null; // null => sous-catégories masquées
let activeType = 'Entrée froide';
const cartList = document.getElementById('cart-list');
const totalPriceEl = document.getElementById('total-price');
const tableInput = document.getElementById('table-input');
const notesInput = document.getElementById('notes');
const submitBtn = document.getElementById('submit-order');
const feedback = document.getElementById('feedback');
const lastOrderEl = document.getElementById('last-order');
const historyEl = document.getElementById('history');
const runningTotalEl = document.getElementById('running-total');
const requestBillBtn = document.getElementById('request-bill');
const mobileTotalEl = document.getElementById('mobile-total');
const mobileSubmitBtn = document.getElementById('mobile-submit');
const cartButton = document.getElementById('cart-button');
const cartDrawer = document.getElementById('cart-drawer');
const closeCartBtn = document.getElementById('close-cart');

const cart = new Map();

function saveCartToStorage() {
    try {
        const arr = Array.from(cart.values()).map(i => ({ id: i.id, name: i.name, price: i.price, quantity: i.quantity }));
        localStorage.setItem('cart', JSON.stringify(arr));
    } catch {}
}

function loadCartFromStorage() {
    try {
        const raw = localStorage.getItem('cart');
        if (!raw) return;
        const arr = JSON.parse(raw);
        arr.forEach(i => cart.set(i.id, { id: i.id, name: i.name, price: i.price, quantity: i.quantity }));
    } catch {}
}

function formatPrice(amount) { return `${amount.toFixed(2)} ${CURRENCY}`; }

function renderGroupTabsAndFilters(groupsMap) {
    // Groups tabs
    groupTabs.innerHTML = '';
    const groups = Array.from(new Set([...groupsMap.keys(), 'services']));
    if (!groups.includes(activeGroup)) activeGroup = groups[0] || 'food';
    groups.forEach(g => {
        const btn = document.createElement('button');
        btn.textContent = g === 'drinks' ? 'Soft' : (g === 'spirits' ? 'Spiritueux' : (g === 'services' ? 'Services' : 'Plats'));
        btn.className = g === activeGroup ? 'active' : '';
        btn.addEventListener('click', () => {
            // Toujours définir d'abord le groupe actif
            activeGroup = g;
            if (g === 'services') {
                // Services: pas de sous-catégories
                expandedGroup = null;
                typeFilters.classList.add('hidden');
                renderGroupTabsAndFilters(groupsMap);
                renderMenuFromGroup(groupsMap);
                return;
            }
            if (expandedGroup === g) {
                expandedGroup = null; // replier la liste des types
                typeFilters.classList.add('hidden');
            } else {
                expandedGroup = g; // montrer la liste des types
                typeFilters.classList.remove('hidden');
            }
            // recalculers types et contenu
            renderGroupTabsAndFilters(groupsMap);
            renderMenuFromGroup(groupsMap);
        });
        groupTabs.appendChild(btn);
    });

    // Types for current group
    typeFilters.innerHTML = '';
    // Si groupe non présent (services), masquer les types
    if (!groupsMap.has(activeGroup)) {
        typeFilters.classList.add('hidden');
        return;
    }
    if (expandedGroup !== activeGroup) {
        typeFilters.classList.add('hidden');
    }
    const allTypes = new Set();
    Object.entries(MENU_BY_CATEGORY).forEach(([cat, items]) => {
        if (groupsMap.get(activeGroup).includes(cat)) {
            items.forEach(it => allTypes.add(it.type));
        }
    });
    const order = (a,b) => { const rank = t => t.toLowerCase().includes('boisson') ? 0 : 1; if (rank(a)!==rank(b)) return rank(a)-rank(b); return a.localeCompare(b); };
    const typesSorted = [...allTypes].sort(order);
    if (!typesSorted.includes(activeType)) activeType = typesSorted[0] || '';
    typesSorted.forEach(type => {
        const btn = document.createElement('button');
        btn.textContent = type;
        btn.className = type === activeType ? 'active' : '';
        btn.addEventListener('click', () => {
            activeType = type;
            // masquer la liste après sélection
            typeFilters.classList.add('hidden');
            expandedGroup = null;
            renderMenuFromGroup(groupsMap);
        });
        typeFilters.appendChild(btn);
    });
}

function renderMenuFromGroup(groupsMap) {
	menuSections.innerHTML = '';
    const catsInGroup = new Set((groupsMap.get(activeGroup) || []));
    if (activeGroup === 'services') {
        renderServicesSection();
        return;
    }
    Object.entries(MENU_BY_CATEGORY).forEach(([category, items]) => {
        if (!catsInGroup.has(category)) return;
        const filtered = !activeType ? items : items.filter(i => i.type === activeType);
        if (filtered.length === 0) return;

        const card = document.createElement('div');
        card.className = 'section-card';

        const header = document.createElement('div');
        header.className = 'section-header';
        header.innerHTML = `<div class="section-title">${category}</div><div class="chevron">›</div>`;

        const content = document.createElement('div');
        content.className = 'section-content';
        const ul = document.createElement('ul');
        filtered.forEach(item => {
            const li = document.createElement('li');
            li.className = 'menu-item';
            li.innerHTML = `
                <div class="info">
                    <div class="name">${item.name}</div>
                </div>
                <div class="price">${formatPrice(item.price)}</div>
                <div class="actions"><button data-id="${item.id}">Ajouter</button></div>
            `;
            li.querySelector('button').addEventListener('click', () => addToCart(item));
            ul.appendChild(li);
        });
        content.appendChild(ul);
        header.addEventListener('click', () => {
            card.classList.toggle('collapsed');
        });

        card.appendChild(header);
        card.appendChild(content);
        menuSections.appendChild(card);
    });
}

function renderServicesSection() {
    menuSections.innerHTML = '';
    const servicesTypes = [
        { cat: 'Assistance', items: [
            { id: 'clear', name: 'Débarrasser' },
            { id: 'cleaning', name: 'Nettoyage (casse)' }
        ]},
        { cat: 'Matériel', items: [
            { id: 'cutlery', name: 'Demander un couvert' },
            { id: 'glasses', name: 'Demander des verres' },
            { id: 'ice', name: 'Demander des glaçons' }
        ]}
    ];
    servicesTypes.forEach(section => {
        const card = document.createElement('div');
        card.className = 'section-card';
        const header = document.createElement('div');
        header.className = 'section-header';
        header.innerHTML = `<div class="section-title">${section.cat}</div><div class="chevron">›</div>`;
        const content = document.createElement('div');
        content.className = 'section-content';
        const ul = document.createElement('ul');
        section.items.forEach(s => {
            const li = document.createElement('li');
            li.className = 'menu-item';
            li.innerHTML = `
                <div class="info"><div class="name">${s.name}</div></div>
                <div class="actions"><button data-service="${s.id}">Appeler</button></div>
            `;
            li.querySelector('button').addEventListener('click', () => sendServiceRequest(s.id));
            ul.appendChild(li);
        });
        content.appendChild(ul);
        header.addEventListener('click', () => card.classList.toggle('collapsed'));
        card.appendChild(header); card.appendChild(content);
        menuSections.appendChild(card);
    });
}

async function sendServiceRequest(type) {
    const table = tableInput.value.trim();
    if (!table) return showFeedback('Entrez un numéro de table', true);
    try {
        const res = await fetch('/service-requests', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ table, type }) });
        if (!res.ok) throw new Error('Erreur service');
        showFeedback('Demande envoyée');
    } catch (e) {
        showFeedback(e.message, true);
    }
}

function addToCart(item) {
	const existing = cart.get(item.id) || { ...item, quantity: 0 };
	existing.quantity += 1;
	cart.set(item.id, existing);
	renderCart();
}

function updateQuantity(itemId, delta) {
	const existing = cart.get(itemId);
	if (!existing) return;
	existing.quantity += delta;
	if (existing.quantity <= 0) {
		cart.delete(itemId);
	} else {
		cart.set(itemId, existing);
	}
	renderCart();
}

function renderCart() {
	cartList.innerHTML = '';
	let total = 0;
	for (const [, item] of cart.entries()) {
		total += item.price * item.quantity;
        const li = document.createElement('li');
        li.className = 'cart-item';
        li.innerHTML = `
            <div class="info"><strong>${item.name}</strong></div>
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
				const delta = Number(btn.getAttribute('data-delta'));
				const id = Number(btn.getAttribute('data-id'));
				updateQuantity(id, delta);
			});
		});
        li.querySelector('.remove').addEventListener('click', () => {
            cart.delete(item.id);
            renderCart();
        });
		cartList.appendChild(li);
	}
    const totalStr = `${total.toFixed(2)} ${CURRENCY}`;
    totalPriceEl.textContent = totalStr;
    if (mobileTotalEl) mobileTotalEl.textContent = totalStr;
    saveCartToStorage();
}

async function submitOrder() {
	const table = tableInput.value.trim();
	if (!table) {
		return showFeedback('Veuillez indiquer le numéro de table.', true);
	}
	const items = Array.from(cart.values()).map(i => ({ id: i.id, name: i.name, price: i.price, quantity: i.quantity }));
	if (items.length === 0) {
		return showFeedback('Votre panier est vide.', true);
	}
	const payload = { table, items, notes: notesInput.value.trim() };
	try {
		const res = await fetch('/orders', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(payload)
		});
		if (!res.ok) {
			const err = await res.json().catch(() => ({}));
			throw new Error(err.error || 'Erreur lors de l\'envoi de la commande');
		}
		const data = await res.json();
		localStorage.setItem('lastOrder', JSON.stringify({ id: data.id, table: data.table, total: data.total, createdAt: data.createdAt }));
		window.location.href = `/client/confirm.html?id=${data.id}`;
	} catch (e) {
		showFeedback(e.message, true);
	}
}

function showFeedback(message, isError = false) {
	feedback.textContent = message;
	feedback.className = 'feedback ' + (isError ? 'error' : 'success');
	setTimeout(() => {
		feedback.textContent = '';
		feedback.className = 'feedback';
	}, 3000);
}

// Initialisation: charger menu dynamique selon ?r=ID (par défaut les-emirs)
const params = new URLSearchParams(window.location.search);
const restaurantId = params.get('r') || 'les-emirs';

async function loadMenu() {
    try {
        const res = await fetch(`/menu/${restaurantId}`);
        if (!res.ok) throw new Error('Menu indisponible');
        const data = await res.json();
        CURRENCY = data.restaurant?.currency || 'TND';
        document.title = `${data.restaurant?.name || 'Menu'} — Menu`;
        const brand = document.querySelector('header .brand h1');
        if (brand && data.restaurant?.name) brand.textContent = data.restaurant.name;
        MENU_BY_CATEGORY = {};
        const groupsMap = new Map();
        (data.categories || []).forEach(cat => {
            MENU_BY_CATEGORY[cat.name] = (cat.items || []).map(i => ({ id: i.id, name: i.name, price: i.price, type: i.type || cat.name }));
            const group = cat.group || 'food';
            if (!groupsMap.has(group)) groupsMap.set(group, []);
            groupsMap.get(group).push(cat.name);
        });
        if (groupsMap.has('drinks')) activeGroup = 'drinks'; else activeGroup = Array.from(groupsMap.keys())[0] || 'food';
        expandedGroup = null;
        renderGroupTabsAndFilters(groupsMap);
        renderMenuFromGroup(groupsMap);
    } catch (e) {
        showFeedback(e.message || 'Erreur de chargement du menu', true);
    }
}

loadMenu();
renderCart();
submitBtn.addEventListener('click', submitOrder);

// Pré-remplir table via ?table=A3
const presetTable = params.get('table');
if (presetTable) {
	tableInput.value = presetTable;
}

// L'affichage de la dernière commande est maintenant dérivé du serveur via renderHistory()

// Historique des commandes de la table courante
async function renderHistory() {
	const table = tableInput.value.trim();
    if (!table) {
        historyEl.innerHTML = '';
        runningTotalEl.textContent = '';
        return;
    }
	const res = await fetch(`/orders?table=${encodeURIComponent(table)}`);
	if (!res.ok) return;
	const list = await res.json();
	const sorted = list.sort((a,b)=>new Date(b.createdAt)-new Date(a.createdAt));
	const totalToPay = sorted.reduce((s,o)=> s + Number(o.total || 0), 0);
	runningTotalEl.textContent = `Total à payer (cumulé): ${formatPrice(totalToPay)}`;

    // Mettre à jour le bandeau "Dernière commande" à partir du plus récent
    // Dernière commande retirée de l'UI
	const blocks = sorted.map(o => {
		const items = (o.items||[]).map(i => `<li>${i.name} × ${i.quantity} — ${formatPrice(i.price * i.quantity)}</li>`).join('');
		return `
			<div class="order" data-id="${o.id}">
				<div class="meta">#${o.id} • ${new Date(o.createdAt).toLocaleTimeString()} • ${formatPrice(o.total || 0)} • ${o.consumptionConfirmed ? 'Confirmée' : 'En attente'}</div>
				<div>
					<button class="toggle-details" data-id="${o.id}">Détails</button>
					<a href="/client/confirm.html?id=${o.id}"><button>Ouvrir</button></a>
				</div>
			</div>
			<div id="details-${o.id}" class="details" style="display:none;">
				<ul>${items}</ul>
				${o.notes ? `<div class="notes">📝 ${o.notes}</div>` : ''}
			</div>
		`;
	}).join('');
	historyEl.innerHTML = '<h3>Historique</h3>' + blocks;
	// bind toggles
	historyEl.querySelectorAll('.toggle-details').forEach(btn => {
		btn.addEventListener('click', () => {
			const id = btn.getAttribute('data-id');
			const el = document.getElementById(`details-${id}`);
			if (!el) return;
			el.style.display = el.style.display === 'none' ? 'block' : 'none';
		});
	});
}

tableInput.addEventListener('change', renderHistory);
renderHistory();

// Demander la facture
async function requestBill() {
    const table = tableInput.value.trim();
    if (!table) return showFeedback('Veuillez renseigner la table avant de demander la facture', true);
    try {
        const res = await fetch('/bills', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ table }) });
        if (!res.ok) {
            const err = await res.json().catch(()=>({}));
            throw new Error(err.error || 'Erreur facture');
        }
        const bill = await res.json();
        window.location.href = `/client/bill.html?id=${bill.id}`;
    } catch (e) {
        showFeedback(e.message, true);
    }
}
if (requestBillBtn) requestBillBtn.addEventListener('click', requestBill);
if (mobileSubmitBtn) mobileSubmitBtn.addEventListener('click', submitOrder);
function openCart() { cartDrawer.classList.remove('hidden'); }
function closeCart() { cartDrawer.classList.add('hidden'); }
if (cartButton) cartButton.addEventListener('click', () => {
    const params = new URLSearchParams(window.location.search);
    const preset = params.get('table') || tableInput.value.trim() || '';
    const suffix = preset ? `?table=${encodeURIComponent(preset)}` : '';
    window.location.href = `/client/cart.html${suffix}`;
});
if (closeCartBtn) closeCartBtn.addEventListener('click', closeCart);
// Fermer en cliquant sur le backdrop
const backdrop = document.querySelector('.cart-drawer-backdrop');
if (backdrop) backdrop.addEventListener('click', closeCart);

loadCartFromStorage();
