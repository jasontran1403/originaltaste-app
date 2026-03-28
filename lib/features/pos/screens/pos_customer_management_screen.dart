// lib/features/pos/screens/pos_customer_management_screen.dart
//
// Màn hình quản lý khách hàng + chương trình khuyến mãi POS
// Design: Minimal-refined, teal accent, dark/light adaptive

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:originaltaste/data/network/dio_client.dart';
import 'package:originaltaste/core/constants/api_constants.dart';

// ─── Models ──────────────────────────────────────────────────────

class PosCustomerMgmt {
  final int    id;
  final String phone;
  final String name;
  final double totalSpend;
  final String createdAt;
  // ── Thêm mới ──
  final String? dateOfBirth;
  final String? deliveryAddress;
  final int?    referredByCustomerId;
  final String? referredByName;
  final String? referredByPhone;

  const PosCustomerMgmt({
    required this.id,
    required this.phone,
    required this.name,
    required this.totalSpend,
    required this.createdAt,
    this.dateOfBirth,
    this.deliveryAddress,
    this.referredByCustomerId,
    this.referredByName,
    this.referredByPhone,
  });

  factory PosCustomerMgmt.fromJson(Map<String, dynamic> j) => PosCustomerMgmt(
    id:                   (j['id'] as num).toInt(),
    phone:                j['phone'] as String,
    name:                 j['name'] as String,
    totalSpend:           (j['totalSpend'] as num?)?.toDouble() ?? 0,
    createdAt:            j['createdAt']?.toString() ?? '',
    dateOfBirth:          j['dateOfBirth'] as String?,
    deliveryAddress:      j['deliveryAddress'] as String?,
    // ← đổi as int? thành (... as num?)?.toInt()
    referredByCustomerId: (j['referredByCustomerId'] as num?)?.toInt(),
    referredByName:       j['referredByName'] as String?,
    referredByPhone:      j['referredByPhone'] as String?,
  );
}

class DiscountOptionMgmt {
  final int?   id;
  String discountType;  // PERCENT_BILL|FIXED_BILL|PERCENT_ITEM|FIXED_ITEM
  double discountValue;
  double? maxPerUse;
  String? label;

  DiscountOptionMgmt({
    this.id,
    required this.discountType,
    required this.discountValue,
    this.maxPerUse,
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'discountType':  discountType,
    'discountValue': discountValue,
    if (maxPerUse != null) 'maxPerUse': maxPerUse,
    if (label != null && label!.isNotEmpty) 'label': label,
  };
}

class DiscountProgramMgmt {
  final int    id;
  final String name;
  final String status;
  final double minSpend;
  final double maxDiscountPerCustomer;
  final int    qualifyFrom;
  final int    qualifyTo;
  final int    applyFrom;
  final int    applyTo;
  final List<Map<String, dynamic>> options;

  const DiscountProgramMgmt({
    required this.id,
    required this.name,
    required this.status,
    required this.minSpend,
    required this.maxDiscountPerCustomer,
    required this.qualifyFrom,
    required this.qualifyTo,
    required this.applyFrom,
    required this.applyTo,
    required this.options,
  });

  factory DiscountProgramMgmt.fromJson(Map<String, dynamic> j) =>
      DiscountProgramMgmt(
        id:                     j['id'] as int,
        name:                   j['name'] as String,
        status:                 j['status'] as String,
        minSpend:               (j['minSpend'] as num).toDouble(),
        maxDiscountPerCustomer: (j['maxDiscountPerCustomer'] as num).toDouble(),
        qualifyFrom:            (j['qualifyFrom'] as num).toInt(),
        qualifyTo:              (j['qualifyTo'] as num).toInt(),
        applyFrom:              (j['applyFrom'] as num).toInt(),
        applyTo:                (j['applyTo'] as num).toInt(),
        options: (j['options'] as List? ?? [])
            .map((e) => e as Map<String, dynamic>).toList(),
      );

  bool get isActive => status == 'ACTIVE';
  bool get isDraft  => status == 'DRAFT';
}

// ─── Main Screen ──────────────────────────────────────────────────

class PosCustomerManagementScreen extends StatefulWidget {
  const PosCustomerManagementScreen({super.key});

  @override
  State<PosCustomerManagementScreen> createState() =>
      _PosCustomerManagementScreenState();
}

class _PosCustomerManagementScreenState
    extends State<PosCustomerManagementScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tab;
  bool _isLoading = false;

  // customers
  List<PosCustomerMgmt> _customers = [];
  String _customerSearch = '';
  Timer? _searchDebounce;

  // programs
  List<DiscountProgramMgmt> _programs = [];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadCustomers(), _loadPrograms()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadCustomers({String? search}) async {
    try {
      final q = search ?? _customerSearch;
      final endpoint = q.length >= 3
          ? '${ApiConstants.posBase}/customers/search?phone=$q'
          : '${ApiConstants.posBase}/customers';
      final res = await DioClient.instance.get<List<PosCustomerMgmt>>(
        endpoint,
        fromData: (d) => (d as List)
            .map((e) => PosCustomerMgmt.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      if (mounted) setState(() => _customers = res.data ?? []);
    } catch (_) {}
  }

  Future<void> _loadPrograms() async {
    try {
      final res = await DioClient.instance.get<List<DiscountProgramMgmt>>(
        '${ApiConstants.posBase}/discounts/programs',
        fromData: (d) => (d as List)
            .map((e) => DiscountProgramMgmt.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      if (mounted) setState(() => _programs = res.data ?? []);
    } catch (_) {}
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _loadCustomers(search: v);
    });
  }

  // ── Color helpers ─────────────────────────────────────────────
  Color _statusColor(String status, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (status) {
      'ACTIVE'    => const Color(0xFF0D9488),
      'DRAFT'     => cs.onSurface.withOpacity(0.45),
      'ENDED'     => cs.error.withOpacity(0.8),
      'CANCELLED' => cs.error,
      _           => cs.onSurface.withOpacity(0.4),
    };
  }

  String _statusLabel(String s) => switch (s) {
    'ACTIVE'    => 'Đang chạy',
    'DRAFT'     => 'Nháp',
    'ENDED'     => 'Đã kết thúc',
    'CANCELLED' => 'Đã hủy',
    _           => s,
  };

  String _fmtMoney(double v) =>
      NumberFormat('#,###', 'vi_VN').format(v);

  String _fmtMs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final teal     = const Color(0xFF0D9488);
    final tealLight= const Color(0xFF99F6E4);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Stack(alignment: Alignment.center, children: [
                  Text('Khách hàng & KM',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface)),
                ]),
              ),

              // Segmented pill tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.35)
                        : cs.onSurface.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tab,
                    indicator: BoxDecoration(
                      color: const Color(0xFF4ADE80),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.black,
                    unselectedLabelColor: cs.onSurface.withOpacity(0.5),
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13),
                    splashFactory: NoSplash.splashFactory,
                    overlayColor:
                    WidgetStateProperty.all(Colors.transparent),
                    padding: const EdgeInsets.all(3),
                    tabs: const [
                      Tab(height: 34, text: 'Khách hàng'),
                      Tab(height: 34, text: 'Chương trình KM'),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),

        // ── Tab content ─────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _CustomerTab(
                customers: _customers,
                onSearch: _onSearchChanged,
                onRefresh: _loadCustomers,
                fmtMoney: _fmtMoney,
                onAdd: () => _showCustomerForm(null),
                onEdit: (c) => _showCustomerForm(c),
              ),
              _ProgramTab(
                programs: _programs,
                onRefresh: _loadPrograms,
                onAdd: () => _showProgramForm(),
                onEnd: (p) => _confirmEndProgram(p),
                onActivate: (p) => _activateProgram(p),
                statusColor: (s) => _statusColor(s, context),
                statusLabel: _statusLabel,
                fmtMoney: _fmtMoney,
                fmtMs: _fmtMs,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Customer form ─────────────────────────────────────────────
  Future<void> _showCustomerForm(PosCustomerMgmt? customer) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => _CustomerFormSheet(
        customer: customer,
        onSaved: _loadCustomers,
      ),
    );
  }

  // ── Program form ──────────────────────────────────────────────
  Future<void> _showProgramForm() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => _ProgramFormSheet(
        onSaved: _loadPrograms,
      ),
    );
  }

  Future<void> _confirmEndProgram(DiscountProgramMgmt p) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Kết thúc chương trình'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Chương trình "${p.name}" sẽ bị kết thúc sớm.'),
            const SizedBox(height: 12),
            TextField(controller: ctrl,
                decoration: const InputDecoration(
                    labelText: 'Lý do (tuỳ chọn)',
                    border: OutlineInputBorder())),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Kết thúc'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await DioClient.instance.put(
        '${ApiConstants.posBase}/discounts/programs/${p.id}/end',
        body: {'reason': reason},
      );
      _loadPrograms();
    } catch (e) {
      if (mounted) _snack('Lỗi: $e', isError: true);
    }
  }

  Future<void> _activateProgram(DiscountProgramMgmt p) async {
    try {
      await DioClient.instance.put(
        '${ApiConstants.posBase}/discounts/programs/${p.id}/activate',
        body: {},
      );
      _loadPrograms();
      if (mounted) _snack('Đã kích hoạt chương trình!');
    } catch (e) {
      if (mounted) _snack('Lỗi: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ─── Customer Tab ─────────────────────────────────────────────────

class _CustomerTab extends StatelessWidget {
  final List<PosCustomerMgmt> customers;
  final ValueChanged<String> onSearch;
  final VoidCallback onRefresh;
  final String Function(double) fmtMoney;
  final VoidCallback onAdd;
  final ValueChanged<PosCustomerMgmt> onEdit;

  const _CustomerTab({
    required this.customers,
    required this.onSearch,
    required this.onRefresh,
    required this.fmtMoney,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = const Color(0xFF0D9488);

    return Column(children: [
      // Search + Add
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8)],
              ),
              child: TextField(
                onChanged: onSearch,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Tìm theo SĐT...',
                  prefixIcon: Icon(Icons.search_rounded,
                      color: cs.onSurface.withOpacity(0.4)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Thêm'),
            style: FilledButton.styleFrom(
              backgroundColor: teal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),

      // Stats row
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Text('${customers.length} khách hàng',
              style: TextStyle(fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5))),
        ]),
      ),

      // List
      Expanded(
        child: customers.isEmpty
            ? _emptyState('Chưa có khách hàng', Icons.people_outline_rounded)
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          itemCount: customers.length,
          itemBuilder: (_, i) => _CustomerCard(
            customer: customers[i],
            fmtMoney: fmtMoney,
            onTap: () => onEdit(customers[i]),
          ),
        ),
      ),
    ]);
  }
}

class _CustomerCard extends StatelessWidget {
  final PosCustomerMgmt customer;
  final String Function(double) fmtMoney;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.fmtMoney,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = const Color(0xFF0D9488);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: teal.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: Center(child: Text(
                customer.name.isNotEmpty
                    ? customer.name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w800, color: teal),
              )),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(customer.phone, style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withOpacity(0.55),
                      letterSpacing: 0.5)),
                ])),

            // Spend
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtMoney(customer.totalSpend),
                  style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: teal)),
              Text('đ chi tiêu', style: TextStyle(
                  fontSize: 10, color: cs.onSurface.withOpacity(0.4))),
            ]),

            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: cs.onSurface.withOpacity(0.3)),
          ]),
        ),
      ),
    );
  }
}

// ─── Program Tab ──────────────────────────────────────────────────

class _ProgramTab extends StatelessWidget {
  final List<DiscountProgramMgmt> programs;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;
  final ValueChanged<DiscountProgramMgmt> onEnd;
  final ValueChanged<DiscountProgramMgmt> onActivate;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final String Function(double) fmtMoney;
  final String Function(int) fmtMs;

  const _ProgramTab({
    required this.programs,
    required this.onRefresh,
    required this.onAdd,
    required this.onEnd,
    required this.onActivate,
    required this.statusColor,
    required this.statusLabel,
    required this.fmtMoney,
    required this.fmtMs,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = const Color(0xFF0D9488);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Text('${programs.length} chương trình',
              style: TextStyle(fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5))),
          const Spacer(),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tạo CT'),
            style: FilledButton.styleFrom(
              backgroundColor: teal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
      Expanded(
        child: programs.isEmpty
            ? _emptyState('Chưa có chương trình', Icons.card_giftcard_rounded)
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          itemCount: programs.length,
          itemBuilder: (_, i) => _ProgramCard(
            program: programs[i],
            onEnd: () => onEnd(programs[i]),
            onActivate: () => onActivate(programs[i]),
            statusColor: statusColor(programs[i].status),
            statusLabel: statusLabel(programs[i].status),
            fmtMoney: fmtMoney,
            fmtMs: fmtMs,
          ),
        ),
      ),
    ]);
  }
}

class _ProgramCard extends StatefulWidget {
  final DiscountProgramMgmt program;
  final VoidCallback onEnd;
  final VoidCallback onActivate;
  final Color statusColor;
  final String statusLabel;
  final String Function(double) fmtMoney;
  final String Function(int) fmtMs;

  const _ProgramCard({
    required this.program,
    required this.onEnd,
    required this.onActivate,
    required this.statusColor,
    required this.statusLabel,
    required this.fmtMoney,
    required this.fmtMs,
  });

  @override
  State<_ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends State<_ProgramCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p    = widget.program;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Header row
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Status dot
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: widget.statusColor,
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      'Áp dụng: ${widget.fmtMs(p.applyFrom)} → ${widget.fmtMs(p.applyTo)}',
                      style: TextStyle(fontSize: 11,
                          color: cs.onSurface.withOpacity(0.5)),
                    ),
                  ])),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: widget.statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(widget.statusLabel,
                    style: TextStyle(fontSize: 11,
                        color: widget.statusColor,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: cs.onSurface.withOpacity(0.4)),
              ),
            ]),
          ),
        ),

        // Expanded details
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: cs.onSurface.withOpacity(0.08)),
                  const SizedBox(height: 8),
                  _infoRow(context, 'Chi tiêu tối thiểu',
                      '${widget.fmtMoney(p.minSpend)}đ'),
                  _infoRow(context, 'Hạn mức/khách',
                      '${widget.fmtMoney(p.maxDiscountPerCustomer)}đ'),
                  _infoRow(context, 'Kỳ tính',
                      '${widget.fmtMs(p.qualifyFrom)} → ${widget.fmtMs(p.qualifyTo)}'),
                  if (p.options.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Các lựa chọn giảm giá:',
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withOpacity(0.6))),
                    const SizedBox(height: 6),
                    ...p.options.map((opt) => _OptionChip(opt: opt)),
                  ],
                  const SizedBox(height: 12),
                  // Action buttons
                  Row(children: [
                    if (p.isDraft) ...[
                      Expanded(child: OutlinedButton.icon(
                        onPressed: widget.onActivate,
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: const Text('Kích hoạt',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: Color(0xFF0D9488)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      )),
                      const SizedBox(width: 8),
                    ],
                    if (p.isActive || p.isDraft)
                      Expanded(child: OutlinedButton.icon(
                        onPressed: widget.onEnd,
                        icon: const Icon(Icons.stop_rounded, size: 16),
                        label: const Text('Kết thúc sớm',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(
                              color: Colors.red, width: 0.8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      )),
                  ]),
                ]),
          )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text('$label: ', style: TextStyle(
            fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
        Text(value, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: cs.onSurface)),
      ]),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final Map<String, dynamic> opt;
  const _OptionChip({required this.opt});

  String get _typeLabel => switch (opt['discountType'] as String) {
    'PERCENT_BILL' => '% bill',
    'FIXED_BILL'   => 'tiền bill',
    'PERCENT_ITEM' => '% món',
    'FIXED_ITEM'   => 'tiền món',
    _ => opt['discountType'] as String,
  };

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final val  = (opt['discountValue'] as num).toDouble();
    final max  = opt['maxPerUse'] != null
        ? (opt['maxPerUse'] as num).toDouble() : null;
    final isPercent = (opt['discountType'] as String).startsWith('PERCENT');
    final valStr = isPercent ? '${val.toInt()}%' : '${(val/1000).toInt()}k';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF0D9488).withOpacity(0.12)
            : const Color(0xFFCCFBF1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.local_offer_rounded, size: 12,
            color: const Color(0xFF0D9488)),
        const SizedBox(width: 5),
        Text(
          opt['label'] != null && (opt['label'] as String).isNotEmpty
              ? opt['label'] as String
              : 'Giảm $valStr $_typeLabel'
              '${max != null ? " (tối đa ${(max/1000).toInt()}k)" : ""}',
          style: const TextStyle(fontSize: 11,
              color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}

// ─── Customer Form Sheet ──────────────────────────────────────────

class _CustomerFormSheet extends StatefulWidget {
  final PosCustomerMgmt? customer;
  final VoidCallback onSaved;

  const _CustomerFormSheet({this.customer, required this.onSaved});

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _phoneCtrl   = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();

  DateTime? _selectedDob;
  bool _isSaving = false;

  bool get _isEdit => widget.customer != null;

  // ── DOB helpers ───────────────────────────────────────────────

  String _fmtDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

  DateTime? _parseDob(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  String? _dobToApi() {
    if (_selectedDob == null) return null;
    return '${_selectedDob!.year}-'
        '${_selectedDob!.month.toString().padLeft(2, '0')}-'
        '${_selectedDob!.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final c = widget.customer!;
      _phoneCtrl.text   = c.phone;
      _nameCtrl.text    = c.name;
      _addressCtrl.text = c.deliveryAddress ?? '';
      _selectedDob      = _parseDob(c.dateOfBirth);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────

  Future<void> _pickDob() async {
    final cs = Theme.of(context).colorScheme;
    DateTime? picked;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Chọn ngày sinh',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 300,
          child: CalendarDatePicker(
            initialDate: _selectedDob ?? DateTime(1990, 1, 1),
            firstDate:   DateTime(1920),
            lastDate:    DateTime.now(),
            onDateChanged: (d) => picked = d,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedDob = null);
            },
            child: Text('Xóa', style: TextStyle(color: cs.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (picked != null) setState(() => _selectedDob = picked);
            },
            child: const Text('Chọn'),
          ),
        ],
      ),
    );
  }

  // ── Save ─────────────────────────────────────────────────────

  Future<void> _save() async {
    final phone = _phoneCtrl.text.trim();
    final name  = _nameCtrl.text.trim();
    if (phone.isEmpty || name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final body = <String, dynamic>{
        'phone': phone,
        'name':  name,
      };
      if (_addressCtrl.text.trim().isNotEmpty)
        body['deliveryAddress'] = _addressCtrl.text.trim();
      if (_dobToApi() != null)
        body['dateOfBirth'] = _dobToApi()!;
      // Referrer KHÔNG gửi khi edit (backend sẽ bỏ qua nếu đã có)

      await DioClient.instance.post(
        '${ApiConstants.posBase}/customers',
        body: body,
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    const teal   = Color(0xFF0D9488);
    final surf   = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bg     = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final txtSec = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Handle
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2)),
          )),

          // Title
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(
                _isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                size: 18, color: teal,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _isEdit ? 'Cập nhật khách hàng' : 'Thêm khách hàng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: cs.onSurface),
            ),
          ]),
          const SizedBox(height: 20),

          // ── SĐT (readonly khi edit) ─────────────────────────
          _buildField(
            controller: _phoneCtrl,
            label: 'Số điện thoại *',
            hint: '0938 121 001',
            icon: Icons.phone_rounded,
            readOnly: _isEdit,
            keyboard: TextInputType.phone,
            formatters: [FilteringTextInputFormatter.allow(
                RegExp(r'[\d\s+\-]'))],
            isDark: isDark, cs: cs, bg: bg, border: border, teal: teal,
          ),
          const SizedBox(height: 12),

          // ── Tên ─────────────────────────────────────────────
          _buildField(
            controller: _nameCtrl,
            label: 'Họ và tên *',
            hint: 'Nguyễn Văn A',
            icon: Icons.person_rounded,
            isDark: isDark, cs: cs, bg: bg, border: border, teal: teal,
          ),
          const SizedBox(height: 12),

          // ── Ngày sinh — calendar picker ──────────────────────
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedDob != null
                      ? teal.withOpacity(0.5) : border,
                  width: _selectedDob != null ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Icon(Icons.cake_rounded, size: 18,
                    color: teal.withOpacity(0.7)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  _selectedDob != null
                      ? _fmtDob(_selectedDob!)
                      : 'Ngày sinh (tùy chọn)',
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedDob != null
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : txtSec.withOpacity(0.6),
                  ),
                )),
                if (_selectedDob != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedDob = null),
                    child: Icon(Icons.clear_rounded, size: 16,
                        color: txtSec.withOpacity(0.5)),
                  )
                else
                  Icon(Icons.arrow_drop_down_rounded, size: 20,
                      color: txtSec.withOpacity(0.5)),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // ── Địa chỉ giao hàng ────────────────────────────────
          TextFormField(
            controller: _addressCtrl,
            maxLines: 2,
            keyboardType: TextInputType.multiline,
            style: TextStyle(fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Địa chỉ giao hàng (tùy chọn)',
              hintText: '123 Nguyễn Trãi, Q5, TP.HCM',
              prefixIcon: Icon(Icons.location_on_rounded, size: 18,
                  color: teal.withOpacity(0.7)),
              filled: true, fillColor: bg,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: teal, width: 1.5)),
              labelStyle: TextStyle(fontSize: 13, color: txtSec),
              hintStyle: TextStyle(fontSize: 13,
                  color: txtSec.withOpacity(0.6)),
            ),
          ),

          // ── Người giới thiệu (chỉ hiện khi thêm mới) ────────
          if (!_isEdit) ...[
            const SizedBox(height: 12),
            _ReferrerField(
              isDark: isDark, cs: cs, bg: bg,
              border: border, teal: teal, txtSec: txtSec,
              myPhone: _phoneCtrl.text,
            ),
          ],

          // ── Info khi edit: người giới thiệu hiện tại ─────────
          if (_isEdit &&
              widget.customer!.referredByCustomerId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: teal.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: teal.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.people_alt_rounded,
                    size: 14, color: teal),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Giới thiệu bởi: ${widget.customer!.referredByName ?? ""}'
                      ' (${widget.customer!.referredByPhone ?? ""})',
                  style: TextStyle(fontSize: 12, color: txtSec),
                )),
              ]),
            ),
          ],

          const SizedBox(height: 20),

          // ── Save button ──────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 48,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: teal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text(
                _isEdit ? 'Cập nhật' : 'Thêm khách hàng',
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _ReferrerField extends StatefulWidget {
  final bool isDark;
  final ColorScheme cs;
  final Color bg, border, teal, txtSec;
  final String myPhone;

  const _ReferrerField({
    required this.isDark, required this.cs,
    required this.bg, required this.border,
    required this.teal, required this.txtSec,
    required this.myPhone,
  });

  @override
  State<_ReferrerField> createState() => _ReferrerFieldState();
}

class _ReferrerFieldState extends State<_ReferrerField> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  bool _searched = false;
  String? _foundName;
  bool _notFound = false;
  String? _resolvedPhone; // phone đã normalize để gửi lên

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    if (_foundName != null || _notFound) {
      setState(() {
        _foundName = null; _notFound = false;
        _searched = false; _resolvedPhone = null;
      });
    }
    _debounce?.cancel();
    final trimmed = v.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.length < 9) {
      if (_searched) setState(() { _searched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600),
            () => _search(trimmed));
  }

  String _normalizePhone(String raw) {
    String s = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (s.startsWith('+84')) s = '0${s.substring(3)}';
    else if (s.startsWith('84') && s.length == 11) s = '0${s.substring(2)}';
    else if (!s.startsWith('0') && s.length == 9)  s = '0$s';
    return s;
  }

  Future<void> _search(String raw) async {
    if (!mounted) return;
    final normalized = _normalizePhone(raw);
    final myNorm     = _normalizePhone(widget.myPhone);
    if (normalized == myNorm) {
      setState(() {
        _isSearching = false; _searched = true;
        _notFound = true; _foundName = null;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await DioClient.instance.get<List<dynamic>>(
        '${ApiConstants.posBase}/customers/search',
        queryParams: {'phone': normalized},
        fromData: (d) => d as List,
      );
      if (!mounted) return;
      final list = ((res.isSuccess ? res.data ?? [] : []) as List)
          .cast<Map<String, dynamic>>();
      final exact = list.where((e) =>
      (e['phone'] as String? ?? '') == normalized).toList();
      if (exact.isNotEmpty) {
        setState(() {
          _isSearching = false; _searched = true;
          _foundName = exact.first['name'] as String?;
          _notFound  = false;
          _resolvedPhone = normalized;
        });
      } else {
        setState(() {
          _isSearching = false; _searched = true;
          _foundName = null; _notFound = true; _resolvedPhone = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _isSearching = false; _searched = true; _notFound = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: _ctrl,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(
            RegExp(r'[\d\s+\-]'))],
        onChanged: _onChanged,
        style: TextStyle(fontSize: 14,
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: 'SĐT người giới thiệu (tùy chọn)',
          hintText: '0938 xxx xxx',
          prefixIcon: Icon(Icons.people_alt_rounded, size: 18,
              color: widget.teal.withOpacity(0.7)),
          suffixIcon: _isSearching
              ? Padding(padding: const EdgeInsets.all(12),
              child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: widget.teal)))
              : _foundName != null
              ? const Icon(Icons.check_circle_rounded,
              color: Color(0xFF0D9488), size: 20)
              : null,
          filled: true, fillColor: widget.bg,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _foundName != null
                    ? widget.teal.withOpacity(0.5) : widget.border,
                width: _foundName != null ? 1.5 : 1,
              )),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.teal, width: 1.5)),
          labelStyle: TextStyle(fontSize: 13, color: widget.txtSec),
          hintStyle: TextStyle(fontSize: 13,
              color: widget.txtSec.withOpacity(0.6)),
        ),
      ),
      if (_searched && !_isSearching) ...[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(children: [
            Icon(
              _foundName != null
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              size: 13,
              color: _foundName != null
                  ? widget.teal
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 5),
            Flexible(child: Text(
              _foundName != null
                  ? 'Người giới thiệu: $_foundName'
                  : _ctrl.text.isNotEmpty
                  ? 'Không tìm thấy số này'
                  : 'Không thể tự giới thiệu chính mình',
              style: TextStyle(
                fontSize: 11,
                color: _foundName != null
                    ? widget.teal
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            )),
          ]),
        ),
      ],
    ]);
  }
}


// ─── Program Form Sheet ───────────────────────────────────────────

class _ProgramFormSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _ProgramFormSheet({required this.onSaved});

  @override
  State<_ProgramFormSheet> createState() => _ProgramFormSheetState();
}

class _ProgramFormSheetState extends State<_ProgramFormSheet> {
  final _nameCtrl     = TextEditingController();
  final _minSpendCtrl = TextEditingController();
  final _maxDiscCtrl  = TextEditingController();
  DateTime? _qualifyFrom, _qualifyTo, _applyFrom, _applyTo;
  bool _isSaving = false;

  List<DiscountOptionMgmt> _options = [
    DiscountOptionMgmt(discountType: 'PERCENT_BILL',  discountValue: 10),
    DiscountOptionMgmt(discountType: 'FIXED_BILL',    discountValue: 20000),
    DiscountOptionMgmt(discountType: 'PERCENT_ITEM',  discountValue: 10),
    DiscountOptionMgmt(discountType: 'FIXED_ITEM',    discountValue: 15000),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minSpendCtrl.dispose();
    _maxDiscCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context,
      DateTime? initial, ValueChanged<DateTime> onPick) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d != null) onPick(d);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _minSpendCtrl.text.isEmpty ||
        _maxDiscCtrl.text.isEmpty || _qualifyFrom == null ||
        _qualifyTo == null || _applyFrom == null || _applyTo == null) {
      _snack('Vui lòng điền đầy đủ thông tin');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await DioClient.instance.post(
        '${ApiConstants.posBase}/discounts/programs',
        body: {
          'name':                   _nameCtrl.text.trim(),
          'qualifyFrom':            _qualifyFrom!.millisecondsSinceEpoch,
          'qualifyTo':              _qualifyTo!.millisecondsSinceEpoch,
          'applyFrom':              _applyFrom!.millisecondsSinceEpoch,
          'applyTo':                _applyTo!.millisecondsSinceEpoch,
          'minSpend':               double.parse(_minSpendCtrl.text.replaceAll(',', '')),
          'maxDiscountPerCustomer': double.parse(_maxDiscCtrl.text.replaceAll(',', '')),
          'options': _options.map((o) => o.toJson()).toList(),
        },
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    final teal   = const Color(0xFF0D9488);
    final surf   = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bg     = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: DraggableScrollableSheet(
        initialChildSize: 1,
        expand: false,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2)),
            )),
            Text('Tạo chương trình khuyến mãi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 20),

            // Tên
            _buildField(
              controller: _nameCtrl,
              label: 'Tên chương trình *',
              hint: 'VD: Khách VIP Q1/2026',
              icon: Icons.campaign_rounded,
              isDark: isDark, cs: cs, bg: bg, border: border, teal: teal,
            ),
            const SizedBox(height: 12),

            // Điều kiện chi tiêu
            _sectionLabel('Điều kiện tham gia', cs),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _buildField(
                controller: _minSpendCtrl,
                label: 'Chi tiêu tối thiểu (đ) *',
                hint: '1000000',
                icon: Icons.paid_rounded,
                keyboard: TextInputType.number,
                isDark: isDark, cs: cs, bg: bg, border: border, teal: teal,
              )),
            ]),
            const SizedBox(height: 8),
            // Kỳ tính chi tiêu
            Row(children: [
              Expanded(child: _DatePickerField(
                label: 'Từ ngày (kỳ tính)',
                value: _qualifyFrom != null ? dateFmt.format(_qualifyFrom!) : null,
                onTap: () => _pickDate(context, _qualifyFrom,
                        (d) => setState(() => _qualifyFrom = d)),
                isDark: isDark, cs: cs, bg: bg, border: border,
              )),
              const SizedBox(width: 10),
              Expanded(child: _DatePickerField(
                label: 'Đến ngày (kỳ tính)',
                value: _qualifyTo != null ? dateFmt.format(_qualifyTo!) : null,
                onTap: () => _pickDate(context, _qualifyTo,
                        (d) => setState(() => _qualifyTo = d)),
                isDark: isDark, cs: cs, bg: bg, border: border,
              )),
            ]),
            const SizedBox(height: 12),

            // Kỳ áp dụng
            _sectionLabel('Thời gian áp dụng', cs),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _DatePickerField(
                label: 'Bắt đầu áp dụng',
                value: _applyFrom != null ? dateFmt.format(_applyFrom!) : null,
                onTap: () => _pickDate(context, _applyFrom,
                        (d) => setState(() => _applyFrom = d)),
                isDark: isDark, cs: cs, bg: bg, border: border,
              )),
              const SizedBox(width: 10),
              Expanded(child: _DatePickerField(
                label: 'Kết thúc áp dụng',
                value: _applyTo != null ? dateFmt.format(_applyTo!) : null,
                onTap: () => _pickDate(context, _applyTo,
                        (d) => setState(() => _applyTo = d)),
                isDark: isDark, cs: cs, bg: bg, border: border,
              )),
            ]),
            const SizedBox(height: 12),

            // Hạn mức
            _buildField(
              controller: _maxDiscCtrl,
              label: 'Hạn mức giảm/khách (đ) *',
              hint: '200000',
              icon: Icons.account_balance_wallet_rounded,
              keyboard: TextInputType.number,
              isDark: isDark, cs: cs, bg: bg, border: border, teal: teal,
            ),
            const SizedBox(height: 16),

            // Options
            _sectionLabel('Lựa chọn giảm giá', cs),
            const SizedBox(height: 8),
            ..._options.asMap().entries.map((e) =>
                _OptionEditor(
                  option: e.value,
                  index: e.key,
                  isDark: isDark,
                  cs: cs,
                  bg: bg,
                  border: border,
                  teal: teal,
                  onChanged: () => setState(() {}),
                )),
            const SizedBox(height: 20),

            SizedBox(width: double.infinity, height: 48,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: _isSaving
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text('Tạo chương trình',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, ColorScheme cs) => Row(children: [
    Container(width: 3, height: 14,
        decoration: BoxDecoration(
            color: const Color(0xFF0D9488),
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 7),
    Text(text, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: cs.onSurface.withOpacity(0.6), letterSpacing: 0.3)),
  ]);
}

class _OptionEditor extends StatelessWidget {
  final DiscountOptionMgmt option;
  final int index;
  final bool isDark;
  final ColorScheme cs;
  final Color bg, border, teal;
  final VoidCallback onChanged;

  const _OptionEditor({
    required this.option,
    required this.index,
    required this.isDark,
    required this.cs,
    required this.bg,
    required this.border,
    required this.teal,
    required this.onChanged,
  });

  String get _typeLabel => switch (option.discountType) {
    'PERCENT_BILL' => 'Giảm % tổng bill',
    'FIXED_BILL'   => 'Giảm tiền tổng bill',
    'PERCENT_ITEM' => 'Giảm % trên 1 món',
    'FIXED_ITEM'   => 'Giảm tiền trên 1 món',
    _ => option.discountType,
  };

  bool get _isPercent =>
      option.discountType.startsWith('PERCENT');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D9488).withOpacity(0.07)
            : const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: teal.withOpacity(0.2), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 22, height: 22,
            decoration: BoxDecoration(
                color: teal, shape: BoxShape.circle),
            child: Center(child: Text('${index + 1}',
                style: const TextStyle(color: Colors.white,
                    fontSize: 11, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 8),
          Text(_typeLabel, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: cs.onSurface)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _SmallField(
            initialValue: option.discountValue.toString(),
            label: _isPercent ? 'Giá trị (%)' : 'Giá trị (đ)',
            keyboard: TextInputType.number,
            onChanged: (v) {
              option.discountValue = double.tryParse(v) ?? option.discountValue;
            },
            isDark: isDark, cs: cs, bg: bg, border: border,
          )),
          const SizedBox(width: 10),
          Expanded(child: _SmallField(
            initialValue: option.maxPerUse?.toString() ?? '',
            label: 'Tối đa/lần (đ)',
            hint: 'Không giới hạn',
            keyboard: TextInputType.number,
            onChanged: (v) {
              option.maxPerUse = v.isEmpty ? null : double.tryParse(v);
            },
            isDark: isDark, cs: cs, bg: bg, border: border,
          )),
        ]),
        const SizedBox(height: 8),
        _SmallField(
          initialValue: option.label ?? '',
          label: 'Nhãn hiển thị (tuỳ chọn)',
          hint: 'VD: Giảm 10% bill (tối đa 30k)',
          onChanged: (v) { option.label = v; },
          isDark: isDark, cs: cs, bg: bg, border: border,
        ),
      ]),
    );
  }
}

// ─── Shared helper widgets ────────────────────────────────────────

Widget _buildField({
  required TextEditingController controller,
  required String label,
  String? hint,
  required IconData icon,
  bool readOnly = false,
  TextInputType keyboard = TextInputType.text,
  List<TextInputFormatter>? formatters,
  required bool isDark,
  required ColorScheme cs,
  required Color bg,
  required Color border,
  required Color teal,
}) {
  return TextFormField(
    controller: controller,
    readOnly: readOnly,
    keyboardType: keyboard,
    inputFormatters: formatters,
    style: TextStyle(fontSize: 14,
        color: isDark ? Colors.white : const Color(0xFF0F172A)),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18,
          color: readOnly
              ? cs.onSurface.withOpacity(0.3)
              : teal.withOpacity(0.7)),
      filled: true,
      fillColor: readOnly
          ? cs.onSurface.withOpacity(0.04)
          : bg,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: teal, width: 1.5)),
      labelStyle: TextStyle(fontSize: 13,
          color: cs.onSurface.withOpacity(0.5)),
      hintStyle: TextStyle(fontSize: 13,
          color: cs.onSurface.withOpacity(0.35)),
    ),
  );
}

class _SmallField extends StatelessWidget {
  final String initialValue;
  final String label;
  final String? hint;
  final TextInputType keyboard;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final ColorScheme cs;
  final Color bg, border;

  const _SmallField({
    required this.initialValue,
    required this.label,
    this.hint,
    this.keyboard = TextInputType.text,
    required this.onChanged,
    required this.isDark,
    required this.cs,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: keyboard,
      onChanged: onChanged,
      style: TextStyle(fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        filled: true, fillColor: bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFF0D9488), width: 1.5)),
        labelStyle: TextStyle(fontSize: 11,
            color: cs.onSurface.withOpacity(0.5)),
        hintStyle: TextStyle(fontSize: 11,
            color: cs.onSurface.withOpacity(0.3)),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme cs;
  final Color bg, border;

  const _DatePickerField({
    required this.label,
    this.value,
    required this.onTap,
    required this.isDark,
    required this.cs,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded, size: 14,
              color: value != null
                  ? const Color(0xFF0D9488)
                  : cs.onSurface.withOpacity(0.35)),
          const SizedBox(width: 8),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10,
                    color: cs.onSurface.withOpacity(0.45))),
                Text(
                  value ?? 'Chọn ngày',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: value != null
                          ? FontWeight.w600 : FontWeight.w400,
                      color: value != null
                          ? cs.onSurface
                          : cs.onSurface.withOpacity(0.35)),
                ),
              ])),
        ]),
      ),
    );
  }
}

Widget _emptyState(String text, IconData icon) =>
    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(fontSize: 15,
              color: Colors.grey.withOpacity(0.5))),
        ]));