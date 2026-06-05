import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../widgets/photo_guide_overlay.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

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
    'Lay flat on a plain surface',
    'Soft natural light works best',
    'Fill the frame, leave a little margin',
    'No hangers — just the item',
  ];

  @override
  void initState() {
    super.initState();
    _tipTimer = Timer.periodic(
      const Duration(milliseconds: 2400),
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
              ? 'Permission denied. Open Settings → Drapeai → enable Camera & Photos.'
              : 'Could not open ${source == ImageSource.camera ? "camera" : "gallery"}: $msg',
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
        onRetake: () {
          Navigator.pop(context);
        },
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
      final result = await api.uploadItem(path);
      if (mounted) {
        context.pushNamed('tag_review', extra: result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'),
              backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0D0C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Simulated camera preview gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 0.7,
                colors: [Color(0xFF2A2724), Color(0xFF0E0D0C)],
              ),
            ),
          ),
          // Scanline overlay
          Opacity(
            opacity: 0.06,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.white10],
                  stops: [0, 1],
                ),
              ),
            ),
          ),
          // Dashed frame
          const _DashedFrame(),
          // Faint silhouette hint
          Center(
            child: Opacity(
              opacity: 0.12,
              child: Icon(Icons.checkroom_rounded, size: 100,
                  color: Colors.white),
            ),
          ),
          // Top controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 16, right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 20,
                        color: Colors.white),
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _showGuide = true),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline, size: 18,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flash_on, size: 18,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Rotating tip
          Positioned(
            bottom: 140, left: 0, right: 0,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(_tipIndex),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_tips[_tipIndex],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Upload processing overlay
          if (_uploading)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.orange),
                    const SizedBox(height: 16),
                    Text('Processing your item...',
                        style: TextStyle(color: Colors.white, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Removing background and tagging',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          // Bottom controls
          Positioned(
            bottom: 36, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gallery
                GestureDetector(
                  onTap: _uploading
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_outlined,
                        size: 22, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 28),
                // Shutter
                GestureDetector(
                  onTap: _uploading
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 28),
                // Spacer to balance gallery button
                const SizedBox(width: 44),
              ],
            ),
          ),
          // Photo guide overlay
          if (_showGuide)
            PhotoGuideOverlay(
              onDismiss: () => setState(() => _showGuide = false),
            ),
        ],
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
          40,
          MediaQuery.of(context).padding.top + 80,
          40,
          220,
        ),
        child: CustomPaint(painter: _DashedBorderPainter()),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 10.0;
    const gap = 6.0;
    const radius = 20.0;
    const sw = 1.5;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(sw / 2, sw / 2, size.width - sw, size.height - sw),
      const Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
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
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sheet handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          // Quality indicator
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.limeSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 20,
                    color: Color(0xFF4D7C0F)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Looks good',
                      style: AppTypography.label.copyWith(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Sharp, well-lit, plain background.',
                      style: AppTypography.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: onRetake,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retake'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onUse,
                    child: const Text('Use this photo'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
