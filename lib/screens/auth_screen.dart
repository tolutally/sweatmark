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
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),
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
        color: AppColors.brandNavy,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.brandCoral.withOpacity(0.35),
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
        const Text(
          'SweatMark',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.neutral900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp ? 'Create your account to get started' : 'Welcome back! Sign in to continue',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.neutral500,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(AuthNotifier authNotifier) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            const Text(
              'Email',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              style: const TextStyle(
                color: AppColors.neutral900,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'you@example.com',
                hintStyle: TextStyle(color: AppColors.neutral400),
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppColors.neutral400,
                  size: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.neutral200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.brandCoral, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.neutral50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            const Text(
              'Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(
                color: AppColors.neutral900,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: _isSignUp ? 'Min. 6 characters' : 'Enter your password',
                hintStyle: TextStyle(color: AppColors.neutral400),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.neutral400,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.neutral400,
                    size: 20,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.neutral200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.brandCoral, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.neutral50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  onTap: authNotifier.isLoading ? null : () => _showForgotPasswordDialog(authNotifier),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandCoral,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            
            // Submit button
            _buildSubmitButton(authNotifier),
            
            // Divider with OR
            const SizedBox(height: 24),
            _buildDivider(),
            const SizedBox(height: 24),
            
            // Social sign-in buttons
            _buildSocialButtons(authNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSignUp = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isSignUp ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _isSignUp
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isSignUp ? AppColors.neutral900 : AppColors.neutral500,
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
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !_isSignUp ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_isSignUp
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: !_isSignUp ? AppColors.neutral900 : AppColors.neutral500,
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
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: authNotifier.isLoading ? null : () => _submitForm(authNotifier),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandCoral,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brandCoral.withOpacity(0.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: authNotifier.isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                _isSignUp ? 'Create Account' : 'Sign In',
                style: const TextStyle(
                  fontSize: 16,
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
            color: AppColors.neutral200,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.neutral400,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.neutral200,
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
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: isLoading ? null : () => _signInWithGoogle(authNotifier),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.neutral800,
              side: const BorderSide(color: AppColors.neutral200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
                    color: AppColors.neutral800,
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
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : () => _signInWithApple(authNotifier),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black.withOpacity(0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Your workouts sync across all devices',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.neutral500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: AppColors.neutral400,
            ),
            const SizedBox(width: 6),
            const Text(
              'Secured with Firebase Authentication',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.neutral400,
              ),
            ),
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
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          content: const Text('Failed to sign in with Google. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          content: const Text('Failed to sign in with Apple. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showForgotPasswordDialog(AuthNotifier authNotifier) {
    final resetEmailController = TextEditingController(text: _emailController.text);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.neutral900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email and we\'ll send you a link to reset your password.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.neutral600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              style: const TextStyle(
                color: AppColors.neutral900,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'you@example.com',
                hintStyle: TextStyle(color: AppColors.neutral400),
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppColors.neutral400,
                  size: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.neutral200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.brandCoral, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.neutral50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.neutral600,
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
                    content: const Text('Please enter a valid email address.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              final success = await authNotifier.sendPasswordResetEmail(email);
              
              if (!mounted) return;
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Password reset email sent! Check your inbox.'
                        : 'Failed to send reset email. Please try again.',
                  ),
                  backgroundColor: success ? AppColors.success : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
