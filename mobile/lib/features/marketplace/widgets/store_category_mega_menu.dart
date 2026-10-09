import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import 'store_design.dart';

/// Multi-column section-wise Mega Menu for Milterra Storefront
void showCategoryDepartmentMenu(BuildContext context) {
  final isMobile = MediaQuery.sizeOf(context).width < 880;
  if (isMobile) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Menu',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) => const CategoryMobileDrawer(),
      transitionBuilder: (ctx, anim1, anim2, child) => SlideTransition(
        position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  } else {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Menu',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) =>
          const CategoryMegaMenuOverlay(),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.02), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }
}

class _MegaMenuItem {
  final String title;
  final String? query;
  final String? category;

  const _MegaMenuItem({
    required this.title,
    this.query,
    this.category,
  });
}

class _MegaMenuSection {
  final String title;
  final List<_MegaMenuItem> items;

  const _MegaMenuSection({
    required this.title,
    required this.items,
  });
}

class _MegaMenuCategory {
  final String id;
  final String name;
  final String icon;
  final String filterCategory;
  final List<_MegaMenuSection> sections;

  const _MegaMenuCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.filterCategory,
    required this.sections,
  });
}

const List<_MegaMenuCategory> _megaMenuCategories = [
  _MegaMenuCategory(
    id: 'dairy',
    name: 'Artisanal Dairy & Cultured',
    icon: '🥛',
    filterCategory: 'Artisanal Dairy & Cultured',
    sections: [
      _MegaMenuSection(
        title: 'VEDIC BILONA GHEE',
        items: [
          _MegaMenuItem(title: 'A2 Gir Cow Bilona Ghee', query: 'cow ghee'),
          _MegaMenuItem(title: 'Murrah Buffalo Danedar Ghee', query: 'buffalo ghee'),
          _MegaMenuItem(title: '2L Heritage Tin Cow Ghee', query: 'tin ghee'),
          _MegaMenuItem(title: 'Traditional Valona Churn Ghee', query: 'valona'),
          _MegaMenuItem(title: 'View All Bilona Ghee →', query: 'ghee'),
        ],
      ),
      _MegaMenuSection(
        title: 'FRESH LIVING DAIRY',
        items: [
          _MegaMenuItem(title: 'Fresh Malai Paneer', query: 'paneer'),
          _MegaMenuItem(title: 'A2 Gir Cow Chilled Raw Milk', query: 'milk'),
          _MegaMenuItem(title: 'Cultured White Makhan', query: 'makhan'),
          _MegaMenuItem(title: 'Fresh Murrah Buffalo Curd', query: 'curd'),
          _MegaMenuItem(title: 'View All Fresh Dairy →'),
        ],
      ),
      _MegaMenuSection(
        title: 'CULTURED & WELLNESS',
        items: [
          _MegaMenuItem(title: 'Spiced Probiotic Mattha', query: 'mattha'),
          _MegaMenuItem(title: 'Traditional Curd Chillies', query: 'chilli'),
          _MegaMenuItem(title: '100x Washed Ghee Cream', query: 'shata dhauta'),
          _MegaMenuItem(title: 'Goat Milk & Honey Soap', query: 'soap'),
        ],
      ),
    ],
  ),
  _MegaMenuCategory(
    id: 'oils',
    name: 'Wood-Pressed Oils & Heritage',
    icon: '🪵',
    filterCategory: 'Wood-Pressed Oils & Pure Sweeteners',
    sections: [
      _MegaMenuSection(
        title: 'MUSTARD OILS (KOLHU)',
        items: [
          _MegaMenuItem(title: 'Black Mustard Oil (Lakdi Ghani)', query: 'mustard'),
          _MegaMenuItem(title: 'Cold-Pressed Yellow Mustard Oil', query: 'yellow'),
          _MegaMenuItem(title: '2L Heritage Tin Mustard Oil', query: 'tin mustard'),
          _MegaMenuItem(title: '5L Wood Kolhu Canister', query: '5L'),
          _MegaMenuItem(title: 'View All Mustard Oils →', query: 'mustard'),
        ],
      ),
      _MegaMenuSection(
        title: 'COLD-PRESSED SEED OILS',
        items: [
          _MegaMenuItem(title: 'Black Sesame (Til) Oil', query: 'sesame'),
          _MegaMenuItem(title: 'Groundnut (Peanut) Oil', query: 'peanut'),
          _MegaMenuItem(title: 'Virgin Cold-Pressed Coconut Oil', query: 'coconut'),
          _MegaMenuItem(title: 'View All Seed Oils →'),
        ],
      ),
      _MegaMenuSection(
        title: 'HERITAGE SWEETENERS',
        items: [
          _MegaMenuItem(title: 'Organic Desi Khand', query: 'khand'),
          _MegaMenuItem(title: 'Heirloom Sugarcane Jaggery', query: 'jaggery'),
          _MegaMenuItem(title: 'Liquid Kakvi (Molasses)', query: 'kakvi'),
        ],
      ),
    ],
  ),
  _MegaMenuCategory(
    id: 'microgreens',
    name: 'Fresh Living Harvest (Greens)',
    icon: '🌱',
    filterCategory: 'Fresh Living Harvest (Microgreens)',
    sections: [
      _MegaMenuSection(
        title: 'LIVE MICROGREEN TRAYS',
        items: [
          _MegaMenuItem(title: 'Live Radish Microgreens (Mooli)', query: 'radish'),
          _MegaMenuItem(title: 'Sunflower Protein Crunch Trays', query: 'sunflower'),
          _MegaMenuItem(title: 'Sweet Pea Shoots (Kids Favorite)', query: 'pea'),
          _MegaMenuItem(title: 'Broccoli & Mustard Detox Trays', query: 'broccoli'),
          _MegaMenuItem(title: 'View All Microgreens →'),
        ],
      ),
      _MegaMenuSection(
        title: 'LIVING SALADS & COMBOS',
        items: [
          _MegaMenuItem(title: 'Weekly Living Salad Box', query: 'salad'),
          _MegaMenuItem(title: 'Detox & Immunity Living Trio', query: 'detox'),
          _MegaMenuItem(title: 'Living Herb & Garnish Punnets', query: 'punnet'),
        ],
      ),
    ],
  ),
  _MegaMenuCategory(
    id: 'flours',
    name: 'Stone-Ground Chakki Atta',
    icon: '🌾',
    filterCategory: 'Stone-Ground Chakki Atta & Flours',
    sections: [
      _MegaMenuSection(
        title: 'HEIRLOOM CHAKKI ATTA',
        items: [
          _MegaMenuItem(title: 'Khapli Emmer Atta (Low GI)', query: 'khapli'),
          _MegaMenuItem(title: 'Sharbati Whole Wheat Atta', query: 'sharbati'),
          _MegaMenuItem(title: 'Multi-Millet Diabetic Superblend', query: 'millet'),
          _MegaMenuItem(title: 'Clay-Oven Roasted Chana Sattu', query: 'sattu'),
          _MegaMenuItem(title: 'View All Atta & Flours →'),
        ],
      ),
      _MegaMenuSection(
        title: 'NATIVE GRAINS & PULSES',
        items: [
          _MegaMenuItem(title: 'Unpolished Desi Dal', query: 'dal'),
          _MegaMenuItem(title: 'Foxtail & Little Millet', query: 'millet'),
          _MegaMenuItem(title: 'Bansi Durum Wheat Sooji', query: 'sooji'),
        ],
      ),
    ],
  ),
  _MegaMenuCategory(
    id: 'spices',
    name: 'Terroir Salts & Native Spices',
    icon: '🧂',
    filterCategory: 'Terroir Salts & Native Spices',
    sections: [
      _MegaMenuSection(
        title: 'TERROIR HIMALAYAN SALTS',
        items: [
          _MegaMenuItem(title: 'Himalayan Pink Salt (Sendha)', query: 'pink salt'),
          _MegaMenuItem(title: 'Wild Harad Black Salt Powder', query: 'black salt'),
          _MegaMenuItem(title: 'Natural Rock Salt Crystals', query: 'salt'),
          _MegaMenuItem(title: 'View All Terroir Salts →', query: 'salt'),
        ],
      ),
      _MegaMenuSection(
        title: 'HEIRLOOM WHOLE SPICES',
        items: [
          _MegaMenuItem(title: 'High-Curcumin Turmeric (>5% Haldi)', query: 'turmeric'),
          _MegaMenuItem(title: 'Patan Whole Cumin (Jeera)', query: 'jeera'),
          _MegaMenuItem(title: 'Guntur Whole Dhania (Coriander)', query: 'dhania'),
          _MegaMenuItem(title: 'Mathania Sun-Dried Chillies', query: 'mathania'),
        ],
      ),
    ],
  ),
  _MegaMenuCategory(
    id: 'balcony',
    name: 'Balcony Garden & Living Soil',
    icon: '🪴',
    filterCategory: 'Apartment Balcony & Living Soil',
    sections: [
      _MegaMenuSection(
        title: 'LIVING SOIL & BIO-INPUTS',
        items: [
          _MegaMenuItem(title: 'Odorless Granular Vermicompost', query: 'vermicompost'),
          _MegaMenuItem(title: 'Balcony Potting Booster Mix', query: 'potting'),
          _MegaMenuItem(title: 'Tamba Chhachh Copper Bio-Spray', query: 'spray'),
          _MegaMenuItem(title: 'Heirloom 5-in-1 Seed Kit', query: 'seeds'),
        ],
      ),
      _MegaMenuSection(
        title: 'PURE ALOE & BOTANICALS',
        items: [
          _MegaMenuItem(
              title: 'Pure Aloe Inner-Leaf Gel (99%)',
              category: 'Pure Aloe Vera & Living Botanicals',
              query: 'aloe gel'),
          _MegaMenuItem(
              title: 'Raw Digestive Aloe Juice',
              category: 'Pure Aloe Vera & Living Botanicals',
              query: 'aloe juice'),
          _MegaMenuItem(
              title: 'Live Balcony Aloe Plant',
              category: 'Pure Aloe Vera & Living Botanicals',
              query: 'aloe plant'),
        ],
      ),
    ],
  ),
  _MegaMenuCategory(
    id: 'sacred',
    name: 'Curated Boxes & Sacred Hawan',
    icon: '🎁',
    filterCategory: 'Curated Kitchen & Wellness Boxes',
    sections: [
      _MegaMenuSection(
        title: 'CURATED GIFT BOXES',
        items: [
          _MegaMenuItem(title: "'The Clean Kitchen' Starter Box", query: 'kitchen'),
          _MegaMenuItem(title: "'Living Balcony' Herb Kit", query: 'balcony'),
          _MegaMenuItem(title: "'Daily Gut Health' Probiotic Duo", query: 'gut health'),
          _MegaMenuItem(title: 'Traditional Vedic Bilona Trio', query: 'bilona'),
        ],
      ),
      _MegaMenuSection(
        title: 'SACRED PUJA & HAWAN',
        items: [
          _MegaMenuItem(
              title: 'Pure Desi Cow Hawan Ghee',
              category: 'Puja & Hawan Samagri',
              query: 'hawan ghee'),
          _MegaMenuItem(
              title: 'Vedic Cow Dung Cakes (Hawan Kanda)',
              category: 'Puja & Hawan Samagri',
              query: 'kanda'),
          _MegaMenuItem(
              title: 'Handcrafted Cow Dung Diyas',
              category: 'Puja & Hawan Samagri',
              query: 'diya'),
          _MegaMenuItem(
              title: 'Charcoal-Free Agarbatti',
              category: 'Natural Agarbatti & Dhoop',
              query: 'agarbatti'),
          _MegaMenuItem(
              title: 'Panchagavya Dhoop Cones',
              category: 'Natural Agarbatti & Dhoop',
              query: 'dhoop'),
        ],
      ),
    ],
  ),
];

class CategoryMegaMenuOverlay extends StatefulWidget {
  const CategoryMegaMenuOverlay({
    super.key,
    this.anchorOffset,
    this.anchorSize,
    this.onClose,
    this.onHoverEnter,
    this.onHoverExit,
  });

  final Offset? anchorOffset;
  final Size? anchorSize;
  final VoidCallback? onClose;
  final VoidCallback? onHoverEnter;
  final VoidCallback? onHoverExit;

  @override
  State<CategoryMegaMenuOverlay> createState() =>
      _CategoryMegaMenuOverlayState();
}

class _CategoryMegaMenuOverlayState
    extends State<CategoryMegaMenuOverlay> {
  int _selectedCategoryIndex = 0;

  void _dismiss() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final activeCat = _megaMenuCategories[
        _selectedCategoryIndex.clamp(0, _megaMenuCategories.length - 1)];

    final double top =
        (widget.anchorOffset != null && widget.anchorSize != null)
            ? widget.anchorOffset!.dy + widget.anchorSize!.height + 2
            : 106.0;

    final double buttonLeft = widget.anchorOffset?.dx ?? 16.0;
    final double menuWidth = math.min(screenSize.width - 32.0, 960.0);
    double menuLeft = buttonLeft;
    if (menuLeft + menuWidth > screenSize.width - 16.0) {
      menuLeft = math.max(16.0, screenSize.width - menuWidth - 16.0);
    }

    return Stack(
      children: [
        // Barrier tap to dismiss
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: Container(
              color: Colors.black.withValues(alpha: 0.18),
            ),
          ),
        ),

        // Anchored dropdown menu container directly below the "Shop By Category" button
        Positioned(
          top: top,
          left: menuLeft,
          width: menuWidth,
          child: MouseRegion(
            onEnter: (_) => widget.onHoverEnter?.call(),
            onExit: (_) => widget.onHoverExit?.call(),
            child: Material(
              elevation: 16,
              shadowColor: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: Container(
                constraints: const BoxConstraints(
                  maxHeight: 460,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffe5e7eb)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT SIDEBAR: Categories with '>' indicator
                    Container(
                      width: 250,
                      color: const Color(0xfff8fafc),
                      child: Column(
                        children: [
                            // Header label
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(18, 14, 18, 10),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0xffe2e8f0)),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.grid_view_rounded,
                                      size: 16, color: Color(0xff0d9488)),
                                  SizedBox(width: 8),
                                  Text(
                                    'DEPARTMENTS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xff64748b),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Category items list
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: _megaMenuCategories.length,
                                itemBuilder: (context, index) {
                                  final cat = _megaMenuCategories[index];
                                  final isSelected =
                                      index == _selectedCategoryIndex;

                                  return MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) {
                                      setState(
                                          () => _selectedCategoryIndex = index);
                                    },
                                    child: InkWell(
                                      onTap: () {
                                        setState(
                                            () => _selectedCategoryIndex = index);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 11),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.transparent,
                                          border: Border(
                                            left: BorderSide(
                                              color: isSelected
                                                  ? const Color(0xff0d9488)
                                                  : Colors.transparent,
                                              width: 3.5,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              cat.icon,
                                              style:
                                                  const TextStyle(fontSize: 15),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                cat.name,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: isSelected
                                                      ? const Color(0xff0d9488)
                                                      : const Color(0xff334155),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              size: 15,
                                              color: isSelected
                                                  ? const Color(0xff0d9488)
                                                  : const Color(0xff94a3b8),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Quick bottom shortcuts
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: const BoxDecoration(
                                color: Color(0xfff1f5f9),
                                border: Border(
                                  top: BorderSide(color: Color(0xffe2e8f0)),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      _dismiss();
                                      storeBrowse(context, sort: 'Best Sellers');
                                    },
                                    child: const Text(
                                      '★ Best Sellers',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xff0d9488),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      _dismiss();
                                      context.go('/marketplace');
                                    },
                                    child: const Text(
                                      '🚜 Machinery →',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xff475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // RIGHT PANEL: Multi-Column Sections for Active Category
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Title & Close Header Bar
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 14, 16, 12),
                                child: Row(
                                  children: [
                                    Text(
                                      activeCat.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xff0f172a),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    InkWell(
                                      onTap: () {
                                        _dismiss();
                                        storeBrowse(context,
                                            category: activeCat.filterCategory);
                                      },
                                      child: const Text(
                                        'View All →',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xff0d9488),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          size: 18, color: Color(0xff64748b)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 18,
                                      tooltip: 'Close Menu',
                                      onPressed: _dismiss,
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xfff1f5f9)),

                              // Multi-column sections
                              Expanded(
                                child: SingleChildScrollView(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 18, 24, 20),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: activeCat.sections.map((sec) {
                                      return Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 20),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Section title
                                              Text(
                                                sec.title,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xff1e293b),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              const SizedBox(height: 10),

                                              // Small, compact items
                                              ...sec.items.map((item) {
                                                return _MegaMenuItemWidget(
                                                  item: item,
                                                  defaultCategory:
                                                      activeCat.filterCategory,
                                                  onTap: _dismiss,
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MegaMenuItemWidget extends StatefulWidget {
  final _MegaMenuItem item;
  final String defaultCategory;
  final VoidCallback onTap;

  const _MegaMenuItemWidget({
    required this.item,
    required this.defaultCategory,
    required this.onTap,
  });

  @override
  State<_MegaMenuItemWidget> createState() => _MegaMenuItemWidgetState();
}

class _MegaMenuItemWidgetState extends State<_MegaMenuItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          widget.onTap();
          storeBrowse(
            context,
            category: widget.item.category ?? widget.defaultCategory,
            query: widget.item.query,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.5),
          child: Text(
            widget.item.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w400,
              color: _isHovered
                  ? const Color(0xff0d9488)
                  : const Color(0xff475569),
            ),
          ),
        ),
      ),
    );
  }
}

class CategoryMobileDrawer extends ConsumerStatefulWidget {
  const CategoryMobileDrawer({super.key});

  @override
  ConsumerState<CategoryMobileDrawer> createState() =>
      _CategoryMobileDrawerState();
}

class _CategoryMobileDrawerState
    extends ConsumerState<CategoryMobileDrawer> {
  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final activeCat = _megaMenuCategories[
        _selectedCategoryIndex.clamp(0, _megaMenuCategories.length - 1)];

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(300.0, 390.0),
          height: double.infinity,
          child: Column(
            children: [
              // Forest Green User / Sign-In Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                color: const Color(0xff1b4d3e),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          if (user != null) {
                            context.push('/profile');
                          } else {
                            context.go('/login?next=/shop');
                          }
                        },
                        child: const CircleAvatar(
                          radius: 15,
                          backgroundColor: Color(0xff143d31),
                          child:
                              Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            if (user != null) {
                              context.push('/profile');
                            } else {
                              context.go('/login?next=/shop');
                            }
                          },
                          child: Text(
                            user != null
                                ? 'Hello, ${user.name?.split(' ').first ?? 'Customer'}'
                                : 'Hello, Sign in',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close Menu',
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),

              // Two-pane Category / Section Body
              Expanded(
                child: Row(
                  children: [
                    // Left narrow category tabs
                    Container(
                      width: 110,
                      color: const Color(0xfff1f5f9),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _megaMenuCategories.length,
                        itemBuilder: (context, idx) {
                          final cat = _megaMenuCategories[idx];
                          final isSelected = idx == _selectedCategoryIndex;
                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedCategoryIndex = idx),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    color: isSelected
                                        ? const Color(0xff0d9488)
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cat.icon,
                                      style: const TextStyle(fontSize: 18)),
                                  const SizedBox(height: 4),
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xff0d9488)
                                          : const Color(0xff334155),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Right sections list
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: ListView(
                          padding: const EdgeInsets.all(14),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    activeCat.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xff0f172a),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    storeBrowse(context,
                                        category: activeCat.filterCategory);
                                  },
                                  child: const Text(
                                    'All →',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xff0d9488),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...activeCat.sections.map((sec) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sec.title,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xff1e293b),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...sec.items.map((item) {
                                      return InkWell(
                                        onTap: () {
                                          Navigator.pop(context);
                                          storeBrowse(
                                            context,
                                            category: item.category ??
                                                activeCat.filterCategory,
                                            query: item.query,
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xff475569),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Mobile bottom footer: Account & Settings
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xfff8fafc),
                  border: Border(top: BorderSide(color: Color(0xffe2e8f0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        storeAccountRoute(context, ref, '/marketplace/orders');
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Your Orders',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff334155),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        storeAccountRoute(context, ref, '/wishlist');
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Wishlist',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff334155),
                          ),
                        ),
                      ),
                    ),
                    if (user != null)
                      InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) context.go('/shop');
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xffdc2626),
                            ),
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/login?next=/shop');
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff0d9488),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
