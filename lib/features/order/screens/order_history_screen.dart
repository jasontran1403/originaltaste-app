// lib/features/order/screens/order_history_screen.dart

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/enums/user_role.dart';
import '../../../data/models/order/order_models.dart';
import '../../../data/models/pos/pos_order_model.dart';
import '../../../data/models/pos/pos_shift_model.dart';
import '../../../data/storage/session_storage.dart';
import '../../../services/admin_service.dart';
import '../../../services/order_service.dart';
import '../../../shared/widgets/order_shared_widgets.dart';
import '../controller/order_history_controller.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() =>
      _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  UserRole? _role;
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final roleStr = await SessionStorage.getRole();
    if (mounted) {
      setState(() {
        _role = UserRole.fromString(roleStr);
        _roleLoaded = true;
      });
      if (_role != UserRole.admin) {
        ref.read(orderHistoryProvider.notifier).loadOrders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (_role == UserRole.admin) {
      return const _AdminOrderHistoryScreen();
    }

    // Seller — giữ nguyên UI cũ
    return const _SellerOrderHistoryScreen();
  }
}

// ════════════════════════════════════════════════════════════════
// SELLER — giữ nguyên UI cũ
// ════════════════════════════════════════════════════════════════

class _SellerOrderHistoryScreen extends ConsumerWidget {
  const _SellerOrderHistoryScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state     = ref.watch(orderHistoryProvider);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark
        ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bg        = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg    = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bg,
      body: state.isLoading
          ? Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(primary)))
          : state.error != null
          ? _buildError(state.error!, primary, ref)
          : state.orders.isEmpty
          ? _buildEmpty(secondary)
          : RefreshIndicator(
        onRefresh: () =>
            ref.read(orderHistoryProvider.notifier).loadOrders(),
        color: primary, backgroundColor: cardBg,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 30, 16, 100),
          itemCount: state.orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final order = state.orders[i];
            return _SellerOrderCard(
              order: order, isDark: isDark,
              primary: primary, secondary: secondary,
              cardBg: cardBg, border: border,
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(String msg, Color primary, WidgetRef ref) =>
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline_rounded, size: 80, color: Colors.redAccent),
        const SizedBox(height: 24),
        Text('Đã xảy ra lỗi', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w600, color: Colors.redAccent)),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(msg, style: TextStyle(
                fontSize: 16, color: Colors.redAccent.withOpacity(0.9)),
                textAlign: TextAlign.center)),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => ref.read(orderHistoryProvider.notifier).loadOrders(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Thử lại'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]));

  Widget _buildEmpty(Color secondary) =>
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 100,
            color: secondary.withOpacity(0.3)),
        const SizedBox(height: 24),
        Text('Chưa có đơn hàng nào', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w600, color: secondary)),
        const SizedBox(height: 12),
        Text('Các đơn hàng đã tạo sẽ hiển thị ở đây',
            style: TextStyle(fontSize: 16, color: secondary.withOpacity(0.7))),
      ]));
}

class _SellerOrderCard extends StatefulWidget {
  final OrderModel order;
  final bool isDark;
  final Color primary, secondary, cardBg, border;
  const _SellerOrderCard({
    required this.order, required this.isDark,
    required this.primary, required this.secondary,
    required this.cardBg, required this.border,
  });
  @override
  State<_SellerOrderCard> createState() => _SellerOrderCardState();
}

class _SellerOrderCardState extends State<_SellerOrderCard> {
  bool _isExporting = false;
  OrderModel get o => widget.order;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/order-detail/${o.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: widget.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.border),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.25 : 0.08),
            blurRadius: 12, offset: const Offset(0, 4),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(), _buildInfo(), _buildActions(context),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final divider = widget.isDark
        ? AppColors.darkBorder : AppColors.lightBorder;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: divider))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.receipt_outlined, size: 22, color: widget.primary),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(o.orderCode, style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 16,
              color: widget.isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(fmtOrderDate(o.createdAt),
              style: TextStyle(fontSize: 13, color: widget.secondary)),
        ])),
        OrderStatusBadge(status: o.status),
      ]),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (o.customerName != null || o.customerPhone != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Icon(Icons.person_outline_rounded,
                  size: 16, color: widget.secondary),
              const SizedBox(width: 8),
              Expanded(child: Text(
                [o.customerName, o.customerPhone]
                    .where((e) => e != null && e.isNotEmpty)
                    .join(' • '),
                style: TextStyle(fontSize: 14, color: widget.secondary),
              )),
            ]),
          ),
        Row(children: [
          Icon(Icons.shopping_bag_outlined,
              size: 16, color: widget.secondary),
          const SizedBox(width: 8),
          Text('${o.items.length} sản phẩm',
              style: TextStyle(fontSize: 14, color: widget.secondary)),
          const Spacer(),
          PaymentStatusBadge(status: o.paymentStatus),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Tổng cộng:',
              style: TextStyle(fontSize: 15, color: widget.secondary)),
          Row(children: [
            Text(fmtMoney(o.finalAmount), style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.green)),
            if (o.discountAmount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('-${fmtMoney(o.discountAmount)}',
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error)),
              ),
            ],
          ]),
        ]),
      ]),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: [
        Expanded(child: _ActionBtn(
          icon: Icons.visibility_outlined, label: 'Chi tiết',
          onTap: () => context.push('/order-detail/${o.id}'),
          outlined: true, color: widget.secondary,
        )),
        const SizedBox(width: 12),
        Expanded(child: _ActionBtn(
          icon: _isExporting
              ? Icons.hourglass_empty_rounded
              : Icons.picture_as_pdf_outlined,
          label: _isExporting ? 'Đang tạo...' : 'Tạo Invoice',
          onTap: _isExporting ? null : () => _exportInvoice(context),
          loading: _isExporting, color: widget.primary,
        )),
      ]),
    );
  }

  Future<void> _exportInvoice(BuildContext ctx) async {
    setState(() => _isExporting = true);
    try {
      await OrderService.instance.generateInvoice(o.id, ctx);   // ← Truyền context
      // SnackBar sẽ được hiển thị bên trong generateInvoice
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('Lỗi: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined, loading;
  final Color color;
  const _ActionBtn({
    required this.icon, required this.label, this.onTap,
    this.outlined = false, this.loading = false, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: outlined ? null
              : (loading ? color.withOpacity(0.6) : color),
          border: outlined
              ? Border.all(color: color, width: 1.5) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: loading
            ? SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(Colors.white)))
            : Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18,
              color: outlined ? color : Colors.white),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600,
              color: outlined ? color : Colors.white)),
        ])),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADMIN — POS order history, style giống PosHistoryScreen
// ════════════════════════════════════════════════════════════════

class _AdminOrderHistoryScreen extends StatefulWidget {
  const _AdminOrderHistoryScreen();

  @override
  State<_AdminOrderHistoryScreen> createState() =>
      _AdminOrderHistoryScreenState();
}

class _AdminOrderHistoryScreenState
    extends State<_AdminOrderHistoryScreen> {

  List<PosShiftModel> _shifts  = [];
  PosShiftModel?      _selShift;
  List<PosOrderModel> _orders  = [];
  bool   _loadingShifts = true;
  bool   _loadingOrders = false;
  String _search        = '';    // search shifts
  String _orderSearch   = '';   // search orders

  @override
  void initState() { super.initState(); _loadShifts(); }

  Future<void> _loadShifts({String? search}) async {
    setState(() => _loadingShifts = true);
    try {
      final list = await AdminService.instance
          .getShifts(search: search ?? _search);
      if (mounted) {
        setState(() {
          _shifts        = list;
          _loadingShifts = false;
          if (list.isNotEmpty && _selShift == null) {
            _selShift = list.first;
            _loadOrders(list.first.id);
          } else if (list.isEmpty) {
            _selShift = null; _orders = [];
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingShifts = false);
    }
  }

  Future<void> _loadOrders(int shiftId) async {
    setState(() { _loadingOrders = true; _orders = []; });
    try {
      final list = await AdminService.instance.getOrdersByShift(shiftId);
      if (mounted) setState(() => _orders = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _fmtTime(int ts) => ts == 0
      ? '—'
      : '${DateTime.fromMillisecondsSinceEpoch(ts).hour.toString().padLeft(2, '0')}:'
      '${DateTime.fromMillisecondsSinceEpoch(ts).minute.toString().padLeft(2, '0')}';

  String _fmtDT(int ts) {
    if (ts == 0) return '—';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}'
        '  ${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}';
  }

  List<PosOrderModel> get _filteredOrders => _orderSearch.isEmpty
      ? _orders
      : _orders.where((o) => o.orderCode.toLowerCase()
      .contains(_orderSearch.toLowerCase())).toList();

  double get _totalRevenue  =>
      _orders.fold(0, (s, o) => s + o.finalAmount);
  int    get _orderCount    => _orders.length;
  double get _cashTotal     =>
      _orders.where((o) => o.paymentMethod == 'CASH')
          .fold(0, (s, o) => s + o.finalAmount);
  double get _transferTotal =>
      _orders.where((o) => o.paymentMethod != 'CASH')
          .fold(0, (s, o) => s + o.finalAmount);

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final cs           = Theme.of(context).colorScheme;
    final bgColor      = isDark
        ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor  = isDark
        ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary  = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const topRowH = 57.0;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(children: [
        // ── Header ────────────────────────────────────────────
        Container(
          color: surfaceColor,
          child: SafeArea(bottom: false, child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Text('Lịch sử POS', style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  letterSpacing: -0.5, color: textPrimary)),
            ),
            Divider(height: 1, color: borderColor),
          ])),
        ),

        Expanded(child: Row(children: [

          // ══ Sidebar ════════════════════════════════════════
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Column(children: [
              // Search shifts
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  style: TextStyle(fontSize: 12, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Tìm ca, tên NV...',
                    hintStyle: TextStyle(fontSize: 12,
                        color: textSecondary),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 16, color: textSecondary),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: cs.primary, width: 1.5)),
                  ),
                  onChanged: (v) {
                    setState(() => _search = v);
                    _loadShifts(search: v);
                  },
                ),
              ),
              Divider(height: 1, color: borderColor),

              // Shift list
              Expanded(
                child: _loadingShifts
                    ? Center(child: CircularProgressIndicator(
                    strokeWidth: 2, color: cs.primary))
                    : _shifts.isEmpty
                    ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_alt_outlined, size: 36,
                      color: textSecondary.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  Text('Không có ca', style: TextStyle(
                      color: textSecondary, fontSize: 12)),
                ]))
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 10),
                  itemCount: _shifts.length,
                  itemBuilder: (_, i) {
                    final s     = _shifts[i];
                    final isSel = _selShift?.id == s.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() => _selShift = s);
                          _loadOrders(s.id);
                        },
                        child: AnimatedContainer(
                          duration:
                          const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSel
                                ? cs.primary.withOpacity(
                                isDark ? 0.2 : 0.08)
                                : Colors.transparent,
                            borderRadius:
                            BorderRadius.circular(12),
                            border: Border.all(
                                color: isSel
                                    ? cs.primary.withOpacity(0.4)
                                    : Colors.transparent),
                          ),
                          child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(child: Text(
                                    '#${s.id} · ${s.staffName}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: isSel
                                            ? cs.primary
                                            : textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  )),
                                  if (s.isOpen)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green
                                            .withOpacity(0.15),
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      child: const Text('Live',
                                          style: TextStyle(fontSize: 9,
                                              color: Colors.green,
                                              fontWeight:
                                              FontWeight.w800)),
                                    ),
                                ]),
                                const SizedBox(height: 4),
                                Text(s.shiftDate,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  '${_fmtTime(s.openTime)} – '
                                      '${s.closeTime != null ? _fmtTime(s.closeTime!) : "..."}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${s.totalOrders} đơn  ·  ${_fmt(s.totalRevenue)}đ',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isSel
                                          ? cs.primary
                                          : textSecondary,
                                      fontWeight: isSel
                                          ? FontWeight.w700
                                          : FontWeight.normal),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),

          // ══ Right panel ════════════════════════════════════
          Expanded(
            child: Container(
              color: bgColor,
              child: Column(children: [
                // Stats row
                Container(
                  color: surfaceColor,
                  height: topRowH,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _selShift != null && _orders.isNotEmpty
                      ? Row(children: [
                    _StatCard(label: 'Tổng đơn',
                        value: '$_orderCount',
                        valueColor: textPrimary,
                        isDark: isDark,
                        icon: Icons.receipt_long_outlined),
                    const SizedBox(width: 8),
                    _StatCard(label: 'Doanh thu',
                        value: '${_fmt(_totalRevenue)}đ',
                        valueColor: cs.primary,
                        isDark: isDark,
                        icon: Icons.trending_up_rounded),
                    const SizedBox(width: 8),
                    _StatCard(label: 'Tiền mặt',
                        value: '${_fmt(_cashTotal)}đ',
                        valueColor: const Color(0xFF10B981),
                        isDark: isDark,
                        icon: Icons.payments_outlined),
                    const SizedBox(width: 8),
                    _StatCard(label: 'Chuyển khoản',
                        value: '${_fmt(_transferTotal)}đ',
                        valueColor: const Color(0xFF3B82F6),
                        isDark: isDark,
                        icon: Icons.account_balance_outlined),
                  ])
                      : const SizedBox.shrink(),
                ),
                Divider(height: 1, color: borderColor),

                // Order search
                Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: TextField(
                    style: TextStyle(fontSize: 13, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tìm mã đơn hàng...',
                      hintStyle: TextStyle(
                          fontSize: 13, color: textSecondary),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 18, color: textSecondary),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: cs.primary, width: 1.5)),
                    ),
                    onChanged: (v) =>
                        setState(() => _orderSearch = v),
                  ),
                ),
                Divider(height: 1, color: borderColor),

                // Order list
                Expanded(
                  child: _loadingOrders
                      ? Center(child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary))
                      : _selShift == null
                      ? _EmptyHint(
                      icon: Icons.touch_app_outlined,
                      message: 'Chọn một ca để xem đơn hàng',
                      isDark: isDark)
                      : _filteredOrders.isEmpty
                      ? _EmptyHint(
                      icon: Icons.receipt_long_outlined,
                      message: 'Không có đơn hàng',
                      isDark: isDark)
                      : ListView.builder(
                    padding: EdgeInsets.fromLTRB(14, 12, 14,
                        MediaQuery.of(context).padding.bottom + 12),
                    itemCount: _filteredOrders.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _OrderTile(
                        order: _filteredOrders[i],
                        formatMoney: _fmt,
                        formatDate: _fmtDT,
                        isDark: isDark,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        onTap: () =>
                            _showDetail(_filteredOrders[i]),
                        onDelete: () {},    // Admin không xóa
                        onTogglePayment: () {}, // Admin không đổi
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ])),
      ]),
    );
  }

  void _showDetail(PosOrderModel order) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? const Color(0xFF1E293B) : Colors.white;
    final borderColor  = isDark
        ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        order: order,
        formatMoney: _fmt,
        formatDate: _fmtDT,
        isDark: isDark,
        surfaceColor: surfaceColor,
        borderColor: borderColor,
        onDelete: () {},   // Admin không xóa từ đây
        onPrint: () => Navigator.pop(context),
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  final PosOrderModel order;
  final String Function(double) formatMoney;
  final String Function(int) formatDate;
  final bool isDark;
  final Color surfaceColor, borderColor;
  final VoidCallback onDelete;
  final VoidCallback onPrint;

  const _OrderDetailSheet({
    required this.order, required this.formatMoney, required this.formatDate,
    required this.isDark, required this.surfaceColor, required this.borderColor,
    required this.onDelete,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final txtPri = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSec = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final c      = _D.srcColor(order.orderSource);
    final isCash = order.paymentMethod == 'CASH';
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: screenHeight * 0.85,  // ← 85% chiều cao màn hình
      decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        // ══ Handle bar ══
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: txtSec.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // ══ Header (fixed) ══
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _D.srcLabel(order.orderSource)[0],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.orderCode,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: txtPri)),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: c.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(_D.srcLabel(order.orderSource),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: (isCash ? const Color(0xFF10B981) : const Color(0xFF3B82F6))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(isCash ? 'Tiền mặt' : 'Chuyển khoản',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isCash ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                        )),
                  ),
                ]),
              ])),

              // Print button
              IconButton(
                onPressed: onPrint,
                icon: const Icon(Icons.print_rounded, color: Color(0xFF0EA5E9), size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.08),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(34, 34),
                ),
                tooltip: 'In bill',
              ),
              const SizedBox(width: 4),
              // Delete button
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.08),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(34, 34),
                ),
                tooltip: 'Xóa đơn hàng',
              ),
              const SizedBox(width: 4),
              // Close button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: txtSec),
                style: IconButton.styleFrom(
                  backgroundColor: txtSec.withOpacity(0.08),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(32, 32),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.schedule_outlined, size: 12, color: txtSec),
              const SizedBox(width: 5),
              Text(formatDate(order.createdAt), style: TextStyle(fontSize: 12, color: txtSec)),
            ]),
            const SizedBox(height: 16),
            Divider(color: borderColor, height: 1),
          ]),
        ),

        // ══ Scrollable content ══
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(children: [
              // Items list
              ...order.items.map((item) => _buildOrderItem(
                item: item,
                formatMoney: formatMoney,
                cs: cs,
                txtPri: txtPri,
                txtSec: txtSec,
                borderColor: borderColor,
              )),
              const SizedBox(height: 12),
            ]),
          ),
        ),

        // ══ Footer (fixed) ══
        Container(
          padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPadding + 20),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Column(children: [
            // ── Tạm tính ────────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Tạm tính', style: TextStyle(fontSize: 13, color: txtSec)),
              Text('${formatMoney(order.totalAmount)}đ',
                  style: TextStyle(fontSize: 13, color: txtSec, fontWeight: FontWeight.w600)),
            ]),

            // ── Giảm giá ────────────────────────────────────────────
            // Hiển thị cho cả đơn thường và đơn App khi có giảm giá
            if (order.discountAmount > 0) ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Giảm giá', style: TextStyle(fontSize: 13, color: Colors.blueAccent)),
                Text('-${formatMoney(order.discountAmount)}đ',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.w600)),
              ]),
            ],

            if (!order.isAppOrder) ...[
              // ── VAT breakdown (chỉ đơn offline có VAT) ──────────────────
              if (!order.isAppOrder && order.totalVat > 0) ...[
                const SizedBox(height: 6),
                // Tổng VAT
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('VAT (đã bao gồm)', style: TextStyle(fontSize: 13, color: Colors.orange)),
                  Text('${formatMoney(order.totalVat)}đ',
                      style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600)),
                ]),
                // Breakdown từng mức — tính từ items
                ...() {
                  final Map<int, double> breakdown = {};
                  for (final item in order.items) {
                    if (item.vatPercent > 0 && item.vatAmount > 0) {
                      breakdown.update(item.vatPercent, (v) => v + item.vatAmount,
                          ifAbsent: () => item.vatAmount);
                    }
                  }
                  final sorted = breakdown.entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key));
                  return sorted.map((e) => Padding(
                    padding: const EdgeInsets.only(top: 3, left: 12),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('• ${e.key}%',
                          style: const TextStyle(fontSize: 11, color: Colors.orange)),
                      Text('${formatMoney(e.value)}đ',
                          style: const TextStyle(fontSize: 11, color: Colors.orange)),
                    ]),
                  ));
                }(),
              ],
            ],

            // ── Phí sàn (chỉ đơn App) ───────────────────────────────
            if (order.isAppOrder && order.platformFeeAmount > 0) ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Text('Phí sàn', style: TextStyle(fontSize: 13, color: Colors.red.shade400)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Text(
                      '${(order.platformRate * 100).toStringAsFixed(2)}%',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade400),
                    ),
                  ),
                ]),
                Text('${formatMoney(order.platformFeeAmount)}đ',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade400,
                        fontWeight: FontWeight.w600)),
              ]),
            ],

            const SizedBox(height: 10),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 10),

            // ── Tổng cộng ────────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Tổng cộng',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
              Text('${formatMoney(order.finalAmount)}đ',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: cs.primary)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildOrderItem({required PosOrderItemModel item, required String Function(double) formatMoney, required ColorScheme cs, required Color txtPri, required Color txtSec, required Color borderColor,}) {
    // Parse variant ingredients và addons
    final variantIngredients = <Map<String, dynamic>>[];
    final addons = <Map<String, dynamic>>[];

    for (final variant in item.selectedIngredients) {
      final variantGroupName = variant['variantGroupName'] as String? ?? '';
      final ingredients = variant['selectedIngredients'] as List<dynamic>? ?? [];
      final isAddonGroup = variantGroupName.toLowerCase().contains('món thêm') ||
          variantGroupName.toLowerCase().contains('addon');

      for (final ing in ingredients) {
        final ingMap = ing as Map<String, dynamic>;
        final ingredientName = ingMap['ingredientName'] as String? ?? '';
        final selectedCount = ingMap['selectedCount'] as int? ?? 1;
        final addonPrice = (ingMap['addonPrice'] as num?)?.toDouble() ?? 0.0;
        final unitWeights = ingMap['unitWeights'] as List<dynamic>?;

        // Tính tổng weight nếu có
        double? totalWeight;
        if (unitWeights != null && unitWeights.isNotEmpty) {
          totalWeight = unitWeights.fold<double>(0.0, (s, w) => s + (w as num).toDouble());
        }

        if (isAddonGroup || addonPrice > 0) {
          addons.add({
            'name': ingredientName,
            'selectedCount': selectedCount,
            'addonPrice': addonPrice,
          });
        } else {
          variantIngredients.add({
            'name': ingredientName,
            'selectedCount': selectedCount,
            'totalWeight': totalWeight,
          });
        }
      }
    }

    final bool isAppOrder = order.orderSource == 'SHOPEE_FOOD' ||
        order.orderSource == 'GRAB_FOOD';

    // Tính định lượng tổng (tổng weight của tất cả ingredients)
    double? totalItemWeight;
    for (final ing in variantIngredients) {
      final w = ing['totalWeight'] as double?;
      if (w != null && w > 0) {
        totalItemWeight = (totalItemWeight ?? 0) + w;
      }
    }

    String? weightLabel;
    if (totalItemWeight != null && totalItemWeight > 0) {
      if (totalItemWeight >= 1) {
        final s = totalItemWeight.toStringAsFixed(3)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        weightLabel = '${s}kg';
      } else {
        weightLabel = '${(totalItemWeight * 1000).round()}g';
      }
    }

    // Giá
    final double defaultPrice = item.defaultPrice;
    final double basePrice    = item.basePrice;
    final double finalUnit    = item.finalUnitPrice;

    final bool hasWeightOverride = (finalUnit - defaultPrice).abs() > 1;

    final bool hasDiscount = !isAppOrder && item.discountPercent > 0;

    final double displayUnit  = finalUnit;
    final double displayTotal = displayUnit * item.quantity;


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Dòng chính: Tên | Giá đơn | x1 (+weight) | Tổng ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: cs.primary.withOpacity(0.6), shape: BoxShape.circle)),
          const SizedBox(width: 10),

          // Tên món
          Expanded(
            child: Text(item.productName,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: txtPri)),
          ),

          // Cột giá đơn + giá gốc bên dưới
          SizedBox(
            width: 90, // ← cố định width cột đơn giá
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${formatMoney(basePrice)}đ',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: (hasDiscount || hasWeightOverride) ? txtPri : cs.primary,
                ),
              ),
              if (hasDiscount) ...[
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${formatMoney(defaultPrice)}đ',
                        style: TextStyle(
                          fontSize: 11, color: txtSec,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: txtSec.withOpacity(0.7),
                        )),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text('-${item.discountPercent}%',
                          style: const TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ],

              if (isAppOrder && (basePrice - finalUnit).abs() > 1) ...[
                const SizedBox(height: 2),
                Text('${formatMoney(basePrice)}đ',
                    style: TextStyle(
                      fontSize: 11, color: txtSec,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: txtSec.withOpacity(0.7),
                    )),
              ],
            ]),
          ),

          const SizedBox(width: 8),

          // Số lượng + weight bên dưới
          SizedBox(
            width: 52, // ← cố định width cột số lượng
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 36,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: txtSec.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('×${item.quantity}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: txtSec, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              if (weightLabel != null) ...[
                const SizedBox(height: 3),
                Text('($weightLabel)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF0EA5E9), fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
          const SizedBox(width: 8),

// Tổng tiền — cố định width
          SizedBox(
            width: 90, // ← cố định width cột tổng
            child: Text(
              '${formatMoney(displayTotal)}đ',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: (hasDiscount || hasWeightOverride) ? txtPri : cs.primary,
              ),
            ),
          ),
        ]),

        // ── Nguyên liệu chính ──
        if (variantIngredients.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...variantIngredients.map((ing) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 3),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: txtSec.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('×${ing['selectedCount']}',
                    style: TextStyle(fontSize: 11, color: txtSec)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(ing['name'] as String,
                  style: TextStyle(fontSize: 12.5, color: txtSec))),
            ]),
          )),
        ],

        // ── Món thêm ──
        if (addons.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withOpacity(isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.25)),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.add_circle_outline, size: 13, color: Color(0xFFFBBF24)),
                const SizedBox(width: 6),
                Text('Món thêm', style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                )),
              ]),
              const SizedBox(height: 8),
              ...addons.map((a) {
                final total = (a['addonPrice'] as double) * (a['selectedCount'] as int);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(children: [
                    Expanded(child: Text(a['name'] as String,
                        style: TextStyle(fontSize: 12.5, color: txtPri))),
                    Text('×${a['selectedCount']}   ${formatMoney(total)}đ',
                        style: const TextStyle(fontSize: 12,
                            color: Color(0xFFFBBF24), fontWeight: FontWeight.w600)),
                  ]),
                );
              }),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isDark;
  const _EmptyHint({required this.icon, required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final txtSec = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: txtSec.withOpacity(0.25)),
      const SizedBox(height: 10),
      Text(message, style: TextStyle(color: txtSec, fontSize: 13)),
    ]));
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  final bool isDark;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.valueColor, required this.isDark, required this.icon});

  @override
  Widget build(BuildContext context) {
    final txtSec    = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bgColor   = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderCol)),
      child: Row(children: [
        Icon(icon, size: 14, color: valueColor.withOpacity(0.6)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: txtSec, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valueColor), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    ));
  }
}

class _D {
  static const grab     = Color(0xFF00B14F);
  static const shopee   = Color(0xFFEE4D2D);
  static const takeaway = Color(0xFF0EA5E9);
  static const dineIn   = Color(0xFF0D9488);
  static const offline  = Color(0xFF94A3B8);

  static Color srcColor(String src) => switch (src) {
    'TAKE_AWAY'   => takeaway,
    'DINE_IN'     => dineIn,
    'SHOPEE_FOOD' => shopee,
    'GRAB_FOOD'   => grab,
    _             => offline,
  };

  static String srcLabel(String src) => switch (src) {
    'TAKE_AWAY'   => 'Take Away',
    'DINE_IN'     => 'Dine In',
    'SHOPEE_FOOD' => 'Shopee',
    'GRAB_FOOD'   => 'Grab',
    _             => 'Offline',
  };
}

class _OrderTile extends StatelessWidget {
  final PosOrderModel order;
  final String Function(double) formatMoney;
  final String Function(int) formatDate;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePayment;
  final bool isDark;
  final Color surfaceColor, borderColor;

  const _OrderTile({
    required this.order, required this.formatMoney, required this.formatDate,
    required this.onTap, required this.onDelete, required this.onTogglePayment,
    required this.isDark, required this.surfaceColor, required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final c      = _D.srcColor(order.orderSource);
    final txtPri = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSec = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final isCash = order.paymentMethod == 'CASH';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          // Source icon
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(_D.srcLabel(order.orderSource)[0],
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c))),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(order.orderCode, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: txtPri)),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(_D.srcLabel(order.orderSource),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c)),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.fastfood_outlined, size: 11, color: txtSec), const SizedBox(width: 4),
              Text('${order.items.length} món', style: TextStyle(fontSize: 11, color: txtSec)),
              const SizedBox(width: 10),
              Icon(Icons.schedule_outlined, size: 11, color: txtSec), const SizedBox(width: 4),
              Text(formatDate(order.createdAt), style: TextStyle(fontSize: 11, color: txtSec)),
            ]),
          ])),

          // Amount + payment + delete
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${formatMoney(order.finalAmount)}đ',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: cs.primary)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              // Payment badge — tap để toggle
              GestureDetector(
                onTap: onTogglePayment,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isCash ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isCash ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withOpacity(0.25),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isCash ? Icons.payments_outlined : Icons.account_balance_outlined,
                        size: 10, color: isCash ? const Color(0xFF10B981) : const Color(0xFF3B82F6)),
                    const SizedBox(width: 3),
                    Text(isCash ? 'Tiền mặt' : 'CK',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: isCash ? const Color(0xFF10B981) : const Color(0xFF3B82F6))),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              // Delete button
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 14, color: Colors.red),
                ),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }
}
