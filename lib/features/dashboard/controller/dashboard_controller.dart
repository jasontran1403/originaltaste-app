import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/user_role.dart';
import '../../../data/models/dashboard/dashboard_period.dart';
import '../../../data/models/dashboard/dashboard_pos_model.dart';
import '../../../data/models/dashboard/dashboard_restaurant_model.dart';
import '../../../data/models/dashboard/dashboard_vehicle_model.dart';
import '../../../data/network/error_handler.dart';
import '../../../features/auth/controller/auth_controller.dart';
import '../../../services/admin_service.dart';
import '../../../services/super_admin_service.dart';

// ENUMS
enum DashboardMode { pos, wholesale, retail }

// STATE
class DashboardState {
  final DashboardMode mode;
  final DashboardPeriod period;
  final DateTime? customFrom;
  final DateTime? customTo;

  final bool posLoading;
  final String? posError;
  final PosDashboardModel? posData;
  final int posAnimationKey;

  final bool restaurantLoading;
  final String? restaurantError;
  final RestaurantDashboardModel? restaurantData;

  final bool vehiclesLoading;
  final bool vehicleSearching;
  final List<PosVehicle> vehicles;
  final List<PosVehicle> filteredVehicles;
  final PosVehicle? selectedVehicle;

  final String chartFilterType;
  final bool chartLoading;
  final List<PosOrderByTimeModel> chartOrdersByTime;

  const DashboardState({
    this.mode               = DashboardMode.pos,
    this.period             = DashboardPeriod.days30,
    this.customFrom,
    this.customTo,
    this.posLoading         = false,
    this.posError,
    this.posData,
    this.posAnimationKey    = 0,
    this.restaurantLoading  = false,
    this.restaurantError,
    this.restaurantData,
    this.vehiclesLoading    = false,
    this.vehicleSearching   = false,
    this.vehicles           = const [],
    this.filteredVehicles   = const [],
    this.selectedVehicle,
    this.chartFilterType    = 'ALL',
    this.chartLoading       = false,
    this.chartOrdersByTime  = const [],
  });

  DashboardState copyWith({
    DashboardMode? mode,
    DashboardPeriod? period,
    DateTime? customFrom,
    bool clearCustomFrom = false,
    DateTime? customTo,
    bool clearCustomTo = false,
    bool? posLoading,
    String? posError,
    bool clearPosError = false,
    PosDashboardModel? posData,
    int? posAnimationKey,
    bool? restaurantLoading,
    String? restaurantError,
    bool clearRestaurantError = false,
    RestaurantDashboardModel? restaurantData,
    bool clearRestaurantData = false,
    bool? vehiclesLoading,
    bool? vehicleSearching,
    List<PosVehicle>? vehicles,
    List<PosVehicle>? filteredVehicles,
    PosVehicle? selectedVehicle,
    bool clearSelectedVehicle = false,
    String? chartFilterType,
    bool? chartLoading,
    List<PosOrderByTimeModel>? chartOrdersByTime,
  }) =>
      DashboardState(
        mode:              mode              ?? this.mode,
        period:            period            ?? this.period,
        customFrom:        clearCustomFrom   ? null : (customFrom ?? this.customFrom),
        customTo:          clearCustomTo     ? null : (customTo   ?? this.customTo),
        posLoading:        posLoading        ?? this.posLoading,
        posError:          clearPosError     ? null : (posError   ?? this.posError),
        posData:           posData           ?? this.posData,
        posAnimationKey:   posAnimationKey   ?? this.posAnimationKey,
        restaurantLoading: restaurantLoading ?? this.restaurantLoading,
        restaurantError:   clearRestaurantError ? null : (restaurantError ?? this.restaurantError),
        restaurantData:    clearRestaurantData  ? null : (restaurantData  ?? this.restaurantData),
        vehiclesLoading:   vehiclesLoading   ?? this.vehiclesLoading,
        vehicleSearching:  vehicleSearching  ?? this.vehicleSearching,
        vehicles:          vehicles          ?? this.vehicles,
        filteredVehicles:  filteredVehicles  ?? this.filteredVehicles,
        selectedVehicle:   clearSelectedVehicle ? null : (selectedVehicle ?? this.selectedVehicle),
        chartFilterType:   chartFilterType   ?? this.chartFilterType,
        chartLoading:      chartLoading      ?? this.chartLoading,
        chartOrdersByTime: chartOrdersByTime ?? this.chartOrdersByTime,
      );
}

// PROVIDER
final dashboardControllerProvider =
NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);

// CONTROLLER
class DashboardController extends Notifier<DashboardState> {
  // Cache
  DashboardPeriod _posLastPeriod   = DashboardPeriod.days30;
  DateTime?       _posLastFrom;
  DateTime?       _posLastTo;
  int?            _posLastVehicleId;
  int             _reloadKey       = 0;
  int             _posLastReloadKey = -1;

  Timer? _reloadDebounce;
  Timer? _vehicleDebounce;

  UserRole get _role        => ref.read(authControllerProvider).role ?? UserRole.admin;
  bool get _isSuperAdmin    => _role == UserRole.superAdmin;

  // ── Chart filter ──────────────────────────────────────────────
  Future<void> setChartFilterType(String filterType) async {
    if (state.chartFilterType == filterType) return;
    state = state.copyWith(
      chartFilterType:   filterType,
      chartLoading:      true,
      chartOrdersByTime: [],
    );
    await _loadChart();
  }

  // ── Load chỉ ordersByTime (endpoint nhẹ) ──────────────────────
  Future<void> _loadChart() async {
    try {
      final ft = state.chartFilterType == 'ALL'
          ? null : state.chartFilterType;

      final result = _isSuperAdmin
          ? await SuperAdminService.instance.getPosChart(
        period:     state.period,
        fromDate:   state.customFrom,
        toDate:     state.customTo,
        vehicleId:  state.selectedVehicle?.id,
        filterType: ft,
      )
          : await AdminService.instance.getPosChart(
        period:     state.period,
        fromDate:   state.customFrom,
        toDate:     state.customTo,
        filterType: ft,
      );

      if (result.isTokenExpired) return;

      state = state.copyWith(
        chartLoading:      false,
        chartOrdersByTime: result.isSuccess ? (result.data ?? []) : [],
      );
    } catch (_) {
      state = state.copyWith(chartLoading: false);
    }
  }

  // ── Vehicle search ─────────────────────────────────────────────
  void cancelVehicleDebounce() => _vehicleDebounce?.cancel();

  void resetVehicleSearch() {
    cancelVehicleDebounce();
    state = state.copyWith(
      vehicleSearching: false,
      filteredVehicles: state.vehicles,
    );
  }

  @override
  DashboardState build() {
    ref.onDispose(() {
      _reloadDebounce?.cancel();
      _vehicleDebounce?.cancel();
    });
    Future.microtask(_init);
    return const DashboardState();
  }

  Future<void> _init() async {
    if (_isSuperAdmin) {
      await _loadVehicles();
    } else {
      await _loadPos();
    }
  }

  // ── Public actions ─────────────────────────────────────────────
  void setMode(DashboardMode m) {
    if (state.mode == m) return;
    state = state.copyWith(mode: m);
    reload();
  }

  void setPeriod(DashboardPeriod p, {DateTime? from, DateTime? to}) {
    state = state.copyWith(
      period:          p,
      customFrom:      from,
      clearCustomFrom: from == null,
      customTo:        to,
      clearCustomTo:   to == null,
    );
    reload();
  }

  void reload() {
    _reloadKey++;
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 10), _load);
  }

  void pullRefresh() => reload();

  void selectVehicle(PosVehicle v) {
    if (state.selectedVehicle?.id == v.id) return;
    state = state.copyWith(
      selectedVehicle:  v,
      filteredVehicles: state.vehicles,
    );
    reload();
  }

  void onVehicleSearchChanged(String query) {
    _vehicleDebounce?.cancel();
    state = state.copyWith(vehicleSearching: true);
    _vehicleDebounce = Timer(const Duration(milliseconds: 600), () {
      final q = query.trim().toLowerCase();
      final filtered = q.isEmpty
          ? state.vehicles
          : state.vehicles
          .where((v) => v.name.toLowerCase().contains(q))
          .toList();
      state = state.copyWith(
        vehicleSearching: false,
        filteredVehicles: filtered,
      );
    });
  }

  // ── Private load ───────────────────────────────────────────────
  Future<void> _load() async {
    if (state.mode == DashboardMode.pos) {
      await _loadPos();
    } else {
      await _loadRestaurant();
    }
  }

  Future<void> _loadPos() async {
    final currentKey = _reloadKey;
    if (currentKey == _posLastReloadKey) return;

    _posLastReloadKey  = currentKey;
    _posLastPeriod     = state.period;
    _posLastFrom       = state.customFrom;
    _posLastTo         = state.customTo;
    _posLastVehicleId  = state.selectedVehicle?.id;

    state = state.copyWith(posLoading: true, clearPosError: true);

    try {
      final ft = state.chartFilterType == 'ALL'
          ? null : state.chartFilterType;

      final result = _isSuperAdmin
          ? await SuperAdminService.instance.getPosDashboard(
        period:     state.period,
        fromDate:   state.customFrom,
        toDate:     state.customTo,
        vehicleId:  state.selectedVehicle?.id,
        filterType: ft,
      )
          : await AdminService.instance.getPosDashboard(
        period:     state.period,
        fromDate:   state.customFrom,
        toDate:     state.customTo,
        filterType: ft,
      );

      if (result.isTokenExpired) return;

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          posLoading:        false,
          posData:           result.data,
          posAnimationKey:   state.posAnimationKey + 1,
          // Sync chart data từ full response (lần đầu / reload toàn trang)
          chartOrdersByTime: result.data!.ordersByTime,
        );
      } else {
        state = state.copyWith(
          posLoading: false,
          posError:   ErrorHandler.message(result.code, result.message),
        );
      }
    } catch (e) {
      state = state.copyWith(posLoading: false);
    }
  }

  Future<void> _loadRestaurant() async {
    state = state.copyWith(
      restaurantLoading:    true,
      clearRestaurantError: true,
      clearRestaurantData:  true,
    );

    final modeStr = state.mode == DashboardMode.wholesale
        ? 'wholesale' : 'retail';

    try {
      final result = _isSuperAdmin
          ? await SuperAdminService.instance.getRestaurantDashboard(
        period:   state.period,
        fromDate: state.customFrom,
        toDate:   state.customTo,
        mode:     modeStr,
      )
          : await AdminService.instance.getRestaurantDashboard(
        period:   state.period,
        fromDate: state.customFrom,
        toDate:   state.customTo,
        mode:     modeStr,
      );

      if (result.isTokenExpired) return;

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          restaurantLoading: false,
          restaurantData:    result.data,
        );
      } else {
        state = state.copyWith(
          restaurantLoading: false,
          restaurantError:   ErrorHandler.message(result.code, result.message),
        );
      }
    } catch (e) {
      state = state.copyWith(
        restaurantLoading: false,
        restaurantError:   'Lỗi không xác định: $e',
      );
    }
  }

  Future<void> _loadVehicles() async {
    state = state.copyWith(vehiclesLoading: true);
    try {
      final result = await SuperAdminService.instance.getVehicles();
      if (result.isTokenExpired) return;

      if (result.isSuccess &&
          result.data != null &&
          result.data!.isNotEmpty) {
        final vehicles = result.data!;
        state = state.copyWith(
          vehiclesLoading:  false,
          vehicles:         vehicles,
          filteredVehicles: vehicles,
          selectedVehicle:  vehicles.first,
        );
      } else {
        state = state.copyWith(vehiclesLoading: false);
      }
    } catch (e) {
      state = state.copyWith(vehiclesLoading: false);
    }
    await _loadPos();
  }
}