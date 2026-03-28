// lib/features/pos/screens/pos_product_grid_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/data/models/pos/pos_product_model.dart';
import 'package:originaltaste/data/models/pos/pos_cart_model.dart';
import 'package:originaltaste/data/models/pos/pos_shift_model.dart';
import 'package:originaltaste/data/models/pos/pos_order_model.dart';
import 'package:originaltaste/data/models/pos/pos_discount_model.dart';
import 'package:originaltaste/features/pos/components/pos_order_mode.dart';
import 'package:originaltaste/features/pos/screens/pos_import_stock_screen.dart';
import 'package:originaltaste/features/pos/screens/pos_shift_screen.dart';
import 'package:originaltaste/features/pos/components/pos_variant_modal.dart';
import 'package:originaltaste/features/pos/components/pos_quick_add_sheet.dart';
import 'package:originaltaste/features/pos/components/pos_customer_sheet.dart';
import 'package:originaltaste/services/pos_printer_service.dart';
import 'package:originaltaste/features/pos/components/printer_settings_dialog.dart';
import 'package:originaltaste/features/pos/components/pos_weight_sheet.dart';
import 'package:originaltaste/features/pos/components/pos_app_discount_sheet.dart';
import 'package:originaltaste/features/pos/components/pos_app_item_price_sheet.dart';

import '../../../shared/widgets/network_image_viewer.dart';

class PosProductGridScreen extends StatefulWidget {
  const PosProductGridScreen({super.key});

  @override
  State<PosProductGridScreen> createState() => _PosProductGridScreenState();
}

class _PosProductGridScreenState extends State<PosProductGridScreen> {
  PosCategoryModel? _selectedCat;
  PosOrderSource    _orderSource             = PosOrderSource.takeAway;
  String            _paymentMethod           = 'CASH';
  bool              _isLoadingProducts       = false;
  bool              _isLoadingCategories     = true;
  bool              _isCreatingOrder         = false;
  bool              _isConnectingPrinter     = false;
  bool              _printerConnected        = false;
  final ScrollController _cartScroll = ScrollController();

  List<PosCategoryModel> _categories   = [];
  List<PosProductModel>  _products     = [];
  PosShiftModel?         _currentShift;

  static final List<CartItem> _persistedCart = [];
  List<CartItem> get _cart => _persistedCart;

  Orientation? _lastOrientation;

  double _appDiscountAmount = 0;   // tiền giảm app (Shopee/Grab)
  double _appFinalOverride  = 0; // 0 = không override

  static double _roundToThousand(double price) {
    final remainder = price % 1000;
    return remainder >= 500
        ? price - remainder + 1000
        : price - remainder;
  }

  // ── Customer + Discount state ─────────────────────────────────
  PosCustomerInfo?      _customer;
  CustomerDiscountInfo? _activeDiscount;
  int?                  _discountItemProductId;

  bool get _canShopee => _cart.every((i) => i.product.isShopeeFood);
  bool get _canGrab   => _cart.every((i) => i.product.isGrabFood);
  double get _subTotal => _cart.fold(0.0, (s, i) => s + i.subtotal);

  Map<int, double> get _vatBreakdown {
    final map = <int, double>{};
    for (final item in _cart) {
      final pct = item.product.vatPercent;
      if (pct > 0) map.update(pct, (v) => v + item.subtotal * pct / 100,
          ifAbsent: () => item.subtotal * pct / 100);
    }
    return map;
  }

  double get _totalVat => _vatBreakdown.values.fold(0.0, (s, v) => s + v);

  double get _discountAmount {
    final opt = _activeDiscount?.selectedOption;
    if (_activeDiscount == null || opt == null) return 0;
    if (_activeDiscount!.exhausted) return 0;

    double base;
    if (opt.discountType.isItemType) {
      base = _discountItemProductId == null
          ? 0
          : _cart
          .where((c) => c.product.id == _discountItemProductId)
          .fold(0.0, (s, c) => s + c.subtotal);
    } else {
      base = _subTotal;
    }

    final raw       = opt.calculate(base);
    final remaining = _activeDiscount!.budgetRemaining;
    return raw.clamp(0, remaining);
  }

  double get _grandTotal {
    final base = (_subTotal + _totalVat - _discountAmount);
    if (_isAppOrder && _appDiscountAmount > 0) {
      return (base - _appDiscountAmount).clamp(0, double.infinity);
    }
    return base.clamp(0, double.infinity);
  }

  bool get _isAppOrder =>
      _orderSource == PosOrderSource.shopeeFood ||
          _orderSource == PosOrderSource.grabFood;

  double get _platformRate {
    if (_orderSource == PosOrderSource.shopeeFood)
      return PrinterConfig.shopeeRate;
    if (_orderSource == PosOrderSource.grabFood)
      return PrinterConfig.grabRate;
    return 0.0;
  }

// Phí sàn = (subTotal - appDiscountAmount) × rate
  double get _platformFee {
    if (!_isAppOrder) return 0.0;
    final afterDiscount = (_subTotal - _appDiscountAmount).clamp(0.0, double.infinity);
    return (afterDiscount * _platformRate).roundToDouble();
  }

// Tiền thực nhận = (subTotal - appDiscountAmount) - platformFee
  double get _netRevenue {
    if (!_isAppOrder) return _grandTotal;
    final afterDiscount = (_subTotal - _appDiscountAmount).clamp(0.0, double.infinity);
    // Làm tròn: >= .5 lên, < .5 xuống
    return (afterDiscount * (1 - _platformRate) * 100).roundToDouble() / 100;
  }


  int get _cartCount => _cart.fold(0, (s, i) => s + i.quantity);

  double get _scaleFactor {
    final width = MediaQuery.of(context).size.width;
    return (width / 1024).clamp(0.75, 1.3);
  }

  void _clearAppDiscount() => setState(() {
    _appDiscountAmount = 0;
    _appFinalOverride  = 0;
  });

  Future<void> _openAppDiscountSheet() async {
    final result = await showAppDiscountSheet(
      context,
      subTotal:        _subTotal,
      currentDiscount: _appDiscountAmount,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.isCleared) {
        _appDiscountAmount = 0;
        _appFinalOverride  = 0;
      } else {
        _appDiscountAmount = result.discountAmount;
        _appFinalOverride  = result.finalAmount;
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadAll();
    _initPrinter();
  }

  @override
  void dispose() {
    _cartScroll.dispose();
    if (_lastOrientation != Orientation.landscape) {
      _persistedCart.clear();
      _appDiscountAmount = 0;
      _appFinalOverride  = 0;
    }
    _lastOrientation = null;
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadCategories(), _loadShift()]);
  }

  Future<void> _initPrinter() async {
    setState(() => _isConnectingPrinter = true);
    final ok = await PrinterConfig.loadStoreAndConnect();
    if (mounted) setState(() {
      _printerConnected    = ok;
      _isConnectingPrinter = false;
    });
  }

  Future<void> _loadShift() async {
    try {
      final s = await PosService.instance.getCurrentShift();
      if (mounted) setState(() => _currentShift = s);
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await PosService.instance.getCategories();
      if (mounted) {
        setState(() {
          _categories          = cats
            ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
          _isLoadingCategories = false;
          if (cats.isNotEmpty) {
            _selectedCat = cats.first;
            _loadProducts(cats.first.id);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadProducts(int catId) async {
    setState(() => _isLoadingProducts = true);
    try {
      final list = await PosService.instance.getProducts(categoryId: catId);
      if (mounted) {
        setState(() {
          _products = list..sort((a, b) {
            final ao = a.displayOrder == 0 ? 999999 : a.displayOrder;
            final bo = b.displayOrder == 0 ? 999999 : b.displayOrder;
            final c  = ao.compareTo(bo);
            return c != 0 ? c : a.name.compareTo(b.name);
          });
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Cart helpers
  // ═══════════════════════════════════════════════════════════════

  void _addToCart(CartItem item) {
    setState(() {
      final idx = _cart.indexWhere((c) =>
      c.product.id == item.product.id &&
          c.selectedPrice.discountPercent == item.selectedPrice.discountPercent &&
          _selectionsEqual(c.variantSelections, item.variantSelections));
      if (idx >= 0) {
        _cart[idx] = _cart[idx].copyWith(quantity: _cart[idx].quantity + 1);
      } else {
        _cart.add(item);
      }
    });
    _scrollToCartBottom();
  }

  void _scrollToCartBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cartScroll.hasClients) {
        _cartScroll.animateTo(_cartScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut);
      }
    });
  }

  void _updateQty(int idx, int delta) {
    setState(() {
      final newQty = _cart[idx].quantity + delta;
      if (newQty <= 0) _cart.removeAt(idx);
      else _cart[idx] = _cart[idx].copyWith(quantity: newQty);
    });
  }

  void _removeFromCart(int idx) => setState(() => _cart.removeAt(idx));

  bool _selectionsEqual(
      List<VariantGroupSelection> a, List<VariantGroupSelection> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].variantId != b[i].variantId) return false;
      if (!_mapEq(a[i].selectedIngredients, b[i].selectedIngredients)) return false;
    }
    return true;
  }

  bool _mapEq(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) { if (a[k] != b[k]) return false; }
    return true;
  }

  // ═══════════════════════════════════════════════════════════════
  // Customer sheet
  // ═══════════════════════════════════════════════════════════════

  Future<void> _openCustomerSheet() async {
    final result = await showPosCustomerSheet(
      context, current: _customer, cartItems: _cart,
    );
    if (result != null && mounted) {
      setState(() {
        _customer              = result.customer;
        _activeDiscount        = result.discount;
        _discountItemProductId = result.discountItemProductId;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Create order + auto print
  // ═══════════════════════════════════════════════════════════════

  Future<void> _openWeightSheet(int idx) async {
    final updated = await showPosWeightSheet(context, _cart[idx]);
    if (updated != null && mounted) {
      setState(() => _cart[idx] = updated);
    }
  }

  Future<void> _createOrder() async {
    if (_cart.isEmpty) return;
    if (_currentShift == null || !_currentShift!.isOpen) {
      _snack('Chưa mở ca. Vui lòng mở ca để bán hàng.');
      return;
    }
    setState(() => _isCreatingOrder = true);
    try {
      final order = await PosService.instance.createOrder(
        orderSource:           _orderSource.apiValue,
        paymentMethod:         _paymentMethod,
        cartItems:             _cart,
        customerPhone:         _customer?.phone,
        customerName:          _customer?.name,
        customerDiscountId:    _activeDiscount?.id,
        discountItemProductId: _discountItemProductId,
        appDiscountAmount: _isAppOrder ? _appDiscountAmount : null,
        appFinalAmount:    _isAppOrder && _appFinalOverride > 0
            ? _appFinalOverride
            : null,
      );

      final customerPhone = _customer?.phone;
      final customerName  = _customer?.name;

      // Lấy snapshot cart TRƯỚC khi clear — dùng để ghép addon vào bill
      final cartSnapshot  = List<CartItem>.from(_cart);

      setState(() {
        _cart.clear();
        _customer              = null;
        _activeDiscount        = null;
        _discountItemProductId = null;

        // === THÊM ===
        _appDiscountAmount = 0;
        _appFinalOverride  = 0;
        // ============
      });

      _autoPrint(order,
        customerPhone: customerPhone,
        customerName:  customerName,
        cartSnapshot:  cartSnapshot,
      );
      _showSuccessDialog(order);
    } catch (e) {
      _snack('Lỗi tạo đơn: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
  }

  // ── Auto print ───────────────────────────────────────────────
  void _autoPrint(
      PosOrderModel order, {
        String?        customerPhone,
        String?        customerName,
        List<CartItem> cartSnapshot = const [],
      }) {
    if (!PrinterConfig.isConnected) return;
    if (cartSnapshot.isEmpty) return; // Không có gì để in

    final phone = (customerPhone?.trim().isNotEmpty == true) ? customerPhone : null;
    final name  = (customerName?.trim().isNotEmpty  == true) ? customerName  : null;

    // ── Build BillItem từ cartSnapshot (KHÔNG dùng order.items) ──
    // order.items có thể rỗng do JPA lazy loading sau khi transaction đóng.
    // cartSnapshot luôn có đầy đủ dữ liệu vì được lấy trước khi clear cart.
    final billItems = cartSnapshot.map((cartItem) {
      // Collect addons của cart item này
      final addons = <BillAddon>[];
      for (final sel in cartItem.variantSelections) {
        if (!sel.isAddonGroup || sel.addonItems == null) continue;
        for (final a in sel.addonItems!) {
          if (a.quantity <= 0) continue;
          addons.add(BillAddon(
            name:      a.ingredientName,
            quantity:  a.quantity,
            unitPrice: a.discountedAddonPrice,
          ));
        }
      }
      return BillItem(
        name:            cartItem.product.name,
        quantity:        cartItem.quantity,
        unitPrice:       cartItem.selectedPrice.price,
        discountPercent: cartItem.selectedPrice.discountPercent,
        addons:          addons,
      );
    }).toList();

    final bill = BillData(
      orderCode:      order.orderCode,
      printTime:      DateTime.fromMillisecondsSinceEpoch(order.createdAt),
      cashierName:    _currentShift?.staffName ?? '',
      customerPhone:  phone,
      customerName:   name,
      orderSource:    order.orderSource,
      items:          billItems,
      subTotal:       order.totalAmount,
      discountAmount: order.discountAmount,
      vatAmount:      0,
      finalAmount:    order.finalAmount,
      paymentMethod:  order.paymentMethod,
      platformFee:  _isAppOrder ? _platformFee  : 0,   // ← THÊM
      platformRate: _isAppOrder ? _platformRate : 0,   // ← THÊM
      netRevenue:   _isAppOrder ? _netRevenue   : 0,   // ← THÊM
    );

    PosPrinterService.instance.print(bill).then((result) {
      if (!result.isSuccess && mounted) {
        _snack('Lỗi in bill: ${result.errorMessage}', isError: true);
        setState(() => _printerConnected = false);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Snack / dialog
  // ═══════════════════════════════════════════════════════════════

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessDialog(PosOrderModel order) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.check_circle_rounded, color: cs.primary, size: 32),
          const SizedBox(width: 12),
          Text('Tạo đơn thành công',
              style: TextStyle(color: cs.primary,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mã đơn: ${order.orderCode}',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const SizedBox(height: 8),
              Text('Tổng tiền: ${_fmt(order.finalAmount)}đ',
                  style: const TextStyle(fontSize: 16)),
              if (_printerConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Icon(Icons.print_rounded, size: 14,
                        color: cs.primary.withOpacity(0.7)),
                    const SizedBox(width: 5),
                    Text('Đang in bill...',
                        style: TextStyle(fontSize: 13,
                            color: cs.primary.withOpacity(0.7))),
                  ]),
                ),
            ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Đóng', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Navigation
  // ═══════════════════════════════════════════════════════════════

  void _onTapProduct(PosProductModel p) {
    if (_currentShift == null || !_currentShift!.isOpen) {
      _snack('Chưa mở ca. Vui lòng mở ca để bán hàng.');
      return;
    }
    _showQuickAdd(p);
  }

  List<VariantGroupSelection>? _savedSelections;
  String? _savedNote;

  void _showQuickAdd(PosProductModel p, {PriceOption? fixedPrice}) {
    _savedSelections = null;
    _savedNote       = null;

    PriceOption effectivePrice;
    if (_orderSource == PosOrderSource.shopeeFood ||
        _orderSource == PosOrderSource.grabFood) {
      final platform = _orderSource == PosOrderSource.shopeeFood
          ? 'SHOPEE_FOOD' : 'GRAB_FOOD';
      final appMenu  = p.appMenus.firstWhere(
            (m) => m.platform == platform && m.isActive,
        orElse: () => AppMenuModel(id: 0, platform: platform,
            price: p.basePrice, isActive: false),
      );
      effectivePrice = appMenu.isActive
          ? PriceOption(discountPercent: 0, price: appMenu.price,
          label: _orderSource == PosOrderSource.shopeeFood
              ? 'Giá Shopee' : 'Giá Grab')
          : fixedPrice ?? p.priceOptions.first;
    } else {
      effectivePrice = fixedPrice ?? PriceOption(
        discountPercent: p.priceOptions.first.discountPercent,
        price: _roundToThousand(p.priceOptions.first.price),
        label: p.priceOptions.first.label,
      );
    }

    showModalBottomSheet<QuickAddResult>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: PosQuickAddSheet(
          product:            p,
          initialPrice:       effectivePrice,
          fixedPrice:         effectivePrice,
          savedSelections:    _savedSelections,
          savedNote:          _savedNote,
          onOpenVariantModal: (price) => _showVariantModal(p, price),
          onQuickAdd: (price) {
            Navigator.pop(context);
            _addToCart(CartItem(
              product:           p,
              selectedPrice:     price,
              variantSelections: buildQuickAddSelections(p),
              quantity:          1,
            ));
          },
        ),
      ),
    ).then((result) {
      if (result != null) {
        _addToCart(CartItem(
          product:           p,
          selectedPrice:     result.price,
          variantSelections: result.selections,
          quantity:          1,
          note:              result.note,
        ));
      }
    });
  }

  void _showVariantModal(PosProductModel p, PriceOption price) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: PosVariantModal(
          product:       p,
          selectedPrice: price,
          onConfirm: (selections, note) {
            _savedSelections = selections;
            _savedNote       = note;
            Navigator.pop(context);
            _showQuickAddWithSelections(p, price, selections, note);
          },
        ),
      ),
    );
  }

  void _showQuickAddWithSelections(PosProductModel p, PriceOption price,
      List<VariantGroupSelection> selections, String? note) {
    showModalBottomSheet<QuickAddResult>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: PosQuickAddSheet(
          product:            p,
          initialPrice:       price,
          fixedPrice:         price,
          savedSelections:    selections,
          savedNote:          note,
          onOpenVariantModal: (p2) => _showVariantModal(p, p2),
          onQuickAdd: (price2) {
            Navigator.pop(context);
            _addToCart(CartItem(
              product:           p,
              selectedPrice:     price2,
              variantSelections: selections,
              quantity:          1,
              note:              note,
            ));
          },
        ),
      ),
    ).then((result) {
      if (result != null) {
        _addToCart(CartItem(
          product:           p,
          selectedPrice:     result.price,
          variantSelections: result.selections,
          quantity:          1,
          note:              result.note,
        ));
      }
    });
  }

  void _goToOpenShift() {
    showPosShiftModal(context, currentShift: null,
        onShiftChanged: (s) {
          if (mounted) setState(() => _currentShift = s);
        });
  }

  void _goToCloseShift() {
    showPosShiftModal(context, currentShift: _currentShift,
        onShiftChanged: (s) {
          if (mounted) setState(() {
            _currentShift = s;
            if (s == null) {
              _cart.clear();
              _appDiscountAmount = 0;  // ← THÊM
              _appFinalOverride  = 0;  // ← THÊM
            }
          });
        });
  }

  void _goToImportStock() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PosImportStockScreen()));
  }

  String _fmt(double v) => NumberFormat('#,###', 'vi_VN').format(v);

  // ═══════════════════════════════════════════════════════════════
  // Customer button widget
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCustomerBtn(double scale) {
    final cs   = Theme.of(context).colorScheme;
    const teal = Color(0xFF0D9488);

    if (_customer == null) {
      return OutlinedButton.icon(
        icon: Icon(Icons.person_add_outlined, size: 14 * scale,
            color: _cart.isEmpty
                ? cs.onSurface.withOpacity(0.3) : teal),
        label: Text('Khách',
            style: TextStyle(
                fontSize: 11 * scale,
                color: _cart.isEmpty
                    ? cs.onSurface.withOpacity(0.3) : teal,
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: _cart.isEmpty
                  ? cs.onSurface.withOpacity(0.15)
                  : teal.withOpacity(0.5)),
          padding: EdgeInsets.symmetric(
              horizontal: 10 * scale, vertical: 7 * scale),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8 * scale)),
        ),
        onPressed: _cart.isEmpty ? null : _openCustomerSheet,
      );
    }

    return Container(
      height: 34 * scale,
      decoration: BoxDecoration(
          color: teal,
          borderRadius: BorderRadius.circular(8 * scale)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _openCustomerSheet,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 10 * scale, vertical: 6 * scale),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_rounded, size: 13 * scale,
                  color: Colors.white),
              SizedBox(width: 5 * scale),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 80 * scale),
                child: Text(_customer!.name,
                    style: TextStyle(fontSize: 11 * scale,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              if (_activeDiscount != null &&
                  _activeDiscount!.selectedOption != null) ...[
                SizedBox(width: 4 * scale),
                Icon(Icons.local_offer_rounded, size: 10 * scale,
                    color: Colors.white.withOpacity(0.85)),
              ],
            ]),
          ),
        ),
        Container(width: 1, height: 20 * scale,
            color: Colors.white.withOpacity(0.3)),
        GestureDetector(
          onTap: () => setState(() {
            _customer              = null;
            _activeDiscount        = null;
            _discountItemProductId = null;
          }),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8 * scale),
            child: Icon(Icons.close_rounded, size: 13 * scale,
                color: Colors.white),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Printer status widget
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPrinterStatus(double scale) {
    if (_isConnectingPrinter) {
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: 10 * scale, vertical: 7 * scale),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8 * scale),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 12 * scale, height: 12 * scale,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.orange)),
          SizedBox(width: 6 * scale),
          Text('Máy in...',
              style: TextStyle(fontSize: 11 * scale,
                  color: Colors.orange, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    final color = _printerConnected ? Colors.green : Colors.red;
    return GestureDetector(
      onTap: () async {
        final changed = await showPrinterSettingsDialog(context);
        if (changed && mounted) {
          setState(() => _printerConnected = PrinterConfig.isConnected);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: 10 * scale, vertical: 7 * scale),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8 * scale),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _printerConnected
                ? Icons.print_rounded : Icons.print_disabled_rounded,
            size: 14 * scale, color: color,
          ),
          SizedBox(width: 5 * scale),
          Text(
            _printerConnected ? 'Máy in ✓' : 'Cài máy in',
            style: TextStyle(fontSize: 11 * scale, color: color,
                fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet    = screenWidth > 800;
    final cs          = Theme.of(context).colorScheme;
    final scale       = _scaleFactor;

    final currentOrientation = MediaQuery.of(context).orientation;
    if (currentOrientation == Orientation.landscape) {
      _lastOrientation = currentOrientation;
    }

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(
            4 * scale, 24 * scale, 4 * scale, 10 * scale),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: isTablet ? 12 : 10,
                child: Column(children: [
                  _buildTopBar(cs, isTablet, scale),
                  _buildCategoryRow(cs, scale),
                  Expanded(child: _buildProductGrid(isTablet, cs, scale)),
                ]),
              ),
              if (isTablet) SizedBox(width: 8 * scale),
              Expanded(
                  flex: isTablet ? 5 : 4,
                  child: _buildCart(cs, scale)),
            ]),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────
  Widget _buildTopBar(ColorScheme cs, bool isTablet, double scale) {
    final isOpen = _currentShift?.isOpen == true;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.surface,
            cs.surfaceContainerHighest.withOpacity(0.6)],
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
        ),
        boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.08),
            blurRadius: 12 * scale,
            offset: Offset(0, 4 * scale))],
      ),
      padding: EdgeInsets.fromLTRB(
          12 * scale, 8 * scale, 12 * scale, 8 * scale),
      child: Row(children: [
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(isOpen
                    ? Icons.storefront_rounded
                    : Icons.storefront_outlined,
                    color: isOpen ? Colors.green : cs.primary,
                    size: 24 * scale),
                SizedBox(width: 12 * scale),
                Flexible(child: Text(
                  isOpen
                      ? _currentShift!.staffName
                      : (PrinterConfig.storeProfile?.name.isNotEmpty == true
                      ? PrinterConfig.storeProfile!.name
                      : 'Original Taste POS'),
                  style: TextStyle(fontSize: 18 * scale,
                      fontWeight: FontWeight.bold,
                      color: isOpen ? Colors.green : cs.onSurface),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
              SizedBox(height: 4 * scale),
              _ClockWidget(cs: cs, scale: scale),
            ])),

        _buildPrinterStatus(scale),
        SizedBox(width: 8 * scale),

        _buildCustomerBtn(scale),
        SizedBox(width: 8 * scale),

        if (isOpen) ...[
          FilledButton.icon(
            icon:  Icon(Icons.inventory_2_outlined, size: 16 * scale),
            label: Text('Nhập kho',
                style: TextStyle(fontSize: 12 * scale)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale, vertical: 8 * scale),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * scale)),
            ),
            onPressed: _goToImportStock,
          ),
          SizedBox(width: 12 * scale),
          FilledButton.icon(
            icon:  Icon(Icons.power_settings_new, size: 16 * scale),
            label: Text('Đóng ca',
                style: TextStyle(fontSize: 12 * scale)),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale, vertical: 8 * scale),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * scale)),
            ),
            onPressed: _goToCloseShift,
          ),
        ] else ...[
          FilledButton.icon(
            icon:  Icon(Icons.play_arrow_rounded, size: 16 * scale),
            label: Text('Mở ca',
                style: TextStyle(fontSize: 12 * scale)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale, vertical: 8 * scale),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * scale)),
            ),
            onPressed: _goToOpenShift,
          ),
        ],
      ]),
    );
  }

  // ── Category row ─────────────────────────────────────────────
  Widget _buildCategoryRow(ColorScheme cs, double scale) {
    if (_isLoadingCategories) {
      return Container(
          height: 120 * scale, color: cs.surface,
          child: const Center(child: CircularProgressIndicator()));
    }
    return Container(
      height: 120 * scale, color: cs.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
            vertical: 8 * scale, horizontal: 4 * scale),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat      = _categories[index];
          final isActive = _selectedCat?.id == cat.id;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCat = cat);
              _loadProducts(cat.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin:   EdgeInsets.symmetric(horizontal: 4 * scale),
              width:    90 * scale,
              decoration: BoxDecoration(
                color: isActive
                    ? cs.primary.withOpacity(0.1)
                    : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20 * scale),
                border: Border.all(
                  color: isActive
                      ? cs.primary : cs.outline.withOpacity(0.3),
                  width: isActive ? 2.5 * scale : 1 * scale,
                ),
                boxShadow: isActive ? [BoxShadow(
                    color:       cs.primary.withOpacity(0.25),
                    blurRadius:  12 * scale,
                    spreadRadius: 2 * scale)] : null,
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12 * scale),
                      child: NetworkImageViewer(
                        imageUrl:    cat.imageUrl,
                        height:      40 * scale,
                        width:       40 * scale,
                        fit:         BoxFit.cover,
                        placeholder: Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.category_rounded,
                                size:  32 * scale,
                                color: cs.primary.withOpacity(0.4))),
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(cat.name,
                        style: TextStyle(
                            fontSize:   13 * scale,
                            fontWeight: isActive
                                ? FontWeight.bold : FontWeight.w600,
                            color: isActive ? cs.primary : cs.onSurface),
                        textAlign: TextAlign.center,
                        maxLines:  2,
                        overflow:  TextOverflow.ellipsis),
                  ]),
            ),
          );
        },
      ),
    );
  }

  // ── Product grid ─────────────────────────────────────────────
  Widget _buildProductGrid(bool isTablet, ColorScheme cs, double scale) {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty) {
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_outlined, size: 60 * scale,
                color: cs.onSurface.withOpacity(0.3)),
            SizedBox(height: 16 * scale),
            Text('Chưa có sản phẩm trong danh mục này',
                style: TextStyle(fontSize: 18 * scale,
                    color: cs.onSurface.withOpacity(0.6))),
          ]));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final sw         = MediaQuery.of(context).size.width;
      final crossCount = sw < 800 ? 2 : sw < 1000 ? 4 : 5;
      final spacing    = sw < 1000 ? 12.0 * scale : 16.0 * scale;

      return GridView.builder(
        padding: EdgeInsets.fromLTRB(
            spacing, spacing, spacing, spacing + 40 * scale),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   crossCount,
          mainAxisSpacing:  spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 0.85, // ảnh vuông hơn vì full card
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final p = _products[index];

          // Giá hiển thị
          String displayPrice;
          if (_orderSource == PosOrderSource.shopeeFood ||
              _orderSource == PosOrderSource.grabFood) {
            final platform = _orderSource == PosOrderSource.shopeeFood
                ? 'SHOPEE_FOOD' : 'GRAB_FOOD';
            final appMenu  = p.appMenus.firstWhere(
                  (m) => m.platform == platform && m.isActive,
              orElse: () => AppMenuModel(id: 0, platform: platform,
                  price: p.basePrice, isActive: false),
            );
            displayPrice = _fmt(appMenu.isActive ? appMenu.price : p.basePrice);
          } else {
            displayPrice = _fmt(p.basePrice);
          }

          final cartQty = _cart
              .where((c) => c.product.id == p.id)
              .fold(0, (s, c) => s + c.quantity);

          final enabled = _orderSource == PosOrderSource.takeAway ||
              _orderSource == PosOrderSource.dineIn ||
              (_orderSource == PosOrderSource.shopeeFood && p.isShopeeFood) ||
              (_orderSource == PosOrderSource.grabFood  && p.isGrabFood);

          // Màu text thích nghi dark/light
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return ClipRRect(
            borderRadius: BorderRadius.circular(14 * scale),
            child: AnimatedOpacity(
              opacity: enabled ? 1.0 : 0.55,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: enabled ? () => _onTapProduct(p) : null,
                child: Stack(fit: StackFit.expand, children: [

                  // ── Ảnh full card ──────────────────────────────
                  NetworkImageViewer(
                    imageUrl: p.imageUrl,
                    width:    double.infinity,
                    height:   double.infinity,
                    fit:      BoxFit.cover,
                    placeholder: Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.fastfood_outlined,
                          size: 40 * scale,
                          color: cs.onSurface.withOpacity(0.3)),
                    ),
                  ),

                  // ── Gradient overlay (đậm hơn ở dưới) ─────────
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(isDark ? 0.5 : 0.45),
                            Colors.black.withOpacity(isDark ? 0.85 : 0.75),
                          ],
                          stops: const [0.0, 0.35, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // ── Tên + giá nằm dưới cùng ────────────────────
                  Positioned(
                    left:   7 * scale,
                    right:  7 * scale,
                    bottom: 7 * scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize:   sw < 1000
                                ? 9 * scale : 11 * scale,
                            fontWeight: FontWeight.w700,
                            color:      Colors.white,
                            height:     1.2,
                            shadows:    const [Shadow(
                              color:      Colors.black54,
                              blurRadius: 6,
                              offset:     Offset(0, 1),
                            )],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2 * scale),
                        Text(
                          displayPrice,
                          style: TextStyle(
                            fontSize:   sw < 1000
                                ? 9 * scale : 11 * scale,
                            fontWeight: FontWeight.w800,
                            color:      Colors.white,
                            shadows:    const [Shadow(
                              color:      Colors.black54,
                              blurRadius: 6,
                              offset:     Offset(0, 1),
                            )],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Cart badge ─────────────────────────────────
                  if (cartQty > 0)
                    Positioned(
                      right: 7 * scale,
                      top:   7 * scale,
                      child: Container(
                        width:  24 * scale,
                        height: 24 * scale,
                        decoration: BoxDecoration(
                          color:  cs.primary,
                          shape:  BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color:     cs.primary.withOpacity(0.45),
                            blurRadius: 6 * scale,
                          )],
                        ),
                        child: Center(
                          child: Text(
                            '$cartQty',
                            style: TextStyle(
                              color:      Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize:   10 * scale,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Disabled overlay ───────────────────────────
                  if (!enabled)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                        child: Center(
                          child: Text(
                            _orderSource == PosOrderSource.shopeeFood
                                ? 'Không bán\nShopee'
                                : 'Không bán\nGrab',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:      Colors.white,
                              fontSize:   11 * scale,
                              fontWeight: FontWeight.bold,
                              height:     1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          );
        },
      );
    });
  }

  // ── Cart ─────────────────────────────────────────────────────
  Widget _buildCart(ColorScheme cs, double scale) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.08),
            blurRadius: 16 * scale,
            offset: Offset(-4 * scale, 0))],
      ),
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              16 * scale, 16 * scale, 16 * scale, 8 * scale),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.shopping_cart_rounded,
                      color: cs.primary, size: 26 * scale),
                  SizedBox(width: 10 * scale),
                  Text('Giỏ hàng ($_cartCount)',
                      style: TextStyle(fontSize: 18 * scale,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface)),
                ]),
                if (_cart.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.delete_sweep_rounded,
                        color: cs.error, size: 24 * scale),
                    onPressed: () {
                      setState(() {
                        _cart.clear();
                        _appDiscountAmount = 0;  // ← THÊM
                        _appFinalOverride  = 0;  // ← THÊM
                      });
                      _snack('Đã xóa toàn bộ giỏ hàng');
                    },
                  ),
              ]),
        ),
        Expanded(child: Stack(children: [
          _cart.isEmpty
              ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 100),
                Icon(Icons.shopping_cart_outlined, size: 70 * scale,
                    color: cs.onSurface.withOpacity(0.3)),
                Text('Giỏ hàng trống',
                    style: TextStyle(fontSize: 18 * scale,
                        color: cs.onSurface.withOpacity(0.6))),
              ]))
              : ListView.builder(
            controller: _cartScroll,
            padding: EdgeInsets.fromLTRB(
                12 * scale, 0, 12 * scale, 340 * scale),
            itemCount: _cart.length,
            itemBuilder: (_, i) => _CartItemTile(
              item:         _cart[i],
              formatMoney:  _fmt,
              onQtyChange:  (d) => _updateQty(i, d),
              onRemove:     () => _removeFromCart(i),
              onWeightTap:  () => _openWeightSheet(i),   // ← THÊM
              scale:        scale,
              isDiscounted: _activeDiscount?.selectedOption != null &&
                  _activeDiscount!.selectedOption!.discountType.isItemType &&
                  _discountItemProductId == _cart[i].product.id,
              isAppOrder:  _isAppOrder, // ← THÊM
              onPriceTap:  _isAppOrder  // ← THÊM
                  ? () async {
                final result = await showAppItemPriceSheet(
                    context, cartItem: _cart[i]);
                if (result != null && mounted) {
                  setState(() {
                    _cart[i] = _cart[i].copyWith(
                      selectedPrice: PriceOption(
                        discountPercent: _cart[i].selectedPrice.discountPercent,
                        price:  result.newPrice,
                        label: 'Giá tùy chỉnh',
                      ),
                    );
                  });
                }
              }
                  : null,
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: 55 * scale),
              child: _CartSummary(
                subTotal:        _subTotal,
                vatBreakdown:    _vatBreakdown,
                grandTotal:      _grandTotal,
                discountAmount:  _discountAmount,
                discountLabel:   _activeDiscount?.programName,
                orderSource:     _orderSource,
                canShopee:       _canShopee,
                canGrab:         _canGrab,
                paymentMethod:   _paymentMethod,
                isCreating:      _isCreatingOrder,
                cartEmpty:       _cart.isEmpty,
                formatMoney:     _fmt,
                platformFee:  _platformFee,
                netRevenue:   _netRevenue,
                platformRate: _platformRate,
                onSourceChanged: (s) => setState(() {
                  _orderSource = s;
                  _clearAppDiscount(); // ← THÊM
                }),
                onPaymentChanged: (p) => setState(() => _paymentMethod = p),
                onCreateOrder:    _createOrder,
                onClearCart: () {
                  setState(() => _cart.clear());
                  _snack('Đã xóa giỏ hàng do đổi chế độ đặt hàng');
                },
                cartItems:           _cart,
                onRemoveUnsupported: (platform) {
                  setState(() {
                    if (platform == null) return;
                    _cart.removeWhere((item) {
                      final menu = item.product.appMenus.firstWhere(
                            (m) => m.platform == platform && m.isActive,
                        orElse: () => AppMenuModel(
                            id: 0, platform: platform,
                            price: 0, isActive: false),
                      );
                      return !menu.isActive;
                    });
                  });
                },
                onUpdatePrices: (platform) {
                  setState(() {
                    for (int i = 0; i < _cart.length; i++) {
                      final item = _cart[i];
                      final double newPrice;
                      final String newLabel;
                      if (platform == null) {
                        newPrice = item.product.basePrice;
                        newLabel = 'Giá gốc';
                      } else {
                        final menu = item.product.appMenus.firstWhere(
                              (m) => m.platform == platform &&
                              m.isActive,
                          orElse: () => AppMenuModel(
                              id: 0, platform: platform,
                              price: item.product.basePrice,
                              isActive: false),
                        );
                        newPrice = menu.price;
                        newLabel = platform == 'SHOPEE_FOOD'
                            ? 'Giá Shopee' : 'Giá Grab';
                      }
                      _cart[i] = item.copyWith(selectedPrice: PriceOption(
                          discountPercent: 0,
                          price: newPrice,
                          label: newLabel));
                    }
                  });
                },
                scale: scale,
                isAppOrder:           _isAppOrder,          // ← THÊM
                appDiscountAmount:    _appDiscountAmount,    // ← THÊM
                onAppDiscountTap:     _openAppDiscountSheet, // ← THÊM
              ),
            ),
          ),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// CART SUMMARY
// ══════════════════════════════════════════════════════════════════

class _CartSummary extends StatelessWidget {
  final double subTotal, grandTotal, discountAmount;
  final String? discountLabel;
  final Map<int, double> vatBreakdown;
  final PosOrderSource orderSource;
  final bool   canShopee, canGrab, isCreating, cartEmpty;
  final String paymentMethod;
  final String Function(double) formatMoney;
  final void Function(PosOrderSource) onSourceChanged;
  final void Function(String) onPaymentChanged;
  final VoidCallback  onCreateOrder;
  final VoidCallback? onClearCart;
  final double scale;
  final List<CartItem> cartItems;
  final void Function(String? platform) onRemoveUnsupported;
  final void Function(String? platform) onUpdatePrices;
  final bool        isAppOrder;
  final double      appDiscountAmount;
  final VoidCallback onAppDiscountTap;
  final double platformFee;
  final double netRevenue;
  final double platformRate;

  const _CartSummary({
    required this.subTotal,
    required this.vatBreakdown,
    required this.grandTotal,
    required this.discountAmount,
    this.discountLabel,
    required this.orderSource,
    required this.canShopee,
    required this.canGrab,
    required this.paymentMethod,
    required this.isCreating,
    required this.cartEmpty,
    required this.formatMoney,
    required this.onSourceChanged,
    required this.onPaymentChanged,
    required this.onCreateOrder,
    required this.onClearCart,
    required this.scale,
    required this.cartItems,
    required this.onRemoveUnsupported,
    required this.onUpdatePrices,
    required this.isAppOrder,
    required this.appDiscountAmount,
    required this.onAppDiscountTap, required this.platformFee, required this.netRevenue, required this.platformRate,
  });

  Future<void> _confirmClearCart(
      BuildContext context, PosOrderSource newSource) async {

    if (cartEmpty) {
      onSourceChanged(newSource);
      return;
    }

    final String? platform = switch (newSource) {
      PosOrderSource.shopeeFood => 'SHOPEE_FOOD',
      PosOrderSource.grabFood   => 'GRAB_FOOD',
      _                         => null,
    };

    final willRemove = <String>[];
    final willUpdate = <String>[];

    for (final item in cartItems) {
      if (platform == null) {
        // Đổi sang Offline
        if (item.product.basePrice != item.selectedPrice.price) {
          willUpdate.add(item.product.name);
        }
      } else {
        // Đổi sang App (Shopee hoặc Grab)
        final appMenu = item.product.appMenus.firstWhere(
              (m) => m.platform == platform && m.isActive,
          orElse: () => AppMenuModel(
              id: 0, platform: platform, price: 0, isActive: false),
        );

        if (!appMenu.isActive) {
          willRemove.add(item.product.name);
        } else if (appMenu.price != item.selectedPrice.price) {
          willUpdate.add(item.product.name);
        }
      }
    }

    // Nếu không có thay đổi gì thì cho đổi luôn
    if (willRemove.isEmpty && willUpdate.isEmpty) {
      onSourceChanged(newSource);
      return;
    }

    final message = willRemove.isEmpty
        ? (willUpdate.length <= 3
        ? 'Giá sẽ được cập nhật: ${willUpdate.join(', ')}.'
        : 'Giá các món trong giỏ sẽ được cập nhật theo nguồn mới.')
        : (willRemove.length <= 3
        ? '${willRemove.join(', ')} không bán ở nguồn này và sẽ bị xóa khỏi giỏ.'
        : '${willRemove.length} món không bán ở nguồn này và sẽ bị xóa khỏi giỏ.');

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi nguồn đơn hàng'),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Xác nhận',
              style: TextStyle(
                color: willRemove.isNotEmpty ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onSourceChanged(newSource);
      if (willRemove.isNotEmpty) {
        onRemoveUnsupported(platform);
      } else {
        onUpdatePrices(platform);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = vatBreakdown.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    const teal = Color(0xFF0D9488);

    return Container(
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.1),
            blurRadius: 8 * scale,
            offset: Offset(0, -4 * scale))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Order Mode Selector
        PosOrderModeSelector(
          current:   orderSource,
          canShopee: canShopee,
          canGrab:   canGrab,
          onChanged: (newSource) {
            if (!cartEmpty && newSource != orderSource) {
              _confirmClearCart(context, newSource);
            } else {
              onSourceChanged(newSource);
            }
          },
        ),

        const SizedBox(height: 8),

        // VAT breakdown
        if (isAppOrder) ...[
          // ── App order: 3 dòng breakdown ──────────────────────────────

          // 1. Tạm tính (giá gốc app)
          _row('Tạm tính', subTotal, cs, scale: scale),

          // 2. Giảm giá (nếu có)
          if (appDiscountAmount > 0)
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.local_offer_rounded,
                        size: 12 * scale, color: const Color(0xFFEE4D2D)),
                    const SizedBox(width: 4),
                    Text('Khuyến mãi',
                        style: TextStyle(
                            fontSize: 12 * scale,
                            color: const Color(0xFFEE4D2D),
                            fontWeight: FontWeight.w600)),
                  ]),
                  Text('-${formatMoney(appDiscountAmount)}đ',
                      style: TextStyle(
                          fontSize: 12 * scale,
                          color: const Color(0xFFEE4D2D),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),

          // 3. Phí App
          Padding(
            padding: EdgeInsets.only(top: 2 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.storefront_rounded,
                      size: 12 * scale,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Phí App (${(platformRate * 100).toStringAsFixed(2)}%)',
                    style: TextStyle(
                        fontSize: 12 * scale,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
                  ),
                ]),
                Text(
                  '-${formatMoney(platformFee)}đ',
                  style: TextStyle(
                      fontSize: 12 * scale,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          Divider(height: 12 * scale),

          // 4. Thực nhận (in đậm màu xanh)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thực nhận',
                  style: TextStyle(
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D9488))),
              Text('${formatMoney(netRevenue)}đ',
                  style: TextStyle(
                      fontSize: 17 * scale,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D9488))),
            ],
          ),

        ] else ...[
          // ── Offline order: layout cũ ──────────────────────────────────

          // VAT breakdown
          ...sorted.map((e) => Padding(
            padding: EdgeInsets.only(top: 2 * scale),
            child: _row('VAT ${e.key}%', e.value, cs, isVat: true, scale: scale),
          )),

          // Customer discount
          if (discountAmount > 0)
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.local_offer_rounded,
                        size: 12 * scale, color: const Color(0xFF0D9488)),
                    const SizedBox(width: 4),
                    Text(
                      discountLabel != null
                          ? 'Giảm ($discountLabel)' : 'Giảm giá',
                      style: TextStyle(
                          fontSize: 12 * scale,
                          color: const Color(0xFF0D9488),
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                  Text('-${formatMoney(discountAmount)}đ',
                      style: TextStyle(
                          fontSize: 12 * scale,
                          color: const Color(0xFF0D9488),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),

          Divider(height: 12 * scale),

          _row('Tổng cộng', grandTotal, cs, isTotal: true, scale: scale),
        ],

        const SizedBox(height: 12),

        // === PHẦN THANH TOÁN ===
        if (isAppOrder) ...[
          // Khi là đơn App: hiển thị 3 nút ngang (Tiền mặt - Chuyển khoản - Khuyến mãi)
          Row(children: [
            // Nút Khuyến mãi App
            _buildAppDiscountButton(context),
            const SizedBox(width: 8),
            // Tiền mặt & Chuyển khoản
            Expanded(
              child: PosPaymentSelector(
                current: paymentMethod,
                onChanged: onPaymentChanged,
              ),
            ),
          ]),
        ] else ...[
          // Đơn Offline: dùng PosPaymentSelector bình thường
          PosPaymentSelector(
            current: paymentMethod,
            onChanged: onPaymentChanged,
          ),
        ],

        const SizedBox(height: 12),

        // Nút Tạo đơn
        SizedBox(
          width: double.infinity,
          height: 48 * scale,
          child: FilledButton.icon(
            icon: isCreating
                ? SizedBox(
                width: 18 * scale,
                height: 18 * scale,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5 * scale, color: Colors.white))
                : Icon(_orderIcon, size: 18 * scale),
            label: Text(_orderLabel,
                style: TextStyle(
                    fontSize: 14 * scale, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: cartEmpty || isCreating ? null : _orderColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12 * scale)),
            ),
            onPressed: (cartEmpty || isCreating) ? null : onCreateOrder,
          ),
        ),
      ]),
    );
  }

  Widget _buildAppDiscountButton(BuildContext context) {
    final hasDiscount = appDiscountAmount > 0;
    const orange = Color(0xFFEE4D2D);
    final cs = Theme.of(context).colorScheme;

    // Format discount text
    String buttonText = 'Giảm';

    return GestureDetector(
      onTap: onAppDiscountTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
        decoration: BoxDecoration(
          color: hasDiscount
              ? orange.withOpacity(0.12)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasDiscount ? orange : cs.outline.withOpacity(0.3),
          ),
        ),
        child: Text(
          buttonText,
          style: TextStyle(
            fontSize: 12 * scale,
            fontWeight: FontWeight.w600,
            color: hasDiscount ? orange : cs.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Helper row
  Widget _row(String label, double value, ColorScheme cs,
      {bool isTotal = false, bool isVat = false, required double scale}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: (isTotal ? 15 : 13) * scale,
            color: isVat ? cs.onSurface.withOpacity(0.55) : cs.onSurface,
          ),
        ),
        Text(
          '+${formatMoney(value)}đ',
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: (isTotal ? 15 : 13) * scale,
            color: isTotal ? cs.primary : cs.onSurface,
          ),
        ),
      ],
    );
  }

  Color get _orderColor => switch (orderSource) {
    PosOrderSource.shopeeFood => const Color(0xFFEE4D2D),
    PosOrderSource.grabFood => const Color(0xFF00B14F),
    _ => Colors.lightBlue,
  };

  IconData get _orderIcon => switch (orderSource) {
    PosOrderSource.shopeeFood => Icons.shopping_bag_outlined,
    PosOrderSource.grabFood => Icons.delivery_dining,
    PosOrderSource.dineIn => Icons.table_restaurant_outlined,
    _ => Icons.storefront_outlined,
  };

  String get _orderLabel => switch (orderSource) {
    PosOrderSource.takeAway => 'Tạo đơn Take Away',
    PosOrderSource.dineIn => 'Tạo đơn Dine In',
    PosOrderSource.shopeeFood => 'Tạo đơn ShopeeFood',
    PosOrderSource.grabFood => 'Tạo đơn GrabFood',
  };
}

// ══════════════════════════════════════════════════════════════════
// CART ITEM TILE
// ══════════════════════════════════════════════════════════════════

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final String Function(double) formatMoney;
  final void Function(int) onQtyChange;
  final VoidCallback onRemove;
  final VoidCallback onWeightTap;   // ← MỚI
  final double scale;
  final bool isDiscounted;
  final bool isAppOrder;
  final VoidCallback? onPriceTap; // callback khi tap giá trong App mode

  const _CartItemTile({
    required this.item,
    required this.formatMoney,
    required this.onQtyChange,
    required this.onRemove,
    required this.onWeightTap,       // ← MỚI
    required this.scale,
    this.isDiscounted = false,
    this.isAppOrder = false,          // ← THÊM nếu chưa có
    this.onPriceTap,                  // ← THÊM nếu chưa có
  });

  // Kiểm tra item có ít nhất 1 ingredient non-addon có selectedCount > 0 không
  bool get _hasWeightableIngredients {
    for (final sel in item.variantSelections) {
      if (sel.isAddonGroup) continue;
      if (sel.selectedIngredients.values.any((c) => c > 0)) return true;
    }
    return false;
  }

  // Kiểm tra item đã có unitWeights override chưa
  bool get _hasWeightOverride {
    for (final sel in item.variantSelections) {
      if (sel.unitWeightsMap.isNotEmpty) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final vUrl = item.product.imageUrl;
    const teal = Color(0xFF0D9488);
    const scaleAccent = Color(0xFF0EA5E9); // sky blue cho icon cân

    return Dismissible(
      key:       ValueKey('${item.product.id}_${item.hashCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
          color: cs.error, alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20 * scale),
          child: Icon(Icons.delete_forever_rounded,
              color: Colors.white, size: 32 * scale)),
      onDismissed: (_) => onRemove(),
      child: Card(
        margin:    EdgeInsets.symmetric(vertical: 6 * scale),
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * scale)),
        child: Container(
          decoration: isDiscounted
              ? BoxDecoration(
              borderRadius: BorderRadius.circular(16 * scale),
              border: Border.all(
                  color: teal.withOpacity(0.4), width: 1.5))
              : null,
          child: Padding(
            padding: EdgeInsets.all(12 * scale),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ảnh sản phẩm
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12 * scale),
                    child: NetworkImageViewer(imageUrl: vUrl,
                        height: 80 * scale, width: 80 * scale,
                        fit: BoxFit.cover),
                  ),
                  SizedBox(width: 12 * scale),

                  // Nội dung
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tên + icon discount + icon đã có weight override
                        Row(children: [
                          Expanded(child: Text(item.product.name,
                              style: TextStyle(fontSize: 15 * scale,
                                  fontWeight: FontWeight.w700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis)),
                          if (isDiscounted)
                            Padding(
                              padding: EdgeInsets.only(left: 4 * scale),
                              child: Icon(Icons.local_offer_rounded,
                                  size: 14 * scale, color: teal),
                            ),
                        ]),
                        SizedBox(height: 4 * scale),

                        // Ghi chú
                        if (item.note != null && item.note!.isNotEmpty)
                          Padding(
                              padding: EdgeInsets.only(bottom: 4 * scale),
                              child: Text('Ghi chú: ${item.note}',
                                  style: TextStyle(fontSize: 12 * scale,
                                      color: cs.onSurface.withOpacity(0.6),
                                      fontStyle: FontStyle.italic))),

                        // Ingredients & addons
                        ..._buildIngredientAndAddonLines(cs, scale),

                        SizedBox(height: 6 * scale),

                        // Giá + nút cân
                        GestureDetector(
                          onTap: isAppOrder ? onPriceTap : null,
                          child: Container(
                            padding: isAppOrder
                                ? EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale)
                                : EdgeInsets.zero,
                            decoration: isAppOrder ? BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6 * scale),
                              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                            ) : null,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                formatMoney(item.selectedPrice.price + item.addonPerUnit),
                                style: TextStyle(
                                  fontSize: 16 * scale, fontWeight: FontWeight.bold,
                                  color: isAppOrder
                                      ? const Color(0xFF0284C7)
                                      : cs.primary,
                                ),
                              ),
                              if (isAppOrder) ...[
                                SizedBox(width: 4 * scale),
                                Icon(Icons.edit_rounded, size: 12 * scale,
                                    color: const Color(0xFF0284C7).withOpacity(0.6)),
                              ],
                            ]),
                          ),
                        ),

                        // Nút điều chỉnh định lượng — dòng riêng bên dưới giá
                        if (_hasWeightableIngredients) ...[
                          SizedBox(height: 6 * scale),
                          GestureDetector(
                            onTap: onWeightTap,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8 * scale,
                                  vertical: 4 * scale),
                              decoration: BoxDecoration(
                                color: _hasWeightOverride
                                    ? scaleAccent.withOpacity(0.12)
                                    : cs.onSurface.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8 * scale),
                                border: Border.all(
                                  color: _hasWeightOverride
                                      ? scaleAccent.withOpacity(0.4)
                                      : cs.onSurface.withOpacity(0.12),
                                ),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _hasWeightOverride
                                          ? Icons.scale_rounded
                                          : Icons.scale_outlined,
                                      size: 12 * scale,
                                      color: _hasWeightOverride
                                          ? scaleAccent
                                          : cs.onSurface.withOpacity(0.4),
                                    ),
                                    SizedBox(width: 4 * scale),
                                    Text(
                                      'Định lượng',
                                      style: TextStyle(
                                        fontSize: 10 * scale,
                                        fontWeight: FontWeight.w600,
                                        color: _hasWeightOverride
                                            ? scaleAccent
                                            : cs.onSurface.withOpacity(0.4),
                                      ),
                                    ),
                                  ]),
                            ),
                          ),
                        ],
                      ])),

                  // Stepper qty
                  Column(children: [
                    _qtyButton(Icons.remove_circle_outline_rounded,
                            () => onQtyChange(-1), cs, scale),
                    Padding(
                        padding: EdgeInsets.symmetric(vertical: 4 * scale),
                        child: Text('${item.quantity}',
                            style: TextStyle(fontSize: 16 * scale,
                                fontWeight: FontWeight.bold))),
                    _qtyButton(Icons.add_circle_rounded,
                            () => onQtyChange(1), cs, scale),
                  ]),
                ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildIngredientAndAddonLines(
      ColorScheme cs, double scale) {
    final lines   = <Widget>[];
    final nameMap = <int, String>{};
    for (final v in item.product.variants)
      for (final ing in v.ingredients)
        nameMap[ing.ingredientId] = ing.ingredientName;

    // ── Nguyên liệu chính (non-addon) ──────────────────────────
    for (final sel in item.variantSelections) {
      if (sel.isAddonGroup) continue;
      for (final e in sel.selectedIngredients.entries) {
        if (e.value <= 0) continue;
        final name        = nameMap[e.key] ?? 'NL #${e.key}';
        final weights     = sel.unitWeightsMap[e.key];
        final hasOverride = weights != null && weights.isNotEmpty;

        lines.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(children: [
            // Tên + số lượng — Flexible để tự cắt khi quá dài
            Flexible(
              child: Text(
                '• $name x${e.value}',
                style: TextStyle(
                    fontSize: 11 * scale,
                    color: cs.onSurface.withOpacity(0.7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ));
      }
    }

    // ── Addons ─────────────────────────────────────────────────
    for (final sel in item.variantSelections) {
      if (!sel.isAddonGroup || sel.addonItems == null) continue;
      for (final a in sel.addonItems!) {
        if (a.quantity <= 0) continue;
        final name = nameMap[a.ingredientId] ?? a.ingredientName;
        lines.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '• $name x${a.quantity}',
            style: TextStyle(
                fontSize: 10 * scale,
                color: cs.primary.withOpacity(0.8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ));
      }
    }

    return lines;
  }

  /// Format weight gọn: 0.200 → 0.2, 0.310 → 0.31
  String _fmtW(double v) {
    return v.toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap,
      ColorScheme cs, double scale) =>
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20 * scale),
          child: Padding(padding: EdgeInsets.all(4 * scale),
              child: Icon(icon, size: 28 * scale, color: cs.primary)));
}


// ══════════════════════════════════════════════════════════════════
// CLOCK WIDGET
// ══════════════════════════════════════════════════════════════════

class _ClockWidget extends StatefulWidget {
  final ColorScheme cs;
  final double scale;
  const _ClockWidget({required this.cs, required this.scale});
  @override State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late Timer    _timer;
  late DateTime _now;
  @override
  void initState() {
    super.initState();
    _now   = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1),
            (_) { if (mounted) setState(() => _now = DateTime.now()); });
  }
  @override void dispose() { _timer.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Text(
    DateFormat('HH:mm:ss  dd/MM/yyyy').format(_now),
    style: TextStyle(
        fontSize: 13 * widget.scale,
        color: widget.cs.onSurface.withOpacity(0.6),
        fontFeatures: const [FontFeature.tabularFigures()]),
  );
}

// ══════════════════════════════════════════════════════════════════
// QUICK ADD HELPERS
// ══════════════════════════════════════════════════════════════════

List<VariantGroupSelection> buildQuickAddSelections(PosProductModel p) {
  final regular = p.variants.where((v) => !v.isAddonGroup).toList();
  final result  = <VariantGroupSelection>[];
  for (final v in regular.where((v) => v.minSelect > 0))
    result.add(VariantGroupSelection(
        variantId: v.id, groupName: v.groupName,
        isAddonGroup: false,
        selectedIngredients: _autoDistribute(v)));
  if (result.isEmpty && regular.isNotEmpty) {
    final first = regular.first;
    result.add(VariantGroupSelection(
        variantId: first.id, groupName: first.groupName,
        isAddonGroup: false,
        selectedIngredients: _autoFill(first)));
  }
  return result;
}

bool canQuickAdd(PosProductModel p) {
  final regular = p.variants.where((v) => !v.isAddonGroup).toList();
  return regular.isEmpty || _getDefaultVariant(p) != null;
}

PosVariantModel? _getDefaultVariant(PosProductModel p) {
  final regular = p.variants.where((v) => !v.isAddonGroup).toList();
  if (regular.isEmpty) return null;
  if (regular.length == 1) return regular.first;
  return regular.where(_isFullAuto).firstOrNull;
}

bool _isFullAuto(PosVariantModel v) {
  if (v.isAddonGroup || v.ingredients.isEmpty) return false;
  final total = v.ingredients.fold(
      0, (s, i) => s + (i.maxSelectableCount ?? 0));
  return v.minSelect > 0 &&
      v.minSelect == v.maxSelect &&
      v.minSelect == total;
}

Map<int, int> _autoDistribute(PosVariantModel v) {
  final result  = <int, int>{};
  final ings    = v.ingredients;
  if (ings.isEmpty) return result;

  int remaining = v.minSelect;
  if (v.minSelect == v.maxSelect) remaining = v.maxSelect;

  final count    = ings.length;
  final base     = remaining ~/ count;
  int   leftover = remaining % count;

  for (final ing in ings) {
    final give = base + (leftover > 0 ? 1 : 0);
    if (leftover > 0) leftover--;
    if (give > 0) result[ing.ingredientId] = give;
  }
  return result;
}

Map<int, int> _autoFill(PosVariantModel v) {
  final result    = <int, int>{};
  int   remaining = v.maxSelect;
  for (final ing in v.ingredients) {
    if (remaining <= 0) break;
    final cap  = ing.maxSelectableCount ?? 1;
    final give = remaining < cap ? remaining : cap;
    if (give > 0) result[ing.ingredientId] = give;
    remaining -= give;
  }
  return result;
}