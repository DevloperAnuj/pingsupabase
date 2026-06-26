import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme.dart';

class ClientFormScreen extends StatefulWidget {
  final String? clientId;
  const ClientFormScreen({super.key, this.clientId});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _tableCtrl = TextEditingController(text: 'users');
  final _notesCtrl = TextEditingController();
  DateTime? _endDate;
  bool _loading = false;
  bool _obscureKey = true;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.clientId != null;
    if (_isEdit) _loadClient();
  }

  Future<void> _loadClient() async {
    setState(() => _loading = true);
    try {
      final c = await ApiService.getClient(widget.clientId!);
      _nameCtrl.text = c['name'] ?? '';
      _urlCtrl.text = c['supabaseUrl'] ?? '';
      _keyCtrl.text = c['anonKey'] ?? '';
      _tableCtrl.text = c['tableName'] ?? 'users';
      _notesCtrl.text = c['notes'] ?? '';
      if (c['projectEndDate'] != null) {
        _endDate = DateTime.tryParse(c['projectEndDate']);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading: $e'), backgroundColor: AppTheme.danger));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'supabaseUrl': _urlCtrl.text.trim(),
      'anonKey': _keyCtrl.text.trim(),
      'tableName': _tableCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'projectEndDate': _endDate?.toIso8601String(),
    };
    try {
      if (_isEdit) {
        await ApiService.updateClient(widget.clientId!, data);
      } else {
        await ApiService.addClient(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger));
    } finally {
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
        title: Text(_isEdit ? 'Edit client' : 'Add client',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.surfaceBorder),
        ),
      ),
      body: _loading && _isEdit
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Center(
              child: SizedBox(
                width: 560,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _field('Student / project name', _nameCtrl,
                          hint: 'e.g. Student A – Capstone 2025',
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 20),
                      _field('Supabase project URL', _urlCtrl,
                          hint: 'https://xxxxxx.supabase.co',
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 20),

                      // Anon key with toggle
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Anon key', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _keyCtrl,
                          obscureText: _obscureKey,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: 'eyJhbGci...',
                            hintStyle: const TextStyle(color: AppTheme.textMuted),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, size: 18),
                              onPressed: () => setState(() => _obscureKey = !_obscureKey),
                            ),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ]),
                      const SizedBox(height: 20),

                      _field('Table to ping', _tableCtrl,
                          hint: 'users',
                          hint2: 'Any table that exists in the DB'),

                      const SizedBox(height: 20),

                      // End date
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Project end date', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now().add(const Duration(days: 180)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 730)),
                            );
                            if (d != null) setState(() => _endDate = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.surfaceBorder),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.textMuted),
                              const SizedBox(width: 10),
                              Text(
                                _endDate != null
                                    ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                    : 'Select end date (optional)',
                                style: TextStyle(
                                  color: _endDate != null ? AppTheme.textPrimary : AppTheme.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                              if (_endDate != null) ...[
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(() => _endDate = null),
                                  child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                                ),
                              ],
                            ]),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 20),
                      _field('Notes', _notesCtrl, hint: 'Optional notes', maxLines: 3),

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _save,
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_isEdit ? 'Save changes' : 'Add client', style: const TextStyle(fontSize: 15)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint, String? hint2, String? Function(String?)? validator, int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
      if (hint2 != null) ...[
        const SizedBox(height: 2),
        Text(hint2, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ],
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(hintText: hint),
        validator: validator,
      ),
    ]);
  }
}
