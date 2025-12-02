import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../state/auth_notifier.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _showEmailForm = false;
  bool _isSignUp = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.watch<AuthNotifier>();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.midnight,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(),
                const SizedBox(height: 32),
                _buildHeader(),
                const SizedBox(height: 48),
                if (!_showEmailForm)
                  ..._buildGuestButtons(authNotifier)
                else
                  ..._buildEmailForm(authNotifier),
                const SizedBox(height: 32),
                _buildFooterNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.brandCoral.withValues(alpha: 0.35),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        PhosphorIconsBold.barbell,
        size: 60,
        color: AppColors.brandNavyDeep,
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'SweatMark',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppColors.neutral0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track your gains, visualize recovery',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.neutral0.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterNote() {
    return Text(
      'Your workouts sync across all devices',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: AppColors.neutral0.withValues(alpha: 0.45),
      ),
    );
  }

  List<Widget> _buildGuestButtons(AuthNotifier authNotifier) {
    return [
      _GradientButton(
        onPressed: authNotifier.isLoading
            ? null
            : () async {
                final success = await authNotifier.signInAnonymously();
                if (!mounted) return;
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to sign in')),
                  );
                }
              },
        child: authNotifier.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandNavyDeep,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIconsBold.lightning, color: AppColors.brandNavyDeep),
                  SizedBox(width: 12),
                  Text(
                    'Continue as Guest',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandNavyDeep,
                    ),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: Divider(color: AppColors.neutral0.withValues(alpha: 0.2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'or',
              style: TextStyle(color: AppColors.neutral0.withValues(alpha: 0.4)),
            ),
          ),
          Expanded(child: Divider(color: AppColors.neutral0.withValues(alpha: 0.2))),
        ],
      ),
      const SizedBox(height: 16),
      _OutlineButton(
        onPressed: () {
          setState(() {
            _showEmailForm = true;
          });
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsRegular.envelope, color: AppColors.brandCoral),
            SizedBox(width: 12),
            Text(
              'Sign in with Email',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.neutral0,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildEmailForm(AuthNotifier authNotifier) {
    return [
      TextField(
        controller: _emailController,
        style: const TextStyle(color: AppColors.neutral0),
        decoration: InputDecoration(
          labelText: 'Email',
          labelStyle: TextStyle(color: AppColors.neutral0.withValues(alpha: 0.7)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.neutral0.withValues(alpha: 0.25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.brandCoral),
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _passwordController,
        obscureText: true,
        style: const TextStyle(color: AppColors.neutral0),
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: TextStyle(color: AppColors.neutral0.withValues(alpha: 0.7)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.neutral0.withValues(alpha: 0.25)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.brandCoral),
          ),
        ),
      ),
      const SizedBox(height: 24),
      _GradientButton(
        onPressed: authNotifier.isLoading
            ? null
            : () async {
                final email = _emailController.text.trim();
                final password = _passwordController.text;

                if (email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final success = _isSignUp
                    ? await authNotifier.signUpWithEmail(email, password)
                    : await authNotifier.signInWithEmail(email, password);

                if (!mounted) return;
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isSignUp ? 'Failed to sign up' : 'Failed to sign in'),
                    ),
                  );
                }
              },
        child: authNotifier.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandNavyDeep,
                ),
              )
            : Text(
                _isSignUp ? 'Sign Up' : 'Sign In',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandNavyDeep,
                ),
              ),
      ),
      const SizedBox(height: 16),
      TextButton(
        onPressed: () {
          setState(() {
            _isSignUp = !_isSignUp;
          });
        },
        child: Text(
          _isSignUp ? 'Already have an account? Sign In' : 'Don\'t have an account? Sign Up',
          style: const TextStyle(color: AppColors.brandCoral),
        ),
      ),
      TextButton(
        onPressed: () {
          setState(() {
            _showEmailForm = false;
          });
        },
        child: const Text(
          'Back',
          style: TextStyle(color: AppColors.neutral400),
        ),
      ),
    ];
  }
}

class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const _GradientButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandCoral.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _OutlineButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.brandCoral, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(child: child),
        ),
      ),
    );
  }
}
