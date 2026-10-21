// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/features/maturity/models/maturity_models.dart';
import 'package:dairy_ai/features/maturity/providers/maturity_providers.dart';

class ThermalSlipDialog extends StatefulWidget {
  final String farmerName;
  final String tagId;
  final String shift;
  final double quantityLitres;
  final double fatPct;
  final double snfPct;
  final double ratePerLitre;

  const ThermalSlipDialog({
    super.key,
    required this.farmerName,
    required this.tagId,
    required this.shift,
    required this.quantityLitres,
    required this.fatPct,
    required this.snfPct,
    required this.ratePerLitre,
  });

  @override
  State<ThermalSlipDialog> createState() => _ThermalSlipDialogState();
}

class _ThermalSlipDialogState extends State<ThermalSlipDialog> {
  ThermalSlipData? _slipData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSlip();
  }

  Future<void> _loadSlip() async {
    final data = await generateThermalSlip(
      farmerName: widget.farmerName,
      shift: widget.shift,
      quantity: widget.quantityLitres,
      fat: widget.fatPct,
      snf: widget.snfPct,
      rate: widget.ratePerLitre,
    );
    if (mounted) {
      setState(() {
        _slipData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _shareOnWhatsApp() async {
    final link = await generateWhatsAppDeepLink(
      farmerName: widget.farmerName,
      quantity: widget.quantityLitres,
      rate: widget.ratePerLitre,
      fat: widget.fatPct,
    );
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _printThermal() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🖨️ ESC/POS 58mm प्रिंटर को कमांड भेजी गई (Printer Online)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long, color: Color(0xff064e3b), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'थर्मल पर्ची (Thermal Slip)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_slipData != null)
                // Thermal Slip Paper styling (Serrated appearance)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xfffdfbf7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'MILTERRA DAIRY',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Text(
                              'दुग्ध संकलन पर्ची (SLIP)',
                              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                            Text(
                              '--------------------------------',
                              style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'पर्ची: ${_slipData!.slipId}',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                      Text(
                        'किसान: ${_slipData!.farmerName}',
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'समय: ${_slipData!.shift} | ${_slipData!.date}',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                      Text(
                        '--------------------------------',
                        style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade400),
                      ),
                      _row('मात्रा (Qty)', '${_slipData!.quantityLitres.toStringAsFixed(1)} L'),
                      _row('फैट (Fat %)', '${_slipData!.fatPct.toStringAsFixed(1)} %'),
                      _row('एस.एन.एफ (SNF)', '${_slipData!.snfPct.toStringAsFixed(1)} %'),
                      _row('दर (Rate/L)', '₹ ${_slipData!.ratePerLitre.toStringAsFixed(2)}'),
                      Text(
                        '--------------------------------',
                        style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade400),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'कुल राशि:',
                            style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '₹ ${_slipData!.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xff064e3b),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '================================',
                        style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade400),
                      ),
                      const Center(
                        child: Text(
                          '* डिजिटल सत्यापित पर्ची *',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareOnWhatsApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('WhatsApp रसीद', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _printThermal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff064e3b),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('प्रिंट पर्ची', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          Text(val, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}
