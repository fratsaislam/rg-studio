import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

const _steps = ['IMPORTING','SORTING','EDITING','RETOUCHING','VALIDATION','EXPORTING','DELIVERED','ARCHIVED'];

final productionJobsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/production');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

class ProductionScreen extends ConsumerWidget {
  const ProductionScreen({super.key});

  double _getProgress(String status) => ((_steps.indexOf(status) + 1) / _steps.length);

  Color _statusColor(String status) {
    switch (status) {
      case 'DELIVERED': return AppTheme.success;
      case 'ARCHIVED': return AppTheme.textMuted;
      case 'VALIDATION': return AppTheme.warning;
      default: return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(productionJobsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Production')),
      body: jobs.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(productionJobsProvider)),
        data: (list) {
          if (list.isEmpty) return const EmptyStateWidget(icon: Icons.movie_filter_outlined, title: 'No production jobs');
          return RefreshIndicator(
            color: AppTheme.primary, backgroundColor: AppTheme.surface,
            onRefresh: () async => ref.invalidate(productionJobsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final job = list[i];
                final status = job['status'] as String;
                final progress = _getProgress(status);
                final color = _statusColor(status);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(job['order']?['eventType'] ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(job['order']?['client']?['name'] ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          StatusBadge(status: status, color: color),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppTheme.border,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Start', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                          Text('${(progress * 100).round()}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                          const Text('Done', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
