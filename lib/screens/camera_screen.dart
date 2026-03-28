import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../theme/app_theme.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isFrontCamera = false;
  bool _isFlipping = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  late AnimationController _recordButtonController;
  late AnimationController _flipController;
  late AnimationController _pulseController;

  late Animation<double> _recordScale;
  late Animation<double> _flipRotation;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _recordButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _recordScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _recordButtonController, curve: Curves.easeInOut),
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

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recordButtonController.dispose();
    _flipController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    HapticFeedback.mediumImpact();

    _recordButtonController.forward().then((_) {
      _recordButtonController.reverse();
    });

    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _recordingSeconds = 0;
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _recordingSeconds++);
        });
      } else {
        _recordingTimer?.cancel();
        _recordingTimer = null;
      }
    });
  }

  void _flipCamera() async {
    if (_isFlipping) return;
    HapticFeedback.lightImpact();

    setState(() => _isFlipping = true);
    await _flipController.forward();
    setState(() => _isFrontCamera = !_isFrontCamera);
    _flipController.reset();
    setState(() => _isFlipping = false);
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview area (simulated)
          _buildCameraPreview(),

          // Top bar (status)
          _buildTopBar(),

          // Bottom controls
          _buildBottomControls(),

          // Recording indicator
          if (_isRecording) _buildRecordingBadge(),

          // Mode selector (top area)
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF1A2030),
              Color(0xFF0A0E1A),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Simulated camera grid
            CustomPaint(
              painter: _CameraGridPainter(),
              size: Size.infinite,
            ),
            // Camera unavailable message
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
                    _isFrontCamera ? 'Cámara frontal' : 'Cámara trasera',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vista previa de cámara',
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
              // Flash button
              _TopBarButton(
                icon: Icons.flash_auto,
                onTap: () => HapticFeedback.lightImpact(),
              ),
              const Spacer(),
              const Spacer(),
              // Settings button
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
        padding: const EdgeInsets.only(bottom: 0),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gallery / last video button
                _buildGalleryButton(),

                const SizedBox(width: 16),

                // Main Record button
                _buildRecordButton(),

                const SizedBox(width: 16),

                // Flip camera button
                _buildFlipButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryButton() {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
          color: Colors.white.withOpacity(0.1),
        ),
        child: Icon(
          Icons.volume_up,
          color: Colors.white.withOpacity(0.8),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedBuilder(
        animation: Listenable.merge([_recordButtonController, _pulseController]),
        builder: (context, _) {
          return ScaleTransition(
            scale: _recordScale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulse ring (when recording)
                if (_isRecording)
                  Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.recordRed.withOpacity(0.25),
                      ),
                    ),
                  ),

                // Outer ring
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isRecording
                          ? AppTheme.recordRed
                          : Colors.white,
                      width: 3.5,
                    ),
                  ),
                ),

                // Inner button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isRecording ? 34 : 60,
                  height: _isRecording ? 34 : 60,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? AppTheme.recordRed
                        : Colors.white,
                    borderRadius: _isRecording
                        ? BorderRadius.circular(8)
                        : BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? AppTheme.recordRed : Colors.white)
                            .withOpacity(0.4),
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
            color: Colors.white.withOpacity(0.9),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingBadge() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Opacity(
              opacity: 0.7 + _pulseAnim.value * 0.15,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.recordRed,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.recordRed.withOpacity(0.4),
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
                Text(
                  'REC  ${_formatTime(_recordingSeconds)}',
                  style: const TextStyle(
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
}

// ───────────────────────────────────────────────
// Supporting widgets
// ───────────────────────────────────────────────

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

class _ModeChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _ModeChip({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryBlue.withOpacity(0.85)
            : Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryBlue
              : Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.55),
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// Grid lines painter for camera effect
class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 0.8;

    // Vertical lines (rule of thirds)
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // Horizontal lines (rule of thirds)
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );

    // Focus frame in center
    final cx = size.width / 2;
    final cy = size.height / 2;
    const frameSize = 90.0;
    const cornerLen = 18.0;
    const thick = 1.5;
    final fp = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke;

    // Top-left corner
    canvas.drawLine(Offset(cx - frameSize, cy - frameSize),
        Offset(cx - frameSize + cornerLen, cy - frameSize), fp);
    canvas.drawLine(Offset(cx - frameSize, cy - frameSize),
        Offset(cx - frameSize, cy - frameSize + cornerLen), fp);

    // Top-right corner
    canvas.drawLine(Offset(cx + frameSize, cy - frameSize),
        Offset(cx + frameSize - cornerLen, cy - frameSize), fp);
    canvas.drawLine(Offset(cx + frameSize, cy - frameSize),
        Offset(cx + frameSize, cy - frameSize + cornerLen), fp);

    // Bottom-left corner
    canvas.drawLine(Offset(cx - frameSize, cy + frameSize),
        Offset(cx - frameSize + cornerLen, cy + frameSize), fp);
    canvas.drawLine(Offset(cx - frameSize, cy + frameSize),
        Offset(cx - frameSize, cy + frameSize - cornerLen), fp);

    // Bottom-right corner
    canvas.drawLine(Offset(cx + frameSize, cy + frameSize),
        Offset(cx + frameSize - cornerLen, cy + frameSize), fp);
    canvas.drawLine(Offset(cx + frameSize, cy + frameSize),
        Offset(cx + frameSize, cy + frameSize - cornerLen), fp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
