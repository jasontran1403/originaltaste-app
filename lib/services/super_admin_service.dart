// lib/services/super_admin_service.dart

import '../data/models/dashboard/dashboard_period.dart';
import '../data/models/dashboard/dashboard_pos_model.dart';
import '../data/models/dashboard/dashboard_restaurant_model.dart';
import '../data/models/dashboard/dashboard_vehicle_model.dart';
import '../data/network/api_result.dart';
import '../data/network/dio_client.dart';

class SuperAdminService {
  SuperAdminService._();
  static final SuperAdminService instance = SuperAdminService._();

  static const _base = '/api/superadmin/dashboard';

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

  // ── POS Vehicles ──────────────────────────────────────────────
  Future<ApiResult<List<PosVehicle>>> getVehicles() {
    return DioClient.instance.get<List<PosVehicle>>(
      '$_base/pos/vehicles',
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map(PosVehicle.fromJson)
          .toList()
          : <PosVehicle>[],
    );
  }

  // ── POS Dashboard (full) ──────────────────────────────────────
  Future<ApiResult<PosDashboardModel>> getPosDashboard({
    required DashboardPeriod period,
    DateTime? fromDate,
    DateTime? toDate,
    int?      vehicleId,
    String?   filterType,
  }) async {
    final params = <String, dynamic>{
      'period': _periodStr(period),
      if (period == DashboardPeriod.custom && fromDate != null)
        'fromTs': fromDate.millisecondsSinceEpoch,
      if (period == DashboardPeriod.custom && toDate != null)
        'toTs': toDate.millisecondsSinceEpoch,
      if (vehicleId  != null) 'vehicleId':  vehicleId,
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
    int?      vehicleId,
    String?   filterType,
  }) async {
    final params = <String, dynamic>{
      'period': _periodStr(period),
      if (period == DashboardPeriod.custom && fromDate != null)
        'fromTs': fromDate.millisecondsSinceEpoch,
      if (period == DashboardPeriod.custom && toDate != null)
        'toTs': toDate.millisecondsSinceEpoch,
      if (vehicleId  != null) 'vehicleId':  vehicleId,
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