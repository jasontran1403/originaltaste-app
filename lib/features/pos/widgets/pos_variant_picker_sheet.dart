// lib/features/pos/widgets/pos_variant_picker_sheet.dart
//
// CẬP NHẬT:
//  - Addon ingredients giờ cũng có field "Định lượng mặc định" (stockDeductPerUnit)
//  - Map<int, TextEditingController> _deductCtrls quản lý input cho cả variant và addon
//  - Khi tạo AddonGroupDraft, truyền ingredientDeductMap

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/pos/pos_draft_models.dart';
import '_pos_form_helpers.dart';

class PosVariantPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> ingredients;
  final bool isDark;
  final bool isAddon;
  final VariantGroupDraft? existing;

  const PosVariantPickerSheet({
    super.key,
    required this.ingredients,
    required this.isDark,
    required this.isAddon,
    this.existing,
  });

  static Future<VariantGroupDraft?> show(
      BuildContext context, {
        required List<Map<String, dynamic>> ingredients,
        required bool isDark,
        required bool isAddon,
        VariantGroupDraft? existing,
      }) async {
    return showModalBottomSheet<VariantGroupDraft>(
      context:            context,
      isScrollControlled: true,
      useSafeArea:        true,
      backgroundColor:    Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => PosVariantPickerSheet(
        ingredients: ingredients,
        isDark:      isDark,
        isAddon:     isAddon,
        existing:    existing,
      ),
    );
  }

  @override
  State<PosVariantPickerSheet> createState() => _PosVariantPickerSheetState();
}

class _PosVariantPickerSheetState extends State<PosVariantPickerSheet> {
  final _nameCtrl   = TextEditingController();
  int  _minSelect   = 1;
  int  _maxSelect   = 1;
  bool _allowRepeat = false;

  final Map<int, int>    _qtyMap    = {};  // ingredientId → qty (variant count)
  final Map<int, TextEditingController> _deductCtrls = {}; // ingredientId → deduct ctrl

  int get _totalSelected => _qtyMap.values.fold(0, (s, q) => s + q);
  Set<int> get _selectedIds =>
      _qtyMap.entries.where((e) => e.value > 0).map((e) => e.key).toSet();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _minSelect     = e.minSelect.toInt();
      _maxSelect     = e.maxSelect.toInt();
      _allowRepeat   = e.allowRepeat;
      for (final id in e.ingredientIds) {
        _qtyMap[id] = (e.ingredientQuantities?[id] ?? 1).toInt();
        // Load deduct từ existing nếu có
        final existing_deduct = e.ingredientDeductMap?[id] ?? 1.0;
        _deductCtrls[id] = TextEditingController(
          text: _formatDeduct(existing_deduct),
        );
      }
    } else {
      _nameCtrl.text = widget.isAddon ? 'Món thêm' : 'Nhóm 1';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _deductCtrls.values) c.dispose();
    super.dispose();
  }

  String _formatDeduct(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(4)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  List<Map<String, dynamic>> get _allIngredients {
    if (widget.isAddon) {
      return widget.ingredients
          .where((i) => ((i['addonPrice'] as num?) ?? 0) > 0)
          .toList();
    }
    return widget.ingredients;
  }

  void _setQty(int id, int delta) {
    setState(() {
      final next = ((_qtyMap[id] ?? 0) + delta).clamp(0, 99);
      if (next == 0) {
        _qtyMap.remove(id);
        _deductCtrls[id]?.dispose();
        _deductCtrls.remove(id);
      } else {
        _qtyMap[id] = next;
        _deductCtrls.putIfAbsent(
          id, () => TextEditingController(text: '1'),
        );
      }
    });
  }

  void _autoFill() {
    final total = _totalSelected;
    if (total == 0) return;
    setState(() {
      _minSelect = total;
      _maxSelect = total;
    });
  }

  Future<void> _openIngredientPicker() async {
    final chosen = await showModalBottomSheet<Set<int>>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (_) => _IngredientPickerDialog(
        allIngredients: _allIngredients,
        selectedIds:    Set.from(_selectedIds),
        isDark:         widget.isDark,
        isAddon:        widget.isAddon,
      ),
    );
    if (chosen == null) return;
    setState(() {
      // Thêm mới
      for (final id in chosen) {
        _qtyMap[id] ??= 1;
        if (!_deductCtrls.containsKey(id)) {
          // Lấy default từ ingredient data nếu có
          final ing = _allIngredients.firstWhere(
                (i) => i['id'] == id,
            orElse: () => {},
          );
          final defaultDeduct = (ing['stockDeductPerUnit'] as num?)?.toDouble() ?? 1.0;
          _deductCtrls[id] = TextEditingController(
            text: _formatDeduct(defaultDeduct),
          );
        }
      }
      // Xóa bỏ chọn
      final toRemove = _qtyMap.keys.where((id) => !chosen.contains(id)).toList();
      for (final id in toRemove) {
        _qtyMap.remove(id);
        _deductCtrls[id]?.dispose();
        _deductCtrls.remove(id);
      }
    });
  }

  void _confirm() {
    if (_nameCtrl.text.trim().isEmpty) {
      PosFormHelpers.showError(context, 'Vui lòng nhập tên nhóm');
      return;
    }
    if (_selectedIds.isEmpty) {
      PosFormHelpers.showError(context, 'Vui lòng thêm ít nhất 1 nguyên liệu');
      return;
    }

    // Build deductMap
    final Map<int, double> deductMap = {};
    for (final id in _selectedIds) {
      final raw = double.tryParse(_deductCtrls[id]?.text.trim() ?? '');
      deductMap[id] = (raw != null && raw > 0) ? raw : 1.0;
    }

    Navigator.pop(context, VariantGroupDraft(
      name:          _nameCtrl.text.trim(),
      minSelect:     widget.isAddon ? 0 : _minSelect,
      maxSelect:     widget.isAddon ? _totalSelected : _maxSelect,
      allowRepeat:   _allowRepeat,
      ingredientIds: _selectedIds.toList(),
      ingredientQuantities: Map.fromEntries(
        widget.isAddon
            ? _selectedIds.map((id) => MapEntry(id, 1))
            : _qtyMap.entries.where((e) => e.value > 0),
      ),
      ingredientDeductMap: deductMap,     // ← TRUYỀN CHO CẢ ADDON
      existingId: widget.existing?.existingId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark      = widget.isDark;
    final cs          = Theme.of(context).colorScheme;
    final surface     = posSurface(isDark);
    final bottom      = MediaQuery.of(context).viewInsets.bottom
        + MediaQuery.of(context).padding.bottom + 16;
    final accentColor = widget.isAddon
        ? const Color(0xFF8B5CF6)
        : const Color(0xFFFF9C00);
    final label = widget.isAddon ? 'Addon' : 'Variant';

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PosFormHelpers.handle(isDark),

          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.isAddon
                    ? Icons.shopping_cart_outlined
                    : Icons.tune_rounded,
                size: 17, color: accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Text('Cấu hình $label',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: posTxtPri(isDark))),
          ]),
          const SizedBox(height: 18),

          Flexible(child: SingleChildScrollView(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Tên nhóm
              PosFormField(
                controller: _nameCtrl, isDark: isDark,
                label: 'Tên nhóm *',
                hint: widget.isAddon ? 'VD: Thêm sốt' : 'VD: Chọn loại xúc xích',
              ),
              const SizedBox(height: 16),

              // Min/Max (chỉ variant)
              if (!widget.isAddon) ...[
                Row(children: [
                  Expanded(child: PosNumberField(
                    label: 'Chọn tối thiểu', value: _minSelect,
                    isDark: isDark, min: 0, max: 100,
                    onChanged: (v) => setState(() {
                      _minSelect = v;
                      if (_maxSelect < v) _maxSelect = v;
                    }),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: PosNumberField(
                    label: 'Chọn tối đa', value: _maxSelect,
                    isDark: isDark, min: 1, max: 100,
                    onChanged: (v) => setState(() {
                      _maxSelect = v;
                      if (_minSelect > v) _minSelect = v;
                    }),
                  )),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  _QuickChip(label: 'Chọn 1', isDark: isDark,
                      selected: _minSelect == 1 && _maxSelect == 1,
                      onTap: () => setState(() { _minSelect = 1; _maxSelect = 1; })),
                  _QuickChip(label: 'Chọn 2', isDark: isDark,
                      selected: _minSelect == 2 && _maxSelect == 2,
                      onTap: () => setState(() { _minSelect = 2; _maxSelect = 2; })),
                  _QuickChip(label: 'Chọn 3', isDark: isDark,
                      selected: _minSelect == 3 && _maxSelect == 3,
                      onTap: () => setState(() { _minSelect = 3; _maxSelect = 3; })),
                  _QuickChip(label: 'Tùy chọn (0–3)', isDark: isDark,
                      selected: _minSelect == 0 && _maxSelect == 3,
                      onTap: () => setState(() { _minSelect = 0; _maxSelect = 3; })),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: posBg(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: posDivider(isDark)),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cho phép chọn lặp cùng nguyên liệu',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: posTxtPri(isDark))),
                          Text('VD: Combo 3 Cheddar → chọn Cheddar 3 lần',
                              style: TextStyle(fontSize: 11,
                                  color: posTxtSec(isDark))),
                        ])),
                    Switch.adaptive(
                      value: _allowRepeat,
                      activeColor: cs.primary,
                      onChanged: (v) => setState(() => _allowRepeat = v),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Danh sách nguyên liệu + định lượng mặc định
              _SelectedIngredientSection(
                allIngredients:  _allIngredients,
                qtyMap:          _qtyMap,
                deductCtrls:     _deductCtrls,
                totalSelected:   _totalSelected,
                minSelect:       _minSelect,
                maxSelect:       _maxSelect,
                isDark:          isDark,
                isAddon:         widget.isAddon,
                accentColor:     accentColor,
                onQtyChanged:    _setQty,
                onAutoFill:      _autoFill,
                onAddIngredient: _openIngredientPicker,
              ),
              const SizedBox(height: 20),
            ],
          ))),

          PosFormHelpers.saveButton(
              label: 'Xác nhận', saving: false, onTap: _confirm),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// _SelectedIngredientSection — hiển thị cả addon với deduct input
// ══════════════════════════════════════════════════════════════════

class _SelectedIngredientSection extends StatelessWidget {
  final List<Map<String, dynamic>> allIngredients;
  final Map<int, int>              qtyMap;
  final Map<int, TextEditingController> deductCtrls;
  final int   totalSelected, minSelect, maxSelect;
  final bool  isDark, isAddon;
  final Color accentColor;
  final void Function(int id, int delta) onQtyChanged;
  final VoidCallback onAutoFill;
  final VoidCallback onAddIngredient;

  const _SelectedIngredientSection({
    required this.allIngredients,
    required this.qtyMap,
    required this.deductCtrls,
    required this.totalSelected,
    required this.minSelect,
    required this.maxSelect,
    required this.isDark,
    required this.isAddon,
    required this.accentColor,
    required this.onQtyChanged,
    required this.onAutoFill,
    required this.onAddIngredient,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = allIngredients
        .where((i) => (qtyMap[i['id'] as int? ?? 0] ?? 0) > 0)
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header row
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cs.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Icon(Icons.category_rounded, size: 12, color: cs.error),
            const SizedBox(width: 4),
            Text(
              isAddon ? 'Món thêm *' : 'Nguyên liệu *',
              style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700, color: cs.error),
            ),
          ]),
        ),
        const Spacer(),
        if (!isAddon && totalSelected > 0) ...[
          GestureDetector(
            onTap: onAutoFill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_fix_high_rounded, size: 12, color: accentColor),
                const SizedBox(width: 4),
                Text('Auto-fill min/max',
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w600, color: accentColor)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
        ],
        GestureDetector(
          onTap: onAddIngredient,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              const Text('Thêm',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),

      // Info hint
      if (selected.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 12,
                color: accentColor.withOpacity(0.7)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Định lượng mặc định = lượng trừ kho mỗi lần chọn 1 unit',
                style: TextStyle(fontSize: 11,
                    color: accentColor.withOpacity(0.7)),
              ),
            ),
          ]),
        ),

      if (selected.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: posBg(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: posDivider(isDark)),
          ),
          child: Row(children: [
            Icon(Icons.touch_app_rounded, size: 14, color: posTxtSec(isDark)),
            const SizedBox(width: 8),
            Text('Nhấn "Thêm" để chọn ${isAddon ? "món thêm" : "nguyên liệu"}',
                style: TextStyle(fontSize: 12, color: posTxtSec(isDark))),
          ]),
        )
      else
        Container(
          decoration: BoxDecoration(
            color: posBg(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: posDivider(isDark)),
          ),
          child: Column(
            children: selected.asMap().entries.map((entry) {
              final i      = entry.key;
              final ing    = entry.value;
              final id     = ing['id'] as int? ?? 0;
              final qty    = qtyMap[id] ?? 0;
              final isLast = i == selected.length - 1;
              final addonPrice =
                  (ing['addonPrice'] as num?)?.toDouble() ?? 0.0;

              return Column(children: [
                _IngredientRow(
                  ingredient:  ing,
                  qty:         qty,
                  isDark:      isDark,
                  isAddon:     isAddon,
                  addonPrice:  addonPrice,
                  accentColor: accentColor,
                  deductCtrl:  deductCtrls[id],
                  onMinus: () => onQtyChanged(id, -1),
                  onPlus:  () => onQtyChanged(id,  1),
                ),
                if (!isLast)
                  Divider(height: 1,
                      color: posDivider(isDark).withOpacity(0.6),
                      indent: 52),
              ]);
            }).toList(),
          ),
        ),

      // Footer tổng
      if (totalSelected > 0) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 13, color: accentColor),
            const SizedBox(width: 6),
            Text(
              isAddon
                  ? 'Tổng: $totalSelected món thêm'
                  : 'Tổng: $totalSelected NL  ·  min/max: $minSelect/$maxSelect',
              style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: accentColor),
            ),
          ]),
        ),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// _IngredientRow — có deduct input cho CẢ variant VÀ addon
// ══════════════════════════════════════════════════════════════════

class _IngredientRow extends StatelessWidget {
  final Map<String, dynamic>   ingredient;
  final int                    qty;
  final bool                   isDark, isAddon;
  final double                 addonPrice;
  final Color                  accentColor;
  final TextEditingController? deductCtrl;
  final VoidCallback           onMinus, onPlus;

  const _IngredientRow({
    required this.ingredient,
    required this.qty,
    required this.isDark,
    required this.isAddon,
    required this.addonPrice,
    required this.accentColor,
    required this.onMinus,
    required this.onPlus,
    this.deductCtrl,
  });

  String _fmtMoney(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final name = ingredient['name'] as String? ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: accentColor.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Tên + giá addon
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: accentColor)),
                if (isAddon && addonPrice > 0)
                  Text('+${_fmtMoney(addonPrice)}đ',
                      style: TextStyle(fontSize: 11,
                          color: accentColor.withOpacity(0.7))),
              ],
            )),

            // Stepper qty (chỉ variant)
            if (!isAddon)
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: onMinus,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.remove, size: 14, color: accentColor),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('$qty',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700, color: accentColor)),
                ),
                GestureDetector(
                  onTap: onPlus,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
              ]),
          ]),

          // ── Định lượng mặc định (cho CẢ variant VÀ addon) ──────────────
          if (deductCtrl != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.scale_outlined, size: 12,
                  color: accentColor.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text(
                'Định lượng mặc định / unit:',
                style: TextStyle(fontSize: 11,
                    color: accentColor.withOpacity(0.8)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                height: 32,
                child: TextField(
                  controller: deductCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                  decoration: InputDecoration(
                    isDense:      true,
                    filled:       true,
                    fillColor:    accentColor.withOpacity(0.06),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: accentColor.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: accentColor.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: accentColor, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(VD: 0.2 = 200g)',
                style: TextStyle(fontSize: 10,
                    color: accentColor.withOpacity(0.5)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// QuickChip + IngredientPickerDialog (giữ nguyên code cũ)
// ═════════════════════════════════════════════════════════════════

class _QuickChip extends StatelessWidget {
  final String label; final bool selected, isDark; final VoidCallback onTap;
  const _QuickChip({required this.label, required this.selected,
    required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : posBg(isDark),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? cs.primary : posDivider(isDark)),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : posTxtSec(isDark))),
      ),
    );
  }
}

class _IngredientPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allIngredients;
  final Set<int> selectedIds;
  final bool isDark, isAddon;
  const _IngredientPickerDialog({
    required this.allIngredients, required this.selectedIds,
    required this.isDark, required this.isAddon,
  });
  @override State<_IngredientPickerDialog> createState() =>
      _IngredientPickerDialogState();
}

class _IngredientPickerDialogState extends State<_IngredientPickerDialog> {
  late final Set<int> _chosen;
  String _search = '';
  @override void initState() { super.initState(); _chosen = Set.from(widget.selectedIds); }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return widget.allIngredients;
    return widget.allIngredients
        .where((i) => (i['name'] as String)
        .toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  String _fmtMoney(double v) => v.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final isDark      = widget.isDark;
    final accentColor = widget.isAddon
        ? const Color(0xFF8B5CF6) : const Color(0xFFFF9C00);
    return Container(
      decoration: BoxDecoration(
        color: posSurface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PosFormHelpers.handle(isDark),
        Row(children: [
          Text(widget.isAddon ? 'Chọn món thêm' : 'Chọn nguyên liệu',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: posTxtPri(isDark))),
          const Spacer(),
          if (_chosen.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: accentColor, borderRadius: BorderRadius.circular(20)),
              child: Text('${_chosen.length} đã chọn',
                  style: const TextStyle(fontSize: 11,
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 12),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: posBg(isDark), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: posDivider(isDark)),
          ),
          child: TextField(
            autofocus: true,
            style: TextStyle(fontSize: 13, color: posTxtPri(isDark)),
            decoration: InputDecoration(
              hintText: 'Tìm nguyên liệu...',
              hintStyle: TextStyle(fontSize: 13, color: posTxtSec(isDark)),
              prefixIcon: Icon(Icons.search_rounded, size: 16, color: posTxtSec(isDark)),
              border: InputBorder.none, isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 8),
        Flexible(child: _filtered.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(20),
            child: Text('Không tìm thấy',
                style: TextStyle(fontSize: 13, color: posTxtSec(isDark)))))
            : ListView.separated(
          shrinkWrap: true,
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => Divider(
              height: 1, color: posDivider(isDark).withOpacity(0.5)),
          itemBuilder: (_, i) {
            final ing       = _filtered[i];
            final id        = ing['id'] as int? ?? 0;
            final isSel     = _chosen.contains(id);
            final addonPrice = (ing['addonPrice'] as num?)?.toDouble() ?? 0.0;
            return GestureDetector(
              onTap: () => setState(() {
                if (isSel) _chosen.remove(id); else _chosen.add(id);
              }),
              child: Container(
                color: isSel ? accentColor.withOpacity(0.06) : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: isSel ? accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: isSel ? accentColor : posDivider(isDark),
                          width: 1.5),
                    ),
                    child: isSel
                        ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(ing['name'] as String? ?? '',
                      style: TextStyle(fontSize: 13,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                          color: isSel ? accentColor : posTxtPri(isDark)))),
                  if (widget.isAddon && addonPrice > 0)
                    Text('+${_fmtMoney(addonPrice)}đ',
                        style: TextStyle(fontSize: 12, color: posTxtSec(isDark))),
                ]),
              ),
            );
          },
        )),
        const SizedBox(height: 12),
        PosFormHelpers.saveButton(
          label: 'Xác nhận (${_chosen.length})', saving: false,
          onTap: () => Navigator.pop(context, _chosen),
        ),
        const SizedBox(height: 4),
      ]),
    );
  }
}