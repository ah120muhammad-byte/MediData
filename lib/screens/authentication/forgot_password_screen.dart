import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';
import 'auth_config.dart';

class ForgotPasswordScreen
    extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
  });

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController =
      TextEditingController();

  bool _isLoading =
      false;

  bool _emailSent =
      false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    FocusScope.of(context).unfocus();

    final email =
        _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        'Please enter your email address.',
      );
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage(
        'Please enter a valid email address.',
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading =
          true;
    });

    try {
      await Supabase.instance.client
          .auth
          .resetPasswordForEmail(
        email,
        redirectTo:
            AuthConfig.redirectUrl,
      );

      if (mounted) {
        setState(() {
          _emailSent =
              true;
        });
      }
    } on AuthException catch (
      error
    ) {
      if (mounted) {
        _showMessage(
          error.message,
        );
      }
    } catch (error) {
      debugPrint(
        'Password reset email error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to send the reset email. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading =
              false;
        });
      }
    }
  }

  bool _isValidEmail(
    String email,
  ) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

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

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'Forgot Password',
        ),
      ),
      body:
          SafeArea(
        child:
            LayoutBuilder(
          builder:
              (
            context,
            constraints,
          ) {
            final horizontalPadding =
                Responsive
                    .horizontalPadding(
              context,
            );

            final contentWidth =
                Responsive
                    .contentWidth(
              context,
            );

            final availableWidth =
                constraints.maxWidth -
                    horizontalPadding *
                        2;

            final width =
                contentWidth <
                        availableWidth
                    ? contentWidth
                    : availableWidth;

            return SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),
              padding:
                  EdgeInsets.fromLTRB(
                horizontalPadding,
                Responsive.spacing(
                  context,
                  base:
                      20,
                  min:
                      14,
                  max:
                      30,
                ),
                horizontalPadding,
                Responsive.scrollBottomPadding(
                  context,
                  base:
                      30,
                ),
              ),
              child:
                  Center(
                child:
                    SizedBox(
                  width:
                      width,
                  child:
                      _emailSent
                          ? _buildSuccess(
                              context,
                            )
                          : _buildForm(
                              context,
                            ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
  ) {
    return Card(
      elevation:
          0,
      child:
          Padding(
        padding:
            EdgeInsets.all(
          Responsive.cardPadding(
            context,
          ),
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            Center(
              child:
                  Container(
                width:
                    Responsive.clamped(
                  context,
                  base:
                      78,
                  min:
                      66,
                  max:
                      100,
                ),
                height:
                    Responsive.clamped(
                  context,
                  base:
                      78,
                  min:
                      66,
                  max:
                      100,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .primary
                          .withValues(
                    alpha:
                        0.10,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    Icon(
                  Icons
                      .lock_reset_rounded,
                  size:
                      Responsive.clamped(
                    context,
                    base:
                        40,
                    min:
                        34,
                    max:
                        52,
                  ),
                  color:
                      AppColors
                          .primary,
                ),
              ),
            ),

            const SizedBox(
              height:
                  20,
            ),

            Text(
              'Reset your password',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    Responsive.titleSize(
                  context,
                  base:
                      24,
                  min:
                      21,
                  max:
                      31,
                ),
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            Text(
              'Enter your email address and we will send you a secure password reset link.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    Responsive.bodyTextSize(
                  context,
                  base:
                      14,
                  min:
                      12,
                  max:
                      17,
                ),
                height:
                    1.45,
                color:
                    Theme.of(
                  context,
                )
                        .colorScheme
                        .onSurface
                        .withValues(
                  alpha:
                      0.60,
                ),
              ),
            ),

            const SizedBox(
              height:
                  24,
            ),

            const Text(
              'Email',
              style:
                  TextStyle(
                fontSize:
                    14,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            TextField(
              controller:
                  _emailController,
              enabled:
                  !_isLoading,
              keyboardType:
                  TextInputType
                      .emailAddress,
              textInputAction:
                  TextInputAction
                      .done,
              onSubmitted:
                  (_) =>
                      _sendResetEmail(),
              decoration:
                  const InputDecoration(
                hintText:
                    'Enter your email',
                prefixIcon:
                    Icon(
                  Icons
                      .email_outlined,
                ),
              ),
            ),

            const SizedBox(
              height:
                  18,
            ),

            SizedBox(
              height:
                  Responsive.buttonHeight(
                context,
              ),
              child:
                  FilledButton(
                onPressed:
                    _isLoading
                        ? null
                        : _sendResetEmail,
                child:
                    _isLoading
                        ? const SizedBox(
                            width:
                                21,
                            height:
                                21,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2.4,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Send Reset Link',
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(
    BuildContext context,
  ) {
    return Card(
      elevation:
          0,
      child:
          Padding(
        padding:
            EdgeInsets.all(
          Responsive.cardPadding(
            context,
          ),
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .mark_email_read_rounded,
              color:
                  Colors.green,
              size:
                  76,
            ),

            const SizedBox(
              height:
                  22,
            ),

            Text(
              'Check your email',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    Responsive.titleSize(
                  context,
                  base:
                      24,
                  min:
                      21,
                  max:
                      31,
                ),
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height:
                  10,
            ),

            const Text(
              'We sent a password reset link to:',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height:
                  7,
            ),

            Text(
              _emailController
                  .text
                  .trim(),
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w700,
                color:
                    AppColors
                        .primary,
              ),
            ),

            const SizedBox(
              height:
                  16,
            ),

            const Text(
              'Open the email and follow the link to choose your new password.',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height:
                  24,
            ),

            SizedBox(
              width:
                  double.infinity,
              height:
                  Responsive.buttonHeight(
                context,
              ),
              child:
                  OutlinedButton(
                onPressed:
                    () {
                  setState(() {
                    _emailSent =
                        false;
                  });
                },
                child:
                    const Text(
                  'Use another email',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}