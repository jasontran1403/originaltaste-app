// lib/features/auth/screens/welcome_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/nav_item.dart';
import '../../../core/enums/user_role.dart';

class WelcomeScreen extends StatefulWidget {
  final UserRole role;
  const WelcomeScreen({super.key, required this.role});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {

  late AnimationController _shimmerCtrl;
  late AnimationController _exitCtrl;
  late Animation<double>   _exitFade;
  late Animation<double>   _exitScale;

  @override
  void initState() {
    super.initState();

    // ── Shimmer: ease-in-out để highlight tăng tốc giữa, giảm ở đầu/cuối
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // ── Exit: fade out + scale up nhẹ
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );

    Future.delayed(AppConstants.welcomeDuration, _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    await _exitCtrl.forward();
    if (mounted) context.go(widget.role.homeRoute);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _exitFade,
        child: ScaleTransition(
          scale: _exitScale,
          child: Center(
            child: _ShimmerText(
              text:       AppConstants.appName,
              controller: _shimmerCtrl,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHIMMER TEXT
// ══════════════════════════════════════════════════════════════

class _ShimmerText extends AnimatedWidget {
  final String text;

  const _ShimmerText({
    required this.text,
    required AnimationController controller,
  }) : super(listenable: controller);

  AnimationController get _ctrl => listenable as AnimationController;

  @override
  Widget build(BuildContext context) {
    // Ease the raw 0→1 progress để shimmer tăng/giảm tốc tự nhiên
    final eased = Curves.easeInOut.transform(_ctrl.value);

    return CustomPaint(
      painter: _ShimmerTextPainter(
        text:     text,
        progress: eased,
      ),
      // Invisible text giữ đúng kích thước cho CustomPaint
      child: Text(
        text,
        style: const TextStyle(
          fontSize:      40,
          fontWeight:    FontWeight.bold,
          letterSpacing: 3,
          color:         Colors.transparent,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PAINTER
// ══════════════════════════════════════════════════════════════

class _ShimmerTextPainter extends CustomPainter {
  final String text;
  final double progress; // 0 → 1, đã eased

  _ShimmerTextPainter({required this.text, required this.progress});

  // Cache TextPainter để không layout lại mỗi frame
  static TextPainter? _baseCache;
  static String?      _baseKey;

  @override
  void paint(Canvas canvas, Size size) {
    final offset = _centered(size);

    // ── 1. Base text (xám tối) ────────────────────────────────
    final base = _buildBase(size);
    base.paint(canvas, offset);

    // ── 2. Shimmer overlay ────────────────────────────────────
    // Highlight di chuyển từ trái (-width) → phải (+2*width)
    // Highlight rộng = 55% chiều rộng text để trông tự nhiên
    final tw         = base.width;
    final hlWidth    = tw * 0.55;
    // shimmerX: tâm highlight, chạy từ -hlWidth → tw + hlWidth
    final shimmerX   = -hlWidth + progress * (tw + hlWidth * 2);

    final shader = LinearGradient(
      begin:  Alignment.centerLeft,
      end:    Alignment.centerRight,
      colors: const [
        Colors.transparent,
        Color(0x66FFFFFF),  // ramp lên nhẹ
        Color(0xFFFFFFFF),  // peak
        Color(0xFFEEEEEE),
        Color(0xFFFFFFFF),
        Color(0x66FFFFFF),  // ramp xuống nhẹ
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.45, 0.5, 0.55, 0.7, 1.0],
    ).createShader(
      // Rect của highlight — tính tuyệt đối trên canvas
      Rect.fromLTWH(
        offset.dx + shimmerX - hlWidth / 2,
        offset.dy,
        hlWidth,
        base.height,
      ),
    );

    final shimmerPaint = Paint()..shader = shader;

    final shimmer = TextPainter(
      text: TextSpan(
        text:  text,
        style: TextStyle(
          fontSize:      40,
          fontWeight:    FontWeight.bold,
          letterSpacing: 3,
          foreground:    shimmerPaint,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    shimmer.paint(canvas, offset);
  }

  TextPainter _buildBase(Size size) {
    if (_baseKey == text && _baseCache != null) return _baseCache!;
    _baseKey   = text;
    _baseCache = TextPainter(
      text: TextSpan(
        text:  text,
        style: const TextStyle(
          fontSize:      40,
          fontWeight:    FontWeight.bold,
          letterSpacing: 3,
          color:         Color(0xFF374151), // xám tối hơn chút
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    return _baseCache!;
  }

  Offset _centered(Size size) {
    final tp = _buildBase(size);
    return Offset(
      (size.width  - tp.width)  / 2,
      (size.height - tp.height) / 2,
    );
  }

  @override
  bool shouldRepaint(_ShimmerTextPainter old) => old.progress != progress;
}