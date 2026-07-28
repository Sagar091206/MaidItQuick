import 'package:flutter/material.dart';

import '../../../core/brand_theme.dart';

class MvpHomeScreen extends StatelessWidget {
  const MvpHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Image.asset('assets/branding/maiditquick-wordmark.jpeg', height: 96, fit: BoxFit.contain)),
            const SizedBox(height: 34),
            const Text('Home help\nin minutes.', style: TextStyle(fontSize: 42, height: 1.04, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            const Text('Book trusted home help in just a few taps.', style: TextStyle(fontSize: 18, color: BrandColors.muted)),
            const SizedBox(height: 26),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(width: 48, height: 48, decoration: const BoxDecoration(color: BrandColors.lime, shape: BoxShape.circle), child: const Icon(Icons.bolt, color: BrandColors.evergreen)),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Available near you', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 4), Text('Check your PIN for an instant ETA', style: TextStyle(color: BrandColors.muted))])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.arrow_forward), label: const Text('Book a service')),
            const SizedBox(height: 16),
            const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _TrustItem(icon: Icons.verified_user_outlined, label: 'Verified\nprofessionals'),
              _TrustItem(icon: Icons.flash_on_outlined, label: 'Quick\nbooking'),
              _TrustItem(icon: Icons.support_agent_outlined, label: '24/7\nsupport'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(children: [Icon(icon, color: BrandColors.lime), const SizedBox(height: 8), Text(label, textAlign: TextAlign.center, style: const TextStyle(color: BrandColors.muted))]);
}
