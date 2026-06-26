const fs = require('fs');
const path = require('path');
const { encrypt, decrypt } = require('./crypto');

const VAULT_PATH = path.join(__dirname, 'data', 'vault.enc');
const LOGS_PATH = path.join(__dirname, 'data', 'logs.json');

function ensureDataDir() {
  const dir = path.join(__dirname, 'data');
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

// Load and decrypt the vault. Returns array of client objects.
function loadVault(password) {
  ensureDataDir();
  if (!fs.existsSync(VAULT_PATH)) return [];
  const blob = fs.readFileSync(VAULT_PATH, 'utf8').trim();
  if (!blob) return [];
  try {
    const json = decrypt(blob, password);
    return JSON.parse(json);
  } catch {
    throw new Error('WRONG_PASSWORD');
  }
}

// Encrypt and save the vault.
function saveVault(clients, password) {
  ensureDataDir();
  const blob = encrypt(JSON.stringify(clients), password);
  fs.writeFileSync(VAULT_PATH, blob, 'utf8');
}

// Check if vault file exists (used to know if first-time setup)
function vaultExists() {
  return fs.existsSync(VAULT_PATH);
}

// Load ping logs (unencrypted — not sensitive, just status info)
function loadLogs() {
  ensureDataDir();
  if (!fs.existsSync(LOGS_PATH)) return [];
  try {
    return JSON.parse(fs.readFileSync(LOGS_PATH, 'utf8'));
  } catch {
    return [];
  }
}

// Append a ping result to logs, keep last 200 entries
function appendLog(entry) {
  ensureDataDir();
  const logs = loadLogs();
  logs.unshift(entry);
  const trimmed = logs.slice(0, 200);
  fs.writeFileSync(LOGS_PATH, JSON.stringify(trimmed, null, 2), 'utf8');
}

module.exports = { loadVault, saveVault, vaultExists, loadLogs, appendLog };
