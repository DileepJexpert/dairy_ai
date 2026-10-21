import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/feed/providers/feed_provider.dart' show dioProvider;

// ---------------------------------------------------------------------------
// Document Model
// ---------------------------------------------------------------------------

class FarmDoc {
  final String id;
  final String title;
  final String documentType;
  final String fileUrl;
  final String? fileName;
  final String? notes;
  final String date;
  final String? createdAt;

  const FarmDoc({
    required this.id,
    required this.title,
    required this.documentType,
    required this.fileUrl,
    this.fileName,
    this.notes,
    required this.date,
    this.createdAt,
  });

  factory FarmDoc.fromJson(Map<String, dynamic> json) {
    return FarmDoc(
      id: json['id'] as String,
      title: json['title'] as String,
      documentType: json['document_type'] as String? ?? 'other',
      fileUrl: json['file_url'] as String,
      fileName: json['file_name'] as String?,
      notes: json['notes'] as String?,
      date: json['date'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }

  String get typeLabel {
    switch (documentType) {
      case 'vaccination_chart':
        return '💉 Vaccination Chart';
      case 'rate_card':
        return '📈 Milk Rate Card';
      case 'feed_plan':
        return '🌾 Feed & Ration Plan';
      case 'lab_report':
        return '🔬 Lab Test Report';
      case 'cattle_certificate':
        return '📜 Pedigree Certificate';
      default:
        return '📄 Farm Document';
    }
  }

  Color get typeColor {
    switch (documentType) {
      case 'vaccination_chart':
        return const Color(0xff047857);
      case 'rate_card':
        return const Color(0xff1d4ed8);
      case 'feed_plan':
        return const Color(0xffb45309);
      case 'lab_report':
        return const Color(0xff7c3aed);
      default:
        return const Color(0xff475569);
    }
  }
}

// ---------------------------------------------------------------------------
// Documents Riverpod Provider
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Demo data fallbacks for offline and unauthenticated states.
// ---------------------------------------------------------------------------
final _demoFarmDocs = [
  const FarmDoc(
    id: 'doc-demo-1',
    title: 'ICAR Bovine Vaccination Protocol 2026',
    documentType: 'vaccination_chart',
    fileUrl: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800&auto=format&fit=crop&q=80',
    fileName: 'vaccination_schedule_2026.pdf',
    notes: 'National dairy animal vaccination calendar approved by NDDB',
    date: '2026-10-01',
  ),
  const FarmDoc(
    id: 'doc-demo-2',
    title: 'Standard Milk Fat & SNF Slab Rate Card',
    documentType: 'rate_card',
    fileUrl: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=800&auto=format&fit=crop&q=80',
    fileName: 'coop_rate_slab_card.pdf',
    notes: 'Official pricing table for cow milk (fat 3.5 - 5.0) and buffalo milk (fat 6.0 - 8.5)',
    date: '2026-10-05',
  ),
  const FarmDoc(
    id: 'doc-demo-3',
    title: 'Milterra Balanced Dairy Ration Chart',
    documentType: 'feed_plan',
    fileUrl: 'https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=800&auto=format&fit=crop&q=80',
    fileName: 'balanced_ration_chart.jpg',
    notes: 'Diet formulation chart for milking cows yielding 12-18 L/day',
    date: '2026-10-10',
  ),
  const FarmDoc(
    id: 'doc-demo-4',
    title: 'Milk Quality Somatic Cell Count (SCC) Lab Report',
    documentType: 'lab_report',
    fileUrl: 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=800&auto=format&fit=crop&q=80',
    fileName: 'bulk_tank_lab_analysis.pdf',
    notes: 'Grade A rating: SCC < 150,000 cells/ml. Mastitis negative.',
    date: '2026-10-14',
  ),
];

// ---------------------------------------------------------------------------
// Farm documents provider
// ---------------------------------------------------------------------------

final farmDocumentsProvider = FutureProvider.autoDispose
    .family<List<FarmDoc>, String?>((ref, typeFilter) async {
  try {
    final dio = ref.watch(dioProvider);
    final params = <String, dynamic>{};
    if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
      params['type'] = typeFilter;
    }
    final res = await dio.get('/farm/documents', queryParameters: params);
    final data = res.data as Map<String, dynamic>;
    if (data['success'] == true && data['data'] is List) {
      final list = (data['data'] as List)
          .map((e) => FarmDoc.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) return list;
    }
  } catch (_) {}
  if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
    return _demoFarmDocs.where((d) => d.documentType == typeFilter).toList();
  }
  return _demoFarmDocs;
});

// ---------------------------------------------------------------------------
// Farm Documents & Charts Screen
// ---------------------------------------------------------------------------

class FarmDocumentsScreen extends ConsumerStatefulWidget {
  const FarmDocumentsScreen({super.key});

  @override
  ConsumerState<FarmDocumentsScreen> createState() => _FarmDocumentsScreenState();
}

class _FarmDocumentsScreenState extends ConsumerState<FarmDocumentsScreen> {
  String _selectedCategory = 'all';

  final List<Map<String, String>> _categories = const [
    {'key': 'all', 'label': 'All Documents'},
    {'key': 'vaccination_chart', 'label': 'Vaccine Charts'},
    {'key': 'rate_card', 'label': 'Rate Cards'},
    {'key': 'feed_plan', 'label': 'Feed Plans'},
    {'key': 'lab_report', 'label': 'Lab Reports'},
  ];

  void _showUploadDialog(BuildContext context) {
    final titleController = TextEditingController();
    final urlController = TextEditingController(
      text: 'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800&auto=format&fit=crop&q=60',
    );
    final notesController = TextEditingController();
    String docType = 'vaccination_chart';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_upload_outlined, color: Color(0xff047857), size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Upload Chart or Document',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Chart Title *',
                        hintText: 'e.g. Vaccination Schedule 2026',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: docType,
                      decoration: const InputDecoration(
                        labelText: 'Document Type',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'vaccination_chart',
                          child: Text('💉 Vaccination Schedule Chart'),
                        ),
                        DropdownMenuItem(
                          value: 'rate_card',
                          child: Text('📈 Milk Fat/SNF Rate Card'),
                        ),
                        DropdownMenuItem(
                          value: 'feed_plan',
                          child: Text('🌾 Fodder & Diet Ration Chart'),
                        ),
                        DropdownMenuItem(
                          value: 'lab_report',
                          child: Text('🔬 Milk Purity / Vet Lab Report'),
                        ),
                        DropdownMenuItem(
                          value: 'cattle_certificate',
                          child: Text('📜 Pashu Pedigree Certificate'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('📄 Other Farm Document'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => docType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'Chart Image / PDF URL *',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Remarks (Optional)',
                        hintText: 'e.g. Applicable for Anand BMC center',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              final url = urlController.text.trim();
                              if (title.isEmpty || url.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter title and image URL')),
                                );
                                return;
                              }
                              setDialogState(() => isSubmitting = true);
                              try {
                                final dio = ref.read(dioProvider);
                                final response = await dio.post(
                                  '/farm/documents',
                                  data: {
                                    'title': title,
                                    'document_type': docType,
                                    'file_url': url,
                                    'notes': notesController.text.trim(),
                                    'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                                  },
                                );
                                if (response.data['success'] == true) {
                                  ref.invalidate(farmDocumentsProvider);
                                  if (mounted) {
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Chart uploaded successfully!'),
                                        backgroundColor: Color(0xff047857),
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                setDialogState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Upload failed: $e')),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        isSubmitting ? 'Uploading...' : 'Save & Publish Chart',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _viewFullChart(BuildContext context, FarmDoc doc) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xff064e3b),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: Image.network(
                doc.fileUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(40),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Unable to load chart image preview'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (doc.notes != null && doc.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Notes: ${doc.notes}',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(farmDocumentsProvider(_selectedCategory));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Charts & Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(farmDocumentsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadDialog(context),
        backgroundColor: const Color(0xff047857),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Upload Chart'),
      ),
      body: Column(
        children: [
          // Category filter row
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['key'];
                return ChoiceChip(
                  label: Text(cat['label']!),
                  selected: isSelected,
                  selectedColor: const Color(0xff047857).withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xff047857) : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedCategory = cat['key']!);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Documents grid / list
          Expanded(
            child: docsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48, color: Color(0xff047857)),
                      const SizedBox(height: 12),
                      const Text(
                        'Sign in to View Farm Charts',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.push('/login?next=/more/documents'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff047857), foregroundColor: Colors.white),
                        child: const Text('Sign In (1-Click Demo Available)'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No Farm Charts or Documents Yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Upload your vaccination charts, milk rate cards, and feed plans.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => _showUploadDialog(context),
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Your First Chart'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(farmDocumentsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          onTap: () => _viewFullChart(context, doc),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    doc.fileUrl,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 72,
                                      height: 72,
                                      color: Colors.grey.shade100,
                                      child: const Icon(Icons.image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: doc.typeColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          doc.typeLabel,
                                          style: TextStyle(
                                            color: doc.typeColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        doc.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          doc.notes!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        'Date: ${doc.date}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.fullscreen, color: Color(0xff047857)),
                                  tooltip: 'View Full Chart',
                                  onPressed: () => _viewFullChart(context, doc),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
