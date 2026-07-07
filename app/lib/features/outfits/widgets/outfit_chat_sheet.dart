import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/environment.dart';
import '../../wardrobe/models/item_model.dart';
import '../models/outfit_model.dart';

class OutfitChatSheet extends ConsumerStatefulWidget {
  final Outfit outfit;
  final ValueChanged<Outfit>? onUpdated;

  const OutfitChatSheet({required this.outfit, this.onUpdated, super.key});

  @override
  ConsumerState<OutfitChatSheet> createState() => _OutfitChatSheetState();
}

class _OutfitChatSheetState extends ConsumerState<OutfitChatSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  final List<_ChatMessage> _messages = [];

  static const _suggestions = [
    'Make it more formal',
    'Try darker colors',
    'Swap the top',
    'More casual please',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send([String? prefilled]) async {
    final msg = (prefilled ?? _controller.text).trim();
    if (msg.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: msg));
      _loading = true;
      _controller.clear();
    });

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.refineOutfit(widget.outfit.id, msg);
      final reason = (result['reason'] as String?)?.trim() ?? '';
      final swaps = (result['swaps'] as List?) ?? [];
      setState(() {
        _messages.add(_ChatMessage(
          role: 'ai',
          text: reason.isEmpty
              ? (swaps.isEmpty
                  ? 'Kept the outfit as is.'
                  : 'Made ${swaps.length} swap${swaps.length == 1 ? '' : 's'}.')
              : reason,
          imageUrls: (result['items'] as List?)
              ?.map((it) => (it as Map)['image_url'] as String? ?? '')
              .where((u) => u.isNotEmpty)
              .toList(),
        ));
      });

      // Notify parent if items changed
      if (swaps.isNotEmpty && widget.onUpdated != null) {
        final items = (result['items'] as List?)
                ?.map((j) => Item.fromJson(j as Map<String, dynamic>))
                .toList() ??
            widget.outfit.items;
        widget.onUpdated!(widget.outfit.copyWith(
          items: items,
          reason: reason.isNotEmpty ? reason : widget.outfit.reason,
        ));
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          role: 'ai',
          text: 'Sorry, that didn\'t work: ${e.toString().split(':').first}',
          error: true,
        ));
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text('Style chat',
                      style: GoogleFonts.instrumentSerif(
                          fontSize: 22, color: AppColors.ink)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Tell me how to tweak this outfit. I\'ll swap items from your wardrobe.',
                    style: AppTypography.caption),
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _suggestions.map((s) {
                          return GestureDetector(
                            onTap: () => _send(s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(s,
                                  style: AppTypography.label
                                      .copyWith(fontSize: 13)),
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 6),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i == _messages.length) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text('…thinking',
                                  style: AppTypography.caption),
                            ),
                          );
                        }
                        final m = _messages[i];
                        return _BubbleView(message: m);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'e.g. "make it more formal"',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.orange),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _loading ? null : () => _send(),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _loading
                            ? AppColors.ink3
                            : AppColors.ink,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.arrow_upward,
                          size: 20, color: Colors.white),
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
}

class _ChatMessage {
  final String role; // 'user' | 'ai'
  final String text;
  final bool error;
  final List<String>? imageUrls;

  _ChatMessage({
    required this.role,
    required this.text,
    this.error = false,
    this.imageUrls,
  });
}

class _BubbleView extends StatelessWidget {
  final _ChatMessage message;
  const _BubbleView({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.ink
                    : (message.error ? AppColors.red50 : AppColors.card),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                message.text,
                style: AppTypography.body.copyWith(
                  color: isUser ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
          if (message.imageUrls != null && message.imageUrls!.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: message.imageUrls!.take(4).map((u) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: Environment.resolveUrl(u),
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppColors.gray100),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.gray100,
                          child: const Icon(Icons.broken_image_outlined,
                              size: 16, color: AppColors.gray400),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
