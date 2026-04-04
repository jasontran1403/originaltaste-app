// lib/features/management/screens/inventory_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/inventory_batch_models.dart';
import '../../../data/models/management/management_models.dart';
import '../../../services/inventory_batch_service.dart';
import '../../../services/seller_service.dart';

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _BatchRow {
  final IngredientModel ingredient;
  double    quantity;
  DateTime? expiryDate;
  _BatchRow({required this.ingredient, required this.quantity, this.expiryDate});
}

String _fmtQty(double q) =>
    q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

double get _safeBottomPad => MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.views.first).padding.bottom;

// ═══════════════════════════════════════════════════════════════
// InventoryScreen
// ═══════════════════════════════════════════════════════════════

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _tab = 0;

  static const _tabs      = ['Phiếu', 'Nhập', 'Xuất', 'Điều chỉnh'];
  static const _tabColors = [
    Color(0xFF6366F1), Color(0xFF0EA5E9),
    Color(0xFFF97316), Color(0xFFEAB308),
  ];
  static const _tabIcons = [
    Icons.receipt_long_rounded, Icons.download_rounded,
    Icons.upload_rounded,       Icons.tune_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final top       = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F6FA),
      body: Column(children: [
        // AppBar
        Container(
          color: cardBg,
          padding: EdgeInsets.fromLTRB(4, top + 8, 16, 12),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: onBg),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _tabColors[_tab].withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_tabIcons[_tab], color: _tabColors[_tab], size: 18),
            ),
            const SizedBox(width: 10),
            Text(_tabs[_tab],
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg)),
          ]),
        ),
        Container(height: 1, color: border),

        // Toggle tabs
        Container(
          color: cardBg,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final sel = _tab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? _tabColors[i].withOpacity(0.12)
                          : (isDark ? AppColors.darkCard : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? _tabColors[i] : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(_tabs[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? _tabColors[i] : secondary,
                          )),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Container(height: 1, color: border),

        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              _BatchListTab(),
              _ImportTab(),
              _ExportTab(),
              _AdjustTab(),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 0 — Danh sách phiếu
// ═══════════════════════════════════════════════════════════════

class _BatchListTab extends StatefulWidget {
  const _BatchListTab();
  @override State<_BatchListTab> createState() => _BatchListTabState();
}

class _BatchListTabState extends State<_BatchListTab> {
  List<InventoryBatchSummary> _items = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await InventoryBatchService.instance.getBatches();
    if (!mounted) return;
    if (r.isSuccess && r.data != null) setState(() { _items = r.data!; _loading = false; });
    else setState(() { _error = r.message ?? 'Lỗi tải dữ liệu'; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(msg: _error!, onRetry: _load);

    final sub = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
          ? CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.receipt_long_outlined, size: 52, color: sub.withOpacity(0.3)),
              const SizedBox(height: 10),
              Text('Chưa có phiếu nào', style: TextStyle(color: sub, fontSize: 14)),
            ])),
          ),
        ],
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) => _BatchCard(batch: _items[i], onTap: () => _showDetail(_items[i].id)),
      ),
    );
  }

  void _showDetail(int id) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _BatchDetailSheet(batchId: id),
  );
}

// ── Batch Card ──

class _BatchCard extends StatelessWidget {
  final InventoryBatchSummary batch;
  final VoidCallback onTap;
  const _BatchCard({required this.batch, required this.onTap});

  static const _colors = {'IMPORT': Color(0xFF0EA5E9), 'EXPORT': Color(0xFFF97316), 'ADJUST': Color(0xFFEAB308)};
  static const _labels = {'IMPORT': 'Nhập', 'EXPORT': 'Xuất', 'ADJUST': 'Điều chỉnh'};
  static const _icons  = {'IMPORT': Icons.download_rounded, 'EXPORT': Icons.upload_rounded, 'ADJUST': Icons.tune_rounded};

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard : Colors.white;
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final color     = _colors[batch.action] ?? const Color(0xFF6366F1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(_icons[batch.action] ?? Icons.receipt_long_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(_labels[batch.action] ?? batch.action,
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(batch.batchCode,
                  style: TextStyle(fontSize: 12, color: onBg, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(batch.createdAt)),
                style: TextStyle(fontSize: 11, color: secondary)),
            if (batch.supplierRef?.isNotEmpty == true)
              Text('Ref: ${batch.supplierRef}',
                  style: TextStyle(fontSize: 11, color: secondary), overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${batch.totalItems} mục',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(batch.createdByName, style: TextStyle(fontSize: 11, color: secondary)),
          ]),
        ]),
      ),
    );
  }
}

// ── Batch Detail Sheet ──

class _BatchDetailSheet extends StatefulWidget {
  final int batchId;
  const _BatchDetailSheet({required this.batchId});
  @override State<_BatchDetailSheet> createState() => _BatchDetailSheetState();
}

class _BatchDetailSheetState extends State<_BatchDetailSheet> {
  InventoryBatchDetail? _detail;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await InventoryBatchService.instance.getBatchDetail(widget.batchId);
    if (!mounted) return;
    setState(() { _detail = r.data; _loading = false; });
  }

  static const _actionColors = {'IMPORT': Color(0xFF0EA5E9), 'EXPORT': Color(0xFFF97316), 'ADJUST': Color(0xFFEAB308)};
  static const _actionLabels = {'IMPORT': 'Nhập kho', 'EXPORT': 'Xuất kho', 'ADJUST': 'Kiểm kho'};

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: _loading
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : _detail == null
          ? const Center(child: Text('Không tìm thấy phiếu'))
          : _buildContent(border, onBg, secondary),
    );
  }

  Widget _buildContent(Color border, Color onBg, Color secondary) {
    final d     = _detail!;
    final color = _actionColors[d.action] ?? const Color(0xFF6366F1);

    return Column(children: [
      Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
          decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(_actionLabels[d.action] ?? d.action,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(d.createdAt)),
                style: TextStyle(fontSize: 12, color: secondary)),
          ]),
          const SizedBox(height: 6),
          Text(d.batchCode,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: onBg)),
          if (d.supplierRef?.isNotEmpty == true)
            Text('Ref: ${d.supplierRef}', style: TextStyle(fontSize: 12, color: secondary)),
          Text('Bởi: ${d.createdByName}', style: TextStyle(fontSize: 12, color: secondary)),
          if (d.receiptImageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(d.receiptImageUrl!,
                  height: 140, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Divider(height: 0, color: border),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Expanded(flex: 3, child: _th('Nguyên liệu', secondary)),
          Expanded(flex: 2, child: _th(d.action == 'ADJUST' ? 'Tồn thực' : 'Số lượng', secondary, center: true)),
          Expanded(flex: 2, child: _th('Tồn cũ', secondary, center: true)),
          Expanded(flex: 2, child: _th('Tồn mới', secondary, center: true)),
          if (d.action == 'ADJUST') const SizedBox(width: 64),
        ]),
      ),
      Divider(height: 0, color: border),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: d.lines.length,
          separatorBuilder: (_, __) => Divider(height: 0, color: border),
          itemBuilder: (_, i) => _LogLineRow(line: d.lines[i], action: d.action),
        ),
      ),
    ]);
  }

  Widget _th(String t, Color c, {bool center = false}) =>
      Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
          textAlign: center ? TextAlign.center : TextAlign.left);
}

class _LogLineRow extends StatelessWidget {
  final BatchLogLine line;
  final String action;
  const _LogLineRow({required this.line, required this.action});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    final Color  qtyColor;
    final String qtyStr;
    if (action == 'ADJUST') {
      qtyStr   = _fmtQty(line.quantityAfter);
      qtyColor = onBg;
    } else {
      qtyStr   = line.quantity >= 0 ? '+${_fmtQty(line.quantity)}' : _fmtQty(line.quantity);
      qtyColor = line.quantity >= 0 ? const Color(0xFF10B981) : const Color(0xFFF97316);
    }

    Widget? badge;
    if (action == 'ADJUST') {
      final s = line.adjustStatus ?? 'MATCH';
      final (bc, bl) = switch (s) {
        'SURPLUS'  => (const Color(0xFF10B981), 'Dư ${_fmtQty(line.quantity)}'),
        'SHORTAGE' => (const Color(0xFFF97316), 'Thiếu ${_fmtQty(line.quantity.abs())}'),
        _          => (const Color(0xFF6B7280), 'Khớp'),
      };
      badge = Container(
        width: 64,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: bc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(bl, style: TextStyle(fontSize: 9, color: bc, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(line.ingredientName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onBg),
              overflow: TextOverflow.ellipsis),
          Text(line.unit, style: TextStyle(fontSize: 11, color: secondary)),
        ])),
        Expanded(flex: 2, child: Text(qtyStr,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: qtyColor),
            textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text(_fmtQty(line.quantityBefore),
            style: TextStyle(fontSize: 12, color: secondary), textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text(_fmtQty(line.quantityAfter),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onBg),
            textAlign: TextAlign.center)),
        if (badge != null) badge,
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 1 — Nhập kho (layout giống ManualImportScreen)
// ═══════════════════════════════════════════════════════════════

class _ImportTab extends StatefulWidget {
  const _ImportTab();
  @override State<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<_ImportTab> {
  static const _accent = Color(0xFF0EA5E9);

  List<IngredientModel> _all      = [];
  List<IngredientModel> _filtered = [];
  final List<_BatchRow> _batch    = [];
  bool    _loading    = true;
  bool    _submitting = false;
  String? _error;

  final _searchCtrl      = TextEditingController();
  final _supplierRefCtrl = TextEditingController();
  File?   _receiptImage;
  Timer?  _debounce;

  IngredientModel? _selected;
  final _qtyCtrl  = TextEditingController();
  final _qtyFocus = FocusNode();
  DateTime? _popupExpiry;
  String?   _popupError;

  @override
  void initState() { super.initState(); _fetch(); _searchCtrl.addListener(_onSearch); }

  @override
  void dispose() {
    _searchCtrl.dispose(); _supplierRefCtrl.dispose();
    _qtyCtrl.dispose(); _qtyFocus.dispose(); _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    final r = await SellerService.instance.getIngredients(page: 0, size: 200);
    if (!mounted) return;
    if (r.isSuccess && r.data != null) {
      setState(() { _all = r.data!; _filtered = List.from(_all); _loading = false; });
    } else {
      setState(() { _error = r.message ?? 'Lỗi'; _loading = false; });
    }
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        _filtered = q.isEmpty ? List.from(_all)
            : _all.where((i) => i.name.toLowerCase().contains(q)).toList();
      });
    });
  }

  void _openPopup(IngredientModel ing) {
    setState(() { _selected = ing; _qtyCtrl.text = ''; _popupExpiry = null; _popupError = null; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _qtyFocus.requestFocus());
  }

  void _closePopup() => setState(() {
    _selected = null; _qtyCtrl.text = ''; _popupExpiry = null; _popupError = null;
  });

  Future<void> _pickExpiryDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _popupExpiry ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 10),
      helpText: 'Chọn hạn dùng',
    );
    if (picked != null) setState(() => _popupExpiry = picked);
  }

  void _confirmAdd() {
    final qty = double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0) { setState(() => _popupError = 'Số lượng phải lớn hơn 0'); return; }
    final ing      = _selected!;
    final existIdx = _batch.indexWhere((r) => r.ingredient.id == ing.id);
    if (existIdx >= 0) {
      setState(() { _batch[existIdx].quantity += qty; _batch[existIdx].expiryDate = _popupExpiry; });
    } else {
      setState(() => _batch.add(_BatchRow(ingredient: ing, quantity: qty, expiryDate: _popupExpiry)));
    }
    _closePopup();
  }

  String _displayExpiry(_BatchRow row) {
    final ne = row.expiryDate;
    final oe = row.ingredient.expiryDate != null
        ? DateTime.fromMillisecondsSinceEpoch(row.ingredient.expiryDate!) : null;
    if (ne == null && oe == null) return '--';
    final now = DateTime.now();
    if (ne != null && ne.isAfter(now)) {
      if (oe == null || ne.isBefore(oe)) return DateFormat('dd/MM/yyyy').format(ne);
      return DateFormat('dd/MM/yyyy').format(oe);
    }
    if (oe != null && oe.isAfter(now)) return DateFormat('dd/MM/yyyy').format(oe);
    final fb = ne ?? oe;
    return fb != null ? DateFormat('dd/MM/yyyy').format(fb) : '--';
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(msg: _error!, onRetry: _fetch);

    return Stack(children: [
      LayoutBuilder(builder: (_, c) => c.maxWidth > 700
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 420, child: _batchPanel(cardBg, border, onBg, secondary)),
        Container(width: 1, color: border),
        Expanded(child: _ingredientPanel(cardBg, border, onBg, secondary)),
      ])
          : Column(children: [
        if (_batch.isNotEmpty) ...[
          _batchPanel(cardBg, border, onBg, secondary),
          Container(height: 1, color: border),
        ],
        Expanded(child: _ingredientPanel(cardBg, border, onBg, secondary)),
      ]),
      ),
      if (_selected != null)
        _popupOverlay(cardBg, border, onBg, secondary),
      if (_submitting)
        Container(color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator(color: Colors.white))),
    ]);
  }

  // ── Batch panel ──

  Widget _batchPanel(Color cardBg, Color border, Color onBg, Color secondary) {
    return Container(
      color: cardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_batch.isNotEmpty) ...[
          Container(
            color: const Color(0xFFF8F9FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(flex: 3, child: _thCell('Nguyên liệu', secondary)),
              Expanded(flex: 2, child: _thCell('Số lượng', secondary, center: true)),
              Expanded(flex: 2, child: _thCell('Hạn dùng', secondary, center: true)),
              const SizedBox(width: 32),
            ]),
          ),
          Divider(height: 0, color: border),
        ],
        Expanded(
          child: _batch.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined, size: 48, color: secondary.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text('Chưa có nguyên liệu nào', style: TextStyle(color: secondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Chọn từ danh sách bên dưới', style: TextStyle(color: secondary, fontSize: 12)),
          ]))
              : ListView.separated(
            itemCount: _batch.length,
            separatorBuilder: (_, __) => Divider(height: 0, color: border),
            itemBuilder: (_, i) => _batchRow(i, cardBg, secondary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardBg, border: Border(top: BorderSide(color: border)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -3))],
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 90 + _safeBottomPad),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _batch.isEmpty ? null : () => setState(() => _batch.clear()),
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Xóa tất cả'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 2,
              child: ElevatedButton.icon(
                onPressed: (_batch.isEmpty || _submitting) ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(_submitting ? 'Đang nhập...' : 'Nhập kho'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _thCell(String t, Color c, {bool center = false}) =>
      Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: c),
          textAlign: center ? TextAlign.center : TextAlign.left);

  Widget _batchRow(int i, Color cardBg, Color secondary) {
    final row = _batch[i];
    final expiryStr = _displayExpiry(row);
    final isNear = row.expiryDate != null &&
        row.expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
    return Container(
      color: cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row.ingredient.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis),
          Text(row.ingredient.unit, style: TextStyle(fontSize: 11, color: secondary)),
        ])),
        Expanded(flex: 2, child: Text('${_fmtQty(row.quantity)} ${row.ingredient.unit}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: _accent, fontSize: 13),
            textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isNear ? Colors.orange.withOpacity(0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(expiryStr,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: isNear ? Colors.orange.shade700 : Colors.grey.shade700),
              textAlign: TextAlign.center),
        )),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => setState(() => _batch.removeAt(i)),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
          ),
        ),
      ]),
    );
  }

  // ── Ingredient panel ──

  Widget _ingredientPanel(Color cardBg, Color border, Color onBg, Color secondary) {
    return Column(children: [
      Container(
        color: cardBg, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(fontSize: 14, color: onBg),
          decoration: InputDecoration(
            hintText: 'Tìm nguyên liệu...',
            hintStyle: TextStyle(color: secondary, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: secondary, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, size: 16, color: secondary), onPressed: _searchCtrl.clear)
                : null,
            filled: true, fillColor: secondary.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
      Divider(height: 0, color: border),
      Expanded(
        child: _filtered.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 40, color: secondary.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text('Không tìm thấy', style: TextStyle(color: secondary)),
        ]))
            : ListView.builder(
          itemCount: _filtered.length,
          itemBuilder: (_, i) => _ingredientTile(_filtered[i], cardBg, border, onBg, secondary),
        ),
      ),
    ]);
  }

  Widget _ingredientTile(IngredientModel ing, Color cardBg, Color border, Color onBg, Color secondary) {
    final row     = _batch.where((r) => r.ingredient.id == ing.id).firstOrNull;
    final inBatch = row != null;
    return InkWell(
      onTap: () => _openPopup(ing),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: inBatch ? _accent.withOpacity(0.04) : cardBg,
          border: Border(bottom: BorderSide(color: border.withOpacity(0.5))),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: inBatch ? _accent.withOpacity(0.12) : secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(inBatch ? Icons.check_circle_rounded : Icons.inventory_2_outlined,
                color: inBatch ? _accent : secondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ing.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                color: inBatch ? _accent : onBg)),
            Row(children: [
              Text('Tồn: ${_fmtQty(ing.stockQuantity)} ${ing.unit}',
                  style: TextStyle(fontSize: 11, color: secondary)),
              if (inBatch) ...[
                Text(' · ', style: TextStyle(color: secondary, fontSize: 11)),
                Text('Nhập: +${_fmtQty(row.quantity)} ${ing.unit}',
                    style: const TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
              ],
            ]),
          ])),
          Icon(Icons.add_circle_outline_rounded, color: inBatch ? _accent : secondary, size: 20),
        ]),
      ),
    );
  }

  // ── Popup overlay ──

  Widget _popupOverlay(Color cardBg, Color border, Color onBg, Color secondary) =>
      GestureDetector(
        onTap: _closePopup,
        child: Container(
          color: Colors.black.withOpacity(0.45),
          child: Center(child: GestureDetector(onTap: () {},
              child: _popupCard(cardBg, border, onBg, secondary))),
        ),
      );

  Widget _popupCard(Color cardBg, Color border, Color onBg, Color secondary) {
    final ing      = _selected!;
    final existRow = _batch.where((r) => r.ingredient.id == ing.id).firstOrNull;
    final hasExist = existRow != null;

    return Container(
      width: 380, margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 8))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          decoration: BoxDecoration(color: _accent.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.inventory_2_outlined, color: _accent, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ing.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: onBg)),
              Row(children: [
                Text('Tồn: ${_fmtQty(ing.stockQuantity)} ${ing.unit}', style: TextStyle(fontSize: 11, color: secondary)),
                if (hasExist) ...[
                  Text(' · ', style: TextStyle(color: secondary, fontSize: 11)),
                  Text('Đang nhập: ${_fmtQty(existRow.quantity)} ${ing.unit}',
                      style: const TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
                ],
              ]),
            ])),
            IconButton(onPressed: _closePopup, icon: Icon(Icons.close_rounded, size: 20, color: secondary), padding: EdgeInsets.zero),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (hasExist)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _accent.withOpacity(0.06), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accent.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.add_circle_outline, size: 14, color: _accent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'Số lượng sẽ cộng thêm vào ${_fmtQty(existRow.quantity)} ${ing.unit} hiện có',
                    style: const TextStyle(fontSize: 12, color: _accent),
                  )),
                ]),
              ),
            Text('Số lượng thêm *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: onBg)),
            const SizedBox(height: 6),
            TextField(
              controller: _qtyCtrl, focusNode: _qtyFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}'))],
              onChanged: (_) => setState(() => _popupError = null),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onBg),
              decoration: InputDecoration(
                hintText: '0.00', hintStyle: TextStyle(color: secondary),
                suffixText: ing.unit,
                suffixStyle: const TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _accent, width: 1.5)),
                errorText: _popupError,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Text('Hạn dùng', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: onBg)),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickExpiryDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: _popupExpiry != null ? _accent : border),
                  borderRadius: BorderRadius.circular(10),
                  color: _popupExpiry != null ? _accent.withOpacity(0.04) : Colors.transparent,
                ),
                child: Row(children: [
                  Icon(Icons.calendar_month_outlined, size: 18,
                      color: _popupExpiry != null ? _accent : secondary),
                  const SizedBox(width: 10),
                  Text(
                    _popupExpiry != null
                        ? DateFormat('dd/MM/yyyy').format(_popupExpiry!)
                        : 'Chọn ngày hết hạn',
                    style: TextStyle(fontSize: 14,
                        color: _popupExpiry != null ? onBg : secondary,
                        fontWeight: _popupExpiry != null ? FontWeight.w600 : FontWeight.normal),
                  ),
                  const Spacer(),
                  if (_popupExpiry != null)
                    GestureDetector(
                        onTap: () => setState(() => _popupExpiry = null),
                        child: Icon(Icons.clear, size: 16, color: secondary))
                  else
                    Icon(Icons.chevron_right, size: 18, color: secondary),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _closePopup,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Hủy', style: TextStyle(color: secondary)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: _confirmAdd,
                icon: Icon(hasExist ? Icons.add : Icons.add_circle_outline, size: 16),
                label: Text(hasExist ? 'Cộng thêm' : 'Thêm vào phiếu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Submit ──

  void _submit() {
    _supplierRefCtrl.clear();
    setState(() => _receiptImage = null);
    _showConfirmSheet();
  }

  void _showConfirmSheet() {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSS) => Container(
          decoration: BoxDecoration(color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40, height: 4, decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.check_circle_outline_rounded, color: _accent, size: 20)),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Xác nhận nhập kho', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg)),
                    Text('${_batch.length} nguyên liệu', style: TextStyle(fontSize: 12, color: secondary)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              Divider(height: 0, color: border),
              Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text('Danh sách nhập', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: secondary))),
              ..._batch.map((r) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: Row(children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.ingredient.name, style: TextStyle(fontSize: 13, color: onBg, fontWeight: FontWeight.w500))),
                  Text('+${_fmtQty(r.quantity)} ${r.ingredient.unit}',
                      style: const TextStyle(fontSize: 13, color: _accent, fontWeight: FontWeight.w600)),
                ]),
              )),
              const SizedBox(height: 16),
              Divider(height: 0, color: border),
              // Mã NCC
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  Text('Mã phiếu nhà cung cấp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onBg)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('Tùy chọn', style: TextStyle(fontSize: 10, color: secondary, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TextField(
                  controller: _supplierRefCtrl,
                  style: TextStyle(fontSize: 14, color: onBg),
                  decoration: InputDecoration(
                    hintText: 'VD: NCC-2026-00123', hintStyle: TextStyle(color: secondary, fontSize: 13),
                    prefixIcon: Icon(Icons.receipt_outlined, color: secondary, size: 18),
                    filled: true, fillColor: secondary.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              // Ảnh phiếu
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  Text('Ảnh phiếu giao hàng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onBg)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('Tùy chọn', style: TextStyle(fontSize: 10, color: secondary, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _receiptImage == null
                    ? _photoPlaceholder(border, secondary, () async {
                  final img = await _pickPhoto();
                  if (img != null) { setState(() => _receiptImage = img); setSS(() {}); }
                })
                    : _photoPreview(_receiptImage!, border, secondary,
                        () async {
                      final img = await _pickPhoto();
                      if (img != null) { setState(() => _receiptImage = img); setSS(() {}); }
                    },
                        () { setState(() => _receiptImage = null); setSS(() {}); }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Hủy', style: TextStyle(color: secondary)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    onPressed: _submitting ? null : () {
                      Navigator.pop(ctx);
                      _doSubmit(
                        supplierRef: _supplierRefCtrl.text.trim().isEmpty ? null : _supplierRefCtrl.text.trim(),
                        receiptImage: _receiptImage,
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Xác nhận nhập kho'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _photoPlaceholder(Color border, Color secondary, VoidCallback onTap) =>
      GestureDetector(onTap: onTap, child: Container(
        height: 100,
        decoration: BoxDecoration(border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(12), color: secondary.withOpacity(0.04)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.camera_alt_outlined, size: 28, color: secondary.withOpacity(0.5)),
          const SizedBox(height: 6),
          Text('Chụp ảnh phiếu giao hàng', style: TextStyle(fontSize: 13, color: secondary)),
          Text('Nhấn để mở camera', style: TextStyle(fontSize: 11, color: secondary.withOpacity(0.6))),
        ]),
      ));

  Widget _photoPreview(File image, Color border, Color secondary,
      VoidCallback onRetake, VoidCallback onRemove) =>
      Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12),
            child: Image.file(image, height: 160, width: double.infinity, fit: BoxFit.cover)),
        Positioned(top: 8, right: 8, child: Row(children: [
          GestureDetector(onTap: onRetake, child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
          )),
          const SizedBox(width: 6),
          GestureDetector(onTap: onRemove, child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
          )),
        ])),
      ]);

  Future<File?> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
      return picked == null ? null : File(picked.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Không thể mở camera: $e'),
        backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
      ));
      return null;
    }
  }

  Future<void> _doSubmit({String? supplierRef, File? receiptImage}) async {
    setState(() => _submitting = true);
    try {
      final result = await InventoryBatchService.instance.importBatch(
        items: _batch.map((r) => {
          'ingredientId': r.ingredient.id, 'quantity': r.quantity,
          if (r.expiryDate != null) 'expiryDate': r.expiryDate!.millisecondsSinceEpoch,
        }).toList(),
        supplierRef: supplierRef, receiptImage: receiptImage,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() => _batch.clear());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Nhập kho thành công!'), backgroundColor: _accent,
          behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message ?? 'Nhập kho thất bại'),
          backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally { if (mounted) setState(() => _submitting = false); }
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 2 — Xuất kho (layout giống Nhập, accent cam, không hạn dùng)
// ═══════════════════════════════════════════════════════════════

class _ExportTab extends StatefulWidget {
  const _ExportTab();
  @override State<_ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<_ExportTab> {
  static const _accent = Color(0xFFF97316);

  List<IngredientModel> _all      = [];
  List<IngredientModel> _filtered = [];
  final List<_BatchRow> _batch    = [];
  bool    _loading    = true;
  bool    _submitting = false;
  String? _error;

  final _searchCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  Timer?  _debounce;

  IngredientModel? _selected;
  final _qtyCtrl  = TextEditingController();
  final _qtyFocus = FocusNode();
  String? _popupError;

  @override
  void initState() { super.initState(); _fetch(); _searchCtrl.addListener(_onSearch); }

  @override
  void dispose() {
    _searchCtrl.dispose(); _reasonCtrl.dispose();
    _qtyCtrl.dispose(); _qtyFocus.dispose(); _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    final r = await SellerService.instance.getIngredients(page: 0, size: 200);
    if (!mounted) return;
    if (r.isSuccess && r.data != null) {
      setState(() { _all = r.data!; _filtered = List.from(_all); _loading = false; });
    } else {
      setState(() { _error = r.message ?? 'Lỗi'; _loading = false; });
    }
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        _filtered = q.isEmpty ? List.from(_all)
            : _all.where((i) => i.name.toLowerCase().contains(q)).toList();
      });
    });
  }

  void _openPopup(IngredientModel ing) {
    setState(() { _selected = ing; _qtyCtrl.text = ''; _popupError = null; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _qtyFocus.requestFocus());
  }

  void _closePopup() => setState(() { _selected = null; _qtyCtrl.text = ''; _popupError = null; });

  void _confirmAdd() {
    final qty = double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0) { setState(() => _popupError = 'Số lượng phải lớn hơn 0'); return; }
    if (qty > _selected!.stockQuantity) {
      setState(() => _popupError = 'Vượt tồn kho (còn ${_fmtQty(_selected!.stockQuantity)} ${_selected!.unit})');
      return;
    }
    final existIdx = _batch.indexWhere((r) => r.ingredient.id == _selected!.id);
    if (existIdx >= 0) setState(() => _batch[existIdx].quantity += qty);
    else setState(() => _batch.add(_BatchRow(ingredient: _selected!, quantity: qty)));
    _closePopup();
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(msg: _error!, onRetry: _fetch);

    return Stack(children: [
      LayoutBuilder(builder: (_, c) => c.maxWidth > 700
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 420, child: _batchPanel(cardBg, border, onBg, secondary)),
        Container(width: 1, color: border),
        Expanded(child: _ingredientPanel(cardBg, border, onBg, secondary)),
      ])
          : Column(children: [
        if (_batch.isNotEmpty) ...[
          _batchPanel(cardBg, border, onBg, secondary),
          Container(height: 1, color: border),
        ],
        Expanded(child: _ingredientPanel(cardBg, border, onBg, secondary)),
      ]),
      ),
      if (_selected != null) _popupOverlay(cardBg, border, onBg, secondary),
      if (_submitting)
        Container(color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator(color: Colors.white))),
    ]);
  }

  Widget _batchPanel(Color cardBg, Color border, Color onBg, Color secondary) {
    return Container(
      color: cardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_batch.isNotEmpty) ...[
          Container(
            color: const Color(0xFFF8F9FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(flex: 3, child: _thCell('Nguyên liệu', secondary)),
              Expanded(flex: 2, child: _thCell('Số lượng', secondary, center: true)),
              const SizedBox(width: 32),
            ]),
          ),
          Divider(height: 0, color: border),
        ],
        Expanded(
          child: _batch.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined, size: 48, color: secondary.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text('Chưa có nguyên liệu nào', style: TextStyle(color: secondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Chọn từ danh sách bên dưới', style: TextStyle(color: secondary, fontSize: 12)),
          ]))
              : ListView.separated(
            itemCount: _batch.length,
            separatorBuilder: (_, __) => Divider(height: 0, color: border),
            itemBuilder: (_, i) {
              final row = _batch[i];
              return Container(
                color: cardBg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(row.ingredient.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    Text(row.ingredient.unit, style: TextStyle(fontSize: 11, color: secondary)),
                  ])),
                  Expanded(flex: 2, child: Text('${_fmtQty(row.quantity)} ${row.ingredient.unit}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: _accent, fontSize: 13),
                      textAlign: TextAlign.center)),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _batch.removeAt(i)),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red)),
                  ),
                ]),
              );
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardBg, border: Border(top: BorderSide(color: border)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -3))],
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 90 + _safeBottomPad),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _batch.isEmpty ? null : () => setState(() => _batch.clear()),
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: const Text('Xóa tất cả'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton.icon(
              onPressed: (_batch.isEmpty || _submitting) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(_submitting ? 'Đang xuất...' : 'Xuất kho'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _thCell(String t, Color c, {bool center = false}) =>
      Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: c),
          textAlign: center ? TextAlign.center : TextAlign.left);

  Widget _ingredientPanel(Color cardBg, Color border, Color onBg, Color secondary) {
    return Column(children: [
      Container(
        color: cardBg, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: TextField(
          controller: _searchCtrl, style: TextStyle(fontSize: 14, color: onBg),
          decoration: InputDecoration(
            hintText: 'Tìm nguyên liệu...', hintStyle: TextStyle(color: secondary, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: secondary, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, size: 16, color: secondary), onPressed: _searchCtrl.clear)
                : null,
            filled: true, fillColor: secondary.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
      Divider(height: 0, color: border),
      Expanded(
        child: _filtered.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 40, color: secondary.withOpacity(0.3)),
          const SizedBox(height: 8), Text('Không tìm thấy', style: TextStyle(color: secondary)),
        ]))
            : ListView.builder(
          itemCount: _filtered.length,
          itemBuilder: (_, i) {
            final ing     = _filtered[i];
            final row     = _batch.where((r) => r.ingredient.id == ing.id).firstOrNull;
            final inBatch = row != null;
            return InkWell(
              onTap: () => _openPopup(ing),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: inBatch ? _accent.withOpacity(0.04) : cardBg,
                  border: Border(bottom: BorderSide(color: border.withOpacity(0.5))),
                ),
                child: Row(children: [
                  Container(width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: inBatch ? _accent.withOpacity(0.12) : secondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(inBatch ? Icons.check_circle_rounded : Icons.inventory_2_outlined,
                          color: inBatch ? _accent : secondary, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ing.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                        color: inBatch ? _accent : onBg)),
                    Row(children: [
                      Text('Tồn: ${_fmtQty(ing.stockQuantity)} ${ing.unit}',
                          style: TextStyle(fontSize: 11, color: secondary)),
                      if (inBatch) ...[
                        Text(' · ', style: TextStyle(color: secondary, fontSize: 11)),
                        Text('Xuất: ${_fmtQty(row.quantity)} ${ing.unit}',
                            style: const TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ])),
                  Icon(Icons.add_circle_outline_rounded, color: inBatch ? _accent : secondary, size: 20),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _popupOverlay(Color cardBg, Color border, Color onBg, Color secondary) =>
      GestureDetector(
        onTap: _closePopup,
        child: Container(
          color: Colors.black.withOpacity(0.45),
          child: Center(child: GestureDetector(onTap: () {},
              child: _popupCard(cardBg, border, onBg, secondary))),
        ),
      );

  Widget _popupCard(Color cardBg, Color border, Color onBg, Color secondary) {
    final ing      = _selected!;
    final existRow = _batch.where((r) => r.ingredient.id == ing.id).firstOrNull;
    final hasExist = existRow != null;

    return Container(
      width: 380, margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 8))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          decoration: BoxDecoration(color: _accent.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.inventory_2_outlined, color: _accent, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ing.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: onBg)),
              Row(children: [
                Text('Tồn: ${_fmtQty(ing.stockQuantity)} ${ing.unit}', style: TextStyle(fontSize: 11, color: secondary)),
                if (hasExist) ...[
                  Text(' · ', style: TextStyle(color: secondary, fontSize: 11)),
                  Text('Đang xuất: ${_fmtQty(existRow.quantity)} ${ing.unit}',
                      style: const TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
                ],
              ]),
            ])),
            IconButton(onPressed: _closePopup, icon: Icon(Icons.close_rounded, size: 20, color: secondary), padding: EdgeInsets.zero),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Số lượng xuất *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: onBg)),
            const SizedBox(height: 6),
            TextField(
              controller: _qtyCtrl, focusNode: _qtyFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}'))],
              onChanged: (_) => setState(() => _popupError = null),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onBg),
              decoration: InputDecoration(
                hintText: '0.00', hintStyle: TextStyle(color: secondary),
                suffixText: ing.unit,
                suffixStyle: const TextStyle(color: _accent, fontWeight: FontWeight.w700, fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _accent, width: 1.5)),
                errorText: _popupError,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text('Tồn hiện tại: ${_fmtQty(ing.stockQuantity)} ${ing.unit}',
                style: TextStyle(fontSize: 12, color: secondary)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _closePopup,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Hủy', style: TextStyle(color: secondary)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: _confirmAdd,
                icon: Icon(hasExist ? Icons.add : Icons.add_circle_outline, size: 16),
                label: Text(hasExist ? 'Cộng thêm' : 'Thêm vào phiếu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  void _submit() { _reasonCtrl.clear(); _showConfirmSheet(); }

  void _showConfirmSheet() {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.upload_rounded, color: _accent, size: 20)),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Xác nhận xuất kho', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg)),
                  Text('${_batch.length} nguyên liệu', style: TextStyle(fontSize: 12, color: secondary)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            Divider(height: 0, color: border),
            Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text('Danh sách xuất', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: secondary))),
            ..._batch.map((r) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(r.ingredient.name, style: TextStyle(fontSize: 13, color: onBg, fontWeight: FontWeight.w500))),
                Text('-${_fmtQty(r.quantity)} ${r.ingredient.unit}',
                    style: const TextStyle(fontSize: 13, color: _accent, fontWeight: FontWeight.w600)),
              ]),
            )),
            const SizedBox(height: 16),
            Divider(height: 0, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                Text('Lý do xuất kho', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onBg)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('Tùy chọn', style: TextStyle(fontSize: 10, color: secondary, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _reasonCtrl,
                style: TextStyle(fontSize: 14, color: onBg),
                decoration: InputDecoration(
                  hintText: 'VD: Cho đơn hàng khách A, Hỏng hóc...',
                  hintStyle: TextStyle(color: secondary, fontSize: 13),
                  prefixIcon: Icon(Icons.edit_note_rounded, color: secondary, size: 18),
                  filled: true, fillColor: secondary.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _accent, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Hủy', style: TextStyle(color: secondary)),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton.icon(
                  onPressed: _submitting ? null : () {
                    Navigator.pop(ctx);
                    _doSubmit();
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Xác nhận xuất kho'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _doSubmit() async {
    setState(() => _submitting = true);
    try {
      final result = await InventoryBatchService.instance.exportBatch(
        ExportRequest(
          reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
          items: _batch.map((r) => ExportItem(ingredientId: r.ingredient.id, quantity: r.quantity)).toList(),
        ),
      );
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() => _batch.clear());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Xuất kho thành công!'), backgroundColor: _accent,
          behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message ?? 'Xuất kho thất bại'),
          backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally { if (mounted) setState(() => _submitting = false); }
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 3 — Điều chỉnh (kiểm kho)
// ═══════════════════════════════════════════════════════════════

class _AdjustTab extends StatefulWidget {
  const _AdjustTab();
  @override State<_AdjustTab> createState() => _AdjustTabState();
}

class _AdjustTabState extends State<_AdjustTab> {
  static const _accent = Color(0xFFEAB308);

  List<IngredientModel> _all      = [];
  List<IngredientModel> _filtered = [];
  final Map<int, TextEditingController> _ctrlMap = {};
  bool    _loading    = true;
  bool    _submitting = false;
  String? _error;

  final _searchCtrl = TextEditingController();
  Timer?  _debounce;

  @override
  void initState() { super.initState(); _fetch(); _searchCtrl.addListener(_onSearch); }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final c in _ctrlMap.values) c.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    final r = await SellerService.instance.getIngredients(page: 0, size: 200);
    if (!mounted) return;
    if (r.isSuccess && r.data != null) {
      for (final ing in r.data!) _ctrlMap[ing.id] ??= TextEditingController();
      setState(() { _all = r.data!; _filtered = List.from(_all); _loading = false; });
    } else {
      setState(() { _error = r.message ?? 'Lỗi'; _loading = false; });
    }
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        _filtered = q.isEmpty ? List.from(_all)
            : _all.where((i) => i.name.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(msg: _error!, onRetry: _fetch);

    return Column(children: [
      Container(
        color: cardBg, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: TextField(
          controller: _searchCtrl, style: TextStyle(fontSize: 14, color: onBg),
          decoration: InputDecoration(
            hintText: 'Tìm nguyên liệu...', hintStyle: TextStyle(color: secondary, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: secondary, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, size: 16, color: secondary), onPressed: _searchCtrl.clear)
                : null,
            filled: true, fillColor: secondary.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _accent, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
      Divider(height: 0, color: border),
      Expanded(
        child: ListView.separated(
          padding: EdgeInsets.only(bottom: _safeBottomPad + 90),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => Divider(height: 0, color: border),
          itemBuilder: (_, i) {
            final ing    = _filtered[i];
            final ctrl   = _ctrlMap[ing.id]!;
            final actual = double.tryParse(ctrl.text.replaceAll(',', '.'));
            final diff   = actual != null ? actual - ing.stockQuantity : null;

            Color  diffColor = secondary;
            String diffStr   = '';
            if (diff != null) {
              if (diff > 0.001)       { diffColor = const Color(0xFF10B981); diffStr = '+${_fmtQty(diff)} (Dư)'; }
              else if (diff < -0.001) { diffColor = const Color(0xFFF97316); diffStr = '${_fmtQty(diff)} (Thiếu)'; }
              else                    { diffColor = secondary; diffStr = 'Khớp ✓'; }
            }

            return Container(
              color: cardBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ing.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onBg)),
                  Text('Tồn hiện tại: ${_fmtQty(ing.stockQuantity)} ${ing.unit}',
                      style: TextStyle(fontSize: 11, color: secondary)),
                  if (diffStr.isNotEmpty)
                    Text(diffStr, style: TextStyle(fontSize: 11, color: diffColor, fontWeight: FontWeight.w600)),
                ])),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}'))],
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onBg),
                    decoration: InputDecoration(
                      hintText: '0.00', hintStyle: TextStyle(color: secondary, fontSize: 13),
                      suffixText: ing.unit,
                      suffixStyle: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w700),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _accent, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: cardBg, border: Border(top: BorderSide(color: border)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -3))],
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, _safeBottomPad + 90),
        child: ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline, size: 18),
          label: Text(_submitting ? 'Đang tạo phiếu...' : 'Tạo phiếu kiểm kho'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent, foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    ]);
  }

  Future<void> _submit() async {
    final items = <StockCheckItem>[];
    for (final ing in _all) {
      final ctrl = _ctrlMap[ing.id];
      if (ctrl == null || ctrl.text.trim().isEmpty) continue;
      final qty = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
      if (qty == null) continue;
      items.add(StockCheckItem(ingredientId: ing.id, actualQuantity: qty));
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng nhập số lượng thực tế ít nhất 1 nguyên liệu'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await InventoryBatchService.instance.checkBatch(StockCheckRequest(items: items));
      if (!mounted) return;
      if (result.isSuccess) {
        for (final c in _ctrlMap.values) c.clear();
        await _fetch();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Kiểm kho thành công!'), backgroundColor: _accent,
          behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message ?? 'Lỗi kiểm kho'),
          backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally { if (mounted) setState(() => _submitting = false); }
  }
}

// ─── Shared UI ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline, size: 48, color: AppColors.error),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(color: AppColors.error)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
    ]),
  );
}