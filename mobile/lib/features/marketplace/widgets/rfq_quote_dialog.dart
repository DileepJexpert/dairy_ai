import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../admin/providers/admin_marketplace_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/product_models.dart';
import 'store_design.dart';

Future<void> showRFQQuoteDialog(
  BuildContext context, {
  Product? product,
  String? defaultTitle,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _RFQQuoteModal(
      product: product,
      defaultTitle: defaultTitle,
    ),
  );
}

class _RFQQuoteModal extends ConsumerStatefulWidget {
  const _RFQQuoteModal({this.product, this.defaultTitle});

  final Product? product;
  final String? defaultTitle;

  @override
  ConsumerState<_RFQQuoteModal> createState() => _RFQQuoteModalState();
}

class _RFQQuoteModalState extends ConsumerState<_RFQQuoteModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  final _qtyCtrl = TextEditingController(text: '1');
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _selectedUnit = 'Units';
  String _preferredContact = 'whatsapp';
  bool _submitting = false;
  Map<String, dynamic>? _successResponse;

  final List<String> _units = [
    'Units',
    'Sets',
    'Bags (50 kg)',
    'Tonnes (MT)',
    'Liters',
    'Boxes'
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: widget.product?.title ?? widget.defaultTitle ?? '',
    );

    final user = ref.read(currentUserProvider);
    if (user != null) {
      _nameCtrl.text = user.name ?? '';
      _phoneCtrl.text = user.phone;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _qtyCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _pincodeCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRFQ() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final dio = ref.read(dioProvider);
      final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;

      final res = await dio.post('/rfq', data: {
        'product_id': widget.product?.id,
        'product_title': _titleCtrl.text.trim(),
        'quantity': qty,
        'unit': _selectedUnit,
        'buyer_name': _nameCtrl.text.trim(),
        'buyer_phone': _phoneCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
        'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        'requirement_details': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'preferred_contact': _preferredContact,
      });

      if (mounted) {
        setState(() {
          _submitting = false;
          _successResponse = res.data['data'] as Map<String, dynamic>? ?? {};
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeError,
            content: Text('Failed to submit quote request: ${commerceError(e)}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDialogNarrow = width < 560;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: _successResponse != null
            ? _buildSuccessView()
            : _buildFormView(isDialogNarrow),
      ),
    );
  }

  Widget _buildFormView(bool isNarrow) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Banner (IndiaMART / Toolsvilla Style)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff064e3b), Color(0xff047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.request_quote_rounded,
                  color: Color(0xfffef08a),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Get Best Price & Manufacturer Quotes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Direct from verified OEMs, Feed Millers & Distributors',
                      style: TextStyle(
                        color: Color(0xffa7f3d0),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white70),
                tooltip: 'Close',
              ),
            ],
          ),
        ),

        // Scrollable Form Body
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Preview Badge if specific product is selected
                  if (widget.product != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xfff8fafc),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffe2e8f0)),
                      ),
                      child: Row(
                        children: [
                          if (widget.product!.media.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                widget.product!.media.first,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.agriculture,
                                    size: 32,
                                    color: storeGreen),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.product!.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Price: ${storeMoney(widget.product!.price)} / ${widget.product!.unit}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: storeGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product / Machinery Requirement *',
                        hintText: 'e.g. 3HP Chaff Cutter with Motor / 5 Tonnes Cattle Feed',
                        prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please specify your requirement'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quantity and Unit Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Required Quantity *',
                            hintText: 'e.g. 1, 5, 20',
                            prefixIcon: Icon(Icons.pin_outlined, size: 20),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter quantity';
                            final n = int.tryParse(v.trim());
                            if (n == null || n <= 0) return 'Valid qty';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit / Packaging',
                            border: OutlineInputBorder(),
                          ),
                          items: _units
                              .map((u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u, style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedUnit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Buyer Name & Phone
                  if (isNarrow) ...[
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Your Full Name / Farm Name *',
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: '10-Digit Mobile Number (WhatsApp) *',
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter phone number';
                        if (v.replaceAll(RegExp(r'\D'), '').length < 10) {
                          return 'Enter valid 10-digit number';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Your Name / Farm Name *',
                              prefixIcon: Icon(Icons.person_outline, size: 20),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter name'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Mobile (WhatsApp) *',
                              prefixIcon: Icon(Icons.phone_outlined, size: 20),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Enter phone';
                              if (v.replaceAll(RegExp(r'\D'), '').length < 10) {
                                return 'Enter 10-digit phone';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // PIN Code & City
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: _pincodeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Delivery PIN Code',
                            hintText: '380015',
                            prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'City / District',
                            hintText: 'e.g. Anand, Gujarat',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Additional Details / Specs
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Specific Requirements / Notes (Optional)',
                      hintText: 'e.g. Need 4-stroke petrol engine, delivery needed within 5 days, interested in dealership',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Contact Preference
                  const Text(
                    'Preferred Mode of Response:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _preferredContact = 'whatsapp'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _preferredContact == 'whatsapp'
                                  ? const Color(0xffdcfce7)
                                  : const Color(0xfff8fafc),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _preferredContact == 'whatsapp'
                                    ? const Color(0xff16a34a)
                                    : const Color(0xffcbd5e1),
                                width: _preferredContact == 'whatsapp' ? 1.5 : 1.0,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xff16a34a)),
                                SizedBox(width: 6),
                                Text(
                                  'WhatsApp (Fastest)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff15803d)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _preferredContact = 'call'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _preferredContact == 'call'
                                  ? const Color(0xffe0f2fe)
                                  : const Color(0xfff8fafc),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _preferredContact == 'call'
                                    ? const Color(0xff0284c7)
                                    : const Color(0xffcbd5e1),
                                width: _preferredContact == 'call' ? 1.5 : 1.0,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone_in_talk_outlined, size: 16, color: Color(0xff0284c7)),
                                SizedBox(width: 6),
                                Text(
                                  'Phone Call',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff0369a1)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff047857),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _submitting ? null : _submitRFQ,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Request Instant Quotes from Verified Suppliers',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      '🔒 Verified Suppliers · No spam · Free inquiry service',
                      style: TextStyle(fontSize: 11, color: storeMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    final refNo = _successResponse?['reference_no'] ?? 'RFQ-CONFIRMED';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xffdcfce7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xff16a34a),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Requirement Submitted Successfully!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xff064e3b),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xfff1f5f9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xffcbd5e1)),
            ),
            child: Text(
              'Reference ID: $refNo',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xff334155),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'We are matching your requirement with top-rated manufacturers & distributors. You will receive customized quotes on WhatsApp / Call within 2 to 4 hours.',
            style: TextStyle(fontSize: 13, color: Color(0xff475569), height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff047857),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done / Continue Browsing'),
            ),
          ),
        ],
      ),
    );
  }
}
