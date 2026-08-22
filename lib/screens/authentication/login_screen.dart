import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_brand.dart';
import '../../core/theme/app_colors.dart';
import 'register_screen.dart';
import '../../core/responsive/responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.signInWithPassword(email: email, password: password);

      if (!mounted) return;

      // لا نحتاج Navigator هنا.
      //
      // بعد نجاح تسجيل الدخول:
      // Supabase ينشئ Session
      // ↓
      // AuthGate يلتقط الـ Session
      // ↓
      // AppShell يظهر تلقائيًا.
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==========================================================================
  // FORGOT PASSWORD
  // ==========================================================================

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Forgot password screen will be added next.'),
      ),
    );
  }

  // ==========================================================================
  // REGISTER
  // ==========================================================================

  void _goToRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const RegisterScreen()));
  }

  // ==========================================================================
  // GOOGLE
  // ==========================================================================

  void _continueWithGoogle() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google login will be connected later.')),
    );
  }

  // ==========================================================================
  // FACEBOOK
  // ==========================================================================

  void _continueWithFacebook() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Facebook login will be connected later.')),
    );
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
                    ScrollViewKeyboardDismissBehavior.manual,

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
                          // ======================================================
                          // LOGO
                          // ======================================================
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

                          // ======================================================
                          // GLASS CARD
                          // ======================================================
                          ClipRRect(
                            borderRadius: BorderRadius.circular(cardRadius),

                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),

                              child: Container(
                                width: double.infinity,

                                padding: EdgeInsets.all(cardPadding),

                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.35),

                                  borderRadius: BorderRadius.circular(
                                    cardRadius,
                                  ),

                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),

                                    width: 1,
                                  ),

                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),

                                      blurRadius: 20,

                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    // ============================================
                                    // TITLE
                                    // ============================================
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

                                    SizedBox(
                                      height: Responsive.value<double>(
                                        context,
                                        phone: 8,
                                        tablet: 10,
                                        large: 12,
                                      ),
                                    ),

                                    // ============================================
                                    // SUBTITLE
                                    // ============================================
                                    const SizedBox(
                                      width: double.infinity,

                                      child: Text(
                                        'Enter your email and password to log in',

                                        textAlign: TextAlign.center,

                                        style: TextStyle(
                                          fontSize: 14,

                                          color: Color(0xFF707784),
                                        ),
                                      ),
                                    ),

                                    SizedBox(
                                      height: Responsive.value<double>(
                                        context,
                                        phone: 24,
                                        tablet: 28,
                                        large: 32,
                                      ),
                                    ),

                                    // ============================================
                                    // EMAIL LABEL
                                    // ============================================
                                    const Text(
                                      'Email',

                                      style: TextStyle(
                                        fontSize: 15,

                                        fontWeight: FontWeight.w600,

                                        color: Color(0xFF252A34),
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // ============================================
                                    // EMAIL
                                    // ============================================
                                    SizedBox(
                                      height: fieldHeight,

                                      child: TextField(
                                        controller: _emailController,

                                        keyboardType:
                                            TextInputType.emailAddress,

                                        textInputAction: TextInputAction.next,

                                        decoration: InputDecoration(
                                          hintText: 'Enter your email',

                                          prefixIcon: const Icon(
                                            Icons.email_outlined,

                                            color: Color(0xFF606775),
                                          ),

                                          filled: true,

                                          fillColor: Colors.white.withValues(
                                            alpha: 0.65,
                                          ),

                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                              ),

                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),

                                            borderSide: BorderSide.none,
                                          ),

                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),

                                            borderSide: BorderSide.none,
                                          ),

                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),

                                            borderSide: BorderSide(
                                              color: AppColors.primary,

                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(
                                      height: Responsive.value<double>(
                                        context,
                                        phone: 18,
                                        tablet: 20,
                                        large: 22,
                                      ),
                                    ),

                                    // ============================================
                                    // PASSWORD LABEL
                                    // ============================================
                                    const Text(
                                      'Password',

                                      style: TextStyle(
                                        fontSize: 15,

                                        fontWeight: FontWeight.w600,

                                        color: Color(0xFF252A34),
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // ============================================
                                    // PASSWORD
                                    // ============================================
                                    SizedBox(
                                      height: fieldHeight,

                                      child: TextField(
                                        controller: _passwordController,

                                        obscureText: !_isPasswordVisible,

                                        textInputAction: TextInputAction.done,

                                        onSubmitted: (_) => _login(),

                                        decoration: InputDecoration(
                                          hintText: 'Enter your password',

                                          prefixIcon: const Icon(
                                            Icons.lock_outline,

                                            color: Color(0xFF606775),
                                          ),

                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _isPasswordVisible =
                                                    !_isPasswordVisible;
                                              });
                                            },

                                            icon: Icon(
                                              _isPasswordVisible
                                                  ? Icons
                                                        .visibility_off_outlined
                                                  : Icons.visibility_outlined,

                                              color: const Color(0xFF606775),
                                            ),
                                          ),

                                          filled: true,

                                          fillColor: Colors.white.withValues(
                                            alpha: 0.65,
                                          ),

                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                              ),

                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),

                                            borderSide: BorderSide.none,
                                          ),

                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),

                                            borderSide: BorderSide.none,
                                          ),

                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),

                                            borderSide: BorderSide(
                                              color: AppColors.primary,

                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // ============================================
                                    // REMEMBER + FORGOT
                                    // ============================================
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,

                                          child: Checkbox(
                                            value: _rememberMe,

                                            onChanged: (value) {
                                              setState(() {
                                                _rememberMe = value ?? false;
                                              });
                                            },

                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        const Flexible(
                                          child: Text(
                                            'Remember me',

                                            style: TextStyle(
                                              fontSize: 14,

                                              color: Color(0xFF606775),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        TextButton(
                                          onPressed: _forgotPassword,

                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,

                                            minimumSize: Size.zero,

                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),

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

                                    // ============================================
                                    // LOGIN BUTTON
                                    // ============================================
                                    SizedBox(
                                      width: double.infinity,

                                      height: buttonHeight,

                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppColors.primary,

                                              AppColors.primary.withValues(
                                                alpha: 0.85,
                                              ),
                                            ],
                                          ),

                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),

                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.25),

                                              blurRadius: 12,

                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),

                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _login,

                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,

                                            disabledBackgroundColor:
                                                Colors.transparent,

                                            shadowColor: Colors.transparent,

                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),

                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,

                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.5,

                                                        color: Colors.white,
                                                      ),
                                                )
                                              : const Text(
                                                  'Log In',

                                                  style: TextStyle(
                                                    fontSize: 17,

                                                    fontWeight: FontWeight.w600,

                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(
                                      height: Responsive.value<double>(
                                        context,
                                        phone: 20,
                                        tablet: 24,
                                        large: 26,
                                      ),
                                    ),

                                    // ============================================
                                    // OR
                                    // ============================================
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

                                          child: Text(
                                            'Or',

                                            style: TextStyle(
                                              fontSize: 13,

                                              color: Color(0xFF7A808B),
                                            ),
                                          ),
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

                                    // ============================================
                                    // GOOGLE
                                    // ============================================
                                    _SocialButton(
                                      icon: const Text(
                                        'G',

                                        style: TextStyle(
                                          fontSize: 20,

                                          fontWeight: FontWeight.bold,

                                          color: Color(0xFF4285F4),
                                        ),
                                      ),

                                      text: 'Continue with Google',

                                      onPressed: _continueWithGoogle,
                                    ),

                                    const SizedBox(height: 12),

                                    // ============================================
                                    // FACEBOOK
                                    // ============================================
                                    _SocialButton(
                                      icon: const Icon(
                                        Icons.facebook,

                                        size: 22,

                                        color: Color(0xFF1877F2),
                                      ),

                                      text: 'Continue with Facebook',

                                      onPressed: _continueWithFacebook,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ======================================================
                          // SIGN UP
                          // ======================================================
                          SizedBox(
                            height: Responsive.value<double>(
                              context,
                              phone: 22,
                              tablet: 28,
                              large: 32,
                            ),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              Flexible(
                                child: Text(
                                  "Don't have an account?",

                                  overflow: TextOverflow.ellipsis,

                                  style: const TextStyle(
                                    fontSize: 14,

                                    color: Color(0xFF707784),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 6),

                              TextButton(
                                onPressed: _goToRegister,

                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,

                                  minimumSize: Size.zero,

                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),

                                child: Text(
                                  'Sign Up',

                                  style: TextStyle(
                                    fontSize: 14,

                                    fontWeight: FontWeight.w600,

                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
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
}

// ============================================================================
// SOCIAL BUTTON
// ============================================================================

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String text;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,

      height: Responsive.buttonHeight(context),

      child: ElevatedButton(
        onPressed: onPressed,

        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.65),

          foregroundColor: const Color(0xFF252A34),

          elevation: 0,

          shadowColor: Colors.transparent,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            SizedBox(width: 28, child: Center(child: icon)),

            const SizedBox(width: 8),

            Flexible(
              child: Text(
                text,

                overflow: TextOverflow.ellipsis,

                style: const TextStyle(
                  fontSize: 14,

                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
