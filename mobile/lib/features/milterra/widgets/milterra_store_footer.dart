import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/store_theme.dart';

/// Minimal, high-trust luxury brand footer for Milterra D2C Ghee.
class MilterraStoreFooter extends StatelessWidget {
  const MilterraStoreFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: storeGreen,
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 4 Trust Pillars
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isWide = constraints.maxWidth >= 768;
                    return GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: isWide ? 2.5 : 2.0,
                      children: const [
                        _TrustPillar(
                          icon: Icons.verified_outlined,
                          title: 'Vedic Bilona Method',
                          subtitle: 'Hand-churned from cultured curd in earthen & brass vessels',
                        ),
                        _TrustPillar(
                          icon: Icons.science_outlined,
                          title: 'Lab-Tested Purity',
                          subtitle: '100% free of palm oil, preservatives & adulterants',
                        ),
                        _TrustPillar(
                          icon: Icons.local_shipping_outlined,
                          title: 'Glass Jar Safe Delivery',
                          subtitle: 'Eco-friendly, shockproof doorstep delivery across India',
                        ),
                        _TrustPillar(
                          icon: Icons.support_agent_outlined,
                          title: 'Direct Farm Connect',
                          subtitle: 'Directly supporting indigenous Gir & Murrah farmers',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                const Divider(color: Color(0xff1f4d41)),
                const SizedBox(height: 24),

                // Footer Links & Brand Summary
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MILTERRA PURE ORGANICS',
                            style: TextStyle(
                              color: storeGold,
                              fontFamily: 'CormorantGaramond',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Committed to restoring ancient Vedic dairy wisdom. Every batch of our A2 Desi Cow Ghee and Rich Buffalo Ghee is crafted using traditional Bilona churning to preserve natural butyric acid, fat-soluble vitamins (A, D, E, K), and authentic aroma.',
                            style: TextStyle(
                              color: StorePalette.onDark,
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'FSSAI Central Lic. No: 10822003000412 • NABL Lab Certified',
                            style: TextStyle(
                              color: storeGold,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QUICK LINKS',
                            style: TextStyle(
                              color: storeGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _footerLink(context, 'About Our Vedic Farm', '/about'),
                          _footerLink(context, 'Lab Reports & Certificates', '/purity-scanner'),
                          _footerLink(context, 'Milterra Earth Living Soil', '/earth'),
                          _footerLink(context, 'Farmer & Machinery Hub →', '/marketplace'),
                          _footerLink(context, 'Help & Customer Support', '/help'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0xff1f4d41)),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    '© 2026 MILTERRA D2C. All rights reserved. Pure Vedic Dairy & Farm Direct.',
                    style: TextStyle(
                      color: StorePalette.onDark,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footerLink(BuildContext context, String title, String route) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => context.go(route),
        child: Text(
          title,
          style: const TextStyle(
            color: StorePalette.onDark,
            fontSize: 12,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xff1f4d41),
          ),
        ),
      ),
    );
  }
}

class _TrustPillar extends StatelessWidget {
  const _TrustPillar({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: storeGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: storeGold, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: storeWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: StorePalette.onDark,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
