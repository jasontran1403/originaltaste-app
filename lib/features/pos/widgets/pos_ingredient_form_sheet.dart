// lib/features/pos/widgets/pos_ingredient_form_sheet.dart
//
// Modal bottom sheet để tạo / chỉnh sửa Ingredient POS
// Fields: tên, đơn vị tính, số lẻ/bịch, loại (MAIN/SUB), giá addon

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:originaltaste/services/pos_service.dart';
import '_pos_form_helpers.dart';

class PosIngredientFormSheet extends StatefulWidget {
  /// null = create mode
  final Map<String, dynamic>? ingredient;

  const PosIngredientFormSheet({super.key, this.ingredient});

  static Future<bool> show(BuildContext context,
      {Map<String, dynamic>? ingredient}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosIngredientFormSheet(ingredient: ingredient),
    );
    return result == true;
  }

  @override
  State<PosIngredientFormSheet> createState() => _PosIngredientFormSheetState();
}

class _PosIngredientFormSheetState extends State<PosIngredientFormSheet> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _unitCtrl     = TextEditingController();
  final _perPackCtrl  = TextEditingController();
  final _addonPriceCtrl = TextEditingController();

  /// 0 = MAIN, 1 = SUB
  int  _typeIdx = 0;
  bool _saving  = false;

  bool get _isEdit => widget.ingredient != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final ing = widget.ingredient!;
      _nameCtrl.text       = ing['name'] as String? ?? '';
      _unitCtrl.text       = '';  // unit display only
      _perPackCtrl.text    = (ing['unitPerPack'] as num? ?? 1).toString();
      _addonPriceCtrl.text = (ing['addonPrice'] as num? ?? 0).toString();
      _typeIdx             = (ing['ingredientType'] as String? ?? 'MAIN') == 'SUB' ? 1 : 0;
    } else {
      _unitCtrl.text    = 'kg';
      _perPackCtrl.text = '1';
      _addonPriceCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _perPackCtrl.dispose();
    _addonPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final body = <String, dynamic>{
        'name':        _nameCtrl.text.trim(),
        // unit field not in old API body
        'unitPerPack': int.tryParse(_perPackCtrl.text) ?? 1,
        'ingredientType': _typeIdx == 0 ? 'MAIN' : 'SUB',
        'addonPrice': double.tryParse(_addonPriceCtrl.text) ?? 0,
      };

      if (_isEdit) {
        final id = widget.ingredient!['id'] as int;
        await PosService.instance.updateIngredient(id, body);
      } else {
        await PosService.instance.createIngredient(body);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        PosFormHelpers.showError(context, e);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final surface = posSurface(isDark);
    final bottom  = MediaQuery.of(context).viewInsets.bottom
        + MediaQuery.of(context).padding.bottom + 16;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PosFormHelpers.handle(isDark),
              PosFormHelpers.titleRow(
                isDark: isDark,
                icon: _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                label: _isEdit ? 'Chỉnh sửa nguyên liệu' : 'Thêm nguyên liệu',
              ),
              const SizedBox(height: 20),

              // ── Tên ──────────────────────────────────────────
              PosFormField(
                controller: _nameCtrl,
                label: 'Tên nguyên liệu *',
                hint: 'VD: Hotdog, Mozzarella...',
                isDark: isDark,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 14),

              // ── Đơn vị + Số lẻ / bịch ────────────────────────
              Row(children: [
                Expanded(child: PosFormField(
                  controller: _unitCtrl,
                  label: 'Đơn vị tính',
                  hint: 'kg, lọ, gói...',
                  isDark: isDark,
                )),
                const SizedBox(width: 12),
                Expanded(child: PosFormField(
                  controller: _perPackCtrl,
                  label: 'Số lẻ trong 1 bịch *',
                  hint: '1',
                  isDark: isDark,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return 'Nhập số ≥ 1';
                    return null;
                  },
                )),
              ]),

              // Helper text for perPack
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Text('VD: 1 bịch Cheddar = 5 lẻ → nhập 5',
                    style: TextStyle(fontSize: 11,
                        color: posTxtSec(isDark).withOpacity(0.7))),
              ),

              // ── Loại nguyên liệu ──────────────────────────────
              PosFormHelpers.sectionLabel('Loại nguyên liệu', isDark),
              PosSegmentControl(
                options: const ['Chính', 'Phụ'],
                icons: const [Icons.star_rounded, Icons.star_border_rounded],
                selected: _typeIdx,
                isDark: isDark,
                onChanged: (i) => setState(() => _typeIdx = i),
              ),
              const SizedBox(height: 14),

              // ── Giá Addon ─────────────────────────────────────
              PosFormHelpers.sectionLabel('Giá Addon (khi dùng trong nhóm thêm món)', isDark),
              PosFormField(
                controller: _addonPriceCtrl,
                label: 'Giá Addon',
                hint: '0',
                isDark: isDark,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: false),
                suffixText: 'đ',
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0) return 'Nhập giá ≥ 0';
                  return null;
                },
              ),
              PosFormHelpers.infoBox(
                  '0 = không tính tiền thêm khi chọn nguyên liệu này', isDark),

              const SizedBox(height: 20),

              // ── Save ──────────────────────────────────────────
              PosFormHelpers.saveButton(
                label: _isEdit ? 'Lưu thay đổi' : 'Lưu',
                saving: _saving,
                onTap: _save,
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }
}