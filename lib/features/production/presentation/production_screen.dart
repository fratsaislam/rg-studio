import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common_widgets.dart';

const _steps = [
  'IMPORTING',
  'SORTING',
  'EDITING',
  'RETOUCHING',
  'VALIDATION',
  'EXPORTING',
  'DELIVERED',
  'ARCHIVED'
];

const _statusLabels = {
  'IMPORTING': 'UPLOADING',
  'SORTING': 'SORTING',
  'EDITING': 'EDITING',
  'RETOUCHING': 'RETOUCHING',
  'VALIDATION': 'VALIDATION',
  'EXPORTING': 'EXPORTING',
  'DELIVERED': 'FINISHED',
  'ARCHIVED': 'ARCHIVED',
};

final productionJobsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/production');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

class ProductionScreen extends ConsumerWidget {
  const ProductionScreen({super.key});

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
                          StatusBadge(status: _statusLabels[status] ?? status, color: color),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _MetaChip(icon: Icons.folder_rounded, label: job['folderPath'] ?? 'No folder'),
                          const SizedBox(width: 8),
                          _MetaChip(icon: Icons.perm_media_rounded, label: '${job['_count']?['medias'] ?? 0} files'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showUploadSheet(context, ref, job),
                              icon: const Icon(Icons.upload_file_rounded, size: 18),
                              label: const Text('Upload'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showStatusSheet(context, ref, job),
                              icon: const Icon(Icons.fact_check_rounded, size: 18),
                              label: const Text('Status'),
                            ),
                          ),
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

  Future<void> _showUploadSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> job) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _UploadMediaSheet(jobId: job['id'] as int),
    );
    ref.invalidate(productionJobsProvider);
  }

  void _showStatusSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> job) {
    String status = job['status'] as String;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Production Status', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: status,
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _steps.map((s) => DropdownMenuItem(value: s, child: Text(_statusLabels[s] ?? s))).toList(),
                onChanged: (v) => setSheetState(() => status = v ?? status),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(dioProvider).put('/production/${job['id']}', data: {'status': status});
                  ref.invalidate(productionJobsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.textMuted, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadMediaSheet extends ConsumerStatefulWidget {
  final int jobId;
  const _UploadMediaSheet({required this.jobId});

  @override
  ConsumerState<_UploadMediaSheet> createState() => _UploadMediaSheetState();
}

class _UploadMediaSheetState extends ConsumerState<_UploadMediaSheet> {
  bool _uploading = false;

  Future<void> _pickAndUpload(ImageSource source, String type, {bool video = false}) async {
    final picker = ImagePicker();
    final file = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final data = FormData.fromMap({
        'type': type,
        'file': await MultipartFile.fromFile(file.path, filename: file.name),
      });
      await ref.read(dioProvider).post(
        '/production/${widget.jobId}/media/upload',
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Media uploaded'), backgroundColor: AppTheme.success));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upload Media', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (_uploading) const LinearProgressIndicator(color: AppTheme.primary),
          if (_uploading) const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploading ? null : () => _pickAndUpload(ImageSource.camera, 'PHOTO'),
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('Take Photo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _uploading ? null : () => _pickAndUpload(ImageSource.gallery, 'PHOTO'),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Upload Photo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _uploading ? null : () => _pickAndUpload(ImageSource.gallery, 'VIDEO', video: true),
            icon: const Icon(Icons.video_library_rounded),
            label: const Text('Upload Video'),
          ),
        ],
      ),
    );
  }
}
