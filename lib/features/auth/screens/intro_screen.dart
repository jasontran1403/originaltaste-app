// lib/features/auth/screens/intro_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_constants.dart';
import '../controller/auth_controller.dart';

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  late AnimationController _swipeCtrl;
  late Animation<Offset> _swipeAnim;

  @override
  void initState() {
    super.initState();

    _swipeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _swipeAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1, 0),
    ).animate(CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeInCubic));

    _checkSession();
    _initVideo();
  }

  Future<void> _checkSession() async {
    final ok = await ref.read(authControllerProvider.notifier).restoreSession();
    if (ok && mounted) {
      // Đã login → skip intro → welcome
      final role = ref.read(authControllerProvider).role;
      context.go('/welcome', extra: role);
    }
  }

  Future<void> _initVideo() async {
    try {
      _videoCtrl = VideoPlayerController.asset(AppConstants.introVideoPath);
      await _videoCtrl!.initialize();
      _videoCtrl!.setLooping(false);
      _videoCtrl!.setVolume(0);

      if (mounted) {
        setState(() => _videoReady = true);
        await _videoCtrl!.play();
      }

      // Khi video kết thúc → swipe sang login
      _videoCtrl!.addListener(_onVideoEnd);
    } catch (_) {
      // Không có video → đi thẳng login sau 2s
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _navigateToLogin();
    }
  }

  void _onVideoEnd() {
    if (_videoCtrl == null) return;
    final pos = _videoCtrl!.value.position;
    final dur = _videoCtrl!.value.duration;
    if (dur.inMilliseconds > 0 &&
        pos.inMilliseconds >= dur.inMilliseconds - 200) {
      _videoCtrl!.removeListener(_onVideoEnd);
      _navigateToLogin();
    }
  }

  Future<void> _navigateToLogin() async {
    if (!mounted) return;
    await _swipeCtrl.forward();
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _videoCtrl?.removeListener(_onVideoEnd);
    _videoCtrl?.dispose();
    _swipeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SlideTransition(
        position: _swipeAnim,
        child: SizedBox.expand(
          child: _videoReady && _videoCtrl != null
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoCtrl!.value.size.width,
                    height: _videoCtrl!.value.size.height,
                    child: VideoPlayer(_videoCtrl!),
                  ),
                )
              : _buildFallback(),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          AppConstants.appName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
