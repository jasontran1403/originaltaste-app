// lib/features/dashboard/screens/dashboard_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/enums/user_role.dart';
import '../../../data/models/dashboard/dashboard_period.dart';
import '../../../data/storage/session_storage.dart';
import '../../../features/auth/controller/auth_controller.dart';
import '../../../shared/widgets/dashboard_pos_content.dart';
import '../../../shared/widgets/dashboard_shared_widgets.dart';
import '../../../shared/widgets/dashboard_vehicle_dropdown.dart';
import '../controller/dashboard_controller.dart';
import '../widgets/dashboard_restaurant_content.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role     = ref.watch(authControllerProvider).role ?? UserRole.admin;
    final ctrl     = ref.watch(dashboardControllerProvider);
    final notifier = ref.read(dashboardControllerProvider.notifier);
    final isSuperAdmin = role == UserRole.superAdmin;

    return Scaffold(
      body: Column(children: [
        const SizedBox(height: 20),
        _TopBar(
          ctrl:         ctrl,
          notifier:     notifier,
          isSuperAdmin: isSuperAdmin,
        ),
        const Divider(height: 0),
        Expanded(child: _buildContent(ctrl)),
      ]),
    );
  }

  Widget _buildContent(DashboardState ctrl) {
    return switch (ctrl.mode) {
      DashboardMode.pos       => const DashboardPosContent(),
      DashboardMode.wholesale => const DashboardRestaurantContent(),
      DashboardMode.retail    => const DashboardRestaurantContent(),
    };
  }
}

// ══════════════════════════════════════════════════════════════════
// TOP BAR
// ══════════════════════════════════════════════════════════════════

class _TopBar extends ConsumerStatefulWidget {
  final DashboardState      ctrl;
  final DashboardController notifier;
  final bool                isSuperAdmin;

  const _TopBar({
    required this.ctrl,
    required this.notifier,
    required this.isSuperAdmin,
  });

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  bool _isExporting = false;

  // ── Export logic ──────────────────────────────────────────────
  Future<void> _exportOrders() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final ctrl = widget.ctrl;

      final params = <String, dynamic>{
        'period': _periodStr(ctrl.period),
      };
      if (ctrl.period == DashboardPeriod.custom) {
        if (ctrl.customFrom != null)
          params['fromTs'] = ctrl.customFrom!.millisecondsSinceEpoch;
        if (ctrl.customTo != null)
          params['toTs'] = ctrl.customTo!.millisecondsSinceEpoch;
      }

      final String endpoint;
      if (ctrl.selectedVehicle != null) {
        endpoint = '/api/superadmin/dashboard/pos/export';
        params['storeId'] = ctrl.selectedVehicle!.id;
      } else {
        endpoint = '/api/admin/dashboard/pos/export';
      }

      // Gọi API — backend tạo file và gửi Telegram async
      final token = await SessionStorage.getAccessToken();
      final dio   = Dio(BaseOptions(
        baseUrl:        ApiConstants.baseUrl,
        receiveTimeout: const Duration(seconds: 30),
        connectTimeout: const Duration(seconds: 15),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ));

      final response = await dio.get(endpoint, queryParameters: params);

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Backend trả về message — hiện snackbar thành công
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.telegram, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Báo cáo đang được tạo và gửi vào Telegram...'),
          ]),
          backgroundColor: Colors.green.shade700,
          behavior:        SnackBarBehavior.floating,
          duration:        const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      } else {
        _snackError('Lỗi server: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _snackError(e.response?.statusCode == 401
          ? 'Phiên đăng nhập hết hạn'
          : 'Lỗi kết nối: ${e.message}');
    } catch (e) {
      _snackError('Lỗi export: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _snackError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: Colors.red.shade700,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _periodStr(DashboardPeriod p) => switch (p) {
    DashboardPeriod.today   => 'TODAY',
    DashboardPeriod.days7   => '7DAYS',
    DashboardPeriod.days30  => '30DAYS',
    DashboardPeriod.months3 => '3MONTHS',
    DashboardPeriod.months6 => '6MONTHS',
    DashboardPeriod.year    => 'YEAR',
    DashboardPeriod.custom  => 'CUSTOM',
  };

  // ── Export button widget ──────────────────────────────────────
  Widget _buildExportButton() {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;

    // Chỉ hiện ở POS mode, và chỉ SuperAdmin
    if (widget.ctrl.mode != DashboardMode.pos) return const SizedBox.shrink();
    if (!widget.isSuperAdmin) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      child: _isExporting
          ? OutlinedButton.icon(
        icon: SizedBox(
          width: 13, height: 13,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: primary),
        ),
        label: Text('Đang xuất...',
            style: TextStyle(fontSize: 11, color: primary)),
        style: OutlinedButton.styleFrom(
          side:    BorderSide(color: primary.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape:   RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: null,
      )
          : OutlinedButton.icon(
        icon: Icon(Icons.file_download_outlined,
            size: 15, color: primary),
        label: Text('Export',
            style: TextStyle(
                fontSize: 11, color: primary,
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side:    BorderSide(color: primary.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape:   RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _exportOrders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl    = widget.ctrl;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng 1: mode toggle (SuperAdmin only) + vehicle dropdown
          if (widget.isSuperAdmin) ...[
            Wrap(
              spacing: 12,
              children: [
                DashboardModeToggle(
                  selected:  ctrl.mode.index,
                  onChanged: (i) =>
                      widget.notifier.setMode(DashboardMode.values[i]),
                ),
                if (ctrl.mode == DashboardMode.pos)
                  const DashboardVehicleDropdown(),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Dòng 2: period filter + Export button
          Row(children: [
            Expanded(
              child: DashboardPeriodFilter(
                selected:   ctrl.period,
                customFrom: ctrl.customFrom,
                customTo:   ctrl.customTo,
                onSelect:   (p) => widget.notifier.setPeriod(p),
                onCustom: (from, to) => widget.notifier.setPeriod(
                  DashboardPeriod.custom,
                  from: from,
                  to:   to,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildExportButton(),
          ]),
        ],
      ),
    );
  }
}