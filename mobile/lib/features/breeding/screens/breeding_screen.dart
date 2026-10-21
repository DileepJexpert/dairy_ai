import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/breeding/models/breeding_models.dart';
import 'package:dairy_ai/features/breeding/providers/breeding_provider.dart';
import 'package:dairy_ai/features/breeding/screens/add_breeding_event_screen.dart';
import 'package:dairy_ai/features/feed/models/feed_models.dart';
import 'package:dairy_ai/features/feed/providers/feed_provider.dart'
    show cattleListProvider;

class BreedingScreen extends ConsumerStatefulWidget {
  const BreedingScreen({super.key});

  @override
  ConsumerState<BreedingScreen> createState() => _BreedingScreenState();
}

class _BreedingScreenState extends ConsumerState<BreedingScreen> {
  String? _selectedCattleId;

  @override
  Widget build(BuildContext context) {
    final cattleAsync = ref.watch(cattleListProvider);
    final recordsAsync = ref.watch(breedingRecordsProvider(_selectedCattleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('पशु प्रजनन व गर्भधान (Breeding Tracker)'),
        backgroundColor: const Color(0xff064e3b),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEvent(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Event'),
      ),
      body: Column(
        children: [
          // -- Cattle filter --
          Padding(
            padding: const EdgeInsets.all(16),
            child: cattleAsync.when(
              data: (cattleList) => DropdownButtonFormField<String>(
                value: _selectedCattleId,
                decoration: const InputDecoration(
                  labelText: 'Filter by Cattle',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.filter_alt_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Cattle'),
                  ),
                  ...cattleList.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} (${c.tagId})'),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedCattleId = value);
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

          // -- 283-Day Gestation & Heat Alerts Banner --
          _buildGestationAndHeatOverview(context),

          // -- Timeline --
          Expanded(
            child: recordsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timeline, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No breeding events recorded'),
                        SizedBox(height: 4),
                        Text('Tap + to add a breeding event'),
                      ],
                    ),
                  );
                }
                return _BreedingTimeline(records: records);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_note, size: 56, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No breeding records available'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddEvent(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBreedingEventScreen(
          preselectedCattleId: _selectedCattleId,
        ),
      ),
    );
  }

  Widget _buildGestationAndHeatOverview(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffdf2f8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xfffbcfe8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Color(0xffbe185d), size: 18),
              const SizedBox(width: 8),
              const Text(
                '283-Day Bovine Reproduction & Heat Alerts',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xff831843)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xfffce7f3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('AI Protocol Active',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffbe185d))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 4-Stage Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _stageBadge('Day 18–21: Repeat Heat', isAlert: true),
                const SizedBox(width: 6),
                _stageBadge('Day 60–90: Vet PD Check', isAlert: false),
                const SizedBox(width: 6),
                _stageBadge('Day 210: Dry-Off Alert', isAlert: false),
                const SizedBox(width: 6),
                _stageBadge('Day 280: Calving Prep', isAlert: false),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xfffbcfe8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xffbe185d), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Missing estrus window delays conception by 21 days (~₹10,000 lost milk yield). Check morning mucus discharge daily.',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageBadge(String label, {required bool isAlert}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xffbe185d) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAlert ? const Color(0xffbe185d) : const Color(0xfffbcfe8),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isAlert ? Colors.white : const Color(0xff831843),
        ),
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// Breeding Timeline
// ---------------------------------------------------------------------------
class _BreedingTimeline extends StatelessWidget {
  final List<BreedingRecord> records;
  const _BreedingTimeline({required this.records});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final isLast = index == records.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline column
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _eventColor(record.eventType),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _eventIcon(record.eventType),
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Content card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  record.eventTypeLabel,
                                  style: context.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDate(record.date, dateFormat),
                                style: context.textTheme.bodySmall,
                              ),
                            ],
                          ),

                          if (record.cattleName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              record.cattleName!,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: context.colorScheme.primary,
                              ),
                            ),
                          ],

                          if (record.bullId != null) ...[
                            const SizedBox(height: 4),
                            Text('Bull: ${record.bullId}',
                                style: context.textTheme.bodySmall),
                          ],

                          if (record.aiTechName != null) ...[
                            const SizedBox(height: 4),
                            Text('AI Tech: ${record.aiTechName}',
                                style: context.textTheme.bodySmall),
                          ],

                          // Expected calving date
                          if (record.expectedCalvingDate != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month,
                                      size: 16, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Expected calving: ${dateFormat.format(record.expectedCalvingDate!)}',
                                    style:
                                        context.textTheme.bodySmall?.copyWith(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (record.notes != null &&
                              record.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(record.notes!,
                                style: context.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _eventColor(BreedingEventType type) {
    switch (type) {
      case BreedingEventType.heatDetected:
        return Colors.orange;
      case BreedingEventType.aiDone:
        return Colors.blue;
      case BreedingEventType.pregnancyConfirmed:
        return Colors.purple;
      case BreedingEventType.calved:
        return Colors.green;
    }
  }

  IconData _eventIcon(BreedingEventType type) {
    switch (type) {
      case BreedingEventType.heatDetected:
        return Icons.local_fire_department;
      case BreedingEventType.aiDone:
        return Icons.science;
      case BreedingEventType.pregnancyConfirmed:
        return Icons.favorite;
      case BreedingEventType.calved:
        return Icons.child_friendly;
    }
  }

  String _formatDate(String isoDate, DateFormat fmt) {
    try {
      return fmt.format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }
}
