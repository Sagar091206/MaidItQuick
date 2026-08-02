import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/data/service_catalog_repository.dart';
import '../../booking/presentation/booking_wizard_screen.dart';

/// Premium service details screen opened from the dashboard grid.
class ServiceDetailsScreen extends StatefulWidget {
  const ServiceDetailsScreen({
    super.key,
    required this.api,
    required this.session,
    required this.serviceId,
    required this.initialService,
    required this.onLogout,
  });

  final ApiClient api;
  final Session session;
  final int serviceId;
  final CatalogService initialService;
  final VoidCallback onLogout;

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen> {
  CatalogService? _service;
  bool _loading = true;
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
      final detail = await ServiceCatalogRepository(widget.api)
          .fetchDetail(widget.serviceId);
      if (mounted) setState(() => _service = detail);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this service.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _bookThisService() {
    final service = _service ?? widget.initialService;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => BookingWizardScreen(
          api: widget.api,
          session: widget.session,
          onLogout: widget.onLogout,
          initialServices: [service.name],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final service = _service;
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Service' : service?.name ?? 'Service'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const SkeletonListView(itemCount: 3)
            : _error != null
                ? ErrorStateView(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Card(
                        color: context.brandCard,
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              Text(
                                service!.emoji.isEmpty
                                    ? '🧽'
                                    : service.emoji,
                                style: const TextStyle(fontSize: 56),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                service.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                service.priceLabel,
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionHeader(title: "What's included"),
                      const SizedBox(height: 8),
                      Card(
                        color: context.brandCard,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            service.description.isEmpty
                                ? 'Professional ${service.name.toLowerCase()} using the supplies you provide at your home.'
                                : service.description,
                            style: TextStyle(
                              color: context.brandMuted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionHeader(title: 'Good to know'),
                      const SizedBox(height: 8),
                      Card(
                        color: context.brandCard,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _InfoRow(
                                icon: Icons.timer_outlined,
                                text:
                                    'Typical duration: ${service.defaultDurationMinutes} minutes',
                              ),
                              const SizedBox(height: 10),
                              const _InfoRow(
                                icon: Icons.cleaning_services_outlined,
                                text: 'You provide the cleaning supplies',
                              ),
                              const SizedBox(height: 10),
                              const _InfoRow(
                                icon: Icons.group_outlined,
                                text: 'A verified partner is assigned automatically',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _bookThisService,
                        icon: const Icon(Icons.add_task_outlined),
                        label: Text('Book ${service.name}'),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: context.brandMuted)),
        ),
      ],
    );
  }
}
