import 'package:flutter/material.dart';
import 'store_design.dart';

enum AccountSection {
  overview('Overview', Icons.grid_view_outlined, 'Your account at a glance'),
  orders('Orders & returns', Icons.inventory_2_outlined,
      'Track and manage orders'),
  addresses('Delivery addresses', Icons.location_on_outlined,
      'Manage delivery details'),
  profile('Personal information', Icons.person_outline, 'Your account details'),
  wallet('Wallet & history', Icons.account_balance_wallet_outlined,
      'Balance and transactions'),
  wishlist('Wishlist', Icons.favorite_border, 'Products you want to keep'),
  help('Help & support', Icons.help_outline, 'Answers and contact options');

  const AccountSection(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;

  static AccountSection parse(String? value) => values
      .firstWhere((section) => section.name == value, orElse: () => overview);
}

/// Retains visited panels and their scroll positions. Unopened panels do not
/// mount or start requests. Section changes never replace the account frame.
class AccountWorkspace extends StatefulWidget {
  const AccountWorkspace(
      {super.key,
      required this.section,
      required this.onSelect,
      required this.panelBuilder,
      required this.name,
      required this.onShop,
      required this.onSignOut});

  final AccountSection section;
  final ValueChanged<AccountSection> onSelect;
  final Widget Function(AccountSection) panelBuilder;
  final String name;
  final VoidCallback onShop;
  final VoidCallback onSignOut;

  @override
  State<AccountWorkspace> createState() => _AccountWorkspaceState();
}

class _AccountWorkspaceState extends State<AccountWorkspace> {
  final _visited = <AccountSection>{};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.section);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1000;
      final panels = IndexedStack(
        index: widget.section.index,
        sizing: StackFit.expand,
        children: [
          for (final section in AccountSection.values)
            TickerMode(
              key: ValueKey(section),
              enabled: section == widget.section,
              child: _visited.contains(section)
                  ? widget.panelBuilder(section)
                  : const SizedBox.shrink(),
            ),
        ],
      );
      return Padding(
        padding: EdgeInsets.all(wide ? 24 : 12),
        child: Column(children: [
          Row(children: [
            TextButton.icon(
                onPressed: widget.onShop,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to shop')),
            const Spacer(),
            if (!wide)
              TextButton(
                  onPressed: widget.onSignOut, child: const Text('Sign out')),
          ]),
          const SizedBox(height: 12),
          Expanded(
              child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) ...[
                SizedBox(width: 250, child: _sidebar()),
                const SizedBox(width: 20),
              ],
              Expanded(
                  child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    color: storeWhite,
                    border: Border.all(color: storeBorder),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.section != AccountSection.overview)
                              TextButton.icon(
                                  key: const ValueKey('back-to-account'),
                                  onPressed: () =>
                                      widget.onSelect(AccountSection.overview),
                                  icon: const Icon(Icons.arrow_back, size: 16),
                                  label: const Text('Back to account')),
                            if (wide)
                              Text(widget.section.label,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: storeGreen))
                            else
                              DropdownButtonFormField<AccountSection>(
                                key: ValueKey(
                                    'account-selector-${widget.section.name}'),
                                initialValue: widget.section,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Account section',
                                    border: OutlineInputBorder()),
                                items: [
                                  for (final section in AccountSection.values)
                                    DropdownMenuItem(
                                        value: section,
                                        child: Text(section.label))
                                ],
                                onChanged: (value) {
                                  if (value != null) widget.onSelect(value);
                                },
                              ),
                          ],
                        )),
                    const Divider(height: 1),
                    Expanded(child: panels),
                  ],
                ),
              )),
            ],
          )),
        ]),
      );
    });
  }

  Widget _sidebar() => Material(
        color: storeWhite,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: storeBorder),
            borderRadius: BorderRadius.circular(14)),
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                      backgroundColor: storeGreen,
                      child: Icon(Icons.person_outline, color: storeWhite)),
                  const SizedBox(height: 12),
                  Text(widget.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: storeGreen)),
                  const Text('Your Milterra account',
                      style: TextStyle(color: storeMuted)),
                ],
              )),
          const Divider(),
          for (final section in AccountSection.values)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  key: ValueKey('account-nav-${section.name}'),
                  dense: true,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  selected: widget.section == section,
                  selectedTileColor: const Color(0xffeaf2ef),
                  selectedColor: storeGreen,
                  leading: Icon(section.icon, size: 20),
                  title: Text(section.label),
                  onTap: () => widget.onSelect(section),
                )),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.logout, size: 20),
              title: const Text('Sign out'),
              onTap: widget.onSignOut),
        ]),
      );
}
