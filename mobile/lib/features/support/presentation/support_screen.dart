import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api_client.dart';
import '../../../core/api_config.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/support_repository.dart';

const List<String> kSupportCategories = [
  'General inquiry',
  'Booking issue',
  'Payment & refund',
  'Service quality',
  'Cancellation',
  'Account & profile',
  'Other',
];

/// Customer/partner help desk: shows the caller's support tickets and lets
/// them raise a new one with scenario evaluation and photographic evidence.
class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.api,
    required this.session,
    this.preselectedBookingId,
  });

  final ApiClient api;
  final Session session;
  final int? preselectedBookingId;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final SupportRepository _repository = SupportRepository(widget.api);
  List<Map<String, dynamic>> _tickets = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tickets = await _repository.fetchMyTickets(widget.session.token);
      if (!mounted) return;
      setState(() => _tickets = tickets);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Support tickets are currently unavailable.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTicket() async {
    final form = await showModalBottomSheet<_SupportForm>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SupportFormSheet(
        api: widget.api,
        session: widget.session,
        repository: _repository,
        preselectedBookingId: widget.preselectedBookingId,
      ),
    );
    if (form == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      await _repository.createTicket(
        widget.session.token,
        subject: form.subject,
        message: form.message,
        category: form.category,
        bookingId: form.bookingId,
        scenario: form.scenario,
        evidenceUrls: form.evidenceUrls,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support request submitted.')),
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit the request.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _statusOf(Map<String, dynamic> ticket) =>
      (ticket['status'] ?? 'OPEN').toString().toUpperCase();

  Color _statusColor(String status) => switch (status) {
        'RESOLVED' => Colors.green,
        'IN_PROGRESS' || 'IN_REVIEW' => BrandColors.lime,
        'WAITING_FOR_CUSTOMER' => Colors.blueAccent,
        'CLOSED' => Colors.blueGrey,
        _ => Colors.orangeAccent,
      };

  String _timeOf(Map<String, dynamic> ticket) =>
      (ticket['createdAt'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support & Help')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitting ? null : _createTicket,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New request'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        message: _error!,
        onRetry: _load,
      );
    }
    if (_tickets.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          EmptyStateView(
            icon: Icons.support_agent_outlined,
            title: 'No support requests yet',
            message:
                'Raise a request and our support team will get back to you.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 90),
      itemCount: _tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _TicketCard(
        ticket: _tickets[index],
        status: _statusOf(_tickets[index]),
        statusColor: _statusColor(_statusOf(_tickets[index])),
        time: _timeOf(_tickets[index]),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SupportConversationScreen(
                  repository: _repository, session: widget.session, ticket: _tickets[index])));
          _load();
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.status,
    required this.statusColor,
    required this.time,
    required this.onTap,
  });

  final Map<String, dynamic> ticket;
  final String status;
  final Color statusColor;
  final String time;
  final VoidCallback onTap;

  List<String> _extractEvidence(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return raw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final subject = (ticket['subject'] ?? 'Support request').toString();
    final message = (ticket['message'] ?? '').toString();
    final reply = (ticket['reply'] ?? '').toString();
    final category = ticket['category']?.toString();
    final bookingId = ticket['bookingId'];
    final priority = ticket['priority']?.toString();
    final scenario = ticket['scenario']?.toString();
    final evidenceList = _extractEvidence(ticket['evidenceList'] ?? ticket['evidenceUrls']);

    Color priorityColor = Colors.grey;
    if (priority == 'URGENT') priorityColor = Colors.red;
    if (priority == 'HIGH') priorityColor = Colors.deepOrange;
    if (priority == 'MEDIUM') priorityColor = Colors.blue;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (priority != null && priority.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: priorityColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  priority,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: priorityColor),
                                ),
                              ),
                            if (scenario != null && scenario.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  scenario.replaceAll('_', ' '),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ),
                            if (category != null && category.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            if (bookingId != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Booking #$bookingId',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.brown,
                                  ),
                                ),
                              ),
                            if (evidenceList.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '📷 ${evidenceList.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(color: BrandColors.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (reply.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BrandColors.lime.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.support_agent, size: 16, color: BrandColors.limeBright),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Support reply',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: BrandColors.limeBright,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              reply,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (time.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      time,
                      style: const TextStyle(
                        color: BrandColors.muted,
                        fontSize: 10,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: BrandColors.muted),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SupportConversationScreen extends StatefulWidget {
  const SupportConversationScreen({
    super.key,
    required this.repository,
    required this.session,
    required this.ticket,
  });

  final SupportRepository repository;
  final Session session;
  final Map<String, dynamic> ticket;

  @override
  State<SupportConversationScreen> createState() => _SupportConversationScreenState();
}

class _SupportConversationScreenState extends State<SupportConversationScreen> {
  final _message = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true, _sending = false;
  String get _id => widget.ticket['id'].toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _messages = await widget.repository.fetchMessages(widget.session.token, _id);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.sendMessage(widget.session.token, _id, text);
      _message.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Color _statusColor(String status) => switch (status.toUpperCase()) {
    'RESOLVED' => Colors.green,
    'IN_PROGRESS' || 'IN_REVIEW' => BrandColors.lime,
    'WAITING_FOR_CUSTOMER' => Colors.blueAccent,
    'CLOSED' => Colors.blueGrey,
    _ => Colors.orangeAccent,
  };

  List<String> _parseEvidenceList() {
    final raw = widget.ticket['evidenceList'] ?? widget.ticket['evidenceUrls'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return raw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  void _openImagePreview(String url) {
    final fullUrl = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  fullUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.white,
                    child: const Text('Could not load image.'),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = (widget.ticket['message'] ?? '').toString();
    final reply = (widget.ticket['reply'] ?? '').toString();
    final subject = (widget.ticket['subject'] ?? 'Support chat').toString();
    final category = widget.ticket['category']?.toString();
    final bookingId = widget.ticket['bookingId'];
    final scenario = widget.ticket['scenario']?.toString();
    final priority = widget.ticket['priority']?.toString();
    final recommendedAction = widget.ticket['recommendedAction']?.toString();
    final connectsToRefund = widget.ticket['connectsToRefund'] == true;
    final refundInfo = widget.ticket['refundInfo'];
    final status = (widget.ticket['status'] ?? 'OPEN').toString().toUpperCase();
    final evidenceList = _parseEvidenceList();

    final thread = <Map<String, dynamic>>[
      if (initial.isNotEmpty) {
        'senderRole': widget.ticket['requesterRole'] ?? 'CUSTOMER',
        'message': initial,
        'createdAt': widget.ticket['createdAt'],
      },
      ..._messages,
      if (reply.isNotEmpty && !_messages.any((m) => m['message'] == reply)) {
        'senderRole': 'ADMIN',
        'message': reply,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ticket #$_id', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(subject, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status)),
                  ),
                ),
                if (priority != null && priority.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      priority,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.deepOrange),
                    ),
                  ),
                if (scenario != null && scenario.isNotEmpty)
                  Text('• ${scenario.replaceAll('_', ' ')}', style: const TextStyle(fontSize: 12, color: BrandColors.muted)),
                if (category != null && category.isNotEmpty)
                  Text('• $category', style: const TextStyle(fontSize: 12, color: BrandColors.muted)),
                if (bookingId != null)
                  Text('• Booking #$bookingId', style: const TextStyle(fontSize: 12, color: BrandColors.muted)),
              ],
            ),
          ),
          if (recommendedAction != null && recommendedAction.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recommendedAction,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          if (connectsToRefund)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 14, color: Colors.brown),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      refundInfo != null
                          ? 'Linked Refund #${refundInfo['id']} (${refundInfo['status']})'
                          : 'Eligible for Refund Review',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
          if (evidenceList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Row(
                children: [
                  const Icon(Icons.photo_library_outlined, size: 14, color: BrandColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    'Evidence Photos (${evidenceList.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BrandColors.muted),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 72,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: evidenceList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final url = evidenceList[idx];
                  final fullUrl = url.startsWith('http') ? url : '${ApiConfig.baseUrl}$url';
                  return InkWell(
                    onTap: () => _openImagePreview(url),
                    borderRadius: BorderRadius.circular(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey[200],
                        child: Image.network(
                          fullUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: thread.length,
                    itemBuilder: (_, i) {
                      final isMine = (thread[i]['senderRole'] ?? '').toString() != 'ADMIN';
                      final msg = (thread[i]['message'] ?? '').toString();
                      final time = thread[i]['createdAt']?.toString();

                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            color: isMine
                                ? BrandColors.lime.withValues(alpha: 0.20)
                                : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: Radius.circular(isMine ? 12 : 2),
                              bottomRight: Radius.circular(isMine ? 2 : 12),
                            ),
                            border: Border.all(
                              color: isMine ? BrandColors.lime.withValues(alpha: 0.4) : Colors.black12,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMine ? 'You' : 'Support Team',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isMine ? BrandColors.limeBright : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(msg, style: const TextStyle(fontSize: 14)),
                              if (time != null && time.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    time.length > 16 ? time.substring(0, 16).replaceAll('T', ' ') : time,
                                    style: const TextStyle(fontSize: 9, color: BrandColors.muted),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedEvidence {
  _PickedEvidence({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}

class _SupportForm {
  const _SupportForm({
    required this.subject,
    required this.message,
    this.category,
    this.bookingId,
    this.scenario,
    this.evidenceUrls = const [],
  });

  final String subject;
  final String message;
  final String? category;
  final int? bookingId;
  final String? scenario;
  final List<String> evidenceUrls;
}

class _SupportFormSheet extends StatefulWidget {
  const _SupportFormSheet({
    required this.api,
    required this.session,
    required this.repository,
    this.preselectedBookingId,
  });

  final ApiClient api;
  final Session session;
  final SupportRepository repository;
  final int? preselectedBookingId;

  @override
  State<_SupportFormSheet> createState() => _SupportFormSheetState();
}

class _SupportFormSheetState extends State<_SupportFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();

  String _category = kSupportCategories.first;
  int? _selectedBookingId;
  List<Map<String, dynamic>> _userBookings = [];
  bool _loadingBookings = true;

  List<ScenarioRule> _scenarios = kDefaultScenarios;
  late ScenarioRule _selectedRule = _scenarios.firstWhere(
    (s) => s.scenario == 'OTHER',
    orElse: () => _scenarios.first,
  );

  final List<_PickedEvidence> _pickedImages = [];
  bool _uploading = false;
  bool _showEvidenceError = false;

  @override
  void initState() {
    super.initState();
    _selectedBookingId = widget.preselectedBookingId;
    _fetchBookings();
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    try {
      final list = await widget.repository.fetchScenarios();
      if (list.isNotEmpty && mounted) {
        setState(() {
          _scenarios = list;
          _selectedRule = _scenarios.firstWhere(
            (s) => s.scenario == 'OTHER',
            orElse: () => _scenarios.first,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchBookings() async {
    try {
      final payload = await widget.api.get('/bookings', token: widget.session.token);
      if (payload is List && mounted) {
        setState(() {
          _userBookings = payload
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      }
    } catch (_) {
      // Non-fatal: if bookings cannot be fetched, customer can still raise a support ticket
    } finally {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    if (_pickedImages.length >= _selectedRule.maxEvidenceCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum ${_selectedRule.maxEvidenceCount} photos allowed.')),
      );
      return;
    }
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      setState(() {
        _pickedImages.add(_PickedEvidence(
          bytes: bytes,
          fileName: photo.name.isNotEmpty ? photo.name : 'camera.jpg',
        ));
        _showEvidenceError = false;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open camera.')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_pickedImages.length >= _selectedRule.maxEvidenceCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum ${_selectedRule.maxEvidenceCount} photos allowed.')),
      );
      return;
    }
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      setState(() {
        _pickedImages.add(_PickedEvidence(
          bytes: bytes,
          fileName: photo.name.isNotEmpty ? photo.name : 'gallery.jpg',
        ));
        _showEvidenceError = false;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not pick from gallery.')),
        );
      }
    }
  }

  void _onScenarioChanged(ScenarioRule rule) {
    setState(() {
      _selectedRule = rule;
      _showEvidenceError = false;
      if (_subject.text.isEmpty || _scenarios.any((s) => s.displayName == _subject.text)) {
        _subject.text = rule.displayName;
      }
      // Sync category if possible
      final match = kSupportCategories.firstWhere(
        (c) => c.toUpperCase().contains(rule.category) || rule.category.contains(c.toUpperCase()),
        orElse: () => _category,
      );
      _category = match;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRule.requiresEvidence && _pickedImages.isEmpty) {
      setState(() => _showEvidenceError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photos are required for "${_selectedRule.displayName}". Please attach evidence.')),
      );
      return;
    }

    setState(() => _uploading = true);
    List<String> uploadedUrls = [];
    try {
      for (final img in _pickedImages) {
        final url = await widget.repository.uploadEvidence(
          widget.session.token,
          img.bytes,
          img.fileName,
        );
        uploadedUrls.add(url);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload evidence photo: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(_SupportForm(
      subject: _subject.text.trim(),
      message: _message.text.trim(),
      category: _category,
      bookingId: _selectedBookingId,
      scenario: _selectedRule.scenario,
      evidenceUrls: uploadedUrls,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedInList = _selectedBookingId == null ||
        _userBookings.any((b) {
          final id = b['id'] is int ? b['id'] as int : int.tryParse(b['id'].toString());
          return id == _selectedBookingId;
        });

    final showEvidenceSection = _selectedRule.requiresEvidence || _selectedRule.allowOptionalEvidence;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New support request',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scenario / Problem selector
              DropdownButtonFormField<String>(
                initialValue: _selectedRule.scenario,
                decoration: const InputDecoration(
                  labelText: 'Specific Issue / Scenario',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                isExpanded: true,
                items: _scenarios
                    .map((s) => DropdownMenuItem(
                          value: s.scenario,
                          child: Text(
                            s.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    final found = _scenarios.firstWhere((s) => s.scenario == val);
                    _onScenarioChanged(found);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Category dropdown (retained for backward compatibility)
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Issue category',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: kSupportCategories
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),

              if (_userBookings.isNotEmpty || _loadingBookings || _selectedBookingId != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _selectedBookingId,
                  decoration: InputDecoration(
                    labelText: _selectedRule.requiresBooking
                        ? 'Related booking (required)'
                        : 'Related booking (optional)',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None / General inquiry'),
                    ),
                    if (_selectedBookingId != null && !hasSelectedInList)
                      DropdownMenuItem<int?>(
                        value: _selectedBookingId,
                        child: Text('Booking #$_selectedBookingId'),
                      ),
                    ..._userBookings.map((b) {
                      final id = b['id'] is int ? b['id'] as int : int.tryParse(b['id'].toString());
                      final service = b['service']?.toString() ?? 'Booking';
                      return DropdownMenuItem<int?>(
                        value: id,
                        child: Text(
                          'Booking #$id — $service',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedBookingId = val),
                  validator: (val) {
                    if (_selectedRule.requiresBooking && val == null) {
                      return 'Please select the affected booking';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 12),
              TextFormField(
                controller: _subject,
                maxLength: 140,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g. Issue with payment or booking',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Enter a subject'
                        : null,
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue',
                  hintText: 'Please share relevant details so we can assist you quickly…',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Describe the issue'
                        : null,
              ),

              // Scenario-based Evidence Section (Camera + Gallery)
              if (showEvidenceSection) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedRule.requiresEvidence
                        ? Colors.orange.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _showEvidenceError
                          ? Colors.red
                          : _selectedRule.requiresEvidence
                              ? Colors.orange.withValues(alpha: 0.4)
                              : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _selectedRule.requiresEvidence
                                ? Icons.warning_amber_rounded
                                : Icons.photo_camera_outlined,
                            size: 18,
                            color: _selectedRule.requiresEvidence ? Colors.deepOrange : Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedRule.requiresEvidence
                                ? 'Photographic Evidence (REQUIRED)'
                                : 'Attach Evidence (Optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _selectedRule.requiresEvidence ? Colors.deepOrange : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_pickedImages.length}/${_selectedRule.maxEvidenceCount}',
                            style: const TextStyle(fontSize: 12, color: BrandColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedRule.requiresEvidence
                            ? 'Please provide clear photos of the damage or incomplete service.'
                            : 'Upload screenshots or photos to assist the investigation.',
                        style: const TextStyle(fontSize: 11, color: BrandColors.muted),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _uploading ? null : _pickFromCamera,
                              icon: const Icon(Icons.photo_camera, size: 18),
                              label: const Text('Camera'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _uploading ? null : _pickFromGallery,
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ],
                      ),
                      if (_pickedImages.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _pickedImages.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final item = _pickedImages[idx];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      item.bytes,
                                      width: 72,
                                      height: 72,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _pickedImages.removeAt(idx);
                                        });
                                      },
                                      child: const CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.black54,
                                        child: Icon(Icons.close, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                      if (_showEvidenceError && _pickedImages.isEmpty) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'At least 1 photo is required before submitting.',
                          style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              FilledButton(
                onPressed: _uploading ? null : _submit,
                child: _uploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 10),
                          Text('Uploading evidence…'),
                        ],
                      )
                    : const Text('Submit request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(icon, size: 44, color: BrandColors.muted),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: BrandColors.muted),
        ),
        const SizedBox(height: 16),
        Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Retry'))),
      ],
    );
  }
}
