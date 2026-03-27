import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/feed/models/feed_models.dart';
import 'package:dairy_ai/features/feed/providers/feed_provider.dart';

class FeedPlanScreen extends ConsumerStatefulWidget {
  const FeedPlanScreen({super.key});

  @override
  ConsumerState<FeedPlanScreen> createState() => _FeedPlanScreenState();
}

class _FeedPlanScreenState extends ConsumerState<FeedPlanScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedCattleId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cattleAsync = ref.watch(cattleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Feed Optimizer'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Current Plan'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: Column(
        children: [
          // -- Cattle selector --
          Padding(
            padding: const EdgeInsets.all(16),
            child: cattleAsync.when(
              data: (cattleList) => DropdownButtonFormField<String>(
                value: _selectedCattleId,
                decoration: const InputDecoration(
                  labelText: 'Select Cattle',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
                items: cattleList
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.name} (${c.tagId})'),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedCattleId = value);
                },
                hint: const Text('Choose an animal'),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load cattle: $e'),
            ),
          ),

          // -- Tab content --
          Expanded(
            child: _selectedCattleId == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.grass, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Select cattle to view feed plan'),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _CurrentPlanTab(cattleId: _selectedCattleId!),
                      _PlanHistoryTab(cattleId: _selectedCattleId!),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Current Plan Tab
// ---------------------------------------------------------------------------
class _CurrentPlanTab extends ConsumerWidget {
  final String cattleId;
  const _CurrentPlanTab({required this.cattleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(feedPlanProvider(cattleId));
    final actionState = ref.watch(feedActionProvider);

    return planAsync.when(
      data: (plan) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -- Generate button --
              FilledButton.icon(
                onPressed: actionState.isGenerating
                    ? null
                    : () => _generatePlan(ref, cattleId, context),
                icon: actionState.isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(actionState.isGenerating
                    ? 'Generating...'
                    : 'Generate AI Plan'),
              ),

              if (actionState.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  actionState.error!,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ],

              const SizedBox(height: 16),

              if (plan == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.restaurant_menu,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No feed plan yet'),
                        SizedBox(height: 4),
                        Text(
                          'Tap "Generate AI Plan" to create an optimized feed plan.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                _FeedPlanCard(plan: plan),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _generatePlan(
      WidgetRef ref, String cattleId, BuildContext context) async {
    final plan =
        await ref.read(feedActionProvider.notifier).generateFeedPlan(cattleId);
    if (plan != null && context.mounted) {
      context.showSnackBar('AI feed plan generated successfully!');
    }
  }
}

// ---------------------------------------------------------------------------
// Feed Plan Card
// ---------------------------------------------------------------------------
class _FeedPlanCard extends StatelessWidget {
  final FeedPlan plan;
  const _FeedPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                if (plan.isAiGenerated)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 14,
                            color: context.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          'AI Optimized',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Text(
                  _formatDate(plan.createdAt),
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Cost summary
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Cost / Day',
                    value: currencyFormat.format(plan.costPerDay),
                    icon: Icons.currency_rupee,
                    color: context.colorScheme.primary,
                  ),
                ),
                if (plan.totalDmKg != null)
                  Expanded(
                    child: _MetricTile(
                      label: 'Total DM',
                      value: '${plan.totalDmKg!.toStringAsFixed(1)} kg',
                      icon: Icons.scale,
                      color: Colors.orange,
                    ),
                  ),
                if (plan.totalCpPct != null)
                  Expanded(
                    child: _MetricTile(
                      label: 'Crude Protein',
                      value: '${plan.totalCpPct!.toStringAsFixed(1)}%',
                      icon: Icons.science,
                      color: Colors.teal,
                    ),
                  ),
              ],
            ),

            // Savings badge
            if (plan.savingsVsCurrent != null && plan.savingsVsCurrent! > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.savings, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You save ${currencyFormat.format(plan.savingsVsCurrent)} per day with this plan!',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Text('Ingredients',
                style: context.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            // Ingredient table
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                  ),
                  children: const [
                    _TableHeader('Ingredient'),
                    _TableHeader('Qty (kg)'),
                    _TableHeader('Cost'),
                  ],
                ),
                ...plan.ingredients.map((ing) => TableRow(
                      children: [
                        _TableCell(ing.name),
                        _TableCell(ing.quantityKg.toStringAsFixed(1)),
                        _TableCell(currencyFormat.format(ing.totalCost)),
                      ],
                    )),
              ],
            ),

            if (plan.notes != null && plan.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Notes', style: context.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(plan.notes!, style: context.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return isoDate;
    }
  }
}

// ---------------------------------------------------------------------------
// Plan History Tab
// ---------------------------------------------------------------------------
class _PlanHistoryTab extends ConsumerWidget {
  final String cattleId;
  const _PlanHistoryTab({required this.cattleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(feedPlanHistoryProvider(cattleId));

    return historyAsync.when(
      data: (plans) {
        if (plans.isEmpty) {
          return const Center(child: Text('No past feed plans'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FeedPlanCard(plan: plan),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: context.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: context.textTheme.bodySmall),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(text,
          style: context.textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(text, style: context.textTheme.bodySmall),
    );
  }
}
