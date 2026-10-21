// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:dairy_ai/features/milk/widgets/thermal_slip_dialog.dart';

class VoiceEntryDialog extends StatefulWidget {
  const VoiceEntryDialog({super.key});

  @override
  State<VoiceEntryDialog> createState() => _VoiceEntryDialogState();
}

class _VoiceEntryDialogState extends State<VoiceEntryDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isListening = true;
  String _recognizedText = 'बोलिए... (Listening...)';
  double? _parsedQuantity;
  double? _parsedFat;
  String _parsedCattle = 'Ganga (गंगा)';
  String _parsedShift = 'सुबह (Morning)';

  final List<String> _voicePresets = [
    'गंगा गाय ने सुबह 8.5 लीटर दूध दिया, फैट 6.8 है',
    'गौरी गाय शाम 7.0 लीटर दूध, फैट 7.2',
    'लक्ष्मी भैंस सुबह 11 लीटर दूध, फैट 8.0',
    'राधा गाय का तापमान 39.4 बुखार लग रहा है',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Simulate speech recognition listening after 1.5s
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        _simulateRecognized('गंगा गाय ने सुबह 8.5 लीटर दूध दिया, फैट 6.8 है');
      }
    });
  }

  void _simulateRecognized(String text) {
    setState(() {
      _recognizedText = text;
      _isListening = false;
      _parsedQuantity = 8.5;
      _parsedFat = 6.8;
      _parsedCattle = 'Ganga (गंगा)';
      _parsedShift = 'सुबह (Morning)';
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _confirmEntry() {
    Navigator.pop(context);
    // Show thermal slip confirmation immediately
    showDialog(
      context: context,
      builder: (_) => ThermalSlipDialog(
        farmerName: 'Ramesh Patel',
        tagId: _parsedCattle,
        shift: 'MORNING',
        quantityLitres: _parsedQuantity ?? 8.5,
        fatPct: _parsedFat ?? 6.8,
        snfPct: 9.1,
        ratePerLitre: 58.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic, color: Color(0xff064e3b), size: 22),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'आवाज़ से एंट्री (Voice Entry)',
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
              const SizedBox(height: 16),

              // Animated Pulsing Mic
              ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.15).animate(
                  CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _isListening ? const Color(0xff064e3b) : Colors.green.shade700,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                _isListening ? 'कृपया बोलिए... (गीर, मात्रा, फैट)' : 'पहचाना गया (Recognized)',
                style: TextStyle(
                  color: _isListening ? Colors.green.shade800 : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),

              // Recognized Voice Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  '"$_recognizedText"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, fontStyle: FontStyle.italic),
                ),
              ),

              if (!_isListening && _parsedQuantity != null) ...[
                const SizedBox(height: 14),
                // AI Entity Parse Badges
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _badge('पशु', _parsedCattle),
                      _badge('मात्रा', '${_parsedQuantity!} L'),
                      _badge('फैट', '${_parsedFat!}%'),
                      _badge('समय', _parsedShift),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Preset options for 1-click test
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'या इन आवाज़ों पर क्लिक करें (Try Presets):',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _voicePresets.map((preset) {
                  return InkWell(
                    onTap: () => _simulateRecognized(preset),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        preset,
                        style: const TextStyle(fontSize: 11, color: Color(0xff064e3b)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isListening ? null : _confirmEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff064e3b),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('दर्ज करें व पर्ची बनाएं (Confirm)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String title, String val) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff064e3b))),
      ],
    );
  }
}
