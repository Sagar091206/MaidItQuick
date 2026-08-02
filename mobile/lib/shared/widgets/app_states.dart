import 'package:flutter/material.dart';

import '../../core/brand_theme.dart';

/// Pulsing skeleton primitives. Wraps the child in a looping opacity fade.
/// Used for loading states instead of a plain spinner so screens keep their
/// layout while data is fetched.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween(begin: 0.45, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

/// A single pulsing placeholder block.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      width: width,
      height: circle ? radius * 2 : height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// A skeleton list tile: leading circle + two text lines.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key, this.padding = const EdgeInsets.all(16)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.brandCard,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            const SkeletonBox(width: 46, height: 46, radius: 23),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 140, height: 16, radius: 6),
                  SizedBox(height: 10),
                  SkeletonBox(width: double.infinity, height: 12, radius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton card with a title line and two content lines.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.brandCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 120, height: 18, radius: 6),
            const SizedBox(height: 14),
            for (var i = 0; i < lines; i++) ...[
              const SkeletonBox(width: double.infinity, height: 12, radius: 6),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// A full-page loading layout: branded header placeholder + list of skeletons.
class SkeletonListView extends StatelessWidget {
  const SkeletonListView({super.key, this.itemCount = 4, this.slivers = false});

  final int itemCount;
  final bool slivers;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const SkeletonBox(width: 190, height: 30, radius: 8),
          const SizedBox(height: 10),
          const SkeletonBox(width: double.infinity, height: 14, radius: 6),
          const SizedBox(height: 24),
          for (var i = 0; i < itemCount; i++) ...[
            const SkeletonListTile(),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Generic empty state (icon + title + optional message + optional action).
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Card(
      color: context.brandCard,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: scheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.brandMuted, height: 1.35),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry action. Use inside a scrollable so
/// pull-to-refresh still works.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: scheme.primary),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin offline banner shown under the app bar when the network is down.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.wifi_off, size: 18, color: scheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You are offline. Showing the last loaded data.',
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated success check used on confirmation screens.
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({super.key, this.size = 72});

  final double size;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          color: scheme.onPrimary,
          size: widget.size * 0.6,
        ),
      ),
    );
  }
}

/// Shared status pill (replaces the private `_StatusPill` copies).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.color});

  final String status;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final pillColor = color ?? scheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          status.replaceAll('_', ' '),
          style: TextStyle(
            color: pillColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Shared section header with optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Status → human label used by active-booking and confirmation screens.
String bookingStatusLabel(String status) {
  return switch (status) {
    'REQUESTED' => 'Booking confirmed',
    'ASSIGNED' => 'Partner assigned',
    'ACCEPTED' => 'Partner accepted',
    'ON_THE_WAY' => 'Partner on the way',
    'ARRIVED' => 'Partner arrived',
    'IN_PROGRESS' => 'Service in progress',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    _ => status.replaceAll('_', ' '),
  };
}

/// Formats paise as ₹ whole rupees (e.g. 12500 → "₹125").
String formatPaise(int paise) => '₹${(paise / 100).round().toString()}';

/// Formats an ISO date time (e.g. "02/08/2026, 10:00 AM").
String formatDateTime(String iso) {
  final parsed = DateTime.tryParse(iso)?.toLocal();
  if (parsed == null) return iso;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final hour12 = parsed.hour == 0 || parsed.hour == 12 ? 12 : parsed.hour % 12;
  final period = parsed.hour >= 12 ? 'PM' : 'AM';
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}, $hour12:$minute $period';
}
