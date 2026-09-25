import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

/// Postal lookup plus the bundled India state/district master for addresses.
class AddressLocationFields extends ConsumerStatefulWidget {
  const AddressLocationFields({
    super.key,
    required this.pin,
    required this.city,
    required this.stateName,
    required this.district,
  });

  final TextEditingController pin;
  final TextEditingController city;
  final TextEditingController stateName;
  final TextEditingController district;

  @override
  ConsumerState<AddressLocationFields> createState() =>
      _AddressLocationFieldsState();
}

class _AddressLocationFieldsState extends ConsumerState<AddressLocationFields> {
  Map<String, List<String>>? _locations;
  String? _masterError;
  String? _lookupMessage;
  bool _lookingUp = false;
  bool _otherState = false;
  bool _otherDistrict = false;
  int _lookupVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadMaster();
  }

  Future<void> _loadMaster() async {
    try {
      final response =
          await ref.read(dioProvider).get('/marketplace/locations');
      final data = Map<String, dynamic>.from(response.data as Map);
      final states = (data['states'] as List).cast<Map>();
      final locations = <String, List<String>>{
        for (final row in states)
          row['name'].toString():
              (row['districts'] as List).map((d) => d.toString()).toList(),
      };
      if (mounted) setState(() => _locations = locations);
    } catch (_) {
      if (mounted) {
        setState(() => _masterError =
            'State and district list could not be loaded. You can enter them manually.');
      }
    }
  }

  static String _key(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String? _matchingState(String value) {
    if (value.trim().isEmpty || _locations == null) return null;
    final normalized = _key(value);
    for (final state in _locations!.keys) {
      if (_key(state) == normalized ||
          (state == 'Delhi' && normalized == 'nctofdelhi')) {
        return state;
      }
    }
    return null;
  }

  String? _matchingDistrict(String state, String value) {
    if (value.trim().isEmpty) return null;
    for (final district in _locations?[state] ?? <String>[]) {
      if (_key(district) == _key(value)) return district;
    }
    return null;
  }

  Future<void> _lookupPin() async {
    final pin = widget.pin.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _lookupMessage = 'Enter a 6-digit PIN code first.');
      return;
    }
    final version = ++_lookupVersion;
    setState(() {
      _lookingUp = true;
      _lookupMessage = null;
    });
    try {
      final response = await ref.read(dioProvider).get(
          '/marketplace/pincode/lookup',
          queryParameters: {'pincode': pin});
      final result = Map<String, dynamic>.from(response.data as Map);
      if (!mounted || version != _lookupVersion || widget.pin.text != pin) {
        return;
      }
      setState(() {
        final city = result['city']?.toString().trim() ?? '';
        final state = result['state']?.toString().trim() ?? '';
        final district = result['district']?.toString().trim() ?? '';
        if (city.isNotEmpty) widget.city.text = city;
        widget.stateName.text = state;
        widget.district.text = district;
        _otherState = false;
        _otherDistrict = false;
        _lookupMessage = district.isEmpty
            ? 'City and state found. Select your district below.'
            : 'Postal details found. Delivery availability is checked at checkout.';
      });
    } catch (_) {
      if (mounted && version == _lookupVersion) {
        setState(() => _lookupMessage =
            'Postal details could not be found. Select your location manually.');
      }
    } finally {
      if (mounted && version == _lookupVersion) {
        setState(() => _lookingUp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = _locations;
    final stateMatch = _matchingState(widget.stateName.text);
    final stateChoice = _otherState ||
            (widget.stateName.text.trim().isNotEmpty && stateMatch == null)
        ? '__other'
        : stateMatch;
    final districts = locations?[stateMatch] ?? <String>[];
    final districtMatch = stateMatch == null
        ? null
        : _matchingDistrict(stateMatch, widget.district.text);
    final districtChoice = _otherDistrict ||
            (widget.district.text.trim().isNotEmpty && districtMatch == null)
        ? '__other'
        : districtMatch;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: const ValueKey('address-pincode'),
                controller: widget.pin,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: '6-digit PIN Code *',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())
                        ? null
                        : 'Enter a 6-digit PIN',
                onChanged: (value) {
                  _lookupVersion++;
                  setState(() {
                    widget.city.clear();
                    widget.stateName.clear();
                    widget.district.clear();
                    _otherState = false;
                    _otherDistrict = false;
                    _lookupMessage = null;
                    _lookingUp = false;
                  });
                  if (value.length == 6) {
                    _lookupPin();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _lookingUp ? null : _lookupPin,
              child: _lookingUp
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Find'),
            ),
          ],
        ),
        if (_lookupMessage != null) ...[
          const SizedBox(height: 6),
          Text(_lookupMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.city,
          decoration: const InputDecoration(
              labelText: 'Town / City *', border: OutlineInputBorder()),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Enter your town or city' : null,
        ),
        const SizedBox(height: 12),
        if (locations == null) ...[
          if (_masterError == null)
            const LinearProgressIndicator()
          else ...[
            Text(_masterError!,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            TextButton(onPressed: _loadMaster, child: const Text('Retry list')),
          ],
          const SizedBox(height: 8),
          _manualField(widget.stateName, 'State / Union Territory *'),
          const SizedBox(height: 12),
          _manualField(widget.district, 'District *'),
        ] else ...[
          DropdownButtonFormField<String>(
            key: ValueKey('address-state-$stateChoice'),
            initialValue: stateChoice,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'State / Union Territory *',
                border: OutlineInputBorder()),
            hint: const Text('Select state or union territory'),
            items: [
              for (final name in locations.keys)
                DropdownMenuItem(value: name, child: Text(name)),
              const DropdownMenuItem(
                  value: '__other', child: Text('Other — enter manually')),
            ],
            validator: (value) => value == null ? 'Select a state' : null,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _otherState = value == '__other';
                _otherDistrict = false;
                widget.stateName.text = _otherState ? '' : value;
                widget.city.clear();
                widget.district.clear();
              });
            },
          ),
          if (stateChoice == '__other') ...[
            const SizedBox(height: 10),
            _manualField(widget.stateName, 'Enter state / union territory *'),
          ],
          const SizedBox(height: 12),
          if (stateChoice == '__other')
            _manualField(widget.district, 'Enter district *')
          else
            DropdownButtonFormField<String>(
              key: ValueKey('address-district-$stateChoice-$districtChoice'),
              initialValue: districtChoice,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'District *', border: OutlineInputBorder()),
              hint: const Text('Select district'),
              items: [
                for (final name in districts)
                  DropdownMenuItem(value: name, child: Text(name)),
                const DropdownMenuItem(
                    value: '__other', child: Text('Other — enter manually')),
              ],
              validator: (value) => value == null ? 'Select a district' : null,
              onChanged: stateMatch == null
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _otherDistrict = value == '__other';
                        widget.district.text = _otherDistrict ? '' : value;
                      });
                    },
            ),
          if (stateChoice != '__other' && districtChoice == '__other') ...[
            const SizedBox(height: 10),
            _manualField(widget.district, 'Enter district *'),
          ],
        ],
      ],
    );
  }

  Widget _manualField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        validator: (value) => (value ?? '').trim().length < 2
            ? 'Enter a valid ${label.toLowerCase().replaceAll('*', '').trim()}'
            : null,
      );
}
