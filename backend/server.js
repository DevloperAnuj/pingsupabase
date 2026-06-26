const express = require('express');
const cors = require('cors');
const cron = require('node-cron');
const { v4: uuidv4 } = require('uuid');
const { loadVault, saveVault, vaultExists, loadLogs } = require('./vault');
const { pingAll, pingClient } = require('./pinger');

const app = express();
const PORT = process.env.PORT || 3000;

// In-memory session: stores the master password for the current server session.
// This is intentional — the password is never written to disk.
// If the server restarts, the cron will re-use MASTER_PASSWORD env var if set.
let sessionPassword = process.env.MASTER_PASSWORD || null;

app.use(cors());
app.use(express.json());

// ─── Middleware: require password on protected routes ─────────────────────────
function requireAuth(req, res, next) {
  const pw = req.headers['x-master-password'] || sessionPassword;
  if (!pw) return res.status(401).json({ error: 'No master password provided' });
  req._password = pw;
  next();
}

// ─── Routes ───────────────────────────────────────────────────────────────────

// Health check
app.get('/api/health', (req, res) => {
  res.json({ ok: true, vaultExists: vaultExists() });
});

// Unlock / verify password
app.post('/api/unlock', (req, res) => {
  const { password } = req.body;
  if (!password) return res.status(400).json({ error: 'Password required' });
  try {
    loadVault(password); // throws WRONG_PASSWORD if wrong
    sessionPassword = password;
    res.json({ ok: true });
  } catch (e) {
    if (e.message === 'WRONG_PASSWORD') {
      return res.status(401).json({ error: 'Wrong password' });
    }
    res.status(500).json({ error: e.message });
  }
});

// Lock the session
app.post('/api/lock', (req, res) => {
  sessionPassword = process.env.MASTER_PASSWORD || null;
  res.json({ ok: true });
});

// Get all clients
app.get('/api/clients', requireAuth, (req, res) => {
  try {
    const clients = loadVault(req._password);
    // Never send the anon key in list view — only send masked version
    const safe = clients.map(c => ({
      ...c,
      anonKey: c.anonKey ? '••••••••' + c.anonKey.slice(-6) : ''
    }));
    res.json(safe);
  } catch (e) {
    res.status(401).json({ error: 'Wrong password' });
  }
});

// Get single client (full, including key — for edit screen)
app.get('/api/clients/:id', requireAuth, (req, res) => {
  try {
    const clients = loadVault(req._password);
    const client = clients.find(c => c.id === req.params.id);
    if (!client) return res.status(404).json({ error: 'Not found' });
    res.json(client);
  } catch (e) {
    res.status(401).json({ error: 'Wrong password' });
  }
});

// Add client
app.post('/api/clients', requireAuth, (req, res) => {
  try {
    const clients = loadVault(req._password);
    const newClient = {
      id: uuidv4(),
      name: req.body.name,
      supabaseUrl: req.body.supabaseUrl.replace(/\/$/, ''),
      anonKey: req.body.anonKey,
      tableName: req.body.tableName || 'users',
      projectEndDate: req.body.projectEndDate || null,
      notes: req.body.notes || '',
      createdAt: new Date().toISOString()
    };
    clients.push(newClient);
    saveVault(clients, req._password);
    res.json({ ok: true, id: newClient.id });
  } catch (e) {
    res.status(401).json({ error: e.message });
  }
});

// Update client
app.put('/api/clients/:id', requireAuth, (req, res) => {
  try {
    const clients = loadVault(req._password);
    const idx = clients.findIndex(c => c.id === req.params.id);
    if (idx === -1) return res.status(404).json({ error: 'Not found' });
    clients[idx] = {
      ...clients[idx],
      name: req.body.name ?? clients[idx].name,
      supabaseUrl: (req.body.supabaseUrl ?? clients[idx].supabaseUrl).replace(/\/$/, ''),
      anonKey: req.body.anonKey ?? clients[idx].anonKey,
      tableName: req.body.tableName ?? clients[idx].tableName,
      projectEndDate: req.body.projectEndDate ?? clients[idx].projectEndDate,
      notes: req.body.notes ?? clients[idx].notes,
      updatedAt: new Date().toISOString()
    };
    saveVault(clients, req._password);
    res.json({ ok: true });
  } catch (e) {
    res.status(401).json({ error: e.message });
  }
});

// Delete client
app.delete('/api/clients/:id', requireAuth, (req, res) => {
  try {
    const clients = loadVault(req._password);
    const filtered = clients.filter(c => c.id !== req.params.id);
    if (filtered.length === clients.length) return res.status(404).json({ error: 'Not found' });
    saveVault(filtered, req._password);
    res.json({ ok: true });
  } catch (e) {
    res.status(401).json({ error: e.message });
  }
});

// Get ping logs
app.get('/api/logs', requireAuth, (req, res) => {
  const logs = loadLogs();
  res.json(logs);
});

// Manual ping — single client
app.post('/api/ping/:id', requireAuth, async (req, res) => {
  try {
    const clients = loadVault(req._password);
    const client = clients.find(c => c.id === req.params.id);
    if (!client) return res.status(404).json({ error: 'Not found' });
    const result = await pingClient(client);
    res.json(result);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Ping all — called by Coolify cron
app.post('/api/ping-all', async (req, res) => {
  const pw = req.headers['x-master-password'] || sessionPassword;
  if (!pw) return res.status(401).json({ error: 'No password' });
  try {
    const clients = loadVault(pw);
    const results = await pingAll(clients);
    res.json({ ok: true, results });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ─── Built-in cron (every 3 days at 02:00 UTC) ───────────────────────────────
cron.schedule('0 2 */3 * *', async () => {
  const pw = sessionPassword;
  if (!pw) {
    console.log('[Cron] Skipped — no master password in session. Set MASTER_PASSWORD env var.');
    return;
  }
  try {
    const clients = loadVault(pw);
    console.log(`[Cron] Running scheduled ping for ${clients.length} client(s)`);
    await pingAll(clients);
  } catch (e) {
    console.error('[Cron] Error:', e.message);
  }
});

app.listen(PORT, () => {
  console.log(`Supabase Vault backend running on port ${PORT}`);
  if (sessionPassword) {
    console.log('[Auth] MASTER_PASSWORD env var set — cron will run automatically.');
  } else {
    console.log('[Auth] No MASTER_PASSWORD set — unlock via UI to enable cron.');
  }
});
