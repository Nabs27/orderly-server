// 📤 Routes Admin - Parse Menu (PDF → JSON)
// Parsing de menus PDF via DeepSeek V3.1

const express = require('express');
const router = express.Router();
const multer = require('multer');
const pdfParse = require('pdf-parse');
const { OpenAI } = require('openai');
const { authAdmin } = require('../middleware/auth');

// Configuration Multer pour upload
const upload = multer({
	storage: multer.memoryStorage(),
	limits: { fileSize: 10 * 1024 * 1024 }, // 10MB max
	fileFilter: (req, file, cb) => {
		const allowed = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg'];
		if (allowed.includes(file.mimetype)) {
			cb(null, true);
		} else {
			cb(new Error('Format non supporté (PDF, JPG, PNG uniquement)'));
		}
	}
});

// Parse menu depuis PDF
router.post('/parse-menu', authAdmin, upload.single('file'), async (req, res) => {
	try {
		if (!req.file) return res.status(400).json({ error: 'Fichier requis' });
		const { restaurantId, restaurantName, currency } = req.body || {};
		if (!restaurantId || !restaurantName) {
			return res.status(400).json({ error: 'restaurantId et restaurantName requis' });
		}

		console.log(`[admin] parsing menu file: ${req.file.originalname} (${req.file.mimetype})`);
		
		let extractedText = '';
		
		// Si PDF: extraction avec pdf-parse
		if (req.file.mimetype === 'application/pdf') {
			const data = await pdfParse(req.file.buffer);
			extractedText = data.text;
		} 
		// Si image: pour l'instant juste une simulation (OCR nécessiterait Tesseract.js ou Vision API)
		else {
			return res.status(501).json({ 
				error: 'OCR image pas encore implémenté. Utilisez un PDF ou implémentez Tesseract.js/Google Vision',
				hint: 'Pour images, ajouter tesseract.js ou appeler Google Vision API'
			});
		}

		if (!extractedText || extractedText.trim().length < 10) {
			return res.status(400).json({ error: 'Aucun texte extrait du fichier' });
		}

		console.log(`[admin] extracted ${extractedText.length} chars, calling DeepSeek for parsing...`);

		// Appel à DeepSeek V3.1 via OpenAI SDK (compatible avec openrouter.ai)
		const openai = new OpenAI({
			baseURL: 'https://openrouter.ai/api/v1',
			apiKey: process.env.OPENROUTER_API_KEY || '', // Clé OpenRouter pour DeepSeek
			defaultHeaders: {
				'HTTP-Referer': 'https://orderly-server.app',
				'X-Title': 'Orderly Menu Parser'
			}
		});

		const prompt = `Tu es un expert en parsing de menus de restaurant. Transforme le texte ci-dessous en JSON structuré selon ce format EXACT (respecte la structure, les noms de champs et les types) :

{
  "restaurant": {
    "id": "${restaurantId}",
    "name": "${restaurantName}",
    "currency": "${currency || 'TND'}"
  },
  "categories": [
    {
      "name": "Nom de la catégorie",
      "group": "food",
      "items": [
        {
          "id": 1001,
          "name": "Nom du plat",
          "price": 12.50,
          "type": "Type du plat",
          "available": true
        }
      ]
    }
  ]
}

RÈGLES IMPORTANTES :
1. "group" peut être : "food" (plats), "drinks" (boissons soft), ou "spirits" (alcools)
2. Les IDs doivent commencer à 1001 et s'incrémenter (1002, 1003...)
3. "type" décrit la sous-catégorie (ex: "Entrée froide", "Plat tunisien", "Boisson froide")
4. "available" est toujours true par défaut
5. Conserve les noms EXACTS des plats du menu (ne traduis pas, ne modifie pas)
6. Si le prix n'est pas clair, mets 0
7. IMPORTANT: Si un article a des variantes séparées par " / " (ex: "Coca / Fanta / Sprite"), crée un article SÉPARÉ pour chaque variante avec le même prix
8. Exemples de séparation :
   - "Coca / Fanta / Sprite" → 3 articles: "Coca", "Fanta", "Sprite"
   - "Jus (Orange / Citron)" → 2 articles: "Jus Orange", "Jus Citron"
   - "Pastis 51 / Ricard" → 2 articles: "Pastis 51", "Ricard"
9. Retourne UNIQUEMENT le JSON valide, sans texte avant/après

TEXTE DU MENU :
${extractedText}`;

		const completion = await openai.chat.completions.create({
			model: 'deepseek/deepseek-chat-v3.1:free',
			messages: [{ role: 'user', content: prompt }],
			temperature: 0.1, // Faible pour précision
			max_tokens: 8000
		});

		const responseText = completion.choices[0]?.message?.content || '';
		console.log(`[admin] DeepSeek response length: ${responseText.length}`);

		// Extraire le JSON (parfois il y a du texte avant/après)
		const jsonMatch = responseText.match(/\{[\s\S]*\}/);
		if (!jsonMatch) {
			console.error('[admin] No JSON found in response:', responseText.substring(0, 200));
			return res.status(500).json({ error: 'Impossible d\'extraire le JSON de la réponse IA' });
		}

		const parsedMenu = JSON.parse(jsonMatch[0]);
		
		// Validation basique
		if (!parsedMenu.restaurant || !parsedMenu.categories) {
			return res.status(500).json({ error: 'JSON invalide (structure incorrecte)' });
		}

		console.log(`[admin] Successfully parsed menu with ${parsedMenu.categories.length} categories`);
		return res.json({ ok: true, menu: parsedMenu });
	} catch (e) {
		console.error('[admin] parse menu error', e);
		return res.status(500).json({ error: e.message || 'Erreur parsing menu' });
	}
});

module.exports = router;

