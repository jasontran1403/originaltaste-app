// lib/features/pos/screens/pos_shift_screen.dart

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'package:originaltaste/data/models/pos/pos_shift_model.dart';
import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/shared/widgets/app_input_text.dart';

class _DecimalTwoPlacesFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    // Cho phép xóa hết
    if (text.isEmpty) return newValue;

    // Chỉ cho phép chữ số và tối đa 1 dấu chấm
    final validChars = RegExp(r'^[0-9]*\.?[0-9]*$');
    if (!validChars.hasMatch(text)) return oldValue;

    // Không cho phép 2 dấu chấm
    if (text.indexOf('.') != text.lastIndexOf('.')) return oldValue;

    // Tối đa 2 chữ số sau dấu chấm
    final dotIndex = text.indexOf('.');
    if (dotIndex != -1 && text.length - dotIndex - 1 > 2) return oldValue;

    return newValue;
  }
}

// ─────────────────────────────────────────────────────────────
// Helper push màn hình
// ─────────────────────────────────────────────────────────────

Future<void> showPosShiftModal(
    BuildContext context, {
      PosShiftModel? currentShift,
      required void Function(PosShiftModel?) onShiftChanged,
    }) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (ctx) => PosShiftScreen(
        currentShift:   currentShift,
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
  late final TabController _tabCtrl;

  double _openingCash = 0.0;

  Future<void> _showVarianceWarningDialog(double variancePercent) async {
    final shift = widget.currentShift!;
    final openingCash = shift.openingCash?.toDouble() ??
        (shift.id != null ? await PosService.instance.getOpeningCash(shift.id!) : 0.0);
    final expectedTotal = openingCash + shift.totalRevenue.toDouble();
    final actual = _actualCloseAmount;
    final diff = actual - expectedTotal;

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Lệch tiền'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildSummaryRow('Tiền đầu ca:', openingCash),
            _buildSummaryRow('Doanh thu trong ca:', shift.totalRevenue.toDouble()),
            _buildSummaryRow('Tổng dự kiến:', expectedTotal, isBold: true),
            const Divider(height: 24),
            _buildSummaryRow('Tổng tiền bạn đếm:', actual, color: Colors.blue),
            _buildSummaryRow('Chênh lệch:', diff, color: diff >= 0 ? Colors.green : Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Vui lòng kiểm tra lại tiền mặt và chuyển khoản.\n'
                  'Không thể đóng ca khi lệch quá 5%.',
              style: TextStyle(color: Colors.redAccent, fontSize: 13.5),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu, kiểm tra lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, num value, {Color? color, bool isBold = false}) {
    final fmt = _fmtVnd(value.toDouble());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            '${fmt}đ',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
              fontSize: isBold ? 15 : 14,
            ),
          ),
        ],
      ),
    );
  }

  double get _actualCloseAmount {
    final denomList = _buildDenomList(_closeDenomCtrl);
    double sum = denomList.fold(0.0, (prev, item) =>
    prev + (item['denomination'] as int) * (item['quantity'] as int));

    final transfer = _ctrlDouble(_transferCtrl);
    return sum + transfer;
  }

  /// Tính % lệch so với doanh thu
  Future<double> _calculateVariancePercent(PosShiftModel shift) async {
    final expectedRevenue = shift.totalRevenue.toDouble();
    if (expectedRevenue <= 0) return 0.0;

    // Lấy openingCash (ưu tiên từ model, sau đó gọi API)
    double openingCash = 0.0;
    if (shift.openingCash != null) {
      openingCash = shift.openingCash!.toDouble();   // giả sử model có field này
    } else if (shift.id != null) {
      openingCash = await PosService.instance.getOpeningCash(shift.id!);
    }

    final expectedTotal = openingCash + expectedRevenue;
    if (expectedTotal <= 0) return 0.0;

    final actual = _actualCloseAmount;
    final diff = (actual - expectedTotal).abs();

    return (diff / expectedTotal) * 100;
  }

  bool _isLoading    = true;
  bool _isFirstShift = false;
  List<Map<String, dynamic>> _ingredients = [];

  PosShiftModel? _localShift;

  static const List<int> kDenoms = [
    500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000,
  ];

  void _fillFromOcr(ShiftOcrResult result) {
    // Fill tên nhân viên nếu OCR tìm được và ô đang trống
    if (result.staffName != null &&
        result.staffName!.isNotEmpty &&
        _staffNameCtrl.text.trim().isEmpty) {
      _staffNameCtrl.text = result.staffName!;
    }

    // Fill số lượng vào các ô tương ứng
    for (final item in result.inventoryList) {
      final id = item.matchedIngredientId;
      if (id == null) continue;

      // Chọn pack/unit ctrl phù hợp (mở ca hay đóng ca)
      final pCtrl = _isClosing ? _closePackCtrl[id] : _openPackCtrl[id];
      final uCtrl = _isClosing ? _closeUnitCtrl[id] : _openUnitCtrl[id];

      if (pCtrl != null && item.packQuantity != null) {
        pCtrl.text = '${item.packQuantity}';
      }
      if (uCtrl != null && item.unitQuantity != null && item.unitQuantity! > 0) {
        final u = item.unitQuantity!;
        uCtrl.text = u == u.roundToDouble()
            ? u.toInt().toString()
            : u.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
      }
    }

    // Hiện snack báo kết quả match
    final matched   = result.inventoryList.where((i) => i.matchedIngredientId != null).length;
    final unmatched = result.inventoryList.length - matched;
    String msg = 'Đã điền $matched mục';
    if (unmatched > 0) msg += ' ($unmatched mục không nhận dạng được)';
    _snack(msg, isError: unmatched > 0 && matched == 0);
  }

  final _staffNameCtrl = TextEditingController();
  final _noteCtrl      = TextEditingController();

  late final Map<int, TextEditingController> _openDenomCtrl;
  late final Map<int, TextEditingController> _closeDenomCtrl;

  final Map<int, TextEditingController> _openPackCtrl  = {};
  final Map<int, TextEditingController> _openUnitCtrl  = {};  // decimal
  final Map<int, TextEditingController> _closePackCtrl = {};
  final Map<int, TextEditingController> _closeUnitCtrl = {};  // decimal

  final _transferCtrl = TextEditingController();

  bool get _showInventoryTab => _isClosing || _isFirstShift;
  bool get _isClosing => widget.currentShift?.isOpen == true;
  String get _tab1Label => _isClosing ? 'Kho kết ca' : 'Kho đầu ngày';

  List<Map<String, dynamic>> get _currentOpenInventory =>
      _localShift?.openInventory ?? widget.currentShift?.openInventory ?? [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _openDenomCtrl  = {for (final d in kDenoms) d: TextEditingController()};
    _closeDenomCtrl = {for (final d in kDenoms) d: TextEditingController()};
    if (_isClosing) {
      _tabCtrl.addListener(_onTabChanged);
    }

    if (_isClosing && widget.currentShift?.id != null) {
      _loadOpeningCash(widget.currentShift!.id!);
    }

    _init();
  }

  Future<void> _loadOpeningCash(int shiftId) async {
    try {
      final amount = await PosService.instance.getOpeningCash(shiftId);

      debugPrint('=== DEBUG Opening Cash for shift $shiftId: $amount ===');
      if (mounted) setState(() => _openingCash = amount);

    } catch (_) {
      if (mounted) setState(() => _openingCash = 0.0);
    }
  }

  void _onTabChanged() {
    if (_tabCtrl.index == 1 && _isClosing && !_isLoading) {
      _reloadInventory();
    }
  }

  Future<void> _reloadInventory() async {
    try {
      final fresh = await PosService.instance.getCurrentShift();
      if (mounted && fresh != null) {
        setState(() => _localShift = fresh);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
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
      final futures = <Future>[
        PosService.instance.getIngredients(),
        PosService.instance.isFirstShiftOfDay(),
        if (_isClosing) PosService.instance.getCurrentShift(),
      ];
      final results = await Future.wait(futures);

      final ings    = results[0] as List<Map<String, dynamic>>;
      final isFirst = results[1] as bool;
      final fresh   = _isClosing ? results[2] as PosShiftModel? : null;

      for (final ing in ings) {
        final id = ing['id'] as int;
        _openPackCtrl[id]  = TextEditingController();
        _openUnitCtrl[id]  = TextEditingController();
        _closePackCtrl[id] = TextEditingController();
        _closeUnitCtrl[id] = TextEditingController();
      }

      if (!_isClosing && widget.currentShift != null) {
        for (final inv in widget.currentShift!.openInventory) {
          final id   = inv['ingredientId'] as int?;
          if (id == null) continue;
          final pack = inv['packQuantity'] as int? ?? 0;
          final unit = inv['unitQuantity'];  // may be int or double
          if (pack > 0) _openPackCtrl[id]?.text = '$pack';
          if (unit != null && unit != 0) {
            _openUnitCtrl[id]?.text = _fmtUnit(unit);
          }
        }
      }

      if (mounted) {
        setState(() {
          _ingredients  = ings;
          _isFirstShift = isFirst;
          if (fresh != null) _localShift = fresh;
          _isLoading    = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Format unitQuantity: 1.0 → "1", 0.25 → "0.25", 0.50 → "0.5"
  String _fmtUnit(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    if (d == d.roundToDouble()) return d.toStringAsFixed(0);
    // Loại bỏ trailing zero: 0.50 → 0.5
    return d.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }

  void _dismiss() => Navigator.of(context).pop();

  int _ctrlInt(TextEditingController c) =>
      int.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  double _ctrlDouble(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  // Đọc unitQuantity dưới dạng double (hỗ trợ 0.25)
  double _ctrlUnit(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0.0;

  List<Map<String, dynamic>> _buildDenomList(
      Map<int, TextEditingController> ctrlMap) =>
      ctrlMap.entries
          .map((e) => {'denomination': e.key, 'quantity': _ctrlInt(e.value)})
          .where((m) => (m['quantity'] as int) > 0)
          .toList();

  // packQuantity = int, unitQuantity = double (gửi lên server)
  List<Map<String, dynamic>> _buildInventoryList(
      Map<int, TextEditingController> packMap,
      Map<int, TextEditingController> unitMap) =>
      _ingredients.map((ing) {
        final id   = ing['id'] as int;
        final unit = _ctrlUnit(unitMap[id] ?? TextEditingController());
        return {
          'ingredientId': id,
          'packQuantity': _ctrlInt(packMap[id] ?? TextEditingController()),
          'unitQuantity': unit,   // ← double, không phải int
        };
      }).toList();

  bool _hasAnyOpenQty() =>
      _openPackCtrl.values.any((c) => _ctrlInt(c) > 0) ||
          _openUnitCtrl.values.any((c) => _ctrlUnit(c) > 0);

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
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đóng ca'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _closeShift();
  }

  Future<void> _closeShift() async {
    // ── Validate cơ bản ─────────────────────────────────────
    final denomList = _buildDenomList(_closeDenomCtrl);
    final transfer = _ctrlDouble(_transferCtrl);
    final hasAnyMoney = denomList.isNotEmpty || transfer > 0;

    if (!hasAnyMoney) {
      _snack('Vui lòng nhập ít nhất một mệnh giá tiền cuối ca.', isError: true);
      return;
    }

    // ── KIỂM TRA LỆCH > 5% ───────────────────────────────────
    if (widget.currentShift != null) {
      final variancePercent = await _calculateVariancePercent(widget.currentShift!);

      if (variancePercent > 5.0) {
        await _showVarianceWarningDialog(variancePercent);
        return;                    // ← KHÔNG cho đóng ca
      }
    }

    // ── Nếu qua validation thì mới đóng ca ───────────────────
    setState(() => _isLoading = true);
    try {
      final body = <String, dynamic>{
        'closeDenominations': denomList,
        'closeInventory': _buildInventoryList(_closePackCtrl, _closeUnitCtrl),
        if (transfer > 0) 'transferAmount': transfer,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      };

      await PosService.instance.closeShift(body);
      widget.onShiftChanged(null);
      if (mounted) _dismiss();
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('mệnh giá')) msg = 'Vui lòng nhập ít nhất một mệnh giá tiền cuối ca.';
      if (msg.contains('kho cuối ca')) msg = 'Vui lòng nhập số lượng nguyên liệu kiểm kho cuối ca.';
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
                    color: Colors.orange.shade100, shape: BoxShape.circle),
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
            if (_showInventoryTab)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    dividerColor: Colors.transparent,
                    labelPadding: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6),
                    indicatorPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 5),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        colors: _isClosing
                            ? [
                          const Color(0xFFEF4444),
                          const Color(0xFFF87171)
                        ]
                            : [
                          const Color(0xFF10B981),
                          const Color(0xFF34D399)
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isClosing
                              ? Colors.red
                              : Colors.green)
                              .withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade700,
                    labelStyle: const TextStyle(
                      fontSize: 15.8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      const Tab(text: 'Thông tin ca'),
                      Tab(text: _tab1Label),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: _showInventoryTab
                  ? TabBarView(
                controller: _tabCtrl,
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: _isClosing
                        ? _CloseInfoTab(
                      shift:          widget.currentShift!,
                      closeDenomCtrl: _closeDenomCtrl,
                      transferCtrl:   _transferCtrl,
                      noteCtrl:       _noteCtrl,
                      openingCash:    _openingCash,
                    )
                        : _OpenInfoTab(
                      staffNameCtrl:  _staffNameCtrl,
                      openDenomCtrl:  _openDenomCtrl,
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: _InventorySection(
                      isClose:       _isClosing,
                      ingredients:   _ingredients,
                      packCtrl:      _isClosing
                          ? _closePackCtrl
                          : _openPackCtrl,
                      unitCtrl:      _isClosing
                          ? _closeUnitCtrl
                          : _openUnitCtrl,
                      openInventory: _isClosing
                          ? _currentOpenInventory
                          : [],
                      shiftId: _isClosing
                          ? (_localShift?.id ??
                          widget.currentShift?.id)
                          : null,
                      onOcrFill: _fillFromOcr,
                      onUpdateOpenInventory: _isClosing
                          ? (ingredientId, pack, unit) async {
                        final shiftId =
                            _localShift?.id ??
                                widget.currentShift?.id;
                        if (shiftId == null) return;
                        try {
                          await PosService.instance
                              .updateOpenInventory(
                            shiftId:      shiftId,
                            ingredientId: ingredientId,
                            packQuantity: pack,
                            unitQuantity: unit,
                          );
                          await _reloadInventory();
                        } catch (e) {
                          _snack('Lỗi cập nhật kho: $e',
                              isError: true);
                        }
                      }
                          : null,
                    ),
                  ),
                ],
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                child: _OpenInfoTab(
                  staffNameCtrl:  _staffNameCtrl,
                  openDenomCtrl:  _openDenomCtrl,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Format tiền VNĐ
// ══════════════════════════════════════════════════════════════

final _vndFmt = NumberFormat('#,###', 'vi_VN');
String _fmtVnd(double v) => _vndFmt.format(v).replaceAll(',', '.');

// ══════════════════════════════════════════════════════════════
// _StableNumberField — thêm tham số isDecimal
// ══════════════════════════════════════════════════════════════

class _StableNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool   isDense;
  final bool   isDecimal;   // ← MỚI

  const _StableNumberField({
    required this.controller,
    this.hint      = '0',
    this.isDense   = false,
    this.isDecimal = false,   // ← MỚI
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller:   controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      inputFormatters: isDecimal
          ? [_DecimalTwoPlacesFormatter()]
          : [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: isDense ? 13 : 15,
          fontWeight: FontWeight.w600,
          color: cs.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: cs.onSurface.withOpacity(0.3),
            fontSize: isDense ? 13 : 15),
        isDense: isDense,
        contentPadding: EdgeInsets.symmetric(
            vertical: isDense ? 6 : 10, horizontal: 8),
        filled:    true,
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
// Open Info Tab — giữ nguyên
// ══════════════════════════════════════════════════════════════

class _OpenInfoTab extends StatefulWidget {
  final TextEditingController staffNameCtrl;
  final Map<int, TextEditingController> openDenomCtrl;

  const _OpenInfoTab({
    required this.staffNameCtrl,
    required this.openDenomCtrl,
  });

  @override
  State<_OpenInfoTab> createState() => _OpenInfoTabState();
}

class _OpenInfoTabState extends State<_OpenInfoTab> {
  final _totalNotifier = ValueNotifier<double>(0);

  @override
  void dispose() { _totalNotifier.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SectionCard(
        title: 'Thông tin ca',
        icon:  Icons.person_outline,
        child: AppInputText(
          controller: widget.staffNameCtrl,
          label:      'Tên nhân viên *',
          hint:       'Nhập tên...',
          prefixIcon: const Icon(Icons.badge_outlined),
          autofocus:  true,
        ),
      ),
      const SizedBox(height: 12),
      _TotalBanner(notifier: _totalNotifier, hasTransfer: false),
      const SizedBox(height: 12),
      _DenomCard(
        title:         'Tiền đầu ca',
        denomCtrl:     widget.openDenomCtrl,
        totalNotifier: _totalNotifier,
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// Close Info Tab — giữ nguyên
// ══════════════════════════════════════════════════════════════

class _CloseInfoTab extends StatefulWidget {
  final PosShiftModel shift;
  final Map<int, TextEditingController> closeDenomCtrl;
  final TextEditingController transferCtrl;
  final TextEditingController noteCtrl;
  final double openingCash;           // ← Đã truyền từ parent

  const _CloseInfoTab({
    required this.shift,
    required this.closeDenomCtrl,
    required this.transferCtrl,
    required this.noteCtrl,
    required this.openingCash,
  });

  @override
  State<_CloseInfoTab> createState() => _CloseInfoTabState();
}

class _CloseInfoTabState extends State<_CloseInfoTab> {
  final _totalNotifier = ValueNotifier<double>(0);

  @override
  void dispose() {
    _totalNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Card thông tin ca đang mở (giữ nguyên)
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
              const Text('Ca đang mở', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(widget.shift.staffName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              Text(
                'Mở lúc ${DateFormat('HH:mm dd/MM').format(DateTime.fromMillisecondsSinceEpoch(widget.shift.openTime))}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Đơn hàng', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${widget.shift.totalOrders}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
              Text('${_fmtVnd(widget.shift.totalRevenue)}đ',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ],
        ),
      ),

      const SizedBox(height: 12),

      // === CONTAINER 2 CỘT MỚI ===
      _ShiftMoneySummary(
        openingCash: widget.openingCash,
        totalRevenue: widget.shift.totalRevenue.toDouble(),
      ),

      const SizedBox(height: 12),

      _TotalBanner(notifier: _totalNotifier, hasTransfer: true),
      const SizedBox(height: 12),

      _DenomCard(
        title: 'Tiền cuối ca',
        denomCtrl: widget.closeDenomCtrl,
        transferCtrl: widget.transferCtrl,
        totalNotifier: _totalNotifier,
      ),

      const SizedBox(height: 12),

      _SectionCard(
        title: 'Ghi chú chi phí phát sinh',
        icon: Icons.notes_outlined,
        child: AppInputText(
          controller: widget.noteCtrl,
          label: 'Ghi chú (nếu có)',
          hint: 'Nhập ghi chú chi phí...',
          maxLines: 3,
        ),
      ),
    ]);
  }
}

// ── _DenomRow / _DenomCard / banners — giữ nguyên ────────────

class _DenomRow extends StatelessWidget {
  final int denom;
  final TextEditingController ctrl;
  const _DenomRow({required this.denom, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
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
          child: Text(
            '${_fmtVnd(denom.toDouble())}đ',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12,
                color: Colors.orange.shade700),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 2,
        child: _StableNumberField(controller: ctrl),
      ),
    ]);
  }
}

class _DenomCard extends StatefulWidget {
  final String title;
  final Map<int, TextEditingController> denomCtrl;
  final TextEditingController? transferCtrl;
  final ValueNotifier<double>? totalNotifier;

  const _DenomCard({
    required this.title,
    required this.denomCtrl,
    this.transferCtrl,
    this.totalNotifier,
  });

  @override
  State<_DenomCard> createState() => _DenomCardState();
}

class _DenomCardState extends State<_DenomCard> {
  double _total = 0;

  @override
  void initState() {
    super.initState();
    for (final e in widget.denomCtrl.entries) {
      e.value.addListener(_recalculate);
    }
    widget.transferCtrl?.addListener(_recalculate);
    _recalculate();
  }

  @override
  void dispose() {
    for (final e in widget.denomCtrl.entries) {
      e.value.removeListener(_recalculate);
    }
    widget.transferCtrl?.removeListener(_recalculate);
    super.dispose();
  }

  void _recalculate() {
    double sum = 0;
    for (final e in widget.denomCtrl.entries) {
      final qty = int.tryParse(e.value.text.trim()) ?? 0;
      sum += e.key * qty;
    }
    if (widget.transferCtrl != null) {
      sum += double.tryParse(
          widget.transferCtrl!.text.replaceAll(',', '').trim()) ?? 0;
    }
    widget.totalNotifier?.value = sum;
    if (mounted) setState(() => _total = sum);
  }

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final entries = widget.denomCtrl.entries.toList();
    final hasTransfer = widget.transferCtrl != null;

    return _SectionCard(
      title: widget.title,
      icon:  Icons.payments_outlined,
      child: Column(children: [
        for (int i = 0; i < entries.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: _DenomRow(
                  denom: entries[i].key, ctrl: entries[i].value)),
              const SizedBox(width: 10),
              if (i + 1 < entries.length)
                Expanded(child: _DenomRow(
                    denom: entries[i + 1].key,
                    ctrl: entries[i + 1].value))
              else
                const Expanded(child: SizedBox()),
            ]),
          ),
        if (hasTransfer) ...[
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 9),
                decoration: BoxDecoration(
                  color:        Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                alignment: Alignment.center,
                child: Text('Chuyển khoản',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12,
                        color: Colors.blue.shade700)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _StableNumberField(
                  controller: widget.transferCtrl!, hint: '0'),
            ),
          ]),
        ],
        if (widget.totalNotifier == null) ...[
          const SizedBox(height: 12),
          _TotalBannerInline(
              total: _total, hasTransfer: hasTransfer, cs: cs),
        ],
      ]),
    );
  }
}

class _TotalBannerInline extends StatelessWidget {
  final double total; final bool hasTransfer; final ColorScheme cs;
  const _TotalBannerInline(
      {required this.total, required this.hasTransfer, required this.cs});
  @override
  Widget build(BuildContext context) =>
      _buildTotalRow(total, hasTransfer, cs);
}

class _TotalBanner extends StatelessWidget {
  final ValueNotifier<double> notifier;
  final bool hasTransfer;
  const _TotalBanner({required this.notifier, required this.hasTransfer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: notifier,
      builder: (_, total, __) => _buildTotalRow(total, hasTransfer, cs),
    );
  }
}

class _ShiftMoneySummary extends StatelessWidget {
  final double openingCash;
  final double totalRevenue;

  const _ShiftMoneySummary({
    required this.openingCash,
    required this.totalRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final fmtOpening = _fmtVnd(openingCash);
    final fmtRevenue = _fmtVnd(totalRevenue);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cột trái: Tiền đầu ca
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_outlined, size: 18, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    const Text(
                      'Tiền đầu ca',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$fmtOpeningđ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),

          // Cột phải: Doanh thu trong ca
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.trending_up_rounded, size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    const Text(
                      'Doanh thu ca',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$fmtRevenueđ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


Widget _buildTotalRow(double total, bool hasTransfer, ColorScheme cs) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: total > 0
          ? cs.primary.withOpacity(0.08)
          : cs.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: total > 0
            ? cs.primary.withOpacity(0.3)
            : cs.outline.withOpacity(0.2),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 16,
              color: total > 0
                  ? cs.primary
                  : cs.onSurface.withOpacity(0.4)),
          const SizedBox(width: 8),
          Text(
            hasTransfer ? 'Tổng (tiền mặt + CK)' : 'Tổng tiền',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: total > 0
                    ? cs.onSurface
                    : cs.onSurface.withOpacity(0.4)),
          ),
        ]),
        Text(
          '${_fmtVnd(total)}đ',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold,
              color: total > 0
                  ? cs.primary
                  : cs.onSurface.withOpacity(0.3)),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// Inventory Section — truyền isDecimal=true cho ô lẻ
// ══════════════════════════════════════════════════════════════

class _InventorySection extends StatelessWidget {
  final bool isClose;
  final List<Map<String, dynamic>> ingredients;
  final Map<int, TextEditingController> packCtrl;
  final Map<int, TextEditingController> unitCtrl;
  final List<Map<String, dynamic>> openInventory;
  final int? shiftId;
  final Future<void> Function(int ingredientId, int pack, double unit)?
  onUpdateOpenInventory;

  // ← THÊM: callback khi OCR xong để fill controllers từ parent
  final void Function(ShiftOcrResult result)? onOcrFill;

  const _InventorySection({
    required this.isClose,
    required this.ingredients,
    required this.packCtrl,
    required this.unitCtrl,
    this.openInventory = const [],
    this.shiftId,
    this.onUpdateOpenInventory,
    this.onOcrFill,   // ← THÊM
  });

  @override
  Widget build(BuildContext context) {
    final main = ingredients
        .where((i) => (i['ingredientType'] as String?)?.toUpperCase() != 'SUB')
        .toList();
    final sub = ingredients
        .where((i) => (i['ingredientType'] as String?)?.toUpperCase() == 'SUB')
        .toList();

    if (ingredients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Text('Không có nguyên liệu',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.4))),
        ),
      );
    }

    return Column(children: [
      // ── Banner hướng dẫn + nút chụp ảnh ─────────────────────
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isClose ? Colors.blue.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isClose ? Colors.blue.shade200 : Colors.orange.shade200),
        ),
        child: Row(children: [
          Icon(
            isClose ? Icons.inventory_2_outlined : Icons.info_outline,
            size: 16,
            color: isClose ? Colors.blue.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isClose
                  ? 'Kiểm kho kết ca — nhập số lượng còn lại.'
                  : 'Ca đầu tiên — nhập số lượng nguyên liệu trong kho.',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isClose
                      ? Colors.blue.shade800
                      : Colors.orange.shade800),
            ),
          ),
          const SizedBox(width: 8),
          // ── NÚT CHỤP ẢNH ────────────────────────────────────
          _OcrCameraButton(
            isClose:   isClose,
            shiftId:   shiftId,
            onOcrFill: onOcrFill,
          ),
        ]),
      ),

      // ── Bảng kho (giữ nguyên như cũ) ────────────────────────
      if (isClose) ...[
        if (main.isNotEmpty)
          _CloseInventoryTable(
            title:                 'Nguyên liệu Chính',
            ingredients:           main
              ..sort((a, b) =>
                  ((a['displayOrder'] as int?) ?? 0)
                      .compareTo((b['displayOrder'] as int?) ?? 0)),
            openInventory:         openInventory,
            packCtrl:              packCtrl,
            unitCtrl:              unitCtrl,
            onUpdateOpenInventory: onUpdateOpenInventory,
          ),
        if (sub.isNotEmpty) const SizedBox(height: 12),
        if (sub.isNotEmpty)
          _CloseInventoryTable(
            title:                 'Nguyên liệu Phụ',
            ingredients:           sub
              ..sort((a, b) =>
                  ((a['displayOrder'] as int?) ?? 0)
                      .compareTo((b['displayOrder'] as int?) ?? 0)),
            openInventory:         openInventory,
            packCtrl:              packCtrl,
            unitCtrl:              unitCtrl,
            onUpdateOpenInventory: onUpdateOpenInventory,
          ),
      ] else ...[
        if (main.isNotEmpty)
          _IngGroupCard(
            title:       'Nguyên liệu Chính',
            icon:        Icons.kitchen_outlined,
            color:       Colors.blue,
            ingredients: main,
            packCtrl:    packCtrl,
            unitCtrl:    unitCtrl,
          ),
        if (main.isNotEmpty && sub.isNotEmpty) const SizedBox(height: 8),
        if (sub.isNotEmpty)
          _IngGroupCard(
            title:       'Nguyên liệu Phụ',
            icon:        Icons.add_box_outlined,
            color:       Colors.deepOrange,
            ingredients: sub,
            packCtrl:    packCtrl,
            unitCtrl:    unitCtrl,
          ),
      ],
    ]);
  }
}

class _OcrCameraButton extends StatefulWidget {
  final bool   isClose;
  final int?   shiftId;
  final void Function(ShiftOcrResult result)? onOcrFill;

  const _OcrCameraButton({
    required this.isClose,
    this.shiftId,
    this.onOcrFill,
  });

  @override
  State<_OcrCameraButton> createState() => _OcrCameraButtonState();
}

class _OcrCameraButtonState extends State<_OcrCameraButton> {
  bool _loading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();

    // Hỏi user: camera hay gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(isClose: widget.isClose),
    );
    if (source == null || !mounted) return;

    final picked = await picker.pickImage(
      source:      source,
      imageQuality: 85,
      maxWidth:    1920,
    );
    if (picked == null || !mounted) return;

    setState(() => _loading = true);

    try {
      final ShiftOcrResult result;
      if (widget.isClose && widget.shiftId != null) {
        result = await PosService.instance.uploadCloseShiftImage(
          filePath: picked.path,
          shiftId:  widget.shiftId!,
        );
      } else {
        result = await PosService.instance.uploadOpenShiftImage(
          filePath: picked.path,
          shiftId:  widget.shiftId,
        );
      }

      if (!mounted) return;

      if (result.isSuccess) {
        widget.onOcrFill?.call(result);
        _showSnack('OCR thành công — đã điền ${result.inventoryList.length} mục', isError: false);
      } else {
        _showSnack('OCR thất bại: ${result.errorMessage ?? "Lỗi không xác định"}', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Lỗi upload: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isClose ? Colors.blue.shade700 : Colors.orange.shade700;
    return GestureDetector(
      onTap: _loading ? null : _pickAndUpload,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: color.withOpacity(0.35)),
        ),
        child: _loading
            ? SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: color))
            : Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.camera_alt_outlined, size: 15, color: color),
          const SizedBox(width: 5),
          Text('Chụp ảnh',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      ),
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  final bool isClose;
  const _ImageSourceSheet({required this.isClose});

  @override
  Widget build(BuildContext context) {
    final color = isClose ? Colors.blue.shade700 : Colors.orange.shade700;
    return Container(
      margin:  const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2)),
        ),
        Text(
          'Nhập kho từ ảnh',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 4),
        Text('Chụp ảnh bảng kê kiểm kho để tự động điền số liệu',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: _SourceButton(
              icon:    Icons.camera_alt_rounded,
              label:   'Chụp ảnh',
              color:   color,
              onTap:   () => Navigator.pop(context, ImageSource.camera),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SourceButton(
              icon:    Icons.photo_library_rounded,
              label:   'Thư viện',
              color:   Colors.grey.shade700,
              onTap:   () => Navigator.pop(context, ImageSource.gallery),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Hủy', style: TextStyle(color: Colors.grey.shade600)),
        ),
      ]),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _SourceButton({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// _CloseInventoryTable — ô lẻ đầu ca và cuối ca dùng decimal
// ══════════════════════════════════════════════════════════════

class _CloseInventoryTable extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> ingredients;
  final List<Map<String, dynamic>> openInventory;
  final Map<int, TextEditingController> packCtrl;
  final Map<int, TextEditingController> unitCtrl;
  final Future<void> Function(int ingredientId, int pack, double unit)?
  onUpdateOpenInventory;

  const _CloseInventoryTable({
    this.title = 'Nguyên liệu Chính',
    required this.ingredients,
    required this.openInventory,
    required this.packCtrl,
    required this.unitCtrl,
    this.onUpdateOpenInventory,
  });

  @override
  State<_CloseInventoryTable> createState() =>
      _CloseInventoryTableState();
}

class _CloseInventoryTableState extends State<_CloseInventoryTable> {
  int? _focusedId;

  final Map<int, TextEditingController> _openPackCtrl = {};
  final Map<int, TextEditingController> _openUnitCtrl = {};

  final Map<int, DateTime> _lastEditTime = {};
  static const _debounce = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _buildOpenMap();
  }

  @override
  void didUpdateWidget(_CloseInventoryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openInventory != widget.openInventory) {
      final invMap = <int, Map<String, dynamic>>{};
      for (final inv in widget.openInventory) {
        final id = inv['ingredientId'] as int?;
        if (id != null) invMap[id] = inv;
      }
      for (final ing in widget.ingredients) {
        final id   = ing['id'] as int;
        if (id == _focusedId) continue;
        final open = invMap[id];
        final pack = open?['packQuantity'] as int? ?? 0;
        final unit = open?['unitQuantity'];
        _openPackCtrl[id]?.text = pack > 0 ? '$pack' : '';
        _openUnitCtrl[id]?.text =
        unit != null && unit != 0 ? _fmtUnit(unit) : '';
      }
    }
  }

  String _fmtUnit(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    if (d == d.roundToDouble()) return d.toStringAsFixed(0);
    return d.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  }

  void _buildOpenMap() {
    final invMap = <int, Map<String, dynamic>>{};
    for (final inv in widget.openInventory) {
      final id = inv['ingredientId'] as int?;
      if (id != null) invMap[id] = inv;
    }
    for (final ing in widget.ingredients) {
      final id   = ing['id'] as int;
      final open = invMap[id];
      final pack = open?['packQuantity'] as int? ?? 0;
      final unit = open?['unitQuantity'];
      _openPackCtrl[id] = TextEditingController(
          text: pack > 0 ? '$pack' : '');
      _openUnitCtrl[id] = TextEditingController(
          text: unit != null && unit != 0 ? _fmtUnit(unit) : '');
      _openPackCtrl[id]!.addListener(() => _scheduleDebounce(id));
      _openUnitCtrl[id]!.addListener(() => _scheduleDebounce(id));
    }
  }

  void _scheduleDebounce(int ingredientId) {
    final now = DateTime.now();
    _lastEditTime[ingredientId] = now;
    Future.delayed(_debounce, () {
      if (!mounted) return;
      final last = _lastEditTime[ingredientId];
      if (last == null) return;
      if (DateTime.now().difference(last) >= _debounce) {
        _onOpenUnfocus(ingredientId);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _openPackCtrl.values) c.dispose();
    for (final c in _openUnitCtrl.values) c.dispose();
    super.dispose();
  }

  Map<int, Map<String, dynamic>> get _invMap {
    final m = <int, Map<String, dynamic>>{};
    for (final inv in widget.openInventory) {
      final id = inv['ingredientId'] as int?;
      if (id != null) m[id] = inv;
    }
    return m;
  }

  void _onOpenUnfocus(int ingredientId) {
    if (widget.onUpdateOpenInventory == null) return;
    final pack =
        int.tryParse(_openPackCtrl[ingredientId]?.text.trim() ?? '') ?? 0;
    final unit =
        double.tryParse(_openUnitCtrl[ingredientId]?.text.trim() ?? '') ??
            0.0;
    widget.onUpdateOpenInventory!(ingredientId, pack, unit);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const hStyle = TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, height: 1.3);
    final isSub = widget.title.contains('Ph');
    final accentColor = isSub ? Colors.deepOrange : Colors.blue;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.07),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Icon(Icons.kitchen_outlined, size: 18, color: accentColor),
            const SizedBox(width: 8),
            Text(widget.title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: accentColor.shade700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${widget.ingredients.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor)),
            ),
          ]),
        ),

        // Column header
        Container(
          color: cs.surfaceContainerHighest.withOpacity(0.6),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(children: [
            const Expanded(
                flex: 5,
                child: Text('Tên Hàng', style: hStyle)),
            Expanded(
                flex: 4,
                child: Text('Đầu ca',
                    style:
                    hStyle.copyWith(color: Colors.orange.shade700),
                    textAlign: TextAlign.center)),
            Expanded(
                flex: 2,
                child: Text('Tổng Bán',
                    style:
                    hStyle.copyWith(color: Colors.purple.shade400),
                    textAlign: TextAlign.center)),
            Expanded(
                flex: 2,
                child: Text('Nhập',
                    style: hStyle.copyWith(
                        color: Colors.green.shade700),
                    textAlign: TextAlign.center)),
            Expanded(
                flex: 4,
                child: Text('Cuối ca',
                    style: hStyle.copyWith(color: Colors.blue.shade700),
                    textAlign: TextAlign.center)),
          ]),
        ),

        // Sub-header: Bịch / Lẻ labels
        Container(
          color: cs.surfaceContainerHighest.withOpacity(0.3),
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: Row(children: [
            const Expanded(flex: 5, child: SizedBox()),
            // Đầu ca: 2 sub-cols
            Expanded(
                flex: 2,
                child: Text('Bịch',
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange.shade600),
                    textAlign: TextAlign.center)),
            Expanded(
                flex: 2,
                child: Text('Lẻ',
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange.shade600),
                    textAlign: TextAlign.center)),
            // Tổng bán
            const Expanded(flex: 2, child: SizedBox()),
            // Nhập
            const Expanded(flex: 2, child: SizedBox()),
            // Cuối ca: 2 sub-cols
            Expanded(
                flex: 2,
                child: Text('Bịch',
                    style: TextStyle(
                        fontSize: 9, color: Colors.blue.shade600),
                    textAlign: TextAlign.center)),
            Expanded(
                flex: 2,
                child: Text('Lẻ',
                    style: TextStyle(
                        fontSize: 9, color: Colors.blue.shade600),
                    textAlign: TextAlign.center)),
          ]),
        ),

        // Data rows
        ...widget.ingredients.map((ing) {
          final id          = ing['id'] as int;
          final name        = ing['name'] as String;
          final unit        = ing['unit'] as String? ?? 'Cái';
          final unitPerPack = ing['unitPerPack'] as int? ?? 1;
          final open        = _invMap[id];
          final importQty   = open?['importPackQty'] as int? ?? 0;
          final soldQty     = (open?['soldQty'] as num?)?.toDouble() ?? 0.0;
          final isFocused   = _focusedId == id;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isFocused
                  ? Colors.blue.withOpacity(0.07)
                  : Colors.transparent,
              border: Border(
                  top: BorderSide(
                      color: cs.outlineVariant.withOpacity(0.35))),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tên + đơn vị
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isFocused
                                    ? Colors.blue.shade700
                                    : cs.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(
                          '1 Bịch = $unitPerPack $unit',
                          style: TextStyle(
                              fontSize: 9,
                              color: cs.onSurface.withOpacity(0.45)),
                        ),
                      ],
                    ),
                  ),
                  // Đầu ca bịch — integer
                  Expanded(
                      flex: 2,
                      child: _FocusableCell(
                        ctrl:      _openPackCtrl[id] ??
                            TextEditingController(),
                        isDecimal: false,
                        color:     Colors.orange,
                        onFocus: (f) {
                          setState(() => _focusedId =
                          f ? id : (_focusedId == id ? null : _focusedId));
                          if (!f) _onOpenUnfocus(id);
                        },
                        onDebounce: () => _onOpenUnfocus(id),
                      )),
                  // Đầu ca lẻ — DECIMAL
                  Expanded(
                      flex: 2,
                      child: _FocusableCell(
                        ctrl:      _openUnitCtrl[id] ??
                            TextEditingController(),
                        isDecimal: true,    // ← decimal
                        color:     Colors.orange,
                        onFocus: (f) {
                          setState(() => _focusedId =
                          f ? id : (_focusedId == id ? null : _focusedId));
                          if (!f) _onOpenUnfocus(id);
                        },
                        onDebounce: () => _onOpenUnfocus(id),
                      )),
                  // Tổng bán
                  Expanded(
                      flex: 2,
                      child: _ReadCell(
                          value:      soldQty,
                          highlighted: isFocused,
                          textColor:  Colors.purple.shade400)),
                  // Nhập trong ca
                  Expanded(
                      flex: 2,
                      child: _ReadCell(
                          value:      importQty,
                          highlighted: isFocused,
                          textColor:  Colors.green.shade700)),
                  // Cuối ca bịch — integer
                  Expanded(
                      flex: 2,
                      child: _FocusableCell(
                        ctrl:      widget.packCtrl[id] ??
                            TextEditingController(),
                        isDecimal: false,
                        onFocus: (f) => setState(() => _focusedId =
                        f ? id : (_focusedId == id ? null : _focusedId)),
                      )),
                  // Cuối ca lẻ — DECIMAL
                  Expanded(
                      flex: 2,
                      child: _FocusableCell(
                        ctrl:      widget.unitCtrl[id] ??
                            TextEditingController(),
                        isDecimal: true,    // ← decimal
                        onFocus: (f) => setState(() => _focusedId =
                        f ? id : (_focusedId == id ? null : _focusedId)),
                      )),
                ]),
          );
        }),

        const SizedBox(height: 8),
      ]),
    );
  }
}

// ── Read-only cell (giữ nguyên) ───────────────────────────────

class _ReadCell extends StatelessWidget {
  final num? value;           // thay vì int
  final bool highlighted;
  final Color? textColor;

  const _ReadCell({
    required this.value,
    this.highlighted = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? 0;

    // Format đẹp: 1.0 → "1",  1.43 → "1.43",  0.50 → "0.5"
    final String text;
    if (displayValue is int || displayValue == displayValue.toInt().toDouble()) {
      text = displayValue.toInt().toString();
    } else {
      text = displayValue.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }

    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor?.withOpacity(highlighted ? 1.0 : 0.65) ??
              cs.onSurface.withOpacity(highlighted ? 0.9 : 0.55),
        ),
      ),
    );
  }
}

// ── _FocusableCell — thêm isDecimal ──────────────────────────

class _FocusableCell extends StatefulWidget {
  final TextEditingController ctrl;
  final void Function(bool) onFocus;
  final Color?       color;
  final VoidCallback? onDebounce;
  final bool          isDecimal;   // ← MỚI

  const _FocusableCell({
    required this.ctrl,
    required this.onFocus,
    this.color,
    this.onDebounce,
    this.isDecimal = false,   // ← MỚI
  });

  @override
  State<_FocusableCell> createState() => _FocusableCellState();
}

class _FocusableCellState extends State<_FocusableCell> {
  late final FocusNode _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    if (widget.onDebounce != null) {
      widget.ctrl.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      widget.onDebounce?.call();
    });
  }

  void _onFocusChange() {
    widget.onFocus(_focus.hasFocus);
    if (!_focus.hasFocus && widget.onDebounce != null) {
      _debounce?.cancel();
      widget.onDebounce!();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChange);
    if (widget.onDebounce != null) {
      widget.ctrl.removeListener(_onTextChanged);
    }
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final isFocused = _focus.hasFocus;
    final accent    = widget.color ?? Colors.blue;

    return Container(
      margin:     const EdgeInsets.symmetric(horizontal: 2),
      height:     32,
      decoration: BoxDecoration(
        color: isFocused
            ? accent.withOpacity(0.12)
            : cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFocused ? accent : cs.outline.withOpacity(0.3),
          width: isFocused ? 1.5 : 1.0,
        ),
      ),
      child: TextField(
        controller:      widget.ctrl,
        focusNode:       _focus,
        keyboardType:    TextInputType.numberWithOptions(
            decimal: widget.isDecimal),
        inputFormatters: widget.isDecimal
            ? [_DecimalTwoPlacesFormatter()]        // ← decimal formatter
            : [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isFocused
                ? (accent == Colors.orange
                ? Colors.orange.shade700
                : Colors.blue.shade700)
                : cs.onSurface),
        decoration: InputDecoration(
          hintText: widget.isDecimal ? '0' : '0',
          hintStyle: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withOpacity(0.25)),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              vertical: 7, horizontal: 4),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// _IngGroupCard — ô lẻ dùng isDecimal=true
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
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${ingredients.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ]),
        ),
        ...ingredients.map((ing) {
          final id          = ing['id'] as int;
          final name        = ing['name'] as String;
          final unitPerPack = ing['unitPerPack'] as int? ?? 1;
          final imageUrl    = ing['imageUrl'] as String?;
          final unitLabel   = ing['unit'] as String? ?? 'Bịch';

          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: cs.outlineVariant.withOpacity(0.4)))),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? CachedNetworkImage(
                    imageUrl: PosService.buildImageUrl(imageUrl),
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _placeholder(cs))
                    : _placeholder(cs),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(
                          '1 $unitLabel = $unitPerPack lẻ',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withOpacity(0.6)),
                        ),
                      ])),
              // Ô Bịch — integer
              _IngQtyField(
                  label:     unitLabel,
                  ctrl:      packCtrl[id] ?? TextEditingController(),
                  isDecimal: false),
              const SizedBox(width: 8),
              // Ô Lẻ — decimal
              _IngQtyField(
                  label:     'Lẻ',
                  ctrl:      unitCtrl[id] ?? TextEditingController(),
                  isDecimal: true),
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

// ── _IngQtyField — thêm isDecimal ─────────────────────────────

class _IngQtyField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool   isDecimal;    // ← MỚI

  const _IngQtyField({
    required this.label,
    required this.ctrl,
    this.isDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      child: Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withOpacity(0.5))),
        const SizedBox(height: 4),
        _StableNumberField(
            controller: ctrl,
            isDense:    true,
            isDecimal:  isDecimal),    // ← truyền vào
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Section Card — giữ nguyên
// ══════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String   title;
  final IconData icon;
  final Widget?  trailing;
  final Widget   child;

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
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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