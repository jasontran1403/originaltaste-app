// lib/features/dashboard/controller/dashboard_controller.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/user_role.dart';
import '../../../data/models/dashboard/dashboard_period.dart';
import '../../../data/models/dashboard/dashboard_pos_model.dart';
import '../../../data/models/dashboard/dashboard_restaurant_model.dart';
import '../../../data/models/dashboard/dashboard_vehicle_model.dart';
import '../../../data/models/dashboard/pos_chart_models.dart';
import '../../../data/network/error_handler.dart';
import '../../../features/auth/controller/auth_controller.dart';
import '../../../services/admin_service.dart';
import '../../../services/super_admin_service.dart';

enum DashboardMode { pos, wholesale, retail }

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

  // Advanced Charts
  final bool advancedChartsLoading;
  final String? advancedChartsError;
  final List<CategoryItem>       categories;
  final List<PeriodShiftPoint>   shiftData;
  final List<PeriodStackedPoint> stackedData;
  final List<HeatmapCell>        heatmap;
  final Set<String>              selectedCategories; // ← MỚI: category filter

  const DashboardState({
    this.mode = DashboardMode.pos,
    this.period = DashboardPeriod.days30,
    this.customFrom,
    this.customTo,
    this.posLoading = false,
    this.posError,
    this.posData,
    this.posAnimationKey = 0,
    this.restaurantLoading = false,
    this.restaurantError,
    this.restaurantData,
    this.vehiclesLoading = false,
    this.vehicleSearching = false,
    this.vehicles = const [],
    this.filteredVehicles = const [],
    this.selectedVehicle,
    this.chartFilterType = 'ALL',
    this.chartLoading = false,
    this.chartOrdersByTime = const [],

    this.advancedChartsLoading = false,
    this.advancedChartsError,
    this.categories = const [],
    this.shiftData = const [],
    this.stackedData = const [],
    this.heatmap = const [],
    this.selectedCategories = const {},
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

    bool? advancedChartsLoading,
    String? advancedChartsError,
    bool clearAdvancedChartsError = false,
    List<CategoryItem>? categories,
    List<PeriodShiftPoint>? shiftData,
    List<PeriodStackedPoint>? stackedData,
    List<HeatmapCell>? heatmap,
    Set<String>? selectedCategories,
  }) =>
      DashboardState(
        mode: mode ?? this.mode,
        period: period ?? this.period,
        customFrom: clearCustomFrom ? null : (customFrom ?? this.customFrom),
        customTo: clearCustomTo ? null : (customTo ?? this.customTo),
        posLoading: posLoading ?? this.posLoading,
        posError: clearPosError ? null : (posError ?? this.posError),
        posData: posData ?? this.posData,
        posAnimationKey: posAnimationKey ?? this.posAnimationKey,
        restaurantLoading: restaurantLoading ?? this.restaurantLoading,
        restaurantError: clearRestaurantError ? null : (restaurantError ?? this.restaurantError),
        restaurantData: clearRestaurantData ? null : (restaurantData ?? this.restaurantData),
        vehiclesLoading: vehiclesLoading ?? this.vehiclesLoading,
        vehicleSearching: vehicleSearching ?? this.vehicleSearching,
        vehicles: vehicles ?? this.vehicles,
        filteredVehicles: filteredVehicles ?? this.filteredVehicles,
        selectedVehicle: clearSelectedVehicle ? null : (selectedVehicle ?? this.selectedVehicle),
        chartFilterType: chartFilterType ?? this.chartFilterType,
        chartLoading: chartLoading ?? this.chartLoading,
        chartOrdersByTime: chartOrdersByTime ?? this.chartOrdersByTime,

        advancedChartsLoading: advancedChartsLoading ?? this.advancedChartsLoading,
        advancedChartsError: clearAdvancedChartsError ? null : (advancedChartsError ?? this.advancedChartsError),
        categories: categories ?? this.categories,
        shiftData: shiftData ?? this.shiftData,
        stackedData: stackedData ?? this.stackedData,
        heatmap: heatmap ?? this.heatmap,
        selectedCategories: selectedCategories ?? this.selectedCategories,
      );
}

final dashboardControllerProvider = NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);

class DashboardController extends Notifier<DashboardState> {
  int _loadGeneration = 0;
  Timer? _reloadDebounce;
  Timer? _vehicleDebounce;

  UserRole get _role => ref.read(authControllerProvider).role ?? UserRole.admin;
  bool get _isSuperAdmin => _role == UserRole.superAdmin;

  Future<void> toggleCategory(String name) async {
    final current = Set<String>.from(state.selectedCategories);
    if (current.contains(name)) {
      // Bỏ chọn → clear all (load tất cả)
      current.clear();
    } else {
      // Chọn mới → replace, không accumulate
      current.clear();
      current.add(name);
    }
    state = state.copyWith(selectedCategories: current);
    await loadAdvancedCharts();
  }


  String _periodUnit() => switch (state.period) {
    DashboardPeriod.today   => 'DAY',
    DashboardPeriod.days7   => 'WEEK',
    DashboardPeriod.days30  => 'MONTH_30',
    DashboardPeriod.months3 => 'MONTH_3',
    DashboardPeriod.months6 => 'MONTH_6',
    DashboardPeriod.year    => 'YEAR',
    DashboardPeriod.custom  => 'CUSTOM',
  };

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

  // ==================== LOAD POS ====================
  Future<void> _loadPos() async {
    _loadGeneration++;
    final myGeneration = _loadGeneration;

    state = state.copyWith(
      posLoading: true,
      clearPosError: true,
      chartLoading: false,
      chartOrdersByTime: [],
    );

    try {
      final ft = state.chartFilterType == 'ALL' ? null : state.chartFilterType;

      final result = _isSuperAdmin
          ? await SuperAdminService.instance.getPosDashboard(
        period: state.period,
        fromDate: state.customFrom,
        toDate: state.customTo,
        vehicleId: state.selectedVehicle?.id,
        filterType: ft,
      )
          : await AdminService.instance.getPosDashboard(
        period: state.period,
        fromDate: state.customFrom,
        toDate: state.customTo,
        filterType: ft,
      );

      if (myGeneration != _loadGeneration) return;
      if (result.isTokenExpired) return;

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          posLoading: false,
          posData: result.data,
          posAnimationKey: state.posAnimationKey + 1,
          chartLoading: false,
          chartOrdersByTime: result.data!.ordersByTime,
        );

        // Load Advanced Charts sau khi có Pos Data
        await loadAdvancedCharts();
      } else {
        state = state.copyWith(
          posLoading: false,
          chartLoading: false,
          posError: ErrorHandler.message(result.code, result.message),
        );
      }
    } catch (e) {
      if (myGeneration != _loadGeneration) return;
      state = state.copyWith(posLoading: false, chartLoading: false);
    }
  }

  // ==================== ADVANCED CHARTS ====================
  Future<void> loadAdvancedCharts() async {
    _loadGeneration++;
    final myGeneration = _loadGeneration;

    state = state.copyWith(
      advancedChartsLoading: true,
      clearAdvancedChartsError: true,
    );

    try {
      final isSuper   = _isSuperAdmin;
      final storeId   = state.selectedVehicle?.id;
      final fromTs    = _resolveFromTs();
      final toTs      = _resolveToTs();
      final pUnit     = _periodUnit();
      final cats      = state.selectedCategories.isEmpty
          ? <String>[] : state.selectedCategories.toList();

      final catFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getChartCategories(storeId: storeId)
          : AdminService.instance.getChartCategories();

      final shiftFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getPeriodShift(
          storeId: storeId, fromTs: fromTs, toTs: toTs,
          periodUnit: pUnit, categories: cats)
          : AdminService.instance.getPeriodShift(
          fromTs: fromTs, toTs: toTs,
          periodUnit: pUnit, categories: cats);

      final stackedFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getPeriodStacked(
          storeId: storeId, fromTs: fromTs, toTs: toTs,
          periodUnit: pUnit, categories: cats)
          : AdminService.instance.getPeriodStacked(
          fromTs: fromTs, toTs: toTs,
          periodUnit: pUnit, categories: cats);

      final heatmapFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getHeatmap(storeId: storeId)
          : AdminService.instance.getHeatmap();

      final results = await Future.wait([
        catFuture, shiftFuture, stackedFuture, heatmapFuture,
      ]);

      if (myGeneration != _loadGeneration) return;

      state = state.copyWith(
        advancedChartsLoading: false,
        categories: results[0].isSuccess && results[0].data != null
            ? results[0].data as List<CategoryItem> : [],
        shiftData: results[1].isSuccess && results[1].data != null
            ? results[1].data as List<PeriodShiftPoint> : [],
        stackedData: results[2].isSuccess && results[2].data != null
            ? results[2].data as List<PeriodStackedPoint> : [],
        heatmap: results[3].isSuccess && results[3].data != null
            ? results[3].data as List<HeatmapCell> : [],
      );
    } catch (e) {
      if (myGeneration != _loadGeneration) return;
      state = state.copyWith(
        advancedChartsLoading: false,
        advancedChartsError: 'Lỗi tải biểu đồ: $e',
      );
    }
  }

  int _resolveFromTs() {
    final now = DateTime.now();
    return switch (state.period) {
      DashboardPeriod.today   => DateTime(now.year, now.month, now.day)
          .millisecondsSinceEpoch,
      DashboardPeriod.days7   => now.subtract(const Duration(days: 6))
          .millisecondsSinceEpoch,
      DashboardPeriod.days30  => now.subtract(const Duration(days: 29))
          .millisecondsSinceEpoch,
      DashboardPeriod.months3 => DateTime(now.year, now.month - 3, 1)
          .millisecondsSinceEpoch,
      DashboardPeriod.months6 => DateTime(now.year, now.month - 6, 1)
          .millisecondsSinceEpoch,
      DashboardPeriod.year    => DateTime(now.year - 1, now.month, now.day)
          .millisecondsSinceEpoch,
      DashboardPeriod.custom  => state.customFrom?.millisecondsSinceEpoch
          ?? DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
    };
  }

  int _resolveToTs() {
    final now = DateTime.now();
    return switch (state.period) {
      DashboardPeriod.today   => DateTime(now.year, now.month, now.day, 23, 59, 59)
          .millisecondsSinceEpoch,
      _                       => state.customTo?.millisecondsSinceEpoch
          ?? now.millisecondsSinceEpoch,
    };
  }

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

  // ── Load chart độc lập (khi đổi filter type) ─────────────────
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