import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/environment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';
import '../../profile/providers/user_profile_provider.dart';
import '../services/try_on_photo_actions.dart';

/// Pick a shop/screenshot outfit photo and try it on the saved body photo.
class TryOnHomeScreen extends ConsumerStatefulWidget {
  const TryOnHomeScreen({super.key});

  @override
  ConsumerState<TryOnHomeScreen> createState() => _TryOnHomeScreenState();
}

class _TryOnHomeScreenState extends ConsumerState<TryOnHomeScreen> {
  String? _localPath;
  bool _busy = false;
  String? _resultUrl;
  String? _error;
  String? _method;

  Future<void> _pickGarment() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 92,
    );
    if (picked == null) return;
    setState(() {
      _localPath = picked.path;
      _resultUrl = null;
      _error = null;
      _method = null;
    });
  }

  Future<void> _ensureBodyPhoto() async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile?.tryOnPhotoUrl != null) return;
    setState(() => _busy = true);
    try {
      await uploadTryOnPhotoInPlace(ref, context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runTryOn() async {
    final path = _localPath;
    if (path == null) return;

    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile?.tryOnPhotoUrl == null) {
      await _ensureBodyPhoto();
      final again = ref.read(userProfileProvider).valueOrNull;
      if (again?.tryOnPhotoUrl == null) return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _resultUrl = null;
    });
    try {
      final resp = await ref.read(apiClientProvider).externalTryOn(path);
      final status = resp['status'] as String?;
      if (status == 'completed') {
        setState(() {
          _resultUrl = resp['result_url'] as String?;
          _method = resp['method'] as String?;
        });
      } else if (status == 'queued' || status == 'processing') {
        final sessionId = resp['session_id'] as String?;
        if (sessionId == null) {
          throw Exception('No session id returned');
        }
        await _poll(sessionId);
      } else {
        setState(() {
          _error = (resp['error'] as String?) ?? 'Try-on failed';
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll(String sessionId) async {
    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final st = await ref.read(apiClientProvider).externalTryOnStatus(sessionId);
      final status = st['status'] as String?;
      if (status == 'completed') {
        setState(() {
          _resultUrl = st['result_url'] as String?;
          _method = st['method'] as String?;
        });
        return;
      }
      if (status == 'failed') {
        setState(() {
          _error = (st['error'] as String?) ?? 'Try-on failed';
        });
        return;
      }
    }
    setState(() => _error = 'Timed out waiting for try-on');
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop photo try-on'),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () => context.push('/fitting-room/history'),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'Uses your saved full-body photo. Upload a shop screenshot or catalog shot.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: 16),
          profile.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (p) => p.tryOnPhotoUrl == null
                ? DrapeGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No body photo yet', style: AppTypography.title),
                        const SizedBox(height: 8),
                        Text(
                          'Add one here — you stay in this flow.',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 12),
                        DrapeGradientButton(
                          label: _busy ? 'Uploading…' : 'Add full-body photo',
                          onPressed: _busy ? null : _ensureBodyPhoto,
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: Environment.resolveUrl(p.tryOnPhotoUrl!),
                          width: 72,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your saved body photo will be dressed automatically.',
                          style: AppTypography.label,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          DrapeGlassCard(
            onTap: _busy ? null : _pickGarment,
            child: _localPath == null
                ? Column(
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined, size: 40),
                      const SizedBox(height: 8),
                      Text('Pick outfit / garment photo', style: AppTypography.label),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_localPath!),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          DrapeGradientButton(
            label: _busy ? 'Styling you…' : 'See me in this',
            onPressed: (_busy || _localPath == null) ? null : _runTryOn,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(color: AppColors.orange),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: AppTypography.caption.copyWith(color: AppColors.red)),
          ],
          if (_resultUrl != null) ...[
            const SizedBox(height: 20),
            Text(
              _method == null ? 'Result' : 'Result ($_method)',
              style: AppTypography.title.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: Environment.resolveUrl(_resultUrl!),
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
