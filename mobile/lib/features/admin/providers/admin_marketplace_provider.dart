import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/providers/product_provider.dart';
import '../../cart/providers/coupon_provider.dart';

double _number(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;
List<Map<String, dynamic>> _rows(Map body, String key) => (body[key] as List)
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

class BatchCertificate {
  const BatchCertificate({
    required this.id,
    required this.batchNumber,
    required this.productId,
    required this.productTitle,
    required this.category,
    required this.testDate,
    required this.laboratory,
    required this.fssaiLicense,
    this.purityPercent,
    required this.testParameters,
    this.status = 'PENDING_REVIEW',
    required this.certifiedBy,
    required this.remarks,
    this.reportUrl,
  });
  final String id,
      batchNumber,
      productId,
      productTitle,
      category,
      laboratory,
      fssaiLicense,
      status,
      certifiedBy,
      remarks;
  final DateTime testDate;
  final double? purityPercent;
  final Map<String, String> testParameters;
  final String? reportUrl;

  factory BatchCertificate.fromJson(Map<String, dynamic> j) => BatchCertificate(
        id: j['id'],
        batchNumber: j['batch_number'],
        productId: j['product_id'],
        productTitle: j['product_title'],
        category: j['category'],
        testDate: DateTime.parse(j['test_date']),
        laboratory: j['laboratory'],
        fssaiLicense: j['fssai_license'],
        purityPercent:
            j['purity_percent'] == null ? null : _number(j['purity_percent']),
        testParameters: (j['test_parameters'] as Map)
            .map((k, v) => MapEntry(k.toString(), v.toString())),
        status: j['status'],
        certifiedBy: j['certified_by'],
        remarks: j['remarks'],
        reportUrl: j['report_url'],
      );
  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'batch_number': batchNumber,
        'test_date': testDate.toUtc().toIso8601String(),
        'laboratory': laboratory,
        'fssai_license': fssaiLicense,
        'purity_percent': purityPercent,
        'test_parameters': testParameters,
        'status': status,
        'certified_by': certifiedBy,
        'remarks': remarks,
        'report_url': reportUrl,
      };
}

class AdminMarketplaceState {
  const AdminMarketplaceState({
    this.sellers = const [],
    this.offers = const [],
    this.coupons = const [],
    this.auditLogs = const [],
    this.batchCertificates = const [],
    this.loading = false,
    this.saving = false,
    this.error,
  });
  final List<SellerAccount> sellers;
  final List<SellerOffer> offers;
  final List<PlatformCoupon> coupons;
  final List<MarketplaceAuditLog> auditLogs;
  final List<BatchCertificate> batchCertificates;
  final bool loading, saving;
  final String? error;
  AdminMarketplaceState withStatus(
          {bool loading = false, bool saving = false, String? error}) =>
      AdminMarketplaceState(
          sellers: sellers,
          offers: offers,
          coupons: coupons,
          auditLogs: auditLogs,
          batchCertificates: batchCertificates,
          loading: loading,
          saving: saving,
          error: error);

  factory AdminMarketplaceState.fromJson(Map j) => AdminMarketplaceState(
        sellers: _rows(j, 'sellers')
            .map((s) => SellerAccount(
                  id: s['id'],
                  businessName: s['business_name'],
                  gstin: s['gstin'],
                  fssaiLicense: s['fssai_license'],
                  contactEmail: s['contact_email'],
                  contactPhone: s['contact_phone'],
                  warehouseCity: s['warehouse_city'],
                  warehouseState: s['warehouse_state'],
                  bankAccountNumber: s['account_number'],
                  ifscCode: s['ifsc_code'],
                  upiId: s['upi_id'],
                  status: SellerStatus.values.byName(s['status']),
                  ratingScore: _number(s['rating_score']),
                  commissionRatePercent: _number(s['commission_rate'] ?? 5.0),
                  createdAt: DateTime.parse(s['created_at']),
                ))
            .toList(),
        offers: _rows(j, 'offers')
            .map((o) => SellerOffer(
                  id: o['id'],
                  productId: o['product_id'],
                  sellerId: o['seller_id'],
                  sellerName: o['seller_name'],
                  sellerSku: o['seller_sku'],
                  mrp: _number(o['mrp']),
                  sellingPrice: _number(o['selling_price']),
                  discountPercent: _number(o['discount_percent']),
                  availableStock: o['available_stock'],
                  lowStockThreshold: o['low_stock_threshold'],
                  deliveryPromise: '',
                  offerStatus: OfferStatus.values.byName(o['offer_status']),
                  sellerRating: _number(o['seller_rating']),
                  fulfillmentType: FulfillmentType.sellerDirect,
                ))
            .toList(),
        coupons: _rows(j, 'coupons')
            .map((c) => PlatformCoupon(
                  id: c['id'],
                  code: c['code'],
                  description: c['description'],
                  discountType: CouponType.values.byName(c['discount_type']),
                  discountValue: _number(c['discount_value']),
                  minOrderValue: _number(c['min_order_value']),
                  maxDiscountCap: c['max_discount_cap'] == null
                      ? null
                      : _number(c['max_discount_cap']),
                  validUntil: DateTime.tryParse(c['valid_until'] ?? ''),
                  usageCount: c['usage_count'],
                  isActive: c['is_active'],
                ))
            .toList(),
        batchCertificates: _rows(j, 'batch_certificates')
            .map(BatchCertificate.fromJson)
            .toList(),
        auditLogs: _rows(j, 'audit_logs')
            .map((a) => MarketplaceAuditLog(
                  id: a['id'],
                  userRole: a['user_role'],
                  userIdentifier: a['user_identifier'],
                  action: AuditAction.values.byName(a['action']),
                  entityType: a['entity_type'],
                  entityId: a['entity_id'],
                  details: a['details'],
                  timestamp: DateTime.parse(a['timestamp']),
                ))
            .toList(),
      );
}

String commerceError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    final detail = data is Map ? data['detail'] : null;
    if (detail is String) return detail;
    if (detail is List)
      return detail.map((v) => v is Map ? v['msg'] : v).join('; ');
    return 'Could not reach the backend. No success has been confirmed. Please retry.';
  }
  return error is StateError
      ? error.message.toString()
      : 'Invalid backend response. Please retry.';
}

class AdminMarketplaceNotifier extends StateNotifier<AdminMarketplaceState> {
  AdminMarketplaceNotifier(this.ref, this.dio,
      {required this.admin, required bool enabled})
      : super(const AdminMarketplaceState()) {
    if (enabled) refresh();
  }
  final Ref ref;
  final Dio dio;
  final bool admin;
  String get base => admin ? '/admin/commerce' : '/vendor/commerce';

  Future<void> refresh({bool propagate = false}) async {
    if (!mounted) return;
    state = state.withStatus(loading: true);
    try {
      final response = await dio.get(base);
      final parsed =
          AdminMarketplaceState.fromJson(response.data['data'] as Map);
      if (mounted) state = parsed;
    } catch (error) {
      if (mounted) state = state.withStatus(error: commerceError(error));
      if (propagate) rethrow;
    }
  }

  Future<void> _save(String path, Map<String, dynamic> data,
      {String method = 'PATCH'}) async {
    if (state.saving) throw StateError('A save is already in progress.');
    state = state.withStatus(saving: true);
    try {
      await dio.request(path, data: data, options: Options(method: method));
      ref.invalidate(productsProvider);
      ref.invalidate(productDetailProvider);
      ref.invalidate(familiesProvider);
      ref.invalidate(availableCouponsProvider);
      ref.invalidate(publicCertificatesProvider);
      await refresh(propagate: true);
    } catch (error) {
      if (mounted) state = state.withStatus(error: commerceError(error));
      rethrow;
    }
  }

  Future<void> approveSeller(String id) =>
      _save('$base/sellers/$id', {'status': 'approved'});
  Future<void> suspendSeller(String id, String reason) =>
      _save('$base/sellers/$id', {'status': 'suspended', 'reason': reason});
  Future<void> updateSellerCommission(String id, double rate) =>
      _save('/admin/commerce/vendors/$id/commission', {'commission_rate': rate});
  Future<void> updateOfferPrice(String id, double price, double mrp) =>
      _save('$base/offers/$id', {'selling_price': price, 'mrp': mrp});
  Future<void> updateOfferStock(String id, int stock) =>
      _save('$base/offers/$id', {'available_stock': stock});
  Future<void> saveCoupon(PlatformCoupon c) => _save(
      '$base/coupons${c.id.isEmpty ? '' : '/${c.id}'}',
      {
        'code': c.code,
        'description': c.description,
        'discount_type': c.discountType.name,
        'discount_value': c.discountValue,
        'min_order_value': c.minOrderValue,
        'max_discount_cap': c.maxDiscountCap,
        'valid_until': c.validUntil?.toUtc().toIso8601String(),
        'is_active': c.isActive,
      },
      method: c.id.isEmpty ? 'POST' : 'PUT');
  Future<void> toggleCoupon(PlatformCoupon c) =>
      _save('$base/coupons/${c.id}', {'is_active': !c.isActive});
  Future<void> saveCertificate(BatchCertificate c) =>
      _save('$base/certificates${c.id.isEmpty ? '' : '/${c.id}'}', c.toJson(),
          method: c.id.isEmpty ? 'POST' : 'PUT');
}

final adminMarketplaceProvider =
    StateNotifierProvider<AdminMarketplaceNotifier, AdminMarketplaceState>(
        (ref) {
  final user = ref.watch(currentUserProvider);
  final admin = user?.role == 'admin' || user?.role == 'super_admin';
  return AdminMarketplaceNotifier(ref, ref.read(dioProvider),
      admin: admin,
      enabled: admin || user?.role == 'vendor' || user?.role == 'seller');
});

final publicCertificatesProvider =
    FutureProvider.family<List<BatchCertificate>, String?>(
        (ref, productId) async {
  if (productId?.startsWith('family-') == true) return const [];
  final response = await ref.watch(dioProvider).get('/marketplace/certificates',
      queryParameters: {if (productId != null) 'product_id': productId});
  return (response.data['data'] as List)
      .map((j) => BatchCertificate.fromJson(Map<String, dynamic>.from(j)))
      .toList();
});
