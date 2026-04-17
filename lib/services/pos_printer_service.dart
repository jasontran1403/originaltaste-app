// lib/services/pos_printer_service.dart
// Zywell ZY808 — Page0 (PC437) only, no Vietnamese font
// → Strip diacritics, print clean ASCII
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:originaltaste/services/pos_service.dart';

// ═══════════════════════════════════════════════════════════════
// StoreProfile
// ═══════════════════════════════════════════════════════════════

class StoreProfile {
  final String  name;
  final String  address;
  final String  phone;
  final String? printerIp;
  final double  shopeeRate;
  final double  grabRate;

  const StoreProfile({
    required this.name, required this.address,
    required this.phone, this.printerIp,
    this.shopeeRate = 0.0,
    this.grabRate   = 0.0,
  });
  factory StoreProfile.fromJson(Map<String, dynamic> j) => StoreProfile(
    name:       j['name']      as String? ?? '',
    address:    j['address']   as String? ?? '',
    phone:      j['phone']     as String? ?? '',
    printerIp:  j['printerIp'] as String?,
    shopeeRate: (j['shopeeRate'] as num?)?.toDouble() ?? 0.0,
    grabRate:   (j['grabRate']   as num?)?.toDouble() ?? 0.0,
  );
}

// ═══════════════════════════════════════════════════════════════
// PrinterConfig
// ═══════════════════════════════════════════════════════════════

class PrinterConfig {
  static StoreProfile? storeProfile;
  static int           savedPort   = 9100;
  static int           timeoutMs   = 5000;
  static bool          isConnected = false;
  static String? _manualIp;
  static String? get savedIp => _manualIp ?? storeProfile?.printerIp;

  static double get shopeeRate => storeProfile?.shopeeRate ?? 0.0;
  static double get grabRate   => storeProfile?.grabRate   ?? 0.0;

  static Future<bool> loadStoreAndConnect() async {
    try {
      final res    = await PosService.instance.getStoreInfo();
      storeProfile = StoreProfile.fromJson(res);
      final ip     = storeProfile!.printerIp;
      if (ip == null || ip.trim().isEmpty) { isConnected = false; return false; }
      isConnected = await PosPrinterService.instance.testConnection(ip.trim());
      return isConnected;
    } catch (_) { isConnected = false; return false; }
  }

  static Future<bool> connectManualIp(String ip) async {
    try {
      final ok = await PosPrinterService.instance.testConnection(ip.trim());
      if (ok) { _manualIp = ip.trim(); isConnected = true; }
      else    { isConnected = false; }
      return isConnected;
    } catch (_) { isConnected = false; return false; }
  }
}

// ═══════════════════════════════════════════════════════════════
// Bill models
// ═══════════════════════════════════════════════════════════════

class BillAddon {
  final String name;
  final int    quantity;
  final double unitPrice;
  double get total => unitPrice * quantity;
  const BillAddon({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });
}

class BillItem {
  final String          name;
  final int             quantity;
  final double          unitPrice;        // tổng / quantity (có weight)
  final double          basePricePerUnit; // ← THÊM: giá/kg sau giảm %
  final int             discountPercent;
  final List<BillAddon> addons;
  final String?         weightLabel;
  double get total => quantity * unitPrice;
  const BillItem({
    required this.name, required this.quantity,
    required this.unitPrice,
    this.basePricePerUnit = 0,            // ← THÊM
    this.discountPercent  = 0,
    this.addons = const [], this.weightLabel,
  });
}

class BillData {
  final String         orderCode;
  final DateTime       printTime;
  final String         cashierName;
  final String?        customerPhone;
  final String?        customerName;
  final String         orderSource;
  final List<BillItem> items;
  final double         subTotal;
  final double         discountAmount;
  final double         vatAmount;
  final double         finalAmount;
  final String         paymentMethod;
  final double         platformFee;
  final double         platformRate;
  final double         netRevenue;
  final Map<int, double> vatBreakdown;
  final String? eVoucherCode;
  final double  eVoucherDiscount;

  const BillData({
    required this.orderCode, required this.printTime,
    required this.cashierName, this.customerPhone, this.customerName,
    required this.orderSource, required this.items,
    required this.subTotal, this.discountAmount = 0,
    this.vatAmount = 0, required this.finalAmount,
    required this.paymentMethod,
    this.platformFee  = 0,
    this.platformRate = 0,
    this.netRevenue   = 0,
    this.eVoucherCode     = null,   // ← THÊM
    this.eVoucherDiscount = 0.0,    // ← THÊM
    this.vatBreakdown = const {},
  });

  @override
  String toString() {
    final sb = StringBuffer();
    sb.writeln('=== BillData ===');
    sb.writeln('orderCode: $orderCode');
    sb.writeln('printTime: $printTime');
    sb.writeln('cashierName: $cashierName');
    sb.writeln('customerPhone: $customerPhone');
    sb.writeln('customerName: $customerName');
    sb.writeln('orderSource: $orderSource');
    sb.writeln('subTotal: $subTotal');
    sb.writeln('discountAmount: $discountAmount');
    sb.writeln('vatAmount: $vatAmount');
    sb.writeln('finalAmount: $finalAmount');
    sb.writeln('paymentMethod: $paymentMethod');
    sb.writeln('platformFee: $platformFee');
    sb.writeln('platformRate: $platformRate');
    sb.writeln('netRevenue: $netRevenue');
    sb.writeln('vatBreakdown: $vatBreakdown');
    sb.writeln('items (${items.length}):');
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      sb.writeln('  [$i] name: ${item.name}');
      sb.writeln('      quantity: ${item.quantity}');
      sb.writeln('      unitPrice: ${item.unitPrice}');
      sb.writeln('      discountPercent: ${item.discountPercent}');
      sb.writeln('      weightLabel: ${item.weightLabel}');
      sb.writeln('      total: ${item.total}');
      for (final addon in item.addons) {
        sb.writeln('      addon: ${addon.name} x${addon.quantity} @ ${addon.unitPrice} = ${addon.total}');
      }
    }
    return sb.toString();
  }
}



// ═══════════════════════════════════════════════════════════════
// PrintResult
// ═══════════════════════════════════════════════════════════════

class PrintResult {
  final bool    isSuccess;
  final String? errorMessage;
  const PrintResult._({required this.isSuccess, this.errorMessage});
  static const PrintResult ok = PrintResult._(isSuccess: true);
  factory PrintResult.connectionFailed(String msg) =>
      PrintResult._(isSuccess: false, errorMessage: 'Khong ket noi duoc may in: $msg');
  factory PrintResult.error(String msg) =>
      PrintResult._(isSuccess: false, errorMessage: 'Loi in: $msg');
  factory PrintResult.notConfigured() =>
      PrintResult._(isSuccess: false, errorMessage: 'Chua cau hinh IP may in');
}

// ═══════════════════════════════════════════════════════════════
// Vietnamese → ASCII
// ═══════════════════════════════════════════════════════════════

String _vn(String s) {
  const m = <String, String>{
    'à':'a','á':'a','â':'a','ã':'a','ä':'a','å':'a',
    'è':'e','é':'e','ê':'e','ë':'e',
    'ì':'i','í':'i','î':'i','ï':'i',
    'ò':'o','ó':'o','ô':'o','õ':'o','ö':'o',
    'ù':'u','ú':'u','û':'u','ü':'u',
    'ý':'y','ỳ':'y','ỷ':'y','ỹ':'y','ỵ':'y',
    'À':'A','Á':'A','Â':'A','Ã':'A',
    'È':'E','É':'E','Ê':'E',
    'Ì':'I','Í':'I','Î':'I',
    'Ò':'O','Ó':'O','Ô':'O','Õ':'O',
    'Ù':'U','Ú':'U','Û':'U','Ý':'Y',
    'ă':'a','Ă':'A',
    'ắ':'a','Ắ':'A','ặ':'a','Ặ':'A','ằ':'a','Ằ':'A',
    'ẳ':'a','Ẳ':'A','ẵ':'a','Ẵ':'A',
    'ấ':'a','Ấ':'A','ậ':'a','Ậ':'A','ầ':'a','Ầ':'A',
    'ẩ':'a','Ẩ':'A','ẫ':'a','Ẫ':'A',
    'ả':'a','Ả':'A','ạ':'a','Ạ':'A',
    'ế':'e','Ế':'E','ệ':'e','Ệ':'E','ề':'e','Ề':'E',
    'ể':'e','Ể':'E','ễ':'e','Ễ':'E',
    'ẻ':'e','Ẻ':'E','ẽ':'e','Ẽ':'E','ẹ':'e','Ẹ':'E',
    'ị':'i','Ị':'I','ỉ':'i','Ỉ':'I','ĩ':'i','Ĩ':'I',
    'ố':'o','Ố':'O','ộ':'o','Ộ':'O','ồ':'o','Ồ':'O',
    'ổ':'o','Ổ':'O','ỗ':'o','Ỗ':'O',
    'ớ':'o','Ớ':'O','ợ':'o','Ợ':'O','ờ':'o','Ờ':'O',
    'ở':'o','Ở':'O','ỡ':'o','Ỡ':'O',
    'ơ':'o','Ơ':'O',
    'ọ':'o','Ọ':'O','ỏ':'o','Ỏ':'O',
    'ứ':'u','Ứ':'U','ự':'u','Ự':'U','ừ':'u','Ừ':'U',
    'ử':'u','Ử':'U','ữ':'u','Ữ':'U',
    'ư':'u','Ư':'U',
    'ụ':'u','Ụ':'U','ủ':'u','Ủ':'U','ũ':'u','Ũ':'U',
    'đ':'d','Đ':'D',
  };
  return s.split('').map((c) => m[c] ?? c).join();
}

// ═══════════════════════════════════════════════════════════════
// PosPrinterService
// ═══════════════════════════════════════════════════════════════

class PosPrinterService {
  static final PosPrinterService instance = PosPrinterService._();
  PosPrinterService._();

  final _fmt = NumberFormat('#,###', 'vi_VN');
  String _f(double v) => _fmt.format(v);

  // ── Layout constants ─────────────────────────────────────────
  static const int _width    = 48;
  // 3 cột cố định: tên(26) + SL(5) + giá(17) = 48
  static const int _colName  = 26;
  static const int _colQty   =  5;
  static const int _colAmt   = 17;
  // giữ lại cho _rowLR dùng ở các section khác
  static const int _rightWidth = 26;
  static const int _leftWidth  = _width - _rightWidth - 1;

  // ── ESC/POS raw helpers ──────────────────────────────────────

  List<int> _line(String text, {
    bool bold          = false,
    int  align         = 0,
    bool doubleHeight  = false,
    bool doubleWidth   = false,
    bool lf            = true,
  }) {
    final buf = <int>[];
    buf.addAll([0x1B, 0x40]);
    buf.addAll([0x1B, 0x74, 0]);
    buf.addAll([0x1B, 0x45, bold ? 1 : 0]);
    buf.addAll([0x1B, 0x61, align]);
    final h = doubleHeight, w = doubleWidth;
    buf.addAll([0x1D, 0x21, (h ? 0x10 : 0) | (w ? 0x20 : 0)]);
    buf.addAll(_vn(text).codeUnits);
    if (lf) buf.add(0x0A);
    buf.addAll([0x1B, 0x45, 0]);
    buf.addAll([0x1D, 0x21, 0x00]);
    buf.addAll([0x1B, 0x61, 0]);
    return buf;
  }

  /// In 1 dòng có cột trái + cột phải với padding chính xác.
  /// [leftMaxWidth] = độ rộng tối đa cột trái (nếu null dùng _leftWidth).
  List<int> _rowLR(
      String left,
      String right, {
        bool bold        = false,
        int? leftMaxWidth,
      }) {
    final maxL = leftMaxWidth ?? _leftWidth;
    var   l    = _vn(left);
    final r    = _vn(right);

    // Cắt tên nếu quá dài — đảm bảo không bị wrap
    if (l.length > maxL) l = '${l.substring(0, maxL - 2)}..';

    // Tính pad sao cho l + pad + r = _width
    final pad = (_width - l.length - r.length).clamp(1, _width);

    final buf = <int>[];
    buf.addAll([0x1B, 0x74, 0]);
    buf.addAll([0x1B, 0x45, bold ? 1 : 0]);
    buf.addAll([0x1D, 0x21, 0x00]);
    buf.addAll([0x1B, 0x61, 0]);
    buf.addAll(l.codeUnits);
    buf.addAll(List.filled(pad, 0x20));
    buf.addAll(r.codeUnits);
    buf.add(0x0A);
    buf.addAll([0x1B, 0x45, 0]);
    return buf;
  }

  List<int> _hr({String ch = '-'}) =>
      [...[0x1B, 0x74, 0], ...(ch * _width).codeUnits, 0x0A];

  List<int> _row3(String name, String qty, String amt, {bool bold = false}) {
    var n = _vn(name);
    if (n.length > _colName) n = '${n.substring(0, _colName - 2)}..';
    n = n.padRight(_colName);

    var q = _vn(qty);
    if (q.length > _colQty) q = q.substring(0, _colQty);
    q = q.padRight(_colQty);

    var a = _vn(amt);
    if (a.length > _colAmt) a = a.substring(0, _colAmt);
    a = a.padLeft(_colAmt); // căn phải

    final buf = <int>[];
    buf.addAll([0x1B, 0x74, 0]);
    buf.addAll([0x1B, 0x45, bold ? 1 : 0]);
    buf.addAll([0x1D, 0x21, 0x00]);
    buf.addAll([0x1B, 0x61, 0]);
    buf.addAll(n.codeUnits);
    buf.addAll(q.codeUnits);
    buf.addAll(a.codeUnits);
    buf.add(0x0A);
    buf.addAll([0x1B, 0x45, 0]);
    return buf;
  }

  // ── Build right column string ─────────────────────────────────
  // Format: "x1  25,000  25,000d"
  // Căn theo _rightWidth để đều cột với addon
  String _buildRight(int qty, double unitPrice, double total) {
    final qtyStr   = 'x$qty';
    final priceStr = _f(unitPrice);
    final totalStr = '${_f(total)}d';
    // Khoảng cách cố định 2 space giữa các cột
    return '$qtyStr  $priceStr  $totalStr';
  }

  // ── Test TCP ─────────────────────────────────────────────────
  Future<bool> testConnection(String ip, {int port = 9100}) async {
    try {
      final s = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 3));
      await s.close();
      return true;
    } catch (_) { return false; }
  }

  // ── Scan subnet ──────────────────────────────────────────────
  Future<List<String>> scanForPrinters({
    void Function(int progress, int total)? onProgress,
  }) async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false,
      );
      String? subnet;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
            final parts = ip.split('.');
            subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
            break;
          }
        }
        if (subnet != null) break;
      }
      if (subnet == null) return [];
      final found   = <String>[];
      final futures = <Future>[];
      int done = 0; const total = 254;
      for (int i = 1; i <= total; i++) {
        final ip = '$subnet.$i';
        futures.add(
          Socket.connect(ip, PrinterConfig.savedPort,
              timeout: const Duration(milliseconds: 400))
              .then((s) { s.destroy(); found.add(ip); })
              .catchError((_) {})
              .whenComplete(() { done++; onProgress?.call(done, total); }),
        );
      }
      await Future.wait(futures);
      found.sort();
      return found;
    } catch (_) { return []; }
  }

  // ── Build bill ───────────────────────────────────────────────
  Future<Uint8List> buildBill(BillData bill) async {
    final store = PrinterConfig.storeProfile;
    final buf   = <int>[];

    buf.addAll([0x1B, 0x40]);
    buf.addAll([0x1B, 0x74, 0]);

    // ── Header ────────────────────────────────────────────────
    final storeName    = store?.name.isNotEmpty    == true ? store!.name    : '';
    final storeAddress = store?.address.isNotEmpty == true ? store!.address : '';
    final storePhone   = store?.phone.isNotEmpty   == true ? store!.phone   : '';

    if (storeName.isNotEmpty)
      buf.addAll(_line(_vn(storeName), bold: true, align: 1));
    if (storeAddress.isNotEmpty)
      buf.addAll(_line(_vn(storeAddress), align: 1));
    if (storePhone.isNotEmpty)
      buf.addAll(_line('DT: ${_vn(storePhone)}', align: 1));
    buf.addAll(_hr());

    buf.addAll(_line('HOA DON BAN HANG', bold: true, align: 1));
    buf.addAll(_hr());

    // ── Thông tin đơn ────────────────────────────────────────
    final dateStr = DateFormat('dd/MM/yyyy').format(bill.printTime);
    final timeStr = DateFormat('HH:mm:ss').format(bill.printTime);

    buf.addAll(_line('So HD: ${bill.orderCode}'));
    buf.addAll(_rowLR('Ngay in: $dateStr', 'Gio: $timeStr'));
    buf.addAll(_line('Loai don: ${_vn(_srcLabel(bill.orderSource))}'));
    buf.addAll(_line('Thu ngan: ${_vn(bill.cashierName)}'));
    if (bill.customerPhone?.isNotEmpty == true) {
      final extra = bill.customerName?.isNotEmpty == true
          ? ' - ${_vn(bill.customerName!)}' : '';
      buf.addAll(_line('Khach: ${bill.customerPhone}$extra'));
    }
    buf.addAll(_hr());

    // ── Header cột ───────────────────────────────────────────
    buf.addAll(_row3('Ten mon', 'SL', 'Don gia', bold: true));
    buf.addAll(_hr(ch: '-'));

    // ── Danh sách món ────────────────────────────────────────
    if (bill.items.isNotEmpty) {
      for (int i = 0; i < bill.items.length; i++) {
        final item = bill.items[i];

        // Dòng 1: Tên | x3 | 117,000d (tổng)
        buf.addAll(_row3(
          '${i + 1}. ${item.name}',
          'x${item.quantity}',
          '${_f(item.total)}d',
        ));

        // Dòng 2: định lượng | (trống) | 39,000d (đơn giá)
        final double line2Price = item.basePricePerUnit > 0
            ? item.basePricePerUnit
            : item.unitPrice;

        buf.addAll(_row3(
          item.weightLabel != null ? '   (${item.weightLabel})' : '',
          '',
          '${_f(line2Price)}d',
        ));

        // ── Addons ────────────────────────────────────────────
        for (final addon in item.addons) {
          if (addon.quantity <= 0) continue;

          // Dòng 1 addon: tên | xN | total
          buf.addAll(_row3(
            '   + ${addon.name}',
            'x${addon.quantity}',
            '${_f(addon.total)}d',
          ));

          // Dòng 2 addon: (trống) | (trống) | đơn giá
          buf.addAll(_row3(
            '',
            '',
            '${_f(addon.unitPrice)}d',
          ));
        }
      }
    }
    buf.addAll(_hr());

    // ── Tổng cộng ────────────────────────────────────────────────
    final totalQty = bill.items.fold<int>(0, (s, i) => s + i.quantity);

    // Tạm tính (n món)
    buf.addAll(_rowLR(
      'Tam tinh ($totalQty mon):',
      '${_f(bill.subTotal)}d',
    ));

    // Giảm giá (luôn hiển thị)
    buf.addAll(_rowLR(
      'Giam gia:',
      '-${_f(bill.discountAmount)}d',
    ));

    // ← THÊM: E-Voucher (chỉ hiển thị nếu có)
    if (bill.eVoucherDiscount > 0) {
      final code = bill.eVoucherCode != null
          ? ' (${bill.eVoucherCode})'
          : '';
      buf.addAll(_rowLR(
        'E-Voucher$code:',
        '-${_f(bill.eVoucherDiscount)}d',
      ));
    }

    // VAT tổng (luôn hiển thị)
    buf.addAll(_rowLR(
      'VAT (da bao gom):',
      '${_f(bill.vatAmount)}d',
    ));

    // VAT breakdown từng mức — chỉ hiển thị nếu vatAmount > 0
    // bill.vatAmount > 0 mới có breakdown
    // Cần truyền thêm vatBreakdown vào BillData — xem bên dưới
    if (bill.vatAmount > 0) {
      final sortedVat = bill.vatBreakdown.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final e in sortedVat) {
        buf.addAll(_rowLR(
          '  * ${e.key}%:',
          '${_f(e.value)}d',
        ));
      }
    }

    buf.addAll(_rowLR(
      'Tong tien:',
      '${_f(bill.finalAmount)}d',
      bold: true,
    ));

    buf.addAll(_hr());

    // ── Thanh toán ────────────────────────────────────────────
    buf.addAll(_rowLR(
      '',
      _vn(_pmLabel(bill.paymentMethod)),
      bold: true,
    ));

    // ── Footer ────────────────────────────────────────────────
    buf.addAll(_hr());
    buf.addAll(_line('Cam on quy khach - Hen gap lai!', align: 1));

    buf.addAll([0x1B, 0x64, 6]);
    buf.addAll([0x1D, 0x56, 0]);

    return Uint8List.fromList(buf);
  }

  // ── Print ────────────────────────────────────────────────────
  Future<PrintResult> print(BillData bill) async {
    final ip   = PrinterConfig.savedIp;
    final port = PrinterConfig.savedPort;
    if (ip == null || ip.isEmpty) return PrintResult.notConfigured();
    if (bill.items.isEmpty) {
      return const PrintResult._(
          isSuccess: false, errorMessage: 'Don hang khong co san pham');
    }
    try {
      final bytes  = await buildBill(bill);
      final socket = await Socket.connect(ip, port,
          timeout: Duration(milliseconds: PrinterConfig.timeoutMs));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      PrinterConfig.isConnected = true;
      return PrintResult.ok;
    } on SocketException catch (e) {
      PrinterConfig.isConnected = false;
      return PrintResult.connectionFailed(e.message);
    } catch (e) {
      PrinterConfig.isConnected = false;
      return PrintResult.error(e.toString());
    }
  }

  // ── Print với profile tạm ────────────────────────────────────
  Future<PrintResult> printWithProfile(StoreProfile profile, BillData bill) async {
    final ip   = profile.printerIp;
    final port = PrinterConfig.savedPort;
    if (ip == null || ip.isEmpty) return PrintResult.notConfigured();
    if (bill.items.isEmpty) {
      return const PrintResult._(
          isSuccess: false, errorMessage: 'Don hang khong co san pham');
    }
    try {
      final prev = PrinterConfig.storeProfile;
      PrinterConfig.storeProfile = profile;
      final bytes = await buildBill(bill);
      PrinterConfig.storeProfile = prev;
      final socket = await Socket.connect(ip, port,
          timeout: Duration(milliseconds: PrinterConfig.timeoutMs));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return PrintResult.ok;
    } on SocketException catch (e) {
      return PrintResult.connectionFailed(e.message);
    } catch (e) {
      return PrintResult.error(e.toString());
    }
  }

  // ── Test page ────────────────────────────────────────────────
  Future<PrintResult> printTestPage() async {
    final ip   = PrinterConfig.savedIp;
    final port = PrinterConfig.savedPort;
    if (ip == null || ip.isEmpty) return PrintResult.notConfigured();
    try {
      final buf = <int>[];
      buf.addAll([0x1B, 0x40]);
      buf.addAll([0x1B, 0x74, 0]);
      final now     = DateTime.now();
      final timeStr = DateFormat('HH:mm:ss  dd/MM/yyyy').format(now);
      final name    = _vn(PrinterConfig.storeProfile?.name.isNotEmpty == true
          ? PrinterConfig.storeProfile!.name : 'Original Taste');
      buf.addAll([0x1B, 0x64, 1]);
      buf.addAll(_line(name, bold: true, align: 1));
      buf.addAll(_line(timeStr, align: 1));
      buf.addAll([0x1B, 0x64, 4]);
      buf.addAll([0x1D, 0x56, 0]);
      final socket = await Socket.connect(ip, port,
          timeout: Duration(milliseconds: PrinterConfig.timeoutMs));
      socket.add(buf);
      await socket.flush();
      await socket.close();
      return PrintResult.ok;
    } on SocketException catch (e) {
      return PrintResult.connectionFailed(e.message);
    } catch (e) {
      return PrintResult.error(e.toString());
    }
  }

  // ── Labels ───────────────────────────────────────────────────
  String _pmLabel(String m) => switch (m) {
    'CASH'          => 'TIEN MAT',
    'TRANSFER'      => 'CHUYEN KHOAN',
    'BANK_TRANSFER' => 'CHUYEN KHOAN',
    'MOMO'          => 'MOMO',
    'VNPAY'         => 'VNPAY',
    'ZALOPAY'       => 'ZALOPAY',
    _               => m,
  };

  String _srcLabel(String s) => switch (s) {
    'TAKE_AWAY'   => 'Mang ve',
    'DINE_IN'     => 'Tai quay',
    'SHOPEE_FOOD' => 'Shopee Food',
    'GRAB_FOOD'   => 'Grab Food',
    _             => s,
  };
}

// ═══════════════════════════════════════════════════════════════
// _printOrderBill — dùng trong _ShiftHistoryTabState
// ═══════════════════════════════════════════════════════════════
//
// Copy hàm này vào class _ShiftHistoryTabState trong pos_history_screen.dart
// (thay thế hàm _printOrderBill cũ)

/*
  Future<void> _printOrderBill(PosOrderModel order) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 10),
        Text('Dang ket noi may in...'),
      ]),
      duration: const Duration(seconds: 10),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));

    try {
      final storeInfo = await PosService.instance.getStoreInfo();
      final printerIp = storeInfo['printerIp'] as String?;

      if (!mounted) return;

      if (printerIp == null || printerIp.trim().isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Khong tim thay may in, vui long kiem tra lai.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        return;
      }

      final connected = await PosPrinterService.instance.testConnection(printerIp.trim());
      if (!mounted) return;

      if (!connected) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Khong tim thay may in ($printerIp), vui long kiem tra lai.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        return;
      }

      final tempProfile = StoreProfile(
        name:      storeInfo['name']      as String? ?? '',
        address:   storeInfo['address']   as String? ?? '',
        phone:     storeInfo['phone']     as String? ?? '',
        printerIp: printerIp.trim(),
        shopeeRate: (storeInfo['shopeeRate'] as num?)?.toDouble() ?? 0.0,
        grabRate:   (storeInfo['grabRate']   as num?)?.toDouble() ?? 0.0,
      );

      // Xác định đơn App hay không
      final isAppOrder = order.orderSource == 'SHOPEE_FOOD' ||
          order.orderSource == 'GRAB_FOOD';

      // Với đơn App: bill dùng giá gốc (basePrice), tổng = subTotal - discount
      // Với đơn offline: bill dùng finalUnitPrice như cũ
      final billItems = order.items.map((i) {
        // Parse addons từ selectedIngredients
        final addons = <BillAddon>[];
        for (final variant in i.selectedIngredients) {
          final groupName  = variant['variantGroupName'] as String? ?? '';
          final ingredients = variant['selectedIngredients'] as List<dynamic>? ?? [];
          final isAddonGroup = groupName.toLowerCase().contains('mon them') ||
              groupName.toLowerCase().contains('addon');
          for (final ing in ingredients) {
            final ingMap     = ing as Map<String, dynamic>;
            final addonPrice = (ingMap['addonPrice'] as num?)?.toDouble();
            if (isAddonGroup || (addonPrice != null && addonPrice > 0)) {
              final name  = ingMap['ingredientName'] as String? ?? '';
              final count = ingMap['selectedCount'] as int? ?? 1;
              final price = addonPrice ?? 0.0;
              if (price > 0 && count > 0) {
                addons.add(BillAddon(
                  name:      name,
                  quantity:  count,
                  unitPrice: price,
                ));
              }
            }
          }
        }

        return BillItem(
          name:            i.productName,
          quantity:        i.quantity,
          // App: hiện basePrice cho user; offline: hiện finalUnitPrice
          unitPrice:       isAppOrder ? i.basePrice : i.finalUnitPrice,
          discountPercent: i.discountPercent,
          addons:          addons,
        );
      }).toList();

      // App: tổng user thấy = subTotal - discount (giá gốc, không trừ phí sàn)
      // Offline: finalAmount như cũ
      final billFinalAmount = isAppOrder
          ? (order.totalAmount - order.discountAmount)
          : order.finalAmount;

      final bill = BillData(
        orderCode:      order.orderCode,
        printTime:      DateTime.fromMillisecondsSinceEpoch(order.createdAt),
        cashierName:    order.staffName,
        customerPhone:  order.customerPhone,
        customerName:   order.customerName,
        orderSource:    order.orderSource,
        items:          billItems,
        subTotal:       order.totalAmount,
        discountAmount: order.discountAmount,
        vatAmount:      0,
        finalAmount:    billFinalAmount,
        paymentMethod:  order.paymentMethod,
        // platformFee không in ra bill (chỉ nội bộ)
        platformFee:    0,
        platformRate:   0,
        netRevenue:     0,
      );

      final result = await PosPrinterService.instance.printWithProfile(tempProfile, bill);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.print_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('In bill ${order.orderCode} thanh cong'),
          ]),
          backgroundColor: const Color(0xFF0EA5E9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Loi in: ${result.errorMessage}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Loi: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
*/

// ═══════════════════════════════════════════════════════════════
// PrinterSetupSheet
// ═══════════════════════════════════════════════════════════════

Future<bool> showPrinterSetupSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PrinterSetupSheet(),
  );
  return result == true;
}

class _PrinterSetupSheet extends StatefulWidget {
  const _PrinterSetupSheet();
  @override
  State<_PrinterSetupSheet> createState() => _PrinterSetupSheetState();
}

class _PrinterSetupSheetState extends State<_PrinterSetupSheet> {
  final _ctrl    = TextEditingController();
  bool  _loading = false;
  bool? _testOk;
  String? _error;

  @override
  void initState() { super.initState(); _ctrl.text = PrinterConfig.savedIp ?? ''; }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final ip = _ctrl.text.trim();
    if (ip.isEmpty) { setState(() => _error = 'Vui long nhap IP may in'); return; }
    final parts = ip.split('.');
    if (parts.length != 4 || parts.any((p) => int.tryParse(p) == null)) {
      setState(() => _error = 'IP khong hop le (VD: 192.168.1.100)'); return;
    }
    setState(() { _loading = true; _error = null; _testOk = null; });
    final ok = await PrinterConfig.connectManualIp(ip);
    if (!mounted) return;
    setState(() { _loading = false; _testOk = ok; });
    if (ok) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Khong ket noi duoc voi $ip:9100');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cs        = Theme.of(context).colorScheme;
    final surface   = isDark ? const Color(0xFF1E293B) : Colors.white;
    final txtPri    = isDark ? Colors.white : const Color(0xFF0F172A);
    final txtSec    = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border    = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final bg        = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final connected = PrinterConfig.isConnected;
    final currentIp = PrinterConfig.savedIp;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: txtSec.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.print_outlined, color: cs.primary, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cai dat may in',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: txtPri)),
              Text('Nhap dia chi IP may in ESC/POS (LAN, port 9100)',
                  style: TextStyle(fontSize: 12, color: txtSec)),
            ])),
          ]),
          const SizedBox(height: 20),
          if (currentIp != null && currentIp.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (connected ? Colors.green : Colors.red).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: (connected ? Colors.green : Colors.red).withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(connected
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                    color: connected ? Colors.green : Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  connected
                      ? 'Dang ket noi: $currentIp'
                      : 'Mat ket noi: $currentIp',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: connected ? Colors.green : Colors.red),
                )),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 16, color: txtPri,
                letterSpacing: 1, fontWeight: FontWeight.w600),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Dia chi IP may in',
              hintText: '192.168.1.100',
              hintStyle: TextStyle(color: txtSec.withOpacity(0.4),
                  fontWeight: FontWeight.w400, fontSize: 14, letterSpacing: 0),
              prefixIcon: Icon(Icons.lan_outlined, size: 18,
                  color: _error != null ? Colors.red : txtSec),
              suffixIcon: _testOk == true
                  ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
                  : _testOk == false
                  ? const Icon(Icons.cancel_rounded, color: Colors.red, size: 20)
                  : null,
              errorText: _error, filled: true, fillColor: bg,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _error != null ? Colors.red : border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: _error != null ? Colors.red : cs.primary, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5)),
              labelStyle: TextStyle(fontSize: 13, color: txtSec),
            ),
            onChanged: (_) { if (_error != null) setState(() => _error = null); },
          ),
          const SizedBox(height: 8),
          Text('Port mac dinh: 9100',
              style: TextStyle(fontSize: 11, color: txtSec)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(side: BorderSide(color: border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('Dong', style: TextStyle(color: txtSec)),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.wifi_rounded, size: 18),
              label: Text(_loading ? 'Dang kiem tra...' : 'Ket noi'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            )),
          ]),
        ]),
      ),
    );
  }
}