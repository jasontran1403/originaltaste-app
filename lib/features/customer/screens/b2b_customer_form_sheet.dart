// lib/features/customer/screens/b2b_customer_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/customer_controller.dart';
import '../widgets/customer_widgets.dart';

Future<bool> showB2bCustomerForm(
    BuildContext context, {
      B2bCustomerModel? customer,
    }) async {
  final result = await showModalBottomSheet<bool>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => _B2bCustomerFormSheet(customer: customer),
  );
  return result ?? false;
}

class _B2bCustomerFormSheet extends ConsumerStatefulWidget {
  final B2bCustomerModel? customer;
  const _B2bCustomerFormSheet({this.customer});

  @override
  ConsumerState<_B2bCustomerFormSheet> createState() =>
      _B2bCustomerFormSheetState();
}

class _B2bCustomerFormSheetState
    extends ConsumerState<_B2bCustomerFormSheet> {

  final _codeCtrl        = TextEditingController();
  final _companyCtrl     = TextEditingController();
  final _shortNameCtrl   = TextEditingController();
  final _taxCodeCtrl     = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _deliveryCtrl    = TextEditingController();
  final _contactCtrl     = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _discountCtrl    = TextEditingController(text: '0');

  B2bCustomerType _type = B2bCustomerType.retail;
  DateTime? _selectedDob;

  bool get _isEdit => widget.customer != null;

  // ── DOB helpers ───────────────────────────────────────────────
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

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final c = widget.customer!;
      _codeCtrl.text     = c.customerCode    ?? '';
      _companyCtrl.text  = c.companyName     ?? '';
      _shortNameCtrl.text= c.shortName       ?? '';
      _taxCodeCtrl.text  = c.taxCode         ?? '';
      _addressCtrl.text  = c.address         ?? '';
      _deliveryCtrl.text = c.deliveryAddress ?? '';
      _contactCtrl.text  = c.contactName     ?? '';
      _phoneCtrl.text    = c.phone           ?? '';
      _emailCtrl.text    = c.email           ?? '';
      _discountCtrl.text = c.discountRate.toString();
      _type              = c.customerType;
      _selectedDob       = _parseDob(c.dateOfBirth);
    }
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _companyCtrl, _shortNameCtrl, _taxCodeCtrl,
      _addressCtrl, _deliveryCtrl, _contactCtrl, _phoneCtrl,
      _emailCtrl, _discountCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

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
            initialDate: _selectedDob ?? DateTime(1990),
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

  Future<void> _save() async {
    if (_codeCtrl.text.trim().isEmpty) {
      _snack('Vui lòng nhập mã khách hàng');
      return;
    }

    final data = <String, dynamic>{
      'customerCode': _codeCtrl.text.trim().toUpperCase(),
      'customerType': _type == B2bCustomerType.company ? 'COMPANY' : 'RETAIL',
    };

    if (_companyCtrl.text.isNotEmpty)
      data['companyName']     = _companyCtrl.text.trim();
    if (_shortNameCtrl.text.isNotEmpty)
      data['shortName']       = _shortNameCtrl.text.trim();
    if (_taxCodeCtrl.text.isNotEmpty)
      data['taxCode']         = _taxCodeCtrl.text.trim();
    if (_addressCtrl.text.isNotEmpty)
      data['address']         = _addressCtrl.text.trim();
    if (_deliveryCtrl.text.isNotEmpty)
      data['deliveryAddress'] = _deliveryCtrl.text.trim();
    if (_contactCtrl.text.isNotEmpty)
      data['contactName']     = _contactCtrl.text.trim();
    if (_phoneCtrl.text.isNotEmpty)
      data['phone']           = _phoneCtrl.text.trim();
    if (_emailCtrl.text.isNotEmpty)
      data['email']           = _emailCtrl.text.trim();
    if (_dobToApi() != null)
      data['dateOfBirth']     = _dobToApi()!;

    final disc = int.tryParse(_discountCtrl.text) ?? 0;
    data['discountRate'] = disc;

    final ok = await ref.read(customerControllerProvider.notifier)
        .saveB2bCustomer(data, id: _isEdit ? widget.customer!.id : null);

    if (ok && mounted) Navigator.pop(context, true);
    else if (!ok && mounted) {
      final err = ref.read(customerControllerProvider).saveError;
      _snack(err ?? 'Lỗi lưu dữ liệu');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(customerControllerProvider).isSaving;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cs       = Theme.of(context).colorScheme;
    final surf     = isDark ? const Color(0xFF1E293B) : Colors.white;
    const teal     = Color(0xFF0D9488);

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 90),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Handle
            Center(child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2)),
            )),

            // Title
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(_isEdit ? Icons.edit_rounded
                    : Icons.person_add_rounded, size: 18, color: teal),
              ),
              const SizedBox(width: 10),
              Text(_isEdit ? 'Cập nhật khách hàng'
                  : 'Thêm khách hàng Sỉ/Lẻ',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: cs.onSurface)),
            ]),
            const SizedBox(height: 20),

            if (!_isEdit) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(children: [
                  _typeTab('Doanh nghiệp', B2bCustomerType.company,
                      Icons.business_rounded),
                  _typeTab('Khách lẻ', B2bCustomerType.retail,
                      Icons.person_rounded),
                ]),
              ),
              const SizedBox(height: 16),
            ],
            if (_isEdit) const SizedBox(height: 4),

            // ── Mã KH ────────────────────────────────────────────
            FormSectionLabel(label: 'Thông tin cơ bản'),
            const SizedBox(height: 8),
            CustomerFormField(
              controller: _codeCtrl,
              label: 'Mã khách hàng',
              hint:  _type == B2bCustomerType.company
                  ? 'VD: NOK hoặc NOK-01' : 'VD: KLE',
              icon:  Icons.qr_code_rounded,
              required: true,
              readOnly: _isEdit,
            ),
            const SizedBox(height: 10),

            // ── Tên DN (chỉ company) ─────────────────────────────
            if (_type == B2bCustomerType.company) ...[
              CustomerFormField(
                controller: _companyCtrl,
                label: 'Tên doanh nghiệp',
                hint:  'Công ty TNHH ABC',
                icon:  Icons.business_rounded,
              ),
              const SizedBox(height: 10),
              CustomerFormField(
                controller: _shortNameCtrl,
                label: 'Tên rút gọn',
                hint:  'ABC',
                icon:  Icons.badge_rounded,
              ),
              const SizedBox(height: 10),
              CustomerFormField(
                controller: _taxCodeCtrl,
                label: 'Mã số thuế',
                hint:  '0123456789',
                icon:  Icons.receipt_long_rounded,
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 10),
              CustomerFormField(
                controller: _addressCtrl,
                label: 'Địa chỉ công ty',
                hint:  '123 Nguyễn Trãi, Q1, HCM',
                icon:  Icons.location_on_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: 10),
            ],

            // ── Địa chỉ giao hàng ────────────────────────────────
            CustomerFormField(
              controller: _deliveryCtrl,
              label: 'Địa chỉ giao hàng',
              hint:  '456 Lê Lợi, Q1, HCM',
              icon:  Icons.local_shipping_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // ── Người liên hệ ────────────────────────────────────
            FormSectionLabel(label: 'Người liên hệ'),
            const SizedBox(height: 8),
            CustomerFormField(
              controller: _contactCtrl,
              label: 'Chủ / Người liên hệ',
              hint:  'Nguyễn Văn A',
              icon:  Icons.person_rounded,
            ),
            const SizedBox(height: 10),
            DobPickerButton(
              value:    _selectedDob,
              onTap:    _pickDob,
              onClear:  () => setState(() => _selectedDob = null),
            ),
            const SizedBox(height: 10),
            CustomerFormField(
              controller: _phoneCtrl,
              label: 'Số điện thoại',
              hint:  '0938 121 001',
              icon:  Icons.phone_rounded,
              keyboard:   TextInputType.phone,
              formatters: [FilteringTextInputFormatter.allow(
                  RegExp(r'[\d\s+\-]'))],
            ),
            const SizedBox(height: 10),
            CustomerFormField(
              controller: _emailCtrl,
              label: 'Email',
              hint:  'abc@company.com',
              icon:  Icons.email_rounded,
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // ── Chiết khấu ───────────────────────────────────────

            const SizedBox(height: 8),
            CustomerFormField(
              controller: _discountCtrl,
              label: 'Tỷ lệ chiết khấu (%)',
              hint:  '0',
              icon:  Icons.percent_rounded,
              keyboard:   TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 24),

            // ── Save button ──────────────────────────────────────
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isSaving
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : Text(_isEdit ? 'Cập nhật' : 'Thêm khách hàng',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _typeTab(String label, B2bCustomerType type, IconData icon) {
    final active = _type == type;
    const teal   = Color(0xFF0D9488);
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _type = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? teal : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14,
              color: active ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: active ? Colors.white
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          )),
        ]),
      ),
    ));
  }
}