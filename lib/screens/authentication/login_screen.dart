import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_brand.dart';
import '../../core/theme/app_colors.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  // ===========================================================================
  // CONSTANTS
  // ===========================================================================

  static const String _authRedirectUrl =
      'medidata26://auth-callback';

  // ===========================================================================
  // CONTROLLERS
  // ===========================================================================

  final TextEditingController
      _emailController =
      TextEditingController();

  final TextEditingController
      _passwordController =
      TextEditingController();

  // ===========================================================================
  // STATE
  // ===========================================================================

  bool _isPasswordVisible =
      false;

  bool _isLoading =
      false;

  bool _rememberMe =
      true;

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // LOGIN
  // ===========================================================================

  Future<void> _login() async {
    FocusScope.of(context)
        .unfocus();

    final email =
        _emailController.text
            .trim();

    final password =
        _passwordController.text;

    if (email.isEmpty ||
        password.isEmpty) {
      _showMessage(
        'Please enter your email and password.',
      );
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage(
        'Please enter a valid email address.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client
          .auth
          .signInWithPassword(
        email:
            email,
        password:
            password,
      );

      // -----------------------------------------------------------------------
      // DO NOT NAVIGATE HERE.
      //
      // AuthGate watches Supabase auth state.
      // Once the session is created:
      //
      // Supabase
      //   ↓
      // AuthGate
      //   ↓
      // AppShell
      // -----------------------------------------------------------------------
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      final message =
          _friendlyAuthMessage(
        error,
      );

      _showMessage(
        message,
      );
    } catch (error) {
      debugPrint(
        'Login error: $error',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // GOOGLE
  // ===========================================================================

  Future<void>
      _continueWithGoogle() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context)
        .unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client
          .auth
          .signInWithOAuth(
        OAuthProvider.google,
        redirectTo:
            _authRedirectUrl,
        queryParams: const {
          'access_type': 'offline',
          'prompt': 'select_account',
        },
      );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message,
      );
    } catch (error) {
      debugPrint(
        'Google sign-in error: $error',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to continue with Google.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // FORGOT PASSWORD
  // ===========================================================================

  Future<void>
      _forgotPassword() async {
    final emailController =
        TextEditingController(
      text:
          _emailController.text.trim(),
    );

    bool sending = false;

    final result =
        await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title: const Text(
                'Reset Password',
              ),
              content:
                  TextField(
                controller:
                    emailController,
                keyboardType:
                    TextInputType.emailAddress,
                textInputAction:
                    TextInputAction.done,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Email',
                  hintText:
                      'Enter your account email',
                  prefixIcon:
                      Icon(
                    Icons
                        .email_outlined,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      sending
                          ? null
                          : () {
                              Navigator.of(
                                dialogContext,
                              ).pop(
                                false,
                              );
                            },
                  child:
                      const Text(
                    'Cancel',
                  ),
                ),
                FilledButton(
                  onPressed:
                      sending
                          ? null
                          : () async {
                              final email =
                                  emailController
                                      .text
                                      .trim();

                              if (!_isValidEmail(
                                email,
                              )) {
                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text(
                                      'Please enter a valid email address.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(
                                () {
                                  sending =
                                      true;
                                },
                              );

                              try {
                                await Supabase
                                    .instance
                                    .client
                                    .auth
                                    .resetPasswordForEmail(
                                  email,
                                  redirectTo:
                                      _authRedirectUrl,
                                );

                                if (!dialogContext
                                    .mounted) {
                                  return;
                                }

                                Navigator.of(
                                  dialogContext,
                                ).pop(
                                  true,
                                );
                              } on AuthException catch (error) {
                                if (!dialogContext
                                    .mounted) {
                                  return;
                                }

                                setDialogState(
                                  () {
                                    sending =
                                        false;
                                  },
                                );

                                ScaffoldMessenger
                                    .of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(
                                      error.message,
                                    ),
                                  ),
                                );
                              } catch (error) {
                                debugPrint(
                                  'Password reset error: $error',
                                );

                                if (!dialogContext
                                    .mounted) {
                                  return;
                                }

                                setDialogState(
                                  () {
                                    sending =
                                        false;
                                  },
                                );

                                ScaffoldMessenger
                                    .of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text(
                                      'Unable to send the reset email.',
                                    ),
                                  ),
                                );
                              }
                            },
                  child:
                      sending
                          ? const SizedBox(
                              width:
                                  18,
                              height:
                                  18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Text(
                              'Send Email',
                            ),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();

    if (result == true &&
        mounted) {
      _showMessage(
        'Password reset email sent. Check your inbox.',
      );
    }
  }

  // ===========================================================================
  // REGISTER
  // ===========================================================================

  Future<void> _goToRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const RegisterScreen(),
      ),
    );
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  bool _isValidEmail(
    String email,
  ) {
    final pattern =
        RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return pattern.hasMatch(
      email,
    );
  }

  // ===========================================================================
  // AUTH ERROR
  // ===========================================================================

  String _friendlyAuthMessage(
    AuthException error,
  ) {
    final message =
        error.message.toLowerCase();

    if (message.contains(
          'email not confirmed',
        ) ||
        message.contains(
          'email_not_confirmed',
        )) {
      return 'Please confirm your email address before signing in.';
    }

    if (message.contains(
          'invalid login credentials',
        ) ||
        message.contains(
          'invalid_credentials',
        )) {
      return 'Incorrect email or password.';
    }

    if (message.contains(
          'user not found',
        )) {
      return 'No account was found with this email.';
    }

    return error.message;
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(message),
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      resizeToAvoidBottomInset:
          true,
      body:
          Container(
        width:
            double.infinity,
        height:
            double.infinity,
        decoration:
            const BoxDecoration(
          gradient:
              LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,
            colors: [
              Color(
                0xFFE0ECFF,
              ),
              Color(
                0xFFF5F7FA,
              ),
              Color(
                0xFFE8EEF7,
              ),
            ],
          ),
        ),
        child:
            SafeArea(
          child:
              LayoutBuilder(
            builder:
                (
              context,
              constraints,
            ) {
              final keyboardIsOpen =
                  Responsive
                      .keyboardIsOpen(
                context,
              );

              final horizontalPadding =
                  Responsive
                      .horizontalPadding(
                context,
              );

              final responsiveContentWidth =
                  Responsive
                      .contentWidth(
                context,
              );

              final availableWidth =
                  constraints
                      .maxWidth -
                  (horizontalPadding *
                      2);

              final contentWidth =
                  responsiveContentWidth >
                          availableWidth
                      ? availableWidth
                      : responsiveContentWidth;

              final cardPadding =
                  Responsive
                      .cardPadding(
                context,
              );

              final logoSize =
                  Responsive
                      .logoSize(
                context,
              );

              final cardRadius =
                  Responsive
                      .cardRadius(
                context,
              );

              final fieldHeight =
                  Responsive
                      .fieldHeight(
                context,
              );

              final buttonHeight =
                  Responsive
                      .buttonHeight(
                context,
              );

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,
                physics:
                    const ClampingScrollPhysics(),
                padding:
                    EdgeInsets.symmetric(
                  horizontal:
                      horizontalPadding,
                  vertical:
                      keyboardIsOpen
                          ? 12
                          : 20,
                ),
                child:
                    ConstrainedBox(
                  constraints:
                      BoxConstraints(
                    minHeight:
                        constraints
                                .maxHeight -
                            (keyboardIsOpen
                                ? 24
                                : 40),
                  ),
                  child:
                      Center(
                    child:
                        SizedBox(
                      width:
                          contentWidth,
                      child:
                          _buildContent(
                        context,
                        cardPadding:
                            cardPadding,
                        logoSize:
                            logoSize,
                        cardRadius:
                            cardRadius,
                        fieldHeight:
                            fieldHeight,
                        buttonHeight:
                            buttonHeight,
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

  // ===========================================================================
  // CONTENT
  // ===========================================================================

  Widget _buildContent(
    BuildContext context, {
    required double cardPadding,
    required double logoSize,
    required double cardRadius,
    required double fieldHeight,
    required double buttonHeight,
  }) {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        // =====================================================================
        // LOGO
        // =====================================================================

        Image.asset(
          AppBrand.logoPath,
          height:
              logoSize,
          fit:
              BoxFit.contain,
        ),

        SizedBox(
          height:
              Responsive.value<double>(
            context,
            phone:
                12,
            tablet:
                16,
            large:
                18,
          ),
        ),

        // =====================================================================
        // GLASS CARD
        // =====================================================================

        ClipRRect(
          borderRadius:
              BorderRadius.circular(
            cardRadius,
          ),
          child:
              BackdropFilter(
            filter:
                ImageFilter.blur(
              sigmaX:
                  12,
              sigmaY:
                  12,
            ),
            child:
                Container(
              width:
                  double.infinity,
              padding:
                  EdgeInsets.all(
                cardPadding,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white.withValues(
                  alpha:
                      0.35,
                ),
                borderRadius:
                    BorderRadius.circular(
                  cardRadius,
                ),
                border:
                    Border.all(
                  color:
                      Colors.white.withValues(
                    alpha:
                        0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(
                      alpha:
                          0.05,
                    ),
                    blurRadius:
                        20,
                    offset:
                        const Offset(
                      0,
                      8,
                    ),
                  ),
                ],
              ),
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ===========================================================
                  // TITLE
                  // ===========================================================

                  const SizedBox(
                    width:
                        double.infinity,
                    child:
                        AutoSizeText(
                      'Sign in to your Account',
                      maxLines:
                          1,
                      minFontSize:
                          20,
                      maxFontSize:
                          30,
                      stepGranularity:
                          1,
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        fontSize:
                            30,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(
                          0xFF151922,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.value<double>(
                      context,
                      phone:
                          8,
                      tablet:
                          10,
                      large:
                          12,
                    ),
                  ),

                  const SizedBox(
                    width:
                        double.infinity,
                    child:
                        Text(
                      'Enter your email and password to log in',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        fontSize:
                            14,
                        color:
                            Color(
                          0xFF707784,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.value<double>(
                      context,
                      phone:
                          24,
                      tablet:
                          28,
                      large:
                          32,
                    ),
                  ),

                  // ===========================================================
                  // EMAIL
                  // ===========================================================

                  const Text(
                    'Email',
                    style:
                        TextStyle(
                      fontSize:
                          15,
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Color(
                        0xFF252A34,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                        8,
                  ),

                  _buildTextField(
                    controller:
                        _emailController,
                    hint:
                        'Enter your email',
                    icon:
                        Icons
                            .email_outlined,
                    height:
                        fieldHeight,
                    keyboardType:
                        TextInputType.emailAddress,
                    textInputAction:
                        TextInputAction.next,
                  ),

                  SizedBox(
                    height:
                        Responsive.value<double>(
                      context,
                      phone:
                          18,
                      tablet:
                          20,
                      large:
                          22,
                    ),
                  ),

                  // ===========================================================
                  // PASSWORD
                  // ===========================================================

                  const Text(
                    'Password',
                    style:
                        TextStyle(
                      fontSize:
                          15,
                      fontWeight:
                          FontWeight.w600,
                      color:
                          Color(
                        0xFF252A34,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                        8,
                  ),

                  _buildPasswordField(
                    height:
                        fieldHeight,
                  ),

                  const SizedBox(
                    height:
                        10,
                  ),

                  // ===========================================================
                  // REMEMBER / FORGOT
                  // ===========================================================

                  Row(
                    children: [
                      SizedBox(
                        width:
                            24,
                        height:
                            24,
                        child:
                            Checkbox(
                          value:
                              _rememberMe,
                          onChanged:
                              (
                            value,
                          ) {
                            setState(() {
                              _rememberMe =
                                  value ??
                                      true;
                            });
                          },
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              4,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        width:
                            8,
                      ),

                      const Flexible(
                        child:
                            Text(
                          'Remember me',
                          style:
                              TextStyle(
                            fontSize:
                                14,
                            color:
                                Color(
                              0xFF606775,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        width:
                            8,
                      ),

                      TextButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _forgotPassword,
                        style:
                            TextButton.styleFrom(
                          padding:
                              EdgeInsets.zero,
                          minimumSize:
                              Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize
                                  .shrinkWrap,
                        ),
                        child:
                            Text(
                          'Forgot Password?',
                          style:
                              TextStyle(
                            fontSize:
                                14,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                AppColors
                                    .primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                        18,
                  ),

                  // ===========================================================
                  // LOGIN
                  // ===========================================================

                  SizedBox(
                    width:
                        double.infinity,
                    height:
                        buttonHeight,
                    child:
                        DecoratedBox(
                      decoration:
                          BoxDecoration(
                        gradient:
                            LinearGradient(
                          colors: [
                            AppColors
                                .primary,
                            AppColors
                                .primary
                                .withValues(
                              alpha:
                                  0.85,
                            ),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors
                                .primary
                                .withValues(
                              alpha:
                                  0.25,
                            ),
                            blurRadius:
                                12,
                            offset:
                                const Offset(
                              0,
                              6,
                            ),
                          ),
                        ],
                      ),
                      child:
                          ElevatedButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _login,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.transparent,
                          disabledBackgroundColor:
                              Colors.transparent,
                          shadowColor:
                              Colors.transparent,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),
                        child:
                            _isLoading
                                ? const SizedBox(
                                    width:
                                        22,
                                    height:
                                        22,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2.5,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Log In',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          17,
                                      fontWeight:
                                          FontWeight.w600,
                                      color:
                                          Colors.white,
                                    ),
                                  ),
                      ),
                    ),
                  ),

                  SizedBox(
                    height:
                        Responsive.value<double>(
                      context,
                      phone:
                          20,
                      tablet:
                          24,
                      large:
                          26,
                    ),
                  ),

                  // ===========================================================
                  // DIVIDER
                  // ===========================================================

                  Row(
                    children: [
                      Expanded(
                        child:
                            Divider(
                          color:
                              Colors.black.withValues(
                            alpha:
                                0.12,
                          ),
                        ),
                      ),
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          horizontal:
                              14,
                        ),
                        child:
                            Text(
                          'Or',
                          style:
                              TextStyle(
                            fontSize:
                                13,
                            color:
                                Color(
                              0xFF7A808B,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child:
                            Divider(
                          color:
                              Colors.black.withValues(
                            alpha:
                                0.12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                        18,
                  ),

                  // ===========================================================
                  // GOOGLE
                  // ===========================================================

                  _SocialButton(
                    icon:
                        const Text(
                      'G',
                      style:
                          TextStyle(
                        fontSize:
                            20,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(
                          0xFF4285F4,
                        ),
                      ),
                    ),
                    text:
                        'Continue with Google',
                    onPressed:
                        _isLoading
                            ? null
                            : _continueWithGoogle,
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(
          height:
              Responsive.value<double>(
            context,
            phone:
                16,
            tablet:
                22,
            large:
                28,
          ),
        ),

        // =====================================================================
        // REGISTER
        // =====================================================================

        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Flexible(
              child:
                  Text(
                "Don't have an account?",
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize:
                      13,
                  color:
                      Color(
                    0xFF707784,
                  ),
                ),
              ),
            ),
            const SizedBox(
              width:
                  5,
            ),
            TextButton(
              onPressed:
                  _isLoading
                      ? null
                      : _goToRegister,
              style:
                  TextButton.styleFrom(
                padding:
                    EdgeInsets.zero,
                minimumSize:
                    Size.zero,
                tapTargetSize:
                    MaterialTapTargetSize
                        .shrinkWrap,
              ),
              child:
                  Text(
                'Register',
                style:
                    TextStyle(
                  fontSize:
                      13,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // TEXT FIELD
  // ===========================================================================

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String hint,
    required IconData icon,
    required double height,
    TextInputType? keyboardType,
    TextInputAction?
        textInputAction,
  }) {
    return SizedBox(
      height:
          height,
      child:
          TextField(
        controller:
            controller,
        keyboardType:
            keyboardType,
        textInputAction:
            textInputAction,
        decoration:
            _inputDecoration(
          hint:
              hint,
          icon:
              icon,
        ),
      ),
    );
  }

  // ===========================================================================
  // PASSWORD FIELD
  // ===========================================================================

  Widget _buildPasswordField({
    required double height,
  }) {
    return SizedBox(
      height:
          height,
      child:
          TextField(
        controller:
            _passwordController,
        obscureText:
            !_isPasswordVisible,
        textInputAction:
            TextInputAction.done,
        onSubmitted:
            (_) => _login(),
        decoration:
            _inputDecoration(
          hint:
              'Enter your password',
          icon:
              Icons
                  .lock_outline_rounded,
          suffixIcon:
              IconButton(
            onPressed:
                () {
              setState(() {
                _isPasswordVisible =
                    !_isPasswordVisible;
              });
            },
            icon:
                Icon(
              _isPasswordVisible
                  ? Icons
                      .visibility_off_outlined
                  : Icons
                      .visibility_outlined,
              color:
                  const Color(
                0xFF606775,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // INPUT DECORATION
  // ===========================================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget?
        suffixIcon,
  }) {
    return InputDecoration(
      hintText:
          hint,
      prefixIcon:
          Icon(
        icon,
        color:
            const Color(
          0xFF606775,
        ),
      ),
      suffixIcon:
          suffixIcon,
      filled:
          true,
      fillColor:
          Colors.white.withValues(
        alpha:
            0.65,
      ),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal:
            16,
      ),
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        borderSide:
            BorderSide.none,
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        borderSide:
            BorderSide.none,
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        borderSide:
            BorderSide(
          color:
              AppColors.primary,
          width:
              1.5,
        ),
      ),
    );
  }
}

// ============================================================================
// SOCIAL BUTTON
// ============================================================================

class _SocialButton
    extends StatelessWidget {
  final Widget icon;
  final String text;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width:
          double.infinity,
      height:
          Responsive.buttonHeight(
        context,
      ),
      child:
          OutlinedButton(
        onPressed:
            onPressed,
        style:
            OutlinedButton.styleFrom(
          backgroundColor:
              Colors.white.withValues(
            alpha:
                0.55,
          ),
          side:
              BorderSide(
            color:
                Colors.black.withValues(
              alpha:
                  0.08,
            ),
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
        ),
        child:
            Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(
              width:
                  12,
            ),
            Flexible(
              child:
                  Text(
                text,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize:
                      15,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      Color(
                    0xFF252A34,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}