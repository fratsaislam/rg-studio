import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/client_provider.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  final int? clientId;
  const ClientFormScreen({super.key, this.clientId});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;
  bool _initialLoaded = false;

  bool get isEdit => widget.clientId != null;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _companyCtrl.dispose(); _addressCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  void _populate(Client c) {
    _nameCtrl.text = c.name;
    _emailCtrl.text = c.email ?? '';
    _phoneCtrl.text = c.phone ?? '';
    _companyCtrl.text = c.company ?? '';
    _addressCtrl.text = c.address ?? '';
    _notesCtrl.text = c.notes ?? '';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_companyCtrl.text.isNotEmpty) 'company': _companyCtrl.text.trim(),
        if (_addressCtrl.text.isNotEmpty) 'address': _addressCtrl.text.trim(),
        if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
      };
      final repo = ref.read(clientRepositoryProvider);
      if (isEdit) {
        await repo.update(widget.clientId!, data);
      } else {
        await repo.create(data);
      }
      ref.invalidate(clientsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit ? 'Client updated!' : 'Client created!'),
        backgroundColor: AppTheme.success,
      ));
      context.go('/clients');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEdit && !_initialLoaded) {
      final detail = ref.watch(clientDetailProvider(widget.clientId!));
      detail.whenData((c) { if (!_initialLoaded) { _populate(c); setState(() => _initialLoaded = true); } });
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Client' : 'New Client')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field('Full Name *', _nameCtrl, validator: (v) => v!.isEmpty ? 'Required' : null),
            _field('Email', _emailCtrl, type: TextInputType.emailAddress),
            _field('Phone', _phoneCtrl, type: TextInputType.phone),
            _field('Company', _companyCtrl),
            _field('Address', _addressCtrl),
            _field('Notes', _notesCtrl, maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(isEdit ? 'Save Changes' : 'Create Client'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? type, int maxLines = 1, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: type,
            maxLines: maxLines,
            style: const TextStyle(color: AppTheme.textPrimary),
            validator: validator,
          ),
        ],
      ),
    );
  }
}
