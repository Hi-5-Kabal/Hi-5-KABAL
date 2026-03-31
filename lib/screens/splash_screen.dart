import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'camera_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _navigationDelay = Duration(milliseconds: 4000);

  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _loadingController;
  late AnimationController _pulseController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _loadingOpacity;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Animacion del logo
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Animacion del texto
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Animacion de carga
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _loadingOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeIn),
    );

    // Animacion de pulso (mano saludando)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startAnimations();
  }

//inicia las animaciones en secuencia y luego navega a la pantalla de camara
  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    _loadingController.forward();

    await Future.delayed(_navigationDelay);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const CameraScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _loadingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 255, 246, 228),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnim.value,
                          child: child,
                        );
                      },
                      child: _buildLogo(),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Nombre app y texto descriptivo
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        Text(
                          'KABAL',
                          style: GoogleFonts.bebasNeue(
                            color: Color.fromARGB(255, 85, 93, 103),
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            height: 0.9,
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -1),
                          child: Text(
                            'Captura, traduce y comunica sin barreras.',
                            style: GoogleFonts.bebasNeue(
                              color: Color.fromARGB(255, 85, 93, 103),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 64),

                // Loading indicator
                FadeTransition(
                  opacity: _loadingOpacity,
                  child: const _SplashLoader(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //Icono de la mano saludando, con animacion de pulso
  Widget _buildLogo() {
    return const Icon(
      Icons.waving_hand,
      color: Color.fromARGB(255, 4, 193, 181),
      size: 110,
    );
  }
}

class _SplashLoader extends StatefulWidget {
  const _SplashLoader();

  @override
  State<_SplashLoader> createState() => _SplashLoaderState();
}

class _SplashLoaderState extends State<_SplashLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final delay = i * 0.33;
            final value = math.sin((_controller.value - delay) * 2 * math.pi);
            final opacity = (value + 1) / 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 85, 93, 103),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
