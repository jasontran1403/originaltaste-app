// // lib/features/pos/components/pos_app_discount_sheet.dart
// // Feature 2: nhập khuyến mãi App (2 mode: tiền giảm / giá cuối)
// // Feature 3: nút "Khuyến mãi" trong payment row khi chọn App
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:intl/intl.dart';
//
// // ── Result ────────────────────────────────────────────────────────
//
// class AppDiscountResult {
//   final double discountAmount;
//   final double finalAmount;
//   final bool   isCleared;
//
//   const AppDiscountResult({
//     required this.discountAmount,
//     required this.finalAmount,
//     this.isCleared = false,
//   });
//
//   const AppDiscountResult.cleared()
//       : discountAmount = 0,
//         finalAmount    = 0,
//         isCleared      = true;
// }
//
// // ── Public API ────────────────────────────────────────────────────
//
// Future<AppDiscountResult?> showAppDiscountSheet(
//     BuildContext context, {
//       required double subTotal,
//       double currentDiscount = 0,
//     }) {
//   return showModalBottomSheet<AppDiscountResult>(
//     context:            context,
//     isScrollControlled: true,
//     backgroundColor:    Colors.transparent,
//     builder: (_) => Padding(
//       padding: EdgeInsets.only(
//           bottom: MediaQuery.of(context).viewInsets.bottom),
//       child: _AppDiscountSheet(
//         subTotal:        subTotal,
//         currentDiscount: currentDiscount,
//       ),
//     ),
//   );
// }
//
// // ── Sheet widget ──────────────────────────────────────────────────
//
// class _AppDiscountSheet extends StatefulWidget {
//   final double subTotal;
//   final double currentDiscount;
//
//   const _AppDiscountSheet({
//     required this.subTotal,
//     required this.currentDiscount,
//   });
//
//   @override
//   State<_AppDiscountSheet> createState() => _AppDiscountSheetState();
// }
//
// class _AppDiscountSheetState extends State<_AppDiscountSheet> {
//   bool _isDiscountMode = true;
//   final _ctrl = TextEditingController();
//   String? _error;
//
//   static final _fmt = NumberFormat('#,###', 'vi_VN');
//
//   @override
//   void initState() {
//     super.initState();
//     if (widget.currentDiscount > 0) {
//       _ctrl.text = _fmt.format(widget.currentDiscount.toInt());
//     }
//     _ctrl.addListener(() => setState(() => _error = null));
//   }
//
//   @override
//   void dispose() { _ctrl.dispose(); super.dispose(); }
//
//   double get _rawInput {
//     final s = _ctrl.text.replaceAll(',', '').replaceAll('.', '');
//     return double.tryParse(s) ?? 0;
//   }
//
//   double get _previewDiscount =>
//       _isDiscountMode ? _rawInput : (widget.subTotal - _rawInput);
//
//   double get _previewFinal =>
//       _isDiscountMode ? (widget.subTotal - _rawInput) : _rawInput;
//
//   void _confirm() {
//     final val = _rawInput;
//     if (val <= 0) {
//       setState(() => _error = 'Vui lòng nhập số tiền hợp lệ');
//       return;
//     }
//     if (_previewDiscount < 0 || _previewFinal < 0) {
//       setState(() => _error = _isDiscountMode
//           ? 'Tiền giảm không được lớn hơn tổng tiền'
//           : 'Giá cuối phải nhỏ hơn tổng tiền');
//       return;
//     }
//     Navigator.pop(context, AppDiscountResult(
//       discountAmount: _previewDiscount,
//       finalAmount:    _previewFinal,
//     ));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     const orange = Color(0xFFEE4D2D);
//     final hasPreview = _rawInput > 0 && _previewFinal >= 0;
//
//     return Container(
//       decoration: BoxDecoration(
//         color: cs.surface,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
//       child: Column(mainAxisSize: MainAxisSize.min, children: [
//
//         Center(child: Container(width: 36, height: 4,
//             decoration: BoxDecoration(
//                 color: cs.onSurface.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(2)))),
//         const SizedBox(height: 20),
//
//         // Header
//         Row(children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//                 color: orange.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12)),
//             child: const Icon(Icons.local_offer_rounded,
//                 color: orange, size: 20),
//           ),
//           const SizedBox(width: 14),
//           Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//             const Text('Khuyến mãi App',
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
//             Text('Tạm tính: ${_fmt.format(widget.subTotal.toInt())}đ',
//                 style: TextStyle(fontSize: 12,
//                     color: cs.onSurface.withOpacity(0.55))),
//           ]),
//         ]),
//         const SizedBox(height: 20),
//
//         // Mode toggle
//         Container(
//           decoration: BoxDecoration(
//             color: cs.surfaceContainerHighest,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           padding: const EdgeInsets.all(3),
//           child: Row(children: [
//             _tab('Nhập tiền giảm', true,  orange),
//             _tab('Nhập giá cuối',  false, orange),
//           ]),
//         ),
//         const SizedBox(height: 16),
//
//         // Input
//         TextField(
//           controller:   _ctrl,
//           autofocus:    true,
//           keyboardType: TextInputType.number,
//           inputFormatters: [
//             FilteringTextInputFormatter.digitsOnly,
//             _ThousandFormatter(),
//           ],
//           textAlign: TextAlign.center,
//           style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
//           decoration: InputDecoration(
//             labelText:  _isDiscountMode ? 'Số tiền giảm (đ)' : 'Giá cuối (đ)',
//             suffixText: 'đ',
//             errorText:  _error,
//             filled:     true,
//             fillColor:  cs.surfaceContainerHighest,
//             contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 16, vertical: 16),
//             border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(color: cs.outline)),
//             enabledBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(color: cs.outline)),
//             focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: const BorderSide(color: orange, width: 1.5)),
//             errorBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(color: cs.error)),
//           ),
//           onSubmitted: (_) => _confirm(),
//         ),
//
//         // Preview card
//         if (hasPreview) ...[
//           const SizedBox(height: 12),
//           Container(
//             padding: const EdgeInsets.all(14),
//             decoration: BoxDecoration(
//               color:  orange.withOpacity(0.06),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: orange.withOpacity(0.2)),
//             ),
//             child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('Giảm', style: TextStyle(fontSize: 12,
//                             color: cs.onSurface.withOpacity(0.55))),
//                         Text(
//                           '-${_fmt.format(_previewDiscount.toInt())}đ',
//                           style: const TextStyle(fontSize: 15,
//                               fontWeight: FontWeight.w700, color: orange),
//                         ),
//                       ]),
//                   Column(crossAxisAlignment: CrossAxisAlignment.end,
//                       children: [
//                         Text('Khách trả', style: TextStyle(fontSize: 12,
//                             color: cs.onSurface.withOpacity(0.55))),
//                         Text(
//                           '${_fmt.format(_previewFinal.toInt())}đ',
//                           style: const TextStyle(fontSize: 18,
//                               fontWeight: FontWeight.w800),
//                         ),
//                       ]),
//                 ]),
//           ),
//         ],
//
//         const SizedBox(height: 20),
//
//         // Buttons
//         Row(children: [
//           if (widget.currentDiscount > 0) ...[
//             OutlinedButton.icon(
//               onPressed: () => Navigator.pop(
//                   context, const AppDiscountResult.cleared()),
//               icon: const Icon(Icons.delete_outline_rounded,
//                   size: 16, color: Colors.red),
//               label: const Text('Xóa KM',
//                   style: TextStyle(color: Colors.red, fontSize: 13)),
//               style: OutlinedButton.styleFrom(
//                   side: const BorderSide(color: Colors.red),
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 14, vertical: 14),
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12))),
//             ),
//             const SizedBox(width: 8),
//           ],
//           Expanded(child: OutlinedButton(
//             onPressed: () => Navigator.pop(context, null),
//             style: OutlinedButton.styleFrom(
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12))),
//             child: const Text('Hủy'),
//           )),
//           const SizedBox(width: 10),
//           Expanded(flex: 2, child: FilledButton.icon(
//             onPressed: _confirm,
//             icon:  const Icon(Icons.check_rounded, size: 18),
//             label: const Text('Áp dụng',
//                 style: TextStyle(fontWeight: FontWeight.w700)),
//             style: FilledButton.styleFrom(
//                 backgroundColor: orange,
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12))),
//           )),
//         ]),
//       ]),
//     );
//   }
//
//   Widget _tab(String label, bool mode, Color activeColor) =>
//       Expanded(child: GestureDetector(
//         onTap: () => setState(() {
//           _isDiscountMode = mode;
//           _ctrl.clear();
//           _error = null;
//         }),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 180),
//           padding: const EdgeInsets.symmetric(vertical: 10),
//           decoration: BoxDecoration(
//             color: _isDiscountMode == mode
//                 ? activeColor : Colors.transparent,
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: Text(label,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 13, fontWeight: FontWeight.w700,
//                 color: _isDiscountMode == mode
//                     ? Colors.white
//                     : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
//               )),
//         ),
//       ));
// }
//
// class _ThousandFormatter extends TextInputFormatter {
//   static final _fmt = NumberFormat('#,###', 'vi_VN');
//   @override
//   TextEditingValue formatEditUpdate(
//       TextEditingValue old, TextEditingValue value) {
//     if (value.text.isEmpty) return value;
//     final digits = value.text.replaceAll(',', '');
//     final number = int.tryParse(digits);
//     if (number == null) return old;
//     final formatted = _fmt.format(number);
//     return TextEditingValue(
//         text: formatted,
//         selection: TextSelection.collapsed(offset: formatted.length));
//   }
// }

// lib/features/pos/components/pos_app_discount_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ── Result ────────────────────────────────────────────────────────

class AppDiscountResult {
  final double discountAmount;
  final double finalAmount;
  final bool   isCleared;

  const AppDiscountResult({
    required this.discountAmount,
    required this.finalAmount,
    this.isCleared = false,
  });

  const AppDiscountResult.cleared()
      : discountAmount = 0,
        finalAmount    = 0,
        isCleared      = true;
}

// ── Public API ────────────────────────────────────────────────────

Future<AppDiscountResult?> showAppDiscountSheet(
    BuildContext context, {
      required double subTotal,
      double currentDiscount = 0,
    }) {
  return showModalBottomSheet<AppDiscountResult>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AppDiscountSheet(
        subTotal:        subTotal,
        currentDiscount: currentDiscount,
      ),
    ),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────

class _AppDiscountSheet extends StatefulWidget {
  final double subTotal;
  final double currentDiscount;

  const _AppDiscountSheet({
    required this.subTotal,
    required this.currentDiscount,
  });

  @override
  State<_AppDiscountSheet> createState() => _AppDiscountSheetState();
}

class _AppDiscountSheetState extends State<_AppDiscountSheet> {
  final _ctrl = TextEditingController();
  String? _error;

  static final _fmt = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    if (widget.currentDiscount > 0) {
      _ctrl.text = _fmt.format(widget.currentDiscount.toInt());
    }
    _ctrl.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  double get _rawInput {
    final s = _ctrl.text.replaceAll(',', '').replaceAll('.', '');
    return double.tryParse(s) ?? 0;
  }

  double get _previewFinal => widget.subTotal - _rawInput;

  void _confirm() {
    final val = _rawInput;
    if (val <= 0) {
      setState(() => _error = 'Vui lòng nhập số tiền hợp lệ');
      return;
    }
    if (val >= widget.subTotal) {
      setState(() => _error = 'Tiền giảm không được lớn hơn hoặc bằng tổng tiền');
      return;
    }
    Navigator.pop(context, AppDiscountResult(
      discountAmount: val,
      finalAmount:    _previewFinal,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const orange = Color(0xFFEE4D2D);
    final hasPreview = _rawInput > 0 && _previewFinal >= 0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_offer_rounded,
                color: orange, size: 20),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Khuyến mãi App',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('Tạm tính: ${_fmt.format(widget.subTotal.toInt())}đ',
                style: TextStyle(fontSize: 12,
                    color: cs.onSurface.withOpacity(0.55))),
          ]),
        ]),
        const SizedBox(height: 20),

        // Input
        TextField(
          controller:   _ctrl,
          autofocus:    true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ThousandFormatter(),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText:  'Số tiền giảm (đ)',
            suffixText: 'đ',
            errorText:  _error,
            filled:     true,
            fillColor:  cs.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outline)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outline)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: orange, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.error)),
          ),
          onSubmitted: (_) => _confirm(),
        ),

        // Preview
        if (hasPreview) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:  orange.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: orange.withOpacity(0.2)),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Giảm', style: TextStyle(fontSize: 12,
                            color: cs.onSurface.withOpacity(0.55))),
                        Text(
                          '-${_fmt.format(_rawInput.toInt())}đ',
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w700, color: orange),
                        ),
                      ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Khách trả', style: TextStyle(fontSize: 12,
                            color: cs.onSurface.withOpacity(0.55))),
                        Text(
                          '${_fmt.format(_previewFinal.toInt())}đ',
                          style: const TextStyle(fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                      ]),
                ]),
          ),
        ],

        const SizedBox(height: 20),

        // Buttons
        Row(children: [
          if (widget.currentDiscount > 0) ...[
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(
                  context, const AppDiscountResult.cleared()),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: Colors.red),
              label: const Text('Xóa KM',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Hủy'),
          )),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: FilledButton.icon(
            onPressed: _confirm,
            icon:  const Icon(Icons.check_rounded, size: 18),
            label: const Text('Áp dụng',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
                backgroundColor: orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          )),
        ]),
      ]),
    );
  }
}

class _ThousandFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat('#,###', 'vi_VN');
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue value) {
    if (value.text.isEmpty) return value;
    final digits = value.text.replaceAll(',', '');
    final number = int.tryParse(digits);
    if (number == null) return old;
    final formatted = _fmt.format(number);
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}