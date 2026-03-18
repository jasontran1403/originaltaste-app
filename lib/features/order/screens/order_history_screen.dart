// lib/features/order/screens/order_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/order/order_models.dart';
import '../../../services/order_service.dart';
import '../../../shared/widgets/order_shared_widgets.dart';
import '../controller/order_history_controller.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Gọi load dữ liệu ngay khi màn hình mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderHistoryProvider.notifier).loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bg,
      body: state.isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(primary)))
          : state.error != null
          ? _buildErrorState(state.error!, primary)
          : state.orders.isEmpty
          ? _buildEmptyState(secondary)
          : RefreshIndicator(
        onRefresh: () => ref.read(orderHistoryProvider.notifier).loadOrders(),
        color: primary,
        backgroundColor: cardBg,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 30, 16, 100),
          itemCount: state.orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final order = state.orders[index];
            return _OrderCard(
              order: order,
              isDark: isDark,
              primary: primary,
              secondary: secondary,
              cardBg: cardBg,
              border: border,
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorMsg, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 80, color: Colors.redAccent),
          const SizedBox(height: 24),
          Text(
            'Đã xảy ra lỗi',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.redAccent),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMsg,
              style: TextStyle(fontSize: 16, color: Colors.redAccent.withOpacity(0.9)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => ref.read(orderHistoryProvider.notifier).loadOrders(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color secondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 100,
            color: secondary.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Chưa có đơn hàng nào',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: secondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Các đơn hàng đã tạo sẽ hiển thị ở đây',
            style: TextStyle(fontSize: 16, color: secondary.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

// Modern Order Card
class _OrderCard extends StatefulWidget {
  final OrderModel order;
  final bool isDark;
  final Color primary, secondary, cardBg, border;

  const _OrderCard({
    required this.order,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.cardBg,
    required this.border,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _isExporting = false;

  OrderModel get o => widget.order;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/order-detail/${o.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: widget.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: widget.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.isDark ? 0.25 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildInfo(),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final divider = widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_outlined, size: 22, color: widget.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.orderCode,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fmtOrderDate(o.createdAt),
                  style: TextStyle(fontSize: 13, color: widget.secondary),
                ),
              ],
            ),
          ),
          OrderStatusBadge(status: o.status),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Khách hàng
          if (o.customerName != null || o.customerPhone != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.person_outline_rounded, size: 16, color: widget.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [o.customerName, o.customerPhone]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(' • '),
                      style: TextStyle(fontSize: 14, color: widget.secondary),
                    ),
                  ),
                ],
              ),
            ),

          // Số lượng & Thanh toán
          Row(
            children: [
              Icon(Icons.shopping_bag_outlined, size: 16, color: widget.secondary),
              const SizedBox(width: 8),
              Text(
                '${o.items.length} sản phẩm',
                style: TextStyle(fontSize: 14, color: widget.secondary),
              ),
              const Spacer(),
              PaymentStatusBadge(status: o.paymentStatus),
            ],
          ),
          const SizedBox(height: 12),

          // Tổng tiền
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng cộng:',
                style: TextStyle(fontSize: 15, color: widget.secondary),
              ),
              Row(
                children: [
                  Text(
                    fmtMoney(o.finalAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                  if (o.discountAmount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-${fmtMoney(o.discountAmount)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.visibility_outlined,
              label: 'Chi tiết',
              onTap: () => context.push('/order-detail/${o.id}'),
              outlined: true,
              color: widget.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              icon: _isExporting ? Icons.hourglass_empty_rounded : Icons.picture_as_pdf_outlined,
              label: _isExporting ? 'Đang tạo...' : 'Xuất PDF',
              onTap: _isExporting ? null : () => _exportInvoice(context),
              loading: _isExporting,
              color: widget.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportInvoice(BuildContext ctx) async {
    setState(() => _isExporting = true);
    try {
      final result = await OrderService.instance.generateInvoice(o.id);
      if (!ctx.mounted) return;
      final msg = result.isSuccess
          ? (result.data ?? 'Đã gửi hóa đơn qua Telegram')
          : (result.message ?? 'Không thể xuất PDF');
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: result.isSuccess ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: Duration(seconds: result.isSuccess ? 4 : 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

// Nút action hiện đại, hỗ trợ loading & outlined
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined;
  final bool loading;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.outlined = false,
    this.loading = false,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: outlined ? null : (loading ? color.withOpacity(0.6) : color),
          border: outlined ? Border.all(color: color, width: 1.5) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: loading
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: outlined ? color : Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: outlined ? color : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper functions (giữ nguyên)
String fmtOrderDate(int? timestamp) {
  if (timestamp == null || timestamp == 0) return 'Không rõ';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}

String fmtMoney(double amount) {
  return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} đ';
}