// lib/features/pos/components/pos_customer_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:originaltaste/data/models/pos/pos_cart_model.dart';
import 'package:originaltaste/data/models/pos/pos_discount_model.dart';
import 'package:originaltaste/data/network/dio_client.dart';
import 'package:originaltaste/core/constants/api_constants.dart';

// ── Result trả về khi đóng sheet ─────────────────────────────────
class CustomerSheetResult {
  final PosCustomerInfo      customer;
  final CustomerDiscountInfo? discount;
  final int?                  discountItemProductId;

  const CustomerSheetResult({
    required this.customer,
    this.discount,
    this.discountItemProductId,
  });
}

// ── Model ─────────────────────────────────────────────────────────
class PosCustomerInfo {
  final String phone;
  final String name;
  final int?   id;

  const PosCustomerInfo({required this.phone, required this.name, this.id});

  static String normalizePhone(String raw) {
    String s = raw.replaceAll(RegExp(r'\s+'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('84') && s.length == 11) s = '0${s.substring(2)}';
    if (!s.startsWith('0') && s.length == 9)  s = '0$s';
    return s;
  }
}

// ── Entry point ───────────────────────────────────────────────────
Future<CustomerSheetResult?> showPosCustomerSheet(
    BuildContext context, {
      PosCustomerInfo? current,
      required List<CartItem> cartItems,
    }) {
  return showModalBottomSheet<CustomerSheetResult>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 40),
      child: _PosCustomerSheet(current: current, cartItems: cartItems),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
class _PosCustomerSheet extends StatefulWidget {
  final PosCustomerInfo? current;
  final List<CartItem>   cartItems;

  const _PosCustomerSheet({this.current, required this.cartItems});

  @override
  State<_PosCustomerSheet> createState() => _PosCustomerSheetState();
}

class _PosCustomerSheetState extends State<_PosCustomerSheet> {
  final _phoneCtrl = TextEditingController();
  final _nameCtrl  = TextEditingController();
  Timer? _debounce;

  // Trạng thái tìm kiếm
  bool             _isSearching   = false;
  bool             _searched      = false;   // đã search ít nhất 1 lần
  PosCustomerInfo? _foundCustomer;           // null = chưa tìm / không tìm thấy
  bool             _notFound      = false;   // true = đã search nhưng 0 kết quả

  // Trạng thái lưu
  bool             _isSaving      = false;
  PosCustomerInfo? _savedCustomer; // khách đã được lưu/chọn (ready to confirm)

  // Discount
  List<CustomerDiscountInfo> _discounts         = [];
  CustomerDiscountInfo?      _selectedDiscount;
  PosDiscountOption?         _selectedOption;
  int?                       _selectedItemProductId;
  bool                       _isLoadingDiscount = false;

  // ── Derived ───────────────────────────────────────────────────
  /// Khách đang "active" — hoặc từ tìm kiếm, hoặc vừa lưu
  PosCustomerInfo? get _activeCustomer => _savedCustomer ?? _foundCustomer;

  /// Có thể nhấn "Chọn khách"
  bool get _canConfirm => _activeCustomer != null;

  /// Có thể nhấn "Lưu" — chỉ khi chưa tìm thấy và phone + name hợp lệ
  bool get _canSave =>
      _foundCustomer == null &&
          _phoneCtrl.text.trim().length >= 9 &&
          _nameCtrl.text.trim().isNotEmpty &&
          !_isSaving;

  @override
  void initState() {
    super.initState();
    if (widget.current != null) {
      _phoneCtrl.text = widget.current!.phone;
      _nameCtrl.text  = widget.current!.name;
      _savedCustomer  = widget.current;
      if (widget.current!.id != null) _loadDiscount(widget.current!.id!);
    }
    _phoneCtrl.addListener(_onPhoneListener);
    _nameCtrl.addListener(_onNameListener);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _phoneCtrl.removeListener(_onPhoneListener);
    _nameCtrl.removeListener(_onNameListener);
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Phone changed → debounce search ──────────────────────────

  // Name changed -> rebuild de cap nhat _canSave
  void _onNameListener() => setState(() {});

  void _onPhoneListener() {
    final raw = _phoneCtrl.text;
    // Reset mọi state khi user thay đổi số
    if (_savedCustomer != null || _foundCustomer != null || _notFound) {
      setState(() {
        _savedCustomer = null;
        _foundCustomer = null;
        _notFound      = false;
        _searched      = false;
        _nameCtrl.text = '';
        _discounts             = [];
        _selectedDiscount      = null;
        _selectedOption        = null;
        _selectedItemProductId = null;
      });
    }

    _debounce?.cancel();
    final trimmed = raw.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.length < 9) {
      if (_searched) setState(() { _searched = false; _notFound = false; });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 600), () => _search(trimmed));
  }

  Future<void> _search(String raw) async {
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final normalized = PosCustomerInfo.normalizePhone(raw);
      final res = await DioClient.instance.get<List<dynamic>>(
        '${ApiConstants.posBase}/customers/search',
        queryParams: {'phone': normalized},
        fromData: (d) => d as List,
      );

      if (!mounted) return;
      final list = res.isSuccess ? (res.data ?? []) : [];

      // Tìm exact match theo phone normalize
      final exact = list.cast<Map<String, dynamic>>().where((e) {
        final p = e['phone'] as String? ?? '';
        return p == normalized;
      }).toList();

      if (exact.isNotEmpty) {
        final e = exact.first;
        final found = PosCustomerInfo(
          phone: e['phone'] as String,
          name:  e['name']  as String,
          id:    e['id']    as int?,
        );
        setState(() {
          _isSearching   = false;
          _searched      = true;
          _foundCustomer = found;
          _notFound      = false;
          _nameCtrl.text = found.name; // điền tên tự động (readonly)
        });
        if (found.id != null) _loadDiscount(found.id!);
      } else {
        setState(() {
          _isSearching   = false;
          _searched      = true;
          _foundCustomer = null;
          _notFound      = true;
          _nameCtrl.text = '';
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isSearching = false; _searched = true; _notFound = true; });
    }
  }

  // ── Load discount ─────────────────────────────────────────────
  Future<void> _loadDiscount(int customerId) async {
    setState(() => _isLoadingDiscount = true);
    try {
      final res = await DioClient.instance.get<List<CustomerDiscountInfo>>(
        '${ApiConstants.posBase}/discounts/customer/$customerId/active',
        fromData: (d) => (d as List)
            .map((e) => CustomerDiscountInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      if (mounted) setState(() {
        _isLoadingDiscount = false;
        _discounts = res.isSuccess ? (res.data ?? []) : [];
        if (_discounts.length == 1) {
          _selectedDiscount = _discounts.first;
          if (_selectedDiscount!.selectedOptionId != null) {
            _selectedOption = _selectedDiscount!.selectedOption;
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingDiscount = false);
    }
  }

  // ── Lưu khách mới ─────────────────────────────────────────────
  Future<void> _save() async {
    if (!_canSave) return;
    final phone = PosCustomerInfo.normalizePhone(_phoneCtrl.text.trim());
    final name  = _nameCtrl.text.trim();
    setState(() => _isSaving = true);
    try {
      final res = await DioClient.instance.post<Map<String, dynamic>>(
        '${ApiConstants.posBase}/customers',
        body: {'phone': phone, 'name': name},
        fromData: (d) => d as Map<String, dynamic>,
      );
      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        final saved = PosCustomerInfo(
          phone: res.data!['phone'] as String,
          name:  res.data!['name']  as String,
          id:    res.data!['id']    as int?,
        );
        // Sau khi lưu → đóng sheet luôn
        Navigator.pop(context, CustomerSheetResult(customer: saved));
      } else {
        _snack(res.message.isNotEmpty ? res.message : 'Lỗi lưu khách hàng',
            isError: true);
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        _snack('Lỗi: $e', isError: true);
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Confirm chọn khách ────────────────────────────────────────
  void _confirm() {
    if (!_canConfirm) return;
    Navigator.pop(context, CustomerSheetResult(
      customer: _activeCustomer!,
      discount: _selectedDiscount != null && _selectedOption != null
          ? _selectedDiscount : null,
      discountItemProductId: _selectedItemProductId,
    ));
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    const teal    = Color(0xFF0D9488);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bg      = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border  = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final txtSec  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final nameReadOnly = _foundCustomer != null; // tên readonly khi tìm thấy

    return Container(
      decoration: BoxDecoration(
        color:        surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Handle
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: txtSec.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          )),

          // Title
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_search_rounded, size: 18, color: teal),
            ),
            const SizedBox(width: 10),
            Text('Thông tin khách hàng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
          ]),
          const SizedBox(height: 20),

          // ── SĐT field ──────────────────────────────────────────
          TextFormField(
            controller:   _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]'))
            ],
            style: TextStyle(fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Số điện thoại *',
              hintText:  '0938 121 001',
              prefixIcon: const Icon(Icons.phone_rounded,
                  size: 18, color: teal),
              suffixIcon: _isSearching
                  ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: teal)))
                  : _foundCustomer != null
                  ? const Icon(Icons.check_circle_rounded,
                  color: teal, size: 20)
                  : null,
              filled:     true,
              fillColor:  bg,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _foundCustomer != null
                        ? teal.withOpacity(0.5) : border,
                    width: _foundCustomer != null ? 1.5 : 1,
                  )),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: teal, width: 1.5)),
              labelStyle: TextStyle(fontSize: 13, color: txtSec),
              hintStyle:  TextStyle(fontSize: 13,
                  color: txtSec.withOpacity(0.6)),
            ),
          ),
          const SizedBox(height: 6),

          // ── Status message dưới SĐT ────────────────────────────
          if (_searched && !_isSearching)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(children: [
                Icon(
                  _foundCustomer != null
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 13,
                  color: _foundCustomer != null ? teal : cs.error,
                ),
                const SizedBox(width: 5),
                Text(
                  _foundCustomer != null
                      ? 'Đã tìm thấy khách hàng'
                      : 'Không tìm thấy · Vui lòng tạo mới',
                  style: TextStyle(
                      fontSize: 11,
                      color: _foundCustomer != null ? teal : cs.error,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),

          // ── Tên field ──────────────────────────────────────────
          TextFormField(
            controller: _nameCtrl,
            readOnly:   nameReadOnly,
            style: TextStyle(
              fontSize: 14,
              color: nameReadOnly
                  ? (isDark ? Colors.white70 : const Color(0xFF334155))
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            decoration: InputDecoration(
              labelText: 'Tên khách hàng *',
              hintText:  nameReadOnly ? '' : 'Nguyễn Văn A',
              prefixIcon: Icon(Icons.person_rounded, size: 18,
                  color: nameReadOnly
                      ? txtSec.withOpacity(0.5)
                      : teal.withOpacity(0.7)),
              filled:     true,
              fillColor:  nameReadOnly
                  ? cs.onSurface.withOpacity(0.04) : bg,
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
                  borderSide: BorderSide(
                      color: nameReadOnly ? border : teal, width: 1.5)),
              labelStyle: TextStyle(fontSize: 13, color: txtSec),
              hintStyle:  TextStyle(fontSize: 13,
                  color: txtSec.withOpacity(0.6)),
            ),
          ),

          // ── Discount section ────────────────────────────────────
          if (_activeCustomer != null && _activeCustomer!.id != null) ...[
            const SizedBox(height: 16),
            Divider(color: border),
            const SizedBox(height: 10),
            if (_isLoadingDiscount)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: teal)),
                  const SizedBox(width: 10),
                  Text('Đang tải thông tin khuyến mãi...',
                      style: TextStyle(fontSize: 12, color: txtSec)),
                ]),
              )
            else if (_discounts.isNotEmpty)
              _DiscountSection(
                discounts:             _discounts,
                selected:              _selectedDiscount,
                selectedOption:        _selectedOption,
                selectedItemProductId: _selectedItemProductId,
                cartItems:             widget.cartItems,
                isDark:                isDark,
                cs:                    cs,
                teal:                  teal,
                border:                border,
                bg:                    bg,
                txtSec:                txtSec,
                onDiscountSelected: (d) => setState(() {
                  _selectedDiscount      = d;
                  _selectedOption        = d?.selectedOption;
                  _selectedItemProductId = null;
                }),
                onOptionSelected: (opt) => setState(() {
                  _selectedOption        = opt;
                  _selectedItemProductId = null;
                }),
                onItemSelected: (id) =>
                    setState(() => _selectedItemProductId = id),
              ),
          ],

          const SizedBox(height: 20),

          // ── Buttons ─────────────────────────────────────────────
          Row(children: [

            // Nút Lưu — chỉ hiện khi CHƯA tìm thấy
            if (_foundCustomer == null) ...[
              Expanded(child: SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _canSave ? _save : null,
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Lưu khách mới',
                      style: TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    disabledBackgroundColor:
                    teal.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )),
              const SizedBox(width: 10),
            ],

            // Nút Chọn khách — luôn hiển thị, disabled khi chưa có khách
            Expanded(child: SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _canConfirm ? _confirm : null,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Chọn khách',
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: _canConfirm
                      ? const Color(0xFF0284C7)
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )),
          ]),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }
}

// ── Discount sub-section ──────────────────────────────────────────
class _DiscountSection extends StatelessWidget {
  final List<CustomerDiscountInfo>  discounts;
  final CustomerDiscountInfo?       selected;
  final PosDiscountOption?          selectedOption;
  final int?                        selectedItemProductId;
  final List<CartItem>              cartItems;
  final bool                        isDark;
  final ColorScheme                 cs;
  final Color                       teal, border, bg, txtSec;
  final ValueChanged<CustomerDiscountInfo?> onDiscountSelected;
  final ValueChanged<PosDiscountOption?>    onOptionSelected;
  final ValueChanged<int?>                  onItemSelected;

  const _DiscountSection({
    required this.discounts,
    required this.selected,
    required this.selectedOption,
    required this.selectedItemProductId,
    required this.cartItems,
    required this.isDark,
    required this.cs,
    required this.teal,
    required this.border,
    required this.bg,
    required this.txtSec,
    required this.onDiscountSelected,
    required this.onOptionSelected,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final txtPri = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel(label: 'Chương trình khuyến mãi', color: txtSec),
      const SizedBox(height: 10),

      ...discounts.map((d) {
        final isSel = selected?.id == d.id;
        return GestureDetector(
          onTap: () => onDiscountSelected(isSel ? null : d),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin:   const EdgeInsets.only(bottom: 8),
            padding:  const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSel ? teal.withOpacity(0.08) : bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSel ? teal.withOpacity(0.4) : border,
                  width: isSel ? 1.5 : 1),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.local_offer_rounded, size: 15,
                        color: isSel ? teal : txtSec),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d.programName,
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSel ? teal : txtPri))),
                    if (d.exhausted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: cs.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text('Hết hạn mức',
                            style: TextStyle(fontSize: 10,
                                color: cs.error,
                                fontWeight: FontWeight.w700)),
                      )
                    else
                      Text('${_fmtK(d.budgetRemaining)} còn lại',
                          style: TextStyle(fontSize: 11,
                              color: isSel ? teal : txtSec)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Áp dụng: ${d.applyFrom} → ${d.applyTo}',
                      style: TextStyle(fontSize: 11, color: txtSec)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: d.maxDiscount > 0
                          ? (d.budgetUsed / d.maxDiscount).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 4,
                      backgroundColor: teal.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(
                          d.exhausted ? cs.error : teal),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Đã dùng ${_fmtK(d.budgetUsed)} / ${_fmtK(d.maxDiscount)}',
                    style: TextStyle(fontSize: 10, color: txtSec),
                  ),
                ]),
          ),
        );
      }),

      if (selected != null && !selected!.exhausted) ...[
        const SizedBox(height: 8),
        Text('Chọn loại giảm giá:',
            style: TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600, color: txtSec)),
        const SizedBox(height: 8),
        ...selected!.options.map((opt) {
          final isOptSel = selectedOption?.id == opt.id;
          return GestureDetector(
            onTap: () => onOptionSelected(isOptSel ? null : opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin:   const EdgeInsets.only(bottom: 6),
              padding:  const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isOptSel ? teal.withOpacity(0.08) : bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isOptSel ? teal.withOpacity(0.5) : border,
                    width: isOptSel ? 1.5 : 1),
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOptSel ? teal : Colors.transparent,
                    border: Border.all(
                        color: isOptSel
                            ? teal : txtSec.withOpacity(0.4),
                        width: 1.5),
                  ),
                  child: isOptSel
                      ? const Icon(Icons.check, size: 11,
                      color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(opt.displayLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: isOptSel ? teal : (isDark
                          ? Colors.white : const Color(0xFF0F172A)),
                      fontWeight: isOptSel
                          ? FontWeight.w600 : FontWeight.w400,
                    ))),
              ]),
            ),
          );
        }),

        if (selectedOption != null &&
            selectedOption!.discountType.isItemType &&
            cartItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Chọn món được giảm:',
              style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w600, color: txtSec)),
          const SizedBox(height: 8),
          ...{for (final c in cartItems) c.product.id: c}
              .values
              .map((c) {
            final isSel = selectedItemProductId == c.product.id;
            return GestureDetector(
              onTap: () => onItemSelected(isSel ? null : c.product.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin:   const EdgeInsets.only(bottom: 6),
                padding:  const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? teal.withOpacity(0.08) : bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSel ? teal.withOpacity(0.5) : border,
                      width: isSel ? 1.5 : 1),
                ),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSel ? teal : Colors.transparent,
                      border: Border.all(
                          color: isSel ? teal : txtSec.withOpacity(0.4),
                          width: 1.5),
                    ),
                    child: isSel
                        ? const Icon(Icons.check, size: 11,
                        color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.product.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSel ? teal : (isDark
                            ? Colors.white : const Color(0xFF0F172A)),
                        fontWeight: isSel
                            ? FontWeight.w600 : FontWeight.w400,
                      ))),
                  Text('${_fmtMoney(c.subtotal)}đ',
                      style: TextStyle(fontSize: 12, color: txtSec)),
                ]),
              ),
            );
          }),
        ],
      ],
    ]);
  }

  String _fmtK(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return '${k % 1 == 0 ? k.toInt() : k.toStringAsFixed(1)}k';
    }
    return v.toStringAsFixed(0);
  }

  String _fmtMoney(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ── Section label ─────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final Color  color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 3, height: 13,
      decoration: BoxDecoration(
          color: const Color(0xFF0D9488),
          borderRadius: BorderRadius.circular(2)),
    ),
    const SizedBox(width: 7),
    Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: color, letterSpacing: 0.3)),
  ]);
}