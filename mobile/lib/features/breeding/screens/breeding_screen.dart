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
        title: const Text('Breeding Tracker'),
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
              error: (e, _) => Text('Failed to load cattle: $e'),
            ),
          ),

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
              error: (e, _) => Center(child: Text('Error: $e')),
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
