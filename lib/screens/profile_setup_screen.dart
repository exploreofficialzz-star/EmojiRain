import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_constants.dart';
import '../services/profile_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _usernameCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  String _selectedAvatar  = '😎';
  String _selectedCountry = '';
  String _selectedFlag    = '';
  bool   _saving          = false;

  @override
  void initState() {
    super.initState();
    final p = ProfileService.instance;
    if (p.isSetUp) {
      _usernameCtrl.text = p.username;
      _selectedAvatar    = p.avatar;
      _selectedCountry   = p.country;
      _selectedFlag      = p.flag;
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCountry.isEmpty) {
      _showSnack('Please select your country');
      return;
    }

    setState(() => _saving = true);
    await ProfileService.instance.saveProfile(
      username: _usernameCtrl.text.trim(),
      avatar:   _selectedAvatar,
      country:  _selectedCountry,
      flag:     _selectedFlag,
    );
    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: AppColors.surfaceCard,
      behavior:        SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Avatar picker ──────────────────────────────
                        _sectionLabel('CHOOSE YOUR AVATAR'),
                        const SizedBox(height: 10),
                        _buildAvatarGrid(),
                        const SizedBox(height: 24),

                        // ── Username ───────────────────────────────────
                        _sectionLabel('USERNAME'),
                        const SizedBox(height: 10),
                        _buildUsernameField(),
                        const SizedBox(height: 24),

                        // ── Country ────────────────────────────────────
                        _sectionLabel('YOUR COUNTRY'),
                        const SizedBox(height: 10),
                        _buildCountryPicker(),
                        const SizedBox(height: 32),

                        // ── Save button ────────────────────────────────
                        _buildSaveBtn(),
                        const SizedBox(height: 24),

                        // ── Support ────────────────────────────────────
                        _buildSupport(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16,
              ),
            ),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                _selectedAvatar,
                style: const TextStyle(fontSize: 28),
              ),
              const Text(
                'MY PROFILE',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w900,
                  color: AppColors.primary, letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 38),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  // ── Avatar Grid ────────────────────────────────────────────────────────────
  Widget _buildAvatarGrid() {
    final avatars = ProfileService.avatarOptions;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing:  10,
          crossAxisSpacing: 10,
        ),
        itemCount: avatars.length,
        itemBuilder: (_, i) {
          final av       = avatars[i];
          final selected = av == _selectedAvatar;
          return GestureDetector(
            onTap: () => setState(() => _selectedAvatar = av),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(av, style: const TextStyle(fontSize: 22)),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Username Field ─────────────────────────────────────────────────────────
  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameCtrl,
      maxLength:  16,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        counterText:    '',
        hintText:       'Enter your username',
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withOpacity(0.5),
          fontSize: 15,
        ),
        prefixIcon: Text(
          _selectedAvatar,
          style: const TextStyle(fontSize: 20),
        ).pads(const EdgeInsets.symmetric(horizontal: 14)),
        filled:      true,
        fillColor:   AppColors.surfaceCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Username cannot be empty';
        if (v.trim().length < 3) return 'At least 3 characters required';
        return null;
      },
    );
  }

  // ── Country Picker ─────────────────────────────────────────────────────────
  Widget _buildCountryPicker() {
    final countries = ProfileService.countryOptions;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _selectedCountry.isEmpty
              ? Colors.white.withOpacity(0.1)
              : AppColors.primary.withOpacity(0.4),
        ),
      ),
      child: DropdownButton<Map<String, String>>(
        value: _selectedCountry.isNotEmpty
            ? countries.firstWhere(
                (c) => c['name'] == _selectedCountry,
                orElse: () => countries.first,
              )
            : null,
        isExpanded:      true,
        dropdownColor:   AppColors.surfaceCard,
        underline:       const SizedBox.shrink(),
        hint: Text(
          '🌍  Select your country',
          style: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.5),
            fontSize: 15,
          ),
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.textSecondary,
        ),
        items: countries.map((c) {
          return DropdownMenuItem<Map<String, String>>(
            value: c,
            child: Text(
              '${c['flag']}  ${c['name']}',
              style: const TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   14,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() {
              _selectedCountry = val['name']!;
              _selectedFlag    = val['flag']!;
            });
          }
        },
      ),
    );
  }

  // ── Save Button ────────────────────────────────────────────────────────────
  Widget _buildSaveBtn() {
    return GestureDetector(
      onTap: _saving ? null : _save,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryBtnGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:      AppColors.primary.withOpacity(0.4),
              blurRadius: 16, offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: _saving
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  '✅  SAVE PROFILE',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900,
                    color: Colors.black, letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Support ────────────────────────────────────────────────────────────────
  Widget _buildSupport() {
    return Center(
      child: Column(
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
            color: Colors.white.withOpacity(0.07),
          ),
          const SizedBox(height: 10),
          const Text(
            'Need help?',
            style: TextStyle(
              fontSize: 12, color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppSupport.email,
            style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: AppColors.textSecondary, letterSpacing: 1.5,
        ),
      );
}

// ── Extension helper for padding ──────────────────────────────────────────────
extension on Widget {
  Widget pads(EdgeInsets p) => Padding(padding: p, child: this);
}
