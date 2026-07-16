import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/constants.dart';
import '../../clients/data/client_provider.dart';
import '../data/order_provider.dart';

class OrderFormScreen extends ConsumerStatefulWidget {
  final int? orderId;
  const OrderFormScreen({super.key, this.orderId});
  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedClientId;
  final _eventTypeCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _packageCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _eventDate;
  DateTime? _deliveryDate;
  String _status = 'PENDING';
  bool _loading = false;
  bool _loadingExistingOrder = false;

  bool get isEdit => widget.orderId != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _loadExistingOrder();
    }
  }

  Future<void> _loadExistingOrder() async {
    setState(() => _loadingExistingOrder = true);
    try {
      final order =
          await ref.read(orderRepositoryProvider).getById(widget.orderId!);
      if (!mounted) return;
      setState(() {
        _selectedClientId = order.clientId;
        _eventTypeCtrl.text = order.eventType;
        _locationCtrl.text = order.location;
        _packageCtrl.text = order.package;
        _amountCtrl.text = order.totalAmount.toString();
        _depositCtrl.text = order.deposit.toString();
        _notesCtrl.text = order.notes ?? '';
        _eventDate = order.eventDate;
        _deliveryDate = order.deliveryDate;
        _status = order.status;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load order: $e'),
            backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _loadingExistingOrder = false);
    }
  }

  @override
  void dispose() {
    _eventTypeCtrl.dispose();
    _locationCtrl.dispose();
    _packageCtrl.dispose();
    _amountCtrl.dispose();
    _depositCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isEvent) async {
    final currentDate = isEvent ? _eventDate : _deliveryDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
          data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: AppTheme.primary)),
          child: child!),
    );
    if (picked != null) {
      setState(() => isEvent ? _eventDate = picked : _deliveryDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a client')));
      return;
    }
    if (_eventDate == null || _deliveryDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select dates')));
      return;
    }
    setState(() => _loading = true);
    try {
      final data = {
        'clientId': _selectedClientId,
        'eventType': _eventTypeCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'package': _packageCtrl.text.trim(),
        'totalAmount': double.parse(_amountCtrl.text),
        'deposit':
            _depositCtrl.text.isEmpty ? 0 : double.parse(_depositCtrl.text),
        'eventDate': _eventDate!.toUtc().toIso8601String(),
        'deliveryDate': _deliveryDate!.toUtc().toIso8601String(),
        'internalDeadline': _deliveryDate!.toUtc().toIso8601String(),
        'status': _status,
        if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text,
      };
      final repo = ref.read(orderRepositoryProvider);
      if (isEdit) {
        await repo.update(widget.orderId!, data);
      } else {
        await repo.create(data);
      }
      ref.invalidate(ordersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEdit ? 'Order updated!' : 'Order created!'),
          backgroundColor: AppTheme.success));
      context.go('/orders');
    } catch (e) {
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider(null));

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Order' : 'New Order')),
      body: _loadingExistingOrder && isEdit
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Client selector
                  _label('Client *'),
                  const SizedBox(height: 6),
                  clients.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(e.toString(),
                        style: const TextStyle(color: AppTheme.error)),
                    data: (list) => DropdownButtonFormField<int>(
                      initialValue: _selectedClientId,
                      dropdownColor: AppTheme.surface,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration:
                          const InputDecoration(hintText: 'Select client'),
                      items: list
                          .map((c) => DropdownMenuItem(
                              value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedClientId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _textField(
                      'Event Type *', _eventTypeCtrl, 'Wedding, Corporate...'),
                  _textField('Location *', _locationCtrl, 'Venue, City'),
                  _textField('Package *', _packageCtrl, 'Gold, Premium...'),
                  _textField('Total Amount (DA) *', _amountCtrl, '0',
                      type: TextInputType.number),
                  _textField('Deposit (DA)', _depositCtrl, '0',
                      type: TextInputType.number, required: false),
                  _label('Status *'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    dropdownColor: AppTheme.surface,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration:
                        const InputDecoration(hintText: 'Select status'),
                    items: AppConstants.orderStatuses
                        .map((status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  // Event date
                  _label('Event Date *'),
                  const SizedBox(height: 6),
                  _dateTile(
                      _eventDate, 'Pick event date', () => _pickDate(true)),
                  const SizedBox(height: 16),
                  _label('Delivery Date *'),
                  const SizedBox(height: 6),
                  _dateTile(_deliveryDate, 'Pick delivery date',
                      () => _pickDate(false)),
                  const SizedBox(height: 16),
                  _textField('Notes', _notesCtrl, '',
                      maxLines: 3, required: false),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)
                        : Text(isEdit ? 'Save Changes' : 'Create Order'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500));

  Widget _textField(String label, TextEditingController ctrl, String hint,
      {TextInputType? type, int maxLines = 1, bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: type,
            maxLines: maxLines,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(hintText: hint),
            validator: required ? (v) => v!.isEmpty ? 'Required' : null : null,
          ),
        ],
      ),
    );
  }

  Widget _dateTile(DateTime? date, String hint, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined,
              size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          Text(date != null ? DateFormat('MMM d, y').format(date) : hint,
              style: TextStyle(
                  color:
                      date != null ? AppTheme.textPrimary : AppTheme.textMuted,
                  fontSize: 14)),
        ]),
      ),
    );
  }
}
