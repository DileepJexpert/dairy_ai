import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/store_design.dart';

class AboutMilterraScreen extends StatelessWidget {
  const AboutMilterraScreen({super.key});

  @override
  Widget build(BuildContext context) => _BrandPage(
        selected: 'About Us',
        hero: const _Hero(
          eyebrow: 'ABOUT MILTERRA',
          title: 'Food feels different when its source is visible.',
          body:
              'Milterra is building a more transparent way to discover food: one that makes the source, maker, method and available proof easier to understand before you buy.',
          icon: Icons.eco_outlined,
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Heading(
              title: 'What guides us',
              body:
                  'Know Your Source is the standard we use when presenting every product and every claim.',
            ),
            const SizedBox(height: 16),
            const _CardGrid(cards: [
              _CardData(Icons.location_on_outlined, 'Traceable sourcing',
                  'Explain where a product comes from and identify its producer when that information is verified.'),
              _CardData(Icons.menu_book_outlined, 'Honest product information',
                  'Describe ingredients, pack size and process clearly, without hiding behind vague marketing language.'),
              _CardData(Icons.fact_check_outlined, 'Evidence before claims',
                  'Publish lab reports, certificates and batch details only when the supporting evidence is available.'),
            ]),
            const SizedBox(height: 32),
            _Statement(
              title: 'What we are building',
              body:
                  'A direct marketplace where people can understand the journey behind their food. As verified information becomes available, product pages can connect the producer, origin, method, batch and quality records in one place.',
              actions: [
                _Action('Read Our Farm Story', Icons.agriculture_outlined,
                    () => context.go('/farm-story')),
                _Action('Contact Us', Icons.chat_bubble_outline,
                    () => context.go('/contact'), outlined: true),
              ],
            ),
          ],
        ),
      );
}

class FarmStoryScreen extends StatelessWidget {
  const FarmStoryScreen({super.key});

  static const _steps = [
    _Step('01', Icons.landscape_outlined, 'The farm',
        'The place and growing environment are the beginning of the story. We show origin details when they are confirmed.'),
    _Step('02', Icons.person_outline, 'The farmer or maker',
        'Food has people behind it. Producer profiles should use real names, records and photographs with permission.'),
    _Step('03', Icons.grass_outlined, 'The animal or crop',
        'Breed, crop variety, feed and cultivation details are shown only when the source can support them.'),
    _Step('04', Icons.settings_outlined, 'The process',
        'How the product is made matters. We explain the actual method and avoid invented tradition or process claims.'),
    _Step('05', Icons.science_outlined, 'Purity testing',
        'When a product is tested, the relevant report and testing context should be available for customers to review.'),
    _Step('06', Icons.qr_code_2_outlined, 'Your product and batch',
        'Batch-level records connect the product in your hand to the source and evidence collected for that production run.'),
  ];

  @override
  Widget build(BuildContext context) => _BrandPage(
        selected: 'Our Farm Story',
        hero: const _Hero(
          eyebrow: 'OUR FARM STORY',
          title: 'We believe you should know your source.',
          body:
              'Know where your food comes from, who produced it, how it was made and how its purity was checked. That is what Know Your Source means to us.',
          icon: Icons.agriculture_outlined,
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Heading(
              title: 'From source to product',
              body:
                  'A connected record is more useful than a marketing promise. This is the journey Milterra is designed to make visible.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, box) {
              final columns = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 600 ? 2 : 1);
              final width = (box.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _steps
                    .map((step) => SizedBox(width: width, child: _StepCard(step)))
                    .toList(),
              );
            }),
            const SizedBox(height: 32),
            _Statement(
              title: 'Our standard for proof',
              body:
                  'We publish source records, dated photographs, process details, test reports and batch information only after they are verified. If proof is not available yet, we do not present the claim as established fact.',
              actions: [
                _Action('Browse Products', Icons.storefront_outlined,
                    () => context.go('/shop')),
                _Action('Ask About a Source', Icons.chat_bubble_outline,
                    () => context.go('/contact'), outlined: true),
              ],
            ),
          ],
        ),
      );
}

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static final _whatsApp = Uri.parse(
      'https://wa.me/919839769808?text=Hello%20Milterra%2C%20I%20need%20help.');
  static final _email = Uri(
    scheme: 'mailto',
    path: 'support@milterra.in',
    queryParameters: {'subject': 'Milterra enquiry'},
  );

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This contact option could not be opened.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => _BrandPage(
        selected: 'Contact Us',
        hero: const _Hero(
          eyebrow: 'CONTACT US',
          title: 'Talk directly with Milterra.',
          body:
              'Ask about an order, a product source, available proof or working with Milterra. Choose the channel that suits you.',
          icon: Icons.chat_bubble_outline,
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(builder: (context, box) {
              final width = box.maxWidth >= 720 ? (box.maxWidth - 16) / 2 : box.maxWidth;
              return Wrap(spacing: 16, runSpacing: 16, children: [
                _ContactCard(width, Icons.chat_outlined, 'WhatsApp',
                    '+91 98397 69808', 'Start a conversation', () => _open(context, _whatsApp)),
                _ContactCard(width, Icons.email_outlined, 'Email',
                    'support@milterra.in', 'Send an email', () => _open(context, _email)),
                _ContactCard(width, Icons.support_agent_outlined, 'Customer support',
                    'Orders, delivery, account and returns', 'Open help centre', () => context.go('/help')),
                _ContactCard(width, Icons.handshake_outlined, 'Farm and sourcing enquiries',
                    'Farmers, producers and responsible partnerships', 'Contact our team', () => _open(context, _email)),
              ]);
            }),
            const SizedBox(height: 32),
            const _Heading(
              title: 'How we can help',
              body:
                  'Share your order number for order questions, or the product and batch details when asking about a source or quality record.',
            ),
            const SizedBox(height: 16),
            const _CardGrid(cards: [
              _CardData(Icons.local_shipping_outlined, 'Orders and delivery',
                  'Order status, delivery questions, cancellation and returns.'),
              _CardData(Icons.travel_explore_outlined, 'Product and source',
                  'Ingredients, origin, process, lab evidence and batch records.'),
              _CardData(Icons.inventory_2_outlined, 'Partnerships and boxes',
                  'Producer partnerships, business orders and curated boxes.'),
            ]),
          ],
        ),
      );
}

class _BrandPage extends StatelessWidget {
  const _BrandPage({required this.selected, required this.hero, required this.content});
  final String selected;
  final Widget hero;
  final Widget content;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: storeCream,
        body: Column(children: [
          const StoreHeader(currentCategory: 'All'),
          StoreCategoryNavigation(selected: selected),
          Expanded(child: SingleChildScrollView(child: Column(children: [
            Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width < 600 ? 16 : 28,
                  vertical: 28,
                ),
                child: Column(children: [hero, const SizedBox(height: 28), content]),
              ),
            )),
            const StoreFooter(),
          ]))),
        ]),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.eyebrow, required this.title, required this.body, required this.icon});
  final String eyebrow, title, body;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 24 : 40),
        decoration: BoxDecoration(color: storeGreen, borderRadius: BorderRadius.circular(18)),
        child: LayoutBuilder(builder: (context, box) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(eyebrow, style: const TextStyle(color: storeAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.4)),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(color: Colors.white, fontSize: box.maxWidth < 600 ? 28 : 40, fontWeight: FontWeight.w900, height: 1.12)),
              const SizedBox(height: 14),
              Text(body, style: const TextStyle(color: Color(0xffd9e5df), fontSize: 16, height: 1.55)),
            ])),
            if (box.maxWidth >= 700) ...[
              const SizedBox(width: 36),
              Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), shape: BoxShape.circle), child: Icon(icon, size: 62, color: storeAmber)),
            ],
          ],
        )),
      );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.body});
  final String title, body;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(color: storeGreen, fontSize: 25, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6),
    Text(body, style: const TextStyle(color: storeMuted, fontSize: 15, height: 1.5)),
  ]);
}

class _CardData {
  const _CardData(this.icon, this.title, this.body);
  final IconData icon;
  final String title, body;
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.cards});
  final List<_CardData> cards;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
    final columns = box.maxWidth >= 880 ? 3 : (box.maxWidth >= 580 ? 2 : 1);
    final width = (box.maxWidth - (columns - 1) * 16) / columns;
    return Wrap(spacing: 16, runSpacing: 16, children: cards.map((card) => SizedBox(
      width: width,
      child: _ContentCard(icon: card.icon, title: card.title, body: card.body),
    )).toList());
  });
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 190),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: storeBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: storeSage, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: storeGreen, size: 24)),
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(color: storeGreen, fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text(body, style: const TextStyle(color: storeMuted, fontSize: 13.5, height: 1.45)),
    ]),
  );
}

class _Step {
  const _Step(this.number, this.icon, this.title, this.body);
  final String number, title, body;
  final IconData icon;
}

class _StepCard extends StatelessWidget {
  const _StepCard(this.step);
  final _Step step;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 220),
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: storeBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: storeSage, borderRadius: BorderRadius.circular(10)), child: Icon(step.icon, color: storeGreen, size: 24)),
        Text(step.number, style: const TextStyle(color: storeAmber, fontSize: 22, fontWeight: FontWeight.w900)),
      ]),
      const SizedBox(height: 16),
      Text(step.title, style: const TextStyle(color: storeGreen, fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      Text(step.body, style: const TextStyle(color: storeMuted, fontSize: 13.5, height: 1.45)),
    ]),
  );
}

class _Statement extends StatelessWidget {
  const _Statement({required this.title, required this.body, required this.actions});
  final String title, body;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: storeSage, borderRadius: BorderRadius.circular(16), border: Border.all(color: storeBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: storeGreen, fontSize: 23, fontWeight: FontWeight.w900)),
      const SizedBox(height: 9),
      Text(body, style: const TextStyle(color: Color(0xff33443b), fontSize: 15, height: 1.55)),
      const SizedBox(height: 20),
      Wrap(spacing: 12, runSpacing: 10, children: actions),
    ]),
  );
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.icon, this.onPressed, {this.outlined = false});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool outlined;
  @override
  Widget build(BuildContext context) => outlined
      ? OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label), style: OutlinedButton.styleFrom(foregroundColor: storeGreen, side: const BorderSide(color: storeGreen), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)))
      : FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label), style: FilledButton.styleFrom(backgroundColor: storeGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)));
}

class _ContactCard extends StatelessWidget {
  const _ContactCard(this.width, this.icon, this.title, this.detail, this.actionLabel, this.onPressed);
  final double width;
  final IconData icon;
  final String title, detail, actionLabel;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: storeBorder)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: storeSage, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: storeGreen, size: 25)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: storeGreen, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(detail, style: const TextStyle(color: storeMuted, fontSize: 13.5)),
        const SizedBox(height: 12),
        TextButton(onPressed: onPressed, style: TextButton.styleFrom(foregroundColor: storeGreen, padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap), child: Text(actionLabel)),
      ])),
    ]),
  ));
}
