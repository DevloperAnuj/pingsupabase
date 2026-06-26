# Supabase Vault

Self-hosted encrypted vault for managing Supabase client credentials with automatic keep-alive pinging.

## Stack
- **Frontend**: Flutter Web served by Nginx
- **Backend**: Node.js (Express + node-cron)
- **Crypto**: AES-256-GCM with PBKDF2 key derivation
- **Storage**: Encrypted JSON file on Docker volume

---

## Deploy on Coolify

### 1. Push this repo to GitHub (private)

### 2. Add to Coolify
- New Resource → Docker Compose
- Point to your repo
- Set the compose file to `docker-compose.yml`

### 3. Ports & domain — handled by Traefik (no host ports)
This compose file publishes **no host ports**, so it can't conflict with
other apps on the server. The `frontend` service uses Coolify's magic
variable `SERVICE_FQDN_FRONTEND_80`, so Coolify generates a domain and its
Traefik proxy routes it to the frontend on port 80. To use your own domain,
set it on the `frontend` service in the Coolify UI (Domains field).

The `backend` is **never publicly exposed** — the frontend's nginx proxies
`/api/` to it over the private Docker network. That's why no second domain or
port is needed.

### 4. Set environment variable (optional but recommended)
In Coolify environment variables:
```
MASTER_PASSWORD=your-strong-master-password
```
This allows the built-in cron (every 3 days at 02:00 UTC) to run automatically
after server restarts without needing to unlock the UI. This built-in cron is
the primary keep-alive mechanism.

### 5. Optional — extra Coolify scheduled task (redundancy)
The built-in cron already covers keep-alive when `MASTER_PASSWORD` is set. If
you also want a Coolify-managed task, add one in your project → Scheduled Tasks
that execs the `backend` container:
```
Container: backend
Command:   curl -s -X POST http://localhost:3000/api/ping-all -H "x-master-password: your-master-password"
Schedule:  0 2 */3 * *
```

### 6. Access the app
Open the domain Coolify assigned to the `frontend` service. On the unlock
screen, leave **Backend URL blank** — the app talks to the backend through the
same domain (nginx proxy). Only fill it in if your backend runs on a separate
host.

---

## First-time setup
1. Open the app URL
2. Enter your Coolify backend URL (e.g. `https://vault.yourdomain.com`)
3. Choose a strong master password (this encrypts everything — don't lose it)
4. Click "Create vault"
5. Add your first student client

---

## Security model
- Master password is never stored anywhere
- All client data encrypted with AES-256-GCM before writing to disk
- Each encryption uses a fresh random salt + IV
- Ping logs are not encrypted (they contain no sensitive data)
- The anon key shown in the client list is masked (last 6 chars only)

---

## API endpoints (all require `x-master-password` header except health)

| Method | Path | Description |
|--------|------|-------------|
| GET | /api/health | Check if backend is reachable |
| POST | /api/unlock | Verify password and start session |
| POST | /api/lock | Clear session |
| GET | /api/clients | List all clients (masked keys) |
| GET | /api/clients/:id | Get single client (full data) |
| POST | /api/clients | Add client |
| PUT | /api/clients/:id | Update client |
| DELETE | /api/clients/:id | Delete client |
| GET | /api/logs | Get ping log history |
| POST | /api/ping/:id | Ping one client now |
| POST | /api/ping-all | Ping all clients (used by cron) |
