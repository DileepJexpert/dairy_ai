import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product_models.dart';

/// Shared destination: no unrelated purity scores or seed reports are evidence.
void showProductQuality(BuildContext context, {Product? product}) {
  final reports = product?.labReports ?? <Uri>[];
  showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(
                reports.isEmpty ? 'Quality & Research' : 'Lab Test Reports'),
            scrollable: true,
            content: reports.isEmpty
                ? Text(product?.isConcept == true
                    ? 'This is a product concept, not confirmation of completed testing. '
                        'No verified reports or confirmed farmer trials are published here.'
                    : 'No verified product-specific lab reports are published here yet. '
                        'Product imagery and labels are not evidence of completed testing.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: reports
                        .map((uri) => ListTile(
                            title: SelectableText(uri.toString()),
                            trailing: IconButton(
                              tooltip: 'Copy report link',
                              icon: const Icon(Icons.copy),
                              onPressed: () => Clipboard.setData(
                                  ClipboardData(text: uri.toString())),
                            )))
                        .toList()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          ));
}

class ProductQualityLink extends StatelessWidget {
  const ProductQualityLink({super.key, this.product});
  final Product? product;
  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => showProductQuality(context, product: product),
        icon: const Icon(Icons.science_outlined, size: 18),
        label: Text(product?.labReports.isNotEmpty == true
            ? 'Lab Test Reports'
            : 'Quality & Research'),
      );
}

/// Do not pretend to submit a form while the collection service is unconfigured.
Future<void> showConceptInterest(BuildContext context, Product product,
    {bool updates = false}) async {
  final draft = TextEditingController();
  await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(
                updates ? 'Register for Updates' : 'Share Farmer Feedback'),
            scrollable: true,
            content: SizedBox(
                width: 440,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(updates
                          ? 'Update registration is not open yet. No farmer trial is being offered. '
                              'You can save this concept to your wishlist and check back.'
                          : 'Feedback on a concept is not a review of a purchased product. '
                              'Online collection is not connected yet. You may prepare and copy a draft; '
                              'nothing entered here is sent or registered.'),
                      if (!updates) ...[
                        const SizedBox(height: 16),
                        TextField(
                            controller: draft,
                            minLines: 3,
                            maxLines: 6,
                            decoration: const InputDecoration(
                                labelText: 'Your feedback draft',
                                hintText:
                                    'What would you want from this product?')),
                      ],
                    ])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
              if (!updates)
                FilledButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(
                          text: '${product.title}\n${draft.text}'));
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Copy draft')),
            ],
          ));
  // Let the dialog route finish its exit animation before releasing its field.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  draft.dispose();
}

class ConceptActions extends StatelessWidget {
  const ConceptActions({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton(
            onPressed: () => showConceptInterest(context, product),
            child: const Text('Share Farmer Feedback',
                textAlign: TextAlign.center)),
        const SizedBox(height: 6),
        OutlinedButton(
            onPressed: () =>
                showConceptInterest(context, product, updates: true),
            child: const Text('Register for Updates',
                textAlign: TextAlign.center)),
      ]);
}
