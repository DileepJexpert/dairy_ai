// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/maturity/models/maturity_models.dart';
import 'package:dairy_ai/features/maturity/providers/maturity_providers.dart';

class GroupFeedPoolScreen extends ConsumerWidget {
  const GroupFeedPoolScreen({super.key});

  void _showJoinModal(BuildContext context, GroupFeedPool pool) {
    double qty = pool.minOrderKg;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final totalCost = qty * pool.groupPricePerKg;
          final retailCost = qty * pool.retailPricePerKg;
          final savings = retailCost - totalCost;

          return Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group_work, color: Color(0xff064e3b), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pool.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'ऑर्डर मात्रा: ${qty.toInt()} कि.ग्रा. (kg)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Slider(
                  value: qty,
                  min: pool.minOrderKg,
                  max: 5000,
                  divisions: 45,
                  activeColor: const Color(0xff064e3b),
                  onChanged: (val) => setModalState(() => qty = val),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('सामूहिक मूल्य:', style: TextStyle(fontSize: 11)),
                          Text(
                            '₹${totalCost.toInt()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff064e3b),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'बचत: ₹${savings.toInt()} (${pool.savingsPct.toInt()}%)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('सामूहिक खरीद में ${qty.toInt()} kg सफलतापूर्वक बुक हो गया! कुल बचत: ₹${savings.toInt()}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff064e3b),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('ऑर्डर बुक करें (Confirm Booking)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poolsAsync = ref.watch(groupFeedPoolsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('सामूहिक चारा व साइलेज खरीद (Group Buying Pool)'),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: poolsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('डेटा लोड करने में असमर्थ')),
            data: (pools) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Promotional Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff14532d), Color(0xff166534), Color(0xff15803d)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff14532d).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade300,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '🌾 15-25% थोक फैक्ट्री बचत',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xff78350f)),
                              ),
                            ),
                            const Icon(Icons.handshake, color: Colors.white70, size: 24),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'गांव क्लस्टर सामूहिक चारा खरीद पूल',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'गांव के 20+ किसान मिलकर पूरा ट्रक बुक करते हैं, जिससे सीधा फैक्ट्री-गेट दाम मिलता है।',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'सक्रिय सामूहिक पूल (Active Community Pools):',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...pools.map((pool) => _PoolCard(
                        pool: pool,
                        onJoin: () => _showJoinModal(context, pool),
                      )),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  final GroupFeedPool pool;
  final VoidCallback onJoin;

  const _PoolCard({required this.pool, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final progress = pool.bookedTons / pool.targetTons;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  pool.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  '${pool.hoursRemaining} घंटे शेष',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'डिलिवरी हब: ${pool.deliveryHub}',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          // Price Comparison Row
          Row(
            children: [
              Text(
                '₹${pool.groupPricePerKg.toStringAsFixed(2)} / kg',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff064e3b),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${pool.retailPricePerKg.toStringAsFixed(2)}',
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${pool.savingsPct.toStringAsFixed(1)}% छूट',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'बुक: ${pool.bookedTons.toStringAsFixed(1)} / ${pool.targetTons.toInt()} टन',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                '${(progress * 100).toInt()}% पूर्ण (${pool.participatingFarmers} किसान)',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Color(0xff16a34a)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 14),

          // Join Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff064e3b),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text('सामूहिक पूल में ऑर्डर बुक करें →', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
