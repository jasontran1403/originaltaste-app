// lib/services/inventory_batch_service.dart
import 'dart:convert';
import 'dart:io';
import '../data/models/management/inventory_batch_models.dart';
import '../data/network/api_result.dart';
import '../data/network/dio_client.dart';

class InventoryBatchService {
  InventoryBatchService._();
  static final InventoryBatchService instance = InventoryBatchService._();

  static const _base = '/api/seller/inventory-batches';

  // ── List batches (tab Phiếu / filter theo action) ─────────────────
  Future<ApiResult<List<InventoryBatchSummary>>> getBatches({
    String? action, // null=tất cả, "IMPORT"|"EXPORT"|"ADJUST"
    int page = 0,
    int size = 30,
  }) {
    return DioClient.instance.get<List<InventoryBatchSummary>>(
      _base,
      queryParams: {
        'page': page,
        'size': size,
        if (action != null) 'action': action,
      },
      fromData: (d) {
        final content = (d is Map ? d['content'] : d) as List? ?? [];
        return content
            .map((e) => InventoryBatchSummary.fromJson(e))
            .toList();
      },
    );
  }

  // ── Detail ─────────────────────────────────────────────────────────
  Future<ApiResult<InventoryBatchDetail>> getBatchDetail(int id) {
    return DioClient.instance.get<InventoryBatchDetail>(
      '$_base/$id',
      fromData: (d) => InventoryBatchDetail.fromJson(d),
    );
  }

  // ── Nhập kho (multipart: data JSON + image optional) ───────────────
  Future<ApiResult<Map<String, dynamic>>> importBatch({
    required List<Map<String, dynamic>> items,
    String? supplierRef,
    File?   receiptImage,
  }) {
    final dataMap = {
      'items': items,
      if (supplierRef != null && supplierRef.isNotEmpty)
        'supplierRef': supplierRef,
    };

    return DioClient.instance.postMultipart<Map<String, dynamic>>(
      '$_base/import',
      fields: {'data': jsonEncode(dataMap)},
      files: receiptImage != null ? {'image': receiptImage} : null,
      fromData: (d) => d as Map<String, dynamic>,
    );
  }

  // ── Xuất kho ───────────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> exportBatch(ExportRequest req) {
    return DioClient.instance.post<Map<String, dynamic>>(
      '$_base/export',
      body: req.toJson(),
      fromData: (d) => d as Map<String, dynamic>,
    );
  }

  // ── Kiểm kho ───────────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> checkBatch(StockCheckRequest req) {
    return DioClient.instance.post<Map<String, dynamic>>(
      '$_base/check',
      body: req.toJson(),
      fromData: (d) => d as Map<String, dynamic>,
    );
  }
}