import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/cart/widgets/address_location_fields.dart';

void main() {
  testWidgets('PIN lookup selects the matching master state and district',
      (tester) async {
    final pin = TextEditingController();
    final city = TextEditingController();
    final state = TextEditingController();
    final district = TextEditingController();
    final formKey = GlobalKey<FormState>();
    addTearDown(() {
      pin.dispose();
      city.dispose();
      state.dispose();
      district.dispose();
    });
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      final data = request.path == '/marketplace/locations'
          ? {
              'states': [
                {
                  'name': 'Uttar Pradesh',
                  'districts': ['Gautam Buddha Nagar', 'Lucknow']
                },
                {
                  'name': 'Rajasthan',
                  'districts': ['Jaipur', 'Jodhpur']
                },
              ]
            }
          : {
              'pincode': '201305',
              'city': 'Noida',
              'state': 'Uttar Pradesh',
              'district': 'Gautam Buddha Nagar'
            };
      handler.resolve(Response(requestOptions: request, data: data));
    }));

    await tester.pumpWidget(ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: AddressLocationFields(
                  pin: pin, city: city, stateName: state, district: district),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('address-pincode')), '201305');
    await tester.pumpAndSettle();
    expect(city.text, 'Noida');
    expect(state.text, 'Uttar Pradesh');
    expect(district.text, 'Gautam Buddha Nagar');

    await tester.tap(find.text('Uttar Pradesh').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rajasthan').last);
    await tester.pumpAndSettle();
    expect(state.text, 'Rajasthan');
    expect(district.text, isEmpty);
    final districtDropdown = find.byType(DropdownButtonFormField<String>).last;
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(districtDropdown)
            .onChanged,
        isNotNull);
    await tester.tap(districtDropdown);
    await tester.pumpAndSettle();
    expect(find.text('Jaipur'), findsOneWidget);
    await tester.tap(find.text('Other — enter manually').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter district *'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'New District');
    city.text = 'Jaipur';
    expect(formKey.currentState!.validate(), isTrue);
    await tester.tap(find.text('Rajasthan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other — enter manually').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter state / union territory *'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter state / union territory *'),
        'New State');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter district *'),
        'New District');
    city.text = 'New City';
    expect(formKey.currentState!.validate(), isTrue);
    expect(tester.takeException(), isNull);
  });
}
