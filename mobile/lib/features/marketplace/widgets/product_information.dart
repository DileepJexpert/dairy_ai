import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/providers/admin_marketplace_provider.dart';
import '../models/product_models.dart';

/// Shared destination: no unrelated purity scores or seed reports are evidence.
void showProductQuality(BuildContext context, {Product? product}) {
  showDialog<void>(
      context: context,
      builder: (context) => Consumer(builder: (context, ref, _) {
            final productId = product?.id;
            final reports = ref.watch(publicCertificatesProvider(productId));
            return AlertDialog(
              scrollable: true,
              title: Text(reports.valueOrNull?.isNotEmpty == true
                  ? 'Lab Test Reports'
                  : 'Quality & Research'),
              content: SizedBox(
                  width: 560,
                  child: reports.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) =>
                        Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Could not load reports from the backend.'),
                      TextButton(
                          onPressed: () => ref.invalidate(
                              publicCertificatesProvider(productId)),
                          child: const Text('Retry')),
                    ]),
                    data: (rows) => rows.isEmpty
                        ? const Text(
                            'No product-specific lab reports are published here yet. Concept labels and packaging images do not confirm completed testing.')
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: rows
                                .map((c) => ListTile(
                                      title: Text(
                                          '${c.productTitle} · Batch ${c.batchNumber}'),
                                      subtitle: SelectableText(
                                          '${c.laboratory}\n${c.reportUrl}'),
                                      trailing: IconButton(
                                          tooltip: 'Copy report URL',
                                          icon: const Icon(Icons.copy),
                                          onPressed: () => Clipboard.setData(
                                              ClipboardData(
                                                  text: c.reportUrl!))),
                                    ))
                                .toList()),
                  )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            );
          }));
}

class ProductQualityLink extends ConsumerWidget {
  const ProductQualityLink({super.key, this.product});
  final Product? product;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = product?.id;
    final reports = ref.watch(publicCertificatesProvider(id));
    return TextButton.icon(
        onPressed: () => showProductQuality(context, product: product),
        icon: const Icon(Icons.science_outlined, size: 18),
        label: Text(reports.valueOrNull?.isNotEmpty == true
            ? 'Lab Test Reports'
            : 'Quality & Research'));
  }
}

Future<void> showConceptInterest(
    BuildContext context, WidgetRef ref, Product product,
    {bool updates = false}) async {
  final user = ref.read(currentUserProvider);
  final name = TextEditingController(text: user?.name ?? '');
  final contact = TextEditingController(text: user?.phone ?? '');
  final feedback = TextEditingController();
  bool saving = false;
  await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
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
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(updates
                            ? 'Register your contact preference for future product updates. This is not a farmer-trial enrolment.'
                            : 'Feedback on a concept is separate from a review of a purchased product.'),
                        const SizedBox(height: 16),
                        TextField(
                          controller: name,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: contact,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Email or phone',
                            hintText: 'you@gmail.com or 9876543210',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (!updates) ...[
                          const SizedBox(height: 12),
                          TextField(
                              controller: feedback,
                              enabled: !saving,
                              minLines: 3,
                              maxLines: 6,
                              decoration: const InputDecoration(
                                  labelText: 'Your feedback',
                                  hintText:
                                      'What would you want from this product?',
                                  border: OutlineInputBorder())),
                        ],
                      ])),
              actions: [
                TextButton(
                    onPressed:
                        saving ? null : () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final visitorName = name.text.trim();
                            final contactValue = contact.text.trim();
                            final message = feedback.text.trim();
                            if (visitorName.length < 2 ||
                                contactValue.length < 5 ||
                                (!updates && message.length < 5)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Add your name, contact, and meaningful feedback.')),
                              );
                              return;
                            }
                            setDialogState(() => saving = true);
                            try {
                              final isEmail = contactValue.contains('@');
                              await ref.read(dioProvider).post(
                                '/marketplace/concepts/${product.id}/feedback',
                                data: {
                                  'concept_title': product.title,
                                  'visitor_name': visitorName,
                                  if (isEmail) 'email': contactValue,
                                  if (!isEmail) 'phone': contactValue,
                                  'message': updates ? null : message,
                                  'wants_updates': updates,
                                },
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(updates
                                        ? 'You are registered for future updates.'
                                        : 'Thank you. Your concept feedback was saved.'),
                                  ),
                                );
                              }
                            } catch (error) {
                              setDialogState(() => saving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Could not save: $error')),
                                );
                              }
                            }
                          },
                    child: Text(saving
                        ? 'Saving…'
                        : updates
                            ? 'Register for Updates'
                            : 'Submit Feedback')),
              ],
            );
          }));
  // Let the dialog route finish its exit animation before releasing its field.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  name.dispose();
  contact.dispose();
  feedback.dispose();
}

class ConceptActions extends ConsumerWidget {
  const ConceptActions({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton(
            onPressed: () => showConceptInterest(context, ref, product),
            child: const Text('Share Farmer Feedback',
                textAlign: TextAlign.center)),
        const SizedBox(height: 6),
        OutlinedButton(
            onPressed: () =>
                showConceptInterest(context, ref, product, updates: true),
            child: const Text('Register for Updates',
                textAlign: TextAlign.center)),
      ]);
}
