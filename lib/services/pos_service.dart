// lib/services/pos_service.dart

import '../core/constants/api_constants.dart';
import '../data/models/pos/pos_product_model.dart';
import '../data/models/pos/pos_shift_model.dart';
import '../data/models/pos/pos_order_model.dart';
import '../data/models/pos/pos_cart_model.dart';
import '../data/network/dio_client.dart';

// Helper để cast an toàn
Map<String, dynamic> _asMap(dynamic d) => d as Map<String, dynamic>;
List<dynamic> _asList(dynamic d) => d as List<dynamic>;

class PosService {
  PosService._();
  static final PosService instance = PosService._();

  static const _base = ApiConstants.posBase;

  // ── Image URL builder ─────────────────────────────────────────
  static String buildImageUrl(String? dbPath) {
    if (dbPath == null || dbPath.isEmpty) return '';
    final parts = dbPath.split('/');
    if (parts.length < 4) return '';
    return '${ApiConstants.baseUrl}${ApiConstants.images}/${parts[2]}/${parts[3]}';
  }

  static String buildPosImageUrl(String? dbPath) {
    if (dbPath == null || dbPath.isEmpty) return '';
    final parts = dbPath.split('/');
    if (parts.length < 4) return '';
    return '${ApiConstants.baseUrl}${ApiConstants.images}/images/${parts[2]}/${parts[3]}';
  }

  // ── Upload ────────────────────────────────────────────────────
  static Future<String> uploadImage({
    required String filePath,
    required String type,
  }) async {
    // Backend category dùng @RequestParam("file")
    // Các endpoint khác dùng @RequestParam("image")
    final (String endpoint, String fieldName) = switch (type) {
      'category'    => (ApiConstants.uploadCategory,   'file'),
      'product'     => (ApiConstants.uploadProduct,    'image'),
      'pos-product' => (ApiConstants.uploadPosProduct, 'image'),
      'variant'     => (ApiConstants.uploadVariant,    'image'),
      'ingredient'  => (ApiConstants.uploadIngredient, 'image'),
      _             => throw Exception('Loại ảnh không hỗ trợ: $type'),
    };

    final res = await DioClient.instance.upload<String>(
      endpoint,
      filePath:  filePath,
      fieldName: fieldName,
      fromData:  (d) {
        // Category: data là String trực tiếp (imageUrl)
        if (d is String) return d;
        // Các loại khác: data là Map {imageUrl: "..."}
        if (d is Map<String, dynamic>) {
          return d['imageUrl'] as String?
              ?? d['filename'] as String?
              ?? '';
        }
        return '';
      },
    );

    if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
      return res.data!;
    }
    throw Exception(res.message.isNotEmpty ? res.message : 'Upload ảnh thất bại');
  }

  // ── Categories ────────────────────────────────────────────────
  Future<List<PosCategoryModel>> getCategories() async {
    final res = await DioClient.instance.get<List<PosCategoryModel>>(
      '$_base/categories',
      fromData: (d) => _asList(d)
          .map((e) => PosCategoryModel.fromJson(_asMap(e)))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosCategoryModel> createCategory({
    required String name,
    bool    singlePrice  = false,
    int     displayOrder = 0,
    String? imageUrl,
  }) async {
    final body = <String, dynamic>{
      'name': name, 'singlePrice': singlePrice, 'displayOrder': displayOrder,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
    final res = await DioClient.instance.post<PosCategoryModel>(
      '$_base/categories',
      body: body,
      fromData: (d) => PosCategoryModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosCategoryModel> updateCategory(int id, Map<String, dynamic> fields) async {
    final res = await DioClient.instance.put<PosCategoryModel>(
      '$_base/categories/$id',
      body: fields,
      fromData: (d) => PosCategoryModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<void> deleteCategory(int id) async {
    final res = await DioClient.instance.delete('$_base/categories/$id');
    if (!res.isSuccess) throw Exception(res.message);
  }

  // ── Products ──────────────────────────────────────────────────
  Future<List<PosProductModel>> getProducts({int? categoryId}) async {
    final res = await DioClient.instance.get<List<PosProductModel>>(
      '$_base/products',
      queryParams: categoryId != null ? {'categoryId': '$categoryId'} : null,
      fromData: (d) => _asList(d)
          .map((e) => PosProductModel.fromJson(_asMap(e)))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosProductModel> getProductById(int id) async {
    final res = await DioClient.instance.get<PosProductModel>(
      '$_base/products/$id',
      fromData: (d) => PosProductModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosProductModel> createProduct(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post<PosProductModel>(
      '$_base/products',
      body: body,
      fromData: (d) => PosProductModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosProductModel> updateProduct(int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put<PosProductModel>(
      '$_base/products/$id',
      body: body,
      fromData: (d) => PosProductModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<void> deleteProduct(int id) async {
    final res = await DioClient.instance.delete('$_base/products/$id');
    if (!res.isSuccess) throw Exception(res.message);
  }

  // ── Ingredients ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getIngredients() async {
    final res = await DioClient.instance.get<List<Map<String, dynamic>>>(
      '$_base/ingredients',
      fromData: (d) => _asList(d).map((e) => _asMap(e)).toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<Map<String, dynamic>> createIngredient(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post<Map<String, dynamic>>(
      '$_base/ingredients',
      body: body,
      fromData: (d) => _asMap(d),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<Map<String, dynamic>> updateIngredient(int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put<Map<String, dynamic>>(
      '$_base/ingredients/$id',
      body: body,
      fromData: (d) => _asMap(d),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<void> deleteIngredient(int id) async {
    final res = await DioClient.instance.delete('$_base/ingredients/$id');
    if (!res.isSuccess) throw Exception(res.message);
  }

  // ── Variants ──────────────────────────────────────────────────
  Future<void> createVariant(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post('$_base/variants', body: body);
    if (!res.isSuccess) throw Exception(res.message);
  }

  Future<void> updateVariant(int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put('$_base/variants/$id', body: body);
    if (!res.isSuccess) throw Exception(res.message);
  }

  Future<void> deleteVariant(int id) async {
    final res = await DioClient.instance.delete('$_base/variants/$id');
    if (!res.isSuccess) throw Exception(res.message);
  }

  // ── Shifts ────────────────────────────────────────────────────
  Future<PosShiftModel?> getCurrentShift() async {
    final res = await DioClient.instance.get<PosShiftModel>(
      '$_base/shifts/current',
      fromData: (d) => PosShiftModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data;
    return null;
  }

  Future<PosShiftModel> openShift(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post<PosShiftModel>(
      '$_base/shifts/open',
      body: body,
      fromData: (d) => PosShiftModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosShiftModel> closeShift(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post<PosShiftModel>(
      '$_base/shifts/close',
      body: body,
      fromData: (d) => PosShiftModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty ? res.message : 'Lỗi khi đóng ca');
  }

  Future<bool> isFirstShiftOfDay() async {
    final res = await DioClient.instance.get<bool>(
      '$_base/shifts/is-first-today',
      fromData: (d) => d is bool ? d : d.toString().toLowerCase() == 'true',
    );
    return res.isSuccess ? (res.data ?? false) : false;
  }

  Future<bool> verifyPosMenuPin(String pin) async {
    final res = await DioClient.instance.post(
      '$_base/verify-menu-pin',
      body: {'pin': pin},
    );
    if (res.code == 900) return true;
    throw Exception(res.message.isNotEmpty ? res.message : 'Mật khẩu không đúng');
  }

  Future<List<PosShiftModel>> getShiftsByDate(String date) async {
    final res = await DioClient.instance.get<List<PosShiftModel>>(
      '$_base/shifts',
      queryParams: {'date': date},
      fromData: (d) => _asList(d)
          .map((e) => PosShiftModel.fromJson(_asMap(e)))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<Map<String, dynamic>> getShiftReport(int shiftId) async {
    final res = await DioClient.instance.get<Map<String, dynamic>>(
      '$_base/shifts/$shiftId/report',
      fromData: (d) => _asMap(d),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  // ── Orders ────────────────────────────────────────────────────
  Future<PosOrderModel> createOrder({
    required String         orderSource,
    required List<CartItem> cartItems,
    String?                 paymentMethod,
    String?                 note,
    String?                 customerPhone,          // ← THÊM
    String?                 customerName,           // ← THÊM
    int?                    customerDiscountId,     // ← THÊM
    int?                    discountItemProductId,  // ← THÊM
  }) async {
    final items = cartItems.map((c) => <String, dynamic>{
      'productId':       c.product.id,
      'quantity':        c.quantity,
      'discountPercent': c.selectedPrice.discountPercent,
      'vatPercent':      c.product.vatPercent,
      if (c.note != null && c.note!.isNotEmpty) 'note': c.note,
      'variantSelections': c.variantSelections
          .where((s) => s.selectedIngredients.isNotEmpty)
          .map((s) => <String, dynamic>{
        'variantId':    s.variantId,
        'isAddonGroup': s.isAddonGroup,
        'selectedIngredients': s.selectedIngredients.entries.map((e) {
          final addon = s.addonItems
              ?.where((a) => a.ingredientId == e.key)
              .firstOrNull;
          return <String, dynamic>{
            'ingredientId':  e.key,
            'selectedCount': e.value,
            if (addon != null) ...{
              'isAddonIngredient':  true,
              'addonPriceSnapshot': addon.discountedAddonPrice,
              'addonBasePrice':     addon.baseAddonPrice,
              'addonName':          addon.ingredientName,
            },
          };
        }).toList(),
      }).toList(),
    }).toList();

    final body = <String, dynamic>{
      'orderSource':   orderSource,
      'paymentMethod': paymentMethod ?? 'CASH',
      'items':         items,
      if (note != null && note.isNotEmpty)                    'note':                  note,
      if (customerPhone != null && customerPhone.isNotEmpty)  'customerPhone':         customerPhone,
      if (customerName  != null && customerName.isNotEmpty)   'customerName':          customerName,
      if (customerDiscountId != null)                         'customerDiscountId':    customerDiscountId,
      if (discountItemProductId != null)                      'discountItemProductId': discountItemProductId,
    };

    final res = await DioClient.instance.post<PosOrderModel>(
      '$_base/orders',
      body: body,
      fromData: (d) => PosOrderModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<Map<String, dynamic>> getStoreInfo() async {
    final res = await DioClient.instance.get<Map<String, dynamic>>(
      '$_base/store/info',
      fromData: (d) => _asMap(d),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty ? res.message : 'Không lấy được thông tin store');
  }

  Future<void> deleteOrder(int orderId, String passcode) async {
    final res = await DioClient.instance.post(
      '$_base/orders/$orderId/delete',
      body: {'passcode': passcode},
    );
    if (!res.isSuccess) throw Exception(res.message.isNotEmpty ? res.message : 'Không thể xóa đơn hàng');
  }

  Future<PosOrderModel> getOrderById(int id) async {
    final res = await DioClient.instance.get<PosOrderModel>(
      '$_base/orders/$id',
      fromData: (d) => PosOrderModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<List<PosOrderModel>> getOrdersByShift(int shiftId) async {
    final res = await DioClient.instance.get<List<PosOrderModel>>(
      '$_base/shifts/$shiftId/orders',
      fromData: (d) => _asList(d)
          .map((e) => PosOrderModel.fromJson(_asMap(e)))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosOrderModel> cancelOrder(int orderId, String password) async {
    final res = await DioClient.instance.post<PosOrderModel>(
      '$_base/orders/$orderId/cancel',
      body: {'password': password},
      fromData: (d) => PosOrderModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosOrderModel> updateOrderPaymentMethod(int orderId, String method) async {
    final res = await DioClient.instance.put<PosOrderModel>(
      '$_base/orders/$orderId/payment-method',
      body: {'paymentMethod': method},
      fromData: (d) => PosOrderModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  // ── Stock Import ──────────────────────────────────────────────
  Future<void> importStock(List<Map<String, dynamic>> items) async {
    final res = await DioClient.instance.post(
      '$_base/shifts/stock-import',
      body: {'items': items},
    );

    if (!res.isSuccess) throw Exception(res.message);
  }

  Future<List<Map<String, dynamic>>> getStockImportHistory() async {
    final res = await DioClient.instance.get<List<Map<String, dynamic>>>(
      '$_base/shifts/stock-import/history',
      fromData: (d) => _asList(d).map((e) => _asMap(e)).toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    return [];
  }

  // ── Reports (Telegram export) ─────────────────────────────────

  /// Export báo cáo 1 ca → server xử lý ngầm, gửi Excel lên Telegram.
  /// Trả về message xác nhận từ server.
  Future<String> triggerShiftReport(int shiftId) async {
    final res = await DioClient.instance.get<String>(
      '$_base/reports/shift/$shiftId',
      fromData: (d) {
        if (d is Map<String, dynamic>) return d['message'] as String? ?? 'Đang xử lý...';
        return d.toString();
      },
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty ? res.message : 'Không thể gửi báo cáo');
  }

  /// Export báo cáo theo khoảng ngày (chỉ ca đã đóng).
  /// [from] và [to] theo định dạng 'yyyy-MM-dd', vd: '2026-03-01'.
  Future<String> triggerRangeReport({
    required String from,
    required String to,
  }) async {
    final res = await DioClient.instance.get<String>(
      '$_base/reports/range',
      queryParams: {'from': from, 'to': to},
      fromData: (d) {
        if (d is Map<String, dynamic>) return d['message'] as String? ?? 'Đang xử lý...';
        return d.toString();
      },
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty ? res.message : 'Không thể gửi báo cáo');
  }
}