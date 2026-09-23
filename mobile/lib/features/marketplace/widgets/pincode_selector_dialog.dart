import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pincode_provider.dart';
import 'store_design.dart';

/// Shows an interactive Amazon-style PIN code selector and live delivery check modal.
Future<void> showPincodeSelectorDialog(BuildContext context, WidgetRef ref) async {
  final currentPin = ref.read(currentPincodeProvider);
  final controller = TextEditingController(text: currentPin);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: storeWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PincodeModalContent(
      initialPin: currentPin,
      controller: controller,
    ),
  );
}

class _PincodeModalContent extends ConsumerStatefulWidget {
  const _PincodeModalContent({
    required this.initialPin,
    required this.controller,
  });

  final String initialPin;
  final TextEditingController controller;

  @override
  ConsumerState<_PincodeModalContent> createState() => _PincodeModalContentState();
}

class _PincodeModalContentState extends ConsumerState<_PincodeModalContent> {
  String? _queriedPin;
  bool _checking = false;
  PincodeDeliveryInfo? _checkedInfo;

  @override
  void initState() {
    super.initState();
    _checkPincode(widget.initialPin);
  }

  Future<void> _checkPincode(String pin) async {
    final clean = pin.trim();
    if (clean.length != 6) return;

    setState(() {
      _checking = true;
      _queriedPin = clean;
    });

    try {
      final info = await ref.read(deliveryCheckProvider(clean).future);
      if (mounted) {
        setState(() {
          _checkedInfo = info;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  void _applyPincode(PincodeDeliveryInfo info) {
    ref.read(currentPincodeProvider.notifier).state = info.pincode;
    ref.read(selectedDeliveryLocationProvider.notifier).state = info.locationLabel;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: storeGreen,
        content: Text(
          'Delivery location set to ${info.locationLabel}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: storeGreen, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Enter a delivery PIN code',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: storeGreen,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Check delivery availability, expected delivery dates, and shipping options.',
            style: TextStyle(fontSize: 12.5, color: storeMuted),
          ),
          const SizedBox(height: 18),

          // Pincode Input Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter 6-digit PIN code',
                    hintStyle: const TextStyle(fontSize: 13, color: storeMuted),
                    prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18, color: storeGreen),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: storeBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: storeGreen, width: 1.5),
                    ),
                  ),
                  onSubmitted: (val) => _checkPincode(val),
                  onChanged: (val) {
                    if (val.trim().length == 6) {
                      _checkPincode(val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: storeAmber,
                    foregroundColor: storeGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  onPressed: _checking
                      ? null
                      : () => _checkPincode(widget.controller.text),
                  child: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: storeGreen),
                        )
                      : const Text('Check', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          // Live Result Box
          if (_checkedInfo != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _checkedInfo!.isServiceable
                    ? const Color(0xfff0fbf4)
                    : const Color(0xfffef2f2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _checkedInfo!.isServiceable
                      ? const Color(0xff86efac)
                      : const Color(0xfffca5a5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _checkedInfo!.isServiceable
                            ? Icons.check_circle
                            : Icons.error_outline,
                        color: _checkedInfo!.isServiceable
                            ? storeSuccess
                            : storeError,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _checkedInfo!.isServiceable
                              ? 'Deliverable to ${_checkedInfo!.locationLabel}'
                              : 'Currently Unavailable for PIN ${_checkedInfo!.pincode}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: _checkedInfo!.isServiceable
                                ? storeSuccess
                                : storeError,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_checkedInfo!.isServiceable &&
                      _checkedInfo!.expectedDeliveryText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Expected Delivery: ${_checkedInfo!.expectedDeliveryText}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff0f1111),
                      ),
                    ),
                  ],
                  if (_checkedInfo!.message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _checkedInfo!.message!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _checkedInfo!.isServiceable
                            ? const Color(0xff166534)
                            : const Color(0xff991b1b),
                      ),
                    ),
                  ],
                  if (_checkedInfo!.isServiceable) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: storeGreen,
                          foregroundColor: storeWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => _applyPincode(_checkedInfo!),
                        child: const Text('Deliver to this Address',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          const Text(
            'Or select a major delivery hub:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hub in [
                {'pin': '110001', 'name': 'New Delhi 110001'},
                {'pin': '201301', 'name': 'Noida 201301'},
                {'pin': '122002', 'name': 'Gurugram 122002'},
                {'pin': '226010', 'name': 'Lucknow 226010'},
                {'pin': '560001', 'name': 'Bengaluru 560001'},
                {'pin': '400001', 'name': 'Mumbai 400001'},
              ])
                ActionChip(
                  avatar: const Icon(Icons.location_city, size: 14, color: storeGreen),
                  label: Text(hub['name']!),
                  backgroundColor: _queriedPin == hub['pin']
                      ? storeAmber
                      : const Color(0xfff3f4f6),
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _queriedPin == hub['pin']
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: const Color(0xff1f2937),
                  ),
                  onPressed: () {
                    widget.controller.text = hub['pin']!;
                    _checkPincode(hub['pin']!);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
