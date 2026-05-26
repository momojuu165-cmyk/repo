import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _barCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _particleCtrl;

  // ── Logo animations ──────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoRotate;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringFade;

  // ── Text animations ───────────────────────────────────────────────────────────
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _taglineFade;

  // ── Bar / shimmer ────────────────────────────────────────────────────────────
  late final Animation<double> _barWidth;
  late final Animation<double> _shimmer;

  bool _done = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF5C1400),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // ── Logo controller (1.4s) ────────────────────────────────────────────────
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));

    _logoScale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.15)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 70),
      TweenSequenceItem(
          tween: Tween(begin: 1.15, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 30),
    ]).animate(_logoCtrl);

    _logoFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.5)));

    _logoRotate = Tween(begin: -0.15, end: 0.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));

    _ringScale = Tween(begin: 0.6, end: 1.8)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));

    _ringFade = Tween(begin: 0.6, end: 0.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));

    // ── Text controller (1.2s, starts after 0.5s) ────────────────────────────
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _titleFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));

    _subtitleFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOut)));

    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _textCtrl,
                curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic)));

    _taglineFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut)));

    // ── Loading bar (1.8s, delayed) ───────────────────────────────────────────
    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _barWidth = CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut);

    // ── Shimmer ───────────────────────────────────────────────────────────────
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _shimmer = Tween(begin: -1.5, end: 2.5).animate(_shimmerCtrl);

    // ── Particles ────────────────────────────────────────────────────────────
    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Logo bounces in
    await Future.delayed(const Duration(milliseconds: 200));
    _logoCtrl.forward();

    // Text slides up
    await Future.delayed(const Duration(milliseconds: 700));
    _textCtrl.forward();

    // Bar fills
    await Future.delayed(const Duration(milliseconds: 400));
    _barCtrl.forward();

    // Wait for bar to finish + small pause
    await Future.delayed(const Duration(milliseconds: 2400));

    if (mounted && !_done) {
      _done = true;
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _barCtrl.dispose();
    _shimmerCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const primary = Color(AppColors.primaryInt); // dark navy
    const accent = Color(AppColors.accentInt); // gold

    return Scaffold(
      body: Stack(
        children: [
          // ── Image-backed hero background ───────────────────────────────────
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/icon/splash.jpeg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.38),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFBF360C),
                  Color(0xFFD84315),
                  Color(0xFF8D1F00),
                  Color(0xFF5C1400),
                ],
                stops: [0.0, 0.28, 0.6, 1.0],
              ),
            ),
          ),

          // ── Decorative circle top-right ─────────────────────────────────────
          Positioned(
            top: -size.width * 0.25,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.75,
              height: size.width * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.12),
                    accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Decorative circle bottom-left ───────────────────────────────────
          Positioned(
            bottom: -size.width * 0.3,
            left: -size.width * 0.2,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primary.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Floating particles ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _ParticlePainter(
                progress: _particleCtrl.value,
                accent: accent,
              ),
            ),
          ),

          // ── Main content ────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top spacer
                SizedBox(height: size.height * 0.12),

                // ── Logo section ──────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      // Expanding ring
                      Transform.scale(
                        scale: _ringScale.value,
                        child: Opacity(
                          opacity: _ringFade.value.clamp(0.0, 1.0),
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: accent, width: 2.5),
                            ),
                          ),
                        ),
                      ),
                      // Logo container
                      FadeTransition(
                        opacity: _logoFade,
                        child: Transform.rotate(
                          angle: _logoRotate.value,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: _LogoWidget(accent: accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: size.height * 0.06),

                // ── App name ──────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _textCtrl,
                  builder: (_, __) => Column(
                    children: [
                      FadeTransition(
                        opacity: _titleFade,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                accent,
                                Colors.white,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ).createShader(bounds),
                            child: const Text(
                              AppConstants.appName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Subtitle
                      FadeTransition(
                        opacity: _subtitleFade,
                        child: SlideTransition(
                          position: _subtitleSlide,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 28,
                                height: 1.5,
                                color: accent.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppConstants.appSubtitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 28,
                                height: 1.5,
                                color: accent.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Tagline badges
                      FadeTransition(
                        opacity: _taglineFade,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: const [
                            _Badge(
                                icon: Icons.inventory_2_outlined,
                                label: 'إدارة المخزون'),
                            _Badge(icon: Icons.payment, label: 'نظام تقسيط'),
                            _Badge(
                                icon: Icons.electrical_services,
                                label: 'أدوات كهربائية'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Loading bar ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([_barCtrl, _shimmerCtrl]),
                        builder: (_, __) => Column(
                          children: [
                            // Bar track
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Stack(
                                children: [
                                  // Fill
                                  FractionallySizedBox(
                                    widthFactor: _barWidth.value,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: LinearGradient(
                                          colors: [
                                            accent.withValues(alpha: 0.6),
                                            accent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Shimmer
                                  if (_barWidth.value > 0.05)
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: FractionallySizedBox(
                                          widthFactor: _barWidth.value,
                                          child: ShaderMask(
                                            shaderCallback: (bounds) =>
                                                LinearGradient(
                                              begin: Alignment(
                                                  _shimmer.value - 0.5, 0),
                                              end: Alignment(
                                                  _shimmer.value + 0.5, 0),
                                              colors: [
                                                Colors.transparent,
                                                Colors.white.withValues(alpha: 0.55),
                                                Colors.transparent,
                                              ],
                                            ).createShader(bounds),
                                            blendMode: BlendMode.srcATop,
                                            child:
                                                Container(color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _barWidth.value < 0.4
                                  ? 'جاري التحميل...'
                                  : _barWidth.value < 0.8
                                      ? 'تحضير البيانات...'
                                      : 'مرحباً بك!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Version label
                      Text(
                        'الإصدار 3.0.0',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Logo widget ─────────────────────────────────

class _LogoWidget extends StatelessWidget {
  final Color accent;
  const _LogoWidget({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.9),
            const Color(0xFFD4850A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.5),
            blurRadius: 32,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 60,
            spreadRadius: 12,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner glow circle
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Icon
          const Icon(
            Icons.store_mall_directory_rounded,
            size: 56,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Badge widget ────────────────────────────────

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    const accent = Color(AppColors.accentInt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent.withValues(alpha: 0.85)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Particle painter ────────────────────────────

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color accent;

  _ParticlePainter({required this.progress, required this.accent});

  static final _rng = math.Random(42);
  static final _particles = List.generate(22, (i) {
    return {
      'x': _rng.nextDouble(),
      'y': _rng.nextDouble(),
      'r': 1.0 + _rng.nextDouble() * 2.5,
      'speed': 0.2 + _rng.nextDouble() * 0.5,
      'phase': _rng.nextDouble(),
    };
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final double phase =
          ((p['phase'] as double) + progress * (p['speed'] as double)) % 1.0;
      final double y = ((p['y'] as double) - phase * 0.4 + 1.0) % 1.0;
      final opacity = (math.sin(phase * math.pi)).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = accent.withValues(alpha: opacity * 0.35)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset((p['x'] as double) * size.width, y * size.height),
        p['r'] as double,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
