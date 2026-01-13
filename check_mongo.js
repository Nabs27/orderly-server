// Script de diagnostic MongoDB
const { MongoClient } = require('mongodb');
require('dotenv').config();

async function checkData() {
  const client = new MongoClient(process.env.MONGODB_URI);
  await client.connect();
  const db = client.db();

  console.log('🔍 Vérification des données MongoDB...');

  // Compter toutes les commandes
  const totalOrders = await db.collection('orders').countDocuments();
  const totalArchived = await db.collection('archivedOrders').countDocuments();

  console.log(`📊 Total commandes: ${totalOrders}`);
  console.log(`📊 Total archivées: ${totalArchived}`);

  // Vérifier les serverIdentifier
  const serverIds = await db.collection('orders').distinct('serverIdentifier');
  const archivedServerIds = await db.collection('archivedOrders').distinct('serverIdentifier');

  console.log(`🏷️ ServerIdentifier dans orders: ${JSON.stringify(serverIds)}`);
  console.log(`🏷️ ServerIdentifier dans archived: ${JSON.stringify(archivedServerIds)}`);

  // Dernières commandes
  const recentOrders = await db.collection('orders').find({}).sort({ _id: -1 }).limit(3).toArray();
  console.log(`📋 Dernières commandes:`, recentOrders.map(o => ({
    id: o.id,
    table: o.table,
    serverId: o.serverIdentifier,
    lastSync: o.lastSync
  })));

  // Dernières archivées
  const recentArchived = await db.collection('archivedOrders').find({}).sort({ _id: -1 }).limit(3).toArray();
  console.log(`📋 Dernières archivées:`, recentArchived.map(o => ({
    id: o.id,
    table: o.table,
    serverId: o.serverIdentifier,
    lastSync: o.lastSync
  })));

  await client.close();
}

checkData().catch(console.error);