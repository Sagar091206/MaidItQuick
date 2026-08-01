import 'package:flutter/material.dart';

import '../../../core/brand_theme.dart';

/// Numbered, expandable onboarding card shared by the customer and partner
/// journeys so both flows use the same visual language.
class OnboardingStepCard extends StatelessWidget {
  const OnboardingStepCard({
    super.key,
    required this.number,
    required this.title,
    required this.status,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String number;
  final String title;
  final String status;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase().replaceAll('_', ' ');
    final approved =
        normalized == 'APPROVED' || normalized == 'READY' || normalized == 'AVAILABLE';
    final pending = normalized == 'PENDING';
    final locked = normalized == 'LOCKED';
    final statusColor = approved
        ? BrandColors.lime
        : pending
            ? Colors.amber
            : locked
                ? BrandColors.muted
                : Colors.orangeAccent;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: approved
              ? BrandColors.lime
              : BrandColors.muted.withValues(alpha: 0.28),
          foregroundColor: approved
              ? BrandColors.evergreen
              : Theme.of(context).colorScheme.onSurface,
          child: Text(
            number,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          normalized,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: children,
      ),
    );
  }
}
