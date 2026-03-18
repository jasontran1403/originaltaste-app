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

  String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return '${v.toInt()} kg';
    return '${v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')} kg';
  }

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
          constraints: BoxConstraints(maxHeight: screenHeight), // Giới hạn max height = chiều cao màn hình
          margin: const EdgeInsets.all(10), // Padding ngoài 10 đơn vị
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Phần list nguyên liệu (scrollable)
              Expanded(
                child: _loadingIngs
                    ? const Center(child: CircularProgressIndicator())
                    : _ingredients.isEmpty
                    ? Center(
                  child: Text(
                    'Chưa có nguyên liệu nào',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
                  ),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ingredients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final ing = _ingredients[i];
                    final ingId = ing['id'] as int;
                    final qty = _importQty[ingId] ?? 0.0;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: qty > 0
                            ? Border.all(color: cs.primary, width: 1.5)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ing['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: AppInputDecimal(
                              label: 'Số lượng nhập',
                              hint: '0',
                              suffixText: 'Bịch',
                              initialValue: qty > 0 ? qty : null,
                              decimalPlaces: 2,
                              min: 0,
                              onChanged: (v) => setState(() {
                                if (v <= 0) {
                                  _importQty.remove(ingId);
                                } else {
                                  _importQty[ingId] = v;
                                }
                              }),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Phần ghi chú + nút submit (FIXED ở bottom)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outlineVariant)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}