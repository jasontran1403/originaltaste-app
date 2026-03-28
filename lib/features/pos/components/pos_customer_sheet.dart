// lib/features/pos/components/pos_customer_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:originaltaste/data/models/pos/pos_cart_model.dart';
import 'package:originaltaste/data/models/pos/pos_discount_model.dart';
import 'package:originaltaste/data/network/dio_client.dart';
import 'package:originaltaste/core/constants/api_constants.dart';

// ── Models ────────────────────────────────────────────────────────

class CustomerSheetResult {
  final PosCustomerInfo       customer;
  final CustomerDiscountInfo? discount;
  final int?                  discountItemProductId;

  const CustomerSheetResult({
    required this.customer,
    this.discount,
    this.discountItemProductId,
  });
}

class PosCustomerInfo {
  final String  phone;
  final String  name;
  final int?    id;
  final String? dateOfBirth;
  final String? deliveryAddress;
  final int?    referredByCustomerId;
  final String? referredByName;
  final String? referredByPhone;

  const PosCustomerInfo({
    required this.phone,
    required this.name,
    this.id,
    this.dateOfBirth,
    this.deliveryAddress,
    this.referredByCustomerId,
    this.referredByName,
    this.referredByPhone,
  });

  static String normalizePhone(String raw) {
    String s = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (s.startsWith('+84')) s = '0${s.substring(3)}';
    else if (s.startsWith('84') && s.length == 11) s = '0${s.substring(2)}';
    else if (!s.startsWith('0') && s.length == 9)  s = '0$s';
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

// ── Sheet ─────────────────────────────────────────────────────────

class _PosCustomerSheet extends StatefulWidget {
  final PosCustomerInfo? current;
  final List<CartItem>   cartItems;
  const _PosCustomerSheet({this.current, required this.cartItems});
  @override
  State<_PosCustomerSheet> createState() => _PosCustomerSheetState();
}

class _PosCustomerSheetState extends State<_PosCustomerSheet> {
  final _phoneCtrl    = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _refPhoneCtrl = TextEditingController();

  DateTime? _selectedDob;   // ngày sinh — chọn từ calendar

  Timer? _debounce;
  Timer? _refDebounce;

  bool             _isSearching   = false;
  bool             _searched      = false;
  PosCustomerInfo? _foundCustomer;
  bool             _notFound      = false;

  bool             _isSaving      = false;
  PosCustomerInfo? _savedCustomer;

  bool             _isSearchingRef = false;
  PosCustomerInfo? _foundReferrer;
  bool             _refNotFound    = false;
  bool             _refSearched    = false;

  List<CustomerDiscountInfo> _discounts         = [];
  CustomerDiscountInfo?      _selectedDiscount;
  PosDiscountOption?         _selectedOption;
  int?                       _selectedItemProductId;
  bool                       _isLoadingDiscount = false;

  // ── DOB helpers ───────────────────────────────────────────────

  String _fmtDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

  DateTime? _parseDob(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  String? _dobToApi() {
    if (_selectedDob == null) return null;
    return '${_selectedDob!.year}-'
        '${_selectedDob!.month.toString().padLeft(2, '0')}-'
        '${_selectedDob!.day.toString().padLeft(2, '0')}';
  }

  // ── Derived ───────────────────────────────────────────────────

  PosCustomerInfo? get _activeCustomer => _savedCustomer ?? _foundCustomer;
  bool get _canConfirm => _activeCustomer != null;
  bool get _canSave =>
      _foundCustomer == null &&
          _phoneCtrl.text.trim().length >= 9 &&
          _nameCtrl.text.trim().isNotEmpty &&
          !_isSaving;

  @override
  void initState() {
    super.initState();
    if (widget.current != null) {
      final c = widget.current!;
      _phoneCtrl.text   = c.phone;
      _nameCtrl.text    = c.name;
      _addressCtrl.text = c.deliveryAddress ?? '';
      _selectedDob      = _parseDob(c.dateOfBirth);
      _savedCustomer    = c;
      if (c.referredByPhone != null) {
        _refPhoneCtrl.text = c.referredByPhone!;
        _foundReferrer = PosCustomerInfo(
          phone: c.referredByPhone!,
          name:  c.referredByName ?? '',
          id:    c.referredByCustomerId,
        );
      }
      if (c.id != null) _loadDiscount(c.id!);
    }
    _phoneCtrl.addListener(_onPhoneChanged);
    _nameCtrl.addListener(() => setState(() {}));
    _refPhoneCtrl.addListener(_onRefPhoneChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refDebounce?.cancel();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _refPhoneCtrl.dispose();
    super.dispose();
  }

  // ── Phone search ──────────────────────────────────────────────

  void _onPhoneChanged() {
    if (_savedCustomer != null || _foundCustomer != null || _notFound) {
      setState(() {
        _savedCustomer    = null;
        _foundCustomer    = null;
        _notFound         = false;
        _searched         = false;
        _nameCtrl.text    = '';
        _addressCtrl.text = '';
        _selectedDob      = null;
        _refPhoneCtrl.text = '';
        _foundReferrer    = null;
        _refSearched      = false;
        _discounts             = [];
        _selectedDiscount      = null;
        _selectedOption        = null;
        _selectedItemProductId = null;
      });
    }
    _debounce?.cancel();
    final trimmed = _phoneCtrl.text.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.length < 9) {
      if (_searched) setState(() { _searched = false; _notFound = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600),
            () => _search(trimmed));
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
      final list = (res.isSuccess ? (res.data ?? []) : [])
          .cast<Map<String, dynamic>>();
      final exact = list.where((e) =>
      (e['phone'] as String? ?? '') == normalized).toList();

      if (exact.isNotEmpty) {
        final found = _fromMap(exact.first);
        setState(() {
          _isSearching   = false;
          _searched      = true;
          _foundCustomer = found;
          _notFound      = false;
          _nameCtrl.text    = found.name;
          _addressCtrl.text = found.deliveryAddress ?? '';
          _selectedDob      = _parseDob(found.dateOfBirth);
          if (found.referredByPhone != null) {
            _refPhoneCtrl.text = found.referredByPhone!;
            _foundReferrer = PosCustomerInfo(
              phone: found.referredByPhone!,
              name:  found.referredByName ?? '',
              id:    found.referredByCustomerId,
            );
          }
        });
        if (found.id != null) _loadDiscount(found.id!);
      } else {
        setState(() {
          _isSearching = false; _searched = true;
          _foundCustomer = null; _notFound = true;
          _nameCtrl.text = '';
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _isSearching = false; _searched = true; _notFound = true;
      });
    }
  }

  // ── Referrer search ───────────────────────────────────────────

  void _onRefPhoneChanged() {
    if (_foundReferrer != null || _refNotFound) {
      setState(() {
        _foundReferrer = null;
        _refNotFound   = false;
        _refSearched   = false;
      });
    }
    _refDebounce?.cancel();
    final trimmed = _refPhoneCtrl.text.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.length < 9) {
      if (_refSearched) setState(() { _refSearched = false; _refNotFound = false; });
      return;
    }
    _refDebounce = Timer(const Duration(milliseconds: 600),
            () => _searchReferrer(trimmed));
  }

  Future<void> _searchReferrer(String raw) async {
    if (!mounted) return;
    setState(() => _isSearchingRef = true);
    try {
      final normalized = PosCustomerInfo.normalizePhone(raw);
      final myPhone = PosCustomerInfo.normalizePhone(_phoneCtrl.text);
      if (normalized == myPhone) {
        setState(() {
          _isSearchingRef = false; _refSearched = true;
          _refNotFound = true; _foundReferrer = null;
        });
        return;
      }
      final res = await DioClient.instance.get<List<dynamic>>(
        '${ApiConstants.posBase}/customers/search',
        queryParams: {'phone': normalized},
        fromData: (d) => d as List,
      );
      if (!mounted) return;
      final list = (res.isSuccess ? (res.data ?? []) : [])
          .cast<Map<String, dynamic>>();
      final exact = list.where((e) =>
      (e['phone'] as String? ?? '') == normalized).toList();

      if (exact.isNotEmpty) {
        setState(() {
          _isSearchingRef = false; _refSearched = true;
          _foundReferrer = _fromMap(exact.first); _refNotFound = false;
        });
      } else {
        setState(() {
          _isSearchingRef = false; _refSearched = true;
          _foundReferrer = null; _refNotFound = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _isSearchingRef = false; _refSearched = true; _refNotFound = true;
      });
    }
  }

  // ── Date picker ───────────────────────────────────────────────

  Future<void> _pickDob() async {
    final cs = Theme.of(context).colorScheme;
    DateTime? picked;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Chọn ngày sinh',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 300,
          child: CalendarDatePicker(
            initialDate: _selectedDob ?? DateTime(1990, 1, 1),
            firstDate:   DateTime(1920),
            lastDate:    DateTime.now(),
            onDateChanged: (d) => picked = d,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedDob = null);
            },
            child: Text('Xóa', style: TextStyle(color: cs.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (picked != null) setState(() => _selectedDob = picked);
            },
            child: const Text('Chọn'),
          ),
        ],
      ),
    );
  }

  // ── Discount ─────────────────────────────────────────────────

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
          _selectedOption   = _selectedDiscount!.selectedOption;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingDiscount = false);
    }
  }

  // ── Save ─────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      final body = <String, dynamic>{
        'phone': PosCustomerInfo.normalizePhone(_phoneCtrl.text.trim()),
        'name':  _nameCtrl.text.trim(),
      };
      if (_dobToApi() != null)          body['dateOfBirth']     = _dobToApi()!;
      if (_addressCtrl.text.isNotEmpty) body['deliveryAddress'] = _addressCtrl.text.trim();
      if (_foundReferrer != null)       body['referredByPhone'] = _foundReferrer!.phone;

      final res = await DioClient.instance.post<Map<String, dynamic>>(
        '${ApiConstants.posBase}/customers',
        body: body,
        fromData: (d) => d as Map<String, dynamic>,
      );
      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        Navigator.pop(context, CustomerSheetResult(
            customer: _fromMap(res.data!)));
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

  PosCustomerInfo _fromMap(Map<String, dynamic> e) => PosCustomerInfo(
    phone:                e['phone']                as String? ?? '',
    name:                 e['name']                 as String? ?? '',
    id:                   e['id']                   as int?,
    dateOfBirth:          e['dateOfBirth']           as String?,
    deliveryAddress:      e['deliveryAddress']       as String?,
    referredByCustomerId: e['referredByCustomerId']  as int?,
    referredByName:       e['referredByName']        as String?,
    referredByPhone:      e['referredByPhone']       as String?,
  );

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    const teal    = Color(0xFF0D9488);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bg      = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border  = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final txtSec  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final nameReadOnly = _foundCustomer != null;

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
              child: const Icon(Icons.person_search_rounded,
                  size: 18, color: teal),
            ),
            const SizedBox(width: 10),
            Text('Thông tin khách hàng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
          ]),
          const SizedBox(height: 20),

          // ── SĐT ─────────────────────────────────────────────
          _buildField(
            ctrl: _phoneCtrl, label: 'Số điện thoại *', hint: '0938 121 001',
            icon: Icons.phone_rounded,
            teal: teal, bg: bg, border: border, txtSec: txtSec, isDark: isDark,
            keyboard:   TextInputType.phone,
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s+\-]'))],
            suffix: _isSearching
                ? _loadingWidget(teal)
                : _foundCustomer != null
                ? const Icon(Icons.check_circle_rounded, color: teal, size: 20)
                : null,
            borderColor: _foundCustomer != null ? teal.withOpacity(0.5) : null,
          ),
          const SizedBox(height: 4),
          if (_searched && !_isSearching)
            _statusRow(
              found: _foundCustomer != null,
              foundText:    'Đã tìm thấy khách hàng',
              notFoundText: 'Không tìm thấy · Vui lòng tạo mới',
              cs: cs, teal: teal,
            ),
          const SizedBox(height: 8),

          // ── Tên ─────────────────────────────────────────────
          _buildField(
            ctrl: _nameCtrl, label: 'Tên khách hàng *',
            hint: nameReadOnly ? '' : 'Nguyễn Văn A',
            icon: Icons.person_rounded,
            teal: teal, bg: bg, border: border, txtSec: txtSec, isDark: isDark,
            readOnly: nameReadOnly,
          ),
          const SizedBox(height: 10),

          // ── Ngày sinh — date picker ──────────────────────────
          GestureDetector(
            onTap: nameReadOnly ? null : _pickDob,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: nameReadOnly
                    ? teal.withOpacity(0.04) : bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedDob != null
                      ? teal.withOpacity(0.5) : border,
                  width: _selectedDob != null ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Icon(Icons.cake_rounded, size: 18,
                    color: nameReadOnly
                        ? txtSec.withOpacity(0.5)
                        : teal.withOpacity(0.7)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  _selectedDob != null
                      ? _fmtDob(_selectedDob!)
                      : 'Ngày sinh (tùy chọn)',
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedDob != null
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : txtSec.withOpacity(0.6),
                  ),
                )),
                if (_selectedDob != null && !nameReadOnly)
                  GestureDetector(
                    onTap: () => setState(() => _selectedDob = null),
                    child: Icon(Icons.clear_rounded, size: 16,
                        color: txtSec.withOpacity(0.5)),
                  )
                else if (!nameReadOnly)
                  Icon(Icons.arrow_drop_down_rounded, size: 20,
                      color: txtSec.withOpacity(0.5)),
              ]),
            ),
          ),
          const SizedBox(height: 10),

          // ── Địa chỉ ─────────────────────────────────────────
          _buildField(
            ctrl: _addressCtrl, label: 'Địa chỉ giao hàng (tùy chọn)',
            hint: '123 Nguyễn Trãi, Q5, TP.HCM',
            icon: Icons.location_on_rounded,
            teal: teal, bg: bg, border: border, txtSec: txtSec, isDark: isDark,
            readOnly: nameReadOnly, maxLines: 2,
          ),
          const SizedBox(height: 10),

          // ── Người giới thiệu ─────────────────────────────────
          if (!nameReadOnly ||
              (_foundCustomer != null &&
                  _foundCustomer!.referredByCustomerId == null)) ...[
            _buildField(
              ctrl: _refPhoneCtrl,
              label: 'SĐT người giới thiệu (tùy chọn)',
              hint: '0938 xxx xxx',
              icon: Icons.people_alt_rounded,
              teal: teal, bg: bg, border: border, txtSec: txtSec, isDark: isDark,
              readOnly: nameReadOnly && _foundCustomer?.referredByCustomerId != null,
              keyboard:   TextInputType.phone,
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s+\-]'))],
              suffix: _isSearchingRef
                  ? _loadingWidget(teal)
                  : _foundReferrer != null
                  ? const Icon(Icons.check_circle_rounded, color: teal, size: 20)
                  : null,
              borderColor: _foundReferrer != null ? teal.withOpacity(0.5) : null,
            ),
            const SizedBox(height: 4),
            if (_refSearched && !_isSearchingRef)
              _statusRow(
                found: _foundReferrer != null,
                foundText:    'Người giới thiệu: ${_foundReferrer?.name ?? ""}',
                notFoundText: 'Không tìm thấy số này',
                cs: cs, teal: teal,
              ),
            const SizedBox(height: 8),
          ],

          // Hiển thị referrer đã có
          if (_foundCustomer != null &&
              _foundCustomer!.referredByCustomerId != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: teal.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: teal.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.people_alt_rounded, size: 14, color: teal),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Giới thiệu bởi: ${_foundCustomer!.referredByName ?? ""}'
                      ' (${_foundCustomer!.referredByPhone ?? ""})',
                  style: TextStyle(fontSize: 12, color: txtSec),
                )),
              ]),
            ),
            const SizedBox(height: 10),
          ],

          // ── Discount section ─────────────────────────────────
          if (_activeCustomer != null && _activeCustomer!.id != null) ...[
            Divider(color: border),
            const SizedBox(height: 10),
            if (_isLoadingDiscount)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  _loadingWidget(teal),
                  const SizedBox(width: 10),
                  Text('Đang tải khuyến mãi...',
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
                isDark: isDark, cs: cs, teal: teal,
                border: border, bg: bg, txtSec: txtSec,
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

          // ── Buttons ─────────────────────────────────────────
          Row(children: [
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: teal,
                    disabledBackgroundColor: teal.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )),
              const SizedBox(width: 10),
            ],
            Expanded(child: SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _canConfirm ? _confirm : null,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Chọn khách',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: _canConfirm ? const Color(0xFF0284C7) : null,
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

  // ── UI helpers ────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController ctrl,
    required String label, required String hint, required IconData icon,
    required Color teal, required Color bg, required Color border,
    required Color txtSec, required bool isDark,
    bool readOnly = false,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
    Widget? suffix, Color? borderColor, int maxLines = 1,
  }) {
    final eBorder = borderColor ?? border;
    return TextFormField(
      controller:  ctrl,
      readOnly:    readOnly,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
      maxLines:    maxLines,
      inputFormatters: formatters,
      style: TextStyle(fontSize: 14,
          color: readOnly
              ? (isDark ? Colors.white70 : const Color(0xFF334155))
              : (isDark ? Colors.white   : const Color(0xFF0F172A))),
      decoration: InputDecoration(
        labelText:  label, hintText: hint,
        prefixIcon: Icon(icon, size: 18,
            color: readOnly ? txtSec.withOpacity(0.5) : teal.withOpacity(0.7)),
        suffixIcon: suffix,
        filled:     true,
        fillColor:  readOnly ? teal.withOpacity(0.04) : bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: eBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: eBorder,
                width: borderColor != null ? 1.5 : 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: readOnly ? border : teal, width: 1.5)),
        labelStyle: TextStyle(fontSize: 13, color: txtSec),
        hintStyle:  TextStyle(fontSize: 13, color: txtSec.withOpacity(0.6)),
      ),
    );
  }

  Widget _statusRow({
    required bool found,
    required String foundText, required String notFoundText,
    required ColorScheme cs, required Color teal,
  }) =>
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Row(children: [
          Icon(
            found ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 13, color: found ? teal : cs.error,
          ),
          const SizedBox(width: 5),
          Flexible(child: Text(
            found ? foundText : notFoundText,
            style: TextStyle(fontSize: 11,
                color: found ? teal : cs.error,
                fontWeight: FontWeight.w500),
          )),
        ]),
      );

  Widget _loadingWidget(Color color) => Padding(
    padding: const EdgeInsets.all(12),
    child: SizedBox(width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: color)),
  );
}

// ══════════════════════════════════════════════════════════════════
// DISCOUNT SECTION
// ══════════════════════════════════════════════════════════════════

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
    required this.discounts, required this.selected,
    required this.selectedOption, required this.selectedItemProductId,
    required this.cartItems, required this.isDark, required this.cs,
    required this.teal, required this.border, required this.bg,
    required this.txtSec, required this.onDiscountSelected,
    required this.onOptionSelected, required this.onItemSelected,
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
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSel ? teal.withOpacity(0.08) : bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSel ? teal.withOpacity(0.4) : border,
                  width: isSel ? 1.5 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.local_offer_rounded, size: 15,
                        color: isSel ? teal : txtSec),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d.programName,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
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
                                color: cs.error, fontWeight: FontWeight.w700)),
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
                          ? (d.budgetUsed / d.maxDiscount).clamp(0.0, 1.0) : 0,
                      minHeight: 4,
                      backgroundColor: teal.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(
                          d.exhausted ? cs.error : teal),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Đã dùng ${_fmtK(d.budgetUsed)} / ${_fmtK(d.maxDiscount)}',
                      style: TextStyle(fontSize: 10, color: txtSec)),
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
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        color: isOptSel ? teal : txtSec.withOpacity(0.4),
                        width: 1.5),
                  ),
                  child: isOptSel
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(opt.displayLabel,
                    style: TextStyle(fontSize: 13,
                        color: isOptSel ? teal
                            : (isDark ? Colors.white
                            : const Color(0xFF0F172A)),
                        fontWeight: isOptSel
                            ? FontWeight.w600 : FontWeight.w400))),
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
              .values.map((c) {
            final isSel = selectedItemProductId == c.product.id;
            return GestureDetector(
              onTap: () => onItemSelected(isSel ? null : c.product.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
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
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(c.product.name,
                      style: TextStyle(fontSize: 13,
                          color: isSel ? teal
                              : (isDark ? Colors.white
                              : const Color(0xFF0F172A)),
                          fontWeight: isSel
                              ? FontWeight.w600 : FontWeight.w400))),
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

  String _fmtMoney(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ══════════════════════════════════════════════════════════════════
// SECTION LABEL
// ══════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color  color;
  const _SectionLabel({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 13,
        decoration: BoxDecoration(color: const Color(0xFF0D9488),
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 7),
    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: color, letterSpacing: 0.3)),
  ]);
}