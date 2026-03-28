// lib/services/admin_service.dart

import '../data/models/customer/customer_data_models.dart';
import '../data/models/dashboard/dashboard_period.dart';
import '../data/models/dashboard/dashboard_pos_model.dart';
import '../data/models/dashboard/dashboard_restaurant_model.dart';
import '../data/network/api_result.dart';
import '../data/network/dio_client.dart';

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  static const _base = '/api/admin/dashboard';

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

  Future<ApiResult<PosCustomerPageResult>> getPosCustomers({
    String? search,
    int page = 0,
    int size = 50,
  }) {
    return DioClient.instance.get<PosCustomerPageResult>(
      '/api/admin/pos-customers',
      queryParams: {
        'page': page,
        'size': size,
        if (search != null) 'search': search,
      },
      fromData: (d) => PosCustomerPageResult.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosCustomerData>> getPosCustomerById(int id) {
    return DioClient.instance.get<PosCustomerData>(
      '/api/admin/pos-customers/$id',
      fromData: (d) => PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosCustomerData>> createPosCustomer(
      Map<String, String> data) {
    return DioClient.instance.post<PosCustomerData>(
      '/api/admin/pos-customers',
      body: data,
      fromData: (d) => PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosCustomerData>> updatePosCustomer(
      int id, Map<String, String> data) {
    return DioClient.instance.put<PosCustomerData>(
      '/api/admin/pos-customers/$id',
      body: data,
      fromData: (d) => PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }


  // ── POS Dashboard (full) ──────────────────────────────────────
  Future<ApiResult<PosDashboardModel>> getPosDashboard({
    required DashboardPeriod period,
    DateTime? fromDate,
    DateTime? toDate,
    String?   filterType,
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

  // ── POS Chart only (ordersByTime) ────────────────────────────
  Future<ApiResult<List<PosOrderByTimeModel>>> getPosChart({
    required DashboardPeriod period,
    DateTime? fromDate,
    DateTime? toDate,
    String?   filterType,
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

  // ── Restaurant Dashboard ──────────────────────────────────────
  Future<ApiResult<RestaurantDashboardModel>> getRestaurantDashboard({
    DashboardPeriod period   = DashboardPeriod.days30,
    DateTime?       fromDate,
    DateTime?       toDate,
    required String mode,
  }) {
    final params = <String, dynamic>{
      'period': _periodStr(period),
      'mode':   mode,
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
}