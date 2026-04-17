// lib/services/admin_service.dart

import '../data/models/customer/customer_data_models.dart';
import '../data/models/dashboard/dashboard_period.dart';
import '../data/models/dashboard/dashboard_pos_model.dart';
import '../data/models/dashboard/dashboard_restaurant_model.dart';
import '../data/models/dashboard/pos_chart_models.dart';
import '../data/models/pos/pos_order_model.dart';
import '../data/models/pos/pos_product_model.dart';  // ← THÊM
import '../data/models/pos/pos_shift_model.dart';
import '../data/network/api_result.dart';
import '../data/network/dio_client.dart';

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  static const _base    = '/api/admin/dashboard';
  static const _posBase = '/api/admin';  // ← THÊM

  // ── Helper ────────────────────────────────────────────────────
  static String _periodStr(DashboardPeriod p) => switch (p) {
    DashboardPeriod.today   => 'TODAY',
    DashboardPeriod.days7   => '7DAYS',
    DashboardPeriod.days30  => '30DAYS',
    DashboardPeriod.months3 => '3MONTHS',
    DashboardPeriod.months6 => '6MONTHS',
    DashboardPeriod.year    => 'YEAR',
    DashboardPeriod.custom  => 'CUSTOM',
  };

  // ════════════════════════════════════════
  // GIỮ NGUYÊN CÁC METHOD CŨ
  // ════════════════════════════════════════

  Future<ApiResult<PosCustomerPageResult>> getPosCustomers({
    String? search, int page = 0, int size = 50,
  }) {
    return DioClient.instance.get<PosCustomerPageResult>(
      '/api/admin/pos-customers',
      queryParams: {
        'page': page, 'size': size,
        if (search != null) 'search': search,
      },
      fromData: (d) =>
          PosCustomerPageResult.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosCustomerData>> getPosCustomerById(int id) {
    return DioClient.instance.get<PosCustomerData>(
      '/api/admin/pos-customers/$id',
      fromData: (d) =>
          PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosCustomerData>> createPosCustomer(
      Map<String, String> data) {
    return DioClient.instance.post<PosCustomerData>(
      '/api/admin/pos-customers',
      body: data,
      fromData: (d) =>
          PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosCustomerData>> updatePosCustomer(
      int id, Map<String, String> data) {
    return DioClient.instance.put<PosCustomerData>(
      '/api/admin/pos-customers/$id',
      body: data,
      fromData: (d) =>
          PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosDashboardModel>> getPosDashboard({
    required DashboardPeriod period,
    DateTime? fromDate, DateTime? toDate, String? filterType,
  }) async {
    final params = <String, dynamic>{
      'period': _periodStr(period),
      if (period == DashboardPeriod.custom && fromDate != null)
        'fromTs': fromDate.millisecondsSinceEpoch,
      if (period == DashboardPeriod.custom && toDate != null)
        'toTs': toDate.millisecondsSinceEpoch,
      if (filterType != null) 'filterType': filterType,
    };
    return DioClient.instance.get<PosDashboardModel>(
      '$_base/pos',
      queryParams: params,
      fromData: (d) => d != null
          ? PosDashboardModel.fromJson(d as Map<String, dynamic>)
          : null,
    );
  }

  Future<ApiResult<List<PosOrderByTimeModel>>> getPosChart({
    required DashboardPeriod period,
    DateTime? fromDate, DateTime? toDate, String? filterType,
  }) async {
    final params = <String, dynamic>{
      'period': _periodStr(period),
      if (period == DashboardPeriod.custom && fromDate != null)
        'fromTs': fromDate.millisecondsSinceEpoch,
      if (period == DashboardPeriod.custom && toDate != null)
        'toTs': toDate.millisecondsSinceEpoch,
      if (filterType != null) 'filterType': filterType,
    };
    return DioClient.instance.get<List<PosOrderByTimeModel>>(
      '$_base/pos/chart',
      queryParams: params,
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map(PosOrderByTimeModel.fromJson)
          .toList()
          : <PosOrderByTimeModel>[],
    );
  }

  Future<ApiResult<RestaurantDashboardModel>> getRestaurantDashboard({
    DashboardPeriod period = DashboardPeriod.days30,
    DateTime? fromDate, DateTime? toDate,
    required String mode,
  }) {
    final params = <String, dynamic>{
      'period': _periodStr(period), 'mode': mode,
    };
    if (period == DashboardPeriod.custom) {
      if (fromDate != null)
        params['fromTs'] = fromDate.millisecondsSinceEpoch.toString();
      if (toDate != null)
        params['toTs'] = toDate.millisecondsSinceEpoch.toString();
    }
    return DioClient.instance.get<RestaurantDashboardModel>(
      '$_base/restaurant',
      queryParams: params,
      fromData: (d) => d != null
          ? RestaurantDashboardModel.fromJson(d as Map<String, dynamic>)
          : null,
    );
  }

  // ════════════════════════════════════════
  // STORE
  // ════════════════════════════════════════

  Future<Map<String, dynamic>?> getStoreInfo() async {
    final res = await DioClient.instance.get<Map<String, dynamic>>(
      '$_posBase/store/info',
      fromData: (d) => d as Map<String, dynamic>,
    );
    return res.data;
  }

  Future<bool> updateStoreInfo(Map<String, dynamic> body) async {
    final res = await DioClient.instance.put(
      '$_posBase/store/info',
      body: body,
    );
    return res.isSuccess;
  }

  // ════════════════════════════════════════
  // CATEGORY
  // ════════════════════════════════════════

  Future<List<PosCategoryModel>> getCategories({
    bool includeDefault = false,
  }) async {
    final res = await DioClient.instance.get<List<PosCategoryModel>>(
      '$_posBase/categories'
          '${includeDefault ? '?includeDefault=true' : ''}',
      fromData: (d) => (d as List)
          .map((e) =>
          PosCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return res.data ?? [];
  }

  Future<bool> createCategory(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post(
      '$_posBase/categories',
      body: body,
    );
    return res.isSuccess;
  }

  Future<bool> updateCategory(int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put(
      '$_posBase/categories/$id',
      body: body,
    );
    return res.isSuccess;
  }

  Future<void> deleteCategory(int id) async {
    await DioClient.instance.delete('$_posBase/categories/$id');
  }

  // ════════════════════════════════════════
  // INGREDIENT
  // ════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getIngredients() async {
    final res = await DioClient.instance
        .get<List<Map<String, dynamic>>>(
      '$_posBase/ingredients',
      fromData: (d) => (d as List)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
    return res.data ?? [];
  }

  Future<bool> createIngredient(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post(
      '$_posBase/ingredients',
      body: body,
    );
    return res.isSuccess;
  }

  Future<bool> updateIngredient(
      int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put(
      '$_posBase/ingredients/$id',
      body: body,
    );
    return res.isSuccess;
  }

  Future<void> deleteIngredient(int id) async {
    await DioClient.instance.delete('$_posBase/ingredients/$id');
  }

  // ════════════════════════════════════════
  // PRODUCT
  // ════════════════════════════════════════

  Future<List<PosProductModel>> getProducts({int? categoryId}) async {
    final query = categoryId != null ? '?categoryId=$categoryId' : '';
    final res = await DioClient.instance.get<List<PosProductModel>>(
      '$_posBase/products$query',
      fromData: (d) => (d as List)
          .map((e) => PosProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return res.data ?? [];
  }

  Future<List<PosShiftModel>> getShifts({String? search}) async {
    final res = await DioClient.instance.get<List<PosShiftModel>>(
      '$_posBase/shifts',
      queryParams: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
      fromData: (d) => (d as List)
          .map((e) => PosShiftModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<List<PosOrderModel>> getOrdersByShift(int shiftId) async {
    final res = await DioClient.instance.get<List<PosOrderModel>>(
      '$_posBase/shifts/$shiftId/orders',
      fromData: (d) => (d as List)
          .map((e) => PosOrderModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosProductModel> createProduct(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post<PosProductModel>(
      '$_posBase/products',
      body: body,
      fromData: (d) => PosProductModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosProductModel> updateProduct(int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put<PosProductModel>(
      '$_posBase/products/$id',
      body: body,
      fromData: (d) => PosProductModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<void> deleteProduct(int id) async {
    final res = await DioClient.instance.delete('$_posBase/products/$id');
    if (!res.isSuccess) throw Exception(res.message);
  }

  static Map<String, dynamic> _asMap(dynamic d) =>
      d as Map<String, dynamic>;

  // ════════════════════════════════════════
  // VARIANT
  // ════════════════════════════════════════

  Future<bool> createVariant(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post(
      '$_posBase/variants',
      body: body,
    );
    return res.isSuccess;
  }

  Future<bool> updateVariant(
      int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put(
      '$_posBase/variants/$id',
      body: body,
    );
    return res.isSuccess;
  }

  Future<void> deleteVariant(int id) async {
    await DioClient.instance.delete('$_posBase/variants/$id');
  }

  // ════════════════════════════════════════
  // ADVANCED CHARTS (dành cho Admin)
  // Lưu ý: Không cần truyền storeId vì đã nằm trong JWT token
  // ════════════════════════════════════════

  /// Lấy danh sách danh mục để filter chart
  Future<ApiResult<List<CategoryItem>>> getChartCategories() {
    return DioClient.instance.get<List<CategoryItem>>(
      '$_posBase/charts/categories',
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => CategoryItem.fromJson(e))
          .toList()
          : <CategoryItem>[],
    );
  }

  /// Monthly Shift Chart
  Future<ApiResult<List<PeriodShiftPoint>>> getPeriodShift({
    required int fromTs,
    required int toTs,
    required String periodUnit,
    List<String>? categories,
  }) async {
    final params = <String, dynamic>{
      'fromTs':     fromTs,
      'toTs':       toTs,
      'periodUnit': periodUnit,
    };
    if (categories != null && categories.isNotEmpty) {
      params['categories'] = categories;
    }
    return DioClient.instance.get<List<PeriodShiftPoint>>(
      '$_posBase/charts/monthly-shift',
      queryParams: params,
      fromData: (d) => (d as List)
          .map((e) => PeriodShiftPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Monthly Stacked Chart (theo ca hoặc theo danh mục)
  Future<ApiResult<List<PeriodStackedPoint>>> getPeriodStacked({
    required int fromTs,
    required int toTs,
    required String periodUnit,
    List<String>? categories,
  }) async {
    final params = <String, dynamic>{
      'fromTs':     fromTs,
      'toTs':       toTs,
      'periodUnit': periodUnit,
    };
    if (categories != null && categories.isNotEmpty) {
      params['categories'] = categories;
    }
    return DioClient.instance.get<List<PeriodStackedPoint>>(
      '$_posBase/charts/monthly-stacked',
      queryParams: params,
      fromData: (d) => (d as List)
          .map((e) => PeriodStackedPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Heatmap đơn hàng 7 ngày gần nhất
  Future<ApiResult<List<HeatmapCell>>> getHeatmap() {
    return DioClient.instance.get<List<HeatmapCell>>(
      '$_posBase/charts/heatmap',
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => HeatmapCell.fromJson(e))
          .toList()
          : <HeatmapCell>[],
    );
  }
}