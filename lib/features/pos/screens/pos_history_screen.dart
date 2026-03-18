// lib/features/pos/screens/pos_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/data/models/pos/pos_shift_model.dart';
import 'package:originaltaste/data/models/pos/pos_order_model.dart';
import 'package:originaltaste/services/pos_printer_service.dart';

// ─── Design tokens ──────────────────────────────────────────
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

// ═══════════════════════════════════════════════════════════════
// ROOT SCREEN
// ═══════════════════════════════════════════════════════════════

class PosHistoryScreen extends StatefulWidget {
  const PosHistoryScreen({super.key});
  @override
  State<PosHistoryScreen> createState() => _PosHistoryScreenState();
}

class _PosHistoryScreenState extends State<PosHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final cs           = Theme.of(context).colorScheme;
    final bgColor      = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor  = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary  = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(children: [
        Container(
          color: surfaceColor,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text('Lịch sử',
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      letterSpacing: -0.5, color: textPrimary,
                    )),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabs,
                  padding: const EdgeInsets.all(4),
                  indicator: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_alt_outlined, size: 14), SizedBox(width: 6), Text('Ca làm việc'),
                    ])),
                    Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inventory_2_outlined, size: 14), SizedBox(width: 6), Text('Nhập kho'),
                    ])),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: borderColor),
            ]),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ShiftHistoryTab(isDark: isDark, surfaceColor: surfaceColor, borderColor: borderColor, bgColor: bgColor),
              _StockImportHistoryTab(isDark: isDark, surfaceColor: surfaceColor, borderColor: borderColor),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1 — Ca làm việc
// ═══════════════════════════════════════════════════════════════

class _ShiftHistoryTab extends StatefulWidget {
  final bool isDark;
  final Color surfaceColor, borderColor, bgColor;
  const _ShiftHistoryTab({
    required this.isDark, required this.surfaceColor,
    required this.borderColor, required this.bgColor,
  });
  @override
  State<_ShiftHistoryTab> createState() => _ShiftHistoryTabState();
}

class _ShiftHistoryTabState extends State<_ShiftHistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<PosShiftModel> _shifts = [];
  PosShiftModel?      _selShift;
  List<PosOrderModel> _orders = [];
  bool   _loadingShifts = true;
  bool   _loadingOrders = false;
  String _search        = '';
  String _selectedDate  = DateTime.now().toString().substring(0, 10);

  @override
  void initState() { super.initState(); _loadShifts(); }

  Future<void> _loadShifts() async {
    setState(() => _loadingShifts = true);
    try {
      final list = await PosService.instance.getShiftsByDate(_selectedDate);
      if (mounted) setState(() {
        _shifts        = list;
        _loadingShifts = false;
        if (list.isNotEmpty) { _selShift = list.first; _loadOrders(list.first.id); }
        else                 { _selShift = null; _orders = []; }
      });
    } catch (_) { if (mounted) setState(() => _loadingShifts = false); }
  }

  Future<void> _loadOrders(int shiftId) async {
    setState(() { _loadingOrders = true; _orders = []; });
    try {
      final list = await PosService.instance.getOrdersByShift(shiftId);
      if (mounted) setState(() => _orders = list);
    } catch (_) {
    } finally { if (mounted) setState(() => _loadingOrders = false); }
  }

  // ── Xóa đơn hàng ─────────────────────────────────────────────
  Future<void> _deleteOrder(PosOrderModel order) async {
    // Hiện dialog nhập mật khẩu
    final passcode = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeletePasswordDialog(orderCode: order.orderCode),
    );
    if (passcode == null || !mounted) return;

    // Gọi API xóa — backend validate passcode
    try {
      await PosService.instance.deleteOrder(order.id, passcode);
      if (!mounted) return;
      setState(() => _orders.removeWhere((o) => o.id == order.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('Đã xóa đơn ${order.orderCode}'),
        ]),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Toggle payment method ────────────────────────────────────
  Future<void> _togglePayment(PosOrderModel order) async {
    final newMethod = order.paymentMethod == 'CASH' ? 'TRANSFER' : 'CASH';
    final newLabel  = newMethod == 'CASH' ? 'Tiền mặt' : 'Chuyển khoản';
    final cs        = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark   = Theme.of(ctx).brightness == Brightness.dark;
        final surface  = widget.surfaceColor;
        final txtPri   = isDark ? Colors.white : const Color(0xFF0F172A);
        final txtSec   = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final isToCard = newMethod == 'TRANSFER';
        final color    = isToCard ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
        final icon     = isToCard ? Icons.account_balance_outlined : Icons.payments_outlined;

        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Đổi thanh toán',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: txtPri))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 4),
            Text(order.orderCode,
                style: TextStyle(fontSize: 12, color: txtSec)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              // From badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (order.paymentMethod == 'CASH'
                      ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (order.paymentMethod == 'CASH'
                      ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withOpacity(0.3)),
                ),
                child: Text(
                  order.paymentMethod == 'CASH' ? 'Tiền mặt' : 'Chuyển khoản',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: order.paymentMethod == 'CASH'
                        ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward_rounded, size: 16, color: txtSec),
              ),
              // To badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(newLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
            const SizedBox(height: 8),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Hủy', style: TextStyle(color: txtSec)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text('Xác nhận', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await PosService.instance.updateOrderPaymentMethod(order.id, newMethod);
      if (!mounted) return;
      // Reload orders list
      if (_selShift != null) _loadOrders(_selShift!.id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('Đã đổi sang $newLabel'),
        ]),
        backgroundColor: newMethod == 'TRANSFER'
            ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi: \$e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked;
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        final cs      = Theme.of(context).colorScheme;
        final surface = widget.surfaceColor;
        final textPri = widget.isDark ? Colors.white : const Color(0xFF0F172A);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: surface,
          contentPadding: EdgeInsets.zero,
          content: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              width: 320,
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: cs.primary,
                    onSurface: textPri,
                  ),
                ),
                child: CalendarDatePicker(
                  initialDate: DateTime.parse(_selectedDate),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  onDateChanged: (d) => picked = d,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Hủy')),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Chọn', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked!.toString().substring(0, 10));
      _loadShifts();
    }
  }

  String _fmt(double v)    => v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  String _fmtTime(int ts)  => ts == 0 ? '—' : DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts));
  String _fmtDT(int ts)    => ts == 0 ? '—' : DateFormat('HH:mm  dd/MM').format(DateTime.fromMillisecondsSinceEpoch(ts));

  List<PosOrderModel> get _filtered => _search.isEmpty
      ? _orders
      : _orders.where((o) => o.orderCode.toLowerCase().contains(_search.toLowerCase())).toList();

  double get _totalRevenue  => _orders.fold(0, (s, o) => s + o.finalAmount);
  int    get _orderCount    => _orders.length;
  double get _cashTotal     => _orders.where((o) => o.paymentMethod == 'CASH').fold(0, (s, o) => s + o.finalAmount);
  double get _transferTotal => _orders.where((o) => o.paymentMethod != 'CASH').fold(0, (s, o) => s + o.finalAmount);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs            = Theme.of(context).colorScheme;
    final textPrimary   = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const topRowH       = 57.0;

    return Row(children: [

      // ══ Sidebar ════════════════════════════════════════════
      Container(
        width: 190,
        decoration: BoxDecoration(
          color: widget.surfaceColor,
          border: Border(right: BorderSide(color: widget.borderColor)),
        ),
        child: Column(children: [
          InkWell(
            onTap: _pickDate,
            child: SizedBox(
              height: topRowH,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Icon(Icons.calendar_month_outlined, size: 14, color: cs.primary),
                  const SizedBox(width: 7),
                  Expanded(child: Text(_selectedDate,
                      style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w700))),
                  Icon(Icons.expand_more_rounded, color: cs.primary, size: 16),
                ]),
              ),
            ),
          ),
          Divider(height: 1, color: widget.borderColor),
          Expanded(
            child: _loadingShifts
                ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                : _shifts.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_alt_outlined, size: 36, color: textSecondary.withOpacity(0.3)),
              const SizedBox(height: 8),
              Text('Không có ca', style: TextStyle(color: textSecondary, fontSize: 12)),
            ]))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              itemCount: _shifts.length,
              itemBuilder: (_, i) {
                final s     = _shifts[i];
                final isSel = _selShift?.id == s.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () { setState(() => _selShift = s); _loadOrders(s.id); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSel ? cs.primary.withOpacity(widget.isDark ? 0.2 : 0.08) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSel ? cs.primary.withOpacity(0.4) : Colors.transparent),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(s.staffName,
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                                  color: isSel ? cs.primary : textPrimary),
                              overflow: TextOverflow.ellipsis)),
                          if (s.isOpen)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                const SizedBox(width: 3),
                                const Text('Live', style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.w800)),
                              ]),
                            ),
                        ]),
                        const SizedBox(height: 5),
                        Row(children: [
                          Icon(Icons.schedule_outlined, size: 11, color: textSecondary),
                          const SizedBox(width: 4),
                          Text('${_fmtTime(s.openTime)} – ${s.closeTime != null ? _fmtTime(s.closeTime!) : "..."}',
                              style: TextStyle(fontSize: 11, color: textSecondary)),
                        ]),
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(Icons.receipt_long_outlined, size: 11, color: textSecondary),
                          const SizedBox(width: 4),
                          Text('${s.totalOrders} đơn', style: TextStyle(fontSize: 11, color: textSecondary)),
                          const SizedBox(width: 6),
                          Expanded(child: Text('${_fmt(s.totalRevenue)}đ',
                              style: TextStyle(fontSize: 11,
                                  color: isSel ? cs.primary : textSecondary,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.normal),
                              overflow: TextOverflow.ellipsis)),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),

      // ══ Right panel ════════════════════════════════════════
      Expanded(
        child: Container(
          color: widget.bgColor,
          child: Column(children: [
            Container(
              color: widget.surfaceColor,
              height: topRowH,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _selShift != null && _orders.isNotEmpty
                  ? Row(children: [
                _StatCard(label: 'Tổng đơn',     value: '$_orderCount',             valueColor: textPrimary,              isDark: widget.isDark, icon: Icons.receipt_long_outlined),
                const SizedBox(width: 8),
                _StatCard(label: 'Doanh thu',    value: '${_fmt(_totalRevenue)}đ',  valueColor: cs.primary,               isDark: widget.isDark, icon: Icons.trending_up_rounded),
                const SizedBox(width: 8),
                _StatCard(label: 'Tiền mặt',     value: '${_fmt(_cashTotal)}đ',     valueColor: const Color(0xFF10B981),  isDark: widget.isDark, icon: Icons.payments_outlined),
                const SizedBox(width: 8),
                _StatCard(label: 'Chuyển khoản', value: '${_fmt(_transferTotal)}đ', valueColor: const Color(0xFF3B82F6),  isDark: widget.isDark, icon: Icons.account_balance_outlined),
                const SizedBox(width: 8),
                _ExportIconButton(
                  isDark: widget.isDark,
                  surfaceColor: widget.surfaceColor,
                  borderColor: widget.borderColor,
                  selectedShift: _selShift,
                ),
              ])
                  : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _ExportIconButton(
                  isDark: widget.isDark,
                  surfaceColor: widget.surfaceColor,
                  borderColor: widget.borderColor,
                  selectedShift: _selShift,
                ),
              ]),
            ),
            Divider(height: 1, color: widget.borderColor),
            Container(
              color: widget.surfaceColor,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: TextField(
                style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Tìm mã đơn hàng...',
                  hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSecondary),
                  filled: true,
                  fillColor: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.5)),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Divider(height: 1, color: widget.borderColor),
            Expanded(
              child: _loadingOrders
                  ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                  : _selShift == null
                  ? _EmptyHint(icon: Icons.touch_app_outlined, message: 'Chọn một ca để xem đơn hàng', isDark: widget.isDark)
                  : _filtered.isEmpty
                  ? _EmptyHint(icon: Icons.receipt_long_outlined, message: 'Không có đơn hàng', isDark: widget.isDark)
                  : ListView.builder(
                padding: EdgeInsets.fromLTRB(14, 12, 14, MediaQuery.of(context).padding.bottom + 12),
                itemCount: _filtered.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OrderTile(
                    order: _filtered[i],
                    formatMoney: _fmt,
                    formatDate: _fmtDT,
                    isDark: widget.isDark,
                    surfaceColor: widget.surfaceColor,
                    borderColor: widget.borderColor,
                    onTap: () => _showDetail(_filtered[i]),
                    onDelete: () => _deleteOrder(_filtered[i]),
                    onTogglePayment: () => _togglePayment(_filtered[i]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  void _showDetail(PosOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        order: order,
        formatMoney: _fmt,
        formatDate: _fmtDT,
        isDark: widget.isDark,
        surfaceColor: widget.surfaceColor,
        borderColor: widget.borderColor,
        onDelete: () {
          Navigator.pop(context);
          _deleteOrder(order);
        },
        onPrint: () => _printOrderBill(order),
      ),
    );
  }

  // ── In bill từ history ────────────────────────────────────────
  // Flow: fetch store info → kết nối IP → build bill → in
  Future<void> _printOrderBill(PosOrderModel order) async {
    if (!mounted) return;

    // Hiện loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 10),
        Text('Đang kết nối máy in...'),
      ]),
      duration: const Duration(seconds: 10),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));

    try {
      // 1. Fetch store info (name, address, phone, printerIp)
      final storeInfo = await PosService.instance.getStoreInfo();

      final printerIp = storeInfo['printerIp'] as String?;

      if (!mounted) return;

      if (printerIp == null || printerIp.trim().isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Không tìm thấy máy in, vui lòng kiểm tra lại.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        return;
      }

      // 2. Test kết nối TCP tới máy in
      final connected = await PosPrinterService.instance
          .testConnection(printerIp.trim());

      if (!mounted) return;

      if (!connected) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Không tìm thấy máy in ($printerIp), vui lòng kiểm tra lại.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        return;
      }

      // 3. Build store profile tạm (không ghi đè PrinterConfig global)
      final tempProfile = StoreProfile(
        name:      storeInfo['name']      as String? ?? '',
        address:   storeInfo['address']   as String? ?? '',
        phone:     storeInfo['phone']     as String? ?? '',
        printerIp: printerIp.trim(),
      );

      // 4. Build bill data
      final bill = BillData(
        orderCode:      order.orderCode,
        printTime:      DateTime.fromMillisecondsSinceEpoch(order.createdAt),
        cashierName:    order.staffName,
        customerPhone:  order.customerPhone,
        customerName:   order.customerName,
        orderSource:    order.orderSource,
        items: order.items.map((i) => BillItem(
          name:            i.productName,
          quantity:        i.quantity,
          unitPrice:       i.finalUnitPrice,
          discountPercent: i.discountPercent,
        )).toList(),
        subTotal:       order.totalAmount,
        discountAmount: order.discountAmount,
        vatAmount:      0,
        finalAmount:    order.finalAmount,
        paymentMethod:  order.paymentMethod,
      );

      // 5. In — dùng IP lấy trực tiếp từ store (không qua PrinterConfig)
      final result = await PosPrinterService.instance
          .printWithProfile(tempProfile, bill);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.print_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('In bill ${order.orderCode} thành công'),
          ]),
          backgroundColor: const Color(0xFF0EA5E9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi in: ${result.errorMessage}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e, stack) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// DELETE PASSWORD DIALOG
// ═══════════════════════════════════════════════════════════════

class _DeletePasswordDialog extends StatefulWidget {
  final String orderCode;
  const _DeletePasswordDialog({required this.orderCode});
  @override
  State<_DeletePasswordDialog> createState() => _DeletePasswordDialogState();
}

class _DeletePasswordDialogState extends State<_DeletePasswordDialog> {
  final _ctrl    = TextEditingController();
  bool  _obscure = true;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _confirm() {
    final pass = _ctrl.text.trim();
    if (pass.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mật khẩu');
      return;
    }
    Navigator.pop(context, pass);   // trả về passcode, để backend validate
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final txtPri  = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSec  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border  = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final bg      = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Xóa đơn hàng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: txtPri)),
          Text(widget.orderCode,
              style: TextStyle(fontSize: 12, color: txtSec, fontWeight: FontWeight.w500)),
        ])),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 4),
        // Warning box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Hành động này không thể hoàn tác.\nĐơn hàng sẽ bị xóa vĩnh viễn khỏi hệ thống.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700, height: 1.4),
            )),
          ]),
        ),
        const SizedBox(height: 16),
        // Password field
        TextField(
          controller: _ctrl,
          obscureText: _obscure,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(fontSize: 16, color: txtPri, letterSpacing: 6, fontWeight: FontWeight.w700),
          onSubmitted: (_) => _confirm(),
          decoration: InputDecoration(
            labelText: 'Mật khẩu xác nhận',
            hintText: '· · · · · ·',
            hintStyle: TextStyle(letterSpacing: 6, color: txtSec.withOpacity(0.4), fontWeight: FontWeight.w400),
            prefixIcon: Icon(Icons.lock_outline_rounded, size: 18,
                color: _error != null ? Colors.red : txtSec),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18, color: txtSec),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            errorText: _error,
            filled: true,
            fillColor: bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _error != null ? Colors.red : border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: _error != null ? Colors.red : cs.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5)),
            labelStyle: TextStyle(fontSize: 13, color: txtSec),
          ),
          onChanged: (_) { if (_error != null) setState(() => _error = null); },
        ),
        const SizedBox(height: 8),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Hủy', style: TextStyle(color: txtSec)),
        ),
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.delete_forever_rounded, size: 16),
          label: const Text('Xóa vĩnh viễn',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EXPORT ICON BUTTON + BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════

class _ExportIconButton extends StatelessWidget {
  final bool isDark;
  final Color surfaceColor, borderColor;
  final PosShiftModel? selectedShift;

  const _ExportIconButton({
    required this.isDark, required this.surfaceColor,
    required this.borderColor, required this.selectedShift,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ExportSheet(
          isDark: isDark, surfaceColor: surfaceColor, borderColor: borderColor,
          selectedShift: selectedShift,
        ),
      ),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF14B8A6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.3)),
        ),
        child: const Icon(Icons.send_outlined, size: 16, color: Color(0xFF14B8A6)),
      ),
    );
  }
}

class _ExportSheet extends StatefulWidget {
  final bool isDark;
  final Color surfaceColor, borderColor;
  final PosShiftModel? selectedShift;
  const _ExportSheet({
    required this.isDark, required this.surfaceColor,
    required this.borderColor, required this.selectedShift,
  });
  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  bool _loading = false;

  Future<void> _export({int? shiftId, String? from, String? to}) async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final String msg;
      if (shiftId != null) {
        msg = await PosService.instance.triggerShiftReport(shiftId);
      } else {
        msg = await PosService.instance.triggerRangeReport(from: from!, to: to!);
      }
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.telegram, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
        ]),
        backgroundColor: const Color(0xFF14B8A6),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text('Lỗi: $e'), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickRange() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final surface   = widget.surfaceColor;
    final isDark    = widget.isDark;
    final cs        = Theme.of(context).colorScheme;
    final rootCtx   = context;
    Navigator.pop(context);

    final result = await showDialog<(DateTime, DateTime)?>(
      context: rootCtx,
      barrierDismissible: true,
      builder: (dialogCtx) => _DateRangePickerDialog(
        isDark: isDark, surfaceColor: surface, accentColor: cs.primary,
      ),
    );

    if (result != null) {
      final (from, to) = result;
      final f = '${from.year}-${from.month.toString().padLeft(2,'0')}-${from.day.toString().padLeft(2,'0')}';
      final t = '${to.year}-${to.month.toString().padLeft(2,'0')}-${to.day.toString().padLeft(2,'0')}';
      _callRangeApi(messenger: messenger, from: f, to: t);
    }
  }

  Future<void> _callRangeApi({required ScaffoldMessengerState messenger, required String from, required String to}) async {
    try {
      final msg = await PosService.instance.triggerRangeReport(from: from, to: to);
      messenger.showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.telegram, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
        ]),
        backgroundColor: const Color(0xFF14B8A6),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final txtPri = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSec = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final s      = widget.selectedShift;
    const teal   = Color(0xFF14B8A6);

    return Container(
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 36),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: txtSec.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.telegram, color: teal, size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Gửi báo cáo Telegram', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: txtPri)),
            Text('Báo cáo Excel sẽ gửi vào nhóm Telegram', style: TextStyle(fontSize: 12, color: txtSec)),
          ]),
        ]),
        const SizedBox(height: 24),
        _ExportOption(
          icon: Icons.receipt_long_outlined,
          title: 'Gửi ca đang chọn',
          subtitle: s != null ? 'Ca #${s.id} · ${s.staffName} · ${s.shiftDate}' : 'Chưa chọn ca nào',
          color: teal,
          enabled: s != null && !_loading,
          isDark: widget.isDark,
          onTap: () => _export(shiftId: s!.id),
        ),
        const SizedBox(height: 14),
        _ExportOption(
          icon: Icons.date_range_outlined,
          title: 'Gửi theo khoảng ngày',
          subtitle: 'Chọn ngày bắt đầu và kết thúc (ca đã đóng)',
          color: const Color(0xFFF97316),
          enabled: !_loading,
          isDark: widget.isDark,
          onTap: _pickRange,
        ),
        if (_loading) ...[
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: teal)),
            const SizedBox(width: 10),
            Text('Đang gửi yêu cầu...', style: TextStyle(color: teal, fontSize: 13)),
          ]),
        ],
      ]),
    );
  }
}

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final bool enabled, isDark;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.enabled, required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final txtPri = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSec = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final bg     = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(isDark ? 0.08 : 0.05) : bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: enabled ? color.withOpacity(0.3) : txtSec.withOpacity(0.15), width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: enabled ? color.withOpacity(0.12) : txtSec.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: enabled ? color : txtSec, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: enabled ? txtPri : txtSec)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: txtSec)),
          ])),
          Icon(Icons.chevron_right_rounded, color: enabled ? color : txtSec.withOpacity(0.3), size: 20),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 2 — Nhập kho
// ═══════════════════════════════════════════════════════════════

class _StockImportHistoryTab extends StatefulWidget {
  final bool isDark;
  final Color surfaceColor, borderColor;
  const _StockImportHistoryTab({required this.isDark, required this.surfaceColor, required this.borderColor});
  @override
  State<_StockImportHistoryTab> createState() => _StockImportHistoryTabState();
}

class _StockImportHistoryTabState extends State<_StockImportHistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await PosService.instance.getStockImportHistory();
      if (mounted) setState(() => _records = list);
    } catch (_) {
    } finally { if (mounted) setState(() => _loading = false); }
  }

  String _fmtDT(dynamic ts) {
    if (ts == null) return '—';
    final ms = ts is int ? ts * 1000 : (ts as num).toInt() * 1000;
    return DateFormat('HH:mm  dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs     = Theme.of(context).colorScheme;
    final txtSec = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final txtPri = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    if (_loading) return Center(child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary));
    if (_records.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cs.primary.withOpacity(0.06), shape: BoxShape.circle),
          child: Icon(Icons.inventory_2_outlined, size: 40, color: cs.primary.withOpacity(0.4))),
      const SizedBox(height: 16),
      Text('Chưa có lịch sử nhập kho', style: TextStyle(color: txtSec, fontSize: 14, fontWeight: FontWeight.w500)),
    ]));

    return RefreshIndicator(
      onRefresh: _load, color: cs.primary,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
        itemCount: _records.length,
        itemBuilder: (_, i) {
          final r         = _records[i];
          final items     = r['items'] as List<dynamic>? ?? [];
          final note      = r['note'] as String?;
          final staffName = r['staffName'] as String? ?? '—';
          final importedAt = r['importedAt'];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: widget.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.borderColor),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.inventory_2_outlined, size: 16, color: cs.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(staffName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: txtPri)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.schedule_outlined, size: 11, color: txtSec),
                      const SizedBox(width: 4),
                      Text(_fmtDT(importedAt), style: TextStyle(fontSize: 11, color: txtSec)),
                    ]),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: cs.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                    child: Text('${items.length} loại', style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              Divider(height: 1, color: widget.borderColor, indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Wrap(spacing: 6, runSpacing: 6,
                  children: items.map((item) {
                    final m    = item as Map<String, dynamic>;
                    final name = m['ingredientName'] as String? ?? '?';
                    final qty  = (m['packQty'] as num?)?.toDouble() ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.borderColor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: txtPri)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                          child: Text('+${_fmt(qty)}', style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ),
              if (note != null && note.isNotEmpty) ...[
                Divider(height: 1, color: widget.borderColor, indent: 14, endIndent: 14),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.notes_rounded, size: 13, color: txtSec),
                    const SizedBox(width: 6),
                    Expanded(child: Text(note, style: TextStyle(fontSize: 12, color: txtSec, fontStyle: FontStyle.italic))),
                  ]),
                ),
              ] else const SizedBox(height: 4),
            ]),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Order Tile  ← THÊM onDelete callback + nút thùng rác
// ═══════════════════════════════════════════════════════════════

class _OrderTile extends StatelessWidget {
  final PosOrderModel order;
  final String Function(double) formatMoney;
  final String Function(int) formatDate;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onTogglePayment;   // ← THÊM
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

// ═══════════════════════════════════════════════════════════════
// Order Detail Sheet  ← THÊM nút Xóa đơn
// ═══════════════════════════════════════════════════════════════

class _OrderDetailSheet extends StatelessWidget {
  final PosOrderModel order;
  final String Function(double) formatMoney;
  final String Function(int) formatDate;
  final bool isDark;
  final Color surfaceColor, borderColor;
  final VoidCallback onDelete;
  final VoidCallback onPrint;    // ← THÊM

  const _OrderDetailSheet({
    required this.order, required this.formatMoney, required this.formatDate,
    required this.isDark, required this.surfaceColor, required this.borderColor,
    required this.onDelete,
    required this.onPrint,       // ← THÊM
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final txtPri = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSec = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final c      = _D.srcColor(order.orderSource);
    final isCash = order.paymentMethod == 'CASH';

    return Container(
      decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 36, height: 4,
            decoration: BoxDecoration(color: txtSec.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),

        // Header row
        Row(children: [
          Container(padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Text(_D.srcLabel(order.orderSource)[0],
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(order.orderCode,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: txtPri)),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
                  child: Text(_D.srcLabel(order.orderSource),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: (isCash ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(isCash ? 'Tiền mặt' : 'Chuyển khoản',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: isCash ? const Color(0xFF10B981) : const Color(0xFF3B82F6))),
              ),
            ]),
          ])),

          // Print button
          IconButton(
            onPressed: onPrint,
            icon: const Icon(Icons.print_rounded,
                color: Color(0xFF0EA5E9), size: 20),
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
                minimumSize: const Size(32, 32)),
          ),
        ]),

        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.schedule_outlined, size: 12, color: txtSec), const SizedBox(width: 5),
          Text(formatDate(order.createdAt), style: TextStyle(fontSize: 12, color: txtSec)),
        ]),
        const SizedBox(height: 16),
        Divider(color: borderColor, height: 1),
        const SizedBox(height: 12),

        // Items
        ...order.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(color: cs.primary.withOpacity(0.5), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(item.productName,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: txtPri))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: txtSec.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: Text('×${item.quantity}',
                  style: TextStyle(color: txtSec, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Text('${formatMoney(item.subtotal)}đ',
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary, fontSize: 13)),
          ]),
        )),

        const SizedBox(height: 4),
        Divider(color: borderColor, height: 1),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Tổng cộng',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: txtPri)),
          Text('${formatMoney(order.finalAmount)}đ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.primary)),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Date Range Picker Dialog
// ═══════════════════════════════════════════════════════════════

class _DateRangePickerDialog extends StatefulWidget {
  final bool isDark;
  final Color surfaceColor, accentColor;
  const _DateRangePickerDialog({
    required this.isDark, required this.surfaceColor, required this.accentColor,
  });
  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  static const teal = Color(0xFF14B8A6);

  DateTime?  _from;
  DateTime?  _to;
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _from = DateTime.now().subtract(const Duration(days: 6));
    _to   = DateTime.now();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _inRange(DateTime d) {
    if (_from == null || _to == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    final f   = DateTime(_from!.year, _from!.month, _from!.day);
    final t   = DateTime(_to!.year, _to!.month, _to!.day);
    return day.isAfter(f) && day.isBefore(t);
  }

  bool _isFrom(DateTime d)  => _from != null && _isSameDay(d, _from!);
  bool _isTo(DateTime d)    => _to   != null && _isSameDay(d, _to!);
  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

  void _onTap(DateTime d) {
    final today = DateTime.now();
    if (d.isAfter(today)) return;
    setState(() {
      if (_from == null || (_from != null && _to != null)) {
        _from = d; _to = null;
      } else {
        if (d.isBefore(_from!)) { _to = _from; _from = d; }
        else                    { _to = d; }
      }
    });
  }

  String _fmtHeader(DateTime d) {
    const months = ['Tháng 1','Tháng 2','Tháng 3','Tháng 4','Tháng 5','Tháng 6',
      'Tháng 7','Tháng 8','Tháng 9','Tháng 10','Tháng 11','Tháng 12'];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _fmtDisp(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final txtPri  = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSec  = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final divider = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final days    = (_from != null && _to != null)
        ? _to!.difference(_from!).inDays + 1
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: widget.surfaceColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.date_range, color: teal, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Chọn khoảng ngày',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: txtPri)),
                Text(
                  (_from == null) ? 'Chọn ngày bắt đầu'
                      : (_to == null) ? 'Chọn ngày kết thúc'
                      : '${_fmtDisp(_from!)}  →  ${_fmtDisp(_to!)}',
                  style: TextStyle(fontSize: 12,
                      color: _from != null && _to != null ? teal : txtSec,
                      fontWeight: _from != null && _to != null ? FontWeight.w600 : FontWeight.normal),
                ),
              ])),
              if (days != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: teal.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('$days ngày', style: const TextStyle(fontSize: 12, color: teal, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: txtSec),
                onPressed: () => setState(() =>
                _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1)),
              ),
              Expanded(child: Center(child: Text(_fmtHeader(_displayMonth),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: txtPri)))),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    color: _displayMonth.year == DateTime.now().year &&
                        _displayMonth.month == DateTime.now().month
                        ? txtSec.withOpacity(0.3) : txtSec),
                onPressed: _displayMonth.year == DateTime.now().year &&
                    _displayMonth.month == DateTime.now().month
                    ? null
                    : () => setState(() =>
                _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: ['T2','T3','T4','T5','T6','T7','CN'].map((d) =>
                Expanded(child: Center(child: Text(d,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: txtSec))))
            ).toList()),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildGrid(txtPri, txtSec),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text('Hủy', style: TextStyle(color: txtSec)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.telegram, size: 16),
                label: const Text('Gửi Telegram'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: teal.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _from != null && _to != null
                    ? () => Navigator.pop(context, (_from!, _to!))
                    : null,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildGrid(Color txtPri, Color txtSec) {
    final today     = DateTime.now();
    final firstDay  = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final startWd   = (firstDay.weekday - 1) % 7;
    final daysInMo  = DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);
    final totalCells = startWd + daysInMo;
    final rows      = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: List.generate(7, (col) {
          final idx    = row * 7 + col;
          final dayNum = idx - startWd + 1;
          if (dayNum < 1 || dayNum > daysInMo) return const Expanded(child: SizedBox(height: 38));
          final d        = DateTime(_displayMonth.year, _displayMonth.month, dayNum);
          final future   = d.isAfter(today);
          final isFrom   = _isFrom(d);
          final isTo     = _isTo(d);
          final inRange  = _inRange(d);
          final isToday  = _isToday(d);
          final selected = isFrom || isTo;

          return Expanded(child: GestureDetector(
            onTap: future ? null : () => _onTap(d),
            child: SizedBox(
              height: 38,
              child: Stack(alignment: Alignment.center, children: [
                if (inRange || isFrom || isTo)
                  Positioned.fill(child: Row(children: [
                    Expanded(child: Container(
                      color: (isFrom && !isTo) ? Colors.transparent : const Color(0xFF14B8A6).withOpacity(0.12),
                    )),
                    Expanded(child: Container(
                      color: (isTo && !isFrom) ? Colors.transparent : const Color(0xFF14B8A6).withOpacity(0.12),
                    )),
                  ])),
                if (selected)
                  Container(width: 34, height: 34,
                      decoration: const BoxDecoration(color: Color(0xFF14B8A6), shape: BoxShape.circle)),
                if (isToday && !selected)
                  Container(width: 34, height: 34,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.5), width: 1.5))),
                Text('$dayNum', style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : isToday ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white
                      : future ? txtSec.withOpacity(0.25)
                      : inRange ? const Color(0xFF14B8A6)
                      : txtPri,
                )),
              ]),
            ),
          ));
        })),
      )),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════════

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