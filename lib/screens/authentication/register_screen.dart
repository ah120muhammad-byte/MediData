import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive/responsive.dart';
import '../../core/theme/app_brand.dart';
import '../../core/theme/app_colors.dart';
import 'auth_config.dart';

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

  bool _isPasswordVisible =
      false;

  bool _isLoading =
      false;

  bool _registrationSubmitted =
      false;

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

  // ==========================================================================
  // DATE
  // ==========================================================================

  Future<void>
      _selectDateOfBirth() async {
    FocusScope.of(context).unfocus();

    final now =
        DateTime.now();

    final pickedDate =
        await showDatePicker(
      context: context,
      initialDate:
          DateTime(
        now.year - 18,
        now.month,
        now.day,
      ),
      firstDate:
          DateTime(
        now.year - 100,
        now.month,
        now.day,
      ),
      lastDate:
          DateTime(
        now.year - 10,
        now.month,
        now.day,
      ),
      helpText:
          'Select your date of birth',
    );

    if (pickedDate == null ||
        !mounted) {
      return;
    }

    setState(() {
      _dateOfBirthController.text =
          '${pickedDate.day.toString().padLeft(2, '0')}/'
          '${pickedDate.month.toString().padLeft(2, '0')}/'
          '${pickedDate.year}';
    });
  }

  // ==========================================================================
  // REGISTER
  // ==========================================================================

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

    final dob =
        _dateOfBirthController.text
            .trim();

    final phone =
        _phoneController.text
            .trim();

    final password =
        _passwordController.text;

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        dob.isEmpty ||
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

    final parts =
        dob.split('/');

    if (parts.length != 3) {
      _showMessage(
        'Invalid date of birth.',
      );
      return;
    }

    final day =
        int.tryParse(parts[0]);

    final month =
        int.tryParse(parts[1]);

    final year =
        int.tryParse(parts[2]);

    if (day == null ||
        month == null ||
        year == null) {
      _showMessage(
        'Invalid date of birth.',
      );
      return;
    }

    final parsed =
        DateTime(
      year,
      month,
      day,
    );

    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      _showMessage(
        'Invalid date of birth.',
      );
      return;
    }

    final dateOfBirth =
        '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading =
          true;
    });

    try {
      final supabase =
          Supabase.instance.client;

      final response =
          await supabase.auth.signUp(
        email:
            email,
        password:
            password,
        emailRedirectTo:
            AuthConfig.redirectUrl,
        data: {
          'first_name':
              firstName,
          'last_name':
              lastName,
          'full_name':
              '$firstName $lastName',
          'date_of_birth':
              dateOfBirth,

          // Important:
          // This is PROFILE DATA only.
          // It is NOT Supabase Auth phone.
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

      // ----------------------------------------------------------------------
      // Email must be confirmed.
      // ----------------------------------------------------------------------

      if (user.emailConfirmedAt ==
          null) {
        if (response.session !=
            null) {
          try {
            await supabase.auth
                .signOut();
          } catch (e) {
            debugPrint(
              'Signup session cleanup error: $e',
            );
          }
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _registrationSubmitted =
              true;
        });

        return;
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        'Account created successfully.',
      );

      Navigator.of(context)
          .pop();
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
        'Registration error: $error',
      );

      if (mounted) {
        _showMessage(
          'Registration failed. Please try again.',
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
  // RESEND
  // ==========================================================================

  Future<void>
      _resendConfirmationEmail() async {
    final email =
        _emailController.text
            .trim();

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
          .resend(
        type:
            OtpType.signup,
        email:
            email,
      );

      if (mounted) {
        _showMessage(
          'A new confirmation email has been sent.',
        );
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
        'Resend confirmation error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to resend confirmation email.',
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
  // VALIDATION
  // ==========================================================================

  bool _isValidEmail(
    String email,
  ) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

  void _goToLogin() {
    Navigator.of(context)
        .pop();
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

    final horizontalPadding =
        Responsive.horizontalPadding(
      context,
    );

    final contentWidth =
        Responsive.contentWidth(
      context,
    );

    final cardPadding =
        Responsive.cardPadding(
      context,
    );

    final fieldHeight =
        Responsive.fieldHeight(
      context,
    );

    final buttonHeight =
        Responsive.buttonHeight(
      context,
    );

    final cardRadius =
        Responsive.cardRadius(
      context,
    );

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

              final availableWidth =
                  constraints.maxWidth -
                  horizontalPadding *
                      2;

              final width =
                  contentWidth <
                          availableWidth
                      ? contentWidth
                      : availableWidth;

              final narrow =
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
                    Center(
                  child:
                      SizedBox(
                    width:
                        width,
                    child:
                        Column(
                      children: [
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
                            ),
                          ),
                        ),

                        Image.asset(
                          AppBrand
                              .logoPath,
                          height:
                              Responsive
                                  .logoSize(
                            context,
                          ),
                        ),

                        const SizedBox(
                          height:
                              14,
                        ),

                        Container(
                          padding:
                              EdgeInsets.all(
                            cardPadding,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white
                                    .withValues(
                              alpha:
                                  0.92,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              cardRadius,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black
                                        .withValues(
                                  alpha:
                                      0.05,
                                ),
                                blurRadius:
                                    22,
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
                                CrossAxisAlignment
                                    .stretch,
                            children: [
                              const AutoSizeText(
                                'Create your Account',
                                maxLines:
                                    1,
                                minFontSize:
                                    21,
                                maxFontSize:
                                    29,
                                textAlign:
                                    TextAlign
                                        .center,
                                style:
                                    TextStyle(
                                  fontSize:
                                      29,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const SizedBox(
                                height:
                                    7,
                              ),

                              const Text(
                                'Create an account to continue!',
                                textAlign:
                                    TextAlign
                                        .center,
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

                              const SizedBox(
                                height:
                                    20,
                              ),

                              if (narrow)
                                Column(
                                  children: [
                                    _field(
                                      label:
                                          'First Name',
                                      controller:
                                          _firstNameController,
                                      hint:
                                          'First name',
                                      icon:
                                          Icons
                                              .person_outline,
                                      height:
                                          fieldHeight,
                                      keyboardType:
                                          TextInputType
                                              .name,
                                    ),
                                    const SizedBox(
                                      height:
                                          12,
                                    ),
                                    _field(
                                      label:
                                          'Last Name',
                                      controller:
                                          _lastNameController,
                                      hint:
                                          'Last name',
                                      icon:
                                          Icons
                                              .person_outline,
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
                                          _field(
                                        label:
                                            'First Name',
                                        controller:
                                            _firstNameController,
                                        hint:
                                            'First name',
                                        icon:
                                            Icons
                                                .person_outline,
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
                                          _field(
                                        label:
                                            'Last Name',
                                        controller:
                                            _lastNameController,
                                        hint:
                                            'Last name',
                                        icon:
                                            Icons
                                                .person_outline,
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

                              _field(
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
                              ),

                              const SizedBox(
                                height:
                                    12,
                              ),

                              _dateField(
                                height:
                                    fieldHeight,
                              ),

                              const SizedBox(
                                height:
                                    12,
                              ),

                              _field(
                                label:
                                    'Phone',
                                controller:
                                    _phoneController,
                                hint:
                                    'Phone number',
                                icon:
                                    Icons
                                        .phone_outlined,
                                height:
                                    fieldHeight,
                                keyboardType:
                                    TextInputType
                                        .phone,
                              ),

                              const SizedBox(
                                height:
                                    12,
                              ),

                              _passwordField(
                                height:
                                    fieldHeight,
                              ),

                              const SizedBox(
                                height:
                                    18,
                              ),

                              SizedBox(
                                height:
                                    buttonHeight,
                                child:
                                    FilledButton(
                                  onPressed:
                                      _isLoading
                                          ? null
                                          : _register,
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
                                              'Register',
                                            ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height:
                              16,
                        ),

                        Wrap(
                          alignment:
                              WrapAlignment
                                  .center,
                          children: [
                            const Text(
                              'Already have an account? ',
                            ),
                            TextButton(
                              onPressed:
                                  _goToLogin,
                              child:
                                  Text(
                                'Log In',
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                  color:
                                      AppColors
                                          .primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _field({
    required String label,
    required TextEditingController
        controller,
    required String hint,
    required IconData icon,
    required double height,
    TextInputType? keyboardType,
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
            decoration:
                InputDecoration(
              hintText:
                  hint,
              prefixIcon:
                  Icon(
                icon,
              ),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),
                borderSide:
                    BorderSide.none,
              ),
              filled:
                  true,
              fillColor:
                  const Color(
                0xFFF8F9FB,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateField({
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
                const InputDecoration(
              hintText:
                  'DD/MM/YYYY',
              prefixIcon:
                  Icon(
                Icons
                    .calendar_today_outlined,
              ),
              border:
                  OutlineInputBorder(
                borderSide:
                    BorderSide.none,
              ),
              filled:
                  true,
              fillColor:
                  Color(
                0xFFF8F9FB,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _passwordField({
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
            onSubmitted:
                (_) => _register(),
            decoration:
                InputDecoration(
              hintText:
                  'Enter your password',
              prefixIcon:
                  const Icon(
                Icons
                    .lock_outline_rounded,
              ),
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
                ),
              ),
              border:
                  const OutlineInputBorder(
                borderSide:
                    BorderSide.none,
              ),
              filled:
                  true,
              fillColor:
                  const Color(
                0xFFF8F9FB,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CHECK EMAIL
// ============================================================================

class _CheckEmailView
    extends StatelessWidget {
  final String email;
  final bool isLoading;
  final Future<void>
      Function() onResend;
  final VoidCallback onBackToLogin;

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
    return Scaffold(
      body:
          SafeArea(
        child:
            Center(
          child:
              SingleChildScrollView(
            padding:
                EdgeInsets.all(
              Responsive.cardPadding(
                context,
              ),
            ),
            child:
                ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth:
                    620,
              ),
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
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons
                            .mark_email_read_outlined,
                        size:
                            Responsive.clamped(
                          context,
                          base:
                              80,
                          min:
                              64,
                          max:
                              104,
                        ),
                        color:
                            AppColors
                                .primary,
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
                                27,
                            min:
                                22,
                            max:
                                34,
                          ),
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                      const SizedBox(
                        height:
                            12,
                      ),
                      const Text(
                        'We sent a confirmation link to:',
                        textAlign:
                            TextAlign.center,
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
                          fontWeight:
                              FontWeight
                                  .w700,
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
                        'Open the email and tap the confirmation link to activate your account. After confirmation, the link will return you to MediData.',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          height:
                              1.5,
                        ),
                      ),
                      const SizedBox(
                        height:
                            24,
                      ),
                      SizedBox(
                        width:
                            double.infinity,
                        height:
                            Responsive
                                .buttonHeight(
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
                            Responsive
                                .buttonHeight(
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}