class TaxonomyNode {
  const TaxonomyNode(
      {required this.id,
      required this.kind,
      required this.name,
      required this.slug,
      this.parentId,
      this.description = '',
      this.sortOrder = 0,
      this.isActive = true,
      this.version = 1});
  final String id, kind, name, slug, description;
  final String? parentId;
  final int sortOrder, version;
  final bool isActive;
  factory TaxonomyNode.fromJson(Map<String, dynamic> j) => TaxonomyNode(
      id: (j['id'] ?? '').toString(),
      kind: (j['kind'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      slug: (j['slug'] ?? '').toString(),
      parentId: j['parent_id']?.toString(),
      description: (j['description'] ?? '').toString(),
      sortOrder: j['sort_order'] is int
          ? (j['sort_order'] as int)
          : (int.tryParse('${j['sort_order']}') ?? 0),
      isActive: j['is_active'] != false,
      version: j['version'] is int
          ? (j['version'] as int)
          : (int.tryParse('${j['version']}') ?? 1));
  Map<String, dynamic> editableFields() => {
        'name': name,
        'slug': slug,
        'description': description,
        'parent_id': parentId,
        'sort_order': sortOrder,
        'is_active': isActive
      };
}

class TaxonomyCatalogue {
  const TaxonomyCatalogue({required this.enabled, required this.nodes});
  final bool enabled;
  final List<TaxonomyNode> nodes;

  List<TaxonomyNode> get departments =>
      nodes.where((n) => n.kind == 'department' && n.isActive).toList();

  List<TaxonomyNode> categoriesFor(String? departmentId) {
    if (departmentId == null) return const [];
    return nodes
        .where((n) => n.kind == 'category' && n.parentId == departmentId && n.isActive)
        .toList();
  }

  List<TaxonomyNode> subcategoriesFor(String? categoryId) {
    if (categoryId == null) return const [];
    return nodes
        .where((n) => n.kind == 'subcategory' && n.parentId == categoryId && n.isActive)
        .toList();
  }

  TaxonomyNode? findNode(String? idOrSlug) {
    if (idOrSlug == null || idOrSlug.isEmpty) return null;
    final lower = idOrSlug.toLowerCase();
    return nodes
        .where((n) => n.id == idOrSlug || n.slug.toLowerCase() == lower)
        .firstOrNull;
  }

  Set<String> descendants(String id) {
    final ids = <String>{id};
    for (var i = 0; i < nodes.length; i++) {
      ids.addAll(nodes.where((n) => ids.contains(n.parentId)).map((n) => n.id));
    }
    return ids;
  }
}
