import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pack_selector.dart';

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
  final ImageProvider image;

  static Future<String?> show(BuildContext context, ImageProvider image) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => WallpaperPreviewScreen(image: image)),
    );
  }

  @override
  State<WallpaperPreviewScreen> createState() => _WallpaperPreviewScreenState();
}

class _WallpaperPreviewScreenState extends State<WallpaperPreviewScreen> {
  String _target = 'both';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg(context),
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
              child: _PhoneFrame(image: widget.image, target: _target),
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
  const _PhoneFrame({required this.image, required this.target});
  final ImageProvider image;
  final String target;

  @override
  Widget build(BuildContext context) {
    final frame = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: AspectRatio(
        aspectRatio: 9 / 19.5,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.borderFocus(context), width: 6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(image: image, fit: BoxFit.cover),
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
              _LockOverlay(target: target),
              _HomeOverlay(target: target),
            ],
          ),
        ),
      ),
    );

    if (target == 'both') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LabelChip(label: 'Lock screen', fraction: 0.5),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: OverflowBox(
                  maxHeight: 420,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(image: image, fit: BoxFit.cover),
                      const _LockContent(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const _LabelChip(label: 'Home screen', fraction: 0.5),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: OverflowBox(
                  maxHeight: 420,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(image: image, fit: BoxFit.cover),
                      const _HomeContent(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(child: frame);
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label, required this.fraction});
  final String label;
  final double fraction;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised(context),
        borderRadius: AppRadius.mdRadius,
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context))),
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.target});
  final String target;
  @override
  Widget build(BuildContext context) {
    if (target != 'lock') return const SizedBox.shrink();
    return const _LockContent();
  }
}

class _LockContent extends StatelessWidget {
  const _LockContent();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '9:41',
            style: TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w200,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Wednesday, August 19',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          SizedBox(height: 16),
          Icon(Icons.lock_outline, color: Colors.white54, size: 20),
        ],
      ),
    );
  }
}

class _HomeOverlay extends StatelessWidget {
  const _HomeOverlay({required this.target});
  final String target;
  @override
  Widget build(BuildContext context) {
    if (target != 'home') return const SizedBox.shrink();
    return const _HomeContent();
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: AppSpacing.xl,
      child: Opacity(
        opacity: 0.6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            4,
            (_) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: AppRadius.mdRadius,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 30,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: AppRadius.smRadius,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience for building the right ImageProvider from an asset path,
/// a file path, or a network URL (for online wallpapers).
ImageProvider wallpaperImageProvider({String? assetPath, String? filePath, String? networkUrl}) {
  if (networkUrl != null) return NetworkImage(networkUrl);
  if (filePath != null) return FileImage(File(filePath));
  return AssetImage(assetPath!);
}