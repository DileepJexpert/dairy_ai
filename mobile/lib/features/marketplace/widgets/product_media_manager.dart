import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/product_provider.dart';
import 'store_design.dart';

final productImagePickerProvider = Provider<Future<XFile?> Function()>(
    (ref) => () => openFile(acceptedTypeGroups: const [
          XTypeGroup(label: 'Product images', extensions: [
            'jpg',
            'jpeg',
            'png',
            'webp'
          ], uniformTypeIdentifiers: [
            'public.jpeg',
            'public.png',
            'org.webmproject.webp'
          ])
        ]));

final productMediaProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
  ref.watch(currentUserProvider);
  final response =
      await ref.read(dioProvider).get('/vendor/products/$id/media');
  return (response.data['data'] as List)
      .map((x) => Map<String, dynamic>.from(x))
      .toList();
});

final mediaPreviewProvider = FutureProvider.autoDispose
    .family<Uint8List, (String, String)>((ref, ids) async {
  ref.watch(currentUserProvider);
  final response = await ref.read(dioProvider).get<List<int>>(
      '/vendor/products/${ids.$1}/media/${ids.$2}/preview',
      options: Options(responseType: ResponseType.bytes));
  return Uint8List.fromList(response.data!);
});

class ProductMediaManager extends ConsumerStatefulWidget {
  const ProductMediaManager(
      {super.key, required this.productId, required this.title});
  final String productId, title;
  @override
  ConsumerState<ProductMediaManager> createState() =>
      _ProductMediaManagerState();
}

class _ProductMediaManagerState extends ConsumerState<ProductMediaManager> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(productMediaProvider(widget.productId));
      ref.invalidate(productsProvider);
      ref.invalidate(productDetailProvider);
    } catch (error) {
      if (!mounted) return;
      final detail = error is DioException && error.response?.data is Map
          ? error.response?.data['detail']
          : null;
      setState(() => _error = detail is String
          ? detail
          : 'Image change could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() => _run(() async {
        final file = await ref.read(productImagePickerProvider)();
        if (file == null) return;
        if (await file.length() > 5 * 1024 * 1024) {
          throw DioException(
              requestOptions: RequestOptions(),
              response: Response(
                  requestOptions: RequestOptions(),
                  data: {'detail': 'Image must be 5 MB or smaller'}));
        }
        final bytes = await file.readAsBytes();
        await ref.read(dioProvider).post(
            '/vendor/products/${widget.productId}/images',
            data: Stream.fromIterable([bytes]),
            options: Options(contentType: 'application/octet-stream'));
      });

  Widget _preview(Map<String, dynamic> row) {
    final url = row['url'].toString();
    if (!url.startsWith('/api/v1/marketplace/media/')) {
      return StoreMediaImage(source: url);
    }
    return ref
        .watch(mediaPreviewProvider((widget.productId, row['id'].toString())))
        .when(
            data: (bytes) => Image.memory(bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined)),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Icon(Icons.broken_image_outlined));
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(productMediaProvider(widget.productId));
    return PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: Text('Product images · ${widget.title}'),
          content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text(
                        'JPEG, PNG or WebP · up to 5 MB and 16 million pixels · 12 images per product. Saved on the backend; draft images stay private.'),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    if (_busy) const LinearProgressIndicator(),
                    media.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => TextButton(
                            onPressed: _busy
                                ? null
                                : () => ref.invalidate(
                                    productMediaProvider(widget.productId)),
                            child: const Text('Could not load images. Retry')),
                        data: (rows) => rows.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No saved product images yet.'))
                            : Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: rows
                                    .map((row) => SizedBox(
                                        width: 170,
                                        child: Card(
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Column(children: [
                                                  SizedBox(
                                                      height: 125,
                                                      width: double.infinity,
                                                      child: _preview(row)),
                                                  if (row['is_primary'] == true)
                                                    const Text('Primary image'),
                                                  if (row['is_primary'] !=
                                                          true &&
                                                      row['media_type'] ==
                                                          'image')
                                                    TextButton(
                                                        onPressed: _busy
                                                            ? null
                                                            : () =>
                                                                _run(() async {
                                                                  await ref
                                                                      .read(
                                                                          dioProvider)
                                                                      .put(
                                                                          '/vendor/products/${widget.productId}/media/${row['id']}/primary');
                                                                }),
                                                        child: const Text(
                                                            'Make primary')),
                                                  TextButton.icon(
                                                      onPressed: _busy
                                                          ? null
                                                          : () async {
                                                              final confirmed = await showDialog<
                                                                      bool>(
                                                                  context:
                                                                      context,
                                                                  builder: (ctx) =>
                                                                      AlertDialog(
                                                                          title: const Text(
                                                                              'Remove image from this product?'),
                                                                          content:
                                                                              const Text('Other seller offers using this image are not changed.'),
                                                                          actions: [
                                                                            TextButton(
                                                                                onPressed: () => Navigator.pop(ctx, false),
                                                                                child: const Text('Cancel')),
                                                                            TextButton(
                                                                                onPressed: () => Navigator.pop(ctx, true),
                                                                                child: const Text('Remove'))
                                                                          ]));
                                                              if (confirmed ==
                                                                      true &&
                                                                  mounted) {
                                                                await _run(
                                                                    () async {
                                                                  await ref
                                                                      .read(
                                                                          dioProvider)
                                                                      .delete(
                                                                          '/vendor/products/${widget.productId}/media/${row['id']}');
                                                                });
                                                              }
                                                            },
                                                      icon: const Icon(
                                                          Icons.delete_outline),
                                                      label:
                                                          const Text('Remove')),
                                                ])))))
                                    .toList())),
                  ]))),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Done')),
            FilledButton.icon(
                onPressed: _busy ||
                        media.isLoading ||
                        media.hasError ||
                        (media.valueOrNull?.length ?? 0) >= 12
                    ? null
                    : _upload,
                icon: const Icon(Icons.upload),
                label: const Text('Upload image'))
          ],
        ));
  }
}
