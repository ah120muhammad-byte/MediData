import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_brand.dart';
import '../core/theme/app_colors.dart';
import '../services/remote_app_settings_service.dart';
import 'authentication/auth_gate_v2.dart';

class SplashScreen extends StatefulWidget {
  final RemoteAppSettings settings;

  const SplashScreen({super.key, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1200), _openApp);
  }

  void _openApp() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AuthGateV2(settings: widget.settings),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: isDark
                      ? AppColors.outlineDark
                      : AppColors.outlineLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.28 : 0.10,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  AppBrand.logoPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.medical_services_rounded,
                    size: 64,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'MediData App',
              textAlign: TextAlign.center,
              style: GoogleFonts.comicRelief(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
