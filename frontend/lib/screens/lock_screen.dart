import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme.dart';
import 'dashboard_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  // Blank = same-origin (proxied to the backend by nginx). The bundled deploy
  // needs no URL here; only fill it in if the backend lives on another host.
  final _urlController = TextEditingController(text: '');
  final _pwController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _vaultExists = false;
  bool _checkingHealth = true;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final saved = await ApiService.getBackendUrl();
    if (saved != null) _urlController.text = saved;
    // Health-check on load for both a saved URL and the blank same-origin case.
    await _checkHealth(_urlController.text.trim());
  }

  Future<void> _checkHealth(String url) async {
    setState(() { _checkingHealth = true; _error = null; });
    try {
      await ApiService.setBackendUrl(url);
      final h = await ApiService.health();
      setState(() {
        _vaultExists = h['vaultExists'] == true;
        _checkingHealth = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Cannot reach backend at $url';
        _checkingHealth = false;
      });
    }
  }

  Future<void> _unlock() async {
    if (_pwController.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await ApiService.unlock(_pwController.text.trim());
      if (ok && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        setState(() { _error = 'Wrong master password'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Connection error: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_rounded, size: 48, color: AppTheme.primary),
              const SizedBox(height: 20),
              const Text('Supabase Vault',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 6),
              Text(
                _vaultExists ? 'Enter your master password to unlock' : 'Set a master password to create your vault',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 40),

              // Backend URL
              Text('Backend URL', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(hintText: 'Leave blank — same server (recommended)'),
                )),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _checkingHealth ? null : () => _checkHealth(_urlController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceCard,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: _checkingHealth
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Connect'),
                ),
              ]),

              const SizedBox(height: 20),

              // Master password
              Text('Master password', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _pwController,
                obscureText: _obscure,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _vaultExists ? 'Enter your master password' : 'Choose a strong master password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _unlock(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _unlock,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_vaultExists ? 'Unlock vault' : 'Create vault', style: const TextStyle(fontSize: 15)),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Zero-knowledge encryption · AES-256-GCM · Your password never leaves this app',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
