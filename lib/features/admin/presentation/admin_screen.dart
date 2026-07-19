import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

final adminUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/users');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

final adminRolesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/roles');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

final auditLogsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/audit');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Admin'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'Accounts'),
            Tab(text: 'Roles'),
            Tab(text: 'Audit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _AccountsTab(),
          _RolesTab(),
          _AuditTab(),
        ],
      ),
    );
  }
}

class _AccountsTab extends ConsumerWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => _showCreateUserSheet(context, ref),
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
      body: users.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(adminUsersProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyStateWidget(
                icon: Icons.people_outline_rounded, title: 'No users');
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: () async => ref.invalidate(adminUsersProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final u = list[i];
                final role = u['role'] as Map<String, dynamic>?;
                final status = u['status'] ?? 'ACTIVE';
                final active = status == 'ACTIVE';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.15),
                        child: Text(
                          '${u['firstName']?[0] ?? ''}${u['lastName']?[0] ?? ''}'
                              .toUpperCase(),
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${u['firstName']} ${u['lastName']}',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(u['email'] ?? '',
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12)),
                            if (role != null)
                              Text(role['name'] ?? '',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(
                        value: active,
                        activeThumbColor: AppTheme.success,
                        onChanged: (v) async {
                          await ref
                              .read(dioProvider)
                              .put('/users/${u['id']}', data: {
                            'status': v ? 'ACTIVE' : 'INACTIVE',
                          });
                          ref.invalidate(adminUsersProvider);
                          ref.invalidate(auditLogsProvider);
                        },
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

  void _showCreateUserSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _CreateUserSheet(),
    );
  }
}

class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet();

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _emailCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  int? _roleId;
  bool _saving = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_roleId == null ||
        _emailCtrl.text.trim().isEmpty ||
        _firstCtrl.text.trim().isEmpty ||
        _lastCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Fill all fields. Password must be at least 8 characters.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post('/users', data: {
        'email': _emailCtrl.text.trim(),
        'firstName': _firstCtrl.text.trim(),
        'lastName': _lastCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'roleId': _roleId,
      });
      ref.invalidate(adminUsersProvider);
      ref.invalidate(auditLogsProvider);
      if (mounted) Navigator.pop(context);
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
    final roles = ref.watch(adminRolesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Account',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _field(_emailCtrl, 'Email'),
            _field(_firstCtrl, 'First name'),
            _field(_lastCtrl, 'Last name'),
            _field(_passwordCtrl, 'Temporary password', obscure: true),
            roles.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(e.toString(),
                  style: const TextStyle(color: AppTheme.error)),
              data: (list) => DropdownButtonFormField<int>(
                initialValue: _roleId,
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(labelText: 'Role'),
                items: list
                    .map((r) => DropdownMenuItem(
                        value: r['id'] as int, child: Text(r['name'])))
                    .toList(),
                onChanged: (v) => setState(() => _roleId = v),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _RolesTab extends ConsumerWidget {
  const _RolesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(adminRolesProvider);
    return roles.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(adminRolesProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
              icon: Icons.admin_panel_settings_outlined, title: 'No roles');
        }
        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () async => ref.invalidate(adminRolesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = list[i];
              final permissions = (r['permissions'] as List?) ?? [];
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
                    Text(r['name'] ?? '',
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: permissions.take(12).map<Widget>((p) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('$p',
                              style: const TextStyle(
                                  color: AppTheme.primary, fontSize: 11)),
                        );
                      }).toList(),
                    ),
                    if (permissions.length > 12) ...[
                      const SizedBox(height: 6),
                      Text('+${permissions.length - 12} more',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12)),
                    ],
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

class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(auditLogsProvider);
    return logs.when(
      loading: () => const AppLoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(auditLogsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
              icon: Icons.manage_search_rounded, title: 'No audit logs');
        }
        return RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () async => ref.invalidate(auditLogsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final log = list[i];
              final user = log['user'] as Map<String, dynamic>?;
              final time = DateTime.parse(log['timestamp']);
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
                    const Icon(Icons.history_edu_rounded,
                        color: AppTheme.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${log['action']} ${log['resource']}',
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(
                              'ID ${log['resourceId']} · ${user?['email'] ?? 'Unknown user'}',
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12)),
                          if (log['details'] != null)
                            Text('${log['details']}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(DateFormat('MMM d\nHH:mm').format(time),
                        textAlign: TextAlign.right,
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
