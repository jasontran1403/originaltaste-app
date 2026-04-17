// lib/features/pos/widgets/pos_ingredient_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:originaltaste/services/pos_service.dart';
import '../../../services/admin_service.dart';
import '_pos_form_helpers.dart';

class PosIngredientFormSheet extends StatefulWidget {
  final Map<String, dynamic>? ingredient;
  final bool useAdminApi;
  const PosIngredientFormSheet({super.key, this.ingredient, this.useAdminApi = false});

  static Future<bool> show(BuildContext context,
      {Map<String, dynamic>? ingredient, bool useAdminApi = false}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosIngredientFormSheet(
          ingredient: ingredient, useAdminApi: useAdminApi),
    );
    return result == true;
  }

  @override
  State<PosIngredientFormSheet> createState() => _PosIngredientFormSheetState();
}

class _PosIngredientFormSheetState extends State<PosIngredientFormSheet> {
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _perPackCtrl    = TextEditingController();
  final _addonPriceCtrl = TextEditingController();

  // ── Unit ────────────────────────────────────────────────────
  // Gợi ý nhanh — user vẫn có thể tự nhập bất cứ gì
  static const _unitSuggestions = [
    'Cái', 'Cây', 'Miếng', 'Lát', 'Viên',
    'Kg', 'Gr', 'Lít', 'Ml',
    'Bịch', 'Túi', 'Hộp', 'Chai', 'Gói', 'Lọ',
  ];
  final _unitCtrl = TextEditingController();

  int  _typeIdx = 0;
  bool _saving  = false;

  bool get _isEdit => widget.ingredient != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final ing = widget.ingredient!;
      _nameCtrl.text       = ing['name'] as String? ?? '';
      _unitCtrl.text       = ing['unit'] as String? ?? 'Cái';   // ← đọc unit
      _perPackCtrl.text    = (ing['unitPerPack'] as num? ?? 1).toString();
      _addonPriceCtrl.text = (ing['addonPrice'] as num? ?? 0).toString();
      _typeIdx             = (ing['ingredientType'] as String? ?? 'MAIN') == 'SUB' ? 1 : 0;
    } else {
      _unitCtrl.text       = 'Cái';
      _perPackCtrl.text    = '1';
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

  // Sửa _save() trong _PosIngredientFormSheetState
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name':           _nameCtrl.text.trim(),
        'unit':           _unitCtrl.text.trim().isEmpty
            ? 'Sản phẩm' : _unitCtrl.text.trim(),
        'unitPerPack':    int.tryParse(_perPackCtrl.text) ?? 1,
        'ingredientType': _typeIdx == 0 ? 'MAIN' : 'SUB',
        'addonPrice':     double.tryParse(_addonPriceCtrl.text) ?? 0,
      };

      if (_isEdit) {
        final id = widget.ingredient!['id'] as int;
        if (widget.useAdminApi) {           // ← THÊM
          await AdminService.instance.updateIngredient(id, body);
        } else {
          await PosService.instance.updateIngredient(id, body);
        }
      } else {
        if (widget.useAdminApi) {           // ← THÊM
          await AdminService.instance.createIngredient(body);
        } else {
          await PosService.instance.createIngredient(body);
        }
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
                icon:  _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                label: _isEdit ? 'Chỉnh sửa nguyên liệu' : 'Thêm nguyên liệu',
              ),
              const SizedBox(height: 20),

              // ── Tên ──────────────────────────────────────────
              PosFormField(
                controller: _nameCtrl,
                label: 'Tên nguyên liệu *',
                hint: 'VD: Hotdog, Mozzarella...',
                isDark: isDark,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 14),

              // ── Đơn vị tính ───────────────────────────────────
              PosFormHelpers.sectionLabel('Đơn vị tính', isDark),
              _UnitInputField(
                controller: _unitCtrl,
                isDark: isDark,
                onChanged: (_) => setState(() {}),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                child: Text(
                  'VD: 1 bịch xúc xích = 5 Cây → đơn vị "Cây", số lẻ 5',
                  style: TextStyle(fontSize: 11, color: posTxtSec(isDark).withOpacity(0.7)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                child: Text(
                  'Đây là đơn vị dùng để đếm khi trừ kho. VD: 200gr thịt bò → đơn vị "Gr", định lượng 200.',
                  style: TextStyle(fontSize: 11, color: posTxtSec(isDark).withOpacity(0.7)),
                ),
              ),

              // ── Số lẻ / bịch ──────────────────────────────────
              PosFormField(
                controller: _perPackCtrl,
                label: '1 bịch/túi/kg = ? ${_unitCtrl.text.trim().isEmpty ? "đơn vị" : _unitCtrl.text.trim()} *',
                hint: '1',
                isDark: isDark,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return 'Nhập số ≥ 1';
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
                child: Text(
                  'VD: 1 bịch xúc xích = 5 cây → nhập 5\n'
                      '    1 Kg thịt bò = 1000 gr → nhập 1000',
                  style: TextStyle(fontSize: 11, color: posTxtSec(isDark).withOpacity(0.7)),
                ),
              ),

              // ── Loại nguyên liệu ──────────────────────────────
              PosFormHelpers.sectionLabel('Loại nguyên liệu', isDark),
              PosSegmentControl(
                options: const ['Chính', 'Phụ'],
                icons:   const [Icons.star_rounded, Icons.star_border_rounded],
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
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                suffixText: 'đ',
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0) return 'Nhập giá ≥ 0';
                  return null;
                },
              ),
              PosFormHelpers.infoBox('0 = không tính tiền thêm khi chọn nguyên liệu này', isDark),

              const SizedBox(height: 20),

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

class _UnitInputField extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _UnitInputField({
    required this.controller,
    required this.isDark,
    this.onChanged,
  });

  @override
  State<_UnitInputField> createState() => _UnitInputFieldState();
}

class _UnitInputFieldState extends State<_UnitInputField> {
  static const _options = [
    'Cái', 'Cây', 'Miếng', 'Lát', 'Viên',
    'Kg', 'Gr', 'Lít', 'Ml',
    'Bịch', 'Túi', 'Hộp', 'Chai', 'Gói', 'Lọ',
    'Khác...',
  ];

  bool _isCustom = false;

  @override
  void initState() {
    super.initState();
    // Nếu giá trị hiện tại không nằm trong list → mở chế độ tự nhập
    final val = widget.controller.text;
    _isCustom = val.isNotEmpty && !_options.contains(val) && val != 'Khác...';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = widget.isDark;

    if (_isCustom) {
      // Chế độ tự nhập — có nút quay lại dropdown
      return Row(children: [
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: posTxtPri(isDark)),
            decoration: InputDecoration(
              labelText: 'Nhập đơn vị *',
              hintText: 'VD: Muỗng, Tô, Phần...',
              filled: true,
              fillColor: posBg(isDark),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: posDivider(isDark))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: posDivider(isDark))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.5)),
              labelStyle: TextStyle(fontSize: 13, color: posTxtSec(isDark)),
              hintStyle:  TextStyle(fontSize: 13, color: posTxtSec(isDark).withOpacity(0.6)),
              suffixIcon: IconButton(
                icon: Icon(Icons.list_rounded, size: 18, color: cs.primary),
                tooltip: 'Chọn từ danh sách',
                onPressed: () => setState(() {
                  _isCustom = false;
                  widget.controller.text = _options.first;
                  widget.onChanged?.call(_options.first);
                }),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập đơn vị' : null,
            onChanged: widget.onChanged,
          ),
        ),
      ]);
    }

    // Chế độ dropdown
    final currentVal = _options.contains(widget.controller.text)
        ? widget.controller.text
        : _options.first;

    return DropdownButtonFormField<String>(
      value: currentVal,
      decoration: InputDecoration(
        labelText: 'Đơn vị tính *',
        filled: true,
        fillColor: posBg(isDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: posDivider(isDark))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: posDivider(isDark))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 1.5)),
        labelStyle: TextStyle(fontSize: 13, color: posTxtSec(isDark)),
      ),
      style: TextStyle(fontSize: 14, color: posTxtPri(isDark)),
      dropdownColor: posSurface(isDark),
      isExpanded: true,
      items: _options.map((u) => DropdownMenuItem(
        value: u,
        child: Text(
          u,
          style: TextStyle(
            fontSize: 14,
            color: u == 'Khác...' ? cs.primary : posTxtPri(isDark),
            fontWeight: u == 'Khác...' ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      )).toList(),
      onChanged: (v) {
        if (v == null) return;
        if (v == 'Khác...') {
          // Chuyển sang chế độ tự nhập, xóa text để user nhập mới
          setState(() {
            _isCustom = true;
            widget.controller.text = '';
          });
        } else {
          widget.controller.text = v;
          widget.onChanged?.call(v);
        }
      },
      validator: (_) => widget.controller.text.trim().isEmpty ? 'Vui lòng chọn đơn vị' : null,
    );
  }
}