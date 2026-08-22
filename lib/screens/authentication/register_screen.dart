import 'dart:ui';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_brand.dart';
import '../../core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/responsive/responsive.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

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
  // DATE PICKER
  // ==========================================================================

  Future<void> _selectDateOfBirth() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();

    final initialDate = DateTime(now.year - 18, now.month, now.day);

    final firstDate = DateTime(now.year - 100, now.month, now.day);

    final lastDate = DateTime(now.year - 10, now.month, now.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select your date of birth',
    );

    if (pickedDate == null) return;

    final formattedDate =
        '${pickedDate.day.toString().padLeft(2, '0')}/'
        '${pickedDate.month.toString().padLeft(2, '0')}/'
        '${pickedDate.year}';

    setState(() {
      _dateOfBirthController.text = formattedDate;
    });
  }

  // ==========================================================================
  // REGISTER
  // ==========================================================================

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    // ============================================================
    // VALIDATION
    // ============================================================

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final dateOfBirthText = _dateOfBirthController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        dateOfBirthText.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );

      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
        ),
      );

      return;
    }

    // ============================================================
    // CONVERT DATE
    // DD/MM/YYYY -> YYYY-MM-DD
    // ============================================================

    final dateParts = dateOfBirthText.split('/');

    if (dateParts.length != 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid date of birth.')));

      return;
    }

    final dateOfBirth =
        '${dateParts[2]}-${dateParts[1].padLeft(2, '0')}-${dateParts[0].padLeft(2, '0')}';

    // ============================================================
    // START LOADING
    // ============================================================

    setState(() {
      _isLoading = true;
    });

    try {
      // ==========================================================
      // SUPABASE AUTH
      // ==========================================================

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'full_name': '$firstName $lastName',
          'date_of_birth': dateOfBirth,
          'phone': phone,
          'role': 'student',
        },
      );

      final user = response.user;

      if (user == null) {
        throw Exception('Account could not be created.');
      }

      if (!mounted) return;

      // ==========================================================
      // EMAIL CONFIRMATION
      // ==========================================================

      final session = response.session;

      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created successfully. Please check your email to confirm your account.',
            ),
          ),
         );

        Navigator.of(context).pop();
        return;
      }

      // ==========================================================
      // ACCOUNT CREATED + SESSION AVAILABLE
      // ==========================================================

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );

      Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $error')));
    } finally {
  if (mounted) {
    setState(() {
      _isLoading = false;
    });
  }
}
  }

  // ==========================================================================
  // LOGIN
  // ==========================================================================

  void _goToLogin() {
    Navigator.of(context).pop();
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

              final availableWidth =
                  constraints.maxWidth - (horizontalPadding * 2);

              final responsiveContentWidth = Responsive.contentWidth(context);

              final contentWidth = responsiveContentWidth > availableWidth
                  ? availableWidth
                  : responsiveContentWidth;

              final cardPadding = Responsive.cardPadding(context);

              final logoSize = Responsive.logoSize(context);

              final fieldHeight = Responsive.fieldHeight(context);

              final buttonHeight = Responsive.buttonHeight(context);

              final cardRadius = Responsive.cardRadius(context);

              final isVeryNarrow = availableWidth < 360;

              final content = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ============================================================
                  // BACK BUTTON
                  // ============================================================
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _goToLogin,
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 25,
                        color: Color(0xFF20242C),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),

                  SizedBox(
                    height: Responsive.value<double>(
                      context,
                      phone: 8,
                      tablet: 12,
                      large: 16,
                    ),
                  ),

                  // ============================================================
                  // LOGO
                  // ============================================================
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

                  // ============================================================
                  // GLASS CARD
                  // ============================================================
                  ClipRRect(
                    borderRadius: BorderRadius.circular(cardRadius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(cardPadding),

                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),

                          borderRadius: BorderRadius.circular(cardRadius),

                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1,
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ==================================================
                            // TITLE
                            // ==================================================
                            const SizedBox(
                              width: double.infinity,
                              child: AutoSizeText(
                                'Create your Account',
                                maxLines: 1,
                                minFontSize: 21,
                                maxFontSize: 29,
                                stepGranularity: 1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF151922),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: Responsive.value<double>(
                                context,
                                phone: 6,
                                tablet: 8,
                                large: 10,
                              ),
                            ),

                            // ==================================================
                            // SUBTITLE
                            // ==================================================
                            const SizedBox(
                              width: double.infinity,
                              child: Text(
                                'Create an account to continue!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF707784),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: Responsive.value<double>(
                                context,
                                phone: 18,
                                tablet: 22,
                                large: 24,
                              ),
                            ),

                            // ==================================================
                            // FIRST + LAST NAME
                            // ==================================================
                            if (isVeryNarrow)
                              Column(
                                children: [
                                  _buildCompactField(
                                    label: 'First Name',
                                    controller: _firstNameController,
                                    hintText: 'First name',
                                    icon: Icons.person_outline,
                                    height: fieldHeight,
                                    keyboardType: TextInputType.name,
                                  ),

                                  const SizedBox(height: 10),

                                  _buildCompactField(
                                    label: 'Last Name',
                                    controller: _lastNameController,
                                    hintText: 'Last name',
                                    icon: Icons.person_outline,
                                    height: fieldHeight,
                                    keyboardType: TextInputType.name,
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildCompactField(
                                      label: 'First Name',
                                      controller: _firstNameController,
                                      hintText: 'First name',
                                      icon: Icons.person_outline,
                                      height: fieldHeight,
                                      keyboardType: TextInputType.name,
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Expanded(
                                    child: _buildCompactField(
                                      label: 'Last Name',
                                      controller: _lastNameController,
                                      hintText: 'Last name',
                                      icon: Icons.person_outline,
                                      height: fieldHeight,
                                      keyboardType: TextInputType.name,
                                    ),
                                  ),
                                ],
                              ),

                            SizedBox(
                              height: Responsive.value<double>(
                                context,
                                phone: 10,
                                tablet: 12,
                                large: 14,
                              ),
                            ),

                            // ==================================================
                            // EMAIL
                            // ==================================================
                            _buildCompactField(
                              label: 'Email',
                              controller: _emailController,
                              hintText: 'Enter your email',
                              icon: Icons.email_outlined,
                              height: fieldHeight,
                              keyboardType: TextInputType.emailAddress,
                            ),

                            SizedBox(
                              height: Responsive.value<double>(
                                context,
                                phone: 10,
                                tablet: 12,
                                large: 14,
                              ),
                            ),

                            // ==================================================
                            // DATE OF BIRTH
                            // ==================================================
                            _buildDateField(
                              height: fieldHeight,
                              onTap: _selectDateOfBirth,
                            ),

                            SizedBox(
                              height: Responsive.value<double>(
                                context,
                                phone: 10,
                                tablet: 12,
                                large: 14,
                              ),
                            ),

                            // ==================================================
                            // PHONE
                            // ==================================================
                            _buildPhoneField(height: fieldHeight),

                            SizedBox(
                              height: Responsive.value<double>(
                                context,
                                phone: 10,
                                tablet: 12,
                                large: 14,
                              ),
                            ),

                            // ==================================================
                            // PASSWORD
                            // ==================================================
                            _buildPasswordField(height: fieldHeight),

                            SizedBox(
                              height: Responsive.value<double>(
                                context,
                                phone: 16,
                                tablet: 18,
                                large: 20,
                              ),
                            ),

                            // ==================================================
                            // REGISTER BUTTON
                            // ==================================================
                            SizedBox(
                              width: double.infinity,
                              height: buttonHeight,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary.withValues(alpha: 0.85),
                                    ],
                                  ),

                                  borderRadius: BorderRadius.circular(16),

                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),

                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _register,

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    disabledBackgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),

                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 21,
                                          height: 21,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Register',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
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
                    height: Responsive.value<double>(
                      context,
                      phone: 16,
                      tablet: 22,
                      large: 28,
                    ),
                  ),

                  // ============================================================
                  // LOGIN LINK
                  // ============================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Already have an account?',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF707784),
                          ),
                        ),
                      ),

                      const SizedBox(width: 5),

                      TextButton(
                        onPressed: _goToLogin,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );

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
                    child: SizedBox(width: contentWidth, child: content),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // FIELD WITH LABEL
  // ==========================================================================

  Widget _buildCompactField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required double height,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF252A34),
          ),
        ),

        const SizedBox(height: 6),

        SizedBox(
          height: height,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: TextInputAction.next,

            decoration: InputDecoration(
              hintText: hintText,

              prefixIcon: Icon(icon, size: 21, color: const Color(0xFF606775)),

              filled: true,

              fillColor: Colors.white.withValues(alpha: 0.65),

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide.none,
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // DATE FIELD
  // ==========================================================================

  Widget _buildDateField({
    required double height,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date of Birth',

          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF252A34),
          ),
        ),

        const SizedBox(height: 6),

        SizedBox(
          height: height,

          child: TextField(
            controller: _dateOfBirthController,

            readOnly: true,

            onTap: onTap,

            decoration: InputDecoration(
              hintText: 'DD/MM/YYYY',

              prefixIcon: const Icon(
                Icons.calendar_today_outlined,
                size: 21,
                color: Color(0xFF606775),
              ),

              filled: true,

              fillColor: Colors.white.withValues(alpha: 0.65),

              contentPadding: const EdgeInsets.symmetric(horizontal: 16),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide.none,
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PHONE FIELD
  // ==========================================================================

  Widget _buildPhoneField({required double height}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Phone Number',

          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF252A34),
          ),
        ),

        const SizedBox(height: 6),

        Row(
          children: [
            Container(
              height: height,

              padding: const EdgeInsets.symmetric(horizontal: 12),

              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),

                borderRadius: BorderRadius.circular(15),
              ),

              child: const Center(
                child: Text(
                  '+20',

                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF505662),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: SizedBox(
                height: height,

                child: TextField(
                  controller: _phoneController,

                  keyboardType: TextInputType.phone,

                  textInputAction: TextInputAction.next,

                  decoration: InputDecoration(
                    hintText: 'Phone number',

                    filled: true,

                    fillColor: Colors.white.withValues(alpha: 0.65),

                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),

                      borderSide: BorderSide.none,
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),

                      borderSide: BorderSide.none,
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),

                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // PASSWORD FIELD
  // ==========================================================================

  Widget _buildPasswordField({required double height}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Password',

          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF252A34),
          ),
        ),

        const SizedBox(height: 6),

        SizedBox(
          height: height,

          child: TextField(
            controller: _passwordController,

            obscureText: !_isPasswordVisible,

            textInputAction: TextInputAction.done,

            decoration: InputDecoration(
              hintText: 'Enter your password',

              prefixIcon: const Icon(
                Icons.lock_outline,
                size: 21,
                color: Color(0xFF606775),
              ),

              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },

                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,

                  size: 21,

                  color: const Color(0xFF606775),
                ),
              ),

              filled: true,

              fillColor: Colors.white.withValues(alpha: 0.65),

              contentPadding: const EdgeInsets.symmetric(horizontal: 16),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide.none,
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),

                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
