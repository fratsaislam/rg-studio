import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../data/supplier_provider.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Suppliers'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [Tab(text: 'Directory'), Tab(text: 'Subcontracts')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [_SupplierList(), _SubcontractList()],
      ),
    );
  }
}

class _SupplierList extends ConsumerWidget {
  const _SupplierList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);
    return suppliers.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(suppliersProvider)),
      data: (list) {
        if (list.isEmpty) return const EmptyStateWidget(icon: Icons.storefront_outlined, title: 'No suppliers registered');
        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () async => ref.invalidate(suppliersProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _SupplierTile(supplier: list[i]),
          ),
        );
      },
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  const _SupplierTile({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final statusColor = supplier.status == 'ACTIVE'
      ? AppTheme.success
      : supplier.status == 'BLACKLISTED'
        ? AppTheme.error
        : AppTheme.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(supplier.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  [supplier.category, supplier.zones, supplier.phone].where((v) => v != null && v.isNotEmpty).join(' · '),
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                if (supplier.qualityRating != null) ...[
                  const SizedBox(height: 6),
                  Text('Quality ${supplier.qualityRating}/5 · ${supplier.subcontractsCount} jobs',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ],
            ),
          ),
          StatusBadge(status: supplier.status, color: statusColor),
        ],
      ),
    );
  }
}

class _SubcontractList extends ConsumerWidget {
  const _SubcontractList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subcontracts = ref.watch(subcontractsProvider);
    return subcontracts.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(subcontractsProvider)),
      data: (list) {
        if (list.isEmpty) return const EmptyStateWidget(icon: Icons.assignment_outlined, title: 'No subcontracts');
        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () async => ref.invalidate(subcontractsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _SubcontractTile(subcontract: list[i]),
          ),
        );
      },
    );
  }
}

class _SubcontractTile extends StatelessWidget {
  final Subcontract subcontract;
  const _SubcontractTile({required this.subcontract});

  @override
  Widget build(BuildContext context) {
    final statusColor = subcontract.status == 'COMPLETED'
      ? AppTheme.success
      : subcontract.status == 'CANCELLED'
        ? AppTheme.error
        : AppTheme.warning;
    final supplierName = subcontract.supplier?['name'] ?? 'Supplier';
    final clientName = subcontract.order?['client']?['name'] ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(supplierName, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
              StatusBadge(status: subcontract.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(clientName, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${subcontract.cost.toStringAsFixed(0)} DA', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              if (subcontract.actualCost != null)
                Text(' · actual ${subcontract.actualCost!.toStringAsFixed(0)} DA', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              if (subcontract.deadline != null)
                Text(DateFormat('MMM d').format(subcontract.deadline!), style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
