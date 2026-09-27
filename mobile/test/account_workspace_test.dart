import 'package:dairy_ai/features/marketplace/widgets/account_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sections mount lazily and preserve scroll when revisited',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = AccountSection.overview;
    final mounts = <AccountSection, int>{};
    await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
      builder: (context, setState) => Scaffold(
          body: AccountWorkspace(
        section: selected,
        name: 'Test customer',
        onShop: () {},
        onSignOut: () {},
        onSelect: (value) => setState(() => selected = value),
        panelBuilder: (value) => _Panel(section: value, mounts: mounts),
      )),
    )));
    expect(mounts, {AccountSection.overview: 1});
    await tester.tap(find.byKey(const ValueKey('account-nav-orders')));
    await tester.pumpAndSettle();
    final orders = find.byKey(const ValueKey('panel-orders'));
    await tester.drag(orders, const Offset(0, -500));
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(find
            .descendant(of: orders, matching: find.byType(Scrollable))
            .first)
        .position
        .pixels;
    expect(scroll, greaterThan(0));
    await tester.tap(find.byKey(const ValueKey('account-nav-addresses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-nav-orders')));
    await tester.pumpAndSettle();
    expect(mounts[AccountSection.orders], 1);
    expect(mounts.containsKey(AccountSection.wallet), isFalse);
    expect(
        tester
            .state<ScrollableState>(find
                .descendant(of: orders, matching: find.byType(Scrollable))
                .first)
            .position
            .pixels,
        scroll);
    await tester.tap(find.byKey(const ValueKey('back-to-account')));
    await tester.pumpAndSettle();
    expect(selected, AccountSection.overview);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile has an in-place selector and explicit return to account',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = AccountSection.overview;
    await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
      builder: (context, setState) => Scaffold(
          body: AccountWorkspace(
        section: selected,
        name: 'Test customer',
        onShop: () {},
        onSignOut: () {},
        onSelect: (value) => setState(() => selected = value),
        panelBuilder: (value) => Center(child: Text('Panel ${value.name}')),
      )),
    )));
    await tester.tap(find.byKey(const ValueKey('account-selector-overview')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delivery addresses').last);
    await tester.pumpAndSettle();
    expect(find.text('Panel addresses'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('back-to-account')));
    await tester.pumpAndSettle();
    expect(find.text('Panel overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Panel extends StatefulWidget {
  const _Panel({required this.section, required this.mounts});
  final AccountSection section;
  final Map<AccountSection, int> mounts;
  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  @override
  void initState() {
    super.initState();
    widget.mounts.update(widget.section, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
        key: ValueKey('panel-${widget.section.name}'),
        itemExtent: 50,
        itemCount: 60,
        itemBuilder: (_, i) => Text('${widget.section.name} row $i'),
      );
}
