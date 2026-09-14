import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/core/media_url.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/marketplace/widgets/product_media_manager.dart';

final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==');

void main() {
  test(
      'Local uploads resolve against API; assets and external URLs stay unchanged',
      () {
    expect(resolveMediaUrl('/api/v1/marketplace/media/123'),
        '${AppConstants.apiBaseUrl}/api/v1/marketplace/media/123');
    expect(resolveMediaUrl('assets/store/cow-ghee.png'),
        'assets/store/cow-ghee.png');
    expect(resolveMediaUrl('https://example.test/image.jpg'),
        'https://example.test/image.jpg');
  });

  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('Image manager fits width $width and saves through API',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var uploaded = false;
      var primary = false;
      var deleted = false;
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) {
        if (r.method == 'POST') {
          expect(r.path, '/vendor/products/p1/images');
          expect(r.contentType, 'application/octet-stream');
          expect(r.data, isA<Stream<List<int>>>());
          uploaded = true;
        }
        if (r.method == 'PUT') {
          expect(r.path, '/vendor/products/p1/media/m1/primary');
          primary = true;
        }
        if (r.method == 'DELETE') deleted = true;
        h.resolve(Response(requestOptions: r, data: {
          'success': true,
          'data': r.method == 'GET'
              ? [
                  if (uploaded && !deleted)
                    {
                      'id': 'm1',
                      'url': '/api/v1/marketplace/media/m1',
                      'is_primary': primary,
                      'media_type': 'image'
                    }
                ]
              : {}
        }));
      }));
      await tester.pumpWidget(ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            productImagePickerProvider.overrideWithValue(
                () async => XFile.fromData(pixel, name: 'product.png')),
            mediaPreviewProvider.overrideWith((ref, ids) async => pixel),
          ],
          child: const MaterialApp(
              home: Scaffold(
                  body: ProductMediaManager(
                      productId: 'p1', title: 'Milterra Ghee')))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload image'));
      await tester.pumpAndSettle();
      expect(uploaded, isTrue);
      await tester.tap(find.text('Make primary'));
      await tester.pumpAndSettle();
      expect(primary, isTrue);
      expect(find.text('Primary image'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove').last);
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
      expect(find.text('No saved product images yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Failed upload stays on form without false success',
      (tester) async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) {
      if (r.method == 'POST') {
        h.reject(DioException(
            requestOptions: r,
            response: Response(
                requestOptions: r,
                statusCode: 422,
                data: {'detail': 'Invalid image'})));
      } else {
        h.resolve(Response(requestOptions: r, data: {'data': []}));
      }
    }));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          productImagePickerProvider.overrideWithValue(
              () async => XFile.fromData(pixel, name: 'bad.png'))
        ],
        child: const MaterialApp(
            home: Scaffold(
                body: ProductMediaManager(productId: 'p1', title: 'Ghee')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload image'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid image'), findsOneWidget);
    expect(find.text('No saved product images yet.'), findsOneWidget);
  });
}
