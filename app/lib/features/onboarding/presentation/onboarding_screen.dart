import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 1;
  bool _saving = false;

  // Identity
  final _nameController = TextEditingController();
  int _age = 25;

  // Style profile (existing)
  String? _gender;
  List<String> _styles = [];
  List<String> _occasions = [];
  List<String> _colors = [];
  String? _fit;
  String? _city;
  String? _climate;

  // Optional final step
  String? _bodyType;
  String? _skinUndertone;
  int? _heightCm;
  String? _budgetTier;
  final Set<String> _lifestyle = {};

  static const _totalSteps = 9;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canProceed => switch (_step) {
        1 => _nameController.text.trim().isNotEmpty,
        2 => _age >= 13 && _age <= 99,
        3 => _gender != null,
        4 => _styles.isNotEmpty,
        5 => _occasions.isNotEmpty,
        6 => _colors.isNotEmpty,
        7 => _fit != null,
        8 => _city != null,
        9 => true, // optional — can always proceed
        _ => false,
      };

  void _next() {
    if (_step < _totalSteps) {
      setState(() => _step++);
    } else {
      _save();
    }
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.savePreferences({
        'name': _nameController.text.trim(),
        'age': _age,
        'gender': _gender,
        'style_goals': _styles,
        'occasions': _occasions,
        'color_preferences': _colors,
        'fit_preference': _fit,
        'location_city': _city,
        'climate': _climate,
        'body_type': _bodyType,
        'skin_undertone': _skinUndertone,
        'height_cm': _heightCm,
        'budget_tier': _budgetTier,
        'lifestyle': _lifestyle.toList(),
      });
      if (mounted) {
        setState(() => _step = 0);
        ref.read(authStatusProvider.notifier).setAuthenticated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'),
              backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) return _buildCompletion();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ProgressBar(value: _step / _totalSteps),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _CircleBackButton(onTap: _back),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_headings[_step - 1],
                    style: AppTypography.displaySerif.copyWith(fontSize: 30)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_subtitles[_step - 1], style: AppTypography.body),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: _buildStep(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: ElevatedButton(
                onPressed: _canProceed && !_saving ? _next : null,
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_step == _totalSteps ? 'Finish' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _headings = [
    'What should we call you?',
    'How old are you?',
    'Who are we styling?',
    'What’s your style?',
    'What do you dress for?',
    'Your go-to colors?',
    'How do you like the fit?',
    'Where are you based?',
    'Tell us more — optional',
  ];

  static const _subtitles = [
    'Your name helps us personalize suggestions.',
    'We tune trend and formality to your age.',
    'Pick one — we’ll tailor the closet to you.',
    'Pick up to 3 that match you.',
    'Multi-select — these power your daily outfits.',
    'Tones you reach for again and again.',
    'Pick one — you can change it later.',
    'We use this for weather + occasion calls.',
    'All optional. Skip what you’d rather not share.',
  ];

  Widget _buildStep() {
    return switch (_step) {
      1 => _buildName(),
      2 => _buildAge(),
      3 => _buildGender(),
      4 => _buildStyle(),
      5 => _buildOccasions(),
      6 => _buildColors(),
      7 => _buildFit(),
      8 => _buildCity(),
      9 => _buildOptional(),
      _ => const SizedBox.shrink(),
    };
  }

  // Step 1: Name
  Widget _buildName() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: GoogleFonts.instrumentSerif(fontSize: 28, color: AppColors.ink),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          hintText: 'Your first name',
        ),
      ),
    );
  }

  // Step 2: Age
  Widget _buildAge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text('$_age',
              style: GoogleFonts.instrumentSerif(
                  fontSize: 72, color: AppColors.ink, height: 1)),
          Text('years', style: AppTypography.caption),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.orange,
              inactiveTrackColor: const Color(0xFFECEAE4),
              thumbColor: AppColors.orange,
              overlayColor: AppColors.orangeSoft,
            ),
            child: Slider(
              min: 13, max: 99, divisions: 86,
              value: _age.toDouble(),
              onChanged: (v) => setState(() => _age = v.round()),
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Gender
  Widget _buildGender() {
    const items = [
      ('w', 'Women', 'Dresses, skirts, more', Icons.female, AppColors.pinkSoft),
      ('m', 'Men', 'Shirts, jeans, more', Icons.male, AppColors.bgWarm),
      ('all', 'Both', 'Mix it up', Icons.all_inclusive, AppColors.lavenderSoft),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: items.map((item) {
          final (key, name, hint, icon, bg) = item;
          final selected = _gender == key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SelectionCard(
              selected: selected,
              onTap: () => setState(() => _gender = key),
              child: Row(
                children: [
                  Container(
                    width: 64, height: 76,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 32, color: AppColors.ink2),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.instrumentSerif(
                          fontSize: 22, color: AppColors.ink)),
                        const SizedBox(height: 4),
                        Text(hint, style: AppTypography.caption),
                      ],
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 28, height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Step 2: Style
  Widget _buildStyle() {
    const items = [
      ('min', 'Minimalist', 'clean lines',
          [Color(0xFFF5F4F0), Color(0xFFE7E5E0)], Icons.straighten),
      ('street', 'Streetwear', 'bold & loose',
          [Color(0xFF1A1A1A), Color(0xFF3D3D3D)], Icons.style),
      ('class', 'Classic', 'timeless',
          [Color(0xFF1E3A5F), Color(0xFFD6CFC2)], Icons.checkroom),
      ('ethnic', 'Ethnic', 'rooted',
          [Color(0xFFA6532A), Color(0xFFFFF1E6)], Icons.auto_awesome),
      ('boho', 'Bohemian', 'relaxed',
          [Color(0xFF6B7A4F), Color(0xFFF3D5DD)], Icons.eco),
      ('sport', 'Sporty', 'on the move',
          [Color(0xFF2049A6), Color(0xFFE8F4FD)], Icons.directions_run),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
        children: items.map((item) {
          final (key, name, hint, colors, icon) = item;
          final isActive = _styles.contains(key);
          return GestureDetector(
            onTap: () => setState(() {
              if (_styles.contains(key)) {
                _styles.remove(key);
              } else if (_styles.length < 3) {
                _styles.add(key);
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isActive ? AppColors.orangeSoft : AppColors.card,
                border: Border.all(
                  color: isActive ? AppColors.orange : AppColors.border,
                  width: isActive ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(17)),
                      ),
                      child: Center(
                        child: Icon(icon, size: 36,
                            color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppTypography.label.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink)),
                        Text(hint,
                            style: AppTypography.caption
                                .copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Step 3: Occasions
  Widget _buildOccasions() {
    const items = [
      ('casual', 'Casual', Icons.weekend, Color(0xFFF5F4F0)),
      ('work', 'Work', Icons.business_center, Color(0xFFE8F4FD)),
      ('party', 'Party', Icons.celebration, Color(0xFFFCE7F3)),
      ('gym', 'Gym', Icons.fitness_center, Color(0xFFECFCCB)),
      ('date', 'Date', Icons.favorite, Color(0xFFFEF2F2)),
      ('festive', 'Festive', Icons.auto_awesome, Color(0xFFFFF1E6)),
      ('travel', 'Travel', Icons.flight, Color(0xFFEDE9FE)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: items.map((item) {
          final (key, name, icon, bg) = item;
          final isActive = _occasions.contains(key);
          return GestureDetector(
            onTap: () => setState(() {
              if (_occasions.contains(key)) {
                _occasions.remove(key);
              } else {
                _occasions.add(key);
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isActive ? AppColors.orangeSoft : AppColors.card,
                border: Border.all(
                  color: isActive ? AppColors.orange : AppColors.border,
                  width: isActive ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.orangeSoft : bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 26,
                        color: isActive ? AppColors.orange : AppColors.ink2),
                  ),
                  const SizedBox(height: 10),
                  Text(name,
                      style: AppTypography.label.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Step 4: Colors
  Widget _buildColors() {
    const items = [
      ('neutral', 'Neutrals', [Color(0xFFD6CFC2), Color(0xFF9C9486)],
          'Beige chinos + cream tee'),
      ('earth', 'Earth', [Color(0xFF7A4A2A), Color(0xFFA6532A)],
          'Olive jacket + rust pants'),
      ('pastel', 'Pastels', [Color(0xFFF3D5DD), Color(0xFFD9CCE6)],
          'Mint shirt + lilac jeans'),
      ('bold', 'Bold', [Color(0xFFC81E3A), Color(0xFF2049A6)],
          'Red blazer + navy jeans'),
      ('mono', 'Mono', [Color(0xFF0B0B0B), Color(0xFFF4F2EC)],
          'Black tee + white sneakers'),
      ('jewel', 'Jewel', [Color(0xFF066E5C), Color(0xFF7E1A35)],
          'Emerald top + burgundy skirt'),
      ('pastel_sage', 'Sage & Sky',
          [Color(0xFFB8CFB0), Color(0xFFBCD4E6)],
          'Sage shirt + sky blue pants'),
      ('warm_sunset', 'Sunset',
          [Color(0xFFE8825B), Color(0xFFE9C46A)],
          'Terracotta + mustard tones'),
      ('cool_ocean', 'Ocean',
          [Color(0xFF1E5F8C), Color(0xFF06A77D)],
          'Indigo shirt + teal accents'),
      ('warm_spice', 'Spice',
          [Color(0xFF8B3A1F), Color(0xFFC97B2A)],
          'Brick red + caramel tan'),
      ('deep_forest', 'Forest',
          [Color(0xFF1F3A2E), Color(0xFF4A6741)],
          'Dark green + khaki'),
      ('soft_blush', 'Blush',
          [Color(0xFFE8B4A0), Color(0xFFD4A5A5)],
          'Peach top + dusty rose'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
        children: items.map((item) {
          final (key, name, swatches, example) = item;
          final selected = _colors.contains(key);
          return GestureDetector(
            onTap: () => setState(() {
              if (_colors.contains(key)) {
                _colors.remove(key);
              } else {
                _colors.add(key);
              }
            }),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: swatches,
                      stops: const [0.5, 0.5],
                    ),
                    border: Border.all(color: AppColors.border),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.bg,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: AppColors.orange,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.orange : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  example,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 9.5,
                    height: 1.15,
                    color: AppColors.ink3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Step 5: Fit
  Widget _buildFit() {
    // (key, name, description, example outfit, silhouette icon)
    const items = [
      ('slim', 'Slim', 'Tailored, close to the body',
          'Skinny jeans + fitted shirt', Icons.person_outline),
      ('regular', 'Regular', 'A safe middle ground',
          'Straight chinos + classic tee', Icons.accessibility_new),
      ('relaxed', 'Relaxed', 'Easy, room to move',
          'Loose trousers + drape shirt', Icons.self_improvement),
      ('oversize', 'Oversized', 'Big, intentional, boxy',
          'Baggy jeans + boxy hoodie', Icons.crop_square),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: items.map((item) {
          final (key, name, desc, example, icon) = item;
          final selected = _fit == key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _fit = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.orangeSoft : AppColors.card,
                  border: Border.all(
                    color: selected ? AppColors.orange : AppColors.border,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFF1EFEB),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.orange
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(icon, size: 26,
                          color: selected
                              ? AppColors.orange
                              : AppColors.ink2),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTypography.label.copyWith(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                          const SizedBox(height: 2),
                          Text(desc, style: AppTypography.caption),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFF1EFEB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('e.g. $example',
                                style: AppTypography.mono.copyWith(
                                  fontSize: 10.5,
                                  color: AppColors.ink2,
                                )),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check, color: AppColors.orange, size: 20),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Step 6: City
  Widget _buildCity() {
    const cities = [
      // India
      ('Mumbai', 'tropical'),
      ('Delhi', 'subtropical'),
      ('Bangalore', 'temperate'),
      ('Chennai', 'tropical'),
      ('Hyderabad', 'subtropical'),
      ('Pune', 'subtropical'),
      ('Kolkata', 'subtropical'),
      ('Ahmedabad', 'subtropical'),
      ('Jaipur', 'subtropical'),
      ('Surat', 'tropical'),
      ('Lucknow', 'subtropical'),
      ('Chandigarh', 'subtropical'),
      ('Kochi', 'tropical'),
      ('Goa', 'tropical'),
      ('Indore', 'subtropical'),
      // Middle East
      ('Dubai', 'arid'),
      ('Abu Dhabi', 'arid'),
      ('Riyadh', 'arid'),
      ('Doha', 'arid'),
      ('Kuwait City', 'arid'),
      // Southeast Asia
      ('Singapore', 'tropical'),
      ('Bangkok', 'tropical'),
      ('Jakarta', 'tropical'),
      ('Kuala Lumpur', 'tropical'),
      ('Manila', 'tropical'),
      ('Ho Chi Minh City', 'tropical'),
      // East Asia
      ('Tokyo', 'temperate'),
      ('Seoul', 'temperate'),
      ('Shanghai', 'temperate'),
      ('Beijing', 'temperate'),
      ('Hong Kong', 'subtropical'),
      // Europe
      ('London', 'temperate'),
      ('Paris', 'temperate'),
      ('Berlin', 'temperate'),
      ('Amsterdam', 'temperate'),
      ('Madrid', 'temperate'),
      ('Rome', 'temperate'),
      ('Barcelona', 'temperate'),
      ('Zurich', 'cold'),
      ('Stockholm', 'cold'),
      // North America
      ('New York', 'temperate'),
      ('Los Angeles', 'temperate'),
      ('Chicago', 'cold'),
      ('Toronto', 'cold'),
      ('Vancouver', 'temperate'),
      ('San Francisco', 'temperate'),
      ('Miami', 'tropical'),
      // Oceania
      ('Sydney', 'temperate'),
      ('Melbourne', 'temperate'),
    ];

    final query = _city ?? '';
    final matches = query.isEmpty
        ? cities
        : cities
            .where((c) =>
                c.$1.toLowerCase().contains(query.toLowerCase()))
            .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (v) => setState(() {
              _city = v;
              final match = cities.where(
                  (c) => c.$1.toLowerCase() == v.toLowerCase());
              if (match.isNotEmpty) _climate = match.first.$2;
            }),
            decoration: const InputDecoration(hintText: 'Search city…'),
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(4),
              children: matches.map((c) {
                final selected = _city?.toLowerCase() == c.$1.toLowerCase();
                return GestureDetector(
                  onTap: () => setState(() {
                    _city = c.$1;
                    _climate = c.$2;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.orangeSoft : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c.$1,
                            style: AppTypography.label.copyWith(
                                color: selected
                                    ? AppColors.orange
                                    : AppColors.ink)),
                        Text(c.$2.toUpperCase(),
                            style: AppTypography.mono
                                .copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_climate != null) ...[
            const SizedBox(height: 22),
            Text('CLIMATE · AUTO-DETECTED',
                style: AppTypography.mono.copyWith(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.ink2)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ['tropical', 'subtropical', 'temperate', 'arid', 'cold']
                  .map((c) {
                final selected = _climate == c;
                return GestureDetector(
                  onTap: () => setState(() => _climate = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.ink : Colors.white,
                      border: Border.all(
                        color: selected
                            ? AppColors.ink
                            : AppColors.borderStrong,
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      c[0].toUpperCase() + c.substring(1),
                      style: AppTypography.label.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // Step 9: Optional body / skin / budget / lifestyle
  Widget _buildOptional() {
    const bodyTypes = [
      ('rectangle', 'Rectangle', Icons.crop_portrait),
      ('triangle', 'Triangle', Icons.change_history),
      ('inverted_triangle', 'Inverted △', Icons.details),
      ('hourglass', 'Hourglass', Icons.hourglass_bottom),
      ('oval', 'Oval', Icons.circle_outlined),
    ];
    const undertones = [
      ('warm', 'Warm', Color(0xFFE8B86A), 'golden / yellow'),
      ('cool', 'Cool', Color(0xFFAEC6E8), 'pink / blue'),
      ('neutral', 'Neutral', Color(0xFFD6CFC2), 'a mix'),
    ];
    const budgets = [
      ('budget', 'Budget', '₹500-2k'),
      ('mid', 'Mid', '₹2k-8k'),
      ('luxury', 'Luxury', '₹8k+'),
    ];
    const lifestyles = ['WFH', 'Office', 'Hybrid', 'Travel-heavy', 'Student'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BODY TYPE',
              style: AppTypography.mono.copyWith(
                  fontSize: 11, color: AppColors.ink2, fontWeight: FontWeight.w600,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bodyTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (k, label, icon) = bodyTypes[i];
                final selected = _bodyType == k;
                return GestureDetector(
                  onTap: () => setState(() =>
                      _bodyType = selected ? null : k),
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.orangeSoft : AppColors.card,
                      border: Border.all(
                          color: selected ? AppColors.orange : AppColors.border,
                          width: selected ? 2 : 1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 26, color: AppColors.ink2),
                        const SizedBox(height: 4),
                        Text(label,
                            style: AppTypography.caption.copyWith(fontSize: 11),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          Text('SKIN UNDERTONE',
              style: AppTypography.mono.copyWith(
                  fontSize: 11, color: AppColors.ink2, fontWeight: FontWeight.w600,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Row(
            children: undertones.map((u) {
              final (k, label, color, hint) = u;
              final selected = _skinUndertone == k;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() =>
                        _skinUndertone = selected ? null : k),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.orangeSoft : AppColors.card,
                        border: Border.all(
                            color: selected
                                ? AppColors.orange
                                : AppColors.border,
                            width: selected ? 2 : 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(height: 6),
                          Text(label,
                              style: AppTypography.label
                                  .copyWith(fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink)),
                          Text(hint, style: AppTypography.caption.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          Text('HEIGHT (CM)',
              style: AppTypography.mono.copyWith(
                  fontSize: 11, color: AppColors.ink2, fontWeight: FontWeight.w600,
                  letterSpacing: 0.6)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _heightCm != null ? '$_heightCm cm' : 'Skip',
                style: GoogleFonts.instrumentSerif(
                    fontSize: 22, color: AppColors.ink),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppColors.orange,
                    inactiveTrackColor: const Color(0xFFECEAE4),
                    thumbColor: AppColors.orange,
                    overlayColor: AppColors.orangeSoft,
                  ),
                  child: Slider(
                    min: 139, max: 210,
                    value: (_heightCm ?? 139).toDouble(),
                    onChanged: (v) {
                      final n = v.round();
                      setState(() => _heightCm = n == 139 ? null : n);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('BUDGET TIER',
              style: AppTypography.mono.copyWith(
                  fontSize: 11, color: AppColors.ink2, fontWeight: FontWeight.w600,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Row(
            children: budgets.map((b) {
              final (k, label, hint) = b;
              final selected = _budgetTier == k;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() =>
                        _budgetTier = selected ? null : k),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.orangeSoft : AppColors.card,
                        border: Border.all(
                            color: selected
                                ? AppColors.orange
                                : AppColors.border,
                            width: selected ? 2 : 1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: AppTypography.label.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink)),
                          Text(hint, style: AppTypography.caption.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          Text('LIFESTYLE',
              style: AppTypography.mono.copyWith(
                  fontSize: 11, color: AppColors.ink2, fontWeight: FontWeight.w600,
                  letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: lifestyles.map((l) {
              final selected = _lifestyle.contains(l);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _lifestyle.remove(l);
                  } else {
                    _lifestyle.add(l);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.ink : AppColors.card,
                    border: Border.all(
                      color: selected ? AppColors.ink : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(l,
                      style: AppTypography.label.copyWith(
                          fontSize: 13,
                          color: selected ? Colors.white : AppColors.ink)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Completion screen
  Widget _buildCompletion() {
    final labels = {
      'w': 'Women', 'm': 'Men', 'all': 'Both',
      'min': 'Minimalist', 'street': 'Streetwear', 'class': 'Classic',
      'ethnic': 'Ethnic', 'boho': 'Boho', 'sport': 'Sporty',
      'casual': 'Casual', 'work': 'Work', 'party': 'Party',
      'gym': 'Gym', 'date': 'Date', 'festive': 'Festive', 'travel': 'Travel',
      'neutral': 'Neutrals', 'earth': 'Earth', 'pastel': 'Pastels',
      'bold': 'Bold', 'mono': 'Mono', 'jewel': 'Jewel',
      'pastel_sage': 'Sage & Sky', 'warm_sunset': 'Sunset',
      'cool_ocean': 'Ocean', 'warm_spice': 'Spice',
      'deep_forest': 'Forest', 'soft_blush': 'Blush',
      'slim': 'Slim', 'regular': 'Regular',
      'relaxed': 'Relaxed', 'oversize': 'Oversized',
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('✶ all set',
                    style: AppTypography.mono.copyWith(
                        color: AppColors.orange,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 16),
              Text(
                _nameController.text.trim().isEmpty
                    ? "You're ready."
                    : "Welcome, ${_nameController.text.trim()}.",
                style: AppTypography.displaySerif.copyWith(fontSize: 36),
              ),
              const SizedBox(height: 6),
              Text("Here's the profile we'll style for.",
                  style: AppTypography.body),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _SummaryRow('Age', ['$_age']),
                        const Divider(height: 24),
                        _SummaryRow('Styling', [labels[_gender] ?? '']),
                        const Divider(height: 24),
                        _SummaryRow('Style',
                            _styles.map((s) => labels[s] ?? s).toList()),
                        const Divider(height: 24),
                        _SummaryRow('Occasions',
                            _occasions.map((o) => labels[o] ?? o).toList()),
                        const Divider(height: 24),
                        _SummaryRow('Colors',
                            _colors.map((c) => labels[c] ?? c).toList()),
                        const Divider(height: 24),
                        _SummaryRow('Fit', [labels[_fit] ?? '']),
                        const Divider(height: 24),
                        _SummaryRow('Based in', [_city ?? '']),
                        if (_bodyType != null || _skinUndertone != null ||
                            _budgetTier != null || _lifestyle.isNotEmpty) ...[
                          const Divider(height: 24),
                          _SummaryRow('Profile', [
                            if (_bodyType != null) _bodyType!.replaceAll('_', ' '),
                            if (_skinUndertone != null) '$_skinUndertone undertone',
                            if (_budgetTier != null) '$_budgetTier budget',
                            if (_heightCm != null) '${_heightCm}cm',
                            ..._lifestyle,
                          ]),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  ref.read(authStatusProvider.notifier).setAuthenticated();
                  context.go('/wardrobe');
                },
                child: const Text('Start exploring →'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: const Color(0xFFECEAE4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0, 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.arrow_back, size: 20, color: AppColors.ink),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _SelectionCard({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.orangeSoft : AppColors.card,
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

class _TileGrid extends StatelessWidget {
  final List<(String, String, String)> items;
  final List<String> selected;
  final ValueChanged<String> onTap;

  const _TileGrid({
    required this.items,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: items.map((item) {
          final (key, name, hint) = item;
          final isActive = selected.contains(key);
          return GestureDetector(
            onTap: () => onTap(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive ? AppColors.orangeSoft : AppColors.card,
                border: Border.all(
                  color: isActive ? AppColors.orange : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(name,
                      style: AppTypography.label.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink)),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(hint, style: AppTypography.caption.copyWith(fontSize: 11)),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final List<String> chips;

  const _SummaryRow(this.label, this.chips);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(label.toUpperCase(),
                style: AppTypography.mono.copyWith(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.ink2)),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: chips.where((c) => c.isNotEmpty).map((c) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EFEB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(c,
                    style: AppTypography.chip.copyWith(fontSize: 11)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
