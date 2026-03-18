// lib/services/seller_service.dart

import '../data/models/management/management_models.dart';
import '../data/models/order/order_models.dart'
    show
    ProductPriceTierModel,
    OrderModel,
    OrderItemModel,
    OrderItemIngredientModel,
    CartItem,
    CustomerModel,
    CustomerAddressModel,
    SelectedCustomer,
    CreateOrderItemRequest,
    CreateOrderRequest,
    OrderMode,
    ItemPriceMode;
import '../data/network/api_result.dart';
import 'package:dio/dio.dart';
import '../data/network/dio_client.dart';

class SellerService {
  SellerService._();
  static final SellerService instance = SellerService._();

  // ══════════════════════════════════════════════════════════════
  // INGREDIENTS
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<List<IngredientModel>>> getIngredients({
    int page = 0,
    int size = 20,
  }) {
    return DioClient.instance.get<List<IngredientModel>>(
      '/api/seller/ingredients',
      queryParams: {'page': page, 'size': size},
      fromData: (d) {
        if (d is Map && d['content'] is List) {
          return (d['content'] as List)
              .map((e) => IngredientModel.fromJson(e))
              .toList();
        }
        if (d is List) return d.map((e) => IngredientModel.fromJson(e)).toList();
        return <IngredientModel>[];
      },
    );
  }

  Future<ApiResult<IngredientModel>> getIngredientById(int id) {
    return DioClient.instance.get<IngredientModel>(
      '/api/seller/ingredients/$id',
      fromData: (d) => IngredientModel.fromJson(d),
    );
  }

  Future<ApiResult<IngredientModel>> createIngredient({
    required String name,
    required String unit,
    required double stockQuantity,
    int? importDate,
    int? expiryDate,
  }) {
    return DioClient.instance.post<IngredientModel>(
      '/api/seller/ingredients',
      body: {
        'name':          name,
        'unit':          unit,
        'stockQuantity': stockQuantity,
        if (importDate != null) 'importDate': importDate,
        if (expiryDate != null) 'expiryDate': expiryDate,
      },
      fromData: (d) => IngredientModel.fromJson(d),
    );
  }

  Future<ApiResult<IngredientModel>> updateIngredient({
    required int id,
    required String name,
    required String unit,
    required double stockQuantity,
    int? importDate,
    int? expiryDate,
  }) {
    return DioClient.instance.put<IngredientModel>(
      '/api/seller/ingredients/$id',
      body: {
        'name':          name,
        'unit':          unit,
        'stockQuantity': stockQuantity,
        if (importDate != null) 'importDate': importDate,
        if (expiryDate != null) 'expiryDate': expiryDate,
      },
      fromData: (d) => IngredientModel.fromJson(d),
    );
  }

  Future<ApiResult<void>> deleteIngredient(int id) {
    return DioClient.instance.delete<void>('/api/seller/ingredients/$id');
  }

  // ══════════════════════════════════════════════════════════════
  // INVENTORY LOGS  (lịch sử xuất/nhập kho)
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<PaginatedLogs>> getInventoryLogs({
    int page = 0,
    int size = 20,
    int? ingredientId,
  }) {
    return DioClient.instance.get<PaginatedLogs>(
      '/api/seller/inventory-logs',
      queryParams: {
        'page': page,
        'size': size,
        if (ingredientId != null) 'ingredientId': ingredientId,
      },
      fromData: (d) => PaginatedLogs.fromJson(d as Map<String, dynamic>),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // MANUAL IMPORT  (nhập kho thủ công — batch)
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<ManualImportResult>> manualImportIngredients(
      List<ManualImportItem> items) {
    return DioClient.instance.post<ManualImportResult>(
      '/api/seller/inventory-imports/manual',
      body: {'items': items.map((e) => e.toJson()).toList()},
      fromData: (d) => ManualImportResult.fromJson(d as Map<String, dynamic>),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // QR IMPORT  (nhập kho từ scan bao bì — lưu phiếu)
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<ManualImportResult>> qrImportWarehouse(
      ImportWarehouseModel model) {
    return DioClient.instance.post<ManualImportResult>(
      '/api/seller/inventory-imports/qr',
      body: {
        'importerName': model.importerName,
        'importTime':   model.importTime.toIso8601String(),
        'products':     model.products
            .map((p) => {
          'productName':       p.productName,
          'manufacturingDate': p.manufacturingDate.toIso8601String(),
          'expiryDate':        p.expiryDate.toIso8601String(),
          'packageWeight':     p.packageWeight,
          'batchWeight':       p.batchWeight,
          'quantity':          p.quantity,
        })
            .toList(),
      },
      fromData: (d) => ManualImportResult.fromJson(d as Map<String, dynamic>),
    );
  }

// ══════════════════════════════════════════════════════════════════
  // PRODUCTS
  // ══════════════════════════════════════════════════════════════════

  Future<ApiResult<List<MgmtProductModel>>> getProducts({
    int page = 0,
    int size = 50,
    int? categoryId,
  }) {
    return DioClient.instance.get<List<MgmtProductModel>>(
      '/api/seller/products',
      queryParams: {
        'page': page,
        'size': size,
        if (categoryId != null) 'categoryId': categoryId,
      },
      fromData: (d) {
        if (d is Map && d['content'] is List) {
          return (d['content'] as List)
              .map((e) => MgmtProductModel.fromJson(e))
              .toList();
        }
        if (d is List) return d.map((e) => MgmtProductModel.fromJson(e)).toList();
        return <MgmtProductModel>[];
      },
    );
  }

  Future<ApiResult<MgmtProductModel>> createProduct({
    required String name,
    required double basePrice,
    String? unit,
    String? imageUrl,
    String? description,
    int? categoryId,
    String? categoryName,
    bool isAvailable = true,
    int vatRate = 0,
    List<Map<String, dynamic>>? tiers,
    List<Map<String, dynamic>>? ingredients,
  }) {
    return DioClient.instance.post<MgmtProductModel>(
      '/api/seller/products',
      body: {
        'name':        name,
        'basePrice':   basePrice,
        if (unit         != null) 'unit':         unit,
        if (imageUrl     != null) 'imageUrl':     imageUrl,
        if (description  != null) 'description':  description,
        if (categoryId   != null) 'categoryId':   categoryId,
        if (categoryName != null) 'category':     categoryName,
        'isAvailable': isAvailable,
        'vatRate':     vatRate,
        if (tiers       != null && tiers.isNotEmpty)       'tiers':       tiers,
        if (ingredients != null && ingredients.isNotEmpty) 'ingredients': ingredients,
      },
      fromData: (d) => MgmtProductModel.fromJson(d),
    );
  }

  Future<ApiResult<MgmtProductModel>> updateProduct({
    required int id,
    required String name,
    required double basePrice,
    String? unit,
    String? imageUrl,
    String? description,
    int? categoryId,
    String? categoryName,
    bool isAvailable = true,
    int vatRate = 0,
    List<Map<String, dynamic>>? tiers,
    List<Map<String, dynamic>>? ingredients,
  }) {
    return DioClient.instance.put<MgmtProductModel>(
      '/api/seller/products/$id',
      body: {
        'name':        name,
        'basePrice':   basePrice,
        if (unit         != null) 'unit':         unit,
        if (imageUrl     != null) 'imageUrl':     imageUrl,
        if (description  != null) 'description':  description,
        if (categoryId   != null) 'categoryId':   categoryId,
        if (categoryName != null) 'category':     categoryName,
        'isAvailable': isAvailable,
        'vatRate':     vatRate,
        if (tiers       != null && tiers.isNotEmpty)       'tiers':       tiers,
        if (ingredients != null && ingredients.isNotEmpty) 'ingredients': ingredients,
      },
      fromData: (d) => MgmtProductModel.fromJson(d),
    );
  }

  Future<ApiResult<void>> deleteProduct(int id) {
    return DioClient.instance.delete<void>('/api/seller/products/$id');
  }

  // ══════════════════════════════════════════════════════════════════
  // CATEGORIES
  // ══════════════════════════════════════════════════════════════════

  Future<ApiResult<List<MgmtCategoryModel>>> getCategories() {
    return DioClient.instance.get<List<MgmtCategoryModel>>(
      '/api/seller/categories',
      fromData: (d) {
        if (d is List) return d.map((e) => MgmtCategoryModel.fromJson(e)).toList();
        return <MgmtCategoryModel>[];
      },
    );
  }

  Future<ApiResult<MgmtCategoryModel>> createCategory({
    required String name,
    String? imageUrl,
  }) {
    return DioClient.instance.post<MgmtCategoryModel>(
      '/api/seller/categories',
      body: {
        'name': name,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
      fromData: (d) => MgmtCategoryModel.fromJson(d),
    );
  }

  Future<ApiResult<MgmtCategoryModel>> updateCategory({
    required int id,
    required String name,
    String? imageUrl,
  }) {
    return DioClient.instance.put<MgmtCategoryModel>(
      '/api/seller/categories/$id',
      body: {
        'name': name,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
      fromData: (d) => MgmtCategoryModel.fromJson(d),
    );
  }

  Future<ApiResult<void>> deleteCategory(int id) {
    return DioClient.instance.delete<void>('/api/seller/categories/$id');
  }

  // ══════════════════════════════════════════════════════════════════
  // IMAGE UPLOAD
  // ══════════════════════════════════════════════════════════════════

  Future<ApiResult<String>> uploadCategoryImage(String filePath) {
    return DioClient.instance.upload<String>(
      '/api/upload/categories/upload-image',
      filePath: filePath,
      fieldName: 'file',           // ← khớp với @RequestParam("file")
      fromData: (rawData) {
        // rawData chính là json['data']
        if (rawData is String && rawData.isNotEmpty) {
          return rawData;
        }
        return null;
      },
    );
  }

  Future<ApiResult<String>> uploadProductImage(String filePath) {
    return DioClient.instance.upload<String>(
      '/api/upload/product-image',
      filePath: filePath,
      fieldName: 'image',          // ← khớp với @RequestParam("image")
      fromData: (rawData) {
        if (rawData is Map<String, dynamic>) {
          final imageUrl = rawData['imageUrl']?.toString();
          if (imageUrl != null && imageUrl.isNotEmpty) {
            return imageUrl;
          }
        }
        return null;
      },
    );
  }
}