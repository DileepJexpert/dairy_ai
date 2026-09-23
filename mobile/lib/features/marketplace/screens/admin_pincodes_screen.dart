import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/store_theme.dart';
import '../../auth/providers/auth_provider.dart';

final adminPincodesSearchProvider = StateProvider<String>((ref) => '');

final adminPincodesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(adminPincodesSearchProvider);
  final dio = ref.watch(dioProvider);

  try {
    final res = await dio.get(
      '/admin/pincodes',
      queryParameters: {
        if (query.trim().isNotEmpty) 'query': query.trim(),
        'per_page': 100,
      },
    );
    if (res.statusCode == 200 && res.data is Map) {
      final list = res.data['data'] as List? ?? [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {}
  return [];
});

/// Admin Management screen for master serviceable delivery PIN codes
class AdminPincodesScreen extends ConsumerStatefulWidget {
  const AdminPincodesScreen({super.key});

  @override
  ConsumerState<AdminPincodesScreen> createState() => _AdminPincodesScreenState();
}

class _AdminPincodesScreenState extends ConsumerState<AdminPincodesScreen> {
  final _searchCtrl = TextEditingController();

  Future<void> _showAddEditDialog([Map<String, dynamic>? item]) async {
    final isEdit = item != null;
    final pinCtrl = TextEditingController(text: item?['pincode'] ?? '');
    final cityCtrl = TextEditingController(text: item?['city'] ?? '');
    final stateCtrl = TextEditingController(text: item?['state'] ?? 'Delhi');
    final minDaysCtrl = TextEditingController(
        text: (item?['delivery_days_min'] ?? 1).toString());
    final maxDaysCtrl = TextEditingController(
        text: (item?['delivery_days_max'] ?? 2).toString());
    final noteCtrl = TextEditingController(text: item?['delivery_message'] ?? '');
    var express = item?['express_available'] ?? true;
    var saving = false;
    var lookingUp = false;
    String? lookupStatus;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit PIN Code' : 'Add Serviceable PIN Code'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinCtrl,
                    enabled: !isEdit,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    onChanged: isEdit
                        ? null
                        : (val) async {
                            final clean = val.trim();
                            if (clean.length == 6) {
                              setDialogState(() {
                                lookingUp = true;
                                lookupStatus = 'Fetching location from India Post…';
                              });
                              try {
                                final dio = ref.read(dioProvider);
                                final res = await dio.get(
                                  '/marketplace/pincode/lookup',
                                  queryParameters: {'pincode': clean},
                                );
                                if (res.data is Map) {
                                  final data = res.data as Map;
                                  final fetchedCity = data['city']?.toString() ?? '';
                                  final fetchedState = data['state']?.toString() ?? '';
                                  if (fetchedCity.isNotEmpty) cityCtrl.text = fetchedCity;
                                  if (fetchedState.isNotEmpty) stateCtrl.text = fetchedState;
                                  setDialogState(() {
                                    lookupStatus = '✓ Auto-filled from India Post';
                                  });
                                }
                              } catch (_) {
                                setDialogState(() {
                                  lookupStatus = null;
                                });
                              } finally {
                                setDialogState(() => lookingUp = false);
                              }
                            } else {
                              setDialogState(() => lookupStatus = null);
                            }
                          },
                    decoration: InputDecoration(
                      labelText: '6-Digit PIN Code',
                      hintText: 'e.g. 201305',
                      border: const OutlineInputBorder(),
                      helperText: lookupStatus,
                      helperStyle: TextStyle(
                        color: lookupStatus != null && lookupStatus!.startsWith('✓')
                            ? storeGreen
                            : storeMuted,
                        fontSize: 11,
                      ),
                      suffixIcon: lookingUp
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'City / Hub Name',
                      hintText: 'e.g. New Delhi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      hintText: 'e.g. Delhi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minDaysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min Days',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: maxDaysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Days',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Note (Optional)',
                      hintText: 'e.g. Next-Day Morning Delivery by 8 AM',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Express Delivery Available'),
                    subtitle: const Text('Next-day cold chain delivery badge'),
                    value: express,
                    activeThumbColor: storeGreen,
                    activeTrackColor: storeGreen.withValues(alpha: 0.5),
                    onChanged: (val) => setDialogState(() => express = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: storeGreen),
              onPressed: saving
                  ? null
                  : () async {
                      final pin = pinCtrl.text.trim();
                      final city = cityCtrl.text.trim();
                      final st = stateCtrl.text.trim();
                      if (pin.length != 6 || city.isEmpty || st.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all required fields.')),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      final dio = ref.read(dioProvider);
                      final data = {
                        'pincode': pin,
                        'city': city,
                        'state': st,
                        'delivery_days_min': int.tryParse(minDaysCtrl.text) ?? 1,
                        'delivery_days_max': int.tryParse(maxDaysCtrl.text) ?? 2,
                        'express_available': express,
                        'delivery_message': noteCtrl.text.trim(),
                        'is_serviceable': true,
                      };

                      try {
                        if (isEdit) {
                          await dio.put('/admin/pincodes/$pin', data: data);
                        } else {
                          await dio.post('/admin/pincodes', data: data);
                        }
                        ref.invalidate(adminPincodesListProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: storeGreen,
                              content: Text('PIN code $pin saved successfully.'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: storeError, content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save PIN'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBulkImportDialog() async {
    final bulkCtrl = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Bulk Import Delivery PIN Codes'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Paste PIN codes, one per line with format:\nPINCODE, City, State, MinDays, MaxDays\n\nExample:\n110001, New Delhi, Delhi, 1, 1\n201301, Noida, Uttar Pradesh, 1, 2\n560001, Bengaluru, Karnataka, 2, 3',
                    style: TextStyle(fontSize: 12, color: storeMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bulkCtrl,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '110001, New Delhi, Delhi, 1, 1\n201301, Noida, UP, 1, 2',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: storeGreen),
              onPressed: saving
                  ? null
                  : () async {
                      final raw = bulkCtrl.text.trim();
                      if (raw.isEmpty) return;

                      final lines = raw.split('\n');
                      final items = <Map<String, dynamic>>[];

                      for (final line in lines) {
                        final parts = line.split(',').map((s) => s.trim()).toList();
                        if (parts.isNotEmpty && parts[0].length == 6) {
                          items.add({
                            'pincode': parts[0],
                            'city': parts.length > 1 ? parts[1] : 'City',
                            'state': parts.length > 2 ? parts[2] : 'State',
                            'delivery_days_min': parts.length > 3 ? (int.tryParse(parts[3]) ?? 1) : 1,
                            'delivery_days_max': parts.length > 4 ? (int.tryParse(parts[4]) ?? 2) : 2,
                            'express_available': true,
                          });
                        }
                      }

                      if (items.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No valid 6-digit PIN codes found.')),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        final dio = ref.read(dioProvider);
                        await dio.post('/admin/pincodes/bulk', data: {'pincodes': items});
                        ref.invalidate(adminPincodesListProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: storeGreen,
                              content: Text('Successfully imported ${items.length} PIN codes.'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(backgroundColor: storeError, content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'Importing…' : 'Import All'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePincode(String pin, bool active) async {
    final dio = ref.read(dioProvider);
    try {
      await dio.put('/admin/pincodes/$pin', data: {'is_serviceable': active});
      ref.invalidate(adminPincodesListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: storeError, content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _deletePincode(String pin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete PIN Code?'),
        content: Text('Are you sure you want to remove $pin from delivery zones?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dio = ref.read(dioProvider);
        await dio.delete('/admin/pincodes/$pin');
        ref.invalidate(adminPincodesListProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: storeGreen, content: Text('PIN $pin removed.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: storeError, content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(adminPincodesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery PIN Codes Master Table',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: storeCream,
        foregroundColor: storeGreen,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Bulk Import'),
            onPressed: _showBulkImportDialog,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            icon: const Icon(Icons.add),
            label: const Text('Add PIN Code'),
            onPressed: () => _showAddEditDialog(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        color: storeCream,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: storeWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: storeBorder),
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by PIN code, City, or State…',
                  prefixIcon: const Icon(Icons.search, color: storeGreen),
                  border: InputBorder.none,
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(adminPincodesSearchProvider.notifier).state = '';
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (val) =>
                    ref.read(adminPincodesSearchProvider.notifier).state = val,
              ),
            ),
            const SizedBox(height: 16),

            // List of PIN Codes
            Expanded(
              child: listAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: storeGreen),
                ),
                error: (e, _) => Center(child: Text('Error loading PIN codes: $e')),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off_outlined,
                              size: 48, color: storeMuted),
                          const SizedBox(height: 12),
                          const Text('No PIN codes found matching search.',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: storeGreen),
                            onPressed: () => _showAddEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Delivery Hub'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final pin = item['pincode'] as String;
                      final city = item['city'] as String;
                      final state = item['state'] as String;
                      final isServiceable = item['is_serviceable'] == true;
                      final minDays = item['delivery_days_min'] ?? 1;
                      final maxDays = item['delivery_days_max'] ?? 2;
                      final express = item['express_available'] == true;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isServiceable ? storeBorder : storeError.withValues(alpha: 0.3)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isServiceable ? const Color(0xfff0fdf4) : const Color(0xfffef2f2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isServiceable ? const Color(0xff86efac) : const Color(0xfffca5a5),
                                  ),
                                ),
                                child: Text(
                                  pin,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isServiceable ? storeSuccess : storeError,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$city, $state',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Timeline: $minDays-$maxDays business days',
                                          style: const TextStyle(fontSize: 12, color: storeMuted),
                                        ),
                                        if (express) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: storeAmber.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.bolt, size: 12, color: storeOrange),
                                                SizedBox(width: 2),
                                                Text('Next-Day Express',
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: storeOrange)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: isServiceable,
                                    activeThumbColor: storeGreen,
                                    activeTrackColor: storeGreen.withValues(alpha: 0.5),
                                    onChanged: (val) => _togglePincode(pin, val),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: storeGreen),
                                    onPressed: () => _showAddEditDialog(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: storeError),
                                    onPressed: () => _deletePincode(pin),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
