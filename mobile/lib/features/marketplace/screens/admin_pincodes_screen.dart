import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/store_theme.dart';
import '../../auth/providers/auth_provider.dart';

final adminPincodesSearchProvider = StateProvider<String>((ref) => '');

final adminDeliveryPolicyProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response =
      await ref.watch(dioProvider).get('/marketplace/admin/delivery-policy');
  return Map<String, dynamic>.from(response.data['data'] as Map);
});

final adminPincodesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final search = ref.watch(adminPincodesSearchProvider).trim();
  final response = await ref.watch(dioProvider).get(
    '/marketplace/admin/pincodes',
    queryParameters: {'per_page': 100, if (search.isNotEmpty) 'query': search},
  );
  return (response.data['data'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
});

class AdminPincodesScreen extends ConsumerStatefulWidget {
  const AdminPincodesScreen({super.key});

  @override
  ConsumerState<AdminPincodesScreen> createState() =>
      _AdminPincodesScreenState();
}

class _AdminPincodesScreenState extends ConsumerState<AdminPincodesScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _error(Object error) {
    if (!mounted) return;
    final detail = error is DioException
        ? error.response?.data?.toString() ?? error.message
        : error.toString();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not save: $detail')));
  }

  Future<void> _editDefault(Map<String, dynamic> policy) async {
    var cod = policy['cod_default_enabled'] == true;
    final fee = TextEditingController(
      text: ((policy['delivery_fee_minor'] as num? ?? 0) / 100)
          .toStringAsFixed(2),
    );
    final freeAbove = TextEditingController(
      text: policy['free_delivery_above_minor'] == null
          ? ''
          : ((policy['free_delivery_above_minor'] as num) / 100)
              .toStringAsFixed(2),
    );
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
          builder: (dialog, setDialog) => AlertDialog(
                title: const Text('Nationwide delivery default'),
                content: SizedBox(
                  width: 430,
                  child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SwitchListTile(
                      title: const Text('Cash on delivery across India'),
                      subtitle:
                          const Text('PIN exceptions below take priority.'),
                      value: cod,
                      onChanged: (value) => setDialog(() => cod = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fee,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Default delivery fee (₹)',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: freeAbove,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Free delivery above cart subtotal (₹)',
                          hintText: 'Blank = no free-delivery threshold',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        'Online payment remains unavailable until the payment gateway is integrated.',
                        style: TextStyle(color: storeMuted)),
                  ])),
                ),
                actions: [
                  TextButton(
                      onPressed: busy ? null : () => Navigator.pop(dialog),
                      child: const Text('Cancel')),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final amount = double.tryParse(fee.text.trim());
                            if (amount == null || amount < 0 || amount > 1000) {
                              _error('Enter a delivery fee from ₹0 to ₹1,000.');
                              return;
                            }
                            final threshold = freeAbove.text.trim().isEmpty
                                ? null
                                : double.tryParse(freeAbove.text.trim());
                            if (freeAbove.text.trim().isNotEmpty &&
                                (threshold == null || threshold < 0)) {
                              _error('Enter a valid free-delivery threshold.');
                              return;
                            }
                            setDialog(() => busy = true);
                            try {
                              await ref.read(dioProvider).put(
                                  '/marketplace/admin/delivery-policy',
                                  data: {
                                    'cod_default_enabled': cod,
                                    'delivery_fee_minor':
                                        (amount * 100).round(),
                                    'free_delivery_above_minor': threshold == null
                                        ? null
                                        : (threshold * 100).round(),
                                    'prepaid_default_enabled':
                                        policy['prepaid_default_enabled'] ==
                                            true,
                                  });
                              ref.invalidate(adminDeliveryPolicyProvider);
                              if (dialog.mounted) Navigator.pop(dialog);
                            } catch (error) {
                              _error(error);
                              if (dialog.mounted) setDialog(() => busy = false);
                            }
                          },
                    child: Text(busy ? 'Saving…' : 'Save default'),
                  ),
                ],
              )),
    );
    fee.dispose();
    freeAbove.dispose();
  }

  Future<void> _editPin([Map<String, dynamic>? rule]) async {
    final pin = TextEditingController(text: rule?['pincode']?.toString() ?? '');
    final city = TextEditingController(text: rule?['city']?.toString() ?? '');
    final state = TextEditingController(text: rule?['state']?.toString() ?? '');
    final fee = TextEditingController(
        text: rule?['delivery_fee_minor'] == null
            ? ''
            : ((rule!['delivery_fee_minor'] as num) / 100).toStringAsFixed(2));
    var cod = rule?['cod_enabled'] == true;
    var prepaid = rule?['prepaid_enabled'] == true;
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
          builder: (dialog, setDialog) => AlertDialog(
                title: Text(
                    rule == null ? 'Add PIN exception' : 'Edit PIN exception'),
                content: SizedBox(
                    width: 430,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: pin,
                          enabled: rule == null,
                          maxLength: 6,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Six-digit PIN',
                              border: OutlineInputBorder())),
                      TextField(
                          controller: city,
                          decoration: const InputDecoration(
                              labelText: 'City (optional)',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(
                          controller: state,
                          decoration: const InputDecoration(
                              labelText: 'State (optional)',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      SwitchListTile(
                          title: const Text('COD allowed'),
                          value: cod,
                          onChanged: (v) => setDialog(() => cod = v)),
                      SwitchListTile(
                          title: const Text('Prepaid policy allowed'),
                          subtitle:
                              const Text('Does not activate online payment.'),
                          value: prepaid,
                          onChanged: (v) => setDialog(() => prepaid = v)),
                      TextField(
                          controller: fee,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText:
                                  'Fee override (₹, blank = national default)',
                              border: OutlineInputBorder())),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: busy ? null : () => Navigator.pop(dialog),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              final code = pin.text.trim();
                              final amount = fee.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(fee.text.trim());
                              if (!RegExp(r'^[1-8][0-9]{5}$').hasMatch(code) ||
                                  (fee.text.trim().isNotEmpty &&
                                      (amount == null ||
                                          amount < 0 ||
                                          amount > 1000))) {
                                _error(
                                    'Enter an Indian PIN format and a fee from ₹0 to ₹1,000.');
                                return;
                              }
                              setDialog(() => busy = true);
                              final body = {
                                if (rule == null) 'pincode': code,
                                'city': city.text.trim(),
                                'state': state.text.trim(),
                                'cod_enabled': cod,
                                'prepaid_enabled': prepaid,
                                'delivery_fee_minor': amount == null
                                    ? null
                                    : (amount * 100).round(),
                              };
                              try {
                                final dio = ref.read(dioProvider);
                                if (rule == null) {
                                  await dio.post('/marketplace/admin/pincodes',
                                      data: body);
                                } else {
                                  await dio.put(
                                      '/marketplace/admin/pincodes/$code',
                                      data: body);
                                }
                                ref.invalidate(adminPincodesListProvider);
                                if (dialog.mounted) Navigator.pop(dialog);
                              } catch (error) {
                                _error(error);
                                if (dialog.mounted) {
                                  setDialog(() => busy = false);
                                }
                              }
                            },
                      child: Text(busy ? 'Saving…' : 'Save exception')),
                ],
              )),
    );
    pin.dispose();
    city.dispose();
    state.dispose();
    fee.dispose();
  }

  Future<void> _delete(String pin) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: Text('Remove $pin exception?'),
              content: const Text(
                  'This PIN will use the nationwide default after removal.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Remove')),
              ],
            ));
    if (yes != true) return;
    try {
      await ref.read(dioProvider).delete('/marketplace/admin/pincodes/$pin');
      ref.invalidate(adminPincodesListProvider);
    } catch (error) {
      _error(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ref.watch(adminDeliveryPolicyProvider);
    final pins = ref.watch(adminPincodesListProvider);
    return Scaffold(
      appBar: AppBar(
          title: const Text('Delivery and payment by PIN'),
          backgroundColor: storeCream,
          foregroundColor: storeGreen),
      body: ColoredBox(
          color: storeCream,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            policy.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => ListTile(
                  title: const Text('Could not load nationwide policy'),
                  subtitle: Text('$e'),
                  trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          ref.invalidate(adminDeliveryPolicyProvider))),
              data: (value) => Card(
                  child: ListTile(
                title: Text(value['cod_default_enabled'] == true
                    ? 'Nationwide COD: on'
                    : 'Nationwide COD: off'),
                subtitle: Text(
                    'Default delivery fee ₹${((value['delivery_fee_minor'] as num? ?? 0) / 100).toStringAsFixed(2)}. '
                    '${value['free_delivery_above_minor'] == null ? '' : 'Free above ₹${((value['free_delivery_above_minor'] as num) / 100).toStringAsFixed(2)}. '}'
                    'Online payment is unavailable. PIN exceptions below take priority.'),
                trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editDefault(value)),
              )),
            ),
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(
                  child: Text('PIN exceptions',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              FilledButton.icon(
                  onPressed: () => _editPin(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add exception')),
            ]),
            const SizedBox(height: 8),
            const Text(
                'Only exceptions are listed. A six-digit format does not prove that a PIN exists or a courier serves it.',
                style: TextStyle(color: storeMuted)),
            const SizedBox(height: 12),
            TextField(
                controller: _search,
                onChanged: (v) =>
                    ref.read(adminPincodesSearchProvider.notifier).state = v,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search PIN, city or state',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            pins.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListTile(
                  title: const Text('Could not load PIN exceptions'),
                  subtitle: Text('$e'),
                  trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          ref.invalidate(adminPincodesListProvider))),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matching PIN exceptions.'))
                  : Column(children: [
                      for (final item in items)
                        Card(
                            child: ListTile(
                          title: Text(item['pincode'].toString()),
                          subtitle: Text(
                              '${item['city'] ?? ''} ${item['state'] ?? ''}\n'
                              'COD ${item['cod_enabled'] == true ? 'on' : 'off'} · '
                              'Prepaid policy ${item['prepaid_enabled'] == true ? 'on' : 'off'} · '
                              'Fee ${item['delivery_fee_minor'] == null ? 'default' : '₹${((item['delivery_fee_minor'] as num) / 100).toStringAsFixed(2)}'}'),
                          isThreeLine: true,
                          trailing: Wrap(children: [
                            IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editPin(item)),
                            IconButton(
                                tooltip: 'Remove',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    _delete(item['pincode'].toString())),
                          ]),
                        ))
                    ]),
            ),
          ])),
    );
  }
}
