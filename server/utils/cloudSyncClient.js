// 🔄 Client de synchronisation Cloud → Local
// Permet au serveur local de se connecter au serveur Cloud via Socket.IO
// et de recevoir les notifications de synchronisation (menu, permissions, etc.)

const io = require('socket.io-client');
const dbManager = require('./dbManager');

class CloudSyncClient {
    constructor() {
        this.socket = null;
        this.isConnected = false;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 10;
        this.callbacks = {
            'sync:menu': [],
            'sync:permissions': [],
            'sync:all': []
        };
    }

    /**
     * Connecte le serveur local au serveur Cloud
     * @param {string} cloudUrl - URL du serveur Cloud (ex: https://my-app.railway.app)
     */
    connect(cloudUrl) {
        // Ne pas connecter si on est le serveur Cloud
        if (dbManager.isCloud) {
            console.log('[cloud-sync] ☁️ Serveur Cloud détecté, pas de connexion client');
            return;
        }

        if (!cloudUrl) {
            console.log('[cloud-sync] ⚠️ CLOUD_SERVER_URL non défini, synchronisation Cloud désactivée');
            return;
        }

        console.log(`[cloud-sync] 🔌 Connexion au serveur Cloud: ${cloudUrl}`);

        this.socket = io(cloudUrl, {
            transports: ['websocket'], // Forcer websocket pour plus de stabilité
            reconnection: true,
            reconnectionDelay: 2000, // Reconnecter plus vite
            reconnectionDelayMax: 10000,
            reconnectionAttempts: Infinity, // Ne jamais abandonner
            timeout: 10000,
            extraHeaders: {
                'x-client-type': 'pos-local-server'
            }
        });

        this.socket.on('connect', () => {
            this.isConnected = true;
            this.reconnectAttempts = 0;
            console.log(`[cloud-sync] ✅ Connecté au serveur Cloud (${cloudUrl})`);

            // S'identifier comme serveur local
            this.socket.emit('client:identify', {
                type: 'local-server',
                timestamp: new Date().toISOString()
            });
        });

        this.socket.on('disconnect', (reason) => {
            this.isConnected = false;
            console.log(`[cloud-sync] ❌ Déconnecté du serveur Cloud: ${reason}`);
        });

        this.socket.on('connect_error', (error) => {
            console.log(`[cloud-sync] ⚠️ Erreur connexion Cloud: ${error.message}`);
            // Si websocket échoue, essayer polling
            if (this.socket.io.opts.transports.includes('websocket')) {
                console.log('[cloud-sync] 🔄 Basculement sur polling...');
                this.socket.io.opts.transports = ['polling', 'websocket'];
            }
        });
        // 🍽️ Écouter les notifications de synchronisation du menu
        this.socket.on('sync:menu', async (data) => {
            console.log('[cloud-sync] 📥 Notification sync:menu reçue', data);
            await this._handleMenuSync(data);
        });

        // 👥 Écouter les notifications de synchronisation des permissions
        this.socket.on('sync:permissions', async (data) => {
            console.log('[cloud-sync] 📥 Notification sync:permissions reçue', data);
            await this._handlePermissionsSync(data);
        });

        // 🔄 Écouter les notifications de synchronisation globale
        this.socket.on('sync:all', async (data) => {
            console.log('[cloud-sync] 📥 Notification sync:all reçue', data);
            await this._handleMenuSync(data);
            await this._handlePermissionsSync(data);
        });
    }

    /**
     * Gère la synchronisation du menu depuis MongoDB
     */
    async _handleMenuSync(data) {
        try {
            const { restaurantId } = data || {};

            if (!dbManager.db) {
                console.log('[cloud-sync] ⚠️ MongoDB non connecté, impossible de synchroniser le menu');
                return;
            }

            // Charger le menu depuis MongoDB
            const menuDoc = await dbManager.menus.findOne({ restaurantId: restaurantId || 'les-emirs' });
            if (!menuDoc || !menuDoc.menu) {
                console.log('[cloud-sync] ⚠️ Menu non trouvé dans MongoDB');
                return;
            }

            // Sauvegarder en fichier JSON local
            const fsp = require('fs').promises;
            const path = require('path');
            const RESTAURANTS_DIR = path.join(__dirname, '..', '..', 'data', 'restaurants');
            const restaurantDir = path.join(RESTAURANTS_DIR, restaurantId || 'les-emirs');

            await fsp.mkdir(restaurantDir, { recursive: true });
            const menuPath = path.join(restaurantDir, 'menu.json');
            await fsp.writeFile(menuPath, JSON.stringify(menuDoc.menu, null, 2), 'utf8');

            console.log(`[cloud-sync] ✅ Menu synchronisé depuis Cloud: ${restaurantId || 'les-emirs'}`);

            // Invalider le cache en mémoire
            const menuSync = require('./menuSync');
            menuSync.clearMenuCache(restaurantId || 'les-emirs');

            // Émettre un événement pour que l'interface se rafraîchisse
            const socketManager = require('./socket');
            const localIO = socketManager.getIO();
            if (localIO) {
                localIO.emit('menu:updated', { restaurantId, source: 'cloud-sync' });
                console.log('[cloud-sync] 📡 Événement menu:updated émis localement');
            }

            // Appeler les callbacks enregistrés
            for (const cb of this.callbacks['sync:menu']) {
                try { await cb(data); } catch (e) { console.error('[cloud-sync] Erreur callback sync:menu:', e); }
            }
        } catch (e) {
            console.error('[cloud-sync] ❌ Erreur synchronisation menu:', e);
        }
    }

    /**
     * Gère la synchronisation des permissions depuis MongoDB
     */
    async _handlePermissionsSync(data) {
        try {
            if (!dbManager.db) {
                console.log('[cloud-sync] ⚠️ MongoDB non connecté, impossible de synchroniser les permissions');
                return;
            }

            // Charger les permissions depuis MongoDB
            const profiles = await dbManager.serverPermissions.find({}).toArray();
            if (!profiles || profiles.length === 0) {
                console.log('[cloud-sync] ⚠️ Aucun profil trouvé dans MongoDB');
                return;
            }

            // Nettoyer les champs MongoDB
            const cleaned = profiles.map(({ _id, lastSynced, ...rest }) => rest);

            // Sauvegarder en fichier JSON local
            const fsp = require('fs').promises;
            const path = require('path');
            const dataStore = require('../data');
            const PERMISSIONS_FILE = dataStore.SERVER_PERMISSIONS_FILE;

            await fsp.mkdir(path.dirname(PERMISSIONS_FILE), { recursive: true });
            await fsp.writeFile(PERMISSIONS_FILE, JSON.stringify(cleaned, null, 2), 'utf8');

            console.log(`[cloud-sync] ✅ Permissions synchronisées depuis Cloud: ${cleaned.length} profil(s)`);

            // Émettre un événement pour que l'interface se rafraîchisse
            const socketManager = require('./socket');
            const localIO = socketManager.getIO();
            if (localIO) {
                localIO.emit('permissions:updated', { source: 'cloud-sync' });
                console.log('[cloud-sync] 📡 Événement permissions:updated émis localement');
            }

            // Appeler les callbacks enregistrés
            for (const cb of this.callbacks['sync:permissions']) {
                try { await cb(data); } catch (e) { console.error('[cloud-sync] Erreur callback sync:permissions:', e); }
            }
        } catch (e) {
            console.error('[cloud-sync] ❌ Erreur synchronisation permissions:', e);
        }
    }

    /**
     * Enregistre un callback pour un événement de synchronisation
     */
    onSync(event, callback) {
        if (this.callbacks[event]) {
            this.callbacks[event].push(callback);
        }
    }

    /**
     * Force une synchronisation complète depuis le Cloud
     */
    async forceSync() {
        if (!this.isConnected) {
            console.log('[cloud-sync] ⚠️ Non connecté au Cloud, impossible de forcer la sync');
            return false;
        }

        console.log('[cloud-sync] 🔄 Synchronisation forcée depuis le Cloud...');
        await this._handleMenuSync({ restaurantId: 'les-emirs' });
        await this._handlePermissionsSync({});
        return true;
    }

    /**
     * Déconnecte du serveur Cloud
     */
    disconnect() {
        if (this.socket) {
            this.socket.disconnect();
            this.socket = null;
            this.isConnected = false;
            console.log('[cloud-sync] 🔌 Déconnecté du serveur Cloud');
        }
    }
}

// Singleton
const cloudSyncClient = new CloudSyncClient();

module.exports = cloudSyncClient;
