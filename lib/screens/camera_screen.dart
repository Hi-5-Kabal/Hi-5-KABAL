import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/holistic_feature_extractor.dart';
import '../services/model_service.dart';
import '../theme/app_theme.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isFrontCamera = false;
  bool _isFlipping = false;

  bool _isModelReady = false;
  bool _isTranslating = false;
  bool _isPredicting = false;
  CameraImage? _latestCameraImage;

  final List<String> _detectedWords = [];
  Timer? _predictionTimer;
  final FlutterTts _tts = FlutterTts();
  late HolisticFeatureExtractor _holisticExtractor;

  late AnimationController _recordButtonController;
  late AnimationController _flipController;
  late AnimationController _pulseController;

  late Animation<double> _recordScale;
  late Animation<double> _flipRotation;
  late Animation<double> _pulseAnim;

  final ScrollController _wordsScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _holisticExtractor = HolisticFeatureExtractor();
    _initAnimations();
    _initCamera();
    _initTts();
    _initModel();
  }

  void _initAnimations() {
    _recordButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _recordScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(
        parent: _recordButtonController,
        curve: Curves.easeInOut,
      ),
    );

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _startCamera(_cameras.first);
    } catch (_) {}
  }

  Future<void> _startCamera(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
    );

    try {
      await controller.initialize();
    } catch (_) {
      controller.dispose();
      return;
    }

    if (!mounted) {
      controller.dispose();
      return;
    }

    final previous = _cameraController;
    setState(() {
      _cameraController = controller;
      _isCameraReady = true;
    });
    previous?.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.8);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _initModel() async {
    await ModelService.init();
    if (!mounted) return;
    setState(() => _isModelReady = ModelService.isLoaded);
  }

  @override
  void dispose() {
    _predictionTimer?.cancel();
    if (_cameraController?.value.isStreamingImages ?? false) {
      _cameraController?.stopImageStream();
    }
    _cameraController?.dispose();
    _holisticExtractor.close();
    _wordsScroll.dispose();
    _recordButtonController.dispose();
    _flipController.dispose();
    _pulseController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleTranslation() async {
    HapticFeedback.mediumImpact();
    _recordButtonController.forward().then((_) => _recordButtonController.reverse());

    if (_isTranslating) {
      await _stopTranslation();
      return;
    }

    if (!_isModelReady) {
      final details = ModelService.lastError ??
          'No se pudo inicializar el interprete TFLite.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Modelo no cargado. Detalle: $details',
          ),
        ),
      );
      return;
    }

    await _startTranslation();
  }

  Future<void> _startTranslation() async {
    ModelService.resetSequence();
    _latestCameraImage = null;

    try {
      if (_cameraController != null &&
          !_cameraController!.value.isStreamingImages) {
        await _cameraController!.startImageStream((image) {
          _latestCameraImage = image;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar stream de camara: $e')),
      );
      return;
    }

    setState(() => _isTranslating = true);
    _predictionTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _captureAndPredict(),
    );
  }

  Future<void> _stopTranslation() async {
    _predictionTimer?.cancel();
    _predictionTimer = null;
    try {
      if (_cameraController?.value.isStreamingImages ?? false) {
        await _cameraController?.stopImageStream();
      }
    } catch (_) {
      // Ignore stop stream transient issues.
    }
    _latestCameraImage = null;
    ModelService.resetSequence();
    setState(() => _isTranslating = false);
  }

  Future<void> _captureAndPredict() async {
    if (_isPredicting ||
        !_isCameraReady ||
        _cameraController == null ||
        _latestCameraImage == null) {
      return;
    }

    _isPredicting = true;
    try {
      final frameFeatures = await _holisticExtractor.extract(
        _latestCameraImage!,
        _cameraController!.description,
      );
      if (frameFeatures == null) return;

      final word = await ModelService.predict(frameFeatures);

      if (word != null && mounted) {
        setState(() {
          if (_detectedWords.isEmpty || _detectedWords.last != word) {
            _detectedWords.add(word);
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_wordsScroll.hasClients) {
            _wordsScroll.animateTo(
              _wordsScroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (_) {
      // Ignore transient camera/inference errors.
    } finally {
      _isPredicting = false;
    }
  }

  Future<void> _speakLastWord() async {
    HapticFeedback.lightImpact();
    if (_detectedWords.isEmpty) return;
    await _tts.stop();
    await _tts.speak(_detectedWords.last);
  }

  Future<void> _flipCamera() async {
    if (_isFlipping || _cameras.length < 2) return;

    if (_isTranslating) {
      await _stopTranslation();
    }

    HapticFeedback.lightImpact();
    setState(() => _isFlipping = true);
    await _flipController.forward();

    _isFrontCamera = !_isFrontCamera;
    final target = _cameras.firstWhere(
      (camera) =>
          camera.lensDirection ==
          (_isFrontCamera ? CameraLensDirection.front : CameraLensDirection.back),
      orElse: () => _cameras[_isFrontCamera ? 1 : 0],
    );

    await _startCamera(target);
    _flipController.reset();
    if (mounted) {
      setState(() => _isFlipping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildTopBar(),
          if (_isTranslating) _buildTranslatingBadge(),
          if (_detectedWords.isNotEmpty) _buildTranslationPanel(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isCameraReady && _cameraController != null) {
      return Positioned.fill(child: CameraPreview(_cameraController!));
    }

    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF1A2030), Color(0xFF0A0E1A)],
          ),
        ),
        child: Stack(
          children: [
            CustomPaint(painter: _CameraGridPainter(), size: Size.infinite),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _isFrontCamera ? Icons.face : Icons.camera_alt_outlined,
                      color: Colors.white.withOpacity(0.3),
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isFrontCamera ? 'Camara frontal' : 'Camara trasera',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Iniciando camara...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslatingBadge() {
    return Positioned(
      top: 76,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Opacity(
              opacity: 0.72 + _pulseAnim.value * 0.14,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.45),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TRADUCIENDO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationPanel() {
    return Positioned(
      bottom: 130,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 180),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.55),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.translate, color: AppTheme.accentBlue, size: 15),
                  const SizedBox(width: 6),
                  const Text(
                    'Traduccion',
                    style: TextStyle(
                      color: AppTheme.accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _detectedWords.clear()),
                    child: Icon(
                      Icons.clear_all,
                      color: Colors.white.withOpacity(0.4),
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  controller: _wordsScroll,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _detectedWords
                        .asMap()
                        .entries
                        .map(
                          (entry) => _WordChip(
                            word: entry.value,
                            isLast: entry.key == _detectedWords.length - 1,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _TopBarButton(
                icon: Icons.flash_auto,
                onTap: () => HapticFeedback.lightImpact(),
              ),
              const Spacer(),
              _TopBarButton(
                icon: Icons.settings,
                onTap: () => HapticFeedback.lightImpact(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.92),
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildVolumeButton(),
                const SizedBox(width: 16),
                _buildTranslateButton(),
                const SizedBox(width: 16),
                _buildFlipButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeButton() {
    return GestureDetector(
      onTap: _speakLastWord,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.30),
            width: 1.5,
          ),
          color: Colors.white.withOpacity(0.10),
        ),
        child: Icon(
          Icons.volume_up,
          color: Colors.white.withOpacity(0.85),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildTranslateButton() {
    return GestureDetector(
      onTap: _toggleTranslation,
      child: AnimatedBuilder(
        animation: Listenable.merge([_recordButtonController, _pulseController]),
        builder: (context, _) {
          return ScaleTransition(
            scale: _recordScale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isTranslating)
                  Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryBlue.withOpacity(0.25),
                      ),
                    ),
                  ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isTranslating ? AppTheme.primaryBlue : Colors.white,
                      width: 3.5,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isTranslating ? 34 : 60,
                  height: _isTranslating ? 34 : 60,
                  decoration: BoxDecoration(
                    color: _isTranslating ? AppTheme.primaryBlue : Colors.white,
                    borderRadius:
                        _isTranslating ? BorderRadius.circular(8) : BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: (_isTranslating ? AppTheme.primaryBlue : Colors.white)
                            .withOpacity(0.40),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlipButton() {
    return GestureDetector(
      onTap: _flipCamera,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.15),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: AnimatedBuilder(
          animation: _flipRotation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _flipRotation.value * 3.14159,
              child: child,
            );
          },
          child: Icon(
            Icons.flip_camera_ios,
            color: Colors.white.withOpacity(0.90),
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  final String word;
  final bool isLast;

  const _WordChip({required this.word, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isLast ? AppTheme.primaryBlue.withOpacity(0.90) : Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLast ? AppTheme.primaryBlue : Colors.white.withOpacity(0.20),
          width: 1,
        ),
      ),
      child: Text(
        word,
        style: TextStyle(
          color: isLast ? Colors.white : Colors.white.withOpacity(0.85),
          fontSize: 14,
          fontWeight: isLast ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBarButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.85), size: 20),
      ),
    );
  }
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.8;

    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );

    final cx = size.width / 2;
    final cy = size.height / 2;
    const frameSize = 90.0;
    const cornerLen = 18.0;
    final framePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(cx - frameSize, cy - frameSize),
      Offset(cx - frameSize + cornerLen, cy - frameSize),
      framePaint,
    );
    canvas.drawLine(
      Offset(cx - frameSize, cy - frameSize),
      Offset(cx - frameSize, cy - frameSize + cornerLen),
      framePaint,
    );

    canvas.drawLine(
      Offset(cx + frameSize, cy - frameSize),
      Offset(cx + frameSize - cornerLen, cy - frameSize),
      framePaint,
    );
    canvas.drawLine(
      Offset(cx + frameSize, cy - frameSize),
      Offset(cx + frameSize, cy - frameSize + cornerLen),
      framePaint,
    );

    canvas.drawLine(
      Offset(cx - frameSize, cy + frameSize),
      Offset(cx - frameSize + cornerLen, cy + frameSize),
      framePaint,
    );
    canvas.drawLine(
      Offset(cx - frameSize, cy + frameSize),
      Offset(cx - frameSize, cy + frameSize - cornerLen),
      framePaint,
    );

    canvas.drawLine(
      Offset(cx + frameSize, cy + frameSize),
      Offset(cx + frameSize - cornerLen, cy + frameSize),
      framePaint,
    );
    canvas.drawLine(
      Offset(cx + frameSize, cy + frameSize),
      Offset(cx + frameSize, cy + frameSize - cornerLen),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
