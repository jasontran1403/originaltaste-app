// lib/data/models/management/inventory_batch_models.dart

// ── Summary (list) ─────────────────────────────────────────────
import 'package:flutter/cupertino.dart';

import '../../../core/constants/api_constants.dart';

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
  final String? receiptImageUrl;  // giữ backward compat
  final List<String> imageUrls;   // ← THÊM
  final String createdByName;
  final int    createdAt;
  final List<BatchLogLine> lines;

  const InventoryBatchDetail({
    required this.id,
    required this.batchCode,
    required this.action,
    this.supplierRef,
    this.receiptImageUrl,
    this.imageUrls = const [],   // ← THÊM
    required this.createdByName,
    required this.createdAt,
    required this.lines,
  });

  factory InventoryBatchDetail.fromJson(Map<String, dynamic> j) {
    List<String> urls = [];

    // ← Build full URL từ path tương đối
    String? buildUrl(String? path) {
      if (path == null || path.isEmpty) return null;
      if (path.startsWith('http')) return path; // đã là full URL
      return '${ApiConstants.baseUrl}${ApiConstants.images}$path';
    }

    if (j['imageUrls'] is List) {
      urls = (j['imageUrls'] as List)
          .map((e) => buildUrl(e as String?))
          .whereType<String>()
          .toList();
    }
    if (urls.isEmpty && j['receiptImageUrl'] != null) {
      final url = buildUrl(j['receiptImageUrl'] as String?);
      if (url != null) urls = [url];
    }

    return InventoryBatchDetail(
      id:             (j['id'] as num).toInt(),
      batchCode:      j['batchCode'] as String,
      action:         j['action']    as String,
      supplierRef:    j['supplierRef']    as String?,
      receiptImageUrl: j['receiptImageUrl'] as String?,
      imageUrls:      urls,
      createdByName:  j['createdByName'] as String,
      createdAt:      (j['createdAt'] as num).toInt(),
      lines: (j['lines'] as List)
          .map((e) => BatchLogLine.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
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