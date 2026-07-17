// lib/screens/splash_screen.dart
//
// Splash screen — brief brand moment while the app initializes
// (checks accessibility-service status, loads cached preset list, etc.).
// Spec: build prompt §3.1.
//
// - Full bg.base background, centered content, edge-to-edge.
// - App mark: 96x96 bg.surface-raised rounded square (radius.lg) with an
//   abstract geometric glyph (overlapping rounded shapes) in accent.primary.
// - "Theme studio" in type.heading, sentence case.
// - Thin indeterminate progress bar (2px, radius.sm, accent fill on
//   border.subtle track), width ~120px.
// - Optional one-line status label in type.body-secondary if init runs long.
// - No taglines, no ads, no version number, no skip button.
// - Always resolves to Home — never Settings or a specific tool.
// - Local features must work fully offline; never block on network.

import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  bool _showStatus = false;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: AppMotion.spinner, // 900ms loop, reused for the bar sweep
    )..repeat();

    _initialize();
  }

  Future<void> _initialize() async {
    // Real init work goes here: check accessibility-service status,
    // load cached preset list, etc. All of this must work fully offline —
    // never block this screen on a network call.
    final stopwatch = Stopwatch()..start();

    // Show the "Setting things up…" label only if init runs past ~1.5s,
    // per spec — normal runs should never show it.
    Timer? statusTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showStatus = true);
    });


    // await themeController.loadCachedPresets();
    // await accessibilityStatus.check();
    await Future.delayed(const Duration(milliseconds: 900));

    statusTimer.cancel();
    stopwatch.stop();

    if (!mounted) return;

    // Splash always resolves to Home — never Settings or a specific tool,
    // regardless of what the user was doing on last close.
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AppMark(),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Theme studio',
                style: AppTypography.heading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              _IndeterminateProgressBar(controller: _progressController),
              AnimatedSwitcher(
                duration: AppMotion.standard,
                child: _showStatus
                    ? const Padding(
                        key: ValueKey('status'),
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          'Setting things up…',
                          style: AppTypography.bodySecondary,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abstract geometric glyph suggesting "layers/customization" —
/// three overlapping rounded squares, not a literal phone icon.
class _AppMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceRaised,
        borderRadius: AppRadius.lgRadius,
      ),
      child: Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 4,
                child: _glyphSquare(opacity: 0.3),
              ),
              Positioned(
                left: 6,
                top: 0,
                child: _glyphSquare(opacity: 0.6),
              ),
              Positioned(
                left: 8,
                top: 2,
                child: _glyphSquare(opacity: 1.0, size: 20, radius: 7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glyphSquare({
    required double opacity,
    double size = 24,
    double radius = 8,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Slim horizontal indeterminate bar — deliberately not a spinner;
/// reads calmer at full-screen scale per spec.
class _IndeterminateProgressBar extends StatelessWidget {
  const _IndeterminateProgressBar({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    const double trackWidth = 120;
    const double fillWidth = 48; // sweeping segment, not a literal % fill

    return ClipRRect(
      borderRadius: AppRadius.smRadius,
      child: SizedBox(
        width: trackWidth,
        height: 2,
        child: Stack(
          children: [
            Container(color: AppColors.borderSubtle),
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                // Sweep from -fillWidth to trackWidth, looping.
                final t = controller.value;
                final dx = (trackWidth + fillWidth) * t - fillWidth;
                return Positioned(
                  left: dx,
                  top: 0,
                  bottom: 0,
                  width: fillWidth,
                  child: Container(color: AppColors.accentPrimary),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}