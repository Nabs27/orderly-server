// 📄 Routes Admin - Génération Factures PDF
// Génération de factures PDF professionnelles

const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const PDFDocument = require('pdfkit');
const fileManager = require('../utils/fileManager');

const { ensureDir } = fileManager;

// Générer une facture PDF
router.post('/generate-invoice', async (req, res) => {
	console.log('[invoice] POST /api/admin/generate-invoice - Body:', JSON.stringify(req.body, null, 2));
	try {
		const { billId, company, items, total, amountPerPerson, covers, paymentMode, date } = req.body || {};
		
		if (!company?.name || !items || !Array.isArray(items)) {
			return res.status(400).json({ error: 'Données facture incomplètes' });
		}

		console.log(`[invoice] Génération facture PDF pour bill ${billId}, société: ${company.name}`);

		// Créer le dossier invoices s'il n'existe pas
		const invoicesDir = path.join(__dirname, '..', '..', 'public', 'invoices');
		await ensureDir(invoicesDir);

		// Générer le nom du fichier PDF
		const timestamp = Date.now();
		const filename = `facture_${billId}_${timestamp}.pdf`;
		const filepath = path.join(invoicesDir, filename);

		// Créer le PDF
		const doc = new PDFDocument({ margin: 50 });
		const stream = fs.createWriteStream(filepath);
		doc.pipe(stream);

		// En-tête restaurant avec style professionnel
		doc.fontSize(24).text('LES EMIRS', { align: 'center' });
		doc.fontSize(16).text('PORT EL KANTAOUI', { align: 'center' });
		doc.fontSize(12).text('RESTAURANT & BAR', { align: 'center' });
		doc.moveDown(1);
		
		// Ligne de séparation
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(1);
		
		// Informations facture
		doc.fontSize(18).text('FACTURE', { align: 'center' });
		doc.fontSize(12).text(`N° ${billId}`, { align: 'center' });
		doc.fontSize(10).text(`Date: ${new Date(date).toLocaleDateString('fr-FR')}`, { align: 'center' });
		doc.moveDown(2);

		// Informations client
		doc.fontSize(12).text('FACTURÉ À:', { underline: true });
		doc.fontSize(11).text(company.name);
		if (company.address) doc.fontSize(10).text(company.address);
		if (company.phone) doc.fontSize(10).text(`Tél: ${company.phone}`);
		if (company.email) doc.fontSize(10).text(`Email: ${company.email}`);
		if (company.taxNumber) doc.fontSize(10).text(`N° Fiscal: ${company.taxNumber}`);
		doc.moveDown(2);

		// Calculs TVA - logique claire
		const totalHT = total / 1.19; // Total HT (TVA 19%)
		const tva = total - totalHT; // Montant TVA
		const timbreFiscal = 1.0; // Timbre fiscal fixe
		const totalTTC = total; // Total TTC (sans timbre fiscal)
		const totalFinal = totalTTC + timbreFiscal; // Total final avec timbre fiscal

		// Tableau des articles avec alignement parfait
		doc.fontSize(12).text('DÉTAIL DE LA CONSOMMATION:', { underline: true });
		doc.moveDown(0.5);
		
		// En-tête du tableau avec alignement précis
		doc.fontSize(10).text('DÉSIGNATION', 50);
		doc.text('QUANTITÉ', 320, doc.y - 12); // Aligné verticalement
		doc.text('PRIX UNIT. HT', 400, doc.y - 12);
		doc.text('TOTAL HT', 480, doc.y - 12);
		doc.moveDown(0.3);
		
		// Ligne de séparation
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(0.3);
		
		// Article principal avec alignement parfait
		const prixUnitaireHT = totalHT / covers;
		doc.fontSize(11).text(`Menu Restaurant (${covers} personne${covers > 1 ? 's' : ''})`, 50);
		doc.text(`${covers}`, 320, doc.y - 11); // Aligné avec l'en-tête
		doc.text(`${prixUnitaireHT.toFixed(2)} TND`, 400, doc.y - 11);
		doc.text(`${totalHT.toFixed(2)} TND`, 480, doc.y - 11);
		doc.moveDown(0.5);
		
		// Ligne de séparation
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(0.5);

		// Totaux détaillés - alignement à droite
		doc.fontSize(11).text('SOUS-TOTAL HT:', 350);
		doc.text(`${totalHT.toFixed(2)} TND`, 480, doc.y - 11);
		doc.moveDown(0.3);
		
		doc.text('TVA (19%):', 350);
		doc.text(`${tva.toFixed(2)} TND`, 480, doc.y - 11);
		doc.moveDown(0.3);
		
		doc.text('TOTAL TTC:', 350);
		doc.text(`${total.toFixed(2)} TND`, 480, doc.y - 11);
		doc.moveDown(0.3);
		
		doc.text('TIMBRE FISCAL:', 350);
		doc.text(`${timbreFiscal.toFixed(2)} TND`, 480, doc.y - 11);
		doc.moveDown(0.5);
		
		// Ligne de séparation finale
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(0.5);
		
		// Total final en gras - alignement parfait
		doc.fontSize(14).text('TOTAL À PAYER:', 350);
		doc.fontSize(14).text(`${totalFinal.toFixed(2)} TND`, 480, doc.y - 14);

		doc.moveDown(2);

		// Mode de paiement
		doc.moveDown(1);
		doc.fontSize(11).text(`Mode de paiement: ${paymentMode}`, { align: 'center' });
		doc.moveDown(2);

		// Ligne de séparation avant "Merci pour votre visite !"
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(1);
		
		// Message de remerciement
		doc.fontSize(10).text('Merci pour votre visite !', { align: 'center' });
		doc.moveDown(1);
		
		// Ligne de séparation avant les données des Emirs
		doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
		doc.moveDown(1);
		
		// Données des Emirs étalées sur toute la largeur avec gestion du débordement
		const pageWidth = 500; // Largeur disponible (550 - 50 marges)
		
		// Nom du restaurant
		doc.fontSize(9).text('RESTAURANT LES EMIRS - PORT EL KANTAOUI', 50, doc.y, { 
			width: pageWidth, 
			align: 'center',
			lineGap: 2
		});
		doc.moveDown(0.3);
		
		// Adresse
		doc.fontSize(8).text('Port El Kantaoui, Sousse, Tunisie', 50, doc.y, { 
			width: pageWidth, 
			align: 'center',
			lineGap: 2
		});
		doc.moveDown(0.3);
		
		// Contact et fiscal - divisé en plusieurs lignes si nécessaire
		const contactText = 'Tél: +216 73 240 000 | Email: contact@lesemirs.tn | N° Fiscal: 12345678/A/M/000';
		
		// Vérifier si le texte est trop long et le diviser
		const maxCharsPerLine = 60; // Nombre de caractères par ligne
		if (contactText.length > maxCharsPerLine) {
			// Diviser le texte en plusieurs lignes
			const parts = contactText.split(' | ');
			for (let i = 0; i < parts.length; i++) {
				doc.fontSize(8).text(parts[i], 50, doc.y, { 
					width: pageWidth, 
					align: 'center',
					lineGap: 2
				});
				if (i < parts.length - 1) {
					doc.moveDown(0.2);
				}
			}
		} else {
			// Texte court, affichage normal
			doc.fontSize(8).text(contactText, 50, doc.y, { 
				width: pageWidth, 
				align: 'center',
				lineGap: 2
			});
		}

		// Finaliser le PDF
		doc.end();

		// Attendre que le fichier soit écrit
		await new Promise((resolve, reject) => {
			stream.on('finish', resolve);
			stream.on('error', reject);
		});

		const invoiceData = {
			billId,
			company,
			items,
			total,
			amountPerPerson,
			covers,
			paymentMode,
			date,
			pdfGenerated: true,
			pdfUrl: `/invoices/${filename}`,
			pdfPath: filepath
		};

		console.log(`[invoice] Facture PDF générée: ${filename}`);
		return res.json({ ok: true, invoice: invoiceData });
	} catch (e) {
		console.error('[invoice] Erreur génération facture:', e);
		return res.status(500).json({ error: 'Erreur génération facture' });
	}
});

module.exports = router;
