import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/drape_ui.dart';
import '../providers/wardrobe_provider.dart';
import '../widgets/photo_guide_overlay.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({this.returnRoute = '/wardrobe', super.key});

  final String returnRoute;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  final _picker = ImagePicker();
  bool _uploading = false;
  int _tipIndex = 0;
  Timer? _tipTimer;
  bool _showGuide = false;

  static const _tips = [
    'Lay flat on a plain background',
    'Use soft natural light',
    'Fill the frame, leave a margin',
    'No hangers, just the piece',
  ];

  @override
  void initState() {
    super.initState();
    _tipTimer = Timer.periodic(
      const Duration(milliseconds: 2800),
      (_) {
        if (mounted) setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
      },
    );
    _checkPhotoGuide();
  }

  Future<void> _checkPhotoGuide() async {
    final show = await PhotoGuideOverlay.shouldShow();
    if (show && mounted) setState(() => _showGuide = true);
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (file == null) return;
      _showPreview(file.path);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final isPermission = msg.contains('photo_access_denied') ||
          msg.contains('camera_access_denied') ||
          msg.contains('PermissionDenied');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.red,
        content: Text(
          isPermission
              ? 'Enable Camera & Photos in Settings → Sugatai'
              : 'Could not open ${source == ImageSource.camera ? "camera" : "gallery"}',
          style: const TextStyle(color: Colors.white),
        ),
      ));
    }
  }

  void _showPreview(String path) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoPreviewSheet(
        imagePath: path,
        onRetake: () => Navigator.pop(context),
        onUse: () {
          Navigator.pop(context);
          _upload(path);
        },
      ),
    );
  }

  Future<void> _upload(String path) async {
    setState(() => _uploading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.uploadItem(path);
      ref.invalidate(wardrobeProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to closet. AI is tagging in the background.'),
          backgroundColor: AppColors.ink,
        ),
      );
      context.go(widget.returnRoute);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed. Please try again.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A14),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Cosmic camera preview
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.1,
                colors: [
                  Color(0xFF2A1035),
                  Color(0xFF140A20),
                  Color(0xFF0C0A14),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Accent orbs
          Positioned(
            top: 80,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.2),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.pink.withValues(alpha: 0.1),
              ),
            ),
          ),
          const _DashedFrame(),
          const Center(
            child: Opacity(
              opacity: 0.08,
              child: Icon(
                Icons.checkroom_rounded,
                size: 120,
                color: Colors.white,
              ),
            ),
          ),
          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassCircleBtn(
                  icon: Icons.close_rounded,
                  onTap: () => context.pop(),
                ),
                Row(
                  children: [
                    _GlassCircleBtn(
                      icon: Icons.tips_and_updates_outlined,
                      onTap: () => setState(() => _showGuide = true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Title
          Positioned(
            top: MediaQuery.paddingOf(context).top + 72,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Add to closet',
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose one clear photo of the clothing piece',
                  style: AppTypography.caption.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
          // Rotating tip pill
          Positioned(
            bottom: 150,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Container(
                  key: ValueKey(_tipIndex),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _tips[_tipIndex],
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_uploading) _buildUploadOverlay(),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GlassCircleBtn(
                  icon: Icons.photo_library_rounded,
                  size: 52,
                  onTap:
                      _uploading ? null : () => _pickImage(ImageSource.gallery),
                ),
                const SizedBox(width: 32),
                GestureDetector(
                  onTap:
                      _uploading ? null : () => _pickImage(ImageSource.camera),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.cta,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange.withValues(alpha: 0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                const SizedBox(width: 52),
              ],
            ),
          ),
          if (_showGuide)
            PhotoGuideOverlay(
              onDismiss: () => setState(() => _showGuide = false),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1525).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: AppColors.orange,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Preparing your piece',
                    style: GoogleFonts.syne(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Removing the background before saving',
                    style:
                        AppTypography.caption.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const _GlassCircleBtn({
    required this.icon,
    this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: size * 0.45, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _DashedFrame extends StatelessWidget {
  const _DashedFrame();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          36,
          MediaQuery.paddingOf(context).top + 140,
          36,
          200,
        ),
        child: CustomPaint(painter: _DashedBorderPainter()),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 12.0;
    const gap = 7.0;
    const radius = 24.0;
    const sw = 2.0;

    final paint = Paint()
      ..shader = AppGradients.hero.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(sw / 2, sw / 2, size.width - sw, size.height - sw),
      const Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      bool draw = true;
      while (d < metric.length) {
        if (draw) {
          final end = (d + dash).clamp(0.0, metric.length);
          canvas.drawPath(metric.extractPath(d, end), paint);
        }
        d += draw ? dash : gap;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PhotoPreviewSheet extends StatelessWidget {
  final String imagePath;
  final VoidCallback onRetake;
  final VoidCallback onUse;

  const _PhotoPreviewSheet({
    required this.imagePath,
    required this.onRetake,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16131F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(
              File(imagePath),
              height: 280,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  gradient: AppGradients.cta,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to add?',
                      style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'We will remove the background before saving.',
                      style:
                          AppTypography.caption.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DrapeGradientButton(
                  label: 'Use this',
                  onPressed: onUse,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
