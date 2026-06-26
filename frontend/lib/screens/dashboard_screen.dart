import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/theme.dart';
import 'lock_screen.dart';
import 'client_form_screen.dart';
import 'logs_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;
  final Set<String> _pinging = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final clients = await ApiService.getClients();
      final logs = await ApiService.getLogs();
      setState(() { _clients = clients; _logs = logs; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pingOne(String id) async {
    setState(() => _pinging.add(id));
    try {
      final result = await ApiService.pingClient(id);
      final ok = result['status'] == 'success';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'Ping successful' : 'Ping failed: ${result['error'] ?? result['httpCode']}'),
          backgroundColor: ok ? AppTheme.success : AppTheme.danger,
        ));
      }
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
    } finally {
      setState(() => _pinging.remove(id));
    }
  }

  Future<void> _pingAll() async {
    setState(() => _loading = true);
    try {
      await ApiService.pingAll();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All clients pinged'), backgroundColor: AppTheme.success));
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _deleteClient(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Delete client', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Remove $name from the vault?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteClient(id);
      await _load();
    }
  }

  Map<String, dynamic>? _lastLog(String clientId) {
    try {
      return _logs.firstWhere((l) => l['clientId'] == clientId);
    } catch (_) {
      return null;
    }
  }

  int _daysLeft(String? dateStr) {
    if (dateStr == null) return 999;
    try {
      final d = DateTime.parse(dateStr);
      return d.difference(DateTime.now()).inDays;
    } catch (_) {
      return 999;
    }
  }

  Color _daysColor(int days) {
    if (days < 14) return AppTheme.danger;
    if (days < 30) return AppTheme.warning;
    return AppTheme.success;
  }

  // Stats
  int get _totalClients => _clients.length;
  int get _healthyClients => _clients.where((c) {
    final log = _lastLog(c['id']);
    return log != null && log['status'] == 'success';
  }).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Row(children: [
        // Sidebar
        Container(
          width: 220,
          color: AppTheme.surfaceCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Icon(Icons.shield_rounded, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 10),
                  const Text('Vault', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                ]),
              ),
              const SizedBox(height: 32),
              _sideItem(Icons.dashboard_rounded, 'Dashboard', true),
              _sideItem(Icons.list_alt_rounded, 'Logs', false, onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LogsScreen()));
              }),
              const Spacer(),
              const Divider(color: AppTheme.surfaceBorder),
              _sideItem(Icons.lock_outline_rounded, 'Lock vault', false, onTap: () async {
                await ApiService.lock();
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LockScreen()));
              }),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Main content
        Expanded(
          child: Column(children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.surfaceBorder)),
              ),
              child: Row(children: [
                const Text('Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pingAll,
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Ping all'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    side: const BorderSide(color: AppTheme.surfaceBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientFormScreen()));
                    _load();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add client'),
                ),
              ]),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Stat cards
                            Row(children: [
                              _statCard('Total clients', '$_totalClients', Icons.people_rounded, AppTheme.primary),
                              const SizedBox(width: 16),
                              _statCard('Healthy', '$_healthyClients', Icons.check_circle_rounded, AppTheme.success),
                              const SizedBox(width: 16),
                              _statCard('Issues', '${_totalClients - _healthyClients}', Icons.warning_rounded, AppTheme.warning),
                              const SizedBox(width: 16),
                              _statCard('Ping schedule', 'Every 3 days', Icons.schedule_rounded, AppTheme.textSecondary),
                            ]),
                            const SizedBox(height: 32),

                            const Text('Clients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const SizedBox(height: 16),

                            if (_clients.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 60),
                                  child: Column(children: [
                                    const Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textMuted),
                                    const SizedBox(height: 12),
                                    const Text('No clients yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientFormScreen()));
                                        _load();
                                      },
                                      child: const Text('Add first client'),
                                    ),
                                  ]),
                                ),
                              )
                            else
                              ...(_clients.map((c) => _clientCard(c))),
                          ]),
                        ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sideItem(IconData icon, String label, bool active, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          border: Border(left: BorderSide(color: active ? AppTheme.primary : Colors.transparent, width: 3)),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: active ? AppTheme.primary : AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: active ? AppTheme.primary : AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _clientCard(Map<String, dynamic> client) {
    final log = _lastLog(client['id']);
    final isSuccess = log?['status'] == 'success';
    final isPinging = _pinging.contains(client['id']);
    final days = _daysLeft(client['projectEndDate']);
    final daysColor = _daysColor(days);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(children: [
        // Status dot
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: log == null ? AppTheme.textMuted : (isSuccess ? AppTheme.success : AppTheme.danger),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),

        // Info
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(client['name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text(client['supabaseUrl'] ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          if (log != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last ping: ${_formatTime(log['timestamp'])} · ${log['status']} · ${log['duration']}ms',
              style: TextStyle(fontSize: 12, color: isSuccess ? AppTheme.success : AppTheme.danger),
            ),
          ] else
            const Text('Never pinged', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ])),

        // Days left badge
        if (client['projectEndDate'] != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: daysColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: daysColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              days < 0 ? 'Ended' : '$days days left',
              style: TextStyle(color: daysColor, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),

        const SizedBox(width: 16),

        // Actions
        isPinging
            ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
            : IconButton(
                icon: const Icon(Icons.bolt_rounded, size: 20),
                color: AppTheme.textSecondary,
                tooltip: 'Ping now',
                onPressed: () => _pingOne(client['id']),
              ),
        IconButton(
          icon: const Icon(Icons.edit_rounded, size: 18),
          color: AppTheme.textSecondary,
          tooltip: 'Edit',
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(
              builder: (_) => ClientFormScreen(clientId: client['id']),
            ));
            _load();
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          color: AppTheme.danger,
          tooltip: 'Delete',
          onPressed: () => _deleteClient(client['id'], client['name']),
        ),
      ]),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return 'never';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}
