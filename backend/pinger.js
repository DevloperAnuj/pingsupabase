const fetch = require('node-fetch');
const { appendLog } = require('./vault');

// Ping a single client's Supabase database
async function pingClient(client) {
  const url = `${client.supabaseUrl}/rest/v1/${client.tableName}?select=*&limit=1`;
  const start = Date.now();
  let status = 'unknown';
  let httpCode = null;
  let error = null;

  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: {
        'apikey': client.anonKey,
        'Authorization': `Bearer ${client.anonKey}`
      },
      timeout: 15000
    });
    httpCode = res.status;
    status = res.status === 200 ? 'success' : 'failed';
  } catch (err) {
    status = 'error';
    error = err.message;
  }

  const duration = Date.now() - start;
  const logEntry = {
    clientId: client.id,
    clientName: client.name,
    timestamp: new Date().toISOString(),
    status,
    httpCode,
    duration,
    error
  };

  appendLog(logEntry);
  return logEntry;
}

// Ping all clients in the vault
async function pingAll(clients) {
  console.log(`[Ping] Starting ping for ${clients.length} client(s)...`);
  const results = await Promise.allSettled(clients.map(pingClient));
  const summary = results.map(r => r.status === 'fulfilled' ? r.value : { status: 'error', error: r.reason });
  const passed = summary.filter(r => r.status === 'success').length;
  console.log(`[Ping] Done. ${passed}/${clients.length} successful.`);
  return summary;
}

module.exports = { pingClient, pingAll };
