import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/data_provider.dart';
import '../../theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// NOTIFICATION PAGE – extracted from main_screen.dart
// ═════════════════════════════════════════════════════════════════════════════

class NotificationPage extends StatefulWidget {
  final DataProvider dp;
  /// Callback to navigate to an entity (e.g. 'tasks', 'ponds', 'products')
  final void Function(String subModuleKey)? onNavigate;
  const NotificationPage({super.key, required this.dp, this.onNavigate});
  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String _filterType = 'all';
  String _filterRead = 'all';

  static IconData _typeIcon(String? type) {
    switch (type) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'info': return Icons.info_outline_rounded;
      case 'alert': return Icons.error_outline_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  static Color _typeColor(String? type) {
    switch (type) {
      case 'warning': return AppColors.warning;
      case 'alert': return AppColors.error;
      case 'info': return AppColors.secondary;
      default: return AppColors.primary;
    }
  }

  static String _typeLabel(String? type) {
    switch (type) {
      case 'warning': return 'Cảnh báo';
      case 'info': return 'Thông tin';
      case 'alert': return 'Khẩn cấp';
      default: return 'Thông báo';
    }
  }

  static int _priorityOrder(String? p) {
    switch (p) {
      case 'high': return 0;
      case 'medium': return 1;
      case 'low': return 2;
      default: return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DataProvider>();
    var notifications = dp.notifications.toList();

    if (_filterType != 'all') {
      notifications = notifications.where((n) => n['type'] == _filterType).toList();
    }
    if (_filterRead == 'unread') {
      notifications = notifications.where((n) => n['read'] != true).toList();
    } else if (_filterRead == 'read') {
      notifications = notifications.where((n) => n['read'] == true).toList();
    }

    notifications.sort((a, b) {
      final aRead = a['read'] == true ? 1 : 0;
      final bRead = b['read'] == true ? 1 : 0;
      if (aRead != bRead) return aRead - bRead;
      final aPri = _priorityOrder(a['priority'] as String?);
      final bPri = _priorityOrder(b['priority'] as String?);
      if (aPri != bPri) return aPri - bPri;
      return (b['createdAt'] as String? ?? '').compareTo(a['createdAt'] as String? ?? '');
    });

    final totalUnread = dp.unreadNotifications;
    final totalRead = dp.notifications.where((n) => n['read'] == true).length;
    final hasFilter = _filterType != 'all' || _filterRead != 'all';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalUnread > 0 ? AppColors.error.withAlpha(15) : AppColors.success.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  totalUnread > 0 ? '$totalUnread chưa đọc' : 'Đã đọc hết',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: totalUnread > 0 ? AppColors.error : AppColors.success),
                ),
              ),
              const Spacer(),
              if (totalUnread > 0)
                TextButton.icon(
                  onPressed: () => dp.markAllNotificationsRead(),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Đọc hết', style: TextStyle(fontSize: 13)),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'check', child: ListTile(dense: true, leading: Icon(Icons.refresh, size: 18), title: Text('Kiểm tra thông báo mới', style: TextStyle(fontSize: 13)))),
                  if (totalRead > 0)
                    PopupMenuItem(value: 'clear', child: ListTile(dense: true, leading: const Icon(Icons.delete_sweep, size: 18, color: AppColors.error), title: Text('Xoá $totalRead đã đọc', style: const TextStyle(fontSize: 13, color: AppColors.error)))),
                ],
                onSelected: (v) async {
                  if (v == 'check') {
                    try {
                      await dp.checkNotifications();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã kiểm tra thông báo'), duration: Duration(seconds: 2)),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Không thể kết nối server'), backgroundColor: AppColors.error, duration: Duration(seconds: 3)),
                        );
                      }
                    }
                  }
                  if (v == 'clear') _confirmClearRead(context, dp, totalRead);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _NotiFilterChip(label: 'Tất cả', active: _filterType == 'all', onTap: () => setState(() => _filterType = 'all')),
              const SizedBox(width: 6),
              _NotiFilterChip(label: 'Cảnh báo', active: _filterType == 'warning', color: AppColors.warning, onTap: () => setState(() => _filterType = 'warning')),
              const SizedBox(width: 6),
              _NotiFilterChip(label: 'Thông tin', active: _filterType == 'info', color: AppColors.secondary, onTap: () => setState(() => _filterType = 'info')),
              const SizedBox(width: 6),
              _NotiFilterChip(label: 'Khẩn cấp', active: _filterType == 'alert', color: AppColors.error, onTap: () => setState(() => _filterType = 'alert')),
              const SizedBox(width: 12),
              _NotiFilterChip(label: 'Chưa đọc', active: _filterRead == 'unread', color: AppColors.primary, onTap: () => setState(() => _filterRead = _filterRead == 'unread' ? 'all' : 'unread')),
              const SizedBox(width: 6),
              _NotiFilterChip(label: 'Đã đọc', active: _filterRead == 'read', color: AppColors.textHint, onTap: () => setState(() => _filterRead = _filterRead == 'read' ? 'all' : 'read')),
              if (hasFilter) ...[
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.clear, size: 14),
                  label: const Text('Xoá lọc', style: TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() { _filterType = 'all'; _filterRead = 'all'; }),
                ),
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Text('${notifications.length} thông báo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: notifications.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(hasFilter ? Icons.filter_list_off : Icons.notifications_off_rounded, size: 56, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    Text(hasFilter ? 'Không có thông báo phù hợp bộ lọc' : 'Không có thông báo', style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (_, i) {
                    final n = notifications[i];
                    final isRead = n['read'] == true;
                    final type = n['type'] as String?;
                    final priority = n['priority'] as String?;
                    final title = n['title'] as String? ?? 'Thông báo';
                    final message = n['message'] as String? ?? '';
                    final createdAt = n['createdAt'] as String?;
                    String timeStr = '';
                    if (createdAt != null) {
                      try {
                        final dt = DateTime.parse(createdAt);
                        final diff = DateTime.now().difference(dt);
                        if (diff.inMinutes < 60) {
                          timeStr = '${diff.inMinutes} phút trước';
                        } else if (diff.inHours < 24) {
                          timeStr = '${diff.inHours} giờ trước';
                        } else if (diff.inDays < 7) {
                          timeStr = '${diff.inDays} ngày trước';
                        } else {
                          timeStr = DateFormat('dd/MM HH:mm').format(dt);
                        }
                      } catch (_) {}
                    }

                    return Dismissible(
                      key: Key(n['_id'] as String? ?? '$i'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: AppColors.error,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        final nId = n['_id'] as String?;
                        if (nId != null) dp.deleteNotification(nId);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isRead ? Colors.transparent : AppColors.primary.withAlpha(18),
                          border: isRead ? null : const Border(left: BorderSide(color: AppColors.primary, width: 3)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: isRead ? AppColors.textHint.withAlpha(15) : _typeColor(type).withAlpha(35),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_typeIcon(type), color: isRead ? AppColors.textHint : _typeColor(type), size: 20),
                              ),
                              if (!isRead)
                                Positioned(
                                  top: -2, right: -2,
                                  child: Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(children: [
                            Expanded(
                              child: Text(title,
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.w400 : FontWeight.w700,
                                  fontSize: 14,
                                  color: isRead ? AppColors.textHint : AppColors.textPrimary,
                                )),
                            ),
                            if (priority == 'high' && !isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: AppColors.error.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                                child: const Text('Quan trọng', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.error)),
                              ),
                            ],
                          ]),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(message,
                                style: TextStyle(fontSize: 12, color: isRead ? AppColors.textHint : AppColors.textSecondary),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isRead ? AppColors.textHint.withAlpha(10) : _typeColor(type).withAlpha(15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(_typeLabel(type), style: TextStyle(fontSize: 10, color: isRead ? AppColors.textHint : _typeColor(type), fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 8),
                                if (timeStr.isNotEmpty)
                                  Text(timeStr, style: TextStyle(fontSize: 11, color: isRead ? AppColors.textHint.withAlpha(150) : AppColors.textSecondary)),
                              ]),
                            ],
                          ),
                          trailing: isRead
                              ? Icon(Icons.check_circle_outline, size: 16, color: AppColors.textHint.withAlpha(100))
                              : null,
                          onTap: () {
                            if (!isRead) {
                              final nId = n['_id'] as String?;
                              if (nId != null) dp.markNotificationRead(nId);
                            }
                            // Navigate to related entity
                            _navigateToEntity(n);
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _navigateToEntity(Map<String, dynamic> n) {
    if (widget.onNavigate == null) return;
    final taskId = n['taskId'] as String?;
    final productId = n['productId'] as String?;
    final pondId = n['pondId'] as String?;
    final customerId = n['customerId'] as String?;
    final batchId = n['batchId'] as String?;
    // Priority: task > pond > product > customer > batch
    if (taskId != null && taskId.isNotEmpty) {
      widget.onNavigate!('tasks');
    } else if (pondId != null && pondId.isNotEmpty) {
      widget.onNavigate!('farm_map');
    } else if (productId != null && productId.isNotEmpty) {
      widget.onNavigate!('products');
    } else if (customerId != null && customerId.isNotEmpty) {
      widget.onNavigate!('customer');
    } else if (batchId != null && batchId.isNotEmpty) {
      widget.onNavigate!('farm_map');
    }
  }

  void _confirmClearRead(BuildContext context, DataProvider dp, int count) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá thông báo đã đọc'),
        content: Text('Xoá $count thông báo đã đọc? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              dp.clearReadNotifications();
            },
            child: const Text('Xoá', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _NotiFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _NotiFilterChip({required this.label, required this.active, this.color = AppColors.primary, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : AppColors.textSecondary, fontWeight: active ? FontWeight.w600 : FontWeight.w400, fontSize: 12)),
      ),
    );
  }
}
