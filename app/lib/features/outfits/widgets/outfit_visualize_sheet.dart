import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/environment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';
import '../../try_on/services/try_on_photo_actions.dart';
import '../../try_on/widgets/try_on_refine_composer.dart';
import '../models/outfit_model.dart';

/// Full-screen sheet that generates and shows "see me in this outfit" preview.
class OutfitVisualizeSheet extends ConsumerStatefulWidget {
  final Outfit outfit;
  const OutfitVisualizeSheet({required this.outfit, super.key});

  @override
  ConsumerState<OutfitVisualizeSheet> createState() =>
      _OutfitVisualizeSheetState();
}

class _OutfitVisualizeSheetState extends ConsumerState<OutfitVisualizeSheet> {
  String? _previewUrl;
  bool _loading = false;
  String? _error;
  String? _method;
  String? _model;
  String? _statusMessage;
  int? _limit;
  int? _remaining;
  final _refineController = TextEditingController();

  @override
  void dispose() {
    _refineController.dispose();
    super.dispose();
  }

  void _captureUsage(Map<String, dynamic> data) {
    final limit = data['limit'];
    final remaining = data['remaining'];
    if (limit is int) _limit = limit;
    if (remaining is int) _remaining = remaining;
  }

  @override
  void initState() {
    super.initState();
    if (widget.outfit.previewUrl != null) {
      _previewUrl = widget.outfit.previewUrl;
    } else {
      _generate(force: false);
    }
  }

  Future<void> _generate({required bool force}) async {
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = 'Styling you… ~15s';
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.visualizeOutfit(widget.outfit.id, force: force);
      if (!mounted) return;
      _captureUsage(data);

      final status = data['status'] as String?;
      final jobId = data['job_id'] as String?;
      if (jobId != null &&
          status != null &&
          status != 'completed' &&
          status != 'failed') {
        await _pollJob(api, jobId);
        return;
      }

      _applyResult(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _mapError(e);
      });
    }
  }

  Future<void> _pollJob(ApiClient api, String jobId) async {
    // Match Avatar Studio (~4 min): refine/HD Vertex can exceed 90s.
    const maxAttempts = 120;
    for (var i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() {
        _statusMessage = i < 5
            ? 'Styling you… ~15s'
            : 'Still generating… hang tight';
      });
      try {
        final data = await api.visualizeOutfitStatus(
          widget.outfit.id,
          jobId: jobId,
        );
        _captureUsage(data);
        final status = data['status'] as String? ?? '';
        if (status == 'completed') {
          _applyResult(data);
          return;
        }
        if (status == 'failed') {
          setState(() {
            _loading = false;
            _error = (data['error'] as String?) ?? 'Try-on failed. Please retry.';
          });
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = _mapError(e);
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = 'Taking longer than expected. Pull to regenerate in a moment.';
    });
  }

  void _applyResult(Map<String, dynamic> data) {
    _captureUsage(data);
    setState(() {
      _previewUrl = data['preview_url'] as String?;
      _method = data['method'] as String?;
      _model = data['model'] as String?;
      _loading = false;
      _statusMessage = null;
      if (_previewUrl == null) {
        _error = (data['error'] as String?) ?? 'No preview returned';
      }
    });
  }

  Future<void> _refine() async {
    final message = _refineController.text.trim();
    if (message.isEmpty || _loading || _previewUrl == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = 'Refining look…';
    });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.refineVisualize(widget.outfit.id, message);
      if (!mounted) return;
      _captureUsage(data);

      final status = data['status'] as String?;
      final jobId = data['job_id'] as String?;
      if (jobId != null &&
          status != null &&
          status != 'completed' &&
          status != 'failed') {
        await _pollJob(api, jobId);
        if (mounted && _error == null) {
          _refineController.clear();
        }
        return;
      }

      _applyResult(data);
      if (_error == null) {
        _refineController.clear();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _mapError(e);
      });
    }
  }

  String _mapError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final detail = e.response?.data;
      if (status == 429) {
        final d = detail is Map ? detail['detail'] : null;
        if (d is Map) {
          if (d['limit'] is int) _limit = d['limit'] as int;
          if (d['remaining'] is int) _remaining = d['remaining'] as int;
        }
        return 'daily_limit';
      }
      if (status == 409) {
        final msg = detail is Map
            ? (detail['detail']?.toString() ?? '')
            : detail?.toString() ?? '';
        if (msg.isNotEmpty) return msg;
        return 'A try-on is already in progress. Wait a moment, then try again.';
      }
      if (status == 400) {
        final msg = detail is Map
            ? (detail['detail']?.toString() ?? '')
            : detail?.toString() ?? '';
        if (msg.toLowerCase().contains('full-body')) {
          return 'add_your_photo';
        }
      }
      if (detail is Map && detail['detail'] != null) {
        final d = detail['detail'];
        if (d is Map && d['message'] != null) {
          return d['message'].toString();
        }
        return d.toString();
      }
    }
    final msg = e.toString();
    if (msg.contains('full-body photo') || msg.contains('400')) {
      return 'add_your_photo';
    }
    if (msg.contains('429') || msg.contains('Daily try-on')) {
      return 'daily_limit';
    }
    return msg;
  }

  String _methodLabel(String method, String? model) {
    if (method == 'composite') return 'Quick composite preview';
    if (method == 'cached') return 'Saved preview';
    if (method.startsWith('ai:')) {
      final parts = method.split(':');
      final provider = parts.length > 1 ? parts[1] : method;
      final refined = parts.length > 2 && parts[2] == 'refine';
      final name = switch (provider) {
        'cloudflare' => 'AI preview',
        'openai' => 'OpenAI',
        'gemini' => 'Gemini',
        'vertex' => 'Vertex AI',
        'nvidia' => 'NVIDIA',
        'runpod' => 'RunPod',
        _ => provider,
      };
      final base = refined ? '$name refine' : name;
      if (provider == 'cloudflare' && !refined) return name;
      return model != null ? '$base · $model' : base;
    }
    return method;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? AppColorsDark.bg : AppColors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (_) => AppGradients.hero
                            .createShader(const Rect.fromLTWH(0, 0, 280, 32)),
                        child: Text(
                          'See me in this fit',
                          style: AppTypography.headingSerif.copyWith(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        'your wardrobe · your photo',
                        style: AppTypography.caption,
                      ),
                      if (_limit != null && _remaining != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$_remaining of $_limit try-ons left today',
                          style: AppTypography.caption.copyWith(
                            color: _remaining! <= 1
                                ? AppColors.orange
                                : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_method != null && _method != 'cached') ...[
                        const SizedBox(height: 4),
                        Text(
                          _methodLabel(_method!, _model),
                          style: AppTypography.mono.copyWith(
                            fontSize: 10,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(context),
          ),
          if (_previewUrl != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TryOnRefineComposer(
                    controller: _refineController,
                    enabled: !_loading,
                    onSubmit: _refine,
                    onDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _loading ? null : () => _generate(force: true),
                    child: Text(
                      'Regenerate from photo',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _previewUrl == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.orange),
            const SizedBox(height: 16),
            Text(_statusMessage ?? 'Creating your look…'),
          ],
        ),
      );
    }

    if (_error == 'add_your_photo') {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: DrapeGlassCard(
          gradientBorder: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 48, color: AppColors.orange),
              const SizedBox(height: 12),
              Text(
                'Add a full-body photo first',
                style: AppTypography.headingSerif.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We use your photo to show AI previews of outfits from your own wardrobe.',
                style: AppTypography.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              DrapeGradientButton(
                label: 'Add photo here',
                onPressed: () async {
                  final ok = await uploadTryOnPhotoInPlace(ref, context);
                  if (ok && mounted) {
                    setState(() => _error = null);
                    await _generate(force: false);
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_error == 'daily_limit') {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: DrapeGlassCard(
          gradientBorder: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Come back tomorrow',
                style: AppTypography.headingSerif.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _limit != null
                    ? 'You\'ve used all $_limit try-ons for today. Cached looks still open instantly.'
                    : 'You\'ve used today\'s try-on previews. Cached looks still open instantly.',
                style: AppTypography.body,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: AppTypography.body, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              DrapeGradientButton(
                label: 'Try again',
                onPressed: () => _generate(force: true),
              ),
            ],
          ),
        ),
      );
    }

    if (_previewUrl == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: Environment.resolveUrl(_previewUrl!),
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.gray100),
            ),
          ),
        ),
        if (_loading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            ),
          ),
      ],
    );
  }
}

/// Opens the visualize sheet for an outfit.
void showOutfitVisualizeSheet(BuildContext context, Outfit outfit) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => OutfitVisualizeSheet(outfit: outfit),
  );
}
