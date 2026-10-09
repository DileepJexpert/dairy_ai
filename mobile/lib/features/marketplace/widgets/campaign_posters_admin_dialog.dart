import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/campaign_posters_provider.dart';

Future<void> showCampaignPostersAdminDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const CampaignPostersAdminDialog(),
  );
}

class CampaignPostersAdminDialog extends ConsumerStatefulWidget {
  const CampaignPostersAdminDialog({super.key});

  @override
  ConsumerState<CampaignPostersAdminDialog> createState() =>
      _CampaignPostersAdminDialogState();
}

class _CampaignPostersAdminDialogState
    extends ConsumerState<CampaignPostersAdminDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<TextEditingController> _titleControllers;
  late List<TextEditingController> _highlightControllers;
  late List<TextEditingController> _wasPriceControllers;
  late List<TextEditingController> _nowPriceControllers;
  late List<TextEditingController> _rewardControllers;
  late List<TextEditingController> _couponControllers;
  late List<TextEditingController> _categoryControllers;

  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _initControllers(List<CampaignPosterConfig> posters) {
    if (_initialized) return;
    _titleControllers =
        posters.map((p) => TextEditingController(text: p.title)).toList();
    _highlightControllers =
        posters.map((p) => TextEditingController(text: p.highlightTag)).toList();
    _wasPriceControllers =
        posters.map((p) => TextEditingController(text: p.wasPrice)).toList();
    _nowPriceControllers =
        posters.map((p) => TextEditingController(text: p.nowPrice)).toList();
    _rewardControllers =
        posters.map((p) => TextEditingController(text: p.rewardTag)).toList();
    _couponControllers =
        posters.map((p) => TextEditingController(text: p.couponCode)).toList();
    _categoryControllers =
        posters.map((p) => TextEditingController(text: p.category)).toList();
    _initialized = true;
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_initialized) {
      for (final c in _titleControllers) {
        c.dispose();
      }
      for (final c in _highlightControllers) {
        c.dispose();
      }
      for (final c in _wasPriceControllers) {
        c.dispose();
      }
      for (final c in _nowPriceControllers) {
        c.dispose();
      }
      for (final c in _rewardControllers) {
        c.dispose();
      }
      for (final c in _couponControllers) {
        c.dispose();
      }
      for (final c in _categoryControllers) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _saveCurrentTab(int idx) async {
    setState(() => _saving = true);
    final posters = ref.read(campaignPostersProvider);
    if (idx >= 0 && idx < posters.length) {
      final updated = posters[idx].copyWith(
        title: _titleControllers[idx].text.trim(),
        highlightTag: _highlightControllers[idx].text.trim(),
        wasPrice: _wasPriceControllers[idx].text.trim(),
        nowPrice: _nowPriceControllers[idx].text.trim(),
        rewardTag: _rewardControllers[idx].text.trim(),
        couponCode: _couponControllers[idx].text.trim(),
        category: _categoryControllers[idx].text.trim(),
      );
      await ref.read(campaignPostersProvider.notifier).updatePoster(idx, updated);
    }
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved discount & offer for Card #${idx + 1}!'),
          backgroundColor: const Color(0xff0d9488),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final posters = ref.watch(campaignPostersProvider);
    _initControllers(posters);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xff111827),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Color(0xfffcd34d), size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configure Campaign Range Cards',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Edit discounts, coupon codes, and price drops live on homepage',
                          style: TextStyle(
                            color: Color(0xff94a3b8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              color: const Color(0xfff8fafc),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xff0d9488),
                unselectedLabelColor: const Color(0xff64748b),
                indicatorColor: const Color(0xff0d9488),
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: '1. Cow Ghee'),
                  Tab(text: '2. Sarso Oil'),
                  Tab(text: '3. Buffalo Ghee'),
                  Tab(text: '4. Malai Paneer'),
                ],
              ),
            ),

            // Tab View with Form
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(4, (idx) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildField(
                          label: 'Range Title',
                          controller: _titleControllers[idx],
                          hint: 'e.g. Vedic A2 Cow Ghee Range',
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          label: 'Top Highlight Banner (Red/Amber Tag)',
                          controller: _highlightControllers[idx],
                          hint: 'e.g. PRICE DROPPED BY ₹200 or EXTRA 15% OFF',
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                label: 'Original Price (Was)',
                                controller: _wasPriceControllers[idx],
                                hint: 'e.g. ₹1,600',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildField(
                                label: 'Offer Price (Now)',
                                controller: _nowPriceControllers[idx],
                                hint: 'e.g. ₹1,399',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                label: 'Reward / Tag text',
                                controller: _rewardControllers[idx],
                                hint: 'e.g. + 5% Milterra Coins',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildField(
                                label: 'Coupon Code',
                                controller: _couponControllers[idx],
                                hint: 'e.g. BILONA200',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildField(
                          label: 'Target Category / Search',
                          controller: _categoryControllers[idx],
                          hint: 'e.g. Vedic Bilona Ghee',
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xff0d9488),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                            ),
                            onPressed: _saving
                                ? null
                                : () => _saveCurrentTab(idx),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text(
                              'Save This Card',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // Bottom Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xfff8fafc),
                border: Border(top: BorderSide(color: Color(0xffe2e8f0))),
              ),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ref
                          .read(campaignPostersProvider.notifier)
                          .resetToDefaults();
                      final p = ref.read(campaignPostersProvider);
                      for (int i = 0; i < 4; i++) {
                        _titleControllers[i].text = p[i].title;
                        _highlightControllers[i].text = p[i].highlightTag;
                        _wasPriceControllers[i].text = p[i].wasPrice;
                        _nowPriceControllers[i].text = p[i].nowPrice;
                        _rewardControllers[i].text = p[i].rewardTag;
                        _couponControllers[i].text = p[i].couponCode;
                        _categoryControllers[i].text = p[i].category;
                      }
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Reset to default cards!')),
                      );
                    },
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Reset to Defaults'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xff334155),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xff94a3b8)),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffcbd5e1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xff0d9488), width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
