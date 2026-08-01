import 'package:flutter/material.dart';

/// Pinned bottom action bar used by the onboarding journeys so the primary
/// CTA stays visible above the keyboard and the home indicator.
class OnboardingBottomBar extends StatelessWidget {
  const OnboardingBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: child,
        ),
      ),
    );
  }
}
