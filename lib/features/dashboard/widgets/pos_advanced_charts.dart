// lib/features/dashboard/widgets/pos_advanced_charts.dart

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/dashboard/pos_chart_models.dart';
import '../../../features/dashboard/controller/dashboard_controller.dart';

class PosAdvancedCharts extends ConsumerWidget {
  const PosAdvancedCharts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.watch(dashboardControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(children: [
      _CategoryFilterBar(
        categories: ctrl.categories,
        selectedCategories: ctrl.selectedCategories,
        isDark: isDark,
        onToggle: (name) =>
            ref.read(dashboardControllerProvider.notifier).toggleCategory(name),
      ),
      const SizedBox(height: 12),
      _Chart1(
        data: ctrl.shiftData,
        loading: ctrl.advancedChartsLoading,
        isDark: isDark,
      ),
      const SizedBox(height: 12),
      _Chart2(
        data: ctrl.stackedData,
        loading: ctrl.advancedChartsLoading,
        isDark: isDark,
      ),
      const SizedBox(height: 12),
      _HeatmapChart(
        cells: ctrl.heatmap,
        loading: ctrl.advancedChartsLoading,
        isDark: isDark,
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// CATEGORY FILTER BAR
// ══════════════════════════════════════════════════════════════════

class _CategoryFilterBar extends StatelessWidget {
  final List<CategoryItem> categories;
  final Set<String> selectedCategories;
  final bool isDark;
  final void Function(String) onToggle;

  const _CategoryFilterBar({
    required this.categories,
    required this.selectedCategories,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lọc theo Danh mục',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withOpacity(0.7))),
        const SizedBox(height: 10),
        if (categories.isEmpty)
          Text('Chưa có danh mục',
              style:
              TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.4)))
        else
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final isSel = selectedCategories.contains(cat.name);
                return GestureDetector(
                  onTap: () => onToggle(cat.name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? cs.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSel ? cs.primary : cs.primary.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(cat.name,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isSel ? Colors.white : cs.primary)),
                  ),
                );
              }).toList()),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// CHART 1 — Dual Line: Revenue (solid) + OrderCount (dashed)
// ══════════════════════════════════════════════════════════════════

class _Chart1 extends StatefulWidget {
  final List<PeriodShiftPoint> data;
  final bool loading;
  final bool isDark;

  const _Chart1(
      {required this.data, required this.loading, required this.isDark});

  @override
  State<_Chart1> createState() => _Chart1State();
}

class _Chart1State extends State<_Chart1> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int? _selectedIdx;
  int _selShift = 0; // 0=all, 1,2,3

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_Chart1 old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_PeriodAgg> get _aggregated {
    final Map<String, _PeriodAgg> map = {};
    for (final p in widget.data) {
      // Khi selShift=0: gom tất cả (bỏ qua shift=0/"Khác" nếu muốn, hoặc include all)
      if (_selShift != 0 && p.shift != _selShift) continue;
      // Khi selShift=0: skip shift=0 (Khác) để không bị tính trùng
      if (_selShift == 0 && p.shift == 0) continue;

      if (!map.containsKey(p.periodLabel)) {
        map[p.periodLabel] = _PeriodAgg(
          label: p.periodLabel, fromTs: p.periodFromTs, toTs: p.periodToTs,
          revenue: p.revenue, orderCount: p.orderCount,
        );
      } else {
        final prev = map[p.periodLabel]!;
        map[p.periodLabel] = _PeriodAgg(
          label: prev.label, fromTs: prev.fromTs, toTs: prev.toTs,
          revenue: prev.revenue + p.revenue,
          orderCount: prev.orderCount + p.orderCount,
        );
      }
    }
    return map.values.toList()..sort((a, b) => a.fromTs.compareTo(b.fromTs));
  }

  int? _calculateIndexFromPosition({
    required Offset? position,
    required double width,
    required int dataLength,
  }) {
    if (position == null || dataLength <= 1) return null;

    const padL = 65.0;
    const padR = 55.0;
    final w = width - padL - padR;
    final x = position.dx;

    if (x < padL || x > padL + w) return null;

    final idx = ((x - padL) / (w / (dataLength - 1))).round().clamp(0, dataLength - 1);
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fmt = NumberFormat('#,###', 'vi_VN');
    final agg = _aggregated;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Doanh thu & Đơn hàng',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 4),
            Row(children: [
              _LegendDot(color: const Color(0xFF2563EB), label: 'Doanh thu'),
              const SizedBox(width: 12),
              _LegendDot(
                  color: const Color(0xFF0891B2),
                  label: 'Số đơn (--)',
                  dashed: true),
            ]),
          ]),
          const Spacer(),
          _ShiftFilter(
            selected: _selShift,
            onSelect: (s) => setState(() {
              _selShift = s;
              _selectedIdx = null;
              _ctrl.forward(from: 0);
            }),
            isDark: widget.isDark,
          ),
        ]),
        const SizedBox(height: 12),
        if (widget.loading)
          const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (agg.isEmpty)
          const SizedBox(
              height: 200, child: Center(child: Text('Không có dữ liệu')))
        else
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => LayoutBuilder(
              builder: (ctx, cst) {
                return GestureDetector(
                  onTapDown: (details) {
                    final idx = _calculateIndexFromPosition(
                      position: details.localPosition,
                      width: cst.maxWidth,
                      dataLength: agg.length,
                    );
                    setState(() {
                      if (_selectedIdx == idx) {
                        _selectedIdx = null;
                      } else {
                        _selectedIdx = idx;
                      }
                    });
                  },
                  onTap: () {
                    if (_selectedIdx != null) {
                      final idx = _calculateIndexFromPosition(
                        position: null,
                        width: cst.maxWidth,
                        dataLength: agg.length,
                      );
                      if (idx == null) {
                        setState(() => _selectedIdx = null);
                      }
                    }
                  },
                  child: Stack(children: [
                    CustomPaint(
                      size: Size(cst.maxWidth, 280),
                      painter: _DualLinePainter(
                        periods: agg,
                        progress: _anim.value,
                        isDark: widget.isDark,
                        selectedIdx: _selectedIdx,
                      ),
                    ),
                    if (_selectedIdx != null && _selectedIdx! < agg.length)
                      _buildTooltip(fmt, agg[_selectedIdx!], cst.maxWidth, agg.length),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildTooltip(NumberFormat fmt, _PeriodAgg p, double maxWidth, int dataLength) {
    final cs = Theme.of(context).colorScheme;

    const padL = 65.0;
    const padR = 55.0;
    final w = maxWidth - padL - padR;
    final x = padL + (_selectedIdx! / (dataLength - 1)) * w;
    final left = (x + 14).clamp(0.0, maxWidth - 230.0);

    return Positioned(
      left: left,
      top: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10)
          ],
          border: Border.all(
              color: widget.isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF2563EB), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Doanh thu: ${fmt.format(p.revenue)}đ',
                    style: TextStyle(fontSize: 11, color: cs.onSurface)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF0891B2), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Số đơn: ${p.orderCount.toInt()}',
                    style: TextStyle(fontSize: 11, color: cs.onSurface)),
              ]),
            ]),
      ),
    );
  }
}

class _PeriodAgg {
  final String label;
  final int fromTs, toTs;
  final double revenue, orderCount;
  const _PeriodAgg(
      {required this.label,
        required this.fromTs,
        required this.toTs,
        required this.revenue,
        required this.orderCount});
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendDot(
      {required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.6))),
    ]);
  }
}

class _ShiftFilter extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  final bool isDark;
  const _ShiftFilter(
      {required this.selected, required this.onSelect, required this.isDark});

  static const _opts = [
    (0, 'Tất cả', Color(0xFF6366F1)),
    (1, 'Ca 1', Color(0xFF2563EB)),
    (2, 'Ca 2', Color(0xFF7C3AED)),
    (3, 'Ca 3', Color(0xFFEA580C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisSize: MainAxisSize.min,
        children: _opts.map((o) {
          final isSel = selected == o.$1;
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () => onSelect(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSel ? o.$3 : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: o.$3, width: 1.5),
                ),
                child: Text(o.$2,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSel ? Colors.white : o.$3)),
              ),
            ),
          );
        }).toList());
  }
}

class _DualLinePainter extends CustomPainter {
  final List<_PeriodAgg> periods;
  final double progress;
  final bool isDark;
  final int? selectedIdx;

  static const _colRev = Color(0xFF2563EB);
  static const _colOrd = Color(0xFF0891B2);

  _DualLinePainter({
    required this.periods,
    required this.progress,
    required this.isDark,
    this.selectedIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (periods.isEmpty) return;
    const padL = 65.0, padR = 55.0, padT = 20.0, padB = 40.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    final n = periods.length;

    double maxRev = periods.map((p) => p.revenue).fold(0.0, (a, b) => a > b ? a : b);
    double maxOrd = periods.map((p) => p.orderCount).fold(0.0, (a, b) => a > b ? a : b);
    if (maxRev == 0) maxRev = 1;
    if (maxOrd == 0) maxOrd = 1;

    final fmtS = TextStyle(
        fontSize: 9,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.5));
    final gridP = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1;
    final fmtC = NumberFormat.compactCurrency(locale: 'vi', symbol: '');

    for (int i = 0; i <= 4; i++) {
      final y = padT + h - (i / 4) * h;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridP);
      _dt(canvas, fmtC.format(maxRev * i / 4), Offset(0, y - 6), fmtS,
          TextAlign.right, 60);
      _dt(canvas, (maxOrd * i / 4).toInt().toString(),
          Offset(padL + w + 4, y - 6), fmtS, TextAlign.left, 50);
    }

    final step = (n / 12).ceil().clamp(1, 999);
    for (int i = 0; i < n; i += step) {
      final x = padL + (n == 1 ? w / 2 : i / (n - 1) * w);
      _dt(canvas, periods[i].label, Offset(x - 22, size.height - padB + 6),
          fmtS, TextAlign.center, 50);
    }

    _drawLineSeries(
        canvas, n, padL, padT, w, h, maxRev, (p) => p.revenue, _colRev, false);
    _drawLineSeries(canvas, n, padL, padT, w, h, maxOrd, (p) => p.orderCount,
        _colOrd, true);

    if (selectedIdx != null && selectedIdx! < n) {
      final x = padL + (n == 1 ? w / 2 : selectedIdx! / (n - 1) * w);
      canvas.drawLine(
          Offset(x, padT),
          Offset(x, padT + h),
          Paint()
            ..color = Colors.grey.withOpacity(0.3)
            ..strokeWidth = 1);
      _hoverDot(
          canvas, x, padT + h - periods[selectedIdx!].revenue / maxRev * h, _colRev);
      _hoverDot(
          canvas, x, padT + h - periods[selectedIdx!].orderCount / maxOrd * h, _colOrd);
    }
  }

  void _drawLineSeries(
      Canvas canvas,
      int n,
      double padL,
      double padT,
      double w,
      double h,
      double maxVal,
      double Function(_PeriodAgg) val,
      Color color,
      bool dashed) {
    final pts = List.generate(
        n,
            (i) => Offset(padL + (n == 1 ? w / 2 : i / (n - 1) * w),
            padT + h - val(periods[i]) / maxVal * h));

    final totalPts = (pts.length * progress).ceil().clamp(1, pts.length);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      final path = Path();
      path.moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < totalPts; i++) path.lineTo(pts[i].dx, pts[i].dy);
      canvas.drawPath(path, paint);
    } else {
      for (int i = 0; i < totalPts - 1; i++) {
        final p1 = pts[i], p2 = pts[i + 1];
        final dist = (p2 - p1).distance;
        final segs = (dist / 10).floor().clamp(1, 999);
        for (int j = 0; j < segs; j++) {
          if (j % 2 == 0) {
            canvas.drawLine(
              Offset.lerp(p1, p2, j / segs)!,
              Offset.lerp(p1, p2, (j + 0.6) / segs)!,
              paint,
            );
          }
        }
      }
    }

    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < totalPts; i++) {
      canvas.drawCircle(pts[i], 3.5, dot);
    }
  }

  void _hoverDot(Canvas canvas, double x, double y, Color c) {
    canvas.drawCircle(
        Offset(x, y),
        6,
        Paint()
          ..color = c
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(x, y),
        9,
        Paint()
          ..color = c.withOpacity(0.2)
          ..style = PaintingStyle.fill);
  }

  void _dt(Canvas canvas, String text, Offset off, TextStyle s, TextAlign a,
      double mw) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: ui.TextDirection.ltr,
        textAlign: a)
      ..layout(maxWidth: mw);
    tp.paint(canvas, off);
  }

  @override
  bool shouldRepaint(_DualLinePainter old) =>
      old.progress != progress ||
          old.selectedIdx != selectedIdx ||
          old.periods != periods;
}

// ══════════════════════════════════════════════════════════════════
// CHART 2 — Stacked Area % + click to show tooltip
// ══════════════════════════════════════════════════════════════════

class _Chart2 extends StatefulWidget {
  final List<PeriodStackedPoint> data;
  final bool loading;
  final bool isDark;

  const _Chart2(
      {required this.data, required this.loading, required this.isDark});

  @override
  State<_Chart2> createState() => _Chart2State();
}

class _Chart2State extends State<_Chart2> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int? _selectedIdx;
  String _metric = 'revenue';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_Chart2 old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _shiftColors = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFEA580C),
    Color(0xFF6366F1),
  ];
  static const _catColors = [
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0D9488),
    Color(0xFFDB2777),
    Color(0xFF65A30D),
  ];

  int? _calculateIndexFromPosition({
    required Offset? position,
    required double width,
    required int dataLength,
  }) {
    if (position == null || dataLength <= 1) return null;

    const padL = 55.0;
    const padR = 20.0;
    final w = width - padL - padR;
    final x = position.dx;

    if (x < padL || x > padL + w) return null;

    final idx = ((x - padL) / (w / (dataLength - 1))).round().clamp(0, dataLength - 1);
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fmt = NumberFormat('#,###', 'vi_VN');

    final tmpFromTs = <String, int>{};
    for (final p in widget.data) {
      tmpFromTs.putIfAbsent(p.periodLabel, () => p.periodFromTs);
    }
    final sortedPeriods = tmpFromTs.keys.toList()
      ..sort((a, b) => (tmpFromTs[a] ?? 0).compareTo(tmpFromTs[b] ?? 0));

    final groups = widget.data.map((p) => p.groupKey).toSet().toList()..sort();
    final Map<String, Map<String, double>> byPeriod = {};
    for (final p in widget.data) {
      byPeriod.putIfAbsent(
          p.periodLabel, () => <String, double>{})[p.groupKey] =
      _metric == 'revenue' ? p.revenue : p.orderCount;
    }

    const isShift = true;

    const colors = _shiftColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Phân bổ theo Ca',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          const Spacer(),
          // _MetricDropdown(
          //   value: _metric,
          //   onChange: (m) => setState(() {
          //     _metric = m;
          //     _selectedIdx = null;
          //     _ctrl.forward(from: 0);
          //   }),
          //   isDark: widget.isDark,
          // ),
          _MetricToggle(
            value: _metric,
            onChange: (m) => setState(() {
              _metric = m;
              _selectedIdx = null;
              _ctrl.forward(from: 0);
            }),
            isDark: widget.isDark,
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(
            spacing: 10,
            runSpacing: 4,
            children: groups.asMap().entries.map((e) {
              final color = colors[e.key % colors.length];
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text(e.value,
                    style: TextStyle(
                        fontSize: 10, color: cs.onSurface.withOpacity(0.7))),
              ]);
            }).toList()),
        const SizedBox(height: 10),
        if (widget.loading)
          const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => LayoutBuilder(
              builder: (ctx, cst) {
                return GestureDetector(
                  onTapDown: (details) {
                    final idx = _calculateIndexFromPosition(
                      position: details.localPosition,
                      width: cst.maxWidth,
                      dataLength: sortedPeriods.length,
                    );
                    setState(() {
                      if (_selectedIdx == idx) {
                        _selectedIdx = null;
                      } else {
                        _selectedIdx = idx;
                      }
                    });
                  },
                  onTap: () {
                    if (_selectedIdx != null) {
                      final idx = _calculateIndexFromPosition(
                        position: null,
                        width: cst.maxWidth,
                        dataLength: sortedPeriods.length,
                      );
                      if (idx == null) {
                        setState(() => _selectedIdx = null);
                      }
                    }
                  },
                  child: Stack(children: [
                    CustomPaint(
                      size: Size(cst.maxWidth, 260),
                      painter: _StackedAreaPainter(
                        byPeriod: byPeriod,
                        periods: sortedPeriods,
                        groups: groups,
                        colors: colors,
                        progress: _anim.value,
                        isDark: widget.isDark,
                        selectedIdx: _selectedIdx,
                      ),
                    ),
                    if (_selectedIdx != null && _selectedIdx! < sortedPeriods.length)
                      _buildTooltip(
                        fmt,
                        sortedPeriods[_selectedIdx!],
                        byPeriod[sortedPeriods[_selectedIdx!]] ?? {},
                        colors,
                        groups,
                        cst.maxWidth,
                        sortedPeriods,
                      ),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildTooltip(
      NumberFormat fmt,
      String period,
      Map<String, double> data,
      List<Color> colors,
      List<String> groups,
      double maxWidth,
      List<String> sortedPeriods,
      ) {
    final cs = Theme.of(context).colorScheme;
    final total = data.values.fold(0.0, (a, b) => a + b);

    const padL = 55.0;
    const padR = 20.0;
    final w = maxWidth - padL - padR;
    final x = padL + (_selectedIdx! / (sortedPeriods.length - 1)) * w;
    final left = (x + 14).clamp(0.0, maxWidth - 230.0);

    return Positioned(
      left: left,
      top: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10)
          ],
          border: Border.all(
              color: widget.isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(period,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
              const SizedBox(height: 6),
              ...groups.asMap().entries.map((e) {
                final color = colors[e.key % colors.length];
                final val = data[e.value] ?? 0;
                final pct = total > 0 ? val / total * 100 : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                        '${e.value}: ${fmt.format(val)}đ (${pct.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 10, color: cs.onSurface)),
                  ]),
                );
              }),
            ]),
      ),
    );
  }
}

class _MetricDropdown extends StatelessWidget {
  final String value;
  final void Function(String) onChange;
  final bool isDark;
  const _MetricDropdown(
      {required this.value, required this.onChange, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary.withOpacity(0.3)),
      ),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        underline: const SizedBox.shrink(),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
        items: const [
          DropdownMenuItem(value: 'revenue', child: Text('Doanh thu')),
          DropdownMenuItem(value: 'orderCount', child: Text('Số đơn')),
        ],
        onChanged: (v) {
          if (v != null) onChange(v);
        },
      ),
    );
  }
}

class _MetricToggle extends StatelessWidget {
  final String value;           // 'revenue' hoặc 'orderCount'
  final void Function(String) onChange;
  final bool isDark;

  const _MetricToggle({
    required this.value,
    required this.onChange,
    required this.isDark,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(
          label: 'Doanh thu',
          metric: 'revenue',
          isSelected: value == 'revenue',
          color: const Color(0xFF2563EB),
        ),
        const SizedBox(width: 6),
        _buildButton(
          label: 'Số đơn',
          metric: 'orderCount',
          isSelected: value == 'orderCount',
          color: const Color(0xFF0891B2),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required String metric,
    required bool isSelected,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => onChange(metric),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _StackedAreaPainter extends CustomPainter {
  final Map<String, Map<String, double>> byPeriod;
  final List<String> periods;
  final List<String> groups;
  final List<Color> colors;
  final double progress;
  final bool isDark;
  final int? selectedIdx;

  _StackedAreaPainter({
    required this.byPeriod,
    required this.periods,
    required this.groups,
    required this.colors,
    required this.progress,
    required this.isDark,
    this.selectedIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (periods.isEmpty || groups.isEmpty) return;
    const padL = 55.0, padR = 20.0, padT = 20.0, padB = 40.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    final n = periods.length;

    final txtS = TextStyle(
        fontSize: 9,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.5));
    final gridP = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = padT + h - (i / 4) * h;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridP);
      _dt(canvas, '${i * 25}%', Offset(0, y - 6), txtS, 50);
    }

    final step = (n / 12).ceil().clamp(1, 999);
    for (int i = 0; i < n; i += step) {
      final x = padL + (n == 1 ? w / 2 : i / (n - 1) * w);
      _dt(canvas, periods[i], Offset(x - 22, size.height - padB + 6), txtS, 50);
    }

    final totals = <String, double>{};
    for (final p in periods) {
      double s = 0;
      for (final g in groups) s += byPeriod[p]?[g] ?? 0;
      totals[p] = s > 0 ? s : 1;
    }

    for (int gi = groups.length - 1; gi >= 0; gi--) {
      final color = colors[gi % colors.length];
      final path = Path();
      final tops = <Offset>[];
      final bots = <Offset>[];

      for (int mi = 0; mi < n; mi++) {
        final x = padL + (n == 1 ? w / 2 : mi / (n - 1) * w);
        final total = totals[periods[mi]] ?? 1;
        double ct = 0, cb = 0;
        for (int g2 = 0; g2 <= gi; g2++)
          ct += (byPeriod[periods[mi]]?[groups[g2]] ?? 0) / total;
        for (int g2 = 0; g2 < gi; g2++)
          cb += (byPeriod[periods[mi]]?[groups[g2]] ?? 0) / total;
        tops.add(Offset(x, padT + h - ct * h * progress));
        bots.add(Offset(x, padT + h - cb * h * progress));
      }

      if (tops.isEmpty) continue;
      path.moveTo(bots.first.dx, bots.first.dy);
      for (final pt in tops) path.lineTo(pt.dx, pt.dy);
      for (final pt in bots.reversed) path.lineTo(pt.dx, pt.dy);
      path.close();

      canvas.drawPath(
          path,
          Paint()
            ..color = color.withOpacity(0.65)
            ..style = PaintingStyle.fill);
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);

      final dotP = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      for (int mi = 0; mi < n; mi++) {
        canvas.drawCircle(tops[mi], 3, dotP);
      }
    }

    if (selectedIdx != null && selectedIdx! < n) {
      final x = padL + (n == 1 ? w / 2 : selectedIdx! / (n - 1) * w);
      canvas.drawLine(
          Offset(x, padT),
          Offset(x, padT + h),
          Paint()
            ..color = Colors.grey.withOpacity(0.3)
            ..strokeWidth = 1);
    }
  }

  void _dt(Canvas canvas, String text, Offset off, TextStyle s, double mw) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: ui.TextDirection.ltr)
      ..layout(maxWidth: mw);
    tp.paint(canvas, off);
  }

  @override
  bool shouldRepaint(_StackedAreaPainter old) =>
      old.progress != progress ||
          old.selectedIdx != selectedIdx ||
          old.byPeriod != byPeriod;
}

// ══════════════════════════════════════════════════════════════════
// HEATMAP
// ══════════════════════════════════════════════════════════════════

class _HeatmapChart extends StatefulWidget {
  final List<HeatmapCell> cells;
  final bool loading;
  final bool isDark;

  const _HeatmapChart(
      {required this.cells, required this.loading, required this.isDark});

  @override
  State<_HeatmapChart> createState() => _HeatmapChartState();
}

class _HeatmapChartState extends State<_HeatmapChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  HeatmapCell? _hovered;

  static const _hours = [8, 10, 12, 14, 16, 18, 20];
  static const _hourLabels = [
    '8h-10h',
    '10h-12h',
    '12h-14h',
    '14h-16h',
    '16h-18h',
    '18h-20h',
    '20h-22h',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_HeatmapChart old) {
    super.didUpdateWidget(old);
    if (old.cells != widget.cells) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Map<String, HeatmapCell> get _cellMap {
    final m = <String, HeatmapCell>{};
    for (final c in widget.cells) m['${c.date}_${c.hour}'] = c;
    return m;
  }

  List<DateTime> get _days {
    final today = DateTime.now();
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  int get _maxCount {
    if (widget.cells.isEmpty) return 1;
    return widget.cells
        .map((c) => c.orderCount)
        .reduce((a, b) => a > b ? a : b);
  }

  Color _cellColor(int count) {
    if (count == 0) {
      return (widget.isDark ? Colors.white : Colors.black).withOpacity(0.04);
    }
    return Color.lerp(
        const Color(0xFFBFDBFE), const Color(0xFF1D4ED8), count / _maxCount)!;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border =
    widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fmt = NumberFormat('#,###', 'vi_VN');
    final days = _days;
    final cellMap = _cellMap;
    final dayFmt = DateFormat('EEE dd/MM', 'vi');
    final dateFmt = DateFormat('dd/MM/yyyy', 'vi');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Heatmap đơn hàng — 7 ngày gần nhất',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: cs.onSurface)),
        const SizedBox(height: 12),
        if (widget.loading)
          const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => LayoutBuilder(
              builder: (ctx, cst) {
                const rowLabelW = 80.0;
                final cellW = (cst.maxWidth - rowLabelW) / _hours.length;
                const cellH = 40.0;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      _hovered = null;
                    });
                  },
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: rowLabelW),
                              ..._hourLabels.map((l) => SizedBox(
                                width: cellW,
                                child: Text(
                                  l,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: cs.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              )),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...days.asMap().entries.map((dayEntry) {
                            final day = dayEntry.value;
                            final dateKey =
                            DateFormat('yyyy-MM-dd').format(day);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: rowLabelW,
                                    child: Text(
                                      dayFmt.format(day),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface.withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                  ..._hours.asMap().entries.map((hEntry) {
                                    final hour = hEntry.value;
                                    final cell = cellMap['${dateKey}_$hour'];
                                    final count = cell?.orderCount ?? 0;
                                    final color = _cellColor(count);

                                    final waveX = hEntry.key / _hours.length;
                                    final waveY = dayEntry.key / 7;
                                    final delay = (waveX * 0.7 + waveY * 0.3);

                                    final lp = Curves.easeOut.transform(
                                      ((_anim.value - delay * 0.8) / 0.6)
                                          .clamp(0.0, 1.0),
                                    );

                                    return MouseRegion(
                                      onEnter: (_) {
                                        if (cell != null && count > 0) {
                                          setState(() => _hovered = cell);
                                        }
                                      },
                                      onExit: (_) {
                                        if (_hovered == cell) {
                                          setState(() => _hovered = null);
                                        }
                                      },
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTapDown: (_) {
                                          if (cell != null && count > 0) {
                                            setState(() {
                                              if (_hovered == cell) {
                                                _hovered = null;
                                              } else {
                                                _hovered = cell;
                                              }
                                            });
                                          }
                                        },
                                        child: AnimatedScale(
                                          scale: (_hovered == cell && count > 0)
                                              ? 1.12
                                              : 1.0,
                                          duration:
                                          const Duration(milliseconds: 120),
                                          child: Container(
                                            width: cellW - 3,
                                            height: cellH,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1.5),
                                            decoration: BoxDecoration(
                                              color: Color.lerp(
                                                (widget.isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                    .withOpacity(0.04),
                                                color,
                                                lp,
                                              ),
                                              borderRadius:
                                              BorderRadius.circular(4),
                                            ),
                                            child: Center(
                                              child: Text(
                                                count > 0 ? '$count' : '',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                  count > (_maxCount * 0.5)
                                                      ? Colors.white
                                                      : cs.onSurface
                                                      .withOpacity(0.7),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      if (_hovered != null)
                        Positioned(
                          top: 40,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                )
                              ],
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dateFmt
                                      .format(DateTime.parse(_hovered!.date)),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _hovered!.hourLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.receipt_outlined,
                                        size: 13,
                                        color: cs.onSurface.withOpacity(0.6)),
                                    const SizedBox(width: 5),
                                    Text('${_hovered!.orderCount} đơn'),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.attach_money_rounded,
                                        size: 13,
                                        color: cs.onSurface.withOpacity(0.6)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${fmt.format(_hovered!.totalRevenue)}đ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}