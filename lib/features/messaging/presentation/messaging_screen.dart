import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/data/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final channelsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/channels');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

final channelMessagesProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, channelId) async {
  final res = await ref.read(dioProvider).get('/channels/$channelId');
  return Map<String, dynamic>.from(res.data['data']);
});

final usersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(dioProvider).get('/users');
  return List<Map<String, dynamic>>.from(res.data['data']);
});

// ── Helpers ───────────────────────────────────────────────────────────────────

/// For a DIRECT channel, returns the other member's full name.
/// Falls back to "Direct Chat" if data is incomplete.
String _dmDisplayName(Map<String, dynamic> channel, int myId) {
  final members = channel['members'] as List? ?? [];
  final other = members.firstWhere(
    (m) {
      final user = m['user'] as Map<String, dynamic>?;
      return user != null && user['id'] != myId;
    },
    orElse: () => null,
  );
  if (other == null) return 'Direct Chat';
  final u = other['user'] as Map<String, dynamic>;
  return '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
}

String _channelDisplayName(Map<String, dynamic> ch, int myId) {
  if (ch['type'] == 'DIRECT') return _dmDisplayName(ch, myId);
  return ch['name'] as String? ?? 'Channel';
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class MessagingScreen extends ConsumerStatefulWidget {
  const MessagingScreen({super.key});
  @override
  ConsumerState<MessagingScreen> createState() => _MessagingState();
}

class _MessagingState extends ConsumerState<MessagingScreen> {
  int? _selectedChannelId;
  String? _selectedChannelName;
  bool _selectedIsDm = false;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _openChannel(Map<String, dynamic> ch, int myId) {
    setState(() {
      _selectedChannelId = ch['id'];
      _selectedChannelName = _channelDisplayName(ch, myId);
      _selectedIsDm = ch['type'] == 'DIRECT';
    });
  }

  Future<void> _sendMessage() async {
    final content = _msgCtrl.text.trim();
    if (content.isEmpty || _selectedChannelId == null) return;
    _msgCtrl.clear();
    try {
      await ref
          .read(dioProvider)
          .post('/channels/$_selectedChannelId/messages', data: {'content': content});
      ref.invalidate(channelMessagesProvider(_selectedChannelId!));
      ref.invalidate(channelsProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    }
  }

  /// Opens a bottom sheet to pick a user and create / open a DM.
  Future<void> _showNewDmDialog(int myId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NewDmSheet(
        myId: myId,
        onRefreshUsers: () => ref.invalidate(usersProvider),
        onSelect: (otherUserId, otherName) async {
          Navigator.of(ctx).pop();
          try {
            final res = await ref.read(dioProvider).post(
              '/channels/direct',
              data: {'otherUserId': otherUserId},
            );
            final channel = Map<String, dynamic>.from(res.data['data']);
            ref.invalidate(channelsProvider);
            if (mounted) {
              setState(() {
                _selectedChannelId = channel['id'];
                _selectedChannelName = otherName;
                _selectedIsDm = true;
              });
            }
          } catch (e) {
            if (!mounted) return;
            // If the DM already exists the backend returns it anyway — but
            // show a snackbar only on genuine errors.
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
            );
          }
        },
      ),
    );
    // Re-invalidate to refresh the provider (in case it wasn't already loaded).
    ref.invalidate(usersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(channelsProvider);
    final user = ref.watch(authStateProvider).value;

    if (_selectedChannelId != null) {
      return _buildChatView(user);
    }

    return _buildConversationList(channels, user);
  }

  // ── Conversation List ───────────────────────────────────────────────────────

  Widget _buildConversationList(
      AsyncValue<List<Map<String, dynamic>>> channels, AppUser? user) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(channelsProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: channels.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(channelsProvider),
        ),
        data: (list) {
          final myId = user?.id ?? 0;
          final textChannels =
              list.where((c) => c['type'] != 'DIRECT').toList();
          final dms = list.where((c) => c['type'] == 'DIRECT').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              // ── Text Channels Section ─────────────────────────────────────
              _SectionHeader(
                icon: Icons.tag_rounded,
                title: 'Channels',
                count: textChannels.length,
              ),
              const SizedBox(height: 8),
              if (textChannels.isEmpty)
                const _EmptySection(
                  icon: Icons.tag_rounded,
                  message: 'No channels assigned to you',
                  subtitle: 'Admins can create and assign channels from the web',
                )
              else
                ...textChannels.map((ch) => _ChannelTile(
                      channel: ch,
                      displayName: _channelDisplayName(ch, myId),
                      isDm: false,
                      onTap: () => _openChannel(ch, myId),
                    )),

              const SizedBox(height: 24),

              // ── Direct Messages Section ───────────────────────────────────
              _SectionHeader(
                icon: Icons.person_rounded,
                title: 'Direct Messages',
                count: dms.length,
                trailing: user != null
                    ? GestureDetector(
                        onTap: () => _showNewDmDialog(myId),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: AppTheme.primary, size: 18),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              if (dms.isEmpty)
                const _EmptySection(
                  icon: Icons.chat_bubble_outline_rounded,
                  message: 'No direct messages yet',
                  subtitle: 'Tap + to start a conversation',
                )
              else
                ...dms.map((ch) => _ChannelTile(
                      channel: ch,
                      displayName: _channelDisplayName(ch, myId),
                      isDm: true,
                      onTap: () => _openChannel(ch, myId),
                    )),
            ],
          );
        },
      ),
    );
  }

  // ── Chat View ───────────────────────────────────────────────────────────────

  Widget _buildChatView(AppUser? user) {
    final channelData = ref.watch(channelMessagesProvider(_selectedChannelId!));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _selectedIsDm
                    ? AppTheme.accent.withValues(alpha: 0.15)
                    : AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: _selectedIsDm
                    ? const Icon(Icons.person_rounded,
                        color: AppTheme.accent, size: 16)
                    : const Text('#',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedChannelName ?? '',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() {
            _selectedChannelId = null;
            _selectedChannelName = null;
            _selectedIsDm = false;
          }),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(channelMessagesProvider(_selectedChannelId!)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: channelData.when(
              loading: () => const AppLoadingWidget(),
              error: (e, _) => AppErrorWidget(message: e.toString()),
              data: (data) {
                final messages = (data['messages'] as List?) ?? [];
                if (messages.isEmpty) {
                  return EmptyStateWidget(
                    icon: _selectedIsDm
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.chat_outlined,
                    title: 'No messages yet',
                    subtitle: _selectedIsDm
                        ? 'Send a message to ${_selectedChannelName ?? 'them'}!'
                        : 'Start the conversation!',
                  );
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final isMe = msg['senderId'] == user?.id;
                    final senderName =
                        '${msg['sender']?['firstName'] ?? ''} ${msg['sender']?['lastName'] ?? ''}'
                            .trim();
                    final time = DateFormat('HH:mm')
                        .format(DateTime.parse(msg['timestamp']));
                    return _MessageBubble(
                      isMe: isMe,
                      senderName: senderName,
                      content: msg['content'],
                      time: time,
                      isDm: _selectedIsDm,
                    );
                  },
                );
              },
            ),
          ),

          // ── Message Input ─────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: _selectedIsDm
                          ? 'Message ${_selectedChannelName ?? ''}...'
                          : 'Message #$_selectedChannelName...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: AppTheme.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: AppTheme.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: AppTheme.primary)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 14),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
                color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const _EmptySection({required this.icon, required this.message, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 28),
          const SizedBox(height: 8),
          Text(message,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Map<String, dynamic> channel;
  final String displayName;
  final bool isDm;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.channel,
    required this.displayName,
    required this.isDm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final msgCount = channel['_count']?['messages'] ?? 0;
    final initials = displayName.isNotEmpty
        ? displayName
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            // Avatar / icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDm
                    ? AppTheme.accent.withValues(alpha: 0.15)
                    : AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isDm
                    ? Text(
                        initials,
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      )
                    : const Text(
                        '#',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$msgCount message${msgCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!isDm && channel['type'] != 'GENERAL')
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.lock_outline_rounded,
                    color: AppTheme.textMuted, size: 14),
              ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final bool isMe;
  final String senderName;
  final String content;
  final String time;
  final bool isDm;

  const _MessageBubble({
    required this.isMe,
    required this.senderName,
    required this.content,
    required this.time,
    required this.isDm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && !isDm)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                senderName,
                style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  child: Text(
                    senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.primary : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    border: isMe
                        ? null
                        : Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    content,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
                top: 3, left: isMe ? 0 : 38, right: isMe ? 4 : 0),
            child: Text(
              time,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

// ── New DM Bottom Sheet ───────────────────────────────────────────────────────

class _NewDmSheet extends ConsumerStatefulWidget {
  final int myId;
  final VoidCallback onRefreshUsers;
  final void Function(int otherUserId, String otherName) onSelect;

  const _NewDmSheet({
    required this.myId,
    required this.onRefreshUsers,
    required this.onSelect,
  });

  @override
  ConsumerState<_NewDmSheet> createState() => _NewDmSheetState();
}

class _NewDmSheetState extends ConsumerState<_NewDmSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-watch the provider inside the sheet so it refreshes when invalidated.
    final usersAsync = ref.watch(usersProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'New Direct Message',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.textMuted, size: 20),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.textMuted, size: 18),
                  filled: true,
                  fillColor: AppTheme.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.primary)),
                ),
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),
            // User list
            Expanded(
              child: usersAsync.when(
                loading: () => const AppLoadingWidget(),
                error: (e, _) => AppErrorWidget(
                  message: e.toString(),
                  onRetry: widget.onRefreshUsers,
                ),
                data: (users) {
                  final filtered = users
                      .where((u) => u['id'] != widget.myId)
                      .where((u) {
                    if (_query.isEmpty) return true;
                    final name =
                        '${u['firstName']} ${u['lastName']}'.toLowerCase();
                    final email =
                        (u['email'] as String? ?? '').toLowerCase();
                    return name.contains(_query) || email.contains(_query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.person_search_rounded,
                      title: 'No members found',
                    );
                  }

                  return ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final u = filtered[i];
                      final name =
                          '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'
                              .trim();
                      final initials = name
                          .split(' ')
                          .where((w) => w.isNotEmpty)
                          .take(2)
                          .map((w) => w[0].toUpperCase())
                          .join();
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              AppTheme.accent.withValues(alpha: 0.15),
                          child: Text(
                            initials,
                            style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14),
                        ),
                        subtitle: Text(
                          u['email'] ?? '',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Message',
                            style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        onTap: () => widget.onSelect(u['id'], name),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        hoverColor: AppTheme.surfaceVariant,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
