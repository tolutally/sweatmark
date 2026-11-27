import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  AppDesign get _design => AppDesign.of(context);
  bool _isSignUp = true;
  bool _obscurePassword = true;
  bool _isSocialLoading = false;
  // Google is configured (Firebase provider + iOS client ID + URL scheme).
  static const _googleEnabled = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static const _interactive = Color(0xFF6741B2);

  void _switchMode() {
    _formKey.currentState?.reset();
    _passwordController.clear();
    setState(() {
      _isSignUp = !_isSignUp;
      _obscurePassword = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.watch<AuthNotifier>();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness,
      ),
      child: Scaffold(
        backgroundColor: _colors.surface,
        body: SafeArea(
          bottom: false,
          // Sign up and sign in are separate screens reached from the footer
          // link; the shared form state is reset when switching.
          child: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(.06, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: SingleChildScrollView(
              key: ValueKey(_isSignUp),
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24, 28 + MediaQuery.paddingOf(context).bottom),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  _buildBrand(),
                  const SizedBox(height: 36),
                  Text(
                    _isSignUp ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 38,
                      height: 1.05,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      color: _colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isSignUp
                        ? 'Track your training and see your progress.'
                        : 'Pick up where you left off.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, color: _colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  _buildForm(authNotifier),
                  const SizedBox(height: 24),
                  _buildSwitchLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() => Column(children: [
        Container(
          width: 72,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Image.asset('assets/icon.png', fit: BoxFit.cover),
        ),
        const SizedBox(height: 12),
        Text('SweatMark',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
                color: _colors.onSurface)),
      ]);

  InputDecoration _field({String? hint, Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _colors.onSurfaceVariant, fontSize: 15),
        suffixIcon: suffix,
        filled: true,
        fillColor: _colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lavender, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _colors.error, width: 1.5),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _colors.onSurface)),
      );

  Widget _buildForm(AuthNotifier authNotifier) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('Email'),
          TextFormField(
            controller: _emailController,
            style: TextStyle(color: _colors.onSurface, fontSize: 15),
            decoration: _field(),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _label('Password'),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: _colors.onSurface, fontSize: 15),
            autofillHints: [
              _isSignUp ? AutofillHints.newPassword : AutofillHints.password
            ],
            decoration: _field(
              hint: _isSignUp ? 'At least 6 characters' : null,
              suffix: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _colors.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (_isSignUp && value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submitForm(authNotifier),
          ),
          if (!_isSignUp)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: authNotifier.isLoading
                    ? null
                    : () => _showForgotPasswordDialog(authNotifier),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  foregroundColor: _interactive,
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
                child: const Text('Forgot password?'),
              ),
            ),
          SizedBox(height: _isSignUp ? 28 : 12),
          _buildSubmitButton(authNotifier),
          const SizedBox(height: 12),
          _buildSocialButtons(authNotifier),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AuthNotifier authNotifier) {
    return FilledButton(
      onPressed:
          authNotifier.isLoading ? null : () => _submitForm(authNotifier),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lavender,
        foregroundColor: AppColors.ink,
        disabledBackgroundColor: AppColors.paleLavender,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      child: authNotifier.isLoading && !_isSocialLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: AppColors.ink))
          : Text(_isSignUp ? 'Create account' : 'Sign in'),
    );
  }

  Widget _socialButton(
          {required Widget icon,
          required String label,
          required VoidCallback? onPressed}) =>
      OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _colors.surface,
          foregroundColor: _colors.onSurface,
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: _colors.outline.withValues(alpha: .6)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          icon,
          const SizedBox(width: 12),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ]),
      );

  Widget _buildSocialButtons(AuthNotifier authNotifier) {
    final isLoading = authNotifier.isLoading || _isSocialLoading;
    return Column(children: [
      if (Platform.isIOS)
        _socialButton(
          icon: Icon(Icons.apple, size: 26, color: _colors.onSurface),
          label: 'Continue with Apple',
          onPressed: isLoading ? null : () => _signInWithApple(authNotifier),
        ),
      if (Platform.isIOS && _googleEnabled) const SizedBox(height: 12),
      if (_googleEnabled)
        _socialButton(
          // Bundled so the button never waits on the network.
          icon: Image.asset('assets/brand/google_g.png', width: 22, height: 22),
          label: 'Continue with Google',
          onPressed: isLoading ? null : () => _signInWithGoogle(authNotifier),
        ),
    ]);
  }

  Widget _buildSwitchLink() {
    final link = _isSignUp ? 'Sign in' : 'Create account';
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
          style: TextStyle(fontSize: 15, color: _colors.onSurfaceVariant),
        ),
        TextButton(
          onPressed: _switchMode,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.padded,
            foregroundColor: _interactive,
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          child: Text(link),
        ),
      ],
    );
  }

  Future<void> _submitForm(AuthNotifier authNotifier) async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = _isSignUp
        ? await authNotifier.signUpWithEmail(email, password)
        : await authNotifier.signInWithEmail(email, password);

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSignUp
                ? 'Failed to create account. Email may already be in use.'
                : 'Failed to sign in. Please check your credentials.',
            style: TextStyle(color: _colors.onErrorContainer),
          ),
          backgroundColor: _colors.errorContainer,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      );
    }
  }

  Future<void> _signInWithGoogle(AuthNotifier authNotifier) async {
    setState(() => _isSocialLoading = true);

    final success = await authNotifier.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isSocialLoading = false);

    if (success == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign in with Google. Please try again.',
              style: TextStyle(color: _colors.onErrorContainer)),
          backgroundColor: _colors.errorContainer,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      );
    }
  }

  Future<void> _signInWithApple(AuthNotifier authNotifier) async {
    setState(() => _isSocialLoading = true);

    final success = await authNotifier.signInWithApple();

    if (!mounted) return;
    setState(() => _isSocialLoading = false);

    if (success == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign in with Apple. Please try again.',
              style: TextStyle(color: _colors.onErrorContainer)),
          backgroundColor: _colors.errorContainer,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      );
    }
  }

  void _showForgotPasswordDialog(AuthNotifier authNotifier) {
    final resetEmailController =
        TextEditingController(text: _emailController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _colors.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email and we\'ll send you a link to reset your password.',
              style: TextStyle(
                fontSize: 15,
                color: _colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              style: TextStyle(
                color: _colors.onSurface,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'you@example.com',
                hintStyle: TextStyle(color: _colors.onSurfaceVariant),
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: _colors.onSurfaceVariant,
                  size: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: _colors.surfaceContainerLow,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: _colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = resetEmailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter a valid email address.',
                        style: TextStyle(color: _colors.onErrorContainer)),
                    backgroundColor: _colors.errorContainer,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              final messenger = ScaffoldMessenger.of(context);

              final success = await authNotifier.sendPasswordResetEmail(email);

              if (!mounted) return;

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Password reset email sent! Check your inbox.'
                        : 'Failed to send reset email. Please try again.',
                    style: TextStyle(
                        color: success
                            ? _design.onSuccessContainer
                            : _colors.onErrorContainer),
                  ),
                  backgroundColor: success
                      ? _design.successContainer
                      : _colors.errorContainer,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Send Link',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
