import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/notification_repository.dart';

/// Customer notification inbox (Alerts tab). Booking updates, start/end OTPs
/// and service notifications appear here and are marked read on the server.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.api, required this.session});

  final ApiClient api;
  final Session session;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final NotificationRepository _repository =
      NotificationRepository(widget.api);
  List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _marking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _unreadCount =>
      _notifications.where((item) => item['read'] != true).length;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifications =
          await _repository.fetchNotifications(widget.session.token);
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Notifications are currently unavailable.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(Map<String, dynamic> notification) async {
    final id = notification['id']?.toString();
    if (id == null || id.isEmpty || notification['read'] == true) return;

    setState(() => notification['read'] = true);

    try {
      final updated =
          await _repository.markReadById(widget.session.token, id);
      if (!mounted) return;
      setState(() {
        for (final item in _notifications) {
          if (item['id']?.toString() == id) {
            item['read'] = updated['read'] ?? true;
          }
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => notification['read'] = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => notification['read'] = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_marking || _unreadCount == 0) return;
    setState(() => _marking = true);

    final readIds = _notifications
        .where((item) => item['read'] != true)
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .toSet();

    for (final item in _notifications) {
      item['read'] = true;
    }
    if (mounted) setState(() {});

    try {
      await _repository.markAllRead(widget.session.token);
    } on ApiException catch (error) {
      if (!mounted) return;
      for (final item in _notifications) {
        if (readIds.contains(item['id']?.toString())) {
          item['read'] = false;
        }
      }
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      for (final item in _notifications) {
        if (readIds.contains(item['id']?.toString())) {
          item['read'] = false;
        }
      }
      setState(() {});
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  IconData _iconFor(String type) => switch (type) {
        'BOOKING' || 'WORKER_ASSIGNMENT' => Icons.calendar_month_outlined,
        'OPERATIONS' => Icons.settings_outlined,
        'SECURITY' => Icons.shield_outlined,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _marking ? null : _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.cloud_off_outlined,
              size: 44, color: BrandColors.muted),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _notifications[index];
          return _AlertCard(
            icon: _iconFor((item['type'] ?? '').toString()),
            title: (item['title'] ?? 'Notification').toString(),
            message: (item['message'] ?? 'Open to view details.').toString(),
            time: (item['createdAt'] ?? '').toString(),
            read: item['read'] == true,
            onTap: () => _markRead(item),
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.read,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String time;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    BrandColors.lime.withValues(alpha: read ? 0.1 : 0.2),
                foregroundColor: BrandColors.evergreen,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight:
                                  read ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!read)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(top: 6, left: 6),
                            decoration: const BoxDecoration(
                              color: BrandColors.lime,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      style: const TextStyle(color: BrandColors.muted),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        time,
                        style: const TextStyle(
                          color: BrandColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
