import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../../try_on/services/try_on_photo_actions.dart';

class BodySetupScreen extends ConsumerStatefulWidget {
  const BodySetupScreen({super.key});

  @override
  ConsumerState<BodySetupScreen> createState() => _BodySetupScreenState();
}

class _BodySetupScreenState extends ConsumerState<BodySetupScreen> {
  Timer? _timer;
  String _status = 'missing';
  String? _error;
  bool _uploading = false;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    final uploaded = await uploadTryOnPhotoInPlace(
      ref,
      context,
      forceGuide: true,
      source: source,
    );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (uploaded) _status = 'queued';
    });
    if (uploaded) _startPolling();
  }

  Future<void> _refreshStatus() async {
    if (_polling) return;
    _polling = true;
    try {
      final data = await ref.read(apiClientProvider).getAvatarProfile();
      if (!mounted) return;
      final status = data['status'] as String? ?? 'missing';
      setState(() {
        _status = status;
        _error = data['error'] as String?;
      });
      if (status == 'ready') {
        _timer?.cancel();
        final wasBodyGate =
            ref.read(authStatusProvider) == AuthStatus.bodySetupNeeded;
        ref.invalidate(userProfileProvider);
        ref.read(authStatusProvider.notifier).setAuthenticated();
        if (wasBodyGate && mounted) context.go('/studio');
      } else if (status == 'queued' || status == 'processing') {
        _startPolling();
      }
    } on DioException catch (error) {
      if (mounted && error.response?.statusCode != 404) {
        setState(() => _error = 'Could not check avatar progress.');
      }
    } finally {
      _polling = false;
    }
  }

  void _startPolling() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshStatus(),
    );
    _refreshStatus();
  }

  bool get _isPreparing =>
      _uploading || _status == 'queued' || _status == 'processing';

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMuted(context);
    final isRequired =
        ref.watch(authStatusProvider) == AuthStatus.bodySetupNeeded;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (!isRequired) ...[
                    IconButton(
                      tooltip: 'Back to studio',
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      'Start with you',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 30,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Add one clear, head-to-toe photo. It becomes your private '
                '2.5D dressing-room base.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  height: 1.5,
                  color: muted,
                ),
              ),
              const SizedBox(height: 26),
              Container(
                height: 330,
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColorsDark.border
                        : AppColors.border,
                  ),
                ),
                child: _isPreparing
                    ? _PreparingState(status: _status)
                    : const _BodyGuideGraphic(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Take photo',
                      onPressed:
                          _isPreparing ? null : () => _pick(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Choose photo',
                      onPressed: _isPreparing
                          ? null
                          : () => _pick(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 17, color: muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your source photo is used only for your avatar and '
                      'try-on renders. You can replace or delete it anytime.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        height: 1.45,
                        color: muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        backgroundColor: AppColors.orange,
        disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _PreparingState extends StatelessWidget {
  const _PreparingState({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(34),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            status == 'processing' ? 'Preparing your avatar' : 'Photo uploaded',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We are checking visibility and removing the background. '
            'You can close the app and return.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyGuideGraphic extends StatelessWidget {
  const _BodyGuideGraphic();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 158,
          height: 272,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(80),
            border: Border.all(
              color: AppColors.orange.withValues(alpha: 0.45),
              width: 2,
            ),
          ),
        ),
        Icon(
          Icons.accessibility_new_rounded,
          size: 180,
          color: AppColors.orange.withValues(alpha: 0.7),
        ),
        Positioned(
          bottom: 18,
          child: Text(
            'Face forward  •  Full body  •  Good light',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted(context),
            ),
          ),
        ),
      ],
    );
  }
}
