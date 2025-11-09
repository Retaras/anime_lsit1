import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'main_screen.dart';
import 'dart:ui';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _glowController;
  late AnimationController _particlesController;
  late AnimationController _cardController;
  late AnimationController _buttonController;
  
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _titleFade;
  late Animation<double> _titleSlide;
  late Animation<double> _cardFade;
  late Animation<double> _cardSlide;
  late Animation<double> _buttonFade;
  late Animation<double> _buttonScale;
  late Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();

    // Контроллер для общей анимации появления
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Пульсация свечения
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowPulse = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Частицы
    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    // Анимация логотипа
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    // Анимация заголовка
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );

    // Карточка с описанием
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOut),
    );

    _cardSlide = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );

    // Кнопка
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOut),
    );

    _buttonScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeOutBack),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    _cardController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _buttonController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _glowController.dispose();
    _particlesController.dispose();
    _cardController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1200),
        pageBuilder: (_, __, ___) => const MainScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          _buildParticles(),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        // Основной фон
        TweenAnimationBuilder(
          tween: Tween<double>(begin: 1.0, end: 1.15),
          duration: const Duration(seconds: 30),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/anime_bg.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            );
          },
        ),
        // Blur и затемнение
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0A0A0A).withOpacity(0.85),
                  const Color(0xFF1A0A0F).withOpacity(0.90),
                  const Color(0xFF2A0505).withOpacity(0.95),
                ],
              ),
            ),
          ),
        ),
        // Виньетка
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _particlesController,
      builder: (context, child) {
        return CustomPaint(
          painter: LuxuryParticlesPainter(_particlesController.value),
          child: Container(),
        );
      },
    );
  }

  Widget _buildContent() {
  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          // Уменьшаем верхний Spacer
          const Spacer(flex: 1),
          _buildLogo(),
          const SizedBox(height: 30), // чуть меньше
          _buildTitle(),
          const SizedBox(height: 12),
          _buildSubtitle(),
          // уменьшаем нижний Spacer
          const Spacer(flex: 1),
          _buildFeatureCard(),
          const Spacer(flex: 1),
          _buildButton(),
          const SizedBox(height: 20), // меньше чем было 50
        ],
      ),
    ),
  );
}

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoScale.value,
          child: Opacity(
            opacity: _logoFade.value,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFF3366).withOpacity(_glowPulse.value),
                        const Color(0xFFFF6B6B).withOpacity(_glowPulse.value * 0.8),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3366).withOpacity(_glowPulse.value * 0.6),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF6B6B).withOpacity(0.3),
                        blurRadius: 80,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.movie_filter_rounded,
                      size: 50,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _titleSlide.value),
          child: Opacity(
            opacity: _titleFade.value,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        Colors.white,
                        Color.lerp(Colors.white, const Color(0xFFFF3366), _glowPulse.value * 0.3)!,
                        Colors.white,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ).createShader(bounds);
                  },
                  child: const Text(
                    'AENIMA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                      height: 1.2,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitle() {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Opacity(
          opacity: _titleFade.value,
          child: Text(
            'АНИМЕ ТРЕКИНГ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFF6B6B).withOpacity(0.9),
              letterSpacing: 3,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard() {
    return AnimatedBuilder(
      animation: _cardController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _cardSlide.value),
          child: Opacity(
            opacity: _cardFade.value,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildFeatureItem(
                    Icons.bookmark_rounded,
                    'Отслеживайте прогресс',
                    'Управляйте списком просмотренных аниме',
                  ),
                  const SizedBox(height: 24),
                  _buildFeatureItem(
                    Icons.star_rounded,
                    'Оценивайте и находите',
                    'Открывайте новые шедевры аниме-индустрии',
                  ),
                  const SizedBox(height: 24),
                  _buildFeatureItem(
                    Icons.insights_rounded,
                    'Анализируйте статистику',
                    'Персональная аналитика вашего опыта',
                  ),
                  const SizedBox(height: 24),
                  _buildFeatureItem(
                    Icons.emoji_events_rounded,
                    'Получайте достижения',
                    'Станьте легендой 2D-мира, выполняя уникальные испытания',
                    ),
                  const SizedBox(height: 24),
                  _buildFeatureItem(
                    Icons.style,// иконка "магия/эффекты"
                    'Собирайте уникальные карты',
                    'Открывайте наборы и получайте карточки с узнаваемыми персонажами мира аниме',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF3366), Color(0xFFFF6B6B)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3366).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButton() {
    return AnimatedBuilder(
      animation: _buttonController,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonScale.value,
          child: Opacity(
            opacity: _buttonFade.value,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return GestureDetector(
                  onTap: _navigateToMain,
                  child: Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.lerp(const Color(0xFFFF3366), const Color(0xFFFF5588), _glowPulse.value * 0.3)!,
                          Color.lerp(const Color(0xFFFF6B6B), const Color(0xFFFF8888), _glowPulse.value * 0.3)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3366).withOpacity(_glowPulse.value * 0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withOpacity(0.3),
                          blurRadius: 50,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'НАЧАТЬ ПУТЕШЕСТВИЕ',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(seconds: 2),
                            builder: (context, double value, child) {
                              return Transform.translate(
                                offset: Offset(math.sin(value * math.pi * 2) * 4, 0),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class LuxuryParticlesPainter extends CustomPainter {
  final double animationValue;

  LuxuryParticlesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Большие медленные частицы
    for (int i = 0; i < 20; i++) {
      final seed = i * 234.567;
      final x = (math.sin(seed) * 0.5 + 0.5) * size.width;
      final y = ((seed % 1.0) + animationValue * 0.3) % 1.0 * size.height;
      final radius = (math.cos(seed * 2) * 0.5 + 0.5) * 2.5 + 1.5;
      final opacity = (math.sin(animationValue * math.pi + seed) * 0.3 + 0.4) * 0.3;

      final gradient = RadialGradient(
        colors: [
          const Color(0xFFFF3366).withOpacity(opacity),
          const Color(0xFFFF6B6B).withOpacity(opacity * 0.3),
          Colors.transparent,
        ],
      );

      final rect = Rect.fromCircle(center: Offset(x, y), radius: radius * 3);
      paint.shader = gradient.createShader(rect);
      canvas.drawCircle(Offset(x, y), radius * 3, paint);
    }

    // Маленькие быстрые частицы
    for (int i = 0; i < 40; i++) {
      final seed = i * 456.789;
      final x = (math.cos(seed * 3) * 0.5 + 0.5) * size.width;
      final y = ((seed % 1.0) + animationValue * 0.7) % 1.0 * size.height;
      final radius = (math.sin(seed) * 0.5 + 0.5) * 1.5 + 0.5;
      final opacity = (math.cos(animationValue * math.pi * 2 + seed * 2) * 0.5 + 0.5) * 0.4;

      paint.shader = null;
      paint.color = Colors.white.withOpacity(opacity * 0.6);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(LuxuryParticlesPainter oldDelegate) => true;
}