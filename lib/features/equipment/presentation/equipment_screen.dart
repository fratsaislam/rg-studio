import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/equipment_provider.dart';
import '../../../shared/widgets/common_widgets.dart';

class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({super.key});
  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() { super.initState(); _tabCtrl = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Equipment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [Tab(text: 'Inventory'), Tab(text: 'Incidents')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_InventoryTab(), _IncidentsTab()],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final identCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add Equipment', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField('Identifier *', identCtrl),
            _dialogField('Name *', nameCtrl),
            _dialogField('Category *', catCtrl),
            _dialogField('Brand', brandCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            onPressed: () async {
              await ref.read(equipmentRepositoryProvider).create({
                'identifier': identCtrl.text, 'name': nameCtrl.text,
                'category': catCtrl.text, if (brandCtrl.text.isNotEmpty) 'brand': brandCtrl.text,
              });
              ref.invalidate(equipmentListProvider);
              if (!mounted) return;
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
        decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: AppTheme.textMuted)),
      ),
    );
  }
}

class _InventoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipment = ref.watch(equipmentListProvider);
    return equipment.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(equipmentListProvider)),
      data: (list) {
        if (list.isEmpty) return const EmptyStateWidget(icon: Icons.construction_outlined, title: 'No equipment registered');
        return RefreshIndicator(
          color: AppTheme.primary, backgroundColor: AppTheme.surface,
          onRefresh: () async => ref.invalidate(equipmentListProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final e = list[i];
              final statusColor = e.status.equipmentStatusColor;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.construction_rounded, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${e.identifier} · ${e.category}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    StatusBadge(status: e.status, color: statusColor),
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

class _IncidentsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider);
    return incidents.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(message: e.toString()),
      data: (list) {
        if (list.isEmpty) return const EmptyStateWidget(icon: Icons.warning_amber_outlined, title: 'No incidents reported');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final inc = list[i];
            final statusColor = inc.status == 'RESOLVED' ? AppTheme.success : inc.status == 'IN_REVIEW' ? AppTheme.warning : AppTheme.error;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(inc.equipment?['name'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                      StatusBadge(status: inc.status, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(inc.description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('${inc.reporter?['firstName']} ${inc.reporter?['lastName']}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
