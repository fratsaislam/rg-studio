import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../data/equipment_provider.dart';
import '../../../shared/widgets/common_widgets.dart';

// ─── Color Helpers ────────────────────────────────────────────────────────────

extension MovementTypeColor on String {
  Color get movementTypeColor {
    switch (this) {
      case 'WITHDRAWAL':
        return AppTheme.error;
      case 'RETURN':
        return AppTheme.success;
      case 'STATUS_CHANGE':
        return AppTheme.primary;
      case 'INCIDENT':
        return AppTheme.warning;
      case 'INSPECTION':
        return const Color(0xFF8B5CF6);
      default:
        return AppTheme.textMuted;
    }
  }
}

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _fmtDateTime(DateTime? d) {
  if (d == null) return '—';
  return '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({super.key});
  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _invalidateAll() {
    ref.invalidate(equipmentListProvider);
    ref.invalidate(availableEquipmentProvider);
    ref.invalidate(currentlyOutProvider);
    ref.invalidate(movementsProvider);
    ref.invalidate(incidentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final currentlyOut = ref.watch(currentlyOutProvider);
    final incidents = ref.watch(incidentsProvider);

    final outCount = currentlyOut.maybeWhen(data: (l) => l.length, orElse: () => 0);
    final incCount = incidents.maybeWhen(
        data: (l) => l.where((i) => i.status != 'RESOLVED').length,
        orElse: () => 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Equipment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_rounded),
            tooltip: 'Check Out',
            onPressed: () => _showCheckoutSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Equipment',
            onPressed: () => _showAddDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.report_problem_rounded),
            tooltip: 'Report Incident',
            onPressed: () => _showIncidentSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: 'Inventory'),
            Tab(
              child: Row(children: [
                const Text('Out'),
                if (outCount > 0) ...[
                  const SizedBox(width: 6),
                  _Badge(count: outCount, color: AppTheme.primary),
                ],
              ]),
            ),
            const Tab(text: 'History'),
            Tab(
              child: Row(children: [
                const Text('Incidents'),
                if (incCount > 0) ...[
                  const SizedBox(width: 6),
                  _Badge(count: incCount, color: AppTheme.warning),
                ],
              ]),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _InventoryTab(onCheckout: (eq) => _showCheckoutSheet(context, preselectedId: eq.id)),
          _CurrentlyOutTab(onReturn: (mov) => _showReturnSheet(context, mov)),
          const _HistoryTab(),
          _IncidentsTab(onSaved: _invalidateAll),
        ],
      ),
    );
  }

  // ── Add Equipment Dialog ───────────────────────────────────────────────────

  void _showAddDialog(BuildContext context) {
    final identCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add Equipment',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField('Identifier *', identCtrl),
              _dialogField('Name *', nameCtrl),
              _dialogField('Category *', catCtrl),
              _dialogField('Brand', brandCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            onPressed: () async {
              if (identCtrl.text.isEmpty || nameCtrl.text.isEmpty || catCtrl.text.isEmpty) return;
              await ref.read(equipmentRepositoryProvider).create({
                'identifier': identCtrl.text.trim(),
                'name': nameCtrl.text.trim(),
                'category': catCtrl.text.trim(),
                if (brandCtrl.text.isNotEmpty) 'brand': brandCtrl.text.trim(),
              });
              _invalidateAll();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: AppTheme.textMuted)),
      ),
    );
  }

  // ── Check-Out Sheet ────────────────────────────────────────────────────────

  void _showCheckoutSheet(BuildContext context, {int? preselectedId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CheckOutSheet(
        preselectedEquipmentId: preselectedId,
        onSaved: _invalidateAll,
      ),
    );
  }

  // ── Return (Check-In) Sheet ────────────────────────────────────────────────

  void _showReturnSheet(BuildContext context, EquipmentMovement mov) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReturnSheet(
        movement: mov,
        onReturned: _invalidateAll,
      ),
    );
  }

  // ── Report Incident Sheet ──────────────────────────────────────────────────

  void _showIncidentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReportIncidentSheet(onSaved: _invalidateAll),
    );
  }
}

// ─── Badge widget ─────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(8)),
        child: Text('$count',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      );
}

// ─── Inventory Tab ────────────────────────────────────────────────────────────

class _InventoryTab extends ConsumerWidget {
  final void Function(Equipment) onCheckout;
  const _InventoryTab({required this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipment = ref.watch(equipmentListProvider);
    final currentlyOut = ref.watch(currentlyOutProvider);

    return equipment.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(equipmentListProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
              icon: Icons.construction_outlined,
              title: 'No equipment registered');
        }

        final outMovements = currentlyOut.maybeWhen(data: (l) => l, orElse: () => <EquipmentMovement>[]);

        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () async {
            ref.invalidate(equipmentListProvider);
            ref.invalidate(currentlyOutProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final e = list[i];
              final outMov = outMovements.where((m) => m.equipment?['id'] == e.id).firstOrNull;
              final statusColor = e.status.equipmentStatusColor;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: outMov != null
                            ? AppTheme.primary.withValues(alpha: 0.4)
                            : AppTheme.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.construction_rounded,
                              color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.name,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${e.identifier} · ${e.category}',
                                  style: const TextStyle(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                      fontFamily: 'monospace')),
                            ],
                          ),
                        ),
                        StatusBadge(status: e.status, color: statusColor),
                      ],
                    ),

                    // "Who has it" info
                    if (outMov != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.2))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline_rounded,
                                    color: AppTheme.primary, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  '${outMov.actor?['firstName']} ${outMov.actor?['lastName']}',
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 6),
                                Text('since ${_fmtDate(outMov.createdAt)}',
                                    style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 11)),
                              ],
                            ),
                            if (outMov.order != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Event: ${outMov.order!['eventType']}',
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Action buttons
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (e.status == 'AVAILABLE') ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => onCheckout(e),
                              icon: const Icon(Icons.upload_rounded, size: 14),
                              label: const Text('Check Out',
                                  style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: BorderSide(
                                    color: AppTheme.primary.withValues(alpha: 0.5)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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

// ─── Currently Out Tab ────────────────────────────────────────────────────────

class _CurrentlyOutTab extends ConsumerWidget {
  final void Function(EquipmentMovement) onReturn;
  const _CurrentlyOutTab({required this.onReturn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final out = ref.watch(currentlyOutProvider);
    return out.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(currentlyOutProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.inventory_2_outlined,
            title: 'All equipment is in',
            subtitle: 'Nothing has been checked out',
          );
        }
        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(currentlyOutProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final mov = list[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: mov.isOverdue
                            ? AppTheme.error.withValues(alpha: 0.5)
                            : AppTheme.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mov.equipment?['name'] ?? '',
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                          ),
                        ),
                        if (mov.isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppTheme.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color:
                                        AppTheme.error.withValues(alpha: 0.4))),
                            child: const Text('OVERDUE',
                                style: TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${mov.equipment?['identifier']} · ${mov.equipment?['category']}',
                      style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                        Icons.person_outline_rounded,
                        '${mov.actor?['firstName']} ${mov.actor?['lastName']}',
                        AppTheme.primary),
                    const SizedBox(height: 4),
                    _infoRow(Icons.calendar_today_outlined,
                        'Out: ${_fmtDateTime(mov.createdAt)}', AppTheme.textMuted),
                    if (mov.expectedReturnDate != null) ...[
                      const SizedBox(height: 4),
                      _infoRow(
                        Icons.access_time_rounded,
                        'Expected: ${_fmtDate(mov.expectedReturnDate)}',
                        mov.isOverdue ? AppTheme.error : AppTheme.textMuted,
                      ),
                    ],
                    if (mov.order != null) ...[
                      const SizedBox(height: 4),
                      _infoRow(
                          Icons.event_rounded,
                          '${mov.order!['eventType']}',
                          AppTheme.textMuted),
                    ],
                    if (mov.notes != null && mov.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _infoRow(Icons.notes_rounded, mov.notes!, AppTheme.textMuted),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => onReturn(mov),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Return Equipment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success.withValues(alpha: 0.2),
                          foregroundColor: AppTheme.success,
                          side: BorderSide(
                              color: AppTheme.success.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) => Row(
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color, fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
        ],
      );
}

// ─── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(movementsProvider);
    return movements.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(movementsProvider)),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
              icon: Icons.history_outlined,
              title: 'No movement history yet');
        }
        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(movementsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final mov = list[i];
              final typeColor = mov.type.movementTypeColor;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: typeColor.withValues(alpha: 0.3))),
                      child: Icon(_movIcon(mov.type), color: typeColor, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  mov.equipment?['name'] ?? '',
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: typeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                        color:
                                            typeColor.withValues(alpha: 0.3))),
                                child: Text(mov.type,
                                    style: TextStyle(
                                        color: typeColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (mov.actor != null)
                            Text(
                              'by ${mov.actor!['firstName']} ${mov.actor!['lastName']}',
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12),
                            ),
                          if (mov.order != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '📅 ${mov.order!['eventType']}',
                              style: const TextStyle(
                                  color: AppTheme.primary, fontSize: 12),
                            ),
                          ],
                          if (mov.returnedAt != null &&
                              mov.type == 'WITHDRAWAL') ...[
                            const SizedBox(height: 2),
                            Text(
                              '✓ Returned: ${_fmtDateTime(mov.returnedAt)}',
                              style: const TextStyle(
                                  color: AppTheme.success, fontSize: 11),
                            ),
                          ],
                          if (mov.expectedReturnDate != null &&
                              mov.type == 'WITHDRAWAL' &&
                              mov.returnedAt == null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '⏰ Expected: ${_fmtDate(mov.expectedReturnDate)}',
                              style: TextStyle(
                                  color: mov.isOverdue
                                      ? AppTheme.error
                                      : AppTheme.warning,
                                  fontSize: 11),
                            ),
                          ],
                          if (mov.notes != null && mov.notes!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('"${mov.notes}"',
                                style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic)),
                          ],
                          const SizedBox(height: 4),
                          Text(_fmtDateTime(mov.createdAt),
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _movIcon(String type) {
    switch (type) {
      case 'WITHDRAWAL':
        return Icons.upload_rounded;
      case 'RETURN':
        return Icons.download_rounded;
      case 'INCIDENT':
        return Icons.warning_amber_rounded;
      case 'INSPECTION':
        return Icons.check_circle_outline_rounded;
      case 'STATUS_CHANGE':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }
}

// ─── Incidents Tab ────────────────────────────────────────────────────────────

class _IncidentsTab extends ConsumerWidget {
  final VoidCallback onSaved;
  const _IncidentsTab({required this.onSaved});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider);
    return incidents.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(message: e.toString()),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
              icon: Icons.warning_amber_outlined,
              title: 'No incidents reported');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final inc = list[i];
            final statusColor = inc.status == 'RESOLVED'
                ? AppTheme.success
                : inc.status == 'IN_REVIEW'
                    ? AppTheme.warning
                    : AppTheme.error;
            return GestureDetector(
              onTap: () => _showReviewSheet(ctx, ref, inc),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(inc.equipment?['name'] ?? '',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600))),
                        StatusBadge(status: inc.status, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(inc.description,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    if (inc.photoUrl != null) ...[
                      const SizedBox(height: 6),
                      const Row(children: [
                        Icon(Icons.photo_rounded,
                            color: AppTheme.primary, size: 14),
                        SizedBox(width: 4),
                        Text('Photo attached',
                            style: TextStyle(
                                color: AppTheme.primary, fontSize: 12)),
                      ]),
                    ],
                    const SizedBox(height: 4),
                    Text(
                        '${inc.reporter?['firstName']} ${inc.reporter?['lastName']} · ${_fmtDateTime(inc.createdAt)}',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                    if (inc.resolution != null) ...[
                      const SizedBox(height: 4),
                      Text('✓ ${inc.resolution}',
                          style: const TextStyle(
                              color: AppTheme.success, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReviewSheet(BuildContext context, WidgetRef ref, Incident incident) {
    String status = incident.status;
    final resolutionCtrl =
        TextEditingController(text: incident.resolution ?? '');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Incident Review',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: status,
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const ['REPORTED', 'IN_REVIEW', 'RESOLVED']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setSheetState(() => status = v ?? status),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: resolutionCtrl,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration:
                    const InputDecoration(labelText: 'Resolution notes'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(equipmentRepositoryProvider)
                        .updateIncident(incident.id, {
                      'status': status,
                      if (resolutionCtrl.text.trim().isNotEmpty)
                        'resolution': resolutionCtrl.text.trim(),
                    });
                    ref.invalidate(incidentsProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Check-Out Sheet ──────────────────────────────────────────────────────────

class _CheckOutSheet extends ConsumerStatefulWidget {
  final int? preselectedEquipmentId;
  final VoidCallback onSaved;
  const _CheckOutSheet({this.preselectedEquipmentId, required this.onSaved});

  @override
  ConsumerState<_CheckOutSheet> createState() => _CheckOutSheetState();
}

class _CheckOutSheetState extends ConsumerState<_CheckOutSheet> {
  int? _equipmentId;
  DateTime? _expectedReturn;
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _equipmentId = widget.preselectedEquipmentId;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _expectedReturn = picked);
  }

  Future<void> _save() async {
    if (_equipmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select equipment')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(equipmentRepositoryProvider).checkOut(
            equipmentId: _equipmentId!,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            expectedReturnDate: _expectedReturn,
          );
      widget.onSaved();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Equipment checked out'),
          backgroundColor: AppTheme.success));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(availableEquipmentProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.upload_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Check Out Equipment',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          available.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) =>
                Text(e.toString(), style: const TextStyle(color: AppTheme.error)),
            data: (list) {
              if (list.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warning, size: 16),
                    SizedBox(width: 8),
                    Text('No equipment available',
                        style: TextStyle(color: AppTheme.warning)),
                  ]),
                );
              }
              return DropdownButtonFormField<int>(
                value: _equipmentId,
                dropdownColor: AppTheme.surface,
                decoration:
                    const InputDecoration(labelText: 'Equipment (Available only) *'),
                items: list
                    .map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.name} (${e.identifier})')))
                    .toList(),
                onChanged: (v) => setState(() => _equipmentId = v),
              );
            },
          ),
          const SizedBox(height: 12),

          // Expected return date
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppTheme.border))),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppTheme.textMuted, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    _expectedReturn == null
                        ? 'Expected return date (optional)'
                        : 'Expected: ${_fmtDate(_expectedReturn)}',
                    style: TextStyle(
                        color: _expectedReturn == null
                            ? AppTheme.textMuted
                            : AppTheme.textPrimary,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _notesCtrl,
            minLines: 2,
            maxLines: 3,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Purpose, who is using it...'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)
                  : const Text('Check Out'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Return Sheet ─────────────────────────────────────────────────────────────

class _ReturnSheet extends ConsumerStatefulWidget {
  final EquipmentMovement movement;
  final VoidCallback onReturned;
  const _ReturnSheet({required this.movement, required this.onReturned});

  @override
  ConsumerState<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<_ReturnSheet> {
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(equipmentRepositoryProvider).checkIn(
            movementId: widget.movement.id,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      widget.onReturned();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Equipment returned'),
          backgroundColor: AppTheme.success));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mov = widget.movement;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.download_rounded, color: AppTheme.success, size: 20),
            const SizedBox(width: 8),
            const Text('Return Equipment',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),

          // Info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mov.equipment?['name'] ?? '',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text(mov.equipment?['identifier'] ?? '',
                    style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontFamily: 'monospace',
                        fontSize: 12)),
                const SizedBox(height: 8),
                if (mov.actor != null)
                  Text(
                    'Checked out by: ${mov.actor!['firstName']} ${mov.actor!['lastName']}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                Text('Date out: ${_fmtDateTime(mov.createdAt)}',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                if (mov.order != null)
                  Text('Event: ${mov.order!['eventType']}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _notesCtrl,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
                labelText: 'Return notes (optional)',
                hintText: 'Condition on return, any issues...'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success.withValues(alpha: 0.2),
                  foregroundColor: AppTheme.success,
                  side: BorderSide(
                      color: AppTheme.success.withValues(alpha: 0.5))),
              child: _saving
                  ? const CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.success)
                  : const Text('Confirm Return'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Report Incident Sheet ────────────────────────────────────────────────────

class _ReportIncidentSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _ReportIncidentSheet({required this.onSaved});

  @override
  ConsumerState<_ReportIncidentSheet> createState() =>
      _ReportIncidentSheetState();
}

class _ReportIncidentSheetState extends ConsumerState<_ReportIncidentSheet> {
  int? _equipmentId;
  XFile? _photo;
  bool _saving = false;
  final _descriptionCtrl = TextEditingController();

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 75);
    if (photo != null) setState(() => _photo = photo);
  }

  Future<void> _save() async {
    if (_equipmentId == null || _descriptionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select equipment and describe the incident')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(equipmentRepositoryProvider);
      final incident = await repo.createIncident({
        'equipmentId': _equipmentId,
        'description': _descriptionCtrl.text.trim(),
      });
      if (_photo != null) {
        await repo.uploadIncidentPhoto(incident.id, _photo!.path);
      }
      widget.onSaved();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Incident reported'),
          backgroundColor: AppTheme.success));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipment = ref.watch(equipmentListProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report Incident',
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
              value: _equipmentId,
              dropdownColor: AppTheme.surface,
              decoration: const InputDecoration(labelText: 'Equipment'),
              items: list
                  .map((e) => DropdownMenuItem(
                      value: e.id, child: Text('${e.name} (${e.identifier})')))
                  .toList(),
              onChanged: (v) => setState(() => _equipmentId = v),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionCtrl,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
                labelText: 'Defect / incident description'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.photo_camera_rounded),
            label: Text(_photo == null ? 'Add Photo' : 'Photo Selected ✓'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)
                  : const Text('Submit Incident'),
            ),
          ),
        ],
      ),
    );
  }
}
