import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

final absencesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/absences/mine');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

class AbsencesScreen extends ConsumerStatefulWidget {
  const AbsencesScreen({super.key});
  @override
  ConsumerState<AbsencesScreen> createState() => _AbsencesState();
}

class _AbsencesState extends ConsumerState<AbsencesScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primary)), child: child!),
    );
    if (picked != null) setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  Future<void> _submitRequest() async {
    if (_startDate == null || _endDate == null || _reasonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all required fields')));
      return;
    }
    try {
      await ref.read(dioProvider).post('/absences', data: {
        'startDate': _startDate!.toIso8601String(),
        'endDate': _endDate!.toIso8601String(),
        'reason': _reasonCtrl.text,
      });
      ref.invalidate(absencesProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted!'), backgroundColor: AppTheme.success));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    }
  }

  void _showRequestSheet() {
    setState(() { _startDate = null; _endDate = null; _reasonCtrl.clear(); });
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setS) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request Absence', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _dateTile(_startDate, 'Start date', () async {
                  await _pickDate(true); setS(() {});
                })),
                const SizedBox(width: 12),
                Expanded(child: _dateTile(_endDate, 'End date', () async {
                  await _pickDate(false); setS(() {});
                })),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Reason *', labelStyle: TextStyle(color: AppTheme.textMuted)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _submitRequest, child: const Text('Submit Request')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final absences = ref.watch(absencesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Absences'),
        actions: [IconButton(icon: const Icon(Icons.add_rounded), onPressed: _showRequestSheet)],
      ),
      body: absences.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString()),
        data: (list) {
          if (list.isEmpty) return const EmptyStateWidget(icon: Icons.event_busy_outlined, title: 'No absence requests', subtitle: 'Tap + to submit one');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final a = list[i];
              final statusColor = (a['status'] as String).absenceStatusColor;
              final start = DateTime.parse(a['startDate']);
              final end = DateTime.parse(a['endDate']);
              final days = end.difference(start).inDays + 1;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(a['reason'], style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                      StatusBadge(status: a['status'], color: statusColor),
                    ]),
                    const SizedBox(height: 6),
                    Text('${DateFormat('MMM d').format(start)} → ${DateFormat('MMM d, y').format(end)} ($days days)',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _dateTile(DateTime? date, String hint, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(date != null ? DateFormat('MMM d').format(date) : hint,
            style: TextStyle(color: date != null ? AppTheme.textPrimary : AppTheme.textMuted, fontSize: 12)),
        ]),
      ),
    );
  }
}
