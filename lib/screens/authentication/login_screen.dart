import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_brand.dart';
import '../../core/theme/app_colors.dart';
import 'auth_config.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  bool _rememberMe = false;

  bool _isLoading = false;

  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // LOGIN
  // ==========================================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (error) {
      debugPrint('Login error: $error');

      if (mounted) {
        _showMessage('Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==========================================================================
  // GOOGLE
  // ==========================================================================

  Future<void> _continueWithGoogle() async {
    if (_isLoading || _isGoogleLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!mounted) {
      return;
    }

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AuthConfig.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (error) {
      debugPrint('Google sign-in error: $error');

      if (mounted) {
        _showMessage('Unable to continue with Google.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  // ==========================================================================
  // FORGOT PASSWORD
  // ==========================================================================

  void _forgotPassword() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
  }

  // ==========================================================================
  // REGISTER
  // ==========================================================================

  void _goToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
  }

  // ==========================================================================
  // MESSAGE
  // ==========================================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0ECFF), Color(0xFFF5F7FA), Color(0xFFE8EEF7)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final keyboardIsOpen = Responsive.keyboardIsOpen(context);

              final horizontalPadding = Responsive.horizontalPadding(context);

              final contentWidth = Responsive.contentWidth(context);

              final cardPadding = Responsive.cardPadding(context);

              final logoSize = Responsive.logoSize(context);

              final cardRadius = Responsive.cardRadius(context);

              final fieldHeight = Responsive.fieldHeight(context);

              final buttonHeight = Responsive.buttonHeight(context);

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: keyboardIsOpen ? 12 : 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - (keyboardIsOpen ? 24 : 40),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            AppBrand.logoPath,
                            height: logoSize,
                            fit: BoxFit.contain,
                          ),

                          SizedBox(
                            height: Responsive.value<double>(
                              context,
                              phone: 12,
                              tablet: 16,
                              large: 18,
                            ),
                          ),

                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(cardPadding),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(cardRadius),
                              border: Border.all(color: Colors.white),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: AutoSizeText(
                                    'Sign in to your Account',
                                    maxLines: 1,
                                    minFontSize: 20,
                                    maxFontSize: 30,
                                    stepGranularity: 1,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF151922),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                const Text(
                                  'Enter your email and password to log in',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF707784),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                const Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                SizedBox(
                                  height: fieldHeight,
                                  child: TextField(
                                    controller: _emailController,
                                    enabled: !_isLoading && !_isGoogleLoading,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: _inputDecoration(
                                      hint: 'Enter your email',
                                      icon: Icons.email_outlined,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                SizedBox(
                                  height: fieldHeight,
                                  child: TextField(
                                    controller: _passwordController,
                                    enabled: !_isLoading && !_isGoogleLoading,
                                    obscureText: !_isPasswordVisible,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _login(),
                                    decoration: _inputDecoration(
                                      hint: 'Enter your password',
                                      icon: Icons.lock_outline_rounded,
                                      suffixIcon: IconButton(
                                        onPressed:
                                            _isLoading || _isGoogleLoading
                                            ? null
                                            : () {
                                                setState(() {
                                                  _isPasswordVisible =
                                                      !_isPasswordVisible;
                                                });
                                              },
                                        icon: Icon(
                                          _isPasswordVisible
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged:
                                            _isLoading || _isGoogleLoading
                                            ? null
                                            : (value) {
                                                setState(() {
                                                  _rememberMe = value ?? false;
                                                });
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Flexible(
                                      child: Text(
                                        'Remember me',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isLoading || _isGoogleLoading
                                          ? null
                                          : _forgotPassword,
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 18),

                                SizedBox(
                                  width: double.infinity,
                                  height: buttonHeight,
                                  child: FilledButton(
                                    onPressed: _isLoading || _isGoogleLoading
                                        ? null
                                        : _login,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Log In',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      child: Text('Or'),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 18),

                                SizedBox(
                                  width: double.infinity,
                                  height: buttonHeight,
                                  child: OutlinedButton(
                                    onPressed: _isLoading || _isGoogleLoading
                                        ? null
                                        : _continueWithGoogle,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (_isGoogleLoading)
                                          const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        else
                                          const Text(
                                            'G',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF4285F4),
                                            ),
                                          ),
                                        const SizedBox(width: 10),
                                        const Text('Continue with Google'),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 18),

                                Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    children: [
                                      const Text("Don't have an account? "),
                                      TextButton(
                                        onPressed:
                                            _isLoading || _isGoogleLoading
                                            ? null
                                            : _goToRegister,
                                        child: Text(
                                          'Create account',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
