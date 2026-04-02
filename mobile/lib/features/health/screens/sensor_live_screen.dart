import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/core/extensions.dart';

/// Live sensor data view for a specific cattle.
/// Shows real-time vitals (temperature, heart rate, activity, battery)
/// with auto-refresh and visual alert indicators.
class SensorLiveScreen extends ConsumerStatefulWidget {
  final String cattleId;
  final String? cattleName;

  const SensorLiveScreen({
    super.key,
    required this.cattleId,
    this.cattleName,
  });

  @override
  ConsumerState<SensorLiveScreen> createState() => _SensorLiveScreenState();
}

class _SensorLiveScreenState extends ConsumerState<SensorLiveScreen> {
  Timer? _refreshTimer;
  Map<String, dynamic>? _latestReading;
  Map<String, dynamic>? _stats;
  List<dynamic> _alerts = [];
  List<dynamic> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchAll(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    try {
      setState(() => _loading = _latestReading == null);

      final api = ref.read(apiClientProvider);
      final results = await Future.wait([
        api.get('/api/v1/cattle/${widget.cattleId}/sensors/latest'),
        api.get('/api/v1/cattle/${widget.cattleId}/sensors/stats?hours=24'),
        api.get('/api/v1/cattle/${widget.cattleId}/health-dashboard'),
        api.get('/api/v1/cattle/${widget.cattleId}/sensors?hours=6'),
      ]);

      if (!mounted) return;

      setState(() {
        _latestReading = results[0].data['data'];
        _stats = results[1].data['data'];
        final dashboard = results[2].data['data'] as Map<String, dynamic>?;
        _alerts = (dashboard?['alerts'] as List?) ?? [];
        _history = (results[3].data['data'] as List?) ?? [];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cattleName ?? 'Sensor Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_latestReading == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No sensor data yet',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start the mock simulator to see live data',
              style: context.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // -- Active alerts --
          if (_alerts.isNotEmpty) ...[
            _AlertBanner(alerts: _alerts),
            const SizedBox(height: 16),
          ],

          // -- Current vitals --
          Text(
            'Current Vitals',
            style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _VitalsGrid(reading: _latestReading!),
          const SizedBox(height: 8),
          Text(
            'Last updated: ${_latestReading!['time'] ?? 'N/A'}',
            style: context.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // -- 24h stats --
          if (_stats != null) ...[
            Text(
              '24-Hour Statistics',
              style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _StatsCard(stats: _stats!),
            const SizedBox(height: 24),
          ],

          // -- Recent readings --
          Text(
            'Recent Readings (6h)',
            style: context.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No readings in the last 6 hours'),
              ),
            )
          else
            ..._history.take(20).map((r) => _ReadingTile(reading: r)),
        ],
      ),
    );
  }
}

// -- Alert banner at the top --
class _AlertBanner extends StatelessWidget {
  final List<dynamic> alerts;
  const _AlertBanner({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${alerts.length} Active Alert${alerts.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...alerts.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${a['message']}',
                style: TextStyle(fontSize: 13, color: Colors.red.shade900),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// -- 2x2 grid of current vitals --
class _VitalsGrid extends StatelessWidget {
  final Map<String, dynamic> reading;
  const _VitalsGrid({required this.reading});

  @override
  Widget build(BuildContext context) {
    final temp = reading['temperature'];
    final hr = reading['heart_rate'];
    final activity = reading['activity_level'];
    final battery = reading['battery_pct'];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        _VitalCard(
          icon: Icons.thermostat,
          label: 'Temperature',
          value: temp != null ? '${temp.toStringAsFixed(1)}' : '--',
          unit: '\u00B0C',
          color: temp != null && temp > 39.5 ? Colors.red : Colors.green,
          isAlert: temp != null && temp > 39.5,
        ),
        _VitalCard(
          icon: Icons.monitor_heart,
          label: 'Heart Rate',
          value: hr != null ? '$hr' : '--',
          unit: 'bpm',
          color: hr != null && hr > 80 ? Colors.orange : Colors.green,
          isAlert: hr != null && hr > 80,
        ),
        _VitalCard(
          icon: Icons.directions_walk,
          label: 'Activity',
          value: activity != null ? '${activity.toStringAsFixed(0)}' : '--',
          unit: '/100',
          color: Colors.blue,
          isAlert: false,
        ),
        _VitalCard(
          icon: Icons.battery_std,
          label: 'Battery',
          value: battery != null ? '$battery' : '--',
          unit: '%',
          color: battery != null && battery < 15 ? Colors.red : Colors.green,
          isAlert: battery != null && battery < 15,
        ),
      ],
    );
  }
}

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isAlert;

  const _VitalCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.isAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isAlert ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAlert ? color : Colors.grey.shade300,
          width: isAlert ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- 24h stats card --
class _StatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatRow('Avg Temperature', _fmt(stats['avg_temperature']), '\u00B0C'),
            _StatRow('Min / Max Temp', '${_fmt(stats['min_temperature'])} / ${_fmt(stats['max_temperature'])}', '\u00B0C'),
            _StatRow('Avg Heart Rate', _fmt(stats['avg_heart_rate']), 'bpm'),
            _StatRow('Avg Activity', _fmt(stats['avg_activity']), '/100'),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic v) => v != null ? v.toStringAsFixed(1) : '--';
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _StatRow(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.textTheme.bodySmall),
          Text(
            '$value $unit',
            style: context.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// -- Individual reading tile --
class _ReadingTile extends StatelessWidget {
  final dynamic reading;
  const _ReadingTile({required this.reading});

  @override
  Widget build(BuildContext context) {
    final temp = reading['temperature'];
    final hr = reading['heart_rate'];
    final activity = reading['activity_level'];
    final time = reading['time'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          temp != null && temp > 39.5 ? Icons.warning : Icons.check_circle,
          color: temp != null && temp > 39.5 ? Colors.red : Colors.green,
          size: 20,
        ),
        title: Text(
          'T: ${temp ?? "--"}\u00B0C  |  HR: ${hr ?? "--"}bpm  |  Act: ${activity ?? "--"}',
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
        subtitle: Text(
          '$time',
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}
