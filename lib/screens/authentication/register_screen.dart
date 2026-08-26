import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_brand.dart';
import '../../core/theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
  // ===========================================================================
  // CONSTANTS
  // ===========================================================================

  static const String _authRedirectUrl =
      'medidata26://auth-callback';

  // ===========================================================================
  // CONTROLLERS
  // ===========================================================================

  final _firstNameController =
      TextEditingController();

  final _lastNameController =
      TextEditingController();

  final _emailController =
      TextEditingController();

  final _dateOfBirthController =
      TextEditingController();

  final _phoneController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  // ===========================================================================
  // STATE
  // ===========================================================================

  bool _isPasswordVisible = false;

  bool _isLoading = false;

  bool _registrationSubmitted = false;

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _dateOfBirthController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // DATE PICKER
  // ===========================================================================

  Future<void>
      _selectDateOfBirth() async {
    FocusScope.of(context).unfocus();

    final now =
        DateTime.now();

    final initialDate =
        DateTime(
      now.year - 18,
      now.month,
      now.day,
    );

    final firstDate =
        DateTime(
      now.year - 100,
      now.month,
      now.day,
    );

    final lastDate =
        DateTime(
      now.year - 10,
      now.month,
      now.day,
    );

    final pickedDate =
        await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText:
          'Select your date of birth',
    );

    if (pickedDate == null ||
        !mounted) {
      return;
    }

    final formattedDate =
        '${pickedDate.day.toString().padLeft(2, '0')}/'
        '${pickedDate.month.toString().padLeft(2, '0')}/'
        '${pickedDate.year}';

    setState(() {
      _dateOfBirthController
          .text = formattedDate;
    });
  }

  // ===========================================================================
  // REGISTER
  // ===========================================================================

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final firstName =
        _firstNameController.text
            .trim();

    final lastName =
        _lastNameController.text
            .trim();

    final email =
        _emailController.text
            .trim();

    final dateOfBirthText =
        _dateOfBirthController.text
            .trim();

    final phone =
        _phoneController.text
            .trim();

    final password =
        _passwordController.text;

    // -------------------------------------------------------------------------
    // VALIDATION
    // -------------------------------------------------------------------------

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        dateOfBirthText.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      _showMessage(
        'Please complete all fields.',
      );

      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage(
        'Please enter a valid email address.',
      );

      return;
    }

    if (password.length < 6) {
      _showMessage(
        'Password must be at least 6 characters.',
      );

      return;
    }

    // -------------------------------------------------------------------------
    // DATE
    // -------------------------------------------------------------------------

    final dateParts =
        dateOfBirthText.split('/');

    if (dateParts.length != 3) {
      _showMessage(
        'Invalid date of birth.',
      );

      return;
    }

    final day =
        int.tryParse(
          dateParts[0],
        );

    final month =
        int.tryParse(
          dateParts[1],
        );

    final year =
        int.tryParse(
          dateParts[2],
        );

    if (day == null ||
        month == null ||
        year == null) {
      _showMessage(
        'Invalid date of birth.',
      );

      return;
    }

    final dateOfBirth =
        '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';

    // -------------------------------------------------------------------------
    // LOADING
    // -------------------------------------------------------------------------

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase =
          Supabase.instance.client;

      // -----------------------------------------------------------------------
      // CREATE ACCOUNT
      // -----------------------------------------------------------------------

      final response =
          await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo:
            _authRedirectUrl,
        data: {
          'first_name':
              firstName,
          'last_name':
              lastName,
          'full_name':
              '$firstName $lastName',
          'date_of_birth':
              dateOfBirth,
          'phone':
              phone,
          'role':
              'student',
        },
      );

      final user =
          response.user;

      if (user == null) {
        throw const AuthException(
          'Account could not be created.',
        );
      }

      if (!mounted) {
        return;
      }

      // -----------------------------------------------------------------------
      // EMAIL CONFIRMATION REQUIRED
      // -----------------------------------------------------------------------

      if (response.session ==
          null) {
        setState(() {
          _registrationSubmitted =
              true;
        });

        return;
      }

      // -----------------------------------------------------------------------
      // SESSION EXISTS
      //
      // This can happen when email confirmation
      // is disabled in Supabase.
      //
      // During production we expect confirmation
      // to be enabled, so this branch should not
      // be the normal registration path.
      // -----------------------------------------------------------------------

      _showMessage(
        'Account created successfully.',
      );

      Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message,
      );
    } catch (error) {
      debugPrint(
        'Registration error: $error',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Registration failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading =
              false;
        });
      }
    }
  }

  // ===========================================================================
  // EMAIL VALIDATION
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
  // RESEND CONFIRMATION EMAIL
  // ===========================================================================

  Future<void>
      _resendConfirmationEmail() async {
    final email =
        _emailController.text
            .trim();

    if (email.isEmpty ||
        !_isValidEmail(email)) {
      _showMessage(
        'Please enter a valid email address.',
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase
          .instance.client.auth
          .resend(
        type:
            OtpType.signup,
        email:
            email,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'A new confirmation email has been sent.',
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
        'Resend confirmation error: $error',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to resend confirmation email.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading =
              false;
        });
      }
    }
  }

  // ===========================================================================
  // LOGIN
  // ===========================================================================

  void _goToLogin() {
    Navigator.of(context).pop();
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
    if (_registrationSubmitted) {
      return _CheckEmailView(
        email:
            _emailController.text
                .trim(),
        isLoading:
            _isLoading,
        onResend:
            _resendConfirmationEmail,
        onBackToLogin:
            _goToLogin,
      );
    }

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

              final availableWidth =
                  constraints
                      .maxWidth -
                  (horizontalPadding *
                      2);

              final responsiveContentWidth =
                  Responsive
                      .contentWidth(
                context,
              );

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

              final cardRadius =
                  Responsive
                      .cardRadius(
                context,
              );

              final isVeryNarrow =
                  availableWidth <
                      360;

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
                          _buildRegisterContent(
                        context,
                        isVeryNarrow:
                            isVeryNarrow,
                        cardPadding:
                            cardPadding,
                        logoSize:
                            logoSize,
                        fieldHeight:
                            fieldHeight,
                        buttonHeight:
                            buttonHeight,
                        cardRadius:
                            cardRadius,
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
  // REGISTER CONTENT
  // ===========================================================================

  Widget _buildRegisterContent(
    BuildContext context, {
    required bool isVeryNarrow,
    required double cardPadding,
    required double logoSize,
    required double fieldHeight,
    required double buttonHeight,
    required double cardRadius,
  }) {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        // =====================================================================
        // BACK
        // =====================================================================

        Align(
          alignment:
              Alignment.centerLeft,
          child:
              IconButton(
            onPressed:
                _goToLogin,
            icon:
                const Icon(
              Icons
                  .arrow_back_rounded,
              size:
                  25,
              color:
                  Color(
                0xFF20242C,
              ),
            ),
            padding:
                EdgeInsets.zero,
            constraints:
                const BoxConstraints(),
          ),
        ),

        SizedBox(
          height:
              Responsive.value<double>(
            context,
            phone:
                8,
            tablet:
                12,
            large:
                16,
          ),
        ),

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
        // CARD
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
                          0.04,
                    ),
                    blurRadius:
                        18,
                    offset:
                        const Offset(
                      0,
                      6,
                    ),
                  ),
                ],
              ),
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  // ===========================================================
                  // TITLE
                  // ===========================================================

                  const SizedBox(
                    width:
                        double.infinity,
                    child:
                        AutoSizeText(
                      'Create your Account',
                      maxLines:
                          1,
                      minFontSize:
                          21,
                      maxFontSize:
                          29,
                      stepGranularity:
                          1,
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        fontSize:
                            29,
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
                          6,
                      tablet:
                          8,
                      large:
                          10,
                    ),
                  ),

                  const SizedBox(
                    width:
                        double.infinity,
                    child:
                        Text(
                      'Create an account to continue!',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        fontSize:
                            13,
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
                          18,
                      tablet:
                          22,
                      large:
                          24,
                    ),
                  ),

                  // ===========================================================
                  // FIRST / LAST NAME
                  // ===========================================================

                  if (isVeryNarrow)
                    Column(
                      children: [
                        _buildField(
                          label:
                              'First Name',
                          controller:
                              _firstNameController,
                          hint:
                              'First name',
                          icon:
                              Icons
                                  .person_outline_rounded,
                          height:
                              fieldHeight,
                          keyboardType:
                              TextInputType
                                  .name,
                        ),
                        const SizedBox(
                          height:
                              10,
                        ),
                        _buildField(
                          label:
                              'Last Name',
                          controller:
                              _lastNameController,
                          hint:
                              'Last name',
                          icon:
                              Icons
                                  .person_outline_rounded,
                          height:
                              fieldHeight,
                          keyboardType:
                              TextInputType
                                  .name,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child:
                              _buildField(
                            label:
                                'First Name',
                            controller:
                                _firstNameController,
                            hint:
                                'First name',
                            icon:
                                Icons
                                    .person_outline_rounded,
                            height:
                                fieldHeight,
                            keyboardType:
                                TextInputType
                                    .name,
                          ),
                        ),
                        const SizedBox(
                          width:
                              10,
                        ),
                        Expanded(
                          child:
                              _buildField(
                            label:
                                'Last Name',
                            controller:
                                _lastNameController,
                            hint:
                                'Last name',
                            icon:
                                Icons
                                    .person_outline_rounded,
                            height:
                                fieldHeight,
                            keyboardType:
                                TextInputType
                                    .name,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  // ===========================================================
                  // EMAIL
                  // ===========================================================

                  _buildField(
                    label:
                        'Email',
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
                        TextInputType
                            .emailAddress,
                    textInputAction:
                        TextInputAction
                            .next,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  // ===========================================================
                  // DOB
                  // ===========================================================

                  _buildDateField(
                    height:
                        fieldHeight,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  // ===========================================================
                  // PHONE
                  // ===========================================================

                  _buildField(
                    label:
                        'Phone',
                    controller:
                        _phoneController,
                    hint:
                        'Enter your phone number',
                    icon:
                        Icons
                            .phone_outlined,
                    height:
                        fieldHeight,
                    keyboardType:
                        TextInputType
                            .phone,
                    textInputAction:
                        TextInputAction
                            .next,
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  // ===========================================================
                  // PASSWORD
                  // ===========================================================

                  _buildPasswordField(
                    height:
                        fieldHeight,
                  ),

                  SizedBox(
                    height:
                        Responsive.value<double>(
                      context,
                      phone:
                          16,
                      tablet:
                          18,
                      large:
                          20,
                    ),
                  ),

                  // ===========================================================
                  // REGISTER BUTTON
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
                            AppColors.primary,
                            AppColors.primary
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
                            color: AppColors.primary
                                .withValues(
                              alpha:
                                  0.18,
                            ),
                            blurRadius:
                                10,
                            offset:
                                const Offset(
                              0,
                              5,
                            ),
                          ),
                        ],
                      ),
                      child:
                          ElevatedButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _register,
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
                                        21,
                                    height:
                                        21,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2.5,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Register',
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
        // LOGIN
        // =====================================================================

        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Flexible(
              child:
                  Text(
                'Already have an account?',
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
                  _goToLogin,
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
                'Log In',
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
  // GENERIC FIELD
  // ===========================================================================

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required double height,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              const TextStyle(
            fontSize:
                14,
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
              7,
        ),
        SizedBox(
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
        ),
      ],
    );
  }

  // ===========================================================================
  // DATE FIELD
  // ===========================================================================

  Widget _buildDateField({
    required double height,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth',
          style:
              TextStyle(
            fontSize:
                14,
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
              7,
        ),
        SizedBox(
          height:
              height,
          child:
              TextField(
            controller:
                _dateOfBirthController,
            readOnly:
                true,
            onTap:
                _selectDateOfBirth,
            decoration:
                _inputDecoration(
              hint:
                  'DD/MM/YYYY',
              icon:
                  Icons
                      .calendar_today_outlined,
              suffixIcon:
                  const Icon(
                Icons
                    .arrow_drop_down_rounded,
                color:
                    Color(
                  0xFF606775,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // PASSWORD
  // ===========================================================================

  Widget _buildPasswordField({
    required double height,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style:
              TextStyle(
            fontSize:
                14,
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
              7,
        ),
        SizedBox(
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
                (_) => _register(),
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
        ),
      ],
    );
  }

  // ===========================================================================
  // INPUT DECORATION
  // ===========================================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
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
// CHECK EMAIL VIEW
// ============================================================================

class _CheckEmailView
    extends StatelessWidget {
  final String email;

  final bool isLoading;

  final Future<void>
      Function()
      onResend;

  final VoidCallback
      onBackToLogin;

  const _CheckEmailView({
    required this.email,
    required this.isLoading,
    required this.onResend,
    required this.onBackToLogin,
  });

  @override
  Widget build(
    BuildContext context,
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

    final cardPadding =
        Responsive
            .cardPadding(
      context,
    );

    final cardRadius =
        Responsive
            .cardRadius(
      context,
    );

    return Scaffold(
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
              final availableWidth =
                  constraints
                      .maxWidth -
                  (horizontalPadding *
                      2);

              final width =
                  contentWidth >
                          availableWidth
                      ? availableWidth
                      : contentWidth;

              return SingleChildScrollView(
                padding:
                    EdgeInsets.symmetric(
                  horizontal:
                      horizontalPadding,
                  vertical:
                      24,
                ),
                child:
                    ConstrainedBox(
                  constraints:
                      BoxConstraints(
                    minHeight:
                        constraints
                            .maxHeight -
                        48,
                  ),
                  child:
                      Center(
                    child:
                        SizedBox(
                      width:
                          width,
                      child:
                          ClipRRect(
                        borderRadius:
                            BorderRadius
                                .circular(
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
                            padding:
                                EdgeInsets.all(
                              cardPadding,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.white.withValues(
                                alpha:
                                    0.40,
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
                                      0.55,
                                ),
                              ),
                            ),
                            child:
                                Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Container(
                                  width:
                                      82,
                                  height:
                                      82,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        AppColors.primary.withValues(
                                      alpha:
                                          0.10,
                                    ),
                                    shape:
                                        BoxShape.circle,
                                  ),
                                  child:
                                      Icon(
                                    Icons
                                        .mark_email_read_outlined,
                                    size:
                                        42,
                                    color:
                                        AppColors.primary,
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      24,
                                ),

                                const Text(
                                  'Check your email',
                                  textAlign:
                                      TextAlign.center,
                                  style:
                                      TextStyle(
                                    fontSize:
                                        27,
                                    fontWeight:
                                        FontWeight.w800,
                                    color:
                                        Color(
                                      0xFF151922,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      12,
                                ),

                                Text(
                                  'We sent a confirmation link to:',
                                  textAlign:
                                      TextAlign.center,
                                  style:
                                      TextStyle(
                                    fontSize:
                                        14,
                                    color:
                                        const Color(
                                      0xFF707784,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      8,
                                ),

                                Text(
                                  email,
                                  textAlign:
                                      TextAlign.center,
                                  style:
                                      TextStyle(
                                    fontSize:
                                        15,
                                    fontWeight:
                                        FontWeight.w700,
                                    color:
                                        AppColors.primary,
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      16,
                                ),

                                const Text(
                                  'Open your email and tap the confirmation link to activate your account. After confirmation, the link will return you to MediData.',
                                  textAlign:
                                      TextAlign.center,
                                  style:
                                      TextStyle(
                                    fontSize:
                                        14,
                                    height:
                                        1.5,
                                    color:
                                        Color(
                                      0xFF606775,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      26,
                                ),

                                SizedBox(
                                  width:
                                      double.infinity,
                                  height:
                                      Responsive.buttonHeight(
                                    context,
                                  ),
                                  child:
                                      FilledButton.icon(
                                    onPressed:
                                        isLoading
                                            ? null
                                            : onResend,
                                    icon:
                                        isLoading
                                            ? const SizedBox(
                                                width:
                                                    18,
                                                height:
                                                    18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth:
                                                      2,
                                                  color:
                                                      Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Icons
                                                    .refresh_rounded,
                                              ),
                                    label:
                                        Text(
                                      isLoading
                                          ? 'Sending...'
                                          : 'Resend confirmation email',
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      12,
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
                                        onBackToLogin,
                                    child:
                                        const Text(
                                      'Back to Login',
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  height:
                                      18,
                                ),

                                Text(
                                  'Check your Spam or Junk folder if you do not see the email.',
                                  textAlign:
                                      TextAlign.center,
                                  style:
                                      TextStyle(
                                    fontSize:
                                        12,
                                    color:
                                        const Color(
                                      0xFF707784,
                                    ).withValues(
                                      alpha:
                                          0.85,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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