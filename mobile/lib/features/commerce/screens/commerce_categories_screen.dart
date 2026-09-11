import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../marketplace/widgets/store_design.dart';
import '../models/taxonomy.dart';
import '../providers/commerce_provider.dart';

/// First commerce-admin slice. Uses server permissions, not a client role picker.
class CommerceCategoriesScreen extends ConsumerWidget {
  const CommerceCategoriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
            title: const Text('Milterra · Commerce admin'),
            leading: IconButton(
                tooltip: 'Back to shop',
                onPressed: () => context.go('/shop'),
                icon: const Icon(Icons.storefront_outlined)),
            actions: [
              TextButton.icon(
                onPressed: () => context.go('/admin/commerce/products'),
                icon: const Icon(Icons.inventory_2_outlined, color: storeAmber, size: 18),
                label: const Text('Products & Stock', style: TextStyle(color: storeWhite)),
              ),
              TextButton.icon(
                onPressed: () => context.go('/admin/commerce/orders'),
                icon: const Icon(Icons.local_shipping_outlined, color: storeAmber, size: 18),
                label: const Text('Orders & Shipments', style: TextStyle(color: storeWhite)),
              ),
              const SizedBox(width: 12),
            ]),
        body: ref.watch(commerceAccessProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _accessMessage(context, ref,
                  'Could not verify access. Sign in again or retry.'),
              data: (access) {
                if (access['can_manage_taxonomy'] != true) {
                  return _accessMessage(context, ref,
                      'Commerce administration requires an authorized staff account.');
                }
                if (access['taxonomy_enabled'] != true) {
                  return const Center(
                      child: Padding(
                          padding: StoreLayout.panelPadding,
                          child: Text(
                              'Category management is not enabled. Follow the local database rebuild guide, then enable COMMERCE_TAXONOMY_ENABLED on the backend.',
                              style: StoreType.body)));
                }
                return ref.watch(adminTaxonomyProvider).when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _accessMessage(
                          context,
                          ref,
                          e is DioException
                              ? dioErrorMessage(e)
                              : 'Could not load categories.'),
                      data: (nodes) => Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: StoreLayout.maxWidth),
                              child: ListView(
                                  padding: StoreLayout.panelPadding,
                                  children: [
                                    const Text('Departments & categories',
                                        style: StoreType.heading),
                                    const SizedBox(height: StoreLayout.xs),
                                    const Text(
                                        'Organize the public shop. Changes are audited; archiving does not delete products or orders.',
                                        style: StoreType.muted),
                                    StoreLayout.panelGap,
                                    Wrap(
                                        spacing: StoreLayout.sm,
                                        runSpacing: StoreLayout.sm,
                                        children: [
                                          FilledButton.icon(
                                              onPressed: () => _edit(
                                                  context, ref, nodes,
                                                  kind: 'department'),
                                              icon: const Icon(Icons.add),
                                              label:
                                                  const Text('Add department')),
                                          OutlinedButton.icon(
                                              onPressed:
                                                  nodes.any((n) => n.isActive)
                                                      ? () => _edit(
                                                          context, ref, nodes,
                                                          kind: 'category')
                                                      : null,
                                              icon: const Icon(Icons.add),
                                              label:
                                                  const Text('Add category')),
                                          TextButton.icon(
                                              onPressed: () {
                                                ref.invalidate(
                                                    adminTaxonomyProvider);
                                                ref.invalidate(
                                                    taxonomyProvider);
                                              },
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Refresh')),
                                        ]),
                                    StoreLayout.panelGap,
                                    if (nodes.isEmpty)
                                      const StorePanel(
                                          child: Text(
                                              'Start by adding a department.',
                                              style: StoreType.body)),
                                    for (final node in nodes)
                                      Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: StoreLayout.sm),
                                          child: StorePanel(
                                              child: Row(children: [
                                            Icon(
                                                node.kind == 'department'
                                                    ? Icons.storefront_outlined
                                                    : Icons.category_outlined,
                                                color: node.isActive
                                                    ? storeGreen
                                                    : storeMuted),
                                            const SizedBox(
                                                width: StoreLayout.md),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(node.name,
                                                      style:
                                                          StoreType.cardTitle),
                                                  Text(
                                                      '${node.kind} · ${node.slug} · Order ${node.sortOrder} · ${node.isActive ? 'Active' : 'Archived'}',
                                                      style: StoreType.muted),
                                                  if (node.parentId != null)
                                                    Text(
                                                        'Parent: ${_parentLabel(nodes, node.parentId)}',
                                                        style: StoreType.muted),
                                                ])),
                                            IconButton(
                                                tooltip: 'Edit ${node.name}',
                                                onPressed: () => _edit(
                                                    context, ref, nodes,
                                                    node: node,
                                                    kind: node.kind),
                                                icon: const Icon(
                                                    Icons.edit_outlined)),
                                          ]))),
                                  ]))),
                    );
              },
            ),
      );

  String _parentLabel(List<TaxonomyNode> nodes, String? id) =>
      nodes.where((n) => n.id == id).map((n) => n.name).firstOrNull ??
      'Unknown';
  Widget _accessMessage(BuildContext context, WidgetRef ref, String message) =>
      Center(
          child: Padding(
              padding: StoreLayout.panelPadding,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(message, style: StoreType.body),
                StoreLayout.panelGap,
                OutlinedButton(
                    onPressed: () {
                      ref.invalidate(commerceAccessProvider);
                      ref.invalidate(adminTaxonomyProvider);
                    },
                    child: const Text('Retry')),
                TextButton(
                    onPressed: () => context.go('/login?next=/admin/commerce'),
                    child: const Text('Sign in'))
              ])));

  Future<void> _edit(
      BuildContext context, WidgetRef ref, List<TaxonomyNode> nodes,
      {TaxonomyNode? node, required String kind}) async {
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CategoryEditor(nodes: nodes, node: node, kind: kind));
    if (saved == true) {
      ref.invalidate(adminTaxonomyProvider);
      ref.invalidate(taxonomyProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Category saved. Public navigation will use the updated taxonomy.')));
      }
    }
  }
}

class _CategoryEditor extends ConsumerStatefulWidget {
  const _CategoryEditor({required this.nodes, required this.kind, this.node});
  final List<TaxonomyNode> nodes;
  final String kind;
  final TaxonomyNode? node;
  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _slug, _description, _order;
  String? _parent, _error;
  late bool _active;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.node?.name ?? '');
    _slug = TextEditingController(text: widget.node?.slug ?? '');
    _description = TextEditingController(text: widget.node?.description ?? '');
    _order = TextEditingController(text: '${widget.node?.sortOrder ?? 0}');
    _parent = widget.node?.parentId;
    _active = widget.node?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _description.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final data = {
      'name': _name.text.trim(),
      'slug': _slug.text.trim(),
      'description': _description.text.trim(),
      'parent_id': widget.kind == 'department' ? null : _parent,
      'sort_order': int.parse(_order.text),
      'is_active': _active
    };
    try {
      final dio = ref.read(dioProvider);
      if (widget.node == null) {
        await dio.post('/admin/commerce/taxonomy',
            data: {...data, 'kind': widget.kind});
      } else {
        await dio.put('/admin/commerce/taxonomy/${widget.node!.id}',
            data: {...data, 'expected_version': widget.node!.version});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is DioException
              ? dioErrorMessage(e)
              : 'Could not save. Please try again.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final excluded = widget.node == null
        ? <String>{}
        : TaxonomyCatalogue(enabled: true, nodes: widget.nodes)
            .descendants(widget.node!.id);
    final parents =
        widget.nodes.where((n) => !excluded.contains(n.id)).toList();
    return PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: Text('${widget.node == null ? 'Add' : 'Edit'} ${widget.kind}'),
          content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextFormField(
                            controller: _name,
                            enabled: !_busy,
                            maxLength: 100,
                            decoration:
                                const InputDecoration(labelText: 'Name'),
                            validator: (v) => (v?.trim().length ?? 0) < 2
                                ? 'Enter at least two characters'
                                : null),
                        const SizedBox(height: StoreLayout.sm),
                        TextFormField(
                            controller: _slug,
                            enabled: !_busy,
                            maxLength: 120,
                            decoration: const InputDecoration(
                                labelText: 'URL slug',
                                hintText: 'animal-nutrition'),
                            validator: (v) =>
                                !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')
                                            .hasMatch(v?.trim() ?? '') ||
                                        (v?.trim().length ?? 0) < 2
                                    ? 'Use lowercase words separated by hyphens'
                                    : null),
                        const SizedBox(height: StoreLayout.sm),
                        if (widget.kind == 'category')
                          DropdownButtonFormField<String>(
                              initialValue: _parent,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Parent'),
                              items: parents
                                  .map((n) => DropdownMenuItem(
                                      value: n.id,
                                      child: Text('${n.name} (${n.kind})',
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: _busy
                                  ? null
                                  : (v) => setState(() => _parent = v),
                              validator: (v) =>
                                  v == null ? 'Choose a parent' : null),
                        const SizedBox(height: StoreLayout.sm),
                        TextFormField(
                            controller: _description,
                            enabled: !_busy,
                            maxLength: 500,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Description')),
                        const SizedBox(height: StoreLayout.sm),
                        TextFormField(
                            controller: _order,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Display order'),
                            validator: (v) {
                              final order = int.tryParse(v ?? '');
                              return order == null || order < 0 || order > 10000
                                  ? 'Enter 0 to 10000'
                                  : null;
                            }),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active'),
                            subtitle: const Text(
                                'Turn off to archive. Active children or products must be moved first.'),
                            value: _active,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _active = v)),
                        if (_error != null)
                          Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                      ])))),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save'))
          ],
        ));
  }
}
