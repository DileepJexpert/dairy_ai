import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/widgets/store_design.dart';

class PurityScannerScreen extends StatefulWidget {
  const PurityScannerScreen({super.key});

  @override
  State<PurityScannerScreen> createState() => _PurityScannerScreenState();
}

class _PurityScannerScreenState extends State<PurityScannerScreen> {
  bool _isScanning = false;
  bool _scanComplete = false;
  double _scanProgress = 0.0;
  Timer? _scanTimer;

  // Reagent status: true = clean/pure, false = adulterated
  bool _detergentClean = true;
  bool _starchClean = true;
  bool _ureaClean = true;
  bool _neutralizerClean = true;

  double _purityScore = 99.4;
  final String _sampleType = 'A2 Gir Cow Milk';
  final String _batchId = 'MLT-A2-2026-B84';

  void _runScan() {
    setState(() {
      _isScanning = true;
      _scanComplete = false;
      _scanProgress = 0.0;
    });

    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      setState(() {
        _scanProgress += 0.05;
        if (_scanProgress >= 1.0) {
          _scanProgress = 1.0;
          _isScanning = false;
          _scanComplete = true;
          _detergentClean = true;
          _starchClean = true;
          _ureaClean = true;
          _neutralizerClean = true;
          _purityScore = 99.4;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Milk Purity Test'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breadcrumb
                      Wrap(
                        children: [
                          InkWell(
                            onTap: () => context.go('/purity'),
                            child: const Text('Purity Checker',
                                style: TextStyle(fontSize: 12, color: storeMuted)),
                          ),
                          const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
                          const Text('AI Test Strip Scanner',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title
                      const Text(
                        'AI Milk Test Strip Scanner',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: storeGreen),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Dip your 4-in-1 chemical purity strip in raw or boiled milk for 3 seconds, align the reaction pads inside the viewfinder, and tap analyze.',
                        style: TextStyle(fontSize: 13, color: storeMuted),
                      ),
                      const SizedBox(height: 20),

                      // Layout: Scanner Viewfinder + Analysis Results
                      LayoutBuilder(builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 720;
                        return isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 52, child: _buildScannerViewfinder()),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 48, child: _buildResultsPanel()),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildScannerViewfinder(),
                                  const SizedBox(height: 18),
                                  _buildResultsPanel(),
                                ],
                              );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerViewfinder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff12231c),
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x1a000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Viewfinder Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isScanning ? storeAmber : storeSuccess,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isScanning
                          ? 'ANALYZING COLORIMETRIC PADS…'
                          : (_scanComplete ? 'CALIBRATION LOCKED' : 'AI CAMERA READY'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('FSSAI 2026 REF',
                      style: TextStyle(fontSize: 10, color: storeAmber, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Viewfinder Camera Area
          SizedBox(
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background subtle grid
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xff0c1914),
                    image: DecorationImage(
                      image: AssetImage('assets/store/farm_video_poster.jpg'),
                      fit: BoxFit.cover,
                      opacity: 0.25,
                    ),
                  ),
                ),

                // Test Strip Graphic
                Center(
                  child: Container(
                    width: 58,
                    height: 250,
                    decoration: BoxDecoration(
                      color: const Color(0xffeae7dc),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white54, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _testPad(
                          label: 'D',
                          name: 'Detergent',
                          color: _scanComplete
                              ? const Color(0xfff3e58d) // Clean yellow
                              : const Color(0xffdcd6c8),
                          isClean: _detergentClean,
                        ),
                        _testPad(
                          label: 'S',
                          name: 'Starch',
                          color: _scanComplete
                              ? const Color(0xffefd8b0) // Clean amber
                              : const Color(0xffdcd6c8),
                          isClean: _starchClean,
                        ),
                        _testPad(
                          label: 'U',
                          name: 'Urea',
                          color: _scanComplete
                              ? const Color(0xfffef3c7) // Clean pale yellow
                              : const Color(0xffdcd6c8),
                          isClean: _ureaClean,
                        ),
                        _testPad(
                          label: 'N',
                          name: 'Neutralizer',
                          color: _scanComplete
                              ? const Color(0xfff5efe6) // Clean cream
                              : const Color(0xffdcd6c8),
                          isClean: _neutralizerClean,
                        ),
                      ],
                    ),
                  ),
                ),

                // Laser scan line animation
                if (_isScanning)
                  Positioned(
                    top: 25 + (_scanProgress * 240),
                    left: 40,
                    right: 40,
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: storeAmber,
                        boxShadow: [
                          BoxShadow(
                            color: storeAmber.withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Corner alignment crosshairs
                const Positioned(
                  top: 20,
                  left: 20,
                  child: Icon(Icons.crop_free, color: storeAmber, size: 28),
                ),
                const Positioned(
                  bottom: 20,
                  right: 20,
                  child: Icon(Icons.crop_free, color: storeAmber, size: 28),
                ),
              ],
            ),
          ),

          // Scan Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: storeAmber,
                      foregroundColor: storeGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isScanning ? null : _runScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: storeGreen),
                          )
                        : const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      _isScanning ? 'Scanning Reagent Pads…' : 'Dip & Scan Test Strip',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _testPad({
    required String label,
    required String name,
    required Color color,
    required bool isClean,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black26),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.black45,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPanel() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Laboratory Assessment',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: storeGreen)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _scanComplete ? const Color(0xffe6f4ea) : storeCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _scanComplete ? const Color(0xff1e8e3e) : storeBorder),
                ),
                child: Text(
                  _scanComplete ? 'VERIFIED PURE' : 'AWAITING SCAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _scanComplete ? const Color(0xff1e8e3e) : storeMuted,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Purity Score Badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xfff4f9f4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffc5e1c7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: storeGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _scanComplete ? '${_purityScore.toStringAsFixed(0)}%' : '--',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scanComplete
                            ? 'Certified 100% Pure · $_sampleType'
                            : 'Align strip to run AI diagnosis',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: storeGreen),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _scanComplete
                            ? 'Zero chemical detergents, starch, synthetic urea, or added water detected.'
                            : 'Supports Milterra test strips and standard FSSAI testing kits for $_sampleType.',
                        style: const TextStyle(fontSize: 12, color: Color(0xff555555)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Detailed Reagent Checklist
          const Text('Reagent Reaction Breakdown',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: storeGreen)),
          const SizedBox(height: 10),

          _adulterantRow(
            title: 'Detergent & Surfactants',
            status: _scanComplete ? 'NEGATIVE (PASS)' : 'Pending',
            isClean: _detergentClean,
            desc: 'Tested for soap residues, anionic surfactants, and foam stabilizers.',
          ),
          _adulterantRow(
            title: 'Starch & Cereal Flours',
            status: _scanComplete ? 'NEGATIVE (PASS)' : 'Pending',
            isClean: _starchClean,
            desc: 'Tested for synthetic thickening agents and added maltodextrins.',
          ),
          _adulterantRow(
            title: 'Synthetic Urea & Added Nitrogen',
            status: _scanComplete ? 'NEGATIVE (PASS)' : 'Pending',
            isClean: _ureaClean,
            desc: 'Tested for non-protein nitrogen used to artificially boost SNF.',
          ),
          _adulterantRow(
            title: 'Chemical Neutralizers (NaOH, NaHCO₃)',
            status: _scanComplete ? 'NEGATIVE (PASS)' : 'Pending',
            isClean: _neutralizerClean,
            desc: 'Tested for alkaline additives used to mask soured milk.',
          ),
          const Divider(height: 22),

          // Traceability action
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: storeGreen,
                side: const BorderSide(color: storeGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => context.push('/purity/certificate/$_batchId'),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: const Text(
                'View Verifiable Batch Lab Certificate',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adulterantRow({
    required String title,
    required String status,
    required bool isClean,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _scanComplete
                ? (isClean ? Icons.check_circle : Icons.cancel)
                : Icons.radio_button_unchecked,
            color: _scanComplete ? (isClean ? storeSuccess : storeError) : storeMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _scanComplete ? (isClean ? storeSuccess : storeError) : storeMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11, color: storeMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
