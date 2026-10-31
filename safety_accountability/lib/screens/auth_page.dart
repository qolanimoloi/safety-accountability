import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/input_validators.dart';
import '../widgets/app_logo.dart';

/// Sign up / Log in screen. Shown whenever `isLoggedIn` (app_settings.dart)
/// is false — main.dart swaps straight to HomeScreen the moment it flips
/// true, so there's no manual navigation needed from here.
///
/// All visible text comes from AppLocalizations, so it follows the language
/// picked in Settings.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeTerms = false;

  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _switchMode(bool toLogin) {
    if (_isLogin == toLogin) return;
    setState(() {
      _isLogin = toLogin;
      _agreeTerms = false;
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isLogin && !_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.acceptTermsSnack)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await AuthService.login(email: _email.text.trim(), password: _password.text);
      } else {
        await AuthService.signup(
          fullName: _fullName.text.trim(),
          email: _email.text.trim(),
          phoneNumber: _phone.text.trim(),
          password: _password.text,
          confirmPassword: _confirmPassword.text,
        );
      }
      if (!mounted) return;
      // Flipping this is all it takes — main.dart is listening and will
      // swap straight to HomeScreen (the map tab). AuthService has already
      // saved the real token on-device by this point.
      isLoggedIn.value = true;
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.serverUnreachable)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _loading = true);
    try {
      final result = await AuthService.loginWithGoogle();
      if (result == null || !mounted) return; // closed the Google window
      // Google doesn't share a phone number, and the app needs one so
      // emergency contacts can find each other. Ask before going in.
      if (result.needsPhone) {
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _PhoneDialog(),
        );
        if (!mounted) return;
      }
      isLoggedIn.value = true;
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.serverUnreachable)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _nameValidator(String? v) {
    if (v == null || v.trim().isEmpty) return AppLocalizations.of(context)!.fullNameRequired;
    return null;
  }

  String? _emailValidator(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.emailRequired;
       if (!InputValidators.isValidEmail(v)) return l10n.emailInvalid;
    return null;
  }

   String? _phoneValidator(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.trim().isEmpty) return l10n.phoneRequired;
    if (InputValidators.normalizeSaMobile(v) == null) return InputValidators.saMobileMessage;
    return null;
  }

  String? _passwordValidator(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.isEmpty) return l10n.passwordRequired;
    if (v.length < 8) return l10n.passwordTooShort;
    return null;
  }

  String? _confirmValidator(String? v) {
    final l10n = AppLocalizations.of(context)!;
    if (v == null || v.isEmpty) return l10n.confirmPasswordRequired;
    if (v != _password.text) return l10n.passwordsDontMatch;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              _buildHero(l10n),
              const SizedBox(height: 22),
              _buildModeToggle(l10n),
              const SizedBox(height: 22),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isLogin) ...[
                      _buildField(
                        controller: _fullName,
                        label: l10n.fullName,
                        icon: Icons.person_outline_rounded,
                        validator: _nameValidator,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildField(
                      controller: _email,
                      label: l10n.emailAddress,
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailValidator,
                    ),
                    const SizedBox(height: 14),
                    if (!_isLogin) ...[
                      _buildField(
                        controller: _phone,
                        label: l10n.phoneNumber,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        hint: l10n.phoneHint,
                        validator: _phoneValidator,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildField(
                      controller: _password,
                      label: l10n.password,
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      validator: _passwordValidator,
                      suffix: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    if (_isLogin) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.forgotPasswordSoon)),
                            );
                          },
                          child: Text(l10n.forgotPassword, style: const TextStyle(fontSize: 12.5)),
                        ),
                      ),
                    ],
                    if (!_isLogin) ...[
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _confirmPassword,
                        label: l10n.confirmPassword,
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscureConfirm,
                        validator: _confirmValidator,
                        suffix: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: Checkbox(
                              value: _agreeTerms,
                              activeColor: const Color(0xFF007BFF),
                              onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                l10n.agreeToTerms,
                                style: const TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007BFF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                              )
                            : Text(
                                _isLogin ? l10n.logIn : l10n.createAccount,
                                style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.4))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(l10n.orDivider, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.4))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
                        ),
                        onPressed: _loading ? null : _continueWithGoogle,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _GoogleMark(),
                            const SizedBox(width: 12),
                            Text(
                              _isLogin ? l10n.continueWithGoogle : l10n.signUpWithGoogle,
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_isLogin ? l10n.noAccountPrompt : l10n.haveAccountPrompt} ',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        GestureDetector(
                          onTap: () => _switchMode(!_isLogin),
                          child: Text(
                            _isLogin ? l10n.signUp : l10n.logIn,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF007BFF), fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(AppLocalizations l10n) {
    return Column(
      children: [
        const AppLogo(height: 150),
        const SizedBox(height: 10),
        Text(
          _isLogin ? l10n.authWelcomeBack : l10n.authCreatePrompt,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildModeToggle(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFEDF1F7), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: _toggleButton(l10n.logIn, _isLogin, () => _switchMode(true))),
          Expanded(child: _toggleButton(l10n.signUp, !_isLogin, () => _switchMode(false))),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF007BFF) : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? hint,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5),
            prefixIcon: Icon(icon, size: 19),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF007BFF), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC3545))),
          ),
        ),
      ],
    );
  }
}

/// Shown once after a first Google sign-in to collect the phone number.
class _PhoneDialog extends StatefulWidget {
  const _PhoneDialog();

  @override
  State<_PhoneDialog> createState() => _PhoneDialogState();
}

class _PhoneDialogState extends State<_PhoneDialog> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AccountService.setPhone(_phone.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on AccountException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.serverUnreachable);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.phoneNumber),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'One last step. Your phone number lets people who add you as an emergency contact find you in the app.',
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.phoneHint,
                  prefixIcon: const Icon(Icons.phone_outlined, size: 19),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                                validator: (v) {
                  if (v == null || v.trim().isEmpty) return l10n.phoneRequired;
                  if (InputValidators.normalizeSaMobile(v) == null) return InputValidators.saMobileMessage;
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFDC3545), fontSize: 12.5)),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007BFF)),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Continue', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// A simple, dependency-free stand-in for the Google "G" mark — four
/// colored quarter-arcs. No official logo asset is bundled, so this reads
/// as "Google" by its familiar colors without pulling in an image asset.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.width * 0.22;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final arcRect = rect.deflate(strokeWidth / 2);

    paint.color = const Color(0xFF4285F4); // blue
    canvas.drawArc(arcRect, -0.4, 1.6, false, paint);
    paint.color = const Color(0xFF34A853); // green
    canvas.drawArc(arcRect, 1.2, 1.6, false, paint);
    paint.color = const Color(0xFFFBBC05); // yellow
    canvas.drawArc(arcRect, 2.8, 1.2, false, paint);
    paint.color = const Color(0xFFEA4335); // red
    canvas.drawArc(arcRect, 4.0, 1.9, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}