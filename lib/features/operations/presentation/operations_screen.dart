import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../equipment/data/equipment_provider.dart';
import '../../planning/presentation/planning_screen.dart';

final dateCapacityProvider =
    FutureProvider.family<Map<String, dynamic>, DateTime>((ref, date) async {
  final res =
      await ref.read(dioProvider).get('/orders/capacity', queryParameters: {
    'date': DateFormat('yyyy-MM-dd').format(date),
  });
  return Map<String, dynamic>.from(res.data['data']);
});

final equipmentReservationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/equipment/reservations/all');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

final equipmentMovementsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/equipment/movements/all');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

class OperationsScreen extends ConsumerStatefulWidget {
  const OperationsScreen({super.key});

  @override
  ConsumerState<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Operations'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'Capacity'),
            Tab(text: 'Reservations'),
            Tab(text: 'Movements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _CapacityTab(
            selectedDate: _selectedDate,
            onPickDate: _pickDate,
          ),
          const _ReservationsTab(),
          const _MovementsTab(),
        ],
      ),
    );
  }
}

class _CapacityTab extends ConsumerWidget {
  final DateTime selectedDate;
  final VoidCallback onPickDate;

  const _CapacityTab({required this.selectedDate, required this.onPickDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capacity = ref.watch(dateCapacityProvider(selectedDate));
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: () async => ref.invalidate(dateCapacityProvider(selectedDate)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: onPickDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, MMM d, y').format(selectedDate),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.edit_calendar_rounded,
                      color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          capacity.when(
            loading: () => const AppLoadingWidget(),
            error: (e, _) => AppErrorWidget(message: e.toString()),
            data: (data) {
              final maxOrders = data['maxOrders'] ?? 3;
              final currentOrders =
                  data['currentOrders'] ?? data['bookedOrders'] ?? 0;
              final isBlocked = data['isBlocked'] == true;
              final available = data['available'] == true;
              final remaining = (maxOrders is num && currentOrders is num)
                  ? maxOrders.toInt() - currentOrders.toInt()
                  : 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      StatCard(
                        title: 'Booked',
                        value: '$currentOrders',
                        icon: Icons.event_available_rounded,
                        color: AppTheme.info,
                      ),
                      StatCard(
                        title: 'Daily limit',
                        value: '$maxOrders',
                        icon: Icons.speed_rounded,
                        color: AppTheme.primary,
                      ),
                      StatCard(
                        title: 'Remaining',
                        value: remaining < 0 ? '0' : '$remaining',
                        icon: Icons.timeline_rounded,
                        color: available ? AppTheme.success : AppTheme.error,
                      ),
                      StatCard(
                        title: 'Blocked',
                        value: isBlocked ? 'Yes' : 'No',
                        icon: Icons.block_rounded,
                        color: isBlocked ? AppTheme.error : AppTheme.success,
                      ),
                    ],
                  ),
                  if (data['reason'] != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      data['reason'],
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showCapacitySheet(context, ref, data),
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('Update Capacity'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCapacitySheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
  ) {
    final maxCtrl = TextEditingController(text: '${data['maxOrders'] ?? 3}');
    final reasonCtrl =
        TextEditingController(text: data['reason']?.toString() ?? '');
    bool isBlocked = data['isBlocked'] == true;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Daily Capacity',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Maximum orders'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: isBlocked,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.error,
                title: const Text('Block this date',
                    style: TextStyle(color: AppTheme.textPrimary)),
                onChanged: (v) => setSheetState(() => isBlocked = v),
              ),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(dioProvider).put('/orders/capacity', data: {
                    'date': selectedDate.toUtc().toIso8601String(),
                    'maxOrders': int.tryParse(maxCtrl.text) ?? 0,
                    'isBlocked': isBlocked,
                    if (reasonCtrl.text.trim().isNotEmpty)
                      'reason': reasonCtrl.text.trim(),
                  });
                  ref.invalidate(dateCapacityProvider(selectedDate));
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Capacity'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationsTab extends ConsumerWidget {
  const _ReservationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservations = ref.watch(equipmentReservationsProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showReservationSheet(context, ref),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: reservations.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(equipmentReservationsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.assignment_outlined,
              title: 'No equipment reservations',
            );
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: () async =>
                ref.invalidate(equipmentReservationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = list[i];
                final equipment = r['equipment'] as Map<String, dynamic>?;
                final team = r['team'] as Map<String, dynamic>?;
                final start = DateTime.parse(r['startDate']);
                final end = DateTime.parse(r['endDate']);
                return Dismissible(
                  key: ValueKey('reservation-${r['id']}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.assignment_return_rounded,
                        color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await ref
                        .read(dioProvider)
                        .delete('/equipment/reservations/${r['id']}');
                    ref.invalidate(equipmentReservationsProvider);
                    ref.invalidate(equipmentListProvider);
                    return false;
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(equipment?['name'] ?? 'Equipment',
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(team?['name'] ?? 'Team',
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 8),
                        Text(
                          '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d, y').format(end)}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showReservationSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ReservationSheet(),
    );
  }
}

class _ReservationSheet extends ConsumerStatefulWidget {
  const _ReservationSheet();

  @override
  ConsumerState<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends ConsumerState<_ReservationSheet> {
  int? _equipmentId;
  int? _teamId;
  DateTime? _startDate;
  DateTime? _endDate;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppTheme.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _endDate = picked);
    }
  }

  Future<void> _save() async {
    if (_equipmentId == null ||
        _teamId == null ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select equipment, team and dates')));
      return;
    }
    await ref.read(dioProvider).post('/equipment/reservations', data: {
      'equipmentId': _equipmentId,
      'teamId': _teamId,
      'startDate': _startDate!.toUtc().toIso8601String(),
      'endDate': _endDate!.toUtc().toIso8601String(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    });
    ref.invalidate(equipmentReservationsProvider);
    ref.invalidate(equipmentMovementsProvider);
    ref.invalidate(equipmentListProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final equipment = ref.watch(equipmentListProvider);
    final teams = ref.watch(planningTeamsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reserve Equipment',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          equipment.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(e.toString(),
                style: const TextStyle(color: AppTheme.error)),
            data: (list) => DropdownButtonFormField<int>(
              initialValue: _equipmentId,
              dropdownColor: AppTheme.surface,
              decoration: const InputDecoration(labelText: 'Equipment'),
              items: list
                  .map((e) => DropdownMenuItem(
                      value: e.id, child: Text('${e.name} (${e.status})')))
                  .toList(),
              onChanged: (v) => setState(() => _equipmentId = v),
            ),
          ),
          const SizedBox(height: 12),
          teams.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(e.toString(),
                style: const TextStyle(color: AppTheme.error)),
            data: (list) => DropdownButtonFormField<int>(
              initialValue: _teamId,
              dropdownColor: AppTheme.surface,
              decoration: const InputDecoration(labelText: 'Team'),
              items: list
                  .map((t) => DropdownMenuItem(
                      value: t['id'] as int, child: Text(t['name'])))
                  .toList(),
              onChanged: (v) => setState(() => _teamId = v),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child:
                      _dateButton(_startDate, 'Start', () => _pickDate(true))),
              const SizedBox(width: 10),
              Expanded(
                  child: _dateButton(_endDate, 'End', () => _pickDate(false))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _save, child: const Text('Create Reservation')),
        ],
      ),
    );
  }

  Widget _dateButton(DateTime? date, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_rounded, size: 16),
      label: Text(date == null ? label : DateFormat('MMM d').format(date)),
    );
  }
}

class _MovementsTab extends ConsumerWidget {
  const _MovementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(equipmentMovementsProvider);
    return movements.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(equipmentMovementsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.history_rounded,
            title: 'No equipment movement history',
          );
        }
        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () async => ref.invalidate(equipmentMovementsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = list[i];
              final equipment = m['equipment'] as Map<String, dynamic>?;
              final actor = m['actor'] as Map<String, dynamic>?;
              final createdAt = DateTime.parse(m['createdAt']);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.swap_horiz_rounded,
                        color: AppTheme.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['type'] ?? 'MOVEMENT',
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(equipment?['name'] ?? 'Equipment',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          if (actor != null)
                            Text('${actor['firstName']} ${actor['lastName']}',
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                          if (m['notes'] != null)
                            Text(m['notes'],
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(DateFormat('MMM d').format(createdAt),
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
