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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.watch<AuthNotifier>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness,
      ),
      child: Scaffold(
        backgroundColor: _colors.surfaceContainerLow,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  _buildLogo(),
                  const SizedBox(height: 24),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildAuthCard(authNotifier),
                  const SizedBox(height: 24),
                  _buildFooterNote(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: _colors.onSurface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _colors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icon.png',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'SweatMark',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w600,
            color: _colors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp
              ? 'Create your account to get started'
              : 'Welcome back! Sign in to continue',
          style: TextStyle(
            fontSize: 15,
            color: _colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(AuthNotifier authNotifier) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _colors.shadow.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab switcher
            _buildTabSwitcher(),
            const SizedBox(height: 24),

            // Email field
            Text(
              'Email',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
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
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.error, width: 1.5),
                ),
                filled: true,
                fillColor: _colors.surfaceContainerLow,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: TextInputType.emailAddress,
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
            const SizedBox(height: 16),

            // Password field
            Text(
              'Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(
                color: _colors.onSurface,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText:
                    _isSignUp ? 'Min. 6 characters' : 'Enter your password',
                hintStyle: TextStyle(color: _colors.onSurfaceVariant),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: _colors.onSurfaceVariant,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: _colors.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.primary, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _colors.error, width: 1.5),
                ),
                filled: true,
                fillColor: _colors.surfaceContainerLow,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

            // Forgot Password link (only show on Sign In)
            if (!_isSignUp) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: authNotifier.isLoading
                      ? null
                      : () => _showForgotPasswordDialog(authNotifier),
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _colors.primary,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Submit button
            _buildSubmitButton(authNotifier),

            // Enable only after both OAuth providers are configured and tested.
            if (const bool.fromEnvironment('ENABLE_SOCIAL_SIGN_IN')) ...[
              const SizedBox(height: 24),
              _buildDivider(),
              const SizedBox(height: 24),
              _buildSocialButtons(authNotifier),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: _colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSignUp = true),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      _isSignUp ? _colors.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: _isSignUp
                      ? [
                          BoxShadow(
                            color: _colors.shadow.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                margin: const EdgeInsets.all(3),
                child: Center(
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _isSignUp
                          ? _colors.onSurface
                          : _colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSignUp = false),
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isSignUp
                      ? _colors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: !_isSignUp
                      ? [
                          BoxShadow(
                            color: _colors.shadow.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                margin: const EdgeInsets.all(3),
                child: Center(
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: !_isSignUp
                          ? _colors.onSurface
                          : _colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AuthNotifier authNotifier) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 52),
      child: ElevatedButton(
        onPressed:
            authNotifier.isLoading ? null : () => _submitForm(authNotifier),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: authNotifier.isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Theme.of(context)
                      .elevatedButtonTheme
                      .style
                      ?.foregroundColor
                      ?.resolve({WidgetState.disabled}),
                ),
              )
            : Text(
                _isSignUp ? 'Create Account' : 'Sign In',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: _colors.outlineVariant,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: _colors.outlineVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButtons(AuthNotifier authNotifier) {
    final isLoading = authNotifier.isLoading || _isSocialLoading;

    return Column(
      children: [
        // Google Sign-In Button
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          child: OutlinedButton(
            onPressed: isLoading ? null : () => _signInWithGoogle(authNotifier),
            style: OutlinedButton.styleFrom(
              backgroundColor: _colors.surface,
              foregroundColor: _colors.onSurface,
              side: BorderSide(color: _colors.outlineVariant),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                  width: 20,
                  height: 20,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.g_mobiledata,
                    size: 24,
                    color: _colors.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _isSignUp ? 'Continue with Google' : 'Sign in with Google',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Apple Sign-In Button (iOS only)
        if (Platform.isIOS) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            child: ElevatedButton(
              onPressed:
                  isLoading ? null : () => _signInWithApple(authNotifier),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _colors.shadow.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.apple,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isSignUp ? 'Continue with Apple' : 'Sign in with Apple',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooterNote() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _design.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
                child: Text(
              'Your workouts sync across all devices',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _colors.onSurfaceVariant,
              ),
            )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: _colors.onSurfaceVariant,
            ),
            SizedBox(width: 6),
            Flexible(
                child: Text(
              'Secured with Firebase Authentication',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _colors.onSurfaceVariant,
              ),
            )),
          ],
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

    if (!success) {
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

    if (!success) {
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
