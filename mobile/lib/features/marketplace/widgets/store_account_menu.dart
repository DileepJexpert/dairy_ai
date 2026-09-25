import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/store_theme.dart';

/// Rich customer menu shared by the desktop header and compact layouts.
class StoreAccountMenu extends StatefulWidget {
  const StoreAccountMenu({
    super.key,
    required this.compact,
    required this.signedIn,
    required this.firstName,
    required this.cartCount,
    required this.wishlistCount,
    required this.onNavigate,
    required this.onSignOut,
  });

  final bool compact;
  final bool signedIn;
  final String firstName;
  final int cartCount;
  final int wishlistCount;
  final ValueChanged<String> onNavigate;
  final VoidCallback onSignOut;

  @override
  State<StoreAccountMenu> createState() => _StoreAccountMenuState();
}

class _StoreAccountMenuState extends State<StoreAccountMenu> {
  final MenuController _controller = MenuController();
  Timer? _closeTimer;

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  void _openOnHover(PointerEnterEvent _) {
    _closeTimer?.cancel();
    if (!widget.compact && !_controller.isOpen) _controller.open();
  }

  void _scheduleClose(PointerExitEvent _) {
    if (widget.compact) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) _controller.close();
    });
  }

  void _navigate(String destination) {
    _closeTimer?.cancel();
    _controller.close();
    widget.onNavigate(destination);
  }

  void _signOut() {
    _closeTimer?.cancel();
    _controller.close();
    widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 24;
    final menuWidth = math.min(widget.compact ? 344.0 : 860.0, availableWidth);
    final menuHeight = math.max(280.0, MediaQuery.sizeOf(context).height - 110);
    return MenuAnchor(
      controller: _controller,
      style: MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        backgroundColor: const WidgetStatePropertyAll(storeWhite),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: storeBorder),
        )),
        elevation: const WidgetStatePropertyAll(12),
      ),
      menuChildren: [
        MouseRegion(
          onEnter: (_) => _closeTimer?.cancel(),
          onExit: _scheduleClose,
          child: SizedBox(
            width: menuWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: menuHeight),
              child: SingleChildScrollView(
                primary: false,
                child: widget.signedIn ? _signedInPanel() : _guestPanel(),
              ),
            ),
          ),
        ),
      ],
      child: MouseRegion(
        onEnter: _openOnHover,
        onExit: _scheduleClose,
        child: InkWell(
          key: const ValueKey('store-account-menu'),
          onTap: () {
            _closeTimer?.cancel();
            if (_controller.isOpen) {
              _controller.close();
            } else {
              _controller.open();
            }
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: widget.compact
                ? const Icon(Icons.person_outline, color: storeWhite, size: 24)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.signedIn
                            ? 'Hello, ${widget.firstName}'
                            : 'Hello, sign in',
                        style: StoreType.amazonTopLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text('Account & Lists ▾',
                          style: StoreType.amazonBottomLine),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _signedInPanel() {
    final shopping = [
      const _AccountLink(
          'Your orders', Icons.inventory_2_outlined, '/marketplace/orders'),
      const _AccountLink('Returns & cancellations',
          Icons.assignment_return_outlined, '/marketplace/orders'),
      _AccountLink(
          'Your cart${widget.cartCount > 0 ? ' (${widget.cartCount})' : ''}',
          Icons.shopping_cart_outlined,
          '/marketplace/cart'),
      const _AccountLink('Browse products', Icons.storefront_outlined, '/shop'),
      const _AccountLink(
          'Offers & deals', Icons.local_offer_outlined, '/shop/deals'),
    ];
    final lists = [
      _AccountLink(
          'Wishlist${widget.wishlistCount > 0 ? ' (${widget.wishlistCount})' : ''}',
          Icons.favorite_border,
          '/wishlist'),
      const _AccountLink(
          'Saved for later', Icons.bookmark_border, '/marketplace/cart'),
    ];
    final account = [
      const _AccountLink(
          'Account overview', Icons.dashboard_outlined, '/account'),
      const _AccountLink('Delivery addresses', Icons.location_on_outlined,
          '/marketplace/addresses'),
      const _AccountLink('Your profile', Icons.person_outline, '/profile'),
      const _AccountLink('Wallet & history',
          Icons.account_balance_wallet_outlined, '/balance'),
      const _AccountLink('Help & support', Icons.help_outline, '/help'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: storeSage,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: storeGreen,
                child: Icon(Icons.person_outline, color: storeWhite),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hello, ${widget.firstName}',
                        style: const TextStyle(
                            color: storeGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    const Text('Your Milterra account',
                        style: TextStyle(color: storeMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (!widget.compact)
                TextButton.icon(
                  onPressed: () => _navigate('/account'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Manage account'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          child: widget.compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('Your shopping', shopping),
                    const Divider(height: 24),
                    _section('Your lists', lists),
                    const Divider(height: 24),
                    _section('Your account', account),
                    const Divider(height: 16),
                    _signOutLink(),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _section('Your shopping', shopping)),
                    const SizedBox(height: 350, child: VerticalDivider()),
                    Expanded(child: _section('Your lists', lists)),
                    const SizedBox(height: 350, child: VerticalDivider()),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section('Your account', account),
                          const Divider(height: 16),
                          _signOutLink(),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _guestPanel() => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Welcome to Milterra',
                style: TextStyle(
                    color: storeGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 6),
            const Text('Sign in to view your orders, lists, and addresses.',
                style: TextStyle(color: storeMuted)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => _navigate('/login?next=/account'),
              child: const Text('Sign in'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _navigate('/register?next=/account'),
              child: const Text('Create account'),
            ),
            const Divider(height: 26),
            _link(const _AccountLink(
                'Browse products', Icons.storefront_outlined, '/shop')),
          ],
        ),
      );

  Widget _section(String title, List<_AccountLink> links) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Text(title,
                style: const TextStyle(
                    color: storeGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
          for (final link in links) _link(link),
        ],
      );

  Widget _link(_AccountLink link) => InkWell(
        key: ValueKey('account-menu-${link.destination}-${link.title}'),
        onTap: () => _navigate(link.destination),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(link.icon, color: storeGreen, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(link.title,
                    style: const TextStyle(color: storeGreen, fontSize: 13)),
              ),
            ],
          ),
        ),
      );

  Widget _signOutLink() => InkWell(
        key: const ValueKey('account-menu-signout'),
        onTap: _signOut,
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.logout, color: storeGreen, size: 18),
              SizedBox(width: 9),
              Text('Sign out',
                  style: TextStyle(color: storeGreen, fontSize: 13)),
            ],
          ),
        ),
      );
}

class _AccountLink {
  const _AccountLink(this.title, this.icon, this.destination);
  final String title;
  final IconData icon;
  final String destination;
}
