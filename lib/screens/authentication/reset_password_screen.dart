import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_colors.dart';

class ResetPasswordScreen
    extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
  });

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  final TextEditingController
      _passwordController =
      TextEditingController();

  final TextEditingController
      _confirmController =
      TextEditingController();

  bool _showPassword =
      false;

  bool _showConfirm =
      false;

  bool _isLoading =
      false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // UPDATE PASSWORD
  // ==========================================================================

  Future<void> _updatePassword() async {
    FocusScope.of(context).unfocus();

    final password =
        _passwordController.text;

    final confirm =
        _confirmController.text;

    if (password.length < 6) {
      _showMessage(
        'Password must be at least 6 characters.',
      );
      return;
    }

    if (password != confirm) {
      _showMessage(
        'Passwords do not match.',
      );
      return;
    }

    if (Supabase.instance.client.auth
            .currentSession ==
        null) {
      _showMessage(
        'Your recovery session is no longer valid. Please request a new reset link.',
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
          .updateUser(
        UserAttributes(
          password:
              password,
        ),
      );

      await Supabase.instance.client
          .auth
          .signOut();

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context:
            context,
        barrierDismissible:
            false,
        builder:
            (
          dialogContext,
        ) {
          return AlertDialog(
            icon:
                const Icon(
              Icons
                  .check_circle_rounded,
              color:
                  Colors.green,
              size:
                  52,
            ),
            title:
                const Text(
              'Password Updated',
            ),
            content:
                const Text(
              'Your password has been updated successfully. You can now sign in with your new password.',
              textAlign:
                  TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed:
                    () {
                  Navigator.of(
                    dialogContext,
                  ).pop();
                },
                child:
                    const Text(
                  'Continue',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).popUntil(
        (
          route,
        ) =>
            route.isFirst,
      );
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
        'Reset password error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to update your password. Please try again.',
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

  // ==========================================================================
  // MESSAGE
  // ==========================================================================

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

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return PopScope(
      canPop:
          false,
      child:
          Scaffold(
        appBar:
            AppBar(
          title:
              const Text(
            'Reset Password',
          ),
          automaticallyImplyLeading:
              false,
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
                        24,
                    min:
                        16,
                    max:
                        32,
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
                        Card(
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
                                      80,
                                  min:
                                      68,
                                  max:
                                      104,
                                ),
                                height:
                                    Responsive.clamped(
                                  context,
                                  base:
                                      80,
                                  min:
                                      68,
                                  max:
                                      104,
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
                                      BoxShape
                                          .circle,
                                ),
                                child:
                                    Icon(
                                  Icons
                                      .lock_reset_rounded,
                                  size:
                                      Responsive.clamped(
                                    context,
                                    base:
                                        42,
                                    min:
                                        34,
                                    max:
                                        54,
                                  ),
                                  color:
                                      AppColors
                                          .primary,
                                ),
                              ),
                            ),

                            const SizedBox(
                              height:
                                  22,
                            ),

                            Text(
                              'Create a new password',
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
                                    FontWeight
                                        .w800,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  10,
                            ),

                            Text(
                              'Choose a strong password for your MediData account.',
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
                                  26,
                            ),

                            const Text(
                              'New Password',
                              style:
                                  TextStyle(
                                fontSize:
                                    14,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  8,
                            ),

                            TextField(
                              controller:
                                  _passwordController,
                              enabled:
                                  !_isLoading,
                              obscureText:
                                  !_showPassword,
                              decoration:
                                  InputDecoration(
                                hintText:
                                    'Enter new password',
                                prefixIcon:
                                    const Icon(
                                  Icons
                                      .lock_outline_rounded,
                                ),
                                suffixIcon:
                                    IconButton(
                                  onPressed:
                                      _isLoading
                                          ? null
                                          : () {
                                              setState(
                                                () {
                                                  _showPassword =
                                                      !_showPassword;
                                                },
                                              );
                                            },
                                  icon:
                                      Icon(
                                    _showPassword
                                        ? Icons
                                            .visibility_off_outlined
                                        : Icons
                                            .visibility_outlined,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              height:
                                  14,
                            ),

                            const Text(
                              'Confirm Password',
                              style:
                                  TextStyle(
                                fontSize:
                                    14,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  8,
                            ),

                            TextField(
                              controller:
                                  _confirmController,
                              enabled:
                                  !_isLoading,
                              obscureText:
                                  !_showConfirm,
                              textInputAction:
                                  TextInputAction
                                      .done,
                              onSubmitted:
                                  (_) =>
                                      _updatePassword(),
                              decoration:
                                  InputDecoration(
                                hintText:
                                    'Confirm new password',
                                prefixIcon:
                                    const Icon(
                                  Icons
                                      .lock_outline_rounded,
                                ),
                                suffixIcon:
                                    IconButton(
                                  onPressed:
                                      _isLoading
                                          ? null
                                          : () {
                                              setState(
                                                () {
                                                  _showConfirm =
                                                      !_showConfirm;
                                                },
                                              );
                                            },
                                  icon:
                                      Icon(
                                    _showConfirm
                                        ? Icons
                                            .visibility_off_outlined
                                        : Icons
                                            .visibility_outlined,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(
                              height:
                                  22,
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
                                        : _updatePassword,
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
                                            'Update Password',
                                          ),
                              ),
                            ),
                          ],
                        ),
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