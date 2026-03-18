// lib/features/management/screens/manual_import_screen.dart
// 1:1 với GetX gốc (v4):
//   - Fetch ingredients riêng (page=0,size=200) thay vì dùng provider chung
//   - _displayExpiry: ưu tiên hạn mới > hạn cũ ingredient
//   - Popup: batch + conflict dialog
//   - Submit: Navigator.pop(true) + ScaffoldMessenger (không dùng Get.*)
//   - Toast sau pop: dùng rootNavigator context (không bị huỷ theo screen)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/management_models.dart';
import '../../../services/seller_service.dart';

class _BatchRow {
  final IngredientModel ingredient;
  double quantity;
  DateTime? expiryDate;

  _BatchRow({
    required this.ingredient,
    required this.quantity,
    this.expiryDate,
  });
}

class ManualImportScreen extends StatefulWidget {
  const ManualImportScreen({super.key});

  @override
  State<ManualImportScreen> createState() => _ManualImportScreenState();
}

class _ManualImportScreenState extends State<ManualImportScreen> {
  List<IngredientModel> _allIngredients = [];
  List<IngredientModel> _filtered       = [];
  final List<_BatchRow>  _batch         = [];
  bool   _loading    = true;
  bool   _submitting = false;
  String? _error;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  IngredientModel? _selected;
  final _qtyCtrl  = TextEditingController();
  final _qtyFocus = FocusNode();
  DateTime? _popupExpiry;
  String?   _popupError;

  @override
  void initState() {
    super.initState();
    _fetchIngredients();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _qtyFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Fetch ─────────────────────────────────────────────────────────

  Future<void> _fetchIngredients() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await SellerService.instance
          .getIngredients(page: 0, size: 200);
      if (result.isSuccess && result.data != null) {
        setState(() {
          _allIngredients = result.data!;
          _filtered       = List.from(_allIngredients);
          _loading        = false;
        });
      } else {
        setState(() {
          _error   = result.message ?? 'Lỗi tải nguyên liệu';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Search ────────────────────────────────────────────────────────

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        _filtered = q.isEmpty
            ? List.from(_allIngredients)
            : _allIngredients
            .where((i) => i.name.toLowerCase().contains(q))
            .toList();
      });
    });
  }

  // ── Popup ─────────────────────────────────────────────────────────

  void _openPopup(IngredientModel ing) {
    setState(() {
      _selected    = ing;
      _qtyCtrl.text = '';
      _popupExpiry = null;
      _popupError  = null;
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _qtyFocus.requestFocus());
  }

  void _closePopup() => setState(() {
    _selected    = null;
    _qtyCtrl.text = '';
    _popupExpiry = null;
    _popupError  = null;
  });

  Future<void> _pickExpiryDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _popupExpiry ?? now.add(const Duration(days: 30)),
      firstDate:   now.subtract(const Duration(days: 1)),
      lastDate:    DateTime(now.year + 10),
      helpText:    'Chọn hạn dùng',
    );
    if (picked != null) setState(() => _popupExpiry = picked);
  }

  void _confirmAdd() {
    final qty = double.tryParse(
        _qtyCtrl.text.trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      setState(() => _popupError = 'Số lượng phải lớn hơn 0');
      return;
    }

    final ing      = _selected!;
    final existIdx = _batch.indexWhere((r) => r.ingredient.id == ing.id);

    if (existIdx >= 0) {
      final existing   = _batch[existIdx];
      final sameExpiry =
          (_popupExpiry == null && existing.expiryDate == null) ||
              (_popupExpiry != null &&
                  existing.expiryDate != null &&
                  _popupExpiry!.year  == existing.expiryDate!.year &&
                  _popupExpiry!.month == existing.expiryDate!.month &&
                  _popupExpiry!.day   == existing.expiryDate!.day);

      if (sameExpiry) {
        setState(() => _batch[existIdx].quantity += qty);
        _closePopup();
      } else {
        _showDateConflictDialog(existIdx, qty, _popupExpiry);
      }
    } else {
      setState(() => _batch.add(_BatchRow(
        ingredient: ing,
        quantity:   qty,
        expiryDate: _popupExpiry,
      )));
      _closePopup();
    }
  }

  void _showDateConflictDialog(
      int idx, double addQty, DateTime? newExpiry) {
    final ing     = _batch[idx].ingredient;
    final oldDate = _batch[idx].expiryDate;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 24),
          SizedBox(width: 8),
          Text('Hạn dùng khác nhau'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nguyên liệu "${ing.name}" đã có trong phiếu.'),
            const SizedBox(height: 4),
            const Text('Số lượng sẽ được cộng dồn.',
                style: TextStyle(
                    color: Color(0xFF009688),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _dateRow('Hạn hiện tại:', oldDate),
            _dateRow('Hạn mới nhập:', newExpiry),
            const SizedBox(height: 12),
            const Text('Ghi đè hạn dùng?'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Chỉnh sửa lại')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688)),
            onPressed: () {
              setState(() {
                _batch[idx].quantity   += addQty;
                _batch[idx].expiryDate = newExpiry;
              });
              Navigator.pop(ctx);
              _closePopup();
            },
            child: const Text('Ghi đè & cộng dồn',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(String label, DateTime? date) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(
          width: 130,
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600))),
      Text(
        date != null
            ? DateFormat('dd/MM/yyyy').format(date)
            : '-- Không có --',
        style: TextStyle(
            color: date == null
                ? Colors.grey
                : const Color(0xFF009688)),
      ),
    ]),
  );

  /// Hiển thị hạn dùng đẹp nhất: ưu tiên hạn mới còn hạn,
  /// fallback sang hạn của ingredient gốc
  String _displayExpiry(_BatchRow row) {
    final newExpiry = row.expiryDate;
    final oldExpiry = row.ingredient.expiryDate != null
        ? DateTime.fromMillisecondsSinceEpoch(
        row.ingredient.expiryDate!)
        : null;
    if (newExpiry == null && oldExpiry == null) return '--';
    final now = DateTime.now();
    if (newExpiry != null && newExpiry.isAfter(now)) {
      if (oldExpiry == null || newExpiry.isBefore(oldExpiry)) {
        return DateFormat('dd/MM/yyyy').format(newExpiry);
      }
      return DateFormat('dd/MM/yyyy').format(oldExpiry);
    }
    if (oldExpiry != null && oldExpiry.isAfter(now)) {
      return DateFormat('dd/MM/yyyy').format(oldExpiry);
    }
    final fallback = newExpiry ?? oldExpiry;
    return fallback != null
        ? DateFormat('dd/MM/yyyy').format(fallback)
        : '--';
  }

  // ── Submit ────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_batch.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận nhập kho'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập ${_batch.length} nguyên liệu vào kho?'),
            const SizedBox(height: 8),
            ..._batch.map((r) => Padding(
              padding:
              const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                const Icon(Icons.fiber_manual_record,
                    size: 6, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${r.ingredient.name}: '
                        '+${_fmtQty(r.quantity)} '
                        '${r.ingredient.unit}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            )),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nhập kho',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _submitting = true);

    try {
      final result = await SellerService.instance
          .manualImportIngredients(
        _batch
            .map((r) => ManualImportItem(
          ingredientId: r.ingredient.id,
          quantity:     r.quantity,
          expiryDate:
          r.expiryDate?.millisecondsSinceEpoch,
        ))
            .toList(),
      );

      print('API manualImportIngredients RESPONSE:');
      print('  isSuccess: ${result.isSuccess}');
      print('  message: ${result.message}');
      print('  data: ${result.data}'); // in batchCode nếu có

      if (result.isSuccess) {
        final batchCode = result.data?.batchCode ?? '';
        final count     = _batch.length;

        print('Batch code: ${result.data?.batchCode ?? 'không có'}');
        print('Số lượng nhập: ${_batch.length}');

        if (!context.mounted) return;
        // Pop trước, snackbar dùng rootScaffold (context of parent)
        Navigator.pop(context, true);

        await Future.delayed(const Duration(milliseconds: 100));
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Batch $batchCode — $count nguyên liệu nhập thành công'),
            backgroundColor: const Color(0xFF009688),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text(result.message ?? 'Nhập kho thất bại'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AppColors.darkBg    : const Color(0xFFF5F6FA);
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final top       = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Nội dung chính (scrollable)
          Column(
            children: [
              // App bar
              Container(
                padding: EdgeInsets.fromLTRB(4, top + 8, 16, 12),
                color: cardBg,
                child: Row(children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: onBg),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C6BC0).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFF5C6BC0), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Nhập kho thủ công',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg)),
                ]),
              ),
              Container(height: 1, color: border),

              // Nội dung scrollable
              Expanded(
                child: _buildBody(isDark, bg, cardBg, border, onBg, secondary),
              ),
            ],
          ),

          // Bottom fixed buttons (luôn ở dưới cùng, không bị đẩy lên)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),

          // Popup overlay (nếu có)
          if (_selected != null)
            _buildPopupOverlay(cardBg, border, onBg, secondary),

          // Submitting overlay
          if (_submitting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, Color bg, Color cardBg,
      Color border, Color onBg, Color secondary) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: AppColors.error)),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: _fetchIngredients,
              child: const Text('Thử lại')),
        ]),
      );
    }
    return LayoutBuilder(
      builder: (_, constraints) => constraints.maxWidth > 700
          ? _buildWideLayout(cardBg, border, onBg, secondary)
          : _buildNarrowLayout(cardBg, border, onBg, secondary),
    );
  }

  // ── Layouts ───────────────────────────────────────────────────────

  Widget _buildWideLayout(Color cardBg, Color border,
      Color onBg, Color secondary) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 420,
            child:
            _buildBatchPanel(cardBg, border, onBg, secondary)),
        Container(width: 1, color: border),
        Expanded(
            child: _buildIngredientPanel(
                cardBg, border, onBg, secondary)),
      ]);

  Widget _buildNarrowLayout(Color cardBg, Color border,
      Color onBg, Color secondary) =>
      Column(children: [
        if (_batch.isNotEmpty) ...[
          _buildBatchPanel(cardBg, border, onBg, secondary),
          Container(height: 1, color: border),
        ],
        Expanded(
            child: _buildIngredientPanel(
                cardBg, border, onBg, secondary)),
      ]);

  double get _bottomPad => MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first).padding.bottom;

  // ── Batch panel ───────────────────────────────────────────────────

  Widget _buildBatchPanel(Color cardBg, Color border, Color onBg, Color secondary) {
    return Container(
      color: cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header phiếu nhập
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF009688).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_batch.length} mục',
                    style: const TextStyle(
                      color: Color(0xFF009688),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    )),
              ),
              const SizedBox(width: 8),
              Text('Phiếu nhập',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: onBg,
                  )),
            ]),
          ),

          // Header table (nếu có batch)
          if (_batch.isNotEmpty) ...[
            Container(
              color: const Color(0xFFF8F9FA),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Expanded(flex: 3, child: _thCell('Nguyên liệu', secondary)),
                Expanded(flex: 2, child: _thCell('Số lượng', secondary, center: true)),
                Expanded(flex: 2, child: _thCell('Hạn dùng', secondary, center: true)),
                const SizedBox(width: 32),
              ]),
            ),
            Divider(height: 0, color: border),
          ],

          // Danh sách batch (scrollable)
          Expanded(
            child: _batch.isEmpty
                ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inbox_outlined,
                    size: 48, color: secondary.withOpacity(0.3)),
                const SizedBox(height: 8),
                Text('Chưa có nguyên liệu nào',
                    style: TextStyle(color: secondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Chọn từ danh sách bên phải',
                    style: TextStyle(color: secondary, fontSize: 12)),
              ]),
            )
                : ListView.separated(
              itemCount: _batch.length,
              separatorBuilder: (_, __) => Divider(height: 0, color: border),
              itemBuilder: (_, i) => _buildBatchRow(i, cardBg, secondary),
            ),
          ),

          // Nút bottom cố định ở đáy panel Phiếu nhập
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + _bottomPad + 80),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _batch.isEmpty ? null : () => setState(() => _batch.clear()),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('Xóa tất cả'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_batch.isEmpty || _submitting) ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_submitting ? 'Đang nhập...' : 'Nhập kho'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _thCell(String text, Color secondary,
      {bool center = false}) =>
      Text(text,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: secondary),
          textAlign:
          center ? TextAlign.center : TextAlign.left);

  Widget _buildBatchRow(
      int i, Color cardBg, Color secondary) {
    final row        = _batch[i];
    final expiryStr  = _displayExpiry(row);
    final isNear     = row.expiryDate != null &&
        row.expiryDate!.isBefore(
            DateTime.now().add(const Duration(days: 30)));

    return Container(
      color: cardBg,
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(row.ingredient.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  Text(row.ingredient.unit,
                      style: TextStyle(
                          fontSize: 11, color: secondary)),
                ])),
        Expanded(
            flex: 2,
            child: Text(
                '${_fmtQty(row.quantity)} '
                    '${row.ingredient.unit}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF009688),
                    fontSize: 13),
                textAlign: TextAlign.center)),
        Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isNear
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(expiryStr,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isNear
                          ? Colors.orange.shade700
                          : Colors.grey.shade700),
                  textAlign: TextAlign.center),
            )),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => setState(() => _batch.removeAt(i)),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(
                Icons.remove_circle_outline,
                size: 16, color: Colors.red),
          ),
        ),
      ]),
    );
  }

  // ── Ingredient panel ──────────────────────────────────────────────

  Widget _buildIngredientPanel(Color cardBg, Color border,
      Color onBg, Color secondary) {
    return Column(children: [
      Container(
        color: cardBg,
        padding:
        const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(fontSize: 14, color: onBg),
          decoration: InputDecoration(
            hintText:  'Tìm nguyên liệu...',
            hintStyle: TextStyle(
                color: secondary, fontSize: 14),
            prefixIcon: Icon(Icons.search,
                color: secondary, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                icon: Icon(Icons.clear,
                    size: 16, color: secondary),
                onPressed: _searchCtrl.clear)
                : null,
            filled:    true,
            fillColor: secondary.withOpacity(0.06),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: Color(0xFF009688), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
        ),
      ),
      Divider(height: 0, color: border),
      Expanded(
        child: _filtered.isEmpty
            ? Center(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 40,
                      color: secondary.withOpacity(0.3)),
                  const SizedBox(height: 8),
                  Text('Không tìm thấy',
                      style: TextStyle(color: secondary)),
                ]))
            : ListView.builder(
          itemCount: _filtered.length,
          itemBuilder: (_, i) => _buildIngredientTile(
              _filtered[i],
              cardBg, border, onBg, secondary),
        ),
      ),
    ]);
  }

  Widget _buildIngredientTile(IngredientModel ing,
      Color cardBg, Color border, Color onBg, Color secondary) {
    final row     = _batch
        .where((r) => r.ingredient.id == ing.id)
        .firstOrNull;
    final inBatch = row != null;

    return InkWell(
      onTap: () => _openPopup(ing),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: inBatch
              ? const Color(0xFF009688).withOpacity(0.04)
              : cardBg,
          border: Border(
              bottom: BorderSide(
                  color: border.withOpacity(0.5))),
        ),
        child: Row(children: [
          Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: inBatch
                    ? const Color(0xFF009688).withOpacity(0.12)
                    : secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                inBatch
                    ? Icons.check_circle_rounded
                    : Icons.inventory_2_outlined,
                color: inBatch
                    ? const Color(0xFF009688)
                    : secondary,
                size: 18,
              )),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ing.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: inBatch
                              ? const Color(0xFF009688)
                              : onBg)),
                  Row(children: [
                    Text(
                        'Tồn: ${_fmtQty(ing.stockQuantity)} '
                            '${ing.unit}',
                        style: TextStyle(
                            fontSize: 11, color: secondary)),
                    if (inBatch) ...[
                      Text(' · ',
                          style: TextStyle(
                              color: secondary,
                              fontSize: 11)),
                      Text(
                          'Nhập: +${_fmtQty(row.quantity)} '
                              '${ing.unit}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF009688),
                              fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ]),
          ),
          Icon(Icons.add_circle_outline_rounded,
              color: inBatch
                  ? const Color(0xFF009688)
                  : secondary,
              size: 20),
        ]),
      ),
    );
  }

  // ── Popup overlay + card ──────────────────────────────────────────

  Widget _buildPopupOverlay(Color cardBg, Color border,
      Color onBg, Color secondary) =>
      GestureDetector(
        onTap: _closePopup,
        child: Container(
          color: Colors.black.withOpacity(0.45),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: _buildPopupCard(
                  cardBg, border, onBg, secondary),
            ),
          ),
        ),
      );

  Widget _buildPopupCard(Color cardBg, Color border,
      Color onBg, Color secondary) {
    final ing      = _selected!;
    final existRow = _batch
        .where((r) => r.ingredient.id == ing.id)
        .firstOrNull;
    final hasExisting = existRow != null;

    return Container(
      width: 380,
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 30,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF009688).withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color:
                  const Color(0xFF009688).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.inventory_2_outlined,
                  color: Color(0xFF009688), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ing.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: onBg)),
                    Row(children: [
                      Text(
                          'Tồn: ${_fmtQty(ing.stockQuantity)} '
                              '${ing.unit}',
                          style: TextStyle(
                              fontSize: 11, color: secondary)),
                      if (hasExisting) ...[
                        Text(' · ',
                            style: TextStyle(
                                color: secondary,
                                fontSize: 11)),
                        Text(
                            'Đang nhập: '
                                '${_fmtQty(existRow.quantity)} '
                                '${ing.unit}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF009688),
                                fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ]),
            ),
            IconButton(
              onPressed: _closePopup,
              icon: Icon(Icons.close_rounded,
                  size: 20, color: secondary),
              padding: EdgeInsets.zero,
            ),
          ]),
        ),

        // Form
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasExisting) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFF009688).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF009688)
                              .withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.add_circle_outline,
                          size: 14, color: Color(0xFF009688)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Số lượng sẽ cộng thêm vào '
                              '${_fmtQty(existRow.quantity)} '
                              '${ing.unit} hiện có',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF009688)),
                        ),
                      ),
                    ]),
                  ),
                ],

                Text('Số lượng thêm *',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: onBg)),
                const SizedBox(height: 6),
                TextField(
                  controller: _qtyCtrl,
                  focusNode:  _qtyFocus,
                  keyboardType:
                  const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*[,.]?\d{0,2}'))
                  ],
                  onChanged: (_) =>
                      setState(() => _popupError = null),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: onBg),
                  decoration: InputDecoration(
                    hintText:    '0.00',
                    hintStyle:
                    TextStyle(color: secondary),
                    suffixText:  ing.unit,
                    suffixStyle: const TextStyle(
                        color: Color(0xFF009688),
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                    border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF009688),
                            width: 1.5)),
                    errorText:      _popupError,
                    contentPadding:
                    const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),

                const SizedBox(height: 16),
                Text('Hạn dùng',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: onBg)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickExpiryDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _popupExpiry != null
                              ? const Color(0xFF009688)
                              : border),
                      borderRadius: BorderRadius.circular(10),
                      color: _popupExpiry != null
                          ? const Color(0xFF009688)
                          .withOpacity(0.04)
                          : Colors.transparent,
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 18,
                          color: _popupExpiry != null
                              ? const Color(0xFF009688)
                              : secondary),
                      const SizedBox(width: 10),
                      Text(
                          _popupExpiry != null
                              ? DateFormat('dd/MM/yyyy')
                              .format(_popupExpiry!)
                              : 'Chọn ngày hết hạn',
                          style: TextStyle(
                              fontSize: 14,
                              color: _popupExpiry != null
                                  ? onBg
                                  : secondary,
                              fontWeight: _popupExpiry != null
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                      const Spacer(),
                      if (_popupExpiry != null)
                        GestureDetector(
                          onTap: () => setState(
                                  () => _popupExpiry = null),
                          child: Icon(Icons.clear,
                              size: 16, color: secondary),
                        )
                      else
                        Icon(Icons.chevron_right,
                            size: 18, color: secondary),
                    ]),
                  ),
                ),

                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _closePopup,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 13),
                        side: BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(10)),
                      ),
                      child: Text('Hủy',
                          style:
                          TextStyle(color: secondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _confirmAdd,
                      icon: Icon(
                          hasExisting
                              ? Icons.add
                              : Icons.add_circle_outline,
                          size: 16),
                      label: Text(hasExisting
                          ? 'Cộng thêm'
                          : 'Thêm vào phiếu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color(0xFF009688),
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(
                            vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
              ]),
        ),
      ]),
    );
  }

  String _fmtQty(double q) => q == q.truncateToDouble()
      ? q.toInt().toString()
      : q.toStringAsFixed(2);
}