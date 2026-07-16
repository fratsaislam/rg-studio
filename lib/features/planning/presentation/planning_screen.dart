import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

// ── Planning providers ─────────────────────────────────────────────
final planningProjectsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/planning/projects');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

final planningTeamsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/planning/teams');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

class PlanningScreen extends ConsumerStatefulWidget {
  const PlanningScreen({super.key});
  @override
  ConsumerState<PlanningScreen> createState() => _PlanningState();
}

class _PlanningState extends ConsumerState<PlanningScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(planningProjectsProvider);
    final teams = ref.watch(planningTeamsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Planning'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [Tab(text: 'Projects'), Tab(text: 'Teams')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // Projects
          projects.when(
            loading: () => const AppLoadingWidget(),
            error: (e, _) => AppErrorWidget(message: e.toString()),
            data: (list) {
              if (list.isEmpty) return const EmptyStateWidget(icon: Icons.layers_outlined, title: 'No projects yet');
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final p = list[i];
                  final teams = (p['teams'] as List?) ?? [];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'], style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('${p['order']?['eventType']} · ${p['order']?['client']?['name']}',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        if (teams.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: teams.map<Widget>((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(t['name'], style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
          // Teams
          teams.when(
            loading: () => const AppLoadingWidget(),
            error: (e, _) => AppErrorWidget(message: e.toString()),
            data: (list) {
              if (list.isEmpty) return const EmptyStateWidget(icon: Icons.group_outlined, title: 'No teams yet');
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final t = list[i];
                  final members = (t['members'] as List?) ?? [];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.group_rounded, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 6),
                          Text(t['name'], style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${members.length} members', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ]),
                        if (t['project'] != null) ...[
                          const SizedBox(height: 4),
                          Text(t['project']['name'], style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                        if (members.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: members.map<Widget>((m) {
                              final user = m['user'];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20)),
                                child: Text('${user['firstName']} ${user['lastName']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
