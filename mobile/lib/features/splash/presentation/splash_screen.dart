import 'package:flutter/material.dart';

import '../../../core/app_meta.dart';
import '../../../core/brand_theme.dart';

/// Branded launch screen. Shows an animated logo, the app name, a loading
/// indicator and the version while the stored session is restored, then
/// auto-navigates (session exists -> home, otherwise -> login).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: _SplashContent(),
        ),
      ),
    );
  }
}

class _SplashContent extends StatefulWidget {
  const _SplashContent();

  @override
  State<_SplashContent> createState() => _SplashContentState();
}

class _SplashContentState extends State<_SplashContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final Animation<double> _logoScale = Tween<double>(begin: 0.92, end: 1.06)
      .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  bool _motionDisabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect "reduce motion" accessibility settings by showing the logo
    // without the pulse animation.
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations != _motionDisabled) {
      _motionDisabled = disableAnimations;
      _pulse.reset();
      if (!disableAnimations) _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _logoScale,
          child: Container(
            width: 112,
            height: 112,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.45),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/branding/maiditquick-logo-square.jpeg',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          AppMeta.appName,
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          AppMeta.tagline,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.brandMuted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 44),
        const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
        const Spacer(),
        Text(
          'Version ${AppMeta.version}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.brandMuted.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
