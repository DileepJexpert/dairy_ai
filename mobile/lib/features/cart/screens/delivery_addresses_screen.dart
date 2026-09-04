import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/delivery_address.dart';
import '../providers/delivery_address_provider.dart';

class DeliveryAddressesScreen extends ConsumerWidget {
  const DeliveryAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(deliveryAddressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Add a delivery address to continue.'))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(deliveryAddressesProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, index) =>
                      _addressCard(context, ref, items[index]),
                ),
              ),
      ),
    );
  }

  Widget _addressCard(
          BuildContext context, WidgetRef ref, DeliveryAddress address) =>
      Card(
        child: ListTile(
          title: Row(children: [
            Expanded(child: Text(address.recipientName)),
            if (address.isDefault) const Chip(label: Text('Default')),
          ]),
          subtitle: Text('${address.summary}\n${address.phone}'),
          isThreeLine: true,
          onTap: address.isDefault
              ? null
              : () => ref
                  .read(deliveryAddressesProvider.notifier)
                  .makeDefault(address.id),
          trailing: IconButton(
            tooltip: 'Delete address',
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                ref.read(deliveryAddressesProvider.notifier).delete(address.id),
          ),
        ),
      );

  Future<void> _showAddressForm(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final fields = <String, TextEditingController>{
      for (final key in [
        'recipient_name',
        'phone',
        'address_line1',
        'village_or_city',
        'district',
        'state',
        'postal_code'
      ])
        key: TextEditingController(),
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('New delivery address',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final field in [
              ('recipient_name', 'Recipient name'),
              ('phone', 'Phone number'),
              ('address_line1', 'House / street'),
              ('village_or_city', 'Village or city'),
              ('district', 'District'),
              ('state', 'State'),
              ('postal_code', '6-digit postal code'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  controller: fields[field.$1],
                  keyboardType: field.$1 == 'phone' || field.$1 == 'postal_code'
                      ? TextInputType.phone
                      : TextInputType.text,
                  decoration: InputDecoration(
                      labelText: field.$2, border: const OutlineInputBorder()),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
              ),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (fields['postal_code']!.text.trim().length != 6) return;
                    await ref.read(deliveryAddressesProvider.notifier).create({
                      for (final entry in fields.entries)
                        entry.key: entry.value.text.trim(),
                    });
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  child: const Text('Save address'),
                )),
          ])),
        ),
      ),
    );
    for (final controller in fields.values) {
      controller.dispose();
    }
  }
}
