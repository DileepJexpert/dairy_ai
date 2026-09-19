import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../providers/vendor_provider.dart';

const Color storeGreen = Color(0xff1b4332);
const Color storeBorder = Color(0xffe2e8f0);
const Color storeMuted = Color(0xff64748b);
const Color storeCream = Color(0xfffdfbf7);
const Color storeAmber = Color(0xffd97706);

class VendorReviewsScreen extends ConsumerStatefulWidget {
  const VendorReviewsScreen({super.key});

  @override
  ConsumerState<VendorReviewsScreen> createState() =>
      _VendorReviewsScreenState();
}

class _VendorReviewsScreenState extends ConsumerState<VendorReviewsScreen> {
  String _filter = 'all'; // 'all', 'unreplied', 'replied'

  Future<void> _submitReply(String reviewId, String currentReply) async {
    final controller = TextEditingController(text: currentReply);
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.reply_rounded, color: storeGreen),
              const SizedBox(width: 8),
              Text(
                currentReply.isEmpty ? 'Reply to Customer' : 'Update Reply',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your official response will be published publicly under this review on your product page.',
                  style: TextStyle(fontSize: 12, color: storeMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  maxLength: 600,
                  decoration: const InputDecoration(
                    labelText: 'Seller Response',
                    hintText:
                        'Thank the customer, clarify usage, or offer support...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: storeGreen),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        final dio = ref.read(dioProvider);
                        final res = await dio.post(
                          '/vendor/products/reviews/$reviewId/reply',
                          data: {'reply': text},
                        );
                        if (!mounted) return;
                        Navigator.pop(dialogCtx);
                        ref.invalidate(vendorReviewsProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res.data['message']?.toString() ??
                                  'Reply published successfully',
                            ),
                            backgroundColor: storeGreen,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to publish reply: $e'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Publish Reply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(vendorReviewsProvider(_filter));
    final allReviewsAsync = ref.watch(vendorReviewsProvider('all'));

    return Scaffold(
      backgroundColor: storeCream,
      appBar: AppBar(
        title: const Text(
          'Customer Reviews & Q&A',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xff1e293b),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xff1e293b)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Reviews',
            onPressed: () => ref.invalidate(vendorReviewsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Overview Stats
          allReviewsAsync.when(
            data: (allReviews) {
              final total = allReviews.length;
              final unreplied = allReviews
                  .where((r) =>
                      r['vendor_reply'] == null ||
                      r['vendor_reply'].toString().trim().isEmpty)
                  .length;
              final double avgRating = total > 0
                  ? allReviews
                          .map((r) =>
                              double.tryParse(r['rating']?.toString() ?? '5') ??
                              5.0)
                          .reduce((a, b) => a + b) /
                      total
                  : 5.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    _buildStatPill(
                      title: 'Total Reviews',
                      value: '$total',
                      icon: Icons.rate_review_outlined,
                      color: storeGreen,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      title: 'Avg Rating',
                      value: '★ ${avgRating.toStringAsFixed(1)}',
                      icon: Icons.star_rounded,
                      color: storeAmber,
                    ),
                    const SizedBox(width: 8),
                    _buildStatPill(
                      title: 'Needs Reply',
                      value: '$unreplied',
                      icon: Icons.mark_chat_unread_outlined,
                      color: unreplied > 0 ? const Color(0xffef4444) : storeGreen,
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(height: 1, color: storeBorder),

          // Filters Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('All Reviews', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Needs Reply', 'unreplied'),
                const SizedBox(width: 8),
                _buildFilterChip('Replied', 'replied'),
              ],
            ),
          ),
          const Divider(height: 1, color: storeBorder),

          // Review list
          Expanded(
            child: reviewsAsync.when(
              data: (reviews) {
                if (reviews.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.reviews_outlined,
                              size: 56, color: storeMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(
                            _filter == 'unreplied'
                                ? 'All caught up! No pending reviews to answer.'
                                : 'No customer reviews found for this filter.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: storeMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final review = reviews[i];
                    return _buildReviewCard(review);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Failed to load reviews: $err',
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(vendorReviewsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) setState(() => _filter = value);
      },
      selectedColor: storeGreen,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : const Color(0xff334155),
      ),
      backgroundColor: const Color(0xfff1f5f9),
      side: BorderSide(
        color: selected ? storeGreen : storeBorder,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final reviewId = review['id']?.toString() ?? '';
    final productTitle = review['product_title']?.toString() ?? 'Product Item';
    final rating = int.tryParse(review['rating']?.toString() ?? '5') ?? 5;
    final comment = review['comment']?.toString() ?? '';
    final userName = review['user_name']?.toString() ?? 'Verified Buyer';
    final vendorReply = review['vendor_reply']?.toString();
    final isApproved = review['is_approved'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Tag & Moderation status
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 14, color: storeGreen),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  productTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff0f172a),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isApproved
                      ? const Color(0xffecfdf5)
                      : const Color(0xfffef2f2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isApproved ? 'LIVE' : 'UNDER REVIEW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isApproved
                        ? const Color(0xff059669)
                        : const Color(0xffdc2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Rating stars & Author
          Row(
            children: [
              for (int s = 1; s <= 5; s++)
                Icon(
                  s <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 16,
                  color: s <= rating ? storeAmber : const Color(0xffcbd5e1),
                ),
              const SizedBox(width: 8),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff475569),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.verified, size: 12, color: Color(0xff10b981)),
            ],
          ),
          const SizedBox(height: 8),

          // Customer Review Comment
          Text(
            comment.isEmpty ? '(No written comment provided)' : comment,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: comment.isEmpty
                  ? storeMuted
                  : const Color(0xff1e293b),
              fontStyle: comment.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),

          // Existing Seller Reply
          if (vendorReply != null && vendorReply.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffe2e8f0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storefront, size: 14, color: storeGreen),
                      SizedBox(width: 6),
                      Text(
                        'Your Official Response',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: storeGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vendorReply,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xff334155),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Action button
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: storeGreen,
                side: const BorderSide(color: storeGreen),
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(
                vendorReply != null && vendorReply.trim().isNotEmpty
                    ? Icons.edit_outlined
                    : Icons.reply_rounded,
                size: 14,
              ),
              label: Text(
                vendorReply != null && vendorReply.trim().isNotEmpty
                    ? 'Edit Reply'
                    : 'Reply to Customer',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _submitReply(reviewId, vendorReply ?? ''),
            ),
          ),
        ],
      ),
    );
  }
}
