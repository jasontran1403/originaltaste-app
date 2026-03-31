// lib/data/models/pos/pos_order_model.dart

class PosOrderItemModel {
  final int     id;
  final int     productId;
  final String  productName;
  final String? productImageUrl;
  final double  basePrice;
  final int     discountPercent;
  final double  finalUnitPrice;
  final int     quantity;
  final double  subtotal;
  final int     vatPercent;
  final double  vatAmount;
  final double  addonAmount;
  final String? note;
  final List<Map<String, dynamic>> selectedIngredients;

  const PosOrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.basePrice,
    required this.discountPercent,
    required this.finalUnitPrice,
    required this.quantity,
    required this.subtotal,
    this.vatPercent  = 0,
    this.vatAmount   = 0,
    this.addonAmount = 0,
    this.note,
    required this.selectedIngredients,
  });

  factory PosOrderItemModel.fromJson(Map<String, dynamic> j) => PosOrderItemModel(
    id:                 j['id'] as int,
    productId:          j['productId'] as int,
    productName:        j['productName'] as String,
    productImageUrl:    j['productImageUrl'] as String?,
    basePrice:          (j['basePrice'] as num).toDouble(),
    discountPercent:    j['discountPercent'] as int? ?? 0,
    finalUnitPrice:     (j['finalUnitPrice'] as num).toDouble(),
    quantity:           j['quantity'] as int,
    subtotal:           (j['subtotal'] as num).toDouble(),
    vatPercent:         j['vatPercent'] as int? ?? 0,
    vatAmount:          (j['vatAmount'] as num?)?.toDouble() ?? 0.0,
    addonAmount:        (j['addonAmount'] as num?)?.toDouble() ?? 0.0,
    note:               j['note'] as String?,
    selectedIngredients: (j['variantSelections'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>(),
  );
}

class PosOrderModel {
  final int     id;
  final String  orderCode;
  final int     shiftId;
  final String  staffName;
  final String  orderSource;
  final String  status;
  final String  paymentMethod;
  final double  totalAmount;       // raw (trước discount, trước rate)
  final double  discountAmount;    // KM raw
  final double  finalAmount;       // net quán nhận
  final String? note;
  final int     createdAt;
  final int     updatedAt;
  final List<PosOrderItemModel> items;
  final String? customerPhone;
  final String? customerName;

  // ── Platform fee snapshot ─────────────────────────────────────
  final double platformRate;        // 0.3305
  final double platformFeeAmount;   // (total - discount) × rate

  const PosOrderModel({
    required this.id,
    required this.orderCode,
    required this.shiftId,
    required this.staffName,
    required this.orderSource,
    required this.status,
    required this.paymentMethod,
    required this.totalAmount,
    required this.discountAmount,
    required this.finalAmount,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.customerPhone,
    this.customerName,
    this.platformRate       = 0.0,
    this.platformFeeAmount  = 0.0,
  });

  bool get isAppOrder =>
      orderSource == 'SHOPEE_FOOD' || orderSource == 'GRAB_FOOD';

  /// Tổng hiển thị cho user = total - discount (giá gốc, chưa trừ phí sàn)
  double get grossAfterDiscount => totalAmount - discountAmount;

  factory PosOrderModel.fromJson(Map<String, dynamic> j) => PosOrderModel(
    id:                 j['id'] as int,
    orderCode:          j['orderCode'] as String,
    shiftId:            j['shiftId'] as int,
    staffName:          j['staffName'] as String? ?? '',
    orderSource:        j['orderSource'] as String? ?? 'TAKE_AWAY',
    status:             j['status'] as String? ?? '',
    paymentMethod:      j['paymentMethod'] as String? ?? 'CASH',
    totalAmount:        (j['totalAmount'] as num?)?.toDouble() ?? 0.0,
    discountAmount:     (j['discountAmount'] as num?)?.toDouble() ?? 0.0,
    finalAmount:        (j['finalAmount'] as num?)?.toDouble() ?? 0.0,
    note:               j['note'] as String?,
    createdAt:          j['createdAt'] as int? ?? 0,
    updatedAt:          j['updatedAt'] as int? ?? 0,
    items:              (j['items'] as List<dynamic>? ?? [])
        .map((e) => PosOrderItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    customerPhone:      j['customerPhone'] as String?,
    customerName:       j['customerName'] as String?,
    platformRate:       (j['platformRate'] as num?)?.toDouble() ?? 0.0,
    platformFeeAmount:  (j['platformFeeAmount'] as num?)?.toDouble()
        ?? (j['platformFee'] as num?)?.toDouble()
        ?? 0.0,
  );
}