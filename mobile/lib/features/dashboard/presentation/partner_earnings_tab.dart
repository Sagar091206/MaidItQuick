import 'package:flutter/material.dart';

import '../../../core/brand_theme.dart';

class PartnerEarningsTab extends StatefulWidget {
  const PartnerEarningsTab({
    super.key,
    required this.dashboard,
    required this.onRefresh,
  });

  final Map<String, dynamic> dashboard;
  final Future<void> Function() onRefresh;

  @override
  State<PartnerEarningsTab> createState() => _EarningsTabState();
}

class _EarningsTabState extends State<PartnerEarningsTab> {
  String _selectedPeriod = 'WEEK';

  static const _periods = ['TODAY', 'WEEK', 'MONTH'];

  /// Formats a rupee amount. Numeric values are treated as rupees; strings
  /// that already carry a currency symbol are returned unchanged.
  String _money(dynamic value) {
    if (value == null) return '₹0';

    if (value is num) {
      final amount = value < 0 ? value.abs() : value;
      final digits = amount % 1 == 0 ? 0 : 2;
      return '₹${amount.toStringAsFixed(digits)}';
    }

    final text = value.toString().trim();
    if (text.isEmpty) return '₹0';
    return text.startsWith('₹') ? text : '₹$text';
  }

  List<Map<String, dynamic>> _transactions(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String get _periodEarnings {
    return switch (_selectedPeriod) {
      'TODAY' => _money(
          widget.dashboard['todayEarnings'] ??
              widget.dashboard['currentEarnings'],
        ),
      'MONTH' => _money(
          widget.dashboard['monthlyEarnings'] ??
              widget.dashboard['monthEarnings'],
        ),
      _ => _money(
          widget.dashboard['weeklyEarnings'] ??
              widget.dashboard['weekEarnings'],
        ),
    };
  }

  String _periodLabel(String period) {
    return switch (period) {
      'TODAY' => 'Today',
      'WEEK' => 'Week',
      'MONTH' => 'Month',
      _ => period,
    };
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _transactions(
      widget.dashboard['transactions'] ?? widget.dashboard['earningsHistory'],
    );

    final incentives = _money(
      widget.dashboard['incentives'] ?? widget.dashboard['incentiveEarnings'],
    );

    final deductions = _money(
      widget.dashboard['deductions'] ?? widget.dashboard['totalDeductions'],
    );

    final availableBalance = _money(
      widget.dashboard['availableBalance'] ??
          widget.dashboard['withdrawableBalance'],
    );

    final pendingSettlement = _money(
      widget.dashboard['pendingSettlement'] ??
          widget.dashboard['pendingPayout'],
    );

    final completedJobs = (widget.dashboard['completedJobs'] ?? 0).toString();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text(
              'Earnings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Track earnings, incentives, deductions and settlements.',
              style: TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 18),
            SegmentedButton<String>(
              segments: _periods
                  .map(
                    (period) => ButtonSegment(
                      value: period,
                      label: Text(_periodLabel(period)),
                    ),
                  )
                  .toList(),
              selected: {_selectedPeriod},
              onSelectionChanged: (selection) {
                setState(() => _selectedPeriod = selection.first);
              },
            ),
            const SizedBox(height: 18),
            _PrimaryEarningsCard(
              period: _selectedPeriod,
              amount: _periodEarnings,
              completedJobs: completedJobs,
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _EarningsMetricCard(
                  icon: Icons.card_giftcard_outlined,
                  label: 'Incentives',
                  value: incentives,
                ),
                _EarningsMetricCard(
                  icon: Icons.remove_circle_outline,
                  label: 'Deductions',
                  value: deductions,
                ),
                _EarningsMetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Available balance',
                  value: availableBalance,
                ),
                _EarningsMetricCard(
                  icon: Icons.schedule_outlined,
                  label: 'Pending settlement',
                  value: pendingSettlement,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Settlement summary',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _SettlementSummaryCard(
              availableBalance: availableBalance,
              pendingSettlement: pendingSettlement,
              nextSettlement: (widget.dashboard['nextSettlementDate'] ??
                      widget.dashboard['nextPayoutDate'] ??
                      'Not scheduled')
                  .toString(),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Transaction history',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${transactions.length}',
                  style: const TextStyle(
                    color: BrandColors.lime,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (transactions.isEmpty)
              const _EarningsEmptyState()
            else
              ...transactions.map(
                (transaction) => _EarningsTransactionCard(
                  transaction: transaction,
                  money: _money,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryEarningsCard extends StatelessWidget {
  const _PrimaryEarningsCard({
    required this.period,
    required this.amount,
    required this.completedJobs,
  });

  final String period;
  final String amount;
  final String completedJobs;

  @override
  Widget build(BuildContext context) {
    final label = switch (period) {
      'TODAY' => 'Today’s earnings',
      'MONTH' => 'Monthly earnings',
      _ => 'Weekly earnings',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: BrandColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.task_alt_outlined,
                  color: BrandColors.lime,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Text('$completedJobs completed jobs'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsMetricCard extends StatelessWidget {
  const _EarningsMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: BrandColors.lime),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: BrandColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementSummaryCard extends StatelessWidget {
  const _SettlementSummaryCard({
    required this.availableBalance,
    required this.pendingSettlement,
    required this.nextSettlement,
  });

  final String availableBalance;
  final String pendingSettlement;
  final String nextSettlement;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SettlementRow(
              label: 'Available balance',
              value: availableBalance,
            ),
            const Divider(height: 24),
            _SettlementRow(
              label: 'Pending settlement',
              value: pendingSettlement,
            ),
            const Divider(height: 24),
            _SettlementRow(
              label: 'Next settlement',
              value: nextSettlement,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: BrandColors.muted),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _EarningsTransactionCard extends StatelessWidget {
  const _EarningsTransactionCard({
    required this.transaction,
    required this.money,
  });

  final Map<String, dynamic> transaction;
  final String Function(dynamic) money;

  @override
  Widget build(BuildContext context) {
    final bookingId = (transaction['bookingId'] ??
            transaction['bookingCode'] ??
            transaction['reference'] ??
            '—')
        .toString();

    final service = (transaction['service'] ??
            transaction['serviceName'] ??
            transaction['title'] ??
            'Service')
        .toString();

    final date = (transaction['date'] ??
            transaction['createdAt'] ??
            transaction['completedAt'] ??
            'Date unavailable')
        .toString();

    final net = transaction['netEarning'] ??
        transaction['netAmount'] ??
        transaction['amount'] ??
        0;

    final status =
        (transaction['settlementStatus'] ?? transaction['status'] ?? 'PENDING')
            .toString()
            .toUpperCase();

    final statusColor = status.contains('PAID') ||
            status.contains('SETTLED') ||
            status.contains('COMPLETED')
        ? BrandColors.lime
        : Colors.amber;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: BrandColors.lime.withValues(alpha: 0.16),
          foregroundColor: BrandColors.lime,
          child: const Icon(Icons.currency_rupee),
        ),
        title: Text(
          service,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$bookingId · $date'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(net),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsEmptyState extends StatelessWidget {
  const _EarningsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: BrandColors.muted,
            ),
            SizedBox(height: 12),
            Text(
              'No earnings yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Completed booking payments will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BrandColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

