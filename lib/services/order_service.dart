// lib/services/order_service.dart

import '../../core/constants/api_constants.dart';
import '../data/models/order/order_models.dart';
import '../data/network/api_result.dart';
import '../data/network/dio_client.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  // ── Image helper ──────────────────────────────────────────────
  static String buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConstants.baseUrl}${ApiConstants.images}/$path';
  }

  // ══════════════════════════════════════════════════════════════
  // PRODUCTS
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<List<ProductModel>>> getProducts({
    int page = 0,
    int size = 200,
    int? categoryId,
  }) {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (categoryId != null) 'categoryId': categoryId,
    };
    return DioClient.instance.get<List<ProductModel>>(
      '/api/seller/products',
      queryParams: params,
      fromData: (d) {
        if (d is Map && d['content'] is List) {
          return (d['content'] as List)
              .map((e) => ProductModel.fromJson(e))
              .toList();
        }
        if (d is List) return d.map((e) => ProductModel.fromJson(e)).toList();
        return <ProductModel>[];
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CATEGORIES
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<List<CategoryModel>>> getCategories() {
    return DioClient.instance.get<List<CategoryModel>>(
      '/api/seller/categories',
      fromData: (d) {
        if (d is List) return d.map((e) => CategoryModel.fromJson(e)).toList();
        return <CategoryModel>[];
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CUSTOMERS
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<CustomerModel?>> getCustomerByPhone(String phone) {
    return DioClient.instance.get<CustomerModel?>(
      '/api/seller/customers/phone/$phone',
      fromData: (d) =>
      d != null ? CustomerModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<ApiResult<CustomerModel>> createCustomer({
    required String phone,
    String? name,
    String? email,
    int discountRate = 0,
    List<Map<String, dynamic>>? addresses,
  }) {
    return DioClient.instance.post<CustomerModel>(
      '/api/seller/customers',
      body: {
        'phone': phone,
        if (name != null)      'name':         name,
        if (email != null)     'email':        email,
        'discountRate':        discountRate,
        if (addresses != null) 'addresses':    addresses,
      },
      fromData: (d) =>
      d != null ? CustomerModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<ApiResult<CustomerModel>> updateCustomer({
    required int id,
    required String phone,
    String? name,
    String? email,
    int discountRate = 0,
    List<Map<String, dynamic>>? addresses,
  }) {
    return DioClient.instance.put<CustomerModel>(
      '/api/seller/customers/$id',
      body: {
        'phone': phone,
        if (name != null)      'name':         name,
        if (email != null)     'email':        email,
        'discountRate':        discountRate,
        if (addresses != null) 'addresses':    addresses,
      },
      fromData: (d) =>
      d != null ? CustomerModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ORDERS
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<List<OrderModel>>> getOrders() {
    return DioClient.instance.get<List<OrderModel>>(
      '/api/seller/orders',
      fromData: (d) {
        if (d is List) return d.map((e) => OrderModel.fromJson(e)).toList();
        return <OrderModel>[];
      },
    );
  }

  Future<ApiResult<OrderModel>> getOrderById(int id) {
    return DioClient.instance.get<OrderModel>(
      '/api/seller/orders/$id',
      fromData: (d) =>
      d != null ? OrderModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<ApiResult<OrderModel>> createOrder(CreateOrderRequest request) {
    return DioClient.instance.post<OrderModel>(
      '/api/seller/orders',
      body: request.toJson(),
      fromData: (d) =>
      d != null ? OrderModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<ApiResult<OrderModel>> cancelOrder(int orderId) {
    return DioClient.instance.post<OrderModel>(
      '/api/seller/orders/$orderId/cancel',
      body: {},
      fromData: (d) =>
      d != null ? OrderModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<ApiResult<String>> generateInvoice(int orderId) {
    return DioClient.instance.get<String>(
      '/api/seller/orders/$orderId/invoice',
      fromData: (d) {
        if (d is Map<String, dynamic>) {
          return d['message']?.toString() ?? 'Đã gửi hóa đơn qua Telegram';
        }
        return d?.toString() ?? 'Thành công';
      },
    );
  }
}