import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final logs = await ApiService.getLogs();
      setState(() { _logs = logs; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceCard,
        elevation: 0,
        title: const Text('Ping logs', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.surfaceBorder),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _logs.isEmpty
              ? const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.history_rounded, size: 48, color: AppTheme.textMuted),
                    SizedBox(height: 12),
                    Text('No ping logs yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
                    SizedBox(height: 6),
                    Text('Trigger a manual ping from the dashboard', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _logs.length,
                  itemBuilder: (_, i) {
                    final log = _logs[i];
                    final isSuccess = log['status'] == 'success';
                    final time = _formatTime(log['timestamp']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.surfaceBorder),
                      ),
                      child: Row(children: [
                        Icon(
                          isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: isSuccess ? AppTheme.success : AppTheme.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(log['clientName'] ?? log['clientId'] ?? '',
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(
                            isSuccess
                                ? 'Success · ${log['duration']}ms · HTTP ${log['httpCode']}'
                                : 'Failed · ${log['error'] ?? 'HTTP ${log['httpCode']}'}',
                            style: TextStyle(color: isSuccess ? AppTheme.success : AppTheme.danger, fontSize: 12),
                          ),
                        ])),
                        Text(time, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ]),
                    );
                  },
                ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}
