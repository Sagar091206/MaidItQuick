import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/brand_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../support/presentation/support_screen.dart';

class PartnerProfileTab extends StatelessWidget {
  const PartnerProfileTab({
    super.key,
    required this.dashboard,
    required this.onLogout,
    required this.onManageVerification,
    required this.api,
    required this.session,
  });

  final Map<String, dynamic> dashboard;
  final VoidCallback onLogout;
  final ValueChanged<int>? onManageVerification;
  final ApiClient api;
  final Session session;

  String _statusFor(List<String> keys) {
    for (final key in keys) {
      final value = dashboard[key];

      if (value is bool) {
        return value ? 'COMPLETED' : 'PENDING';
      }

      final status = value?.toString().trim().toUpperCase();
      if (status == null || status.isEmpty) continue;

      if (status.contains('APPROV') ||
          status.contains('COMPLETE') ||
          status.contains('VERIFIED') ||
          status == 'SUBMITTED' ||
          status == 'ACTIVE') {
        return 'COMPLETED';
      }

      if (status.contains('REJECT') ||
          status.contains('CHANGE') ||
          status.contains('FAILED')) {
        return 'ACTION REQUIRED';
      }

      return 'PENDING';
    }

    return 'PENDING';
  }

  @override
  Widget build(BuildContext context) {
    final name =
        (dashboard['partnerName'] ?? dashboard['name'] ?? 'Partner').toString();
    final email =
        (dashboard['email'] ?? dashboard['partnerEmail'] ?? '').toString();
    final phone =
        (dashboard['phone'] ?? dashboard['partnerPhone'] ?? '').toString();

    final identityStatus = _statusFor(const [
      'identityStatus',
      'kycStatus',
      'identityVerified',
      'kycCompleted',
    ]);

    final addressStatus = _statusFor(const [
      'addressStatus',
      'addressVerificationStatus',
      'addressVerified',
      'addressCompleted',
    ]);

    final payoutStatus = _statusFor(const [
      'payoutStatus',
      'bankStatus',
      'bankVerificationStatus',
      'payoutDetailsVerified',
      'payoutCompleted',
    ]);

    final applicationStatus = _statusFor(const [
      'applicationStatus',
      'approvalStatus',
      'accountStatus',
      'readyForJobs',
      'accountEligible',
    ]);

    final completedCount = [
      identityStatus,
      addressStatus,
      payoutStatus,
      applicationStatus,
    ].where((status) => status == 'COMPLETED').length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'View your partner details and verification progress.',
            style: TextStyle(color: BrandColors.muted),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.person, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            email,
                            style: const TextStyle(color: BrandColors.muted),
                          ),
                        ],
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            phone,
                            style: const TextStyle(color: BrandColors.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Verification status',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$completedCount/4 completed',
                style: const TextStyle(
                  color: BrandColors.lime,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: completedCount / 4,
            minHeight: 8,
            backgroundColor: BrandColors.muted.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 14),
          _ProfileVerificationCard(
            step: 1,
            icon: Icons.badge_outlined,
            title: 'Identity verification',
            onboardingTabIndex: 1,
            onManage: onManageVerification,
            status: identityStatus,
          ),
          const SizedBox(height: 10),
          _ProfileVerificationCard(
            step: 2,
            icon: Icons.location_on_outlined,
            title: 'Address verification',
            onboardingTabIndex: 2,
            onManage: onManageVerification,
            status: addressStatus,
          ),
          const SizedBox(height: 10),
          _ProfileVerificationCard(
            step: 3,
            icon: Icons.account_balance_outlined,
            title: 'Payout details',
            onboardingTabIndex: 3,
            onManage: onManageVerification,
            status: payoutStatus,
          ),
          const SizedBox(height: 10),
          _ProfileVerificationCard(
            step: 4,
            icon: Icons.verified_user_outlined,
            title: 'Application approval',
            onboardingTabIndex: 4,
            onManage: onManageVerification,
            status: applicationStatus,
          ),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('Support'),
                  subtitle: const Text('Get help with your partner account'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => SupportScreen(
                        api: api,
                        session: session,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileVerificationCard extends StatefulWidget {
  const _ProfileVerificationCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.status,
    required this.onboardingTabIndex,
    required this.onManage,
  });

  final int step;
  final IconData icon;
  final String title;
  final String status;
  final int onboardingTabIndex;
  final ValueChanged<int>? onManage;

  @override
  State<_ProfileVerificationCard> createState() =>
      _ProfileVerificationCardState();
}

class _ProfileVerificationCardState extends State<_ProfileVerificationCard> {
  bool _expanded = false;

  bool get _completed => widget.status == 'COMPLETED';
  bool get _actionRequired => widget.status == 'ACTION REQUIRED';

  String get _description {
    switch (widget.title) {
      case 'Identity verification':
        return _completed
            ? 'Identity documents have been submitted and verified.'
            : _actionRequired
                ? 'Your identity documents need correction.'
                : 'Identity verification is still pending.';
      case 'Address verification':
        return _completed
            ? 'Your address and address proof are verified.'
            : _actionRequired
                ? 'Your address details need correction.'
                : 'Address verification is pending.';
      case 'Payout details':
        return _completed
            ? 'Your bank account or UPI payout details are ready.'
            : _actionRequired
                ? 'Your payout details need correction.'
                : 'Payout verification is pending.';
      case 'Application approval':
        return _completed
            ? 'Your Partner application is approved.'
            : _actionRequired
                ? 'Your application needs changes before approval.'
                : 'Your application is waiting for admin approval.';
      default:
        return 'Verification details are unavailable.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _completed
        ? BrandColors.lime
        : _actionRequired
            ? Colors.redAccent
            : Colors.amber;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            leading: CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.18),
              foregroundColor: accent,
              child: _completed
                  ? const Icon(Icons.check)
                  : Text(
                      '${widget.step}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            title: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.status,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            trailing: AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(widget.icon, color: accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _description,
                          style: const TextStyle(
                            color: BrandColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onManage == null
                          ? null
                          : () => widget.onManage!(
                                widget.onboardingTabIndex,
                              ),
                      icon: Icon(
                        _completed
                            ? Icons.visibility_outlined
                            : Icons.edit_document,
                      ),
                      label: Text(
                        _completed
                            ? 'View details'
                            : widget.title == 'Application approval'
                                ? 'View application status'
                                : 'Complete verification',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}
