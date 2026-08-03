import 'package:flutter/material.dart';

import '../../../core/brand_theme.dart';

class PartnerAlertsTab extends StatefulWidget {
  const PartnerAlertsTab({
    super.key,
    required this.pendingActions,
    required this.notifications,
    required this.onRefresh,
    required this.onOpenBooking,
  });

  final List<Map<String, dynamic>> pendingActions;
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function() onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpenBooking;

  @override
  State<PartnerAlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<PartnerAlertsTab> {
  String _selectedFilter = 'ALL';
  final Set<String> _readIds = <String>{};

  static const filters = [
    'ALL',
    'UNREAD',
    'BOOKINGS',
    'VERIFICATION',
    'PAYMENTS',
    'SYSTEM',
  ];

  List<Map<String, dynamic>> get _items {
    final combined = <Map<String, dynamic>>[];

    for (final action in widget.pendingActions) {
      combined.add({
        ...action,
        '_source': 'ACTION',
      });
    }

    for (final notification in widget.notifications) {
      combined.add({
        ...notification,
        '_source': 'NOTIFICATION',
      });
    }

    return combined;
  }

  String _idOf(Map<String, dynamic> item) {
    return (item['id'] ??
            item['notificationId'] ??
            item['actionId'] ??
            item.hashCode)
        .toString();
  }

  bool _isRead(Map<String, dynamic> item) {
    final id = _idOf(item);
    if (_readIds.contains(id)) return true;

    final value =
        item['read'] ?? item['isRead'] ?? item['seen'] ?? item['isSeen'];

    if (value is bool) return value;

    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == 'read' || normalized == 'seen';
  }

  String _categoryOf(Map<String, dynamic> item) {
    final raw = (item['category'] ??
            item['type'] ??
            item['notificationType'] ??
            item['actionType'] ??
            item['_source'] ??
            'SYSTEM')
        .toString()
        .toUpperCase();

    if (raw.contains('BOOK') ||
        raw.contains('REQUEST') ||
        raw.contains('CANCEL')) {
      return 'BOOKINGS';
    }

    if (raw.contains('KYC') ||
        raw.contains('VERIFY') ||
        raw.contains('DOCUMENT') ||
        raw.contains('APPROVAL')) {
      return 'VERIFICATION';
    }

    if (raw.contains('PAY') ||
        raw.contains('EARNING') ||
        raw.contains('SETTLEMENT') ||
        raw.contains('PAYOUT')) {
      return 'PAYMENTS';
    }

    return 'SYSTEM';
  }

  bool _matchesFilter(Map<String, dynamic> item) {
    if (_selectedFilter == 'ALL') return true;
    if (_selectedFilter == 'UNREAD') return !_isRead(item);
    return _categoryOf(item) == _selectedFilter;
  }

  String _titleOf(Map<String, dynamic> item) {
    return (item['title'] ?? item['label'] ?? item['subject'] ?? 'Notification')
        .toString();
  }

  String _messageOf(Map<String, dynamic> item) {
    return (item['message'] ??
            item['description'] ??
            item['body'] ??
            'Open to view details.')
        .toString();
  }

  String _timeOf(Map<String, dynamic> item) {
    return (item['createdAt'] ??
            item['timestamp'] ??
            item['time'] ??
            item['updatedAt'] ??
            'Recently')
        .toString();
  }

  IconData _iconFor(String category) {
    return switch (category) {
      'BOOKINGS' => Icons.calendar_month_outlined,
      'VERIFICATION' => Icons.verified_user_outlined,
      'PAYMENTS' => Icons.account_balance_wallet_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  void _markRead(Map<String, dynamic> item) {
    setState(() => _readIds.add(_idOf(item)));
  }

  void _markAllRead() {
    setState(() {
      for (final item in _items) {
        _readIds.add(_idOf(item));
      }
    });
  }

  void _openItem(Map<String, dynamic> item) {
    _markRead(item);

    final bookingId = item['bookingId'];
    if (bookingId != null) {
      widget.onOpenBooking({'id': bookingId});
      return;
    }

    final category = _categoryOf(item);
    final message = switch (category) {
      'BOOKINGS' => 'Opening related booking.',
      'VERIFICATION' => 'Opening verification details.',
      'PAYMENTS' => 'Opening payment details.',
      _ => 'Opening notification details.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where(_matchesFilter).toList();
    final unreadCount = _items.where((item) => !_isRead(item)).length;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Alerts',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text('Mark all read'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              unreadCount == 0
                  ? 'You are all caught up.'
                  : '$unreadCount unread alert${unreadCount == 1 ? '' : 's'}.',
              style: const TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final selected = _selectedFilter == filter;

                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedFilter = filter);
                    },
                    label: Text(_filterLabel(filter)),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            if (filtered.isEmpty)
              _AlertsEmptyState(filter: _selectedFilter)
            else
              ...filtered.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AlertCard(
                    icon: _iconFor(_categoryOf(item)),
                    title: _titleOf(item),
                    message: _messageOf(item),
                    time: _timeOf(item),
                    category: _categoryOf(item),
                    read: _isRead(item),
                    onTap: () => _openItem(item),
                    onMarkRead: () => _markRead(item),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(String filter) {
    return switch (filter) {
      'ALL' => 'All',
      'UNREAD' => 'Unread',
      'BOOKINGS' => 'Bookings',
      'VERIFICATION' => 'Verification',
      'PAYMENTS' => 'Payments',
      'SYSTEM' => 'System',
      _ => filter,
    };
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.category,
    required this.read,
    required this.onTap,
    required this.onMarkRead,
  });

  final IconData icon;
  final String title;
  final String message;
  final String time;
  final String category;
  final bool read;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;

  Color get _accent {
    return switch (category) {
      'BOOKINGS' => BrandColors.lime,
      'VERIFICATION' => Colors.amber,
      'PAYMENTS' => Colors.lightBlueAccent,
      _ => BrandColors.muted,
    };
  }

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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    backgroundColor: _accent.withValues(alpha: 0.16),
                    foregroundColor: _accent,
                    child: Icon(icon),
                  ),
                  if (!read)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: BrandColors.lime,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
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
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: const TextStyle(
                            color: BrandColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      style: const TextStyle(
                        color: BrandColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            color: _accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (!read)
                          TextButton(
                            onPressed: onMarkRead,
                            child: const Text('Mark read'),
                          ),
                      ],
                    ),
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

class _AlertsEmptyState extends StatelessWidget {
  const _AlertsEmptyState({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      'UNREAD' => 'You have no unread alerts.',
      'BOOKINGS' => 'Booking alerts will appear here.',
      'VERIFICATION' => 'Verification updates will appear here.',
      'PAYMENTS' => 'Payment alerts will appear here.',
      'SYSTEM' => 'System announcements will appear here.',
      _ => 'You have no alerts right now.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(
              Icons.notifications_none,
              size: 42,
              color: BrandColors.muted,
            ),
            const SizedBox(height: 12),
            const Text(
              'No alerts',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BrandColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
