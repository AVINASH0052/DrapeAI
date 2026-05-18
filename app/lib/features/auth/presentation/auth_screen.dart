import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/auth_provider.dart';

enum _AuthView { login, phone, otp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthView _view = _AuthView.login;
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  String? _verificationId;
  String _countryCode = '+91';
  bool _loading = false;
  int _resendTimer = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _otp => _otpControllers.map((c) => c.text).join();
  String get _fullPhone => '$_countryCode ${_phoneController.text.trim()}';

  void _startResendTimer() {
    _resendTimer = 28;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendTimer--;
        if (_resendTimer <= 0) t.cancel();
      });
    });
  }

  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final phone = '$_countryCode${_phoneController.text.trim()}';
      _verificationId = await repo.sendOtp(phone);
      _startResendTimer();
      if (mounted) setState(() => _view = _AuthView.otp);
    } catch (e) {
      if (mounted) _showError('Failed to send OTP: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.verifyOtp(_verificationId!, _otp);
      await ref.read(authStatusProvider.notifier).onLoginSuccess();
    } catch (e) {
      if (mounted) _showError('Invalid OTP');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithGoogle();
      await ref.read(authStatusProvider.notifier).onLoginSuccess();
    } catch (e) {
      if (mounted) _showError('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (_view) {
            _AuthView.login => _buildLogin(),
            _AuthView.phone => _buildPhone(),
            _AuthView.otp => _buildOtp(),
          },
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return Padding(
      key: const ValueKey('login'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          _Wordmark(),
          const Spacer(),
          Text(
            'Welcome to drape.',
            style: AppTypography.displaySerif.copyWith(fontSize: 38),
          ),
          const SizedBox(height: 6),
          Text(
            'AI styling, made for your wardrobe — wherever you are.',
            style: AppTypography.body,
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: _loading ? null : _googleSignIn,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _GoogleLogo(),
                const SizedBox(width: 10),
                Text('Continue with Google',
                    style: AppTypography.button.copyWith(color: AppColors.ink)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _loading
                ? null
                : () => setState(() => _view = _AuthView.phone),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_outlined, size: 18),
                const SizedBox(width: 10),
                Text('Continue with Phone',
                    style: AppTypography.button
                        .copyWith(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: () {
                ref.read(authStatusProvider.notifier).devBypass();
              },
              child: Text('Skip for now (dev)',
                  style: AppTypography.button
                      .copyWith(color: AppColors.ink3)),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text.rich(
              TextSpan(
                style: AppTypography.caption.copyWith(height: 1.5),
                children: [
                  const TextSpan(text: 'By continuing you agree to our '),
                  TextSpan(
                    text: 'Terms',
                    style: const TextStyle(
                        decoration: TextDecoration.underline),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                        decoration: TextDecoration.underline),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPhone() {
    final ready = _phoneController.text.replaceAll(RegExp(r'\D'), '').length >= 8;
    return Padding(
      key: const ValueKey('phone'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _BackButton(onTap: () => setState(() => _view = _AuthView.login)),
          const SizedBox(height: 24),
          Text('Enter your phone',
              style: AppTypography.headingSerif.copyWith(fontSize: 26)),
          const SizedBox(height: 6),
          Text("We'll text you a 6-digit code to verify.",
              style: AppTypography.body),
          const SizedBox(height: 28),
          Row(
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.borderStrong),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _countryCode,
                    items: const [
                      DropdownMenuItem(value: '+91', child: Text('🇮🇳 +91')),
                      DropdownMenuItem(value: '+1', child: Text('🇺🇸 +1')),
                      DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                      DropdownMenuItem(value: '+971', child: Text('🇦🇪 +971')),
                      DropdownMenuItem(value: '+65', child: Text('🇸🇬 +65')),
                    ],
                    onChanged: (v) => setState(() => _countryCode = v!),
                    style: AppTypography.label.copyWith(
                        color: AppColors.ink, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '98765 43210',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _loading || !ready ? null : _sendOtp,
            child: _loading
                ? const _Spinner()
                : const Text('Send code'),
          ),
          const Spacer(),
          Center(
            child: Text("We never share your number.",
                style: AppTypography.caption),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOtp() {
    final filled = _otp.length == 6;
    return Padding(
      key: const ValueKey('otp'),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _BackButton(
              onTap: () => setState(() {
                    _view = _AuthView.phone;
                    for (final c in _otpControllers) c.clear();
                  })),
          const SizedBox(height: 24),
          Text('Verify your number',
              style: AppTypography.headingSerif.copyWith(fontSize: 26)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: AppTypography.body,
              children: [
                const TextSpan(text: 'We sent a code to '),
                TextSpan(
                  text: _fullPhone,
                  style: TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w500),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return _OtpCell(
                controller: _otpControllers[i],
                focusNode: _otpFocusNodes[i],
                onFilled: () {
                  if (i < 5) {
                    _otpFocusNodes[i + 1].requestFocus();
                  } else {
                    _otpFocusNodes[i].unfocus();
                  }
                  setState(() {});
                  if (_otp.length == 6) _verifyOtp();
                },
                onBackspace: () {
                  if (i > 0) _otpFocusNodes[i - 1].requestFocus();
                },
              );
            }),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading || !filled ? null : _verifyOtp,
            child: _loading ? const _Spinner() : const Text('Verify'),
          ),
          const SizedBox(height: 16),
          Center(
            child: _resendTimer > 0
                ? Text(
                    'Resend code in 0:${_resendTimer.toString().padLeft(2, '0')}',
                    style: AppTypography.mono,
                  )
                : GestureDetector(
                    onTap: _sendOtp,
                    child: Text(
                      'Resend code',
                      style: AppTypography.label
                          .copyWith(color: AppColors.orange),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'drape',
          style: GoogleFonts.instrumentSerif(
            fontSize: 36,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          '.',
          style: GoogleFonts.instrumentSerif(
            fontSize: 36,
            fontWeight: FontWeight.w400,
            color: AppColors.orange,
          ),
        ),
        Text(
          'ai',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.arrow_back, size: 20, color: AppColors.ink),
      ),
    );
  }
}

class _OtpCell extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onFilled;
  final VoidCallback onBackspace;

  const _OtpCell({
    required this.controller,
    required this.focusNode,
    required this.onFilled,
    required this.onBackspace,
  });

  @override
  State<_OtpCell> createState() => _OtpCellState();
}

class _OtpCellState extends State<_OtpCell> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  void _onFocus() => setState(() => _focused = widget.focusNode.hasFocus);

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 50,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(
          color: _focused
              ? AppColors.orange
              : AppColors.borderStrong,
          width: _focused ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _focused
            ? [BoxShadow(color: AppColors.orangeSoft, blurRadius: 6)]
            : null,
      ),
      child: Center(
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          maxLength: 1,
          keyboardType: TextInputType.number,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
          onChanged: (v) {
            if (v.isNotEmpty) {
              widget.onFilled();
            } else {
              widget.onBackspace();
            }
          },
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const pi = 3.14159265358979;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const sw = 3.8;
    final rect = Rect.fromCircle(center: center, radius: radius - sw / 2);
    Paint seg(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;

    canvas.drawArc(rect, -pi / 2, pi * 7 / 6, false,
        seg(const Color(0xFF4285F4)));
    canvas.drawArc(
        rect, pi * 2 / 3, pi / 3, false, seg(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, pi, pi / 3, false, seg(const Color(0xFF34A853)));
    canvas.drawArc(
        rect, pi * 4 / 3, pi / 2, false, seg(const Color(0xFFEA4335)));
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width - sw / 2, center.dy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = sw * 0.85
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
