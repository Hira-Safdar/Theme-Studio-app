// lib/widgets/wallpaper_preview.dart
//
// Wallpaper phone-frame preview — device-silhouette frame, full-bleed
// wallpaper, dummy status bar + icons at low opacity to judge legibility,
// Apply/Cancel below. §2 + §3.3.
//
// Shown as a full route so it can breathe (device silhouette needs real
// screen height); returns true if the user confirms Apply, false/null
// if they cancel.

import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pack_selector.dart';

/// Home/lock/both target ids -- setWallpaper() ke [target] param se match
/// karte hain (native_bridge_service.dart / MainActivity.kt).
const List<String> _wallpaperTargets = ['home', 'lock', 'both'];

String _targetLabel(String id) {
  switch (id) {
    case 'home':
      return 'Home screen';
    case 'lock':
      return 'Lock screen';
    default:
      return 'Both';
  }
}

class WallpaperPreviewScreen extends StatefulWidget {
  const WallpaperPreviewScreen({super.key, required this.image});

  /// Pass an [AssetImage] for bundled wallpapers or a [FileImage] for
  /// gallery-picked ones — caller decides which.
  final ImageProvider image;

  /// Returns the chosen target ('home' | 'lock' | 'both') if the user taps
  /// Apply, or null if they cancel/close the preview.
  static Future<String?> show(BuildContext context, ImageProvider image) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => WallpaperPreviewScreen(image: image)),
    );
  }

  @override
  State<WallpaperPreviewScreen> createState() => _WallpaperPreviewScreenState();
}

class _WallpaperPreviewScreenState extends State<WallpaperPreviewScreen> {
  // "Both" default -- sabse common expectation, user chahe to Home/Lock
  // alag se bhi choose kar sakta hai.
  String _target = 'both';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Preview'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close preview',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _PhoneFrame(image: widget.image),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: PackSelector(
                options: _wallpaperTargets,
                selected: _target,
                onChanged: (id) => setState(() => _target = id),
                labelBuilder: _targetLabel,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_target),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.image});
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 19.5,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.borderFocus, width: 6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(image: image, fit: BoxFit.cover),
            // Dummy status bar + icons at low opacity — for judging
            // wallpaper legibility, not a functional status bar.
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: 0.55,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '9:41',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.signal_cellular_alt, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Icon(Icons.wifi, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Icon(Icons.battery_full, color: Colors.white, size: 14),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // A few dummy app icons near the bottom, also low-opacity,
            // so the preview reads like a Home Screen rather than a
            // bare image viewer.
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.xl,
              child: Opacity(
                opacity: 0.55,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    4,
                    (_) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: AppRadius.mdRadius,
                      ),
                    ),
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

/// Convenience for building the right ImageProvider from either an asset
/// path (bundled wallpapers) or a file path (gallery pick).
ImageProvider wallpaperImageProvider({String? assetPath, String? filePath}) {
  if (filePath != null) return FileImage(File(filePath));
  return AssetImage(assetPath!);
}