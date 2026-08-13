import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/support_repository.dart';

/// Customer/partner help desk: shows the caller's support tickets and lets
/// them raise a new one.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.api, required this.session});

  final ApiClient api;
  final Session session;

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
      builder: (context) => const _SupportFormSheet(),
    );
    if (form == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      await _repository.createTicket(
        widget.session.token,
        subject: form.subject,
        message: form.message,
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
        'IN_PROGRESS' => BrandColors.lime,
        _ => Colors.orangeAccent,
      };

  String _timeOf(Map<String, dynamic> ticket) =>
      (ticket['createdAt'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact support')),
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
  });

  final Map<String, dynamic> ticket;
  final String status;
  final Color statusColor;
  final String time;

  @override
  Widget build(BuildContext context) {
    final subject = (ticket['subject'] ?? 'Support request').toString();
    final message = (ticket['message'] ?? '').toString();
    final reply = (ticket['reply'] ?? '').toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
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
              Text(message, style: const TextStyle(color: BrandColors.muted)),
            ],
            if (reply.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BrandColors.lime.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Support reply: $reply',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
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
    );
  }
}

class _SupportForm {
  const _SupportForm({required this.subject, required this.message});

  final String subject;
  final String message;
}

class _SupportFormSheet extends StatefulWidget {
  const _SupportFormSheet();

  @override
  State<_SupportFormSheet> createState() => _SupportFormSheetState();
}

class _SupportFormSheetState extends State<_SupportFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_SupportForm(
      subject: _subject.text.trim(),
      message: _message.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'New support request',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subject,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. KYC document not updating',
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
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty)
                      ? 'Describe the issue'
                      : null,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              child: const Text('Submit request'),
            ),
          ],
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