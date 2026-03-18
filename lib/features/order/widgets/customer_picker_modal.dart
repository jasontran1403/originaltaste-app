// lib/features/order/widgets/customer_picker_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/order/order_models.dart';
import '../../../services/order_service.dart';
import '../controller/order_cart_controller.dart';
import '../../../shared/widgets/order_shared_widgets.dart';

class CustomerPickerModal extends ConsumerStatefulWidget {
  const CustomerPickerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder: (_) => const CustomerPickerModal(),
    );
  }

  @override
  ConsumerState<CustomerPickerModal> createState() =>
      _CustomerPickerModalState();
}

class _CustomerPickerModalState extends ConsumerState<CustomerPickerModal> {
  final _phoneCtrl    = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _notesCtrl    = TextEditingController();

  CustomerModel? _found;
  bool _isSearching = false;
  bool _isSaving    = false;
  String? _searchError;
  bool _showForm    = false;

  bool get _isRetail    => ref.read(orderCartProvider).orderMode == OrderMode.retail;
  bool get _isWholesale => !_isRetail;
  bool get _isExisting  => _found != null;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(orderCartProvider).selectedCustomer;
    if (_isRetail) {
      _nameCtrl.text    = 'Khách lẻ';
      _phoneCtrl.text   = existing?.phone ?? '';
      _emailCtrl.text   = existing?.email ?? '';
      _addressCtrl.text = existing?.address ?? '';
    } else if (existing != null) {
      _phoneCtrl.text    = existing.phone;
      _nameCtrl.text     = existing.name;
      _emailCtrl.text    = existing.email;
      _addressCtrl.text  = existing.address;
      _discountCtrl.text = existing.discountRate.toString();
      _showForm          = true;
      if (existing.id != null) {
        _found = CustomerModel(
          id:           existing.id!,
          phone:        existing.phone,
          name:         existing.name,
          discountRate: existing.discountRate,
          isActive:     true,
          addresses: existing.address.isEmpty ? [] : [
            CustomerAddressModel(address: existing.address, isDefault: true),
          ],
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();    _nameCtrl.dispose();
    _emailCtrl.dispose();    _addressCtrl.dispose();
    _discountCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final surface   = isDark ? AppColors.darkCard : Colors.white;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color:        surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        secondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _ModeBadge(isRetail: _isRetail, primary: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isRetail ? 'Thông tin khách lẻ' : 'Thông tin khách sỉ',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (ref.read(orderCartProvider).selectedCustomer != null)
                TextButton(
                  onPressed: () {
                    ref.read(orderCartProvider.notifier).clearCustomer();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Xóa KH', style: TextStyle(color: AppColors.error)),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:  secondary.withOpacity(0.1),
                    shape:  BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 18, color: secondary),
                ),
              ),
            ]),
          ),
          Divider(height: 16, color: border),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              child: _isRetail
                  ? _buildRetailBody(isDark, primary, secondary, border)
                  : _buildWholesaleBody(isDark, primary, secondary, border),
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // RETAIL BODY
  // ══════════════════════════════════════════════════════════════
  Widget _buildRetailBody(bool isDark, Color primary, Color secondary, Color border) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _InfoBanner(
        text: 'SĐT, email và địa chỉ là bắt buộc. Ghi chú là tuỳ chọn.',
        color: Colors.orange,
      ),
      const SizedBox(height: 20),

      // ── Dòng 1: Tên + SĐT ──────────────────────────────────
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 4,
            child: _Field(
              label: 'Tên khách hàng',
              child: _TextInputFixed(controller: _nameCtrl, hint: 'Khách lẻ',
                  readOnly: true, isDark: isDark, primary: primary, secondary: secondary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: _FieldRequired(
              label: 'Số điện thoại',
              child: _TextInputFixed(
                controller: _phoneCtrl, hint: 'Nhập SĐT...',
                keyboard: TextInputType.phone,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                isDark: isDark, primary: primary, secondary: secondary,
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Dòng 2: Email + Địa chỉ ────────────────────────────
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: _FieldRequired(
              label: 'Email',
              child: _TextInputFixed(
                controller: _emailCtrl, hint: 'abc@xyz.com',
                keyboard: TextInputType.emailAddress,
                validator: (v) {
                  if (v.isEmpty) return null;
                  final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]{2,}$').hasMatch(v);
                  return ok ? null : 'Email không hợp lệ';
                },
                isDark: isDark, primary: primary, secondary: secondary,
                expands: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FieldRequired(
              label: 'Địa chỉ',
              child: _TextInputFixed(
                controller: _addressCtrl, hint: 'Nhập địa chỉ...',
                isDark: isDark, primary: primary, secondary: secondary,
                expands: true,
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      _Field(
        label: 'Ghi chú',
        child: _TextInput(
          controller: _notesCtrl, hint: 'Ghi chú đơn hàng (tuỳ chọn)',
          maxLines: 2,
          isDark: isDark, primary: primary, secondary: secondary,
        ),
      ),
      const SizedBox(height: 24),
      _SubmitButton(
        label: 'Xác nhận',
        icon: Icons.check_circle_outline,
        loading: _isSaving,
        color: Colors.orange.shade700,
        onTap: _isSaving ? null : _applyRetail,
      ),
      const SizedBox(height: 20),
    ]);
  }

  // ══════════════════════════════════════════════════════════════
  // WHOLESALE BODY
  // ══════════════════════════════════════════════════════════════
  Widget _buildWholesaleBody(bool isDark, Color primary, Color secondary, Color border) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Phone search
      Text('Số điện thoại *',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: _TextInput(
            controller: _phoneCtrl,
            hint: 'Nhập SĐT để tìm KH...',
            keyboard: TextInputType.phone,
            readOnly: _isExisting,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            isDark: isDark, primary: primary, secondary: secondary,
            onSubmit: _isExisting ? null : (_) => _searchByPhone(),
          ),
        ),
        if (!_isExisting) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isSearching ? null : _searchByPhone,
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color:        _isSearching ? secondary.withOpacity(0.3) : primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isSearching
                  ? SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search, color: Colors.white, size: 20),
            ),
          ),
        ],
      ]),

      if (_found != null) ...[
        const SizedBox(height: 12),
        _FoundCustomerCard(
          customer: _found!,
          primary:  primary,
          secondary: secondary,
          onDeselect: () => setState(() {
            _found = null; _showForm = false; _searchError = null;
            _phoneCtrl.text = ''; _nameCtrl.text = '';
            _emailCtrl.text = ''; _addressCtrl.text = '';
            _discountCtrl.text = '0';
          }),
        ),
      ],

      if (_searchError != null && !_showForm) ...[
        const SizedBox(height: 10),
        _NotFoundBanner(
          primary: primary,
          onCreateNew: () => setState(() => _showForm = true),
        ),
      ],

      if (_showForm) ...[
        const SizedBox(height: 20),
        _SectionDivider(
          label: _isExisting ? 'Thông tin' : 'Khách hàng mới',
          primary: primary, secondary: secondary,
        ),
        const SizedBox(height: 16),
        _Field(
          label: 'Tên khách hàng *',
          child: _TextInput(controller: _nameCtrl, hint: 'Nhập tên...',
              isDark: isDark, primary: primary, secondary: secondary),
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Email',
          child: _TextInput(
            controller: _emailCtrl, hint: 'Nhập email (tuỳ chọn)...',
            keyboard: TextInputType.emailAddress,
            isDark: isDark, primary: primary, secondary: secondary,
          ),
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Địa chỉ',
          child: _TextInput(
            controller: _addressCtrl, hint: 'Nhập địa chỉ (tuỳ chọn)...',
            maxLines: 2,
            isDark: isDark, primary: primary, secondary: secondary,
          ),
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'Chiết khấu (%)',
          child: _TextInput(
            controller:  _discountCtrl,
            hint:        '0 – 100',
            keyboard:    TextInputType.number,
            formatters:  [FilteringTextInputFormatter.digitsOnly],
            suffix:      '%',
            isDark:      isDark, primary: primary, secondary: secondary,
          ),
        ),
        const SizedBox(height: 24),
        if (_isExisting)
          Row(children: [
            Expanded(child: _OutlineButton(
                label: 'Dùng', onTap: _isSaving ? null : _applyLocal,
                secondary: secondary)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: _SubmitButton(
              label:   _isSaving ? 'Đang lưu...' : 'Cập nhật',
              icon:    Icons.check_circle_outline,
              loading: _isSaving, color: primary,
              onTap:   _isSaving ? null : _updateAndApply,
            )),
          ])
        else
          Row(children: [
            Expanded(child: _OutlineButton(
                label: 'Dùng tạm', onTap: _isSaving ? null : _applyLocal,
                secondary: secondary)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: _SubmitButton(
              label:   _isSaving ? 'Đang lưu...' : 'Lưu & dùng',
              icon:    Icons.save_outlined,
              loading: _isSaving, color: primary,
              onTap:   _isSaving ? null : _saveAndUse,
            )),
          ]),
      ],

      if (!_showForm && _found == null && _searchError == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_search_outlined, size: 52, color: secondary.withOpacity(0.2)),
            const SizedBox(height: 10),
            Text('Nhập SĐT để tìm khách hàng sỉ',
                style: TextStyle(color: secondary)),
          ])),
        ),

      const SizedBox(height: 20),
    ]);
  }

  // ── Actions ───────────────────────────────────────────────────
  void _applyRetail() {
    final phone   = _phoneCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    if (phone.isEmpty || email.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng điền đầy đủ SĐT, email và địa chỉ'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final emailOk = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]{2,}$').hasMatch(email);
    if (!emailOk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Email không đúng định dạng (vd: abc@xyz.com)'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final notes = _notesCtrl.text.trim();
    if (notes.isNotEmpty) {
      ref.read(orderCartProvider.notifier).setOrderNotes(notes);
    }

    _applyCustomer(id: null, name: 'Khách lẻ',
        phone: phone, email: email, address: address, discount: 0);
  }

  Future<void> _searchByPhone() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _isSearching = true; _searchError = null;
      _found = null; _showForm = false;
      _nameCtrl.text = ''; _emailCtrl.text = '';
      _addressCtrl.text = ''; _discountCtrl.text = '0';
    });

    final result = await OrderService.instance.getCustomerByPhone(phone);
    setState(() {
      _isSearching = false;
      if (result.isSuccess && result.data != null) {
        _found               = result.data!;
        _showForm            = true;
        _nameCtrl.text       = _found!.name ?? '';
        _emailCtrl.text      = _found!.email ?? '';
        _addressCtrl.text    = _found!.addresses.isNotEmpty
            ? _found!.addresses.first.address : '';
        _discountCtrl.text   = _found!.discountRate.toString();
      } else {
        _searchError = 'Không tìm thấy';
      }
    });
  }

  void _applyLocal() {
    if (!_validateWholesale()) return;
    _applyCustomer(
      id:       _found?.id,
      name:     _nameCtrl.text.trim(),
      phone:    _phoneCtrl.text.trim(),
      email:    _emailCtrl.text.trim(),
      address:  _addressCtrl.text.trim(),
      discount: (int.tryParse(_discountCtrl.text.trim()) ?? 0).clamp(0, 100),
    );
  }

  Future<void> _saveAndUse() async {
    if (!_validateWholesale()) return;
    setState(() => _isSaving = true);

    final result = await OrderService.instance.createCustomer(
      phone:        _phoneCtrl.text.trim(),
      name:         _nameCtrl.text.trim(),
      email:        _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      discountRate: (int.tryParse(_discountCtrl.text.trim()) ?? 0).clamp(0, 100),
      addresses:    _addressCtrl.text.trim().isEmpty ? null : [
        {'address': _addressCtrl.text.trim(), 'isDefault': true}
      ],
    );

    setState(() => _isSaving = false);

    if (result.isSuccess && result.data != null) {
      final saved = result.data!;
      _showSnack('Đã tạo khách hàng "${saved.name ?? saved.phone}"', Colors.green);
      _applyCustomer(
        id:       saved.id,
        name:     saved.name ?? '',
        phone:    saved.phone,
        email:    saved.email ?? '',
        address:  saved.addresses.isNotEmpty ? saved.addresses.first.address : '',
        discount: saved.discountRate,
      );
    } else {
      _showSnack(result.message ?? 'Không thể tạo khách hàng', Colors.red);
    }
  }

  Future<void> _updateAndApply() async {
    if (!_validateWholesale()) return;

    final newName     = _nameCtrl.text.trim();
    final newEmail    = _emailCtrl.text.trim();
    final newAddress  = _addressCtrl.text.trim();
    final newDiscount = (int.tryParse(_discountCtrl.text.trim()) ?? 0).clamp(0, 100);

    final hasChanged = newName != (_found!.name ?? '') ||
        newEmail != (_found!.email ?? '') ||
        newAddress != (_found!.defaultAddress?.address ?? '') ||
        newDiscount != _found!.discountRate;

    if (hasChanged) {
      setState(() => _isSaving = true);
      final result = await OrderService.instance.updateCustomer(
        id:           _found!.id,
        phone:        _found!.phone,
        name:         newName,
        email:        newEmail.isEmpty ? null : newEmail,
        discountRate: newDiscount,
        addresses:    newAddress.isEmpty ? null : [
          {'address': newAddress, 'isDefault': true}
        ],
      );
      setState(() => _isSaving = false);
      if (!result.isSuccess) {
        _showSnack(result.message ?? 'Không thể cập nhật', Colors.red);
        return;
      }
      _showSnack('Đã cập nhật thông tin khách hàng', Colors.green);
    }

    _applyCustomer(
      id:       _found!.id,
      name:     newName, phone: _found!.phone,
      email:    newEmail, address: newAddress,
      discount: newDiscount,
    );
  }

  void _applyCustomer({
    int? id,
    required String name, required String phone,
    required String email, required String address,
    required int discount,
  }) {
    ref.read(orderCartProvider.notifier).setCustomer(SelectedCustomer(
      id:           id,
      name:         name,
      phone:        phone,
      email:        email,
      address:      address,
      discountRate: discount,
    ));
    if (mounted) Navigator.pop(context);
  }

  bool _validateWholesale() {
    if (_phoneCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) {
      _showSnack('Vui lòng nhập SĐT và tên khách hàng', Colors.orange);
      return false;
    }
    return true;
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ══════════════════════════════════════════════════════════════════
// PRIVATE HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════

class _ModeBadge extends StatelessWidget {
  final bool isRetail;
  final Color primary;
  const _ModeBadge({required this.isRetail, required this.primary});

  @override
  Widget build(BuildContext context) {
    final c = isRetail ? Colors.orange : primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(
        isRetail ? 'Khách lẻ' : 'Khách sỉ',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final bool readOnly;
  final int? maxLines;
  final String? suffix;
  final Function(String)? onSubmit;
  final bool isDark;
  final Color primary;
  final Color secondary;

  const _TextInput({
    required this.controller,
    required this.hint,
    this.keyboard,
    this.formatters,
    this.readOnly   = false,
    this.maxLines   = 1,
    this.suffix,
    this.onSubmit,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = secondary.withOpacity(0.4);
    return TextField(
      controller:       controller,
      keyboardType:     keyboard,
      inputFormatters:  formatters,
      readOnly:         readOnly,
      maxLines:         maxLines,
      onSubmitted:      onSubmit,
      style: TextStyle(
        fontSize: 13,
        color: readOnly ? secondary : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      ),
      decoration: InputDecoration(
        hintText:        hint,
        hintStyle:       TextStyle(fontSize: 13, color: secondary),
        suffixText:      suffix,
        filled:          readOnly,
        fillColor:       readOnly ? secondary.withOpacity(0.06) : null,
        contentPadding:  const EdgeInsets.all(13),
        isDense:         true,
        isCollapsed:     true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }
}

// _TextInputFixed: single-line hoặc expands fill parent height (dùng trong IntrinsicHeight)
class _TextInputFixed extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final bool readOnly;
  final bool expands;         // true → fill chiều cao của IntrinsicHeight row
  final String? suffix;
  final Function(String)? onSubmit;
  final String? Function(String)? validator;
  final bool isDark;
  final Color primary;
  final Color secondary;

  const _TextInputFixed({
    required this.controller,
    required this.hint,
    this.keyboard,
    this.formatters,
    this.readOnly   = false,
    this.expands    = false,
    this.suffix,
    this.onSubmit,
    this.validator,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  @override
  State<_TextInputFixed> createState() => _TextInputFixedState();
}

class _TextInputFixedState extends State<_TextInputFixed> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.secondary.withOpacity(0.4);
    final hasError    = _error != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: TextField(
            controller:      widget.controller,
            keyboardType:    widget.expands ? TextInputType.multiline : widget.keyboard,
            inputFormatters: widget.formatters,
            readOnly:        widget.readOnly,
            expands:         widget.expands,
            maxLines:        widget.expands ? null : 1,
            minLines:        null,
            onSubmitted:     widget.onSubmit,
            textAlignVertical: TextAlignVertical.top,
            onChanged: (v) {
              if (widget.validator != null) {
                setState(() => _error = widget.validator!(v));
              }
            },
            style: TextStyle(
              fontSize: 13,
              color: widget.readOnly
                  ? widget.secondary
                  : (widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
            decoration: InputDecoration(
              hintText:       widget.hint,
              hintStyle:      TextStyle(fontSize: 13, color: widget.secondary),
              suffixText:     widget.suffix,
              filled:         widget.readOnly,
              fillColor:      widget.readOnly ? widget.secondary.withOpacity(0.06) : null,
              contentPadding: const EdgeInsets.all(13),
              isDense:        true,
              isCollapsed:    true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   BorderSide(color: hasError ? AppColors.error : borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   BorderSide(
                  color: hasError ? AppColors.error : widget.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
      if (hasError)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text(_error!, style: TextStyle(fontSize: 11, color: AppColors.error)),
        ),
    ]);
  }
}

// Validated text input — hiển thị error inline bên dưới field
class _TextInputValidated extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final String? Function(String)? validator;
  final bool isDark;
  final Color primary;
  final Color secondary;

  const _TextInputValidated({
    required this.controller,
    required this.hint,
    this.keyboard,
    this.validator,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  @override
  State<_TextInputValidated> createState() => _TextInputValidatedState();
}

class _TextInputValidatedState extends State<_TextInputValidated> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.secondary.withOpacity(0.4);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller:   widget.controller,
        keyboardType: widget.keyboard,
        style: TextStyle(
          fontSize: 13,
          color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        onChanged: (v) {
          if (widget.validator != null) {
            setState(() => _error = widget.validator!(v));
          }
        },
        decoration: InputDecoration(
          hintText:       widget.hint,
          hintStyle:      TextStyle(fontSize: 13, color: widget.secondary),
          contentPadding: const EdgeInsets.all(13),
          isDense:        true,
          isCollapsed:    true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:   BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:   BorderSide(
              color: _error != null ? AppColors.error : borderColor,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:   BorderSide(
              color: _error != null ? AppColors.error : widget.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text(_error!,
              style: TextStyle(fontSize: 11, color: AppColors.error)),
        ),
    ]);
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      child,
    ]);
  }
}

class _FieldRequired extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldRequired({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:        Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('bắt buộc',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700)),
        ),
      ]),
      const SizedBox(height: 8),
      child,
    ]);
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  const _InfoBanner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(children: [
      Icon(Icons.info_outline, size: 15, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 12, color: color))),
    ]),
  );
}

class _NotFoundBanner extends StatelessWidget {
  final Color primary;
  final VoidCallback onCreateNew;
  const _NotFoundBanner({required this.primary, required this.onCreateNew});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color:        Colors.orange.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border:       Border.all(color: Colors.orange.withOpacity(0.3)),
    ),
    child: Row(children: [
      Icon(Icons.info_outline, size: 16, color: Colors.orange),
      const SizedBox(width: 8),
      Expanded(child: Text('Không tìm thấy — bạn có muốn tạo mới?',
          style: TextStyle(fontSize: 12, color: Colors.orange))),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onCreateNew,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:        primary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('Tạo mới',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ]),
  );
}

class _FoundCustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final Color primary, secondary;
  final VoidCallback onDeselect;
  const _FoundCustomerCard({
    required this.customer, required this.primary,
    required this.secondary, required this.onDeselect,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onDeselect,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.green.withOpacity(0.35)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color:  Colors.green.withOpacity(0.12),
            shape:  BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline, size: 18, color: Colors.green),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle, size: 13, color: Colors.green),
            const SizedBox(width: 4),
            Text('Đã có trong hệ thống',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.green)),
          ]),
          const SizedBox(height: 3),
          Text(customer.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(customer.phone, style: TextStyle(fontSize: 12, color: secondary)),
          if (customer.discountRate > 0)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:        primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('CK: ${customer.discountRate}%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primary)),
            ),
        ])),
        Column(children: [
          Icon(Icons.close, size: 15, color: secondary.withOpacity(0.4)),
          const SizedBox(height: 2),
          Text('Bỏ chọn', style: TextStyle(fontSize: 10, color: secondary.withOpacity(0.4))),
        ]),
      ]),
    ),
  );
}

class _SectionDivider extends StatelessWidget {
  final String label;
  final Color primary, secondary;
  const _SectionDivider({required this.label, required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Divider(color: secondary.withOpacity(0.2))),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary)),
    ),
    Expanded(child: Divider(color: secondary.withOpacity(0.2))),
  ]);
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final Color color;
  final VoidCallback? onTap;
  const _SubmitButton({
    required this.label, required this.icon,
    required this.loading, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color:        onTap == null ? color.withOpacity(0.4) : color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: loading
          ? const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ])),
    ),
  );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color secondary;
  const _OutlineButton({required this.label, required this.onTap, required this.secondary});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border:       Border.all(color: secondary.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: Text(label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondary))),
    ),
  );
}