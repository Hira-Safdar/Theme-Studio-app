import 'package:flutter/material.dart';
import '../models/online_icon_pack.dart';
import '../theme/app_theme.dart';

/// Browse online icon packs — each shows name, icon count, and preview grid.
class OnlineIconPacksScreen extends StatelessWidget {
  const OnlineIconPacksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online Icon Packs')),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: OnlineIconPack.curated.length,
        itemBuilder: (context, i) => _PackCard(pack: OnlineIconPack.curated[i]),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack});
  final OnlineIconPack pack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _PackDetailScreen(pack: pack)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: AppTheme.level1(context, radius: AppRadius.lgRadius),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.accentPrimaryMuted(context),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Icon(Icons.palette, color: AppTheme.accentPrimary(context)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pack.name, style: AppTypography.heading),
                  const SizedBox(height: 2),
                  Text(
                    '${pack.iconCount} icons • ${pack.author}',
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary(context)),
          ],
        ),
      ),
    );
  }
}

class _PackDetailScreen extends StatelessWidget {
  const _PackDetailScreen({required this.pack});
  final OnlineIconPack pack;

  @override
  Widget build(BuildContext context) {
    final entries = pack.iconUrls.entries.toList();
    return Scaffold(
      appBar: AppBar(title: Text(pack.name)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised(context),
              border: Border(
                bottom: BorderSide(color: AppTheme.borderSubtle(context)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pack.description, style: AppTypography.bodySecondary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${pack.iconCount} icons • by ${pack.author}',
                  style: AppTypography.label.copyWith(
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
              ),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final entry = entries[i];
                final packageName = entry.key.split('.').last;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.smRadius,
                      child: Image.network(
                        entry.value,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: AppTheme.surfaceRaised(context),
                          child: Icon(Icons.android, color: AppTheme.textSecondary(context), size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      packageName,
                      style: AppTypography.label.copyWith(fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
