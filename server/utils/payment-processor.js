// 🔧 Processeur de paiements - SOURCE DE VÉRITÉ UNIQUE
// Ce module fournit les fonctions de déduplication et de calcul partagées
// entre pos-report-x.js (X Report / KPI) et history-processor.js (Historique)
//
// ⚠️ RÈGLE .cursorrules 2.1: Une table peut avoir PLUSIEURS commandes (orders)
// Chaque paiement apparaît N fois (une par commande) avec le même splitPaymentId
// Ce module garantit une déduplication cohérente pour tous les consommateurs

/**
 * Déduplique les paiements divisés (split payments) provenant de multi-commandes
 * 
 * Problème: Pour un paiement divisé couvrant 3 commandes, chaque transaction
 * (ex: TPE 80 TND) apparaît 3 fois dans paymentHistory (une par commande).
 * 
 * Solution: Grouper par splitPaymentId + mode + enteredAmount pour obtenir
 * les transactions uniques.
 * 
 * @param {Array} payments - Liste brute des paiements (peut contenir des doublons)
 * @returns {Object} { uniquePayments, totals, tipsByServer }
 */
function deduplicateAndCalculate(payments) {
    // Résultats
    const uniquePayments = [];
    const totals = {
        chiffreAffaire: 0,       // Valeur totale des ventes (somme des allocatedAmount)
        totalRecette: 0,         // Montant réellement encaissé (enteredAmount, hors CREDIT)
        totalRemises: 0,         // Total des remises
        nombreRemises: 0,        // Nombre d'actes de remise uniques
        totalPourboires: 0,      // Total des pourboires (excessAmount)
    };
    const tipsByServer = {};     // serveur -> montant pourboire
    const paymentsByMode = {};   // mode -> { total, count }

    // ⚠️ RÈGLE .cursorrules 2.1: Pour les split payments multi-commandes,
    // chaque transaction apparaît N fois (une par commande) avec :
    // - enteredAmount IDENTIQUE (montant réel encaissé)
    // - allocatedAmount DIFFÉRENT (part proportionnelle de la commande)
    // 
    // Solution: Accumuler les allocatedAmount, mais ne compter enteredAmount qu'une fois

    // Map pour accumuler les données des transactions split uniques
    // Clé: splitPaymentId_mode_enteredAmount -> { enteredAmount, totalAllocated, hasCash, counted }
    const splitTransactionAccumulator = new Map();

    // Sets pour tracking des éléments déjà traités
    const processedDiscountActs = new Set();       // Pour compter les remises uniques
    const processedSplitTips = new Set();          // Pour dédupliquer les pourboires split

    // Grouper les split payments pour calcul du pourboire global
    const splitPaymentGroups = {};
    for (const payment of payments) {
        if (payment.isSplitPayment && payment.splitPaymentId) {
            if (!splitPaymentGroups[payment.splitPaymentId]) {
                splitPaymentGroups[payment.splitPaymentId] = [];
            }
            splitPaymentGroups[payment.splitPaymentId].push(payment);
        }
    }

    // ÉTAPE 1: Pour chaque splitPaymentId, accumuler les données
    // ⚠️ IMPORTANT: Deux transactions du MÊME montant (ex: 2 × TPE 80 TND) ont la même clé
    // Solution: Compter les occurrences et diviser par le nombre de commandes

    for (const splitId in splitPaymentGroups) {
        const groupPayments = splitPaymentGroups[splitId];

        // Compter le nombre de commandes distinctes
        const distinctOrderIds = new Set(groupPayments.map(p => p.orderId || p.sessionId)).size;
        const nbOrders = distinctOrderIds > 0 ? distinctOrderIds : 1;

        // Compter les occurrences de chaque mode + enteredAmount
        // Ex: { "TPE_80.000": { count: 6, enteredAmount: 80, allocatedSum: 254 } }
        const txCounts = {};

        for (const payment of groupPayments) {
            if (payment.type === 'refund') continue;

            const enteredAmount = payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0);
            const allocatedAmount = payment.allocatedAmount != null ? payment.allocatedAmount : (payment.amount || 0);
            const mode = payment.paymentMode || 'INCONNU';
            const txKey = `${mode}_${enteredAmount.toFixed(3)}`;

            if (!txCounts[txKey]) {
                txCounts[txKey] = {
                    count: 0,
                    enteredAmount: enteredAmount,
                    allocatedSum: 0,
                    mode: mode,
                    hasCashInPayment: false
                };
            }

            txCounts[txKey].count += 1;
            txCounts[txKey].allocatedSum += allocatedAmount;
            if (payment.hasCashInPayment === true) {
                txCounts[txKey].hasCashInPayment = true;
            }
        }

        // Calculer le nombre réel de transactions et les totaux
        for (const txKey in txCounts) {
            const tx = txCounts[txKey];
            // Nombre réel de transactions = occurrences / nombre de commandes
            // ⚠️ FIX: Revenir à la division par nbOrders pour permettre les paiements multiples de même montant
            const numTransactions = Math.round(tx.count / nbOrders);

            // Ajouter au chiffre d'affaire (somme des allocatedAmount)
            totals.chiffreAffaire += tx.allocatedSum;

            // Ajouter à la recette (enteredAmount × nombre de transactions)
            if (tx.mode !== 'CREDIT') {
                if (tx.hasCashInPayment) {
                    totals.totalRecette += tx.allocatedSum;
                } else {
                    totals.totalRecette += tx.enteredAmount * numTransactions;
                }

                // Paiements par mode
                if (!paymentsByMode[tx.mode]) {
                    paymentsByMode[tx.mode] = { total: 0, count: 0 };
                }
                paymentsByMode[tx.mode].total += tx.enteredAmount * numTransactions;
                paymentsByMode[tx.mode].count += numTransactions;
            }
        }
    }

    // ÉTAPE 3: Traiter les paiements simples (non-split)
    for (const payment of payments) {
        // Ignorer les remboursements
        if (payment.type === 'refund') {
            totals.totalRecette += payment.amount || 0; // Négatif
            continue;
        }

        // Ignorer les split payments (déjà traités)
        if (payment.isSplitPayment && payment.splitPaymentId) {
            // Juste ajouter aux remises si applicable
            const discountAmount = payment.discountAmount || 0;
            const hasDiscount = payment.hasDiscount || discountAmount > 0.01;

            if (hasDiscount && discountAmount > 0.01) {
                const discountKey = `${payment.table}_${payment.splitPaymentId}`;
                if (!processedDiscountActs.has(discountKey)) {
                    processedDiscountActs.add(discountKey);
                    totals.totalRemises += discountAmount;
                    totals.nombreRemises += 1;
                }
            }
            continue;
        }

        // ===== PAIEMENT SIMPLE =====
        const enteredAmount = payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0);
        const allocatedAmount = payment.allocatedAmount != null ? payment.allocatedAmount : (payment.amount || 0);
        const subtotal = payment.subtotal || payment.amount || 0;
        const mode = payment.paymentMode || 'INCONNU';

        totals.chiffreAffaire += subtotal;

        if (mode !== 'CREDIT') {
            if (payment.hasCashInPayment === true) {
                totals.totalRecette += allocatedAmount;
            } else {
                totals.totalRecette += enteredAmount;
            }

            // Paiements par mode
            if (!paymentsByMode[mode]) {
                paymentsByMode[mode] = { total: 0, count: 0 };
            }
            paymentsByMode[mode].total += enteredAmount;
            paymentsByMode[mode].count += 1;
        }

        // ===== REMISES =====
        const discountAmount = payment.discountAmount || 0;
        const hasDiscount = payment.hasDiscount || discountAmount > 0.01;

        if (hasDiscount && discountAmount > 0.01) {
            totals.totalRemises += discountAmount;
            const discountKey = `${payment.table}_${payment.timestamp}_${mode}`;
            if (!processedDiscountActs.has(discountKey)) {
                processedDiscountActs.add(discountKey);
                totals.nombreRemises += 1;
            }
        }

        // Ajouter à la liste des paiements uniques
        uniquePayments.push(payment);
    }

    // ===== POURBOIRES =====
    // Pour les split payments, calculer le pourboire au niveau du groupe
    for (const splitId in splitPaymentGroups) {
        if (processedSplitTips.has(splitId)) continue;
        processedSplitTips.add(splitId);

        const groupPayments = splitPaymentGroups[splitId];
        const hasCash = groupPayments.some(p => p.hasCashInPayment === true);

        if (hasCash) {
            // Pas de pourboire scriptural si liquide présent
            continue;
        }

        // 🆕 Utiliser la même logique que ÉTAPE 1 pour dédupliquer correctement
        const distinctOrderIds = new Set(groupPayments.map(p => p.orderId || p.sessionId)).size;
        const nbOrders = distinctOrderIds > 0 ? distinctOrderIds : 1;

        const txCounts = {};
        let serverName = 'unknown';

        for (const p of groupPayments) {
            const mode = p.paymentMode;
            if (mode === 'TPE' || mode === 'CHEQUE' || mode === 'CARTE') {
                const entered = p.enteredAmount != null ? p.enteredAmount : (p.amount || 0);
                const allocated = p.allocatedAmount || p.amount || 0;
                const key = `${mode}_${entered.toFixed(3)}`;

                if (!txCounts[key]) {
                    txCounts[key] = {
                        count: 0,
                        enteredAmount: entered,
                        allocatedSum: 0
                    };
                }
                txCounts[key].count += 1;
                txCounts[key].allocatedSum += allocated;

                if (p.server && p.server !== 'unknown') {
                    serverName = p.server;
                }
            }
        }

        // Calculer le pourboire total du split
        let totalEntered = 0;
        let totalAllocated = 0;

        for (const key in txCounts) {
            const tx = txCounts[key];
            const numTransactions = Math.round(tx.count / nbOrders);
            totalEntered += tx.enteredAmount * numTransactions;
            totalAllocated += tx.allocatedSum;
        }

        const tipAmount = Math.max(0, totalEntered - totalAllocated);

        if (tipAmount > 0.01 && serverName !== 'unknown') {
            totals.totalPourboires += tipAmount;
            if (!tipsByServer[serverName]) {
                tipsByServer[serverName] = 0;
            }
            tipsByServer[serverName] += tipAmount;
            console.log(`[payment-processor] ✅ Pourboire split: splitId=${splitId}, serveur=${serverName}, tip=${tipAmount.toFixed(3)}`);
        }
    }

    // Pour les paiements simples, le pourboire est déjà dans excessAmount
    for (const payment of payments) {
        if (payment.isSplitPayment) continue;
        if (payment.hasCashInPayment === true) continue;

        const excessAmount = payment.excessAmount || 0;
        if (excessAmount > 0.01) {
            const serverName = payment.server || 'unknown';
            if (serverName !== 'unknown') {
                totals.totalPourboires += excessAmount;
                if (!tipsByServer[serverName]) {
                    tipsByServer[serverName] = 0;
                }
                tipsByServer[serverName] += excessAmount;
            }
        }
    }

    return {
        uniquePayments,
        totals,
        tipsByServer,
        paymentsByMode
    };
}

/**
 * Regroupe les paiements divisés par splitPaymentId et crée un enregistrement unifié
 * 
 * @param {Array} payments - Liste brute des paiements
 * @returns {Array} Liste des paiements regroupés (un par acte de paiement)
 */
function groupSplitPayments(payments) {
    // Séparer split vs regular
    const splitPayments = payments.filter(p => p.isSplitPayment && p.splitPaymentId);
    const regularPayments = payments.filter(p => !p.isSplitPayment);

    // Grouper les split payments par splitPaymentId
    const splitGroups = {};
    for (const payment of splitPayments) {
        const splitId = payment.splitPaymentId;
        if (!splitGroups[splitId]) {
            splitGroups[splitId] = [];
        }
        splitGroups[splitId].push(payment);
    }

    const result = [];

    // Traiter chaque groupe de split payment
    for (const splitId in splitGroups) {
        const groupPayments = splitGroups[splitId];
        const firstPayment = groupPayments[0];

        // Dédupliquer les transactions par mode + enteredAmount
        const txByKey = {};
        for (const p of groupPayments) {
            const mode = p.paymentMode;
            const entered = p.enteredAmount != null ? p.enteredAmount : (p.amount || 0);
            const key = `${mode}_${entered.toFixed(3)}`;

            if (!txByKey[key]) {
                txByKey[key] = {
                    mode: mode,
                    enteredAmount: entered,
                    allocatedAmount: 0,
                    count: 0
                };
            }
            txByKey[key].allocatedAmount += p.allocatedAmount || p.amount || 0;
            txByKey[key].count += 1;
        }

        // Calculer les totaux dédupliqués
        let totalEnteredAmount = 0;
        let totalAllocatedAmount = 0;
        const modes = [];
        const splitPaymentAmounts = [];

        // Compter le nombre de commandes distinctes
        const distinctOrderIds = new Set(groupPayments.map(p => p.orderId || p.sessionId)).size;
        const nbOrders = distinctOrderIds > 0 ? distinctOrderIds : 1;

        for (const key in txByKey) {
            const tx = txByKey[key];
            totalEnteredAmount += tx.enteredAmount;
            // allocatedAmount est la somme de toutes les commandes, donc c'est correct
            totalAllocatedAmount += tx.allocatedAmount;

            if (!modes.includes(tx.mode)) {
                modes.push(tx.mode);
            }

            // Nombre de transactions réelles = count / nbOrders
            // ⚠️ FIX: Force à 1 pour éviter les erreurs de calcul si nbOrders est incorrect
            const numTransactions = 1;
            for (let i = 0; i < numTransactions; i++) {
                splitPaymentAmounts.push({
                    mode: tx.mode,
                    amount: tx.enteredAmount,
                    index: splitPaymentAmounts.filter(s => s.mode === tx.mode).length + 1
                });
            }
        }

        const hasCashInPayment = groupPayments.some(p => p.hasCashInPayment === true);
        const excessAmount = (!hasCashInPayment && totalEnteredAmount > totalAllocatedAmount)
            ? totalEnteredAmount - totalAllocatedAmount
            : 0;

        // Collecter les articles (dédupliqués)
        const itemsMap = {};
        const processedOrderNotes = new Set();

        for (const p of groupPayments) {
            const orderNoteKey = `${p.orderId || p.sessionId}_${p.noteId}`;
            if (processedOrderNotes.has(orderNoteKey)) continue;
            processedOrderNotes.add(orderNoteKey);

            for (const item of p.items || []) {
                const itemKey = `${item.id}_${item.name}`;
                if (!itemsMap[itemKey]) {
                    itemsMap[itemKey] = { ...item, quantity: 0 };
                }
                itemsMap[itemKey].quantity += item.quantity || 0;
            }
        }

        // Construire l'enregistrement unifié
        result.push({
            id: `split_${splitId}`,
            timestamp: firstPayment.timestamp,
            table: firstPayment.table,
            server: firstPayment.server || 'unknown',
            noteId: firstPayment.noteId,
            noteName: firstPayment.noteName,
            paymentMode: modes.length > 1 ? modes.join(' + ') : modes[0],
            isSplitPayment: true,
            splitPaymentId: splitId,
            splitPaymentModes: modes,
            splitPaymentAmounts: splitPaymentAmounts,
            subtotal: totalAllocatedAmount,
            amount: totalAllocatedAmount,
            enteredAmount: totalEnteredAmount,
            allocatedAmount: totalAllocatedAmount,
            excessAmount: excessAmount,
            hasCashInPayment: hasCashInPayment,
            discount: firstPayment.discount || 0,
            discountAmount: firstPayment.discountAmount || 0,
            isPercentDiscount: firstPayment.isPercentDiscount || false,
            hasDiscount: firstPayment.hasDiscount || false,
            items: Object.values(itemsMap),
            covers: firstPayment.covers || 1,
            orderIds: [...new Set(groupPayments.map(p => p.orderId || p.sessionId).filter(id => id != null))]
        });
    }

    // Ajouter les paiements réguliers
    result.push(...regularPayments);

    return result;
}

/**
 * Calcule les totaux par mode de paiement avec déduplication correcte
 * Inclut aussi les pourboires par serveur dans _tipsByServer
 * 
 * @param {Array} payments - Liste brute des paiements
 * @returns {Object} { [mode]: { total, count, payers }, _tipsByServer: { [server]: amount } }
 */
function calculatePaymentsByMode(payments) {
    const result = {};
    const tipsByServer = {};
    const processedSplitTips = new Set();
    const processedSplitIds = new Set();

    // Grouper les split payments pour calcul du pourboire global
    const splitPaymentGroups = {};
    for (const payment of payments) {
        if (payment.isSplitPayment && payment.splitPaymentId) {
            if (!splitPaymentGroups[payment.splitPaymentId]) {
                splitPaymentGroups[payment.splitPaymentId] = [];
            }
            splitPaymentGroups[payment.splitPaymentId].push(payment);
        }
    }

    // ÉTAPE 1: Traiter les split payments (avec comptage des occurrences)
    for (const splitId in splitPaymentGroups) {
        if (processedSplitIds.has(splitId)) continue;
        processedSplitIds.add(splitId);

        const groupPayments = splitPaymentGroups[splitId];

        // Compter le nombre de commandes distinctes
        const distinctOrderIds = new Set(groupPayments.map(p => p.orderId || p.sessionId)).size;
        const nbOrders = distinctOrderIds > 0 ? distinctOrderIds : 1;

        // Compter les occurrences de chaque mode + enteredAmount
        const txCounts = {};

        for (const payment of groupPayments) {
            if (payment.type === 'refund') continue;
            if (payment.paymentMode === 'CREDIT') continue;

            const mode = payment.paymentMode || 'INCONNU';
            const enteredAmount = payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0);
            const txKey = `${mode}_${enteredAmount.toFixed(3)}`;

            if (!txCounts[txKey]) {
                txCounts[txKey] = {
                    count: 0,
                    enteredAmount: enteredAmount,
                    mode: mode,
                    noteName: payment.noteName
                };
            }
            txCounts[txKey].count += 1;
        }

        // Ajouter au résultat avec le nombre correct de transactions
        for (const txKey in txCounts) {
            const tx = txCounts[txKey];
            // ⚠️ FIX: Force à 1 pour éviter les erreurs de calcul si nbOrders est incorrect
            const numTransactions = 1;

            if (!result[tx.mode]) {
                result[tx.mode] = { total: 0, count: 0, payers: [] };
            }

            result[tx.mode].total += tx.enteredAmount * numTransactions;
            result[tx.mode].count += numTransactions;

            if (tx.noteName && !result[tx.mode].payers.includes(tx.noteName)) {
                result[tx.mode].payers.push(tx.noteName);
            }
        }
    }

    // ÉTAPE 2: Traiter les paiements simples (non-split) avec vraie déduplication
    // Contrairement aux split payments, les simples doivent être complètement dédupliqués
    // car chaque "transaction" ne devrait apparaître qu'une seule fois
    const processedSimplePayments = new Set();

    for (const payment of payments) {
        if (payment.type === 'refund') continue;
        if (payment.paymentMode === 'CREDIT') continue;
        if (payment.isSplitPayment && payment.splitPaymentId) continue; // Déjà traité

        const mode = payment.paymentMode || 'INCONNU';
        const enteredAmount = payment.enteredAmount != null ? payment.enteredAmount : (payment.amount || 0);

        // Pour les paiements simples : UNE SEULE occurrence par transaction
        // Clé de déduplication complète : inclure orderId/sessionId pour éviter les faux doublons
        const txKey = `${mode}_${enteredAmount.toFixed(3)}_${payment.orderId || payment.sessionId || 'unknown'}_${payment.timestamp || payment.date || 0}`;

        if (processedSimplePayments.has(txKey)) continue; // Déjà traité
        processedSimplePayments.add(txKey);

        if (!result[mode]) {
            result[mode] = { total: 0, count: 0, payers: [] };
        }

        result[mode].total += enteredAmount;
        result[mode].count += 1;

        if (payment.noteName && !result[mode].payers.includes(payment.noteName)) {
            result[mode].payers.push(payment.noteName);
        }
    }

    // ===== POURBOIRES =====
    // Pour les split payments, calculer le pourboire au niveau du groupe
    for (const splitId in splitPaymentGroups) {
        if (processedSplitTips.has(splitId)) continue;
        processedSplitTips.add(splitId);

        const groupPayments = splitPaymentGroups[splitId];
        const hasCash = groupPayments.some(p => p.hasCashInPayment === true);

        if (hasCash) continue; // Pas de pourboire scriptural si liquide présent

        // Compter le nombre de commandes distinctes
        const distinctOrderIds = new Set(groupPayments.map(p => p.orderId || p.sessionId)).size;
        const nbOrders = distinctOrderIds > 0 ? distinctOrderIds : 1;

        // Compter les occurrences de chaque mode + enteredAmount
        const txCounts = {};
        let serverName = 'unknown';

        for (const p of groupPayments) {
            const mode = p.paymentMode;
            if (mode === 'TPE' || mode === 'CHEQUE' || mode === 'CARTE') {
                const entered = p.enteredAmount != null ? p.enteredAmount : (p.amount || 0);
                const allocated = p.allocatedAmount || p.amount || 0;
                const key = `${mode}_${entered.toFixed(3)}`;

                if (!txCounts[key]) {
                    txCounts[key] = {
                        count: 0,
                        enteredAmount: entered,
                        allocatedSum: 0
                    };
                }
                txCounts[key].count += 1;
                txCounts[key].allocatedSum += allocated;

                if (p.server && p.server !== 'unknown') {
                    serverName = p.server;
                }
            }
        }

        // Calculer le pourboire total du split
        let totalEntered = 0;
        let totalAllocated = 0;

        for (const key in txCounts) {
            const tx = txCounts[key];
            const numTransactions = Math.round(tx.count / nbOrders); // ⚠️ FIX: Revenir à la division par nbOrders
            totalEntered += tx.enteredAmount * numTransactions;
            totalAllocated += tx.allocatedSum;
        }

        const tipAmount = Math.max(0, totalEntered - totalAllocated);

        if (tipAmount > 0.01 && serverName !== 'unknown') {
            if (!tipsByServer[serverName]) {
                tipsByServer[serverName] = 0;
            }
            tipsByServer[serverName] += tipAmount;
            console.log(`[payment-processor] ✅ Pourboire split: splitId=${splitId}, serveur=${serverName}, entered=${totalEntered}, allocated=${totalAllocated}, tip=${tipAmount.toFixed(3)}`);
        }
    }

    // Pour les paiements simples, le pourboire est déjà dans excessAmount
    for (const payment of payments) {
        if (payment.isSplitPayment) continue;
        if (payment.hasCashInPayment === true) continue;
        if (payment.type === 'refund') continue;

        const mode = payment.paymentMode;
        if (mode !== 'TPE' && mode !== 'CHEQUE' && mode !== 'CARTE') continue;

        const excessAmount = payment.excessAmount || 0;
        if (excessAmount > 0.01) {
            const serverName = payment.server || 'unknown';
            if (serverName !== 'unknown') {
                if (!tipsByServer[serverName]) {
                    tipsByServer[serverName] = 0;
                }
                tipsByServer[serverName] += excessAmount;
                console.log(`[payment-processor] ✅ Pourboire simple: serveur=${serverName}, excessAmount=${excessAmount.toFixed(3)}`);
            }
        }
    }

    // Ajouter les pourboires au résultat
    if (Object.keys(tipsByServer).length > 0) {
        result['_tipsByServer'] = tipsByServer;
        console.log(`[payment-processor] Pourboires par serveur:`, tipsByServer);
    }

    return result;
}

/**
 * Extrait les détails de paiement dédupliqués pour un groupe de paiements divisés
 * ⚠️ RÈGLE .cursorrules 3.2: Utiliser splitPaymentId, pas timestamp
 * 
 * @param {Array} payments - Liste des paiements d'un même splitPaymentId (peut contenir des doublons)
 * @returns {Array} Liste des paymentDetails avec index (CARTE #1, CARTE #2, CHEQUE #1, etc.)
 */
function getPaymentDetails(payments) {
    if (!payments || payments.length === 0) {
        return [];
    }

    // Compter les occurrences de chaque mode + enteredAmount
    const txCounts = {};

    for (const p of payments) {
        const enteredAmount = p.enteredAmount != null ? p.enteredAmount : (p.amount || 0);
        const mode = p.paymentMode || 'N/A';
        const txKey = `${mode}_${enteredAmount.toFixed(3)}`;

        if (!txCounts[txKey]) {
            txCounts[txKey] = {
                count: 0,
                mode: mode,
                amount: enteredAmount,
                payment: p // Garder une référence pour creditClientName
            };
        }
        txCounts[txKey].count++;
    }

    // Calculer le nombre de commandes distinctes
    const distinctOrderIds = new Set(payments.map(p => p.orderId || p.sessionId)).size;
    const nbOrders = distinctOrderIds > 0 ? distinctOrderIds : 1;

    // Créer les paymentDetails avec index (CARTE #1, CARTE #2, etc.)
    const paymentDetails = [];

    // Accéder à dataStore pour chercher les clients crédit (fallback)
    let dataStore = null;
    try {
        dataStore = require('../data.js');
    } catch (e) {
        // Ignorer si dataStore n'est pas disponible
    }

    for (const txKey in txCounts) {
        const tx = txCounts[txKey];
        // Nombre réel de transactions = occurrences / nombre de commandes
        // Ex: 8 occurences / 4 commandes = 2 transactions réelles
        // Ex: 4 occurences / 4 commandes = 1 transaction réelle
        const nbTransactions = Math.round(tx.count / nbOrders);

        if (nbTransactions > 1) {
            console.log(`[payment-processor] ℹ️ Multiple transactions detected for ${tx.mode}: ${tx.count} records / ${nbOrders} orders = ${nbTransactions} transactions`);
        }

        // Créer N entrées pour cette transaction
        for (let i = 0; i < nbTransactions; i++) {
            const detail = {
                mode: tx.mode,
                amount: tx.amount,
                index: paymentDetails.filter(d => d.mode === tx.mode).length + 1 // Index par mode (CARTE #1, CARTE #2, etc.)
            };

            // Ajouter le nom du client pour les paiements CREDIT
            if (tx.mode === 'CREDIT') {
                let clientName = null;

                // 1. Essayer creditClientId (nouveau système)
                if (tx.payment.creditClientId && dataStore?.clientCredits) {
                    const client = dataStore.clientCredits.find(c => c.id === tx.payment.creditClientId);
                    if (client?.name) clientName = client.name;
                }

                // 2. Essayer creditClientName (ancien système)
                if (!clientName && tx.payment.creditClientName) {
                    clientName = tx.payment.creditClientName;
                }

                // 3. Dernier recours : chercher dans les transactions de crédit par montant
                if (!clientName && dataStore?.clientCredits) {
                    const paymentAmount = tx.payment.amount || tx.payment.allocatedAmount || tx.amount || 0;
                    const paymentTimestamp = tx.payment.timestamp ? new Date(tx.payment.timestamp).getTime() : 0;

                    for (const client of (dataStore.clientCredits || [])) {
                        if (!client.transactions) continue;
                        for (const txCredit of client.transactions) {
                            if (txCredit.type !== 'DEBIT') continue;
                            const txAmount = Math.abs(txCredit.amount || 0);
                            const txTimestamp = txCredit.date ? new Date(txCredit.date).getTime() : 0;
                            // Correspondance : même montant et timestamp proche (5 min)
                            if (Math.abs(txAmount - paymentAmount) < 0.01 &&
                                Math.abs(txTimestamp - paymentTimestamp) < 5 * 60 * 1000) {
                                if (client.name) {
                                    clientName = client.name;
                                    break;
                                }
                            }
                        }
                        if (clientName) break;
                    }
                }

                detail.clientName = clientName || 'Client inconnu';
            }

            paymentDetails.push(detail);
        }
    }

    return paymentDetails;
}

module.exports = {
    deduplicateAndCalculate,
    groupSplitPayments,
    calculatePaymentsByMode,
    getPaymentDetails
};

