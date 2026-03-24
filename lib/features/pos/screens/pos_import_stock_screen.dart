// lib/features/pos/screens/pos_import_stock_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/shared/widgets/app_input_decimal.dart';

// ═══════════════════════════════════════════════════════════════
// IMPORT STOCK SCREEN — Nhập kho (chỉ 1 màn hình)
// ═══════════════════════════════════════════════════════════════

class PosImportStockScreen extends StatefulWidget {
  const PosImportStockScreen({super.key});

  @override
  State<PosImportStockScreen> createState() => _PosImportStockScreenState();
}

class _PosImportStockScreenState extends State<PosImportStockScreen> {
  List<Map<String, dynamic>> _ingredients = [];
  bool _loadingIngs = true;
  final Map<int, double> _importQty = {};
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIngredients() async {
    try {
      final list = await PosService.instance.getIngredients();
      if (mounted) {
        setState(() {
          _ingredients = list;
          _loadingIngs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingIngs = false);
    }
  }

  bool get _hasAny => _importQty.values.any((v) => v > 0);

  Future<void> _submit() async {
    final items = _importQty.entries
        .where((e) => e.value > 0)
        .map((e) => {'ingredientId': e.key, 'packQty': e.value})
        .toList();
    if (items.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await PosService.instance.importStock(items);
      if (mounted) {
        setState(() => _importQty.clear());
        _noteCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nhập kho thành công')),
        );
        await _loadIngredients();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Tách và sort theo displayOrder ───────────────────────────
  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) {
    final copy = List<Map<String, dynamic>>.from(list);
    copy.sort((a, b) =>
        ((a['displayOrder'] as int?) ?? 0)
            .compareTo((b['displayOrder'] as int?) ?? 0));
    return copy;
  }

  List<Map<String, dynamic>> get _main => _sorted(_ingredients
      .where((i) => (i['ingredientType'] as String?)?.toUpperCase() != 'SUB')
      .toList());

  List<Map<String, dynamic>> get _sub => _sorted(_ingredients
      .where((i) => (i['ingredientType'] as String?)?.toUpperCase() == 'SUB')
      .toList());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text('Nhập kho trong ca',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight),
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              // ── List nguyên liệu (scrollable) ─────────────────
              Expanded(
                child: _loadingIngs
                    ? const Center(child: CircularProgressIndicator())
                    : _ingredients.isEmpty
                    ? Center(
                  child: Text(
                    'Chưa có nguyên liệu nào',
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.5)),
                  ),
                )
                    : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // MAIN group
                    if (_main.isNotEmpty) ...[
                      _GroupHeader(
                        title: 'Nguyên liệu Chính',
                        count: _main.length,
                        color: Colors.blue,
                        icon: Icons.kitchen_outlined,
                      ),
                      const SizedBox(height: 8),
                      ..._main.map((ing) => _IngredientRow(
                        ing: ing,
                        qty: _importQty[ing['id'] as int] ?? 0.0,
                        onChanged: (v) => setState(() {
                          final id = ing['id'] as int;
                          if (v <= 0) {
                            _importQty.remove(id);
                          } else {
                            _importQty[id] = v;
                          }
                        }),
                      )),
                    ],

                    // SUB group
                    if (_sub.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _GroupHeader(
                        title: 'Nguyên liệu Phụ',
                        count: _sub.length,
                        color: Colors.deepOrange,
                        icon: Icons.add_box_outlined,
                      ),
                      const SizedBox(height: 8),
                      ..._sub.map((ing) => _IngredientRow(
                        ing: ing,
                        qty: _importQty[ing['id'] as int] ?? 0.0,
                        onChanged: (v) => setState(() {
                          final id = ing['id'] as int;
                          if (v <= 0) {
                            _importQty.remove(id);
                          } else {
                            _importQty[id] = v;
                          }
                        }),
                      )),
                    ],
                  ],
                ),
              ),

              // ── Submit button (FIXED bottom) ──────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(
                      top: BorderSide(color: cs.outlineVariant)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    icon: _submitting
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.check, size: 18),
                    label: Text(
                      _hasAny
                          ? 'Xác nhận nhập kho (${_importQty.values.where((v) => v > 0).length} loại)'
                          : 'Chọn nguyên liệu để nhập',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: (!_hasAny || _submitting) ? null : _submit,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Group header ──────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _GroupHeader({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ),
      ]),
    );
  }
}

// ── Ingredient row ────────────────────────────────────────────

class _IngredientRow extends StatelessWidget {
  final Map<String, dynamic> ing;
  final double qty;
  final void Function(double) onChanged;

  const _IngredientRow({
    required this.ing,
    required this.qty,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: qty > 0
            ? Border.all(color: cs.primary, width: 1.5)
            : null,
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            ing['name'] as String,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: AppInputDecimal(
            label: 'Số lượng nhập',
            hint: '0',
            suffixText: '',
            initialValue: qty > 0 ? qty : null,
            decimalPlaces: 2,
            min: 0,
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }
}