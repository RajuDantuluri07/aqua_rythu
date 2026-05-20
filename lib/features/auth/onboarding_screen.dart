import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/analytics_service.dart';

const _kOnboardingKey = 'has_seen_onboarding';

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingKey, true);
}

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingKey) ?? false;
}

// ─── Slide data ───────────────────────────────────────────────────────────────

class _Slide {
  final String eyebrow;
  final String headline;
  final String sub;
  final Color accent;
  final Color tintDark;
  final Widget Function(bool animating) illustration;

  const _Slide({
    required this.eyebrow,
    required this.headline,
    required this.sub,
    required this.accent,
    required this.tintDark,
    required this.illustration,
  });
}

final _slides = <_Slide>[
  _Slide(
    eyebrow: 'THE PROBLEM',
    headline: 'Feed Costs\nIncreasing?',
    sub: 'Track feeding, shrimp growth and pond activity — daily, in one app.',
    accent: const Color(0xFFE94B4B),
    tintDark: const Color(0xFF3a1418),
    illustration: (a) => _PainIllo(animating: a),
  ),
  _Slide(
    eyebrow: 'THE SOLUTION',
    headline: 'Smarter Feeding\nDecisions.',
    sub: 'Feed guidance from DOC, tray checks and shrimp growth trends.',
    accent: const Color(0xFF2EBD7A),
    tintDark: const Color(0xFF0a3327),
    illustration: (a) => _SmartFeedIllo(animating: a),
  ),
  _Slide(
    eyebrow: 'THE OUTCOME',
    headline: 'Manage Your\nFarm Better.',
    sub: 'Monitor feed cost, survival, growth and profits from your phone.',
    accent: const Color(0xFF3DB5E6),
    tintDark: const Color(0xFF0a2c44),
    illustration: (a) => _ProIllo(animating: a),
  ),
];

// ─── Main screen ─────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    await markOnboardingSeen();
    unawaited(AnalyticsService.instance.logOnboardingCompleted(slidesSeen: _page + 1));
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      // Fallback: used only when OnboardingScreen is pushed standalone (not via AuthGate).
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    const navy = Color(0xFF062138);
    const navyDeep = Color(0xFF03152a);

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient — shifts subtly per slide
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [slide.tintDark, navy, navyDeep],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Accent glow
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.7, -0.6),
                  radius: 1.1,
                  colors: [
                    slide.accent.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  slide: slide,
                  page: _page,
                  total: _slides.length,
                  onSkip: _finish,
                ),
                // Page view
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) {
                      final s = _slides[i];
                      return _SlidePage(
                        slide: s,
                        floatCtrl: _floatCtrl,
                        isCurrent: i == _page,
                      );
                    },
                  ),
                ),
                _BottomDock(
                  page: _page,
                  total: _slides.length,
                  slide: slide,
                  onNext: _next,
                  onDotTap: (i) => _controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeInOut,
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

// ─── Top bar (logo + skip + progress segments) ───────────────────────────────

class _TopBar extends StatelessWidget {
  final _Slide slide;
  final int page;
  final int total;
  final VoidCallback onSkip;

  const _TopBar({
    required this.slide,
    required this.page,
    required this.total,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand
              Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [slide.accent, const Color(0xFF3DB5E6)],
                    ),
                  ),
                  child: const Icon(Icons.water_drop_rounded,
                      size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  'AQUARYTHU',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.4,
                  ),
                ),
              ]),
              // Skip
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  'Skip intro',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Segmented progress
          Row(
            children: List.generate(total, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.white.withOpacity(0.14),
                  ),
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 500),
                    widthFactor: i <= page ? 1.0 : 0.0,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: slide.accent,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Individual slide page ────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  final AnimationController floatCtrl;
  final bool isCurrent;

  const _SlidePage({
    required this.slide,
    required this.floatCtrl,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration card — white floating card, ~60% of space
          Expanded(
            flex: 62,
            child: AnimatedBuilder(
              animation: floatCtrl,
              builder: (_, child) {
                final dy = isCurrent
                    ? Tween(begin: 0.0, end: -8.0)
                            .animate(CurvedAnimation(
                                parent: floatCtrl, curve: Curves.easeInOut))
                            .value
                    : 0.0;
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: child,
                );
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.32),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                    BoxShadow(
                      color: slide.accent.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: slide.illustration(isCurrent),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Eyebrow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: slide.accent.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: slide.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: slide.accent, blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  slide.eyebrow,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: slide.accent,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Headline
          Text(
            slide.headline,
            style: const TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.06,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 10),
          // Sub
          Text(
            slide.sub,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.75),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Bottom dock ─────────────────────────────────────────────────────────────

class _BottomDock extends StatelessWidget {
  final int page;
  final int total;
  final _Slide slide;
  final VoidCallback onNext;
  final void Function(int) onDotTap;

  const _BottomDock({
    required this.page,
    required this.total,
    required this.slide,
    required this.onNext,
    required this.onDotTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = page == total - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots + counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(total, (i) {
                  final active = i == page;
                  return GestureDetector(
                    onTap: () => onDotTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.only(right: 6),
                      width: active ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: active
                            ? slide.accent
                            : Colors.white.withOpacity(0.22),
                      ),
                    ),
                  );
                }),
              ),
              Text(
                '${page + 1} / $total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // CTA button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: _PressableButton(
              onTap: onNext,
              color: slide.accent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? 'Start My Farm' : 'Continue',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF062138),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFF062138), size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Trust microcues
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Microcue(label: 'Free to start', accent: slide.accent),
              _Dot(),
              _Microcue(label: '10,000+ farmers', accent: slide.accent),
              _Dot(),
              _Microcue(label: 'Works offline', accent: slide.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _Microcue extends StatelessWidget {
  final String label;
  final Color accent;
  const _Microcue({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_rounded, size: 11, color: accent),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.55),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PressableButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  final Widget child;
  const _PressableButton(
      {required this.onTap, required this.color, required this.child});

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.color, widget.color.withOpacity(0.82)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              const BoxShadow(
                color: Colors.white24,
                blurRadius: 0,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─── Illustration 1: Pain — rising cost graph ─────────────────────────────────

class _PainIllo extends StatefulWidget {
  final bool animating;
  const _PainIllo({required this.animating});

  @override
  State<_PainIllo> createState() => _PainIlloState();
}

class _PainIlloState extends State<_PainIllo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _draw;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _draw = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _draw,
      builder: (_, __) => CustomPaint(
        painter: _PainPainter(progress: _draw.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PainPainter extends CustomPainter {
  final double progress;
  _PainPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const danger = Color(0xFFE94B4B);
    const dangerSoft = Color(0xFFFFEDEB);
    const ink = Color(0xFF0B2540);

    // Background soft fill
    final bgPaint = Paint()..color = dangerSoft;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(16)),
        bgPaint);

    // Graph area (top 60%)
    final graphH = h * 0.60;
    final graphW = w - 48;
    const graphLeft = 24.0;
    const graphTop = 20.0;

    // Rising trend points
    final raw = [
      const Offset(0, 0.85),
      const Offset(0.18, 0.74),
      const Offset(0.34, 0.68),
      const Offset(0.50, 0.52),
      const Offset(0.65, 0.36),
      const Offset(0.82, 0.20),
      const Offset(1.0, 0.06),
    ];
    final pts = raw
        .map((p) => Offset(graphLeft + p.dx * graphW, graphTop + p.dy * graphH))
        .toList();

    final visibleCount = (pts.length * progress).ceil().clamp(2, pts.length);
    final visiblePts = pts.sublist(0, visibleCount);
    if (progress < 1 && visibleCount < pts.length) {
      final t = (pts.length * progress) - (visibleCount - 1);
      final last = pts[visibleCount - 1];
      final next = pts[visibleCount < pts.length ? visibleCount : visibleCount - 1];
      visiblePts[visibleCount - 1] = Offset.lerp(last, next, t)!;
    }

    // Fill under line
    final fillPath = Path()..moveTo(visiblePts.first.dx, visiblePts.first.dy);
    for (final p in visiblePts.skip(1)) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(visiblePts.last.dx, graphTop + graphH);
    fillPath.lineTo(visiblePts.first.dx, graphTop + graphH);
    fillPath.close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [danger.withOpacity(0.38), danger.withOpacity(0)],
          ).createShader(Rect.fromLTWH(0, graphTop, w, graphH)));

    // Line
    final linePath = Path()..moveTo(visiblePts.first.dx, visiblePts.first.dy);
    for (final p in visiblePts.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = danger
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // Cost label
    final titlePainter = TextPainter(
      text: const TextSpan(
          text: 'Feed Cost · Month',
          style: TextStyle(
              color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    titlePainter.paint(canvas, const Offset(graphLeft, graphTop - 16 > 4 ? 4 : 4));

    final costPainter = TextPainter(
      text: const TextSpan(
          text: '₹ 48,200',
          style: TextStyle(
              color: ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    costPainter.paint(canvas, const Offset(graphLeft, 20));

    // +32% badge
    final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w - 76, 14, 64, 26), const Radius.circular(13));
    canvas.drawRRect(badgeRect, Paint()..color = const Color(0xFFFFDDDD));
    final pctPainter = TextPainter(
      text: const TextSpan(
          text: '↑ +32%',
          style: TextStyle(
              color: danger, fontSize: 12, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    pctPainter.paint(
        canvas, Offset(w - 76 + (64 - pctPainter.width) / 2, 14 + 7));

    // End dot
    if (visiblePts.length == pts.length) {
      canvas.drawCircle(visiblePts.last, 5,
          Paint()..color = Colors.white);
      canvas.drawCircle(
          visiblePts.last,
          5,
          Paint()
            ..color = danger
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }

    // Feed bags row
    final bagY = h * 0.68;
    _drawFeedBag(canvas, Offset(graphLeft, bagY), 0.75);
    _drawFeedBag(canvas, Offset(graphLeft + 52, bagY - 12), 0.75);
    _drawFeedBag(canvas, Offset(graphLeft + 104, bagY), 0.75);

    // Alert badge bottom-right
    final cx = w - 44.0;
    final cy = h * 0.82;
    canvas.drawCircle(
        Offset(cx, cy), 28, Paint()..color = const Color(0xFFFFDDDD));
    canvas.drawCircle(Offset(cx, cy), 21, Paint()..color = danger);
    final exclPainter = TextPainter(
      text: const TextSpan(
          text: '!',
          style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    exclPainter.paint(
        canvas, Offset(cx - exclPainter.width / 2, cy - exclPainter.height / 2));
  }

  void _drawFeedBag(Canvas canvas, Offset pos, double scale) {
    final r = Rect.fromLTWH(pos.dx, pos.dy, 48 * scale, 66 * scale);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(5 * scale));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFB454));
    final headerR =
        RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx, pos.dy, 48 * scale, 16 * scale),
            Radius.circular(5 * scale));
    canvas.drawRRect(headerR, Paint()..color = const Color(0xFFE8932B));
    final tp = TextPainter(
      text: TextSpan(
          text: 'FEED',
          style: TextStyle(
              color: Colors.white,
              fontSize: 9 * scale,
              fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(pos.dx + (48 * scale - tp.width) / 2, pos.dy + 22 * scale));
  }

  @override
  bool shouldRepaint(_PainPainter old) => old.progress != progress;
}

// ─── Illustration 2: Smart Feed dashboard ────────────────────────────────────

class _SmartFeedIllo extends StatefulWidget {
  final bool animating;
  const _SmartFeedIllo({required this.animating});

  @override
  State<_SmartFeedIllo> createState() => _SmartFeedIlloState();
}

class _SmartFeedIlloState extends State<_SmartFeedIllo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (_, __) {
        final dy1 = Tween(begin: 0.0, end: -6.0)
            .animate(CurvedAnimation(parent: _float, curve: Curves.easeInOut))
            .value;
        final dy2 = Tween(begin: 0.0, end: 5.0)
            .animate(CurvedAnimation(parent: _float, curve: Curves.easeInOut))
            .value;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Phone dashboard card (center)
            Center(
              child: Transform.translate(
                offset: Offset(0, dy1),
                child: _PhoneDashboard(),
              ),
            ),
            // Floating pill — DOC top-left
            Positioned(
              top: 8,
              left: 0,
              child: Transform.translate(
                offset: Offset(0, dy2),
                child: const _FloatingCard(
                  dot: Color(0xFF3DB5E6),
                  label: 'DOC',
                  value: '45',
                ),
              ),
            ),
            // Floating pill — Feed top-right
            Positioned(
              top: 12,
              right: 0,
              child: Transform.translate(
                offset: Offset(0, dy1 * 0.6),
                child: const _FloatingCard(
                  dot: Color(0xFF2EBD7A),
                  label: 'FEED',
                  value: '+5%',
                  valueColor: Color(0xFF2EBD7A),
                ),
              ),
            ),
            // Floating pill — Growth bottom-right
            Positioned(
              bottom: 8,
              right: 0,
              child: Transform.translate(
                offset: Offset(0, dy2 * 0.7),
                child: const _FloatingCard(
                  dot: Color(0xFF2EBD7A),
                  label: 'GROWTH',
                  value: 'Normal',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PhoneDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const good = Color(0xFF2EBD7A);
    const ink = Color(0xFF0B2540);
    const soft = Color(0xFFF2F8FB);

    return Container(
      width: 170,
      height: double.infinity,
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1ECF5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pond A · Today',
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: ink.withOpacity(0.5))),
          const SizedBox(height: 4),
          const Text('Smart plan',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ink)),
          const SizedBox(height: 8),
          // Smart Feed card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: good,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text('SMART FEED',
                      style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5)),
                ]),
                const SizedBox(height: 4),
                const Text('12.4 kg',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text('↑ 0.6 kg vs yesterday',
                    style: TextStyle(
                        fontSize: 8.5,
                        color: Colors.white.withOpacity(0.85))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Growth sparkline
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Growth',
                      style: TextStyle(
                          fontSize: 8,
                          color: ink.withOpacity(0.5),
                          fontWeight: FontWeight.w600)),
                  const Text('+18%',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: good)),
                ]),
                CustomPaint(
                  size: const Size(60, 30),
                  painter: _SparklinePainter(color: good),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Feed times row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['6AM', '10AM', '2PM', '6PM'].map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3DB5E6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(t,
                      style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w600,
                          color: ink.withOpacity(0.7))),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  _SparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [
      Offset(0, size.height * 0.9),
      Offset(size.width * 0.2, size.height * 0.7),
      Offset(size.width * 0.38, size.height * 0.75),
      Offset(size.width * 0.56, size.height * 0.5),
      Offset(size.width * 0.75, size.height * 0.3),
      Offset(size.width, size.height * 0.1),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    for (final p in pts) {
      canvas.drawCircle(p, 1.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _FloatingCard extends StatelessWidget {
  final Color dot;
  final String label;
  final String value;
  final Color? valueColor;

  const _FloatingCard({
    required this.dot,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0B2540);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1ECF5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: ink.withOpacity(0.5),
                    letterSpacing: 0.4)),
          ]),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? ink)),
        ],
      ),
    );
  }
}

// ─── Illustration 3: Pro dashboard ───────────────────────────────────────────

class _ProIllo extends StatefulWidget {
  final bool animating;
  const _ProIllo({required this.animating});

  @override
  State<_ProIllo> createState() => _ProIlloState();
}

class _ProIlloState extends State<_ProIllo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _draw;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _draw = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const good = Color(0xFF2EBD7A);
    const accent = Color(0xFF3DB5E6);
    const coin = Color(0xFFFFB454);
    const ink = Color(0xFF0B2540);
    const soft = Color(0xFFF2F8FB);

    final metrics = [
      {'label': 'Feed used', 'value': '1,240 kg', 'color': accent},
      {'label': 'Survival', 'value': '94%', 'color': good},
      {'label': 'Avg size', 'value': '24 g', 'color': coin},
      {'label': 'FCR', 'value': '1.32', 'color': const Color(0xFF7A5AE0)},
    ];

    return Column(
      children: [
        // Top: profit + graph
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('THIS CYCLE',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: ink.withOpacity(0.45),
                              letterSpacing: 0.6)),
                      const SizedBox(height: 2),
                      const Text('Net profit',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ink)),
                      const Text('₹ 2,18,400',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: good)),
                    ]),
                    // +18% ribbon
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: good,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Row(children: [
                        Icon(Icons.trending_up_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('+18%',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _draw,
                    builder: (_, __) => CustomPaint(
                      painter: _ProfitGraphPainter(
                          progress: _draw.value, color: good),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Metric grid 2x2
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: metrics.map((m) {
            final color = m['color'] as Color;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m['label'] as String,
                      style: TextStyle(
                          fontSize: 8,
                          color: ink.withOpacity(0.5),
                          fontWeight: FontWeight.w600)),
                  Text(m['value'] as String,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ink)),
                ]),
              ]),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ProfitGraphPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ProfitGraphPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final raw = [
      const Offset(0.0, 0.85),
      const Offset(0.15, 0.78),
      const Offset(0.30, 0.80),
      const Offset(0.46, 0.60),
      const Offset(0.62, 0.52),
      const Offset(0.77, 0.30),
      const Offset(0.90, 0.20),
      const Offset(1.0, 0.05),
    ];
    final pts =
        raw.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();

    final visibleCount = (pts.length * progress).ceil().clamp(2, pts.length);
    final vp = pts.sublist(0, visibleCount);
    if (progress < 1 && visibleCount < pts.length) {
      final t = (pts.length * progress) - (visibleCount - 1);
      vp[visibleCount - 1] = Offset.lerp(
          pts[visibleCount - 1], pts[visibleCount], t)!;
    }

    final fillPath = Path()..moveTo(vp.first.dx, vp.first.dy);
    for (final p in vp.skip(1)) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(vp.last.dx, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withOpacity(0.3), color.withOpacity(0)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final line = Path()..moveTo(vp.first.dx, vp.first.dy);
    for (final p in vp.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    if (vp.length == pts.length) {
      canvas.drawCircle(vp.last, 4, Paint()..color = Colors.white);
      canvas.drawCircle(
          vp.last,
          4,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_ProfitGraphPainter old) => old.progress != progress;
}
