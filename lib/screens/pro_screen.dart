import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'main_screen.dart';

class ProScreen extends StatefulWidget {
  const ProScreen({super.key, this.fromSplash = false});

  final bool fromSplash;

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  bool _showClose = false;

  static const bg = Color(0xFFF7F7F7);
  static const blue = Color(0xFF007AFF);
  static const ctaBlue = Color(0xFF2F80ED);
  static const ctaSteel = Color(0xFF4D6FA6);
  static const ctaCyan = Color(0xFF36D1DC);
  static const selectedBg = Color(0xFFF0F7FF);
  late final AnimationController _ctaController;
  late final Animation<double> _ctaScale;

  @override
  void initState() {
    super.initState();
    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _ctaScale = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _ctaController, curve: Curves.easeInOut));
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() => _showClose = true);
    });
  }

  @override
  void dispose() {
    _ctaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),

                      // Printer image (268.72 x 257)
                      SizedBox(
                        width: 268.72,
                        height: 257,
                        child: Image.asset(
                          'assets/images/printer2.png',
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Upgrade headline
                      const SizedBox(
                        width: 256,
                        height: 41,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Go Pro, Print Smarter',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w900,
                              fontSize: 34,
                              height: 1.0,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Bullets block (approx same area)
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 217.83,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BulletRich(
                                normalPrefix: 'Print ',
                                boldWord: 'Unlimited',
                                normalSuffix: ' Documents',
                              ),
                              _BulletRich(
                                normalPrefix: 'Scan your ',
                                boldWord: 'Documents',
                                normalSuffix: '',
                              ),
                              _BulletRich(
                                normalPrefix: 'Unlock ',
                                boldWord: 'Editing',
                                normalSuffix: ' Tools',
                              ),
                              _BulletRich(
                                normalPrefix: 'Remove ',
                                boldWord: 'Ads',
                                normalSuffix: '',
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Plans (fields)
                      Align(
                        alignment: Alignment.center,
                        child: PlanTile(
                          title: 'Weekly Plan',
                          subtitle: 'Billed \$4.99 pr week',
                          rightTop: '\$0.71',
                          rightBottom: 'per day',
                          badgeText: 'Popular',
                          badgeColor: const Color(0xFF1FAAA0),
                          isSelected: selectedIndex == 0,
                          onTap: () => setState(() => selectedIndex = 0),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: PlanTile(
                          title: 'Monthly Plan',
                          subtitle: 'Billed \$7.99 per month',
                          rightTop: '\$0.91',
                          rightBottom: 'per week',
                          badgeText: '50% OFF',
                          badgeColor: const Color(0xFFFF8A00),
                          isSelected: selectedIndex == 1,
                          onTap: () => setState(() => selectedIndex = 1),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: PlanTile(
                          title: 'Yearly Plan',
                          subtitle: 'Billed \$24.99 per year',
                          rightTop: '\$0.48',
                          rightBottom: 'per week',
                          badgeText: '90% OFF',
                          badgeColor: const Color(0xFF6C45FA),
                          isSelected: selectedIndex == 2,
                          onTap: () => setState(() => selectedIndex = 2),
                        ),
                      ),

                      const SizedBox(height: 14),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 4,
              left: 15,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                opacity: _showClose ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showClose,
                  child: IconButton(
                    onPressed: () {
                      if (widget.fromSplash) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const MainScreen(),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: const Color.fromARGB(95, 173, 172, 172),
                    iconSize: 22,
                    tooltip: 'Close',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        color: bg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 280,
              height: 46,
              child: AnimatedBuilder(
                animation: _ctaController,
                builder: (context, _) {
                  final t = _ctaController.value;
                  final begin = Alignment.lerp(
                    Alignment.topLeft,
                    Alignment.bottomRight,
                    t,
                  )!;
                  final end = Alignment.lerp(
                    Alignment.bottomRight,
                    Alignment.topLeft,
                    t,
                  )!;
                  final wave = (math.sin(t * 2 * math.pi) + 1) / 2;
                  final gradient = LinearGradient(
                    colors: const [
                      ctaBlue,
                      ctaSteel,
                      Color.fromARGB(255, 54, 107, 220),
                    ],
                    begin: begin,
                    end: end,
                  );
                  return Transform.scale(
                    scale: _ctaScale.value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: ctaBlue.withOpacity(0.2 + (0.18 * wave)),
                            blurRadius: 14 + (10 * wave),
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.35,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.0),
                                        Colors.white.withOpacity(0.32),
                                        Colors.white.withOpacity(0.0),
                                      ],
                                      stops: const [0.2, 0.5, 0.8],
                                      begin: Alignment(-1.2 + 2.4 * t, -1.0),
                                      end: Alignment(-0.2 + 2.4 * t, 1.0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const MainScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                ),
                                child: const Text(
                                  'Continue',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    fontFamily: 'SF Pro',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try Pro risk‑free. Cancel whenever you want.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 50,
              children: const [
                _FooterLink(text: 'Terms of use'),
                _FooterLink(text: 'Limited Edition'),
                _FooterLink(text: 'Privacy policy'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bullet line with one bold word (exact as you asked)
class _BulletRich extends StatelessWidget {
  const _BulletRich({
    required this.normalPrefix,
    required this.boldWord,
    required this.normalSuffix,
  });

  final String normalPrefix;
  final String boldWord;
  final String normalSuffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: SizedBox(
              width: 15,
              height: 18,
              child: Center(
                child: Icon(Icons.check, size: 18, color: _ProScreenState.blue),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 15,
                  height: 1.25,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: normalPrefix),
                  TextSpan(
                    text: boldWord,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: normalSuffix),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlanTile extends StatelessWidget {
  const PlanTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.rightTop,
    required this.rightBottom,
    required this.badgeText,
    required this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String rightTop;
  final String rightBottom;
  final String badgeText;
  final Color badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  static const blue = Color(0xFF007AFF);
  static const selectedBg = Color(0xFFF0F7FF);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 339,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? blue : const Color(0xFFE3E3E3),
                  width: isSelected ? 1.8 : 1.2,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        rightTop,
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        rightBottom,
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Badge top center
          Positioned(
            top: 1,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'SF Pro',
          fontSize: 10.5,
          color: Colors.black45,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
