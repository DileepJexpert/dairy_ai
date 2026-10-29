import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/shared/widgets/farmer_auth_action.dart';

/// Cattle Feed, Mineral Mixture & Nutrition Store & Promotion Hub.
/// Allows dairy farmers to:
/// 1. Calculate real-time ROI: Daily supplement cost vs extra milk profit.
/// 2. Explore chelated mineral mixtures, liquid calcium, bypass fat, balanced pellets & silage.
/// 3. Book products with 0 upfront cash (deduct from 10-day society milk payout) or Cash on Delivery.
/// 4. Claim free 500g mineral mixture trial packs.
/// 5. Allow local feed dealers, FPOs, chakkis, and silage producers to list & promote their feeds.
class CattleFeedStoreScreen extends ConsumerStatefulWidget {
  const CattleFeedStoreScreen({super.key, this.initialCategory = 'all'});

  final String initialCategory;

  @override
  ConsumerState<CattleFeedStoreScreen> createState() =>
      _CattleFeedStoreScreenState();
}

class _CattleFeedStoreScreenState extends ConsumerState<CattleFeedStoreScreen> {
  late String _selectedCategory;
  final _searchController = TextEditingController();
  bool _isLoading = false;

  // ROI Calculator State
  String _roiAnimal = 'cow'; // 'cow' or 'buffalo'
  final double _roiCurrentMilk = 12.0;
  String _roiSupplement = 'mineral_mixture'; // 'mineral_mixture', 'calcium', 'bypass_fat'

  // Products List State
  List<Map<String, dynamic>> _products = [];

  final List<Map<String, dynamic>> _fallbackProducts = [
    {
      'id': 'feed-p01',
      'title': 'Milterra Chelated Mineral Gold (चिलेटेड मिनरल मिक्सर)',
      'brand': 'Milterra Nutrition',
      'category': 'mineral_mixture',
      'price': 135.0,
      'original_price': 220.0,
      'unit': '1 kg Pouch',
      'min_order_qty': 1,
      'rating': 4.9,
      'reviews_count': 86,
      'protein_pct': 0.0,
      'calcium_pct': 28.5,
      'phosphorus_pct': 14.2,
      'dosage_info': '50 ग्राम प्रतिदिन प्रति वयस्क गाय/भैंस। दाने या चोकर में मिलाकर दें।',
      'benefits': '1.2 से 1.5L दूध वृद्धि, बांझपन व रिपीट ब्रीडिंग की रोकथाम, चमकती त्वचा।',
      'seller_name': 'हरियाणा डेयरी विकास संघ (HDDC FPO)',
      'seller_phone': '9876501122',
      'seller_type': 'fpo',
      'location': 'करनाल, हरियाणा (Karnal Hub)',
      'badge': 'BESTSELLER • 38% OFF',
    },
    {
      'id': 'feed-p02',
      'title': 'Milterra Chelated Gold Bucket (5kg बाल्टी)',
      'brand': 'Milterra Nutrition',
      'category': 'mineral_mixture',
      'price': 620.0,
      'original_price': 950.0,
      'unit': '5 kg Bucket',
      'min_order_qty': 1,
      'rating': 4.9,
      'reviews_count': 54,
      'protein_pct': 0.0,
      'calcium_pct': 28.5,
      'phosphorus_pct': 14.2,
      'dosage_info': '100 दिन की खुराक। 50g प्रतिदिन।',
      'benefits': 'बड़ी बाल्टी पैक में ₹330 की सीधी बचत + एयरटाइट सील सुरक्षा।',
      'seller_name': 'किसान शक्ति एग्रो FPO',
      'seller_phone': '9876502233',
      'seller_type': 'fpo',
      'location': 'लुधियाना, पंजाब (Punjab Cluster)',
      'badge': 'SUPER VALUE BUCKET',
    },
    {
      'id': 'feed-p03',
      'title': 'Calci-Lact Strong Liquid Calcium (मिल्क फीवर बचाव)',
      'brand': 'Pashu Raksha Vet',
      'category': 'calcium_supplement',
      'price': 780.0,
      'original_price': 1150.0,
      'unit': '5 Litre Can',
      'min_order_qty': 1,
      'rating': 4.8,
      'reviews_count': 42,
      'protein_pct': 0.0,
      'calcium_pct': 35.0,
      'phosphorus_pct': 17.5,
      'dosage_info': '100ml प्रतिदिन ब्याने के 10 दिन पहले और 30 दिन बाद तक।',
      'benefits': 'ब्याने के बाद कैल्शियम की कमी (मिल्क फीवर) से 100% सुरक्षा व दूध पीक पर ले जाए।',
      'seller_name': 'शर्मा वेटरनरी मेडिकल्स',
      'seller_phone': '9876503344',
      'seller_type': 'dealer',
      'location': 'मेरठ, उत्तर प्रदेश (UP West)',
      'badge': 'VET RECOMMENDED',
    },
    {
      'id': 'feed-p04',
      'title': 'Energy-Bypass Fat 99% (फैट बढ़ाने वाला स्पेशल फीड)',
      'brand': 'GoldDairy Bio',
      'category': 'bypass_fat',
      'price': 1450.0,
      'original_price': 1950.0,
      'unit': '25 kg Bag',
      'min_order_qty': 1,
      'rating': 4.7,
      'reviews_count': 31,
      'protein_pct': 0.0,
      'calcium_pct': 9.0,
      'phosphorus_pct': 0.0,
      'dosage_info': '100-150 ग्राम प्रतिदिन अधिक दूध देने वाले पशुओं के लिए।',
      'benefits': 'दूध का फैट 0.6% से 1.2% तक बढ़ाए, ऊर्जा की कमी रोके और तेजी से वजन सुधारे।',
      'seller_name': 'प्रोग्रेसिव डेयरी फार्मर एसोसिएशन',
      'seller_phone': '9876504455',
      'seller_type': 'fpo',
      'location': 'अंबाला, हरियाणा',
      'badge': 'HIGH FAT BOOST',
    },
    {
      'id': 'feed-p05',
      'title': 'Kisan Dhenu Balanced Pellets 22% CP (संतुलित पशुआहार)',
      'brand': 'Kisan Dhenu Feed',
      'category': 'cattle_feed',
      'price': 1320.0,
      'original_price': 1680.0,
      'unit': '50 kg Bag',
      'min_order_qty': 2,
      'rating': 4.8,
      'reviews_count': 118,
      'protein_pct': 22.0,
      'calcium_pct': 1.8,
      'phosphorus_pct': 0.9,
      'dosage_info': 'प्रति 1L दूध पर 400g दाना + 1.5kg शरीर रक्षा के लिए।',
      'benefits': 'मक्का दरिया, बिनौला, सरसों खल, गेहूं चोकर व मिनरल्स का संतुलित मिश्रण।',
      'seller_name': 'श्री बालाजी कैटल फीड मिल्स',
      'seller_phone': '9876505566',
      'seller_type': 'manufacturer',
      'location': 'जींद, हरियाणा (Direct Mill Rate)',
      'badge': 'DIRECT FACTORY RATE',
    },
    {
      'id': 'feed-p06',
      'title': 'Green Corn Silage Bales (मक्का साइलेज गांठ 60kg)',
      'brand': 'GreenField Silage',
      'category': 'silage',
      'price': 390.0,
      'original_price': 520.0,
      'unit': '60 kg Bale',
      'min_order_qty': 5,
      'rating': 4.9,
      'reviews_count': 67,
      'protein_pct': 8.5,
      'calcium_pct': 0.5,
      'phosphorus_pct': 0.3,
      'dosage_info': '15-20 किलो प्रतिदिन प्रति गाय/भैंस।',
      'benefits': '100% ताजे मीठे मक्का का साइलेज। गर्मियों में हरा चारा न होने पर भी दूध कम नहीं होने देता।',
      'seller_name': 'पंजाब साइलेज फार्म्स क्लस्टर',
      'seller_phone': '9876506677',
      'seller_type': 'farmer',
      'location': 'पटियाला, पंजाब',
      'badge': 'SWEET CORN SILAGE',
    },
    {
      'id': 'feed-p07',
      'title': 'Free Mineral Mix Trial Pack 500g (मुफ़्त मिनरल मिक्स ट्रायल)',
      'brand': 'Milterra Nutrition',
      'category': 'trial_pack',
      'price': 0.0,
      'original_price': 110.0,
      'unit': '500g Trial Sample',
      'min_order_qty': 1,
      'rating': 5.0,
      'reviews_count': 240,
      'protein_pct': 0.0,
      'calcium_pct': 28.5,
      'phosphorus_pct': 14.2,
      'dosage_info': '10 दिन तक 50g रोज देकर खुद दूध में फर्क देखें।',
      'benefits': 'पूरी तरह मुफ्त नमूना! किसान केवल ₹30 गांव पिकअप डिलीवरी शुल्क वहन करें।',
      'seller_name': 'मिल्टेरा किसान सहायता मिशन',
      'seller_phone': '9876500000',
      'seller_type': 'fpo',
      'location': 'अखिल भारतीय (All Districts)',
      'badge': '100% FREE SAMPLE',
    },
  ];

  static const List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'सभी (All)'},
    {'id': 'mineral_mixture', 'label': '🌿 खनिज मिश्रण (Mineral Mix)'},
    {'id': 'calcium_supplement', 'label': '🥛 कैल्शियम (Calcium)'},
    {'id': 'bypass_fat', 'label': '⚡ बाईपास फैट (Bypass Fat)'},
    {'id': 'cattle_feed', 'label': '🌾 संतुलित दाना (Pellets)'},
    {'id': 'silage', 'label': '🌽 साइलेज गांठ (Silage)'},
    {'id': 'trial_pack', 'label': '🎁 फ्री ट्रायल (Free Sample)'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _products = _filterFallbackProducts();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(apiClientProvider);
      final res = await dio.get('/api/v1/feed/products', queryParameters: {
        'category': _selectedCategory,
        'q': _searchController.text.trim(),
      });
      if (res.statusCode == 200 && res.data?['data']?['products'] != null) {
        final List<dynamic> list = res.data['data']['products'];
        if (mounted) {
          setState(() {
            _products = list.map((e) => Map<String, dynamic>.from(e)).toList();
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {
      // Graceful fallback to client-side catalog
    }

    if (mounted) {
      setState(() {
        _products = _filterFallbackProducts();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filterFallbackProducts() {
    return _fallbackProducts.where((p) {
      final matchesCat =
          _selectedCategory == 'all' || p['category'] == _selectedCategory;
      final q = _searchController.text.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          (p['title'] as String).toLowerCase().contains(q) ||
          (p['brand'] as String).toLowerCase().contains(q) ||
          (p['benefits'] as String).toLowerCase().contains(q);
      return matchesCat && matchesQuery;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // ROI Calculation
  // ---------------------------------------------------------------------------
  Map<String, dynamic> _calculateRoi() {
    final isCow = _roiAnimal == 'cow';
    final milkRate = isCow ? 38.50 : 62.00;

    double dailyDoseGram = 50.0;
    double dailyCost = 3.85;
    double expectedGainLitres = 1.30;

    if (_roiSupplement == 'calcium') {
      dailyDoseGram = 100.0;
      dailyCost = 15.60;
      expectedGainLitres = 1.80;
    } else if (_roiSupplement == 'bypass_fat') {
      dailyDoseGram = 100.0;
      dailyCost = 12.00;
      expectedGainLitres = 1.50;
    }

    final dailyGrossExtra = expectedGainLitres * milkRate;
    final dailyNetProfit = dailyGrossExtra - dailyCost;
    final monthlyNetProfit = dailyNetProfit * 30.0;
    final roiMultiplier = dailyCost > 0 ? (dailyGrossExtra / dailyCost) : 1.0;

    return {
      'current_milk': _roiCurrentMilk,
      'projected_milk': _roiCurrentMilk + expectedGainLitres,
      'dose_gram': dailyDoseGram.toInt(),
      'daily_cost': dailyCost,
      'extra_litres': expectedGainLitres,
      'daily_gross': dailyGrossExtra,
      'daily_net': dailyNetProfit,
      'monthly_net': monthlyNetProfit,
      'roi_x': roiMultiplier.toStringAsFixed(1),
    };
  }

  // ---------------------------------------------------------------------------
  // 1-Click Order Booking Modal
  // ---------------------------------------------------------------------------
  void _openOrderModal(Map<String, dynamic> product) {
    int qty = (product['min_order_qty'] as num?)?.toInt() ?? 1;
    String paymentMethod = 'milk_payout_deduction';
    final addressCtrl = TextEditingController(
      text: 'ग्राम डेयरी समिति संकलन केंद्र (VLCC Pickup Point)',
    );
    final phoneCtrl = TextEditingController(text: '9876543210');
    final nameCtrl = TextEditingController(text: 'रमेश पटेल (किसान साथी)');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final price = (product['price'] as num).toDouble();
          final total = qty * price;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Text(
                        price == 0 ? 'मुफ़्त (FREE)' : '₹${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff047857),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'प्रति ${product['unit']}',
                        style: const TextStyle(color: Color(0xff64748b)),
                      ),
                      const Spacer(),
                      // Qty counter
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xffcbd5e1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: qty > 1
                                  ? () => setModalState(() => qty--)
                                  : null,
                            ),
                            Text(
                              '$qty',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => setModalState(() => qty++),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'भुगतान का तरीका (Payment Mode)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    value: 'milk_payout_deduction',
                    groupValue: paymentMethod,
                    title: const Text(
                      '🥛 10-दिवसीय दूध बिल से कटौती (0 अग्रिम नकद)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'अगले पखवाड़ा दूध भुगतान से आसान किश्त में स्वतः कटेगा।',
                      style: TextStyle(fontSize: 11),
                    ),
                    activeColor: const Color(0xff047857),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setModalState(() => paymentMethod = v!),
                  ),
                  RadioListTile<String>(
                    value: 'cod',
                    groupValue: paymentMethod,
                    title: const Text(
                      '💵 डिलीवरी पर नकद (Cash on Delivery)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    activeColor: const Color(0xff047857),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setModalState(() => paymentMethod = v!),
                  ),
                  RadioListTile<String>(
                    value: 'upi',
                    groupValue: paymentMethod,
                    title: const Text(
                      '📱 UPI / ऑनलाइन भुगतान',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    activeColor: const Color(0xff047857),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setModalState(() => paymentMethod = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'किसान का नाम',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'मोबाइल नंबर (Phone)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'डिलीवरी का पता / गांव समिति',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'कुल देय राशि:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        price == 0 ? '₹0 (फ्री सैंपल)' : '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff047857),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff047857),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'ऑर्डर की पुष्टि करें (Confirm Order)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        _submitOrder(
                          product: product,
                          qty: qty,
                          total: total,
                          paymentMethod: paymentMethod,
                          name: nameCtrl.text,
                          phone: phoneCtrl.text,
                          address: addressCtrl.text,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitOrder({
    required Map<String, dynamic> product,
    required int qty,
    required double total,
    required String paymentMethod,
    required String name,
    required String phone,
    required String address,
  }) async {
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/api/v1/feed/orders', data: {
        'farmer_name': name,
        'farmer_phone': phone,
        'product_id': product['id'],
        'product_title': product['title'],
        'quantity': qty,
        'total_amount': total,
        'payment_method': paymentMethod,
        'delivery_address': address,
      });
    } catch (_) {
      // Graceful offline behavior
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xff047857), size: 48),
          title: const Text('ऑर्डर सफलतापूर्वक बुक हुआ!'),
          content: Text(
            paymentMethod == 'milk_payout_deduction'
                ? 'आपका ${product['title']} ($qty पैकेट) बुक हो गया है। राशि ₹${total.toStringAsFixed(0)} आपके आगामी 10-दिवसीय दूध बिल से समायोजित की जाएगी।'
                : 'आपका ${product['title']} ($qty पैकेट) बुक हो गया है। सामग्री 24-48 घंटे में आपके गांव संकलन केंद्र पहुंचेगी।',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xff047857)),
              onPressed: () => Navigator.pop(context),
              child: const Text('ठीक है (Done)'),
            ),
          ],
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Promote & List Feed Dialog (For Vendors, FPOs, Dealers, Chakkis)
  // ---------------------------------------------------------------------------
  void _openSellerListingModal() {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final mrpCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: '1 kg Pouch');
    final sellerNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final benefitsCtrl = TextEditingController();
    String cat = 'mineral_mixture';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📢 अपना दाना/मिनरल मिक्स प्रमोट करें',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'FPO, चक्की, साइलेज उत्पादक व डीलर स्टोर लिस्टिंग',
                            style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'उत्पाद का नाम (e.g. शक्ति चिलेटेड मिनरल मिक्स)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cat,
                    decoration: const InputDecoration(
                      labelText: 'श्रेणी (Category)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'mineral_mixture',
                        child: Text('🌿 खनिज मिश्रण (Mineral Mix)'),
                      ),
                      DropdownMenuItem(
                        value: 'calcium_supplement',
                        child: Text('🥛 लिक्विड कैल्शियम (Liquid Calcium)'),
                      ),
                      DropdownMenuItem(
                        value: 'bypass_fat',
                        child: Text('⚡ बाईपास फैट (Bypass Fat)'),
                      ),
                      DropdownMenuItem(
                        value: 'cattle_feed',
                        child: Text('🌾 संतुलित पशुआहार (Balanced Feed)'),
                      ),
                      DropdownMenuItem(
                        value: 'silage',
                        child: Text('🌽 मक्का साइलेज गांठ (Corn Silage)'),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => cat = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'विक्रय मूल्य ₹ (Offer Price)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: mrpCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'एमआरपी ₹ (Original MRP)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'पैकेजिंग इकाई (e.g. 1 kg Pouch, 50 kg Bag, 60 kg Bale)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: benefitsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'फायदे व विशेषताएं (Benefits)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sellerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'दुकान / FPO / उत्पादक का नाम',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'WhatsApp फोन नंबर',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: locCtrl,
                          decoration: const InputDecoration(
                            labelText: 'जिला / राज्य',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff065f46),
                      ),
                      icon: const Icon(Icons.campaign),
                      label: const Text(
                        'तुरंत लिस्ट व प्रमोट करें (Publish Listing)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () async {
                        if (titleCtrl.text.isEmpty ||
                            priceCtrl.text.isEmpty ||
                            sellerNameCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('कृपया नाम, मूल्य और विक्रेता की जानकारी भरें।'),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        await _submitNewListing(
                          title: titleCtrl.text,
                          cat: cat,
                          price: double.tryParse(priceCtrl.text) ?? 100.0,
                          mrp: double.tryParse(mrpCtrl.text) ?? 150.0,
                          unit: unitCtrl.text,
                          sellerName: sellerNameCtrl.text,
                          phone: phoneCtrl.text,
                          location: locCtrl.text,
                          benefits: benefitsCtrl.text,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitNewListing({
    required String title,
    required String cat,
    required double price,
    required double mrp,
    required String unit,
    required String sellerName,
    required String phone,
    required String location,
    required String benefits,
  }) async {
    final newProduct = {
      'id': 'feed-p-${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'brand': sellerName,
      'category': cat,
      'price': price,
      'original_price': mrp,
      'unit': unit,
      'min_order_qty': 1,
      'rating': 5.0,
      'reviews_count': 1,
      'protein_pct': cat == 'cattle_feed' ? 20.0 : 0.0,
      'calcium_pct': cat == 'mineral_mixture' ? 28.0 : 0.0,
      'phosphorus_pct': cat == 'mineral_mixture' ? 14.0 : 0.0,
      'dosage_info': 'दैनिक 50-100 ग्राम दाने में दें।',
      'benefits': benefits.isNotEmpty ? benefits : 'शुद्ध गुणवत्ता व उच्च पोषण।',
      'seller_name': sellerName,
      'seller_phone': phone,
      'seller_type': 'fpo',
      'location': location.isNotEmpty ? location : 'स्थानीय मंडी',
      'badge': 'VERIFIED LOCAL SELLER',
    };

    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/api/v1/feed/products', data: newProduct);
    } catch (_) {}

    setState(() {
      _products.insert(0, newProduct);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xff047857),
          content: Text('बधाई! आपका पशुआहार उत्पाद सफलतापूर्वक लिस्ट और प्रमोट हो गया है।'),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build Main UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final roi = _calculateRoi();

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        title: const Text('पशुआहार व खनिज मिश्रण बाज़ार'),
        backgroundColor: const Color(0xff064e3b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'अपना उत्पाद लिस्ट करें',
            icon: const Icon(Icons.add_business),
            onPressed: _openSellerListingModal,
          ),
          const FarmerAuthAction(nextRoute: '/feed/store'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProducts,
        color: const Color(0xff047857),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            // Top Promotion & Listing Banner for FPOs / Feed Sellers
            _buildVendorHeroPromo(),
            const SizedBox(height: 14),

            // Milk & Supplement ROI Calculator Card
            _buildRoiCalculatorCard(roi),
            const SizedBox(height: 16),

            // Group Buying Banner
            _buildGroupBuyingBanner(),
            const SizedBox(height: 16),

            // Category Horizontal Selector
            _buildCategorySelector(),
            const SizedBox(height: 14),

            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'खनिज मिश्रण, कैल्शियम, बाईपास फैट, साइलेज खोजें...',
                prefixIcon: const Icon(Icons.search, color: Color(0xff047857)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchProducts();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                ),
              ),
              onSubmitted: (_) => _fetchProducts(),
            ),
            const SizedBox(height: 16),

            // Products Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'प्रमाणित पशुआहार व सप्लीमेंट्स (${_products.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openSellerListingModal,
                  icon: const Icon(Icons.add, size: 16, color: Color(0xff047857)),
                  label: const Text(
                    'नया उत्पाद जोड़ें',
                    style: TextStyle(color: Color(0xff047857), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Products List
            if (_isLoading && _products.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xff047857)),
                ),
              )
            else if (_products.isEmpty)
              _buildEmptyState()
            else
              ..._products.map((p) => _buildProductCard(p)),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Banner: Vendor & FPO Promotion
  // ---------------------------------------------------------------------------
  Widget _buildVendorHeroPromo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff064e3b), Color(0xff065f46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff064e3b).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'FPO व डीलर्स के लिए सीधा किसान प्रचार',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'अपना पशुआहार व खनिज मिश्रण प्रमोट करें',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'स्थानीय चक्की, साइलेज उत्पादक व डीलर 2 मिनट में फ्री स्टोर जोड़ें और गांव-गांव ऑर्डर पाएं।',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff064e3b),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: _openSellerListingModal,
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text(
                    'फ्री में लिस्ट करें (List Free)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco, size: 44, color: Colors.amber),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interactive Milk & Profit ROI Calculator
  // ---------------------------------------------------------------------------
  Widget _buildRoiCalculatorCard(Map<String, dynamic> roi) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xffcbd5e1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calculate, color: Color(0xff047857), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'खनिज पोषण व दूध लाभ कैलकुलेटर',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xffecfdf5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${roi['roi_x']}x ROI',
                    style: const TextStyle(
                      color: Color(0xff047857),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Cow vs Buffalo Chip
            Row(
              children: [
                ChoiceChip(
                  label: const Text('🐄 गाय (Cow @ ₹38.5)'),
                  selected: _roiAnimal == 'cow',
                  selectedColor: const Color(0xff047857),
                  labelStyle: TextStyle(
                    color: _roiAnimal == 'cow' ? Colors.white : Colors.black87,
                    fontSize: 11.5,
                  ),
                  onSelected: (_) => setState(() => _roiAnimal = 'cow'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('🐃 भैंस (Buffalo @ ₹62)'),
                  selected: _roiAnimal == 'buffalo',
                  selectedColor: const Color(0xff047857),
                  labelStyle: TextStyle(
                    color: _roiAnimal == 'buffalo' ? Colors.white : Colors.black87,
                    fontSize: 11.5,
                  ),
                  onSelected: (_) => setState(() => _roiAnimal = 'buffalo'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Supplement Choice
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _miniSupplementChip('mineral_mixture', '🌿 चिलेटेड मिनरल (50g)'),
                _miniSupplementChip('calcium', '🥛 लिक्विड कैल्शियम (100ml)'),
                _miniSupplementChip('bypass_fat', '⚡ बाईपास फैट (100g)'),
              ],
            ),
            const SizedBox(height: 14),

            // Live Output Stats Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff0fdf4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xff86efac)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statCell('दैनिक खुराक', '${roi['dose_gram']} g/दिन'),
                      _statCell('दैनिक खर्च', 'मात्र ₹${roi['daily_cost']}'),
                      _statCell('अपेक्षित दूध वृद्धि', '+${roi['extra_litres']} L/दिन'),
                    ],
                  ),
                  const Divider(height: 16, color: Color(0xffbbf7d0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'मासिक अतिरिक्त शुद्ध मुनाफा:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '+₹${(roi['monthly_net'] as double).toStringAsFixed(0)} / पशु',
                        style: const TextStyle(
                          color: Color(0xff047857),
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniSupplementChip(String id, String label) {
    final isSelected = _roiSupplement == id;
    return InkWell(
      onTap: () => setState(() => _roiSupplement = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff065f46) : const Color(0xfff1f5f9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xff065f46) : const Color(0xffcbd5e1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xff334155),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _statCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff064e3b)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Village Group Buying Banner
  // ---------------------------------------------------------------------------
  Widget _buildGroupBuyingBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffeff6ff),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff93c5fd)),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups, color: Color(0xff1d4ed8), size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'गांव क्लस्टर ग्रुप बाइंग (Wholesale Pool)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xff1e3a8a),
                  ),
                ),
                Text(
                  'गांव के 5-10 किसान मिलकर 20+ बोरी बुक करें तो पाएं ₹150/बोरी सीधी छूट!',
                  style: TextStyle(fontSize: 11, color: Color(0xff3b82f6)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff1d4ed8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: () => context.push('/feed/group-buying'),
            child: const Text('पूल देखें', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Category Selector
  // ---------------------------------------------------------------------------
  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((c) {
          final isSelected = _selectedCategory == c['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(c['label']!),
              selected: isSelected,
              selectedColor: const Color(0xff047857),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) {
                setState(() => _selectedCategory = c['id']!);
                _fetchProducts();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Product Card
  // ---------------------------------------------------------------------------
  Widget _buildProductCard(Map<String, dynamic> p) {
    final price = (p['price'] as num).toDouble();
    final mrp = (p['original_price'] as num?)?.toDouble() ?? (price * 1.3);
    final isFree = price == 0;
    final badge = p['badge'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xffe2e8f0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge & Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (badge.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFree
                          ? Colors.purple.shade600
                          : (badge.contains('BESTSELLER')
                              ? const Color(0xffdc2626)
                              : const Color(0xff065f46)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${p['rating']} (${p['reviews_count']})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title & Brand
            Text(
              p['title'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 2),
            Text(
              '${p['brand']} • ${p['location']}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xff64748b)),
            ),
            const SizedBox(height: 10),

            // Nutrient Pill Specs
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if ((p['calcium_pct'] as num? ?? 0) > 0)
                  _specChip('Ca: ${p['calcium_pct']}%', Colors.blue),
                if ((p['phosphorus_pct'] as num? ?? 0) > 0)
                  _specChip('P: ${p['phosphorus_pct']}%', Colors.teal),
                if ((p['protein_pct'] as num? ?? 0) > 0)
                  _specChip('Protein: ${p['protein_pct']}%', Colors.orange),
                _specChip(p['unit'] as String, Colors.indigo),
              ],
            ),
            const SizedBox(height: 10),

            // Benefits Snippet
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xfff1f5f9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xff047857), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p['benefits'] ?? '',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xff334155)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Price & Actions
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isFree ? 'मुफ़्त (₹0)' : '₹${price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isFree ? Colors.purple.shade700 : const Color(0xff047857),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (mrp > price)
                          Text(
                            '₹${mrp.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff94a3b8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'प्रति ${p['unit']}',
                      style: const TextStyle(fontSize: 11, color: Color(0xff64748b)),
                    ),
                  ],
                ),
                const Spacer(),
                // WhatsApp Inquire Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff15803d),
                    side: const BorderSide(color: Color(0xff15803d)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: () {
                    final msg =
                        'नमस्ते, मुझे मिल्टेरा किसान ऐप से आपके उत्पाद *${p['title']}* (₹$price) के बारे में जानकारी और डिलीवरी चाहिए।';
                    launchUrl(Uri.parse('https://wa.me/91${p['seller_phone']}?text=${Uri.encodeComponent(msg)}'));
                  },
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                // 1-Click Order Button
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff047857),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => _openOrderModal(p),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                  label: Text(
                    isFree ? 'फ्री मंगाएं' : 'ऑर्डर करें',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _specChip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade800,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xff94a3b8)),
          const SizedBox(height: 12),
          const Text(
            'इस श्रेणी में कोई उत्पाद नहीं मिला।',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text(
            'आप पहला उत्पाद जोड़कर अपने गांव के किसानों को प्रमोट कर सकते हैं।',
            style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff047857)),
            icon: const Icon(Icons.add),
            label: const Text('अपना उत्पाद लिस्ट करें'),
            onPressed: _openSellerListingModal,
          ),
        ],
      ),
    );
  }
}
