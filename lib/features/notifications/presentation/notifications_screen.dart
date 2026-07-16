import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/notifications');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(dioProvider).put('/notifications/read-all');
              ref.invalidate(notificationsProvider);
            },
            child: const Text('Mark all read', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
          ),
        ],
      ),
      body: notifs.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => AppErrorWidget(message: e.toString(), onRetry: () => ref.invalidate(notificationsProvider)),
        data: (list) {
          if (list.isEmpty) return const EmptyStateWidget(icon: Icons.notifications_none_outlined, title: 'No notifications');
          final unread = list.where((n) => !(n['isRead'] as bool)).length;
          return Column(
            children: [
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.circle, color: AppTheme.primary, size: 8),
                    const SizedBox(width: 8),
                    Text('$unread unread notification${unread > 1 ? 's' : ''}',
                      style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.primary, backgroundColor: AppTheme.surface,
                  onRefresh: () async => ref.invalidate(notificationsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final n = list[i];
                      final isRead = n['isRead'] as bool;
                      return GestureDetector(
                        onTap: () async {
                          if (!isRead) {
                            await ref.read(dioProvider).put('/notifications/${n['id']}/read');
                            ref.invalidate(notificationsProvider);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isRead ? AppTheme.surfaceVariant.withValues(alpha: 0.5) : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isRead ? AppTheme.border : AppTheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isRead)
                                Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4, right: 8), decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle))
                              else
                                const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n['content'], style: TextStyle(color: isRead ? AppTheme.textSecondary : AppTheme.textPrimary, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(4)),
                                        child: Text(n['type'], style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(DateFormat('MMM d, HH:mm').format(DateTime.parse(n['timestamp'])),
                                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                    ]),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
