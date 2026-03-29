// lib/features/order/screens/order_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/order/order_models.dart';
import '../../../shared/widgets/order_shared_widgets.dart';
import '../controller/order_history_controller.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Gọi load chi tiết đơn hàng ngay khi màn hình mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderDetailProvider(widget.orderId).notifier).loadOrder();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderDetailProvider(widget.orderId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: state.isLoading
          ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(primary)))
          : state.error != null
          ? _buildErrorState(state.error!, primary)
          : state.order == null
          ? const Center(child: Text('Không tìm thấy đơn hàng'))
          : _OrderDetailContent(
        order: state.order!,
        orderId: widget.orderId,
        exporting: state.isExporting,
        isDark: isDark,
        primary: primary,
        secondary: secondary,
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
            onPressed: () => ref.read(orderDetailProvider(widget.orderId).notifier).loadOrder(),
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
}

// ══════════════════════════════════════════════════════════════════
// MAIN CONTENT
// ══════════════════════════════════════════════════════════════════

class _OrderDetailContent extends ConsumerWidget {
  final OrderModel order;
  final int orderId;
  final bool exporting, isDark;
  final Color primary, secondary;

  const _OrderDetailContent({
    required this.order,
    required this.orderId,
    required this.exporting,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg  = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color:        cardBg,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: border),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          _Divider(border: border),
          const SizedBox(height: 20),
          _buildCustomerSection(),
          const SizedBox(height: 24),
          _Divider(border: border),
          const SizedBox(height: 20),
          _buildItemsTable(border),
          const SizedBox(height: 24),
          _Divider(border: border),
          const SizedBox(height: 16),
          _buildSummary(),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:        secondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.arrow_back_rounded, size: 18, color: secondary),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
            order.orderCode,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize:   20,
              color:      primary,
            ),
          )),
          const SizedBox(width: 12),
          OrderStatusBadge(status: order.status, fontSize: 12),
        ]),
        if (order.createdAt != null) ...[
          const SizedBox(height: 6),
          Text(fmtOrderDate(order.createdAt),
              style: TextStyle(fontSize: 12, color: secondary)),
        ],
      ])),
    ]);
  }

  // ── Customer section ──────────────────────────────────────────
  Widget _buildCustomerSection() {
    final hasInfo = (order.customerName?.isNotEmpty ?? false) ||
        (order.customerPhone?.isNotEmpty ?? false) ||
        (order.shippingAddress?.isNotEmpty ?? false);

    return LayoutBuilder(builder: (ctx, constraints) {
      final isNarrow = constraints.maxWidth < 500;

      final customerCol = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OrderSectionTitle('Thông tin khách hàng'),
        const SizedBox(height: 12),
        if (order.customerName?.isNotEmpty ?? false)
          InfoRow(Icons.person_outline, order.customerName!.trim()),
        if (order.customerPhone?.isNotEmpty ?? false)
          InfoRow(Icons.phone_outlined, order.customerPhone!.trim()),
        if (order.shippingAddress?.isNotEmpty ?? false)
          InfoRow(Icons.location_on_outlined, order.shippingAddress!.trim()),
        if (!hasInfo)
          Text('Khách vãng lai',
              style: TextStyle(fontSize: 13, color: secondary)),
      ]);

      final paymentCol = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OrderSectionTitle('Thanh toán & Ghi chú'),
        const SizedBox(height: 12),
        InfoRow(
          order.paymentStatus == 'PAID'
              ? Icons.check_circle_outline
              : Icons.radio_button_unchecked,
          paymentStatusLabel(order.paymentStatus),
          color: order.paymentStatus == 'PAID' ? Colors.green : Colors.orange,
        ),
        if (order.paymentMethod?.isNotEmpty ?? false)
          InfoRow(Icons.payment_outlined,
              paymentMethodLabel(order.paymentMethod!.trim())),
        if (order.notes?.isNotEmpty ?? false)
          InfoRow(Icons.notes_outlined, order.notes!.trim(),
              color: Colors.orange.shade700),
      ]);

      if (isNarrow) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          customerCol, const SizedBox(height: 20), paymentCol,
        ]);
      }

      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: customerCol),
        const SizedBox(width: 24),
        Expanded(child: paymentCol),
      ]);
    });
  }

  // ── Items table ───────────────────────────────────────────────
  Widget _buildItemsTable(Color border) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OrderSectionTitle('Sản phẩm (${order.items.length})'),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          border:       Border.all(color: border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color:        secondary.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(children: [
              Expanded(flex: 4, child: _TH('Tên sản phẩm')),
              Expanded(flex: 1, child: _TH('SL',     center: true)),
              Expanded(flex: 2, child: _TH('Đơn giá', center: true)),
              Expanded(flex: 2, child: _TH('Thành tiền', right: true)),
            ]),
          ),
          // Rows
          ...order.items.asMap().entries.map((entry) {
            final idx  = entry.key;
            final item = entry.value;
            final evenBg = isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.015);

            return Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: border)),
                color: idx.isEven ? Colors.transparent : evenBg,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Tên + ghi chú
                Expanded(
                  flex: 4,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.productName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    // Chế độ giá
                    _PriceModeBadge(item: item, primary: primary),
                    if (item.notes?.isNotEmpty ?? false)
                      Text('Ghi chú: ${item.notes}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade700,
                              fontStyle: FontStyle.italic)),
                  ]),
                ),

                // SL
                Expanded(
                  flex: 1,
                  child: Text(
                    '${fmtQtyDisplay(item.quantity)} ${item.unit ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),

                // Đơn giá (có gạch ngang giá gốc nếu khác)
                Expanded(
                  flex: 2,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Text(fmtMoney(item.unitPrice),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primary)),
                    if (item.basePrice != item.unitPrice)
                      Text(fmtMoney(item.basePrice),
                          style: TextStyle(
                              fontSize: 11,
                              color: secondary.withOpacity(0.7),
                              decoration: TextDecoration.lineThrough)),
                  ]),
                ),

                // Thành tiền
                Expanded(
                  flex: 2,
                  child: Text(fmtMoney(item.subtotal),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primary)),
                ),
              ]),
            );
          }),
        ]),
      ),
    ]);
  }

  // ── Summary ───────────────────────────────────────────────────
  Widget _buildSummary() {
    // VAT breakdown từ items
    final vatBreakdown = <int, double>{};
    for (final item in order.items) {
      if (item.vatRate > 0 && item.vatAmount > 0) {
        vatBreakdown.update(
          item.vatRate,
              (v) => v + item.vatAmount,
          ifAbsent: () => item.vatAmount,
        );
      }
    }

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 300,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _SummaryLine(
              label:  'Tạm tính',
              value:  fmtMoney(order.totalAmount),
              isDark: isDark),
          if (order.discountAmount > 0)
            _SummaryLine(
                label:      'Chiết khấu',
                value:      '-${fmtMoney(order.discountAmount)}',
                valueColor: Colors.green,
                isDark:     isDark),
          if (order.vatAmount > 0) ...[
            _SummaryLine(
                label:      'VAT',
                value:      '+${fmtMoney(order.vatAmount)}',
                valueColor: Colors.orange,
                isDark:     isDark),
            ...vatBreakdown.entries.map((e) => Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: _SummaryLine(
                  label:      '↳ VAT ${e.key}%',
                  value:      '+${fmtMoney(e.value)}',
                  valueColor: Colors.orange.withOpacity(0.8),
                  fontSize:   12,
                  isDark:     isDark),
            )),
          ],
          const SizedBox(height: 8),
          Divider(color: secondary.withOpacity(0.2), height: 1),
          const SizedBox(height: 8),
          _SummaryLine(
              label:      'Tổng cộng',
              value:      fmtMoney(order.finalAmount),
              bold:       true,
              valueColor: primary,
              fontSize:   16,
              isDark:     isDark),
        ]),
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════════
// PRIVATE HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════

class _Divider extends StatelessWidget {
  final Color border;
  const _Divider({required this.border});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: border);
}

class _TH extends StatelessWidget {
  final String text;
  final bool center, right;
  const _TH(this.text, {this.center = false, this.right = false});

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: right
        ? TextAlign.right
        : center ? TextAlign.center : TextAlign.left,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
  );
}

// Chế độ giá badge — tái sử dụng từ shared logic
class _PriceModeBadge extends StatelessWidget {
  final OrderItemModel item;
  final Color primary;
  const _PriceModeBadge({required this.item, required this.primary});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (item.priceMode) {
      'TIER'             => (primary, item.tierName != null ? 'Khung: ${item.tierName}' : 'Giá khung'),
      'DISCOUNT_PERCENT' => (Colors.green, item.discountPercent != null ? 'Giảm ${item.discountPercent}%' : 'Giảm giá'),
      _                  => (Colors.grey.shade500, 'Giá gốc'),
    };

    if (label == 'Giá gốc') return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool bold, isDark;
  final double fontSize;

  const _SummaryLine({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
    this.bold     = false,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final onBg = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize:   fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color:      bold ? onBg : secondary,
          )),
          Text(value, style: TextStyle(
            fontSize:   fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color:      valueColor ?? onBg,
          )),
        ],
      ),
    );
  }
}