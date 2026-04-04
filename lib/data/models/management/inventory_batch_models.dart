// lib/data/models/management/inventory_batch_models.dart

// ── Summary (list) ─────────────────────────────────────────────
class InventoryBatchSummary {
  final int    id;
  final String batchCode;
  final String action;       // "IMPORT" | "EXPORT" | "ADJUST"
  final String? supplierRef;
  final String? receiptImageUrl;
  final String  createdByName;
  final int     createdAt;   // epoch ms
  final int     totalItems;

  const InventoryBatchSummary({
    required this.id,
    required this.batchCode,
    required this.action,
    this.supplierRef,
    this.receiptImageUrl,
    required this.createdByName,
    required this.createdAt,
    required this.totalItems,
  });

  factory InventoryBatchSummary.fromJson(Map<String, dynamic> j) =>
      InventoryBatchSummary(
        id:             j['id'] ?? 0,
        batchCode:      j['batchCode'] ?? '',
        action:         j['action'] ?? '',
        supplierRef:    j['supplierRef'],
        receiptImageUrl:j['receiptImageUrl'],
        createdByName:  j['createdByName'] ?? '',
        createdAt:      j['createdAt'] ?? 0,
        totalItems:     j['totalItems'] ?? 0,
      );
}

// ── Detail ─────────────────────────────────────────────────────
class InventoryBatchDetail {
  final int    id;
  final String batchCode;
  final String action;
  final String? supplierRef;
  final String? receiptImageUrl;
  final String  createdByName;
  final int     createdAt;
  final List<BatchLogLine> lines;

  const InventoryBatchDetail({
    required this.id,
    required this.batchCode,
    required this.action,
    this.supplierRef,
    this.receiptImageUrl,
    required this.createdByName,
    required this.createdAt,
    required this.lines,
  });

  factory InventoryBatchDetail.fromJson(Map<String, dynamic> j) =>
      InventoryBatchDetail(
        id:              j['id'] ?? 0,
        batchCode:       j['batchCode'] ?? '',
        action:          j['action'] ?? '',
        supplierRef:     j['supplierRef'],
        receiptImageUrl: j['receiptImageUrl'],
        createdByName:   j['createdByName'] ?? '',
        createdAt:       j['createdAt'] ?? 0,
        lines: (j['lines'] as List? ?? [])
            .map((e) => BatchLogLine.fromJson(e))
            .toList(),
      );
}

class BatchLogLine {
  final int    ingredientId;
  final String ingredientName;
  final String unit;
  final double quantity;       // dương=nhập/dư, âm=xuất/thiếu, 0=khớp
  final double quantityBefore;
  final double quantityAfter;
  final String? adjustStatus;  // "MATCH" | "SHORTAGE" | "SURPLUS"

  const BatchLogLine({
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.quantity,
    required this.quantityBefore,
    required this.quantityAfter,
    this.adjustStatus,
  });

  factory BatchLogLine.fromJson(Map<String, dynamic> j) => BatchLogLine(
    ingredientId:   j['ingredientId'] ?? 0,
    ingredientName: j['ingredientName'] ?? '',
    unit:           j['unit'] ?? '',
    quantity:       (j['quantity'] ?? 0).toDouble(),
    quantityBefore: (j['quantityBefore'] ?? 0).toDouble(),
    quantityAfter:  (j['quantityAfter'] ?? 0).toDouble(),
    adjustStatus:   j['adjustStatus'],
  );
}

// ── Request: xuất kho ──────────────────────────────────────────
class ExportRequest {
  final String? reason;
  final List<ExportItem> items;

  const ExportRequest({this.reason, required this.items});

  Map<String, dynamic> toJson() => {
    if (reason != null && reason!.isNotEmpty) 'reason': reason,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class ExportItem {
  final int    ingredientId;
  final double quantity;

  const ExportItem({required this.ingredientId, required this.quantity});

  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    'quantity':     quantity,
  };
}

// ── Request: kiểm kho ──────────────────────────────────────────
class StockCheckRequest {
  final List<StockCheckItem> items;

  const StockCheckRequest({required this.items});

  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class StockCheckItem {
  final int    ingredientId;
  final double actualQuantity;

  const StockCheckItem({
    required this.ingredientId,
    required this.actualQuantity,
  });

  Map<String, dynamic> toJson() => {
    'ingredientId':   ingredientId,
    'actualQuantity': actualQuantity,
  };
}