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
  const StoreProfile({
    required this.name, required this.address,
    required this.phone, this.printerIp,
  });
  factory StoreProfile.fromJson(Map<String, dynamic> j) => StoreProfile(
    name:      j['name']      as String? ?? '',
    address:   j['address']   as String? ?? '',
    phone:     j['phone']     as String? ?? '',
    printerIp: j['printerIp'] as String?,
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

// FIX 1: Thêm BillAddon để in addon kèm theo mỗi món
class BillAddon {
  final String name;
  final int    quantity;
  final double unitPrice; // = discountedAddonPrice
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
  final double          unitPrice;
  final int             discountPercent;
  final List<BillAddon> addons; // FIX 1
  double get total => quantity * unitPrice;
  const BillItem({
    required this.name, required this.quantity,
    required this.unitPrice, this.discountPercent = 0,
    this.addons = const [], // FIX 1
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
  const BillData({
    required this.orderCode, required this.printTime,
    required this.cashierName, this.customerPhone, this.customerName,
    required this.orderSource, required this.items,
    required this.subTotal, this.discountAmount = 0,
    this.vatAmount = 0, required this.finalAmount,
    required this.paymentMethod,
  });
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
      PrintResult._(isSuccess: false, errorMessage: 'Không kết nối được máy in: $msg');
  factory PrintResult.error(String msg) =>
      PrintResult._(isSuccess: false, errorMessage: 'Loi in: $msg');
  factory PrintResult.notConfigured() =>
      PrintResult._(isSuccess: false, errorMessage: 'Chưa cấu hình IP máy in');
}

// ═══════════════════════════════════════════════════════════════
// Vietnamese → ASCII (no diacritics)
// Máy Zywell ZY808 chỉ có PC437, không có font VN
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

  // ── ESC/POS raw helpers ──────────────────────────────────────

  static const int _width = 48;

  List<int> _line(String text, {
    bool bold          = false,
    int  align         = 0,   // 0=left 1=center 2=right
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

  List<int> _rowLR(String left, String right, {bool bold = false}) {
    final l   = _vn(left);
    final r   = _vn(right);
    final pad = _width - l.length - r.length;
    final buf = <int>[];
    buf.addAll([0x1B, 0x74, 0]);
    buf.addAll([0x1B, 0x45, bold ? 1 : 0]);
    buf.addAll([0x1D, 0x21, 0x00]);
    buf.addAll([0x1B, 0x61, 0]);
    buf.addAll(l.codeUnits);
    if (pad > 0) buf.addAll(List.filled(pad, 0x20));
    buf.addAll(r.codeUnits);
    buf.add(0x0A);
    buf.addAll([0x1B, 0x45, 0]);
    return buf;
  }

  List<int> _hr({String ch = '-'}) =>
      [...[0x1B, 0x74, 0], ...(ch * _width).codeUnits, 0x0A];

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
      final found = <String>[];
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

    if (storeName.isNotEmpty) {
      // FIX 2: bỏ doubleHeight/doubleWidth cho storeName — ZY808 PC437 không
      // render scaling đúng với ASCII, chỉ giữ bold + center
      buf.addAll(_line(_vn(storeName), bold: true, align: 1));
    }
    if (storeAddress.isNotEmpty) {
      buf.addAll(_line(_vn(storeAddress), align: 1));
    }
    if (storePhone.isNotEmpty) {
      buf.addAll(_line('DT: ${_vn(storePhone)}', align: 1));
    }
    buf.addAll(_hr());

    // ── Tiêu đề ──────────────────────────────────────────────
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

    buf.addAll(_line('Ten hang                  SL    Don gia', bold: true));
    buf.addAll(_hr(ch: '-'));

    // ── Danh sách món ────────────────────────────────────────
    // FIX 3: guard tránh in bill rỗng — chỉ in khi items không rỗng
    if (bill.items.isNotEmpty) {
      for (int i = 0; i < bill.items.length; i++) {
        final item = bill.items[i];
        buf.addAll(_line('${i + 1}. ${_vn(item.name)}'));
        if (item.discountPercent > 0) {
          buf.addAll(_line('   (Giam ${item.discountPercent}%)'));
        }
        final qty   = '${item.quantity}';
        final price = _f(item.unitPrice);
        final total = _f(item.total);
        buf.addAll(_rowLR('   x$qty  $price', '${total}d'));

        // FIX 1: In addon nếu có
        for (final addon in item.addons) {
          if (addon.quantity <= 0) continue;
          buf.addAll(_line('   + ${_vn(addon.name)}'));
          buf.addAll(_rowLR(
            '     x${addon.quantity}  ${_f(addon.unitPrice)}',
            '${_f(addon.total)}d',
          ));
        }
      }
    }
    buf.addAll(_hr());

    // ── Tổng cộng ────────────────────────────────────────────
    final totalQty = bill.items.fold<int>(0, (s, i) => s + i.quantity);
    buf.addAll(_rowLR('Tong cong ($totalQty mon):', '${_f(bill.subTotal)}d', bold: true));
    if (bill.discountAmount > 0) {
      buf.addAll(_rowLR('Giam gia:', '-${_f(bill.discountAmount)}d'));
    }
    if (bill.vatAmount > 0) {
      buf.addAll(_rowLR('VAT:', '${_f(bill.vatAmount)}d'));
    }
    buf.addAll(_hr(ch: '='));

    // ── Thanh toán ────────────────────────────────────────────
    buf.addAll(_line(_vn(_pmLabel(bill.paymentMethod)),
        bold: true, doubleHeight: true));
    // FIX 2: số tiền — bỏ doubleWidth, chỉ bold + align right
    // doubleWidth làm lệch alignment và hiển thị sai trên PC437
    buf.addAll(_line('${_f(bill.finalAmount)}d',
        bold: true, align: 2));

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
    // FIX 3: không in nếu không có món — tránh bill "0 mon" rỗng
    if (bill.items.isEmpty) {
      return const PrintResult._(isSuccess: false, errorMessage: 'Don hang khong co san pham');
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
      return const PrintResult._(isSuccess: false, errorMessage: 'Don hang khong co san pham');
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
    if (ip.isEmpty) { setState(() => _error = 'Vui lòng nhập IP máy in'); return; }
    final parts = ip.split('.');
    if (parts.length != 4 || parts.any((p) => int.tryParse(p) == null)) {
      setState(() => _error = 'IP không hợp lệ (VD: 192.168.1.100)'); return;
    }
    setState(() { _loading = true; _error = null; _testOk = null; });
    final ok = await PrinterConfig.connectManualIp(ip);
    if (!mounted) return;
    setState(() { _loading = false; _testOk = ok; });
    if (ok) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Không kết nối được với $ip:9100');
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
              Text('Cài đặt máy in',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: txtPri)),
              Text('Nhập địa chỉ IP máy in ESC/POS (LAN, port 9100)',
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
                border: Border.all(color: (connected ? Colors.green : Colors.red).withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(connected ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: connected ? Colors.green : Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  connected ? 'Đang kết nối: $currentIp' : 'Mất kết nối: $currentIp',
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
              labelText: 'Địa chỉ IP máy in',
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _error != null ? Colors.red : border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: _error != null ? Colors.red : cs.primary, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5)),
              labelStyle: TextStyle(fontSize: 13, color: txtSec),
            ),
            onChanged: (_) { if (_error != null) setState(() => _error = null); },
          ),
          const SizedBox(height: 8),
          Text('Port mặc định: 9100', style: TextStyle(fontSize: 11, color: txtSec)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(side: BorderSide(color: border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('Đóng', style: TextStyle(color: txtSec)),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.wifi_rounded, size: 18),
              label: Text(_loading ? 'Đang kiểm tra...' : 'Kết nối'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          ]),
        ]),
      ),
    );
  }
}