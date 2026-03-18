// lib/features/management/widgets/product_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/management_models.dart';
import '../../../shared/widgets/image_picker_field.dart';
import '../../../shared/widgets/management_shared_widgets.dart';
import '../controller/product_controller.dart';

class ProductFormSheet extends ConsumerStatefulWidget {
  final MgmtProductModel? product;
  const ProductFormSheet({super.key, this.product});

  static Future<bool> show(BuildContext context,
      {MgmtProductModel? product}) async {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isDismissible: true, // Cho phép dismiss bằng click outside
      builder: (_) => Padding(
      // Cách top 30px trên mobile, 20px trên tablet/desktop
        padding: EdgeInsets.only(top: isMobile ? 100 : 20),
        child: ProductFormSheet(product: product),
      ),
    );
    return result == true;
  }

  @override
  ConsumerState<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<ProductFormSheet> {
  late final ProductFormNotifier _n;

  @override
  void initState() {
    super.initState();
    _n = ref.read(productFormProvider(widget.product).notifier);
  }

  void _rebuild() => setState(() {});

  Map<int, String> get _tierErrors => _n.validateTiers();

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(productFormProvider(widget.product));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        60;
    final isEdit = widget.product != null;
    final onBg =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final fillBg = isDark
        ? AppColors.darkBg.withOpacity(0.5)
        : AppColors.lightBg.withOpacity(0.6);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _n.attachListeners(_rebuild));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // Padding nội bộ: top nhỏ hơn vì đã có padding ngoài ở show()
        padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 20),
        child: Form(
          key: _n.formKey,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(), // Tránh overscroll mạnh
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle bar (kéo xuống đóng)
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: secondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_outlined : Icons.add_rounded,
                      size: 18,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: onBg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 1. Ảnh ──────────────────────────────────────────
              ImagePickerField(
                label: 'Ảnh sản phẩm *',
                imageUrl: s.imageUrl,
                isUploading: s.isUploading,
                uploadError: s.uploadError,
                onPick: _n.uploadImage,
                onClear: _n.clearImage,
                height: 160,
              ),
              // Hiển thị lỗi ảnh ngay dưới field
              if (!s.hasImage && s.error == 'Vui lòng chọn ảnh sản phẩm') ...[
                const SizedBox(height: 6),
                Row(children: [
                  const SizedBox(width: 4),
                  Icon(Icons.error_outline, size: 13, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text('Vui lòng chọn ảnh sản phẩm',
                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                ]),
              ],
              const SizedBox(height: 16),

              // ── 2. Tên ──────────────────────────────────────────
              MgmtTextField(
                controller: _n.nameCtrl,
                label: 'Tên sản phẩm *',
                hint: 'VD: Cà phê sữa đá...',
                prefixIcon: Icons.storefront_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tên';
                  if (v.trim().length < 2) return 'Tên quá ngắn';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── 3. Giá gốc ──────────────────────────────────────
              MgmtTextField(
                controller: _n.priceCtrl,
                label: 'Giá gốc (VNĐ) *',
                hint: 'VD: 35000',
                prefixIcon: Icons.payments_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập giá';
                  if (double.tryParse(
                          v.replaceAll(',', '').replaceAll('.', '')) ==
                      null) return 'Giá không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── 4. Đơn vị + VAT (2 cột) ─────────────────────────
              Row(children: [
                Expanded(
                  child: _DropdownField<int>(
                    label: 'Thuế VAT',
                    value: s.vatRate,
                    icon: Icons.receipt_long_outlined,
                    items: _n.vatOptions
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text('$r%')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _n.setVatRate(v);
                    },
                    isDark: isDark,
                    primary: primary,
                    secondary: secondary,
                    border: border,
                    fillBg: fillBg,
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // ── 5. Danh mục ──────────────────────────────────────
              s.isLoadingData
                  ? _LoadingField(
                      label: 'Danh mục',
                      secondary: secondary,
                      border: border,
                      fillBg: fillBg)
                  : _DropdownField<int?>(
                      label: 'Danh mục',
                      value: s.categoryId,
                      icon: Icons.category_outlined,
                      hint: 'Không có danh mục',
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Không có danh mục',
                                style: TextStyle(fontSize: 13))),
                        ...s.categories.map((c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.name,
                                style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (id) {
                        final name = s.categories
                            .where((c) => c.id == id)
                            .map((c) => c.name)
                            .firstOrNull;
                        _n.setCategory(id, name: name);
                      },
                      isDark: isDark,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      fillBg: fillBg,
                    ),
              const SizedBox(height: 12),

              // ── 6. Nguyên liệu ───────────────────────────────────
              s.isLoadingData
                  ? _LoadingField(
                      label: 'Nguyên liệu',
                      secondary: secondary,
                      border: border,
                      fillBg: fillBg)
                  : _DropdownField<int?>(
                      label: 'Nguyên liệu *',
                      value: s.ingredientId,
                      icon: Icons.science_outlined,
                      hint: 'Chọn nguyên liệu chính',
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Chọn nguyên liệu...',
                                style: TextStyle(fontSize: 13))),
                        ...s.ingredients.map((ing) => DropdownMenuItem<int?>(
                            value: ing.id,
                            child: Text(
                              '${ing.name}  (${ing.stockQuantity.toStringAsFixed(1)} ${ing.unit})',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ))),
                      ],
                      onChanged: _n.setIngredient,
                      isDark: isDark,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      fillBg: fillBg,
                    ),
              const SizedBox(height: 12),

              // ── 7. Mô tả ─────────────────────────────────────────
              MgmtTextField(
                controller: _n.descCtrl,
                label: 'Mô tả',
                hint: 'Mô tả ngắn về sản phẩm...',
                prefixIcon: Icons.notes_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              // ── 8. Trạng thái bán ────────────────────────────────
              _AvailableToggle(
                value: s.isAvailable,
                onChanged: _n.setAvailable,
                isDark: isDark,
                primary: primary,
                secondary: secondary,
                border: border,
                fillBg: fillBg,
              ),
              const SizedBox(height: 16),

              // ── 9. Khung giá sỉ ──────────────────────────────────
              _TierSection(
                notifier: _n,
                tierErrors: _tierErrors,
                onRebuild: _rebuild,
                isDark: isDark,
                primary: primary,
                secondary: secondary,
                border: border,
                fillBg: fillBg,
                onBg: onBg,
              ),

              // ── Error ────────────────────────────────────────────
              if (s.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(s.error!,
                            style: TextStyle(
                                fontSize: 12, color: AppColors.error))),
                  ]),
                ),
              ],
              const SizedBox(height: 20),

              // ── Buttons ──────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        s.isSaving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: border),
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (s.isSaving || s.isUploading || _n.hasTierErrors)
                        ? null
                        : () async {
                            final result = await _n.save();
                            if (!context.mounted) return;
                            if (result != null) {
                              showSuccessSnack(
                                  context,
                                  isEdit
                                      ? 'Đã cập nhật sản phẩm'
                                      : 'Đã thêm sản phẩm');
                              Navigator.pop(context, true);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: primary.withOpacity(0.45),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: s.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : s.isUploading
                            ? const Text('Đang upload...',
                                style: TextStyle(fontWeight: FontWeight.w700))
                            : Text(isEdit ? 'Lưu thay đổi' : 'Thêm sản phẩm',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TIER SECTION
// ══════════════════════════════════════════════════════════════════

class _TierSection extends StatelessWidget {
  final ProductFormNotifier notifier;
  final Map<int, String> tierErrors;
  final VoidCallback onRebuild;
  final bool isDark;
  final Color primary, secondary, border, fillBg, onBg;

  const _TierSection({
    required this.notifier,
    required this.tierErrors,
    required this.onRebuild,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fillBg,
    required this.onBg,
  });

  @override
  Widget build(BuildContext context) {
    final tiers = notifier.tiers;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Row(children: [
        Icon(Icons.layers_outlined, size: 16, color: primary),
        const SizedBox(width: 6),
        Text('Khung giá sỉ',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: onBg)),
        const Spacer(),
        GestureDetector(
          onTap: () => notifier.addTier(onRebuild),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 14, color: primary),
              const SizedBox(width: 4),
              Text('Thêm khung',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),

      if (tiers.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: secondary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: secondary.withOpacity(0.15)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline,
                size: 15, color: secondary.withOpacity(0.5)),
            const SizedBox(width: 8),
            Text('Không có khung giá — dùng giá gốc cho tất cả đơn',
                style: TextStyle(fontSize: 12, color: secondary)),
          ]),
        )
      else ...[
        // Column header
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const SizedBox(width: 72),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: Text('Từ (SL)',
                    style: TextStyle(fontSize: 11, color: secondary))),
            const SizedBox(width: 6),
            Expanded(
                flex: 2,
                child: Text('Đến (SL)',
                    style: TextStyle(fontSize: 11, color: secondary))),
            const SizedBox(width: 6),
            Expanded(
                flex: 2,
                child: Text('Giá (đ)',
                    style: TextStyle(fontSize: 11, color: secondary))),
            const SizedBox(width: 32),
          ]),
        ),

        ...List.generate(
            tiers.length,
            (i) => _TierRow(
                  tier: tiers[i],
                  index: i,
                  hasError: tierErrors.containsKey(i),
                  onRemove: () => notifier.removeTier(i, onRebuild),
                  isDark: isDark,
                  primary: primary,
                  secondary: secondary,
                  border: border,
                  fillBg: fillBg,
                )),

        Text('* "Đến" để trống = không giới hạn trên',
            style: TextStyle(fontSize: 11, color: secondary)),

        if (tierErrors.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text('Khung giá phải nối tiếp nhau',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error)),
                ]),
                ...tierErrors.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('• ${e.value}',
                          style:
                              TextStyle(fontSize: 11, color: AppColors.error)),
                    )),
              ],
            ),
          ),
        ],
      ],
    ]);
  }
}

class _TierRow extends StatelessWidget {
  final TierFormItem tier;
  final int index;
  final bool hasError;
  final VoidCallback onRemove;
  final bool isDark;
  final Color primary, secondary, border, fillBg;

  const _TierRow({
    required this.tier,
    required this.index,
    required this.hasError,
    required this.onRemove,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fillBg,
  });

  InputDecoration _deco(String hint, {bool locked = false}) {
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.error.withOpacity(0.8)),
    );
    final normalBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:
          BorderSide(color: locked ? secondary.withOpacity(0.2) : border),
    );
    final b = hasError ? errorBorder : normalBorder;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: secondary.withOpacity(0.5)),
      isDense: true,
      isCollapsed: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      filled: locked,
      fillColor: locked ? secondary.withOpacity(0.06) : null,
      border: b,
      enabledBorder: b,
      focusedBorder: hasError
          ? errorBorder
          : OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primary, width: 1.5)),
      disabledBorder: b,
      suffixIcon: locked
          ? Icon(Icons.lock_outline,
              size: 12, color: secondary.withOpacity(0.4))
          : null,
      suffixIconConstraints: const BoxConstraints(minWidth: 24, maxWidth: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Badge
        Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: hasError
                ? AppColors.error.withOpacity(0.08)
                : primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: hasError
                    ? AppColors.error.withOpacity(0.35)
                    : primary.withOpacity(0.20)),
          ),
          child: Text('Khung ${index + 1}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: hasError ? AppColors.error : primary)),
        ),
        const SizedBox(width: 6),

        // Từ (read-only)
        Expanded(
          flex: 2,
          child: TextField(
            controller: tier.minQtyCtrl,
            readOnly: true,
            enableInteractiveSelection: false,
            style: TextStyle(fontSize: 13, color: secondary.withOpacity(0.65)),
            decoration: _deco('0', locked: true),
          ),
        ),
        const SizedBox(width: 6),

        // Đến
        Expanded(
          flex: 2,
          child: TextField(
            controller: tier.maxQtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(fontSize: 13),
            decoration: _deco('∞'),
          ),
        ),
        const SizedBox(width: 6),

        // Giá
        Expanded(
          flex: 2,
          child: TextField(
            controller: tier.priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 13),
            decoration: _deco('Giá'),
          ),
        ),
        const SizedBox(width: 6),

        // Xóa
        GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.close, size: 15, color: AppColors.error),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SHARED SUB-WIDGETS
// ══════════════════════════════════════════════════════════════════

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final IconData icon;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isDark;
  final Color primary, secondary, border, fillBg;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    required this.items,
    required this.onChanged,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fillBg,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    // Guard: nếu value không tồn tại trong items thì dùng null
    // (tránh crash khi data load async chưa xong)
    final safeValue = items.any((item) => item.value == value) ? value : null;

    return DropdownButtonFormField<T>(
      value: safeValue,
      hint: hint != null
          ? Text(hint!,
              style: TextStyle(color: secondary.withOpacity(0.6), fontSize: 13))
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: secondary),
        prefixIcon: Icon(icon, size: 18, color: secondary),
        filled: true,
        fillColor: fillBg,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primary, width: 1.5)),
      ),
      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
      style: TextStyle(fontSize: 14, color: textColor),
      isExpanded: true,
      items: items,
      onChanged: onChanged,
    );
  }
}

class _LoadingField extends StatelessWidget {
  final String label;
  final Color secondary, border, fillBg;
  const _LoadingField({
    required this.label,
    required this.secondary,
    required this.border,
    required this.fillBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: fillBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: secondary),
        ),
        const SizedBox(width: 10),
        Text('Đang tải $label...',
            style: TextStyle(fontSize: 13, color: secondary)),
      ]),
    );
  }
}

class _AvailableToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  final Color primary, secondary, border, fillBg;

  const _AvailableToggle({
    required this.value,
    required this.onChanged,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fillBg,
  });

  @override
  Widget build(BuildContext context) {
    final onBg =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fillBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(Icons.storefront_outlined, size: 18, color: secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đang bán',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: onBg)),
              Text(value ? 'Hiển thị trong menu' : 'Ẩn khỏi menu',
                  style: TextStyle(fontSize: 11, color: secondary)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: primary,
          activeTrackColor: primary.withOpacity(0.3),
        ),
      ]),
    );
  }
}
