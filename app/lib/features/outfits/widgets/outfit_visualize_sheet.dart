import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/environment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';
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
    });
    try {
      final data = await ref
          .read(apiClientProvider)
          .visualizeOutfit(widget.outfit.id, force: force);
      if (mounted) {
        setState(() {
          _previewUrl = data['preview_url'] as String?;
          _method = data['method'] as String?;
          _model = data['model'] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        setState(() {
          _loading = false;
          if (msg.contains('full-body photo') || msg.contains('400')) {
            _error = 'add_your_photo';
          } else {
            _error = msg;
          }
        });
      }
    }
  }

  String _methodLabel(String method, String? model) {
    if (method == 'composite') return 'Pillow composite preview';
    if (method.startsWith('ai:')) {
      final provider = method.split(':').last;
      final name = switch (provider) {
        'openai' => 'OpenAI',
        'gemini' => 'Gemini',
        'nvidia' => 'NVIDIA',
        _ => provider,
      };
      return model != null ? '$name · $model' : name;
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: DrapeGradientButton(
                label: 'Regenerate',
                onPressed: _loading ? null : () => _generate(force: true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _previewUrl == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.orange),
            SizedBox(height: 16),
            Text('Creating your look…'),
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
              const Text('📸', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'Add a full-body photo first',
                style: AppTypography.headingSerif.copyWith(fontSize: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We use your photo to show outfits from your own wardrobe — not shopping links.',
                style: AppTypography.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              DrapeGradientButton(
                label: 'Go to Profile',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/profile');
                },
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
          child: Text(_error!, style: AppTypography.body, textAlign: TextAlign.center),
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
