// lib/features/pos/screens/pos_shift_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:originaltaste/data/models/pos/pos_shift_model.dart';
import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/shared/widgets/app_input_text.dart';

// Helper để push màn hình
Future<void> showPosShiftModal(
    BuildContext context, {
      PosShiftModel? currentShift,
      required void Function(PosShiftModel?) onShiftChanged,
    }) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (ctx) => PosShiftScreen(
        currentShift: currentShift,
        onShiftChanged: onShiftChanged,
      ),
      fullscreenDialog: true,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// POS SHIFT SCREEN
// ─────────────────────────────────────────────────────────────

class PosShiftScreen extends StatefulWidget {
  final PosShiftModel? currentShift;
  final void Function(PosShiftModel?) onShiftChanged;

  const PosShiftScreen({
    super.key,
    this.currentShift,
    required this.onShiftChanged,
  });

  @override
  State<PosShiftScreen> createState() => _PosShiftScreenState();
}

class _PosShiftScreenState extends State<PosShiftScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  bool _isLoading    = true;
  bool _isFirstShift = false;
  List<Map<String, dynamic>> _ingredients = [];

  static const List<int> kDenoms = [
    500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000,
  ];

  final _staffNameCtrl = TextEditingController();
  final _noteCtrl      = TextEditingController();

  // ── Denomination controllers (stable, không bị recreate) ────
  late final Map<int, TextEditingController> _openDenomCtrl;
  late final Map<int, TextEditingController> _closeDenomCtrl;

  // ── Inventory controllers ────────────────────────────────────
  final Map<int, TextEditingController> _openPackCtrl  = {};
  final Map<int, TextEditingController> _openUnitCtrl  = {};
  final Map<int, TextEditingController> _closePackCtrl = {};
  final Map<int, TextEditingController> _closeUnitCtrl = {};

  // Transfer amount
  final _transferCtrl = TextEditingController();

  bool get _isClosing => widget.currentShift?.isOpen == true;
  String get _tab1Label => _isClosing ? 'Kho kết ca' : 'Kho đầu ngày';

  @override
  void initState() {
    super.initState();
    _openDenomCtrl  = {for (final d in kDenoms) d: TextEditingController()};
    _closeDenomCtrl = {for (final d in kDenoms) d: TextEditingController()};
    _init();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _staffNameCtrl.dispose();
    _noteCtrl.dispose();
    _transferCtrl.dispose();
    for (final c in _openDenomCtrl.values)  c.dispose();
    for (final c in _closeDenomCtrl.values) c.dispose();
    for (final c in _openPackCtrl.values)   c.dispose();
    for (final c in _openUnitCtrl.values)   c.dispose();
    for (final c in _closePackCtrl.values)  c.dispose();
    for (final c in _closeUnitCtrl.values)  c.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final results = await Future.wait([
        PosService.instance.getIngredients(),
        PosService.instance.isFirstShiftOfDay(),
      ]);
      final ings    = results[0] as List<Map<String, dynamic>>;
      final isFirst = results[1] as bool;

      for (final ing in ings) {
        final id = ing['id'] as int;
        _openPackCtrl[id]  = TextEditingController();
        _openUnitCtrl[id]  = TextEditingController();
        _closePackCtrl[id] = TextEditingController();
        _closeUnitCtrl[id] = TextEditingController();
      }

      // Pre-fill existing open inventory
      if (!_isClosing && widget.currentShift != null) {
        for (final inv in widget.currentShift!.openInventory) {
          final id = inv['ingredientId'] as int?;
          if (id == null) continue;
          final pack = inv['packQuantity'] as int? ?? 0;
          final unit = inv['unitQuantity'] as int? ?? 0;
          if (pack > 0) _openPackCtrl[id]?.text = '$pack';
          if (unit > 0) _openUnitCtrl[id]?.text = '$unit';
        }
      }

      if (mounted) {
        setState(() {
          _ingredients  = ings;
          _isFirstShift = isFirst;
          _isLoading    = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _dismiss() => Navigator.of(context).pop();

  // ── Đọc giá trị từ controllers ───────────────────────────────

  int _ctrlInt(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  double _ctrlDouble(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  List<Map<String, dynamic>> _buildDenomList(
      Map<int, TextEditingController> ctrlMap) =>
      ctrlMap.entries
          .map((e) => {'denomination': e.key, 'quantity': _ctrlInt(e.value)})
          .where((m) => (m['quantity'] as int) > 0)
          .toList();

  List<Map<String, dynamic>> _buildInventoryList(
      Map<int, TextEditingController> packMap,
      Map<int, TextEditingController> unitMap) =>
      _ingredients.map((ing) {
        final id = ing['id'] as int;
        return {
          'ingredientId': id,
          'packQuantity': _ctrlInt(packMap[id] ?? TextEditingController()),
          'unitQuantity': _ctrlInt(unitMap[id] ?? TextEditingController()),
        };
      }).toList();

  bool _hasAnyOpenQty() =>
      _openPackCtrl.values.any((c) => _ctrlInt(c) > 0) ||
          _openUnitCtrl.values.any((c) => _ctrlInt(c) > 0);

  // ── Actions ──────────────────────────────────────────────────

  Future<void> _openShift() async {
    if (_staffNameCtrl.text.trim().isEmpty) {
      _snack('Vui lòng nhập tên nhân viên', isError: true);
      return;
    }
    if (_isFirstShift && _ingredients.isNotEmpty && !_hasAnyOpenQty()) {
      await _showFirstShiftWarning();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final body = <String, dynamic>{
        'staffName'         : _staffNameCtrl.text.trim(),
        'openDenominations' : _buildDenomList(_openDenomCtrl),
        if (_isFirstShift)
          'openInventory'   : _buildInventoryList(_openPackCtrl, _openUnitCtrl),
      };
      final shift = await PosService.instance.openShift(body);
      widget.onShiftChanged(shift);
      if (mounted) _dismiss();
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmCloseShift() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
          SizedBox(width: 8),
          Text('Xác nhận đóng ca'),
        ]),
        content: const Text(
            'Bạn có chắc muốn đóng ca?\nHành động này không thể hoàn tác.'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đóng ca'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _closeShift();
  }

  Future<void> _closeShift() async {
    setState(() => _isLoading = true);
    try {
      final transfer = _ctrlDouble(_transferCtrl);
      final body = <String, dynamic>{
        'closeDenominations': _buildDenomList(_closeDenomCtrl),
        'closeInventory'    : _buildInventoryList(_closePackCtrl, _closeUnitCtrl),
        if (transfer > 0) 'transferAmount': transfer,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      };
      await PosService.instance.closeShift(body);
      widget.onShiftChanged(null);
      if (mounted) _dismiss();
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('mệnh giá'))
        msg = 'Vui lòng nhập ít nhất một mệnh giá tiền cuối ca.';
      if (msg.contains('kho cuối ca'))
        msg = 'Vui lòng nhập số lượng nguyên liệu kiểm kho cuối ca.';
      _snack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError
          ? Theme.of(context).colorScheme.error
          : Colors.green,
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Future<void> _showFirstShiftWarning() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Column(children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle),
                child: Icon(Icons.inventory_2_outlined,
                    size: 32, color: Colors.orange.shade700),
              ),
              const SizedBox(height: 12),
              Text('Ca đầu ngày bắt buộc nhập kho',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(children: [
              Text(
                'Đây là ca đầu tiên trong ngày. Vui lòng nhập số lượng nguyên liệu tồn kho trước khi mở ca.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: Colors.grey[700], height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _tabCtrl.animateTo(1);
                  },
                  child: const Text('Đã hiểu, đi nhập kho ngay',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: _dismiss,
        ),
        title: Text(
          _isClosing ? 'Đóng ca' : 'Mở ca',
          style: TextStyle(fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87),
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _isClosing ? Colors.redAccent : Colors.green,
                ),
              ),
            )
          else if (_isClosing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Đóng ca',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onPressed: _confirmCloseShift,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Mở ca',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onPressed: _openShift,
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [Colors.grey.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
            // Pill-style TabBar
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.shade800.withOpacity(0.4)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: _isClosing
                        ? Colors.redAccent
                        : Colors.green,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark
                      ? Colors.grey.shade400
                      : Colors.grey.shade700,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: [
                    const Tab(text: 'Thông tin ca'),
                    Tab(text: _tab1Label),
                  ],
                ),
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // Tab 0: Thông tin ca
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: _isClosing
                        ? _CloseInfoTab(
                      shift:          widget.currentShift!,
                      closeDenomCtrl: _closeDenomCtrl,
                      transferCtrl:   _transferCtrl,
                      noteCtrl:       _noteCtrl,
                      fmtFn:          _fmt,
                    )
                        : _OpenInfoTab(
                      staffNameCtrl:  _staffNameCtrl,
                      openDenomCtrl:  _openDenomCtrl,
                      fmtFn:          _fmt,
                    ),
                  ),

                  // Tab 1: Kiểm kho
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: _InventorySection(
                      isClose:     _isClosing,
                      ingredients: _ingredients,
                      packCtrl:    _isClosing
                          ? _closePackCtrl : _openPackCtrl,
                      unitCtrl:    _isClosing
                          ? _closeUnitCtrl : _openUnitCtrl,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// _StableNumberField — TextField ổn định, không mất focus
// ══════════════════════════════════════════════════════════════

/// Dùng controller bên ngoài → không bị recreate khi parent setState.
class _StableNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDense;

  const _StableNumberField({
    required this.controller,
    this.hint    = '0',
    this.isDense = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: isDense ? 13 : 15,
          fontWeight: FontWeight.w600,
          color: cs.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.3),
            fontSize: isDense ? 13 : 15),
        isDense: isDense,
        contentPadding: EdgeInsets.symmetric(
            vertical: isDense ? 6 : 10, horizontal: 8),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Open Info Tab
// ══════════════════════════════════════════════════════════════

class _OpenInfoTab extends StatelessWidget {
  final TextEditingController staffNameCtrl;
  final Map<int, TextEditingController> openDenomCtrl;
  final String Function(double) fmtFn;

  const _OpenInfoTab({
    required this.staffNameCtrl,
    required this.openDenomCtrl,
    required this.fmtFn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SectionCard(
        title: 'Thông tin ca',
        icon:  Icons.person_outline,
        child: AppInputText(
          controller: staffNameCtrl,
          label:      'Tên nhân viên *',
          hint:       'Nhập tên...',
          prefixIcon: const Icon(Icons.badge_outlined),
          autofocus:  true,
        ),
      ),
      const SizedBox(height: 12),
      _DenomCard(
        title:    'Tiền đầu ca',
        denomCtrl: openDenomCtrl,
        fmtFn:    fmtFn,
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// Close Info Tab
// ══════════════════════════════════════════════════════════════

class _CloseInfoTab extends StatelessWidget {
  final PosShiftModel shift;
  final Map<int, TextEditingController> closeDenomCtrl;
  final TextEditingController transferCtrl;
  final TextEditingController noteCtrl;
  final String Function(double) fmtFn;

  const _CloseInfoTab({
    required this.shift,
    required this.closeDenomCtrl,
    required this.transferCtrl,
    required this.noteCtrl,
    required this.fmtFn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Shift summary banner
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.deepOrange.shade400,
            Colors.orange.shade300,
          ]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ca đang mở',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(shift.staffName, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 20)),
                Text(
                  'Mở lúc ${DateFormat('HH:mm dd/MM').format(DateTime.fromMillisecondsSinceEpoch(shift.openTime))}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Đơn hàng',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('${shift.totalOrders}', style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 24)),
                Text('${fmtFn(shift.totalRevenue)}đ',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ]),
            ]),
      ),
      const SizedBox(height: 12),
      _DenomCard(
        title:       'Tiền cuối ca',
        denomCtrl:   closeDenomCtrl,
        fmtFn:       fmtFn,
        extraChild:  Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _StableNumberField(
            controller: transferCtrl,
            hint:       'Tiền chuyển khoản (nếu có)',
          ),
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: 'Ghi chú chi phí phát sinh',
        icon:  Icons.notes_outlined,
        child: AppInputText(
          controller: noteCtrl,
          label:      'Ghi chú (nếu có)',
          hint:       'Nhập ghi chú chi phí...',
          maxLines:   3,
        ),
      ),
    ]);
  }
}

// ── Single denomination row: [label | input] ─────────────────

class _DenomRow extends StatelessWidget {
  final int denom;
  final TextEditingController ctrl;
  final String Function(double) fmtFn;
  const _DenomRow({required this.denom, required this.ctrl, required this.fmtFn});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Label mệnh giá bên trái
      Expanded(
        flex: 3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color:        Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          alignment: Alignment.center,
          child: Text('${fmtFn(denom.toDouble())}đ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                  color: Colors.orange.shade700),
              textAlign: TextAlign.center),
        ),
      ),
      const SizedBox(width: 8),
      // Input số lượng bên phải
      Expanded(
        flex: 2,
        child: _StableNumberField(controller: ctrl),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// Denomination Card — 2-column grid layout, stable controllers
// ══════════════════════════════════════════════════════════════

class _DenomCard extends StatelessWidget {
  final String title;
  final Map<int, TextEditingController> denomCtrl;
  final String Function(double) fmtFn;
  final Widget? extraChild;

  const _DenomCard({
    required this.title,
    required this.denomCtrl,
    required this.fmtFn,
    this.extraChild,
  });

  @override
  Widget build(BuildContext context) {
    final entries = denomCtrl.entries.toList();
    return _SectionCard(
      title: title,
      icon:  Icons.payments_outlined,
      child: Column(children: [
        // 2 cặp [label|input] mỗi hàng
        for (int i = 0; i < entries.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: _DenomRow(
                  denom: entries[i].key, ctrl: entries[i].value, fmtFn: fmtFn)),
              const SizedBox(width: 10),
              if (i + 1 < entries.length)
                Expanded(child: _DenomRow(
                    denom: entries[i+1].key, ctrl: entries[i+1].value, fmtFn: fmtFn))
              else
                const Expanded(child: SizedBox()),
            ]),
          ),
        if (extraChild != null) extraChild!,
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Inventory Section
// ══════════════════════════════════════════════════════════════

class _InventorySection extends StatelessWidget {
  final bool isClose;
  final List<Map<String, dynamic>> ingredients;
  final Map<int, TextEditingController> packCtrl;
  final Map<int, TextEditingController> unitCtrl;

  const _InventorySection({
    required this.isClose,
    required this.ingredients,
    required this.packCtrl,
    required this.unitCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final main = ingredients
        .where((i) =>
    (i['ingredientType'] as String?)?.toUpperCase() != 'SUB')
        .toList();
    final sub = ingredients
        .where((i) =>
    (i['ingredientType'] as String?)?.toUpperCase() == 'SUB')
        .toList();

    if (ingredients.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Text('Không có nguyên liệu',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface
                    .withOpacity(0.4))),
      ));
    }

    return Column(children: [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:        isClose
              ? Colors.blue.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isClose
                  ? Colors.blue.shade200 : Colors.orange.shade200),
        ),
        child: Row(children: [
          Icon(isClose
              ? Icons.inventory_2_outlined : Icons.info_outline,
              size: 16,
              color: isClose
                  ? Colors.blue.shade700 : Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(
            isClose
                ? 'Kiểm kho kết ca — nhập số lượng nguyên liệu còn lại.'
                : 'Ca đầu tiên trong ngày — nhập số lượng nguyên liệu trong kho.',
            style: TextStyle(fontSize: 12, height: 1.4,
                color: isClose
                    ? Colors.blue.shade800 : Colors.orange.shade800),
          )),
        ]),
      ),
      if (main.isNotEmpty)
        _IngGroupCard(
          title: 'Nguyên liệu Chính',
          icon:  Icons.kitchen_outlined,
          color: Colors.blue,
          ingredients: main,
          packCtrl: packCtrl,
          unitCtrl: unitCtrl,
        ),
      if (main.isNotEmpty && sub.isNotEmpty) const SizedBox(height: 8),
      if (sub.isNotEmpty)
        _IngGroupCard(
          title: 'Nguyên liệu Phụ',
          icon:  Icons.add_box_outlined,
          color: Colors.deepOrange,
          ingredients: sub,
          packCtrl: packCtrl,
          unitCtrl: unitCtrl,
        ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// Ingredient Group Card
// ══════════════════════════════════════════════════════════════

class _IngGroupCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> ingredients;
  final Map<int, TextEditingController> packCtrl;
  final Map<int, TextEditingController> unitCtrl;

  const _IngGroupCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.ingredients,
    required this.packCtrl,
    required this.unitCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${ingredients.length}', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: color)),
            ),
          ]),
        ),

        // Rows
        ...ingredients.map((ing) {
          final id          = ing['id'] as int;
          final name        = ing['name'] as String;
          final unitPerPack = ing['unitPerPack'] as int? ?? 1;
          final imageUrl    = ing['imageUrl'] as String?;
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(border: Border(
                top: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4)))),
            child: Row(children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? CachedNetworkImage(
                    imageUrl: PosService.buildImageUrl(imageUrl),
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        _placeholder(cs))
                    : _placeholder(cs),
              ),
              const SizedBox(width: 12),
              // Name
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('1 bịch = $unitPerPack lẻ',
                        style: TextStyle(fontSize: 11,
                            color: cs.onSurface.withOpacity(0.5))),
                  ])),
              // Pack input
              _IngQtyField(
                  label: 'Bịch',
                  ctrl:  packCtrl[id] ?? TextEditingController()),
              const SizedBox(width: 8),
              // Unit input
              _IngQtyField(
                  label: 'Lẻ',
                  ctrl:  unitCtrl[id] ?? TextEditingController()),
            ]),
          );
        }),
        const SizedBox(height: 6),
      ]),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.set_meal,
          color: cs.onSurface.withOpacity(0.3), size: 22));
}

// ── Ingredient qty field ──────────────────────────────────────

class _IngQtyField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _IngQtyField({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      child: Column(children: [
        Text(label, style: TextStyle(
            fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
        const SizedBox(height: 4),
        _StableNumberField(controller: ctrl, isDense: true),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Section Card
// ══════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String  title;
  final IconData icon;
  final Widget? trailing;
  final Widget  child;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Icon(icon, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold,
                color: cs.onSurface))),
            if (trailing != null) trailing!,
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: child,
        ),
      ]),
    );
  }
}