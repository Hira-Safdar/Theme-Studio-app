import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum IconRowStatus { idle, applying, applied, failed }

class IconListRow extends StatefulWidget {
  const IconListRow({
    super.key,
    required this.label,
    required this.packageName,
    required this.status,
    required this.hasCustomIcon,
    required this.previewPath,
    required this.previewIsFile,
    required this.canEditIcon,
    required this.isSelected,
    required this.oldIconBytes,
    required this.onToggleSelected,
    required this.onPickCustomIcon,
    required this.onApply,
    this.isOnlinePack = false,
    this.adWatched = false,
    this.isAlreadyAdded = false,
    this.onRemove,
    this.available = true,
  });

  final String label;
  final String packageName;
  final IconRowStatus status;
  final bool hasCustomIcon;
  final String previewPath;
  final bool previewIsFile;
  final bool canEditIcon;
  final bool isSelected;
  final Uint8List? oldIconBytes;
  final ValueChanged<bool?> onToggleSelected;
  final VoidCallback onPickCustomIcon;
  final VoidCallback onApply;
  final bool isOnlinePack;
  final bool adWatched;
  final bool isAlreadyAdded;
  final VoidCallback? onRemove;
  final bool available;

  @override
  State<IconListRow> createState() => _IconListRowState();
}

class _IconListRowState extends State<IconListRow> with SingleTickerProviderStateMixin {
  AnimationController? _highlightController;
  Animation<double>? _highlightAnim;
  bool _wasApplied = false;

  @override
  void initState() {
    super.initState();
    if (widget.status == IconRowStatus.applied) _wasApplied = true;
  }

  @override
  void didUpdateWidget(covariant IconListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jab apply ho jaye — highlight animation chalao
    if (widget.status == IconRowStatus.applied && !_wasApplied) {
      _wasApplied = true;
      _startHighlight();
    }
    // Remove ho jaye toh flag reset karo
    if (widget.status == IconRowStatus.idle) _wasApplied = false;
  }

  void _startHighlight() {
    _highlightController?.dispose();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _highlightAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _highlightController!, curve: Curves.easeOut),
    );
    _highlightController!.forward();
  }

  @override
  void dispose() {
    _highlightController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFailed = widget.status == IconRowStatus.failed;

    Widget row = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isFailed
            ? AppTheme.error(context).withValues(alpha: 0.08)
            : AppTheme.surface(context),
        borderRadius: AppRadius.mdRadius,
        border: isFailed ? Border.all(color: AppTheme.error(context)) : null,
      ),
      child: Row(
        children: [
          Checkbox(
            value: widget.isSelected,
            onChanged: widget.onToggleSelected,
            activeColor: AppTheme.accentPrimary(context),
          ),
          _IconTransitionGroup(
            oldIconBytes: widget.oldIconBytes,
            newIconPath: widget.previewPath,
            newIconIsFile: widget.previewIsFile,
            hasCustomIcon: widget.hasCustomIcon,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(widget.label, style: AppTypography.body),
                    ),
                    if (widget.isAlreadyAdded) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success(context).withValues(alpha: 0.15),
                          borderRadius: AppRadius.smRadius,
                        ),
                        child: Text(
                          'Added',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(widget.packageName, style: AppTypography.bodySecondary),
              ],
            ),
          ),
          if (widget.canEditIcon)
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              tooltip: 'Pick custom icon for ${widget.label}',
              color: AppTheme.textSecondary(context),
              onPressed: widget.status == IconRowStatus.applying ? null : widget.onPickCustomIcon,
            ),
          // Agar already added hai toh Remove button,
          // warna icon available nahi toh disabled N/A,
          // warna Apply/Watch Ad button
          if (widget.isAlreadyAdded)
            _RemoveButton(
              onPressed: widget.onRemove,
              applying: widget.status == IconRowStatus.applying,
            )
          else if (!widget.available)
            _DisabledButton()
          else
            _ApplyButton(
              status: widget.status,
              onPressed: widget.onApply,
              isOnlinePack: widget.isOnlinePack,
              adWatched: widget.adWatched,
            ),
        ],
      ),
    );

    // Highlight animation — apply ke baad green glow fade out
    if (_highlightController != null && _highlightAnim != null) {
      row = AnimatedBuilder(
        animation: _highlightAnim!,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdRadius,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.success(context).withValues(alpha: _highlightAnim!.value * 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: row,
      );
    }

    return row;
  }
}

/// Remove button — outlined style, red tint on hover
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed, this.applying = false});
  final VoidCallback? onPressed;
  final bool applying;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: applying ? null : onPressed,
      icon: const Icon(Icons.remove_circle_outline, size: 16),
      label: const Text('Remove'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.error(context),
        side: BorderSide(color: AppTheme.error(context).withValues(alpha: 0.4)),
      ),
    );
  }
}

/// "Before -> after" preview group
class _IconTransitionGroup extends StatelessWidget {
  const _IconTransitionGroup({
    required this.oldIconBytes,
    required this.newIconPath,
    required this.newIconIsFile,
    required this.hasCustomIcon,
  });

  final Uint8List? oldIconBytes;
  final String newIconPath;
  final bool newIconIsFile;
  final bool hasCustomIcon;

  Widget _buildFallback(BuildContext context) =>
      Icon(Icons.android, color: AppTheme.textSecondary(context), size: 22);

  Widget _oldIconWidget(BuildContext context) {
    if (oldIconBytes == null) return _buildFallback(context);
    return Image.memory(
      oldIconBytes!,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallback(context),
    );
  }

  Widget _newIconWidget(BuildContext context) {
    if (newIconPath.isEmpty) return _buildFallback(context);
    if (newIconIsFile) {
      return Image.file(
        File(newIconPath),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(context),
      );
    }
    return Image.asset(
      newIconPath,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallback(context),
    );
  }

  Widget _iconBox(BuildContext context, Widget child) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised(context),
          borderRadius: AppRadius.mdRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBox(context, _oldIconWidget(context)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward, size: 16, color: AppTheme.textSecondary(context)),
            const SizedBox(width: 4),
            _iconBox(context, _newIconWidget(context)),
          ],
        ),
        if (hasCustomIcon)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit, size: 10, color: Color(0xFF00201E)),
            ),
          ),
      ],
    );
  }
}

/// Disabled button for apps without pack icon support
class _DisabledButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text(
        'N/A',
        style: AppTypography.bodySecondary.copyWith(
          color: AppTheme.textSecondary(context).withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.status, required this.onPressed, this.isOnlinePack = false, this.adWatched = false});
  final IconRowStatus status;
  final VoidCallback onPressed;
  final bool isOnlinePack;
  final bool adWatched;

  @override
  Widget build(BuildContext context) {
    if (status == IconRowStatus.applying) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppTheme.accentPrimary(context)),
          ),
        ),
      );
    }

    if (status == IconRowStatus.applied) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Icon(Icons.check_circle, color: AppTheme.success(context)),
      );
    }

    final isFailed = status == IconRowStatus.failed;
    final label = isFailed
        ? 'Retry'
        : isOnlinePack && !adWatched
            ? 'Watch Ad'
            : 'Apply';
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isFailed
            ? Icons.refresh
            : isOnlinePack && !adWatched
                ? Icons.play_circle_outline
                : Icons.check,
        size: 16,
      ),
      label: Text(label),
      style: isFailed
          ? FilledButton.styleFrom(
              backgroundColor: AppTheme.error(context).withValues(alpha: 0.15),
              foregroundColor: AppTheme.error(context),
            )
          : isOnlinePack && !adWatched
              ? FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentPrimary(context).withValues(alpha: 0.15),
                  foregroundColor: AppTheme.accentPrimary(context),
                )
              : null,
    );
  }
}
