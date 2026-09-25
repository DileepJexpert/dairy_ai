import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../providers/pincode_provider.dart';
import 'store_design.dart';

/// Shows an interactive Amazon-style PIN code selector and live delivery check modal.
Future<void> showPincodeSelectorDialog(
    BuildContext context, WidgetRef ref) async {
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
  ConsumerState<_PincodeModalContent> createState() =>
      _PincodeModalContentState();
}

class _PincodeModalContentState extends ConsumerState<_PincodeModalContent> {
  String? _queriedPin;
  bool _checking = false;
  bool _locating = false;
  PincodeDeliveryInfo? _checkedInfo;
  int _checkVersion = 0;

  @override
  void initState() {
    super.initState();
    _checkPincode(widget.initialPin);
  }

  Future<void> _checkPincode(String pin) async {
    final clean = pin.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(clean)) return;
    final version = ++_checkVersion;

    setState(() {
      _checking = true;
      _queriedPin = clean;
      _checkedInfo = null;
    });

    try {
      ref.invalidate(deliveryCheckProvider(clean));
      final info = await ref.read(deliveryCheckProvider(clean).future);
      if (mounted &&
          version == _checkVersion &&
          widget.controller.text == clean) {
        setState(() {
          _checkedInfo = info;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted && version == _checkVersion) {
        setState(() {
          _checkedInfo = PincodeDeliveryInfo(
            isServiceable: false,
            pincode: clean,
            message:
                'Delivery availability could not be verified. Please try again.',
          );
          _checking = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/marketplace/pincode/auto-detect');
      if (res.data is Map) {
        final data = res.data as Map;
        final detectedPin = data['pincode']?.toString() ?? '';
        if (detectedPin.length == 6) {
          _checkVersion++;
          widget.controller.text = detectedPin;
          final svc = data['serviceability'];
          if (svc is Map) {
            final info =
                PincodeDeliveryInfo.fromJson(Map<String, dynamic>.from(svc));
            if (mounted) {
              setState(() {
                _checkedInfo = info;
                _queriedPin = detectedPin;
                _checking = false;
              });
            }
          } else {
            await _checkPincode(detectedPin);
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not auto-detect location. Please enter your PIN code.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _applyPincode(PincodeDeliveryInfo info) {
    ref.read(currentPincodeProvider.notifier).state = info.pincode;
    ref.read(selectedDeliveryLocationProvider.notifier).state =
        info.locationLabel;
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
              const Icon(Icons.location_on_outlined,
                  color: storeGreen, size: 24),
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
          const SizedBox(height: 12),

          // 📍 Use current location button
          InkWell(
            onTap: _locating ? null : _useCurrentLocation,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xffedf7f1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: storeGreen.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_locating)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: storeGreen),
                    )
                  else
                    const Icon(Icons.my_location, size: 16, color: storeGreen),
                  const SizedBox(width: 8),
                  Text(
                    _locating
                        ? 'Detecting your location…'
                        : 'Use my current location',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: storeGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

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
                    prefixIcon: const Icon(Icons.pin_drop_outlined,
                        size: 18, color: storeGreen),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: storeBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: storeGreen, width: 1.5),
                    ),
                  ),
                  onSubmitted: (val) => _checkPincode(val),
                  onChanged: (val) {
                    _checkVersion++;
                    setState(() {
                      _checkedInfo = null;
                      _queriedPin = null;
                      _checking = false;
                    });
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
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: storeGreen),
                        )
                      : const Text('Check',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                  avatar: const Icon(Icons.location_city,
                      size: 14, color: storeGreen),
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
                    _checkVersion++;
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
