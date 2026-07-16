import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_provider.dart';
import '../../clients/data/client_provider.dart';
import '../../orders/data/order_provider.dart';
import '../../equipment/data/equipment_provider.dart';
import '../../../shared/widgets/common_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final clients = ref.watch(clientsProvider(null));
    final orders = ref.watch(ordersProvider(null));
    final equipment = ref.watch(equipmentListProvider);

    final confirmedOrders = orders.value?.where((o) => o.status == 'CONFIRMED').length ?? 0;
    final availableEquipment = equipment.value?.where((e) => e.status == 'AVAILABLE').length ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () async {
            ref.invalidate(clientsProvider);
            ref.invalidate(ordersProvider);
            ref.invalidate(equipmentListProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hello, ${user?.firstName ?? ''}! 👋',
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          await ref.read(authStateProvider.notifier).logout();
                        },
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(user?.initials ?? 'RG',
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stats Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Overview', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          StatCard(title: 'Clients', value: '${clients.value?.length ?? 0}',
                            icon: Icons.people_rounded, color: AppTheme.primary),
                          StatCard(title: 'Active Orders', value: '$confirmedOrders',
                            icon: Icons.shopping_bag_rounded, color: AppTheme.success,
                            subtitle: '${orders.value?.length ?? 0} total'),
                          StatCard(title: 'Equipment', value: '$availableEquipment',
                            icon: Icons.construction_rounded, color: AppTheme.warning,
                            subtitle: 'available'),
                          StatCard(title: 'Total Orders', value: '${orders.value?.length ?? 0}',
                            icon: Icons.bar_chart_rounded, color: AppTheme.info),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Orders
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Orders', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: () => context.go('/orders'),
                        child: const Text('See all', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),

              orders.when(
                loading: () => const SliverToBoxAdapter(child: AppLoadingWidget()),
                error: (e, _) => SliverToBoxAdapter(child: AppErrorWidget(message: e.toString())),
                data: (list) => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i >= (list.length > 5 ? 5 : list.length)) return null;
                      final o = list[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: _OrderTile(order: o),
                      );
                    },
                    childCount: list.length > 5 ? 5 : list.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = order.status.orderStatusColor;
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
            width: 42, height: 42,
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.shopping_bag_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.eventType, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${order.client?['name'] ?? ''} · ${DateFormat('MMM d, y').format(order.eventDate)}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          StatusBadge(status: order.status, color: statusColor),
        ],
      ),
    );
  }
}
