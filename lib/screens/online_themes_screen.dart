import 'package:flutter/material.dart';
import '../models/online_theme.dart';
import '../models/online_wallpaper.dart';
import '../services/app_strings.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';

class OnlineThemesScreen extends StatefulWidget {
  const OnlineThemesScreen({super.key});
  @override
  State<OnlineThemesScreen> createState() => _OnlineThemesScreenState();
}

class _OnlineThemesScreenState extends State<OnlineThemesScreen> {
  String _selectedCategory = 'all';

  List<OnlineTheme> get _filtered {
    if (_selectedCategory == 'all') return OnlineTheme.curated;
    return OnlineTheme.byCategory(_selectedCategory);
  }

  @override
  Widget build(BuildContext context) {
    final categories = OnlineTheme.categories;
    return Scaffold(
      appBar: AppBar(title: Text(tr('online_themes'))),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                _CategoryChip(
                  label: tr('all_categories'),
                  isSelected: _selectedCategory == 'all',
                  onTap: () => setState(() => _selectedCategory = 'all'),
                ),
                ...categories.map((c) => _CategoryChip(
                  label: _titleCase(c),
                  isSelected: _selectedCategory == c,
                  onTap: () => setState(() => _selectedCategory = c),
                )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 3 / 2,
              ),
              itemCount: _filtered.length,
              itemBuilder: (context, i) => _ThemeTile(theme: _filtered[i]),
            ),
          ),
        ],
      ),
    );
  }
}

String _titleCase(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.theme});
  final OnlineTheme theme;

  @override
  Widget build(BuildContext context) {
    final accent = Color(theme.accentColorValue);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ThemeWallpaperPicker(theme: theme)),
      ),
      child: Container(
        decoration: AppTheme.level2(context, radius: AppRadius.lgRadius),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.3),
                    accent.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.palette, color: accent, size: 32),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    theme.name,
                    style: AppTypography.heading.copyWith(
                      color: AppTheme.textPrimary(context),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentPrimaryMuted(context) : AppTheme.surfaceRaised(context),
            borderRadius: AppRadius.smRadius,
            border: Border.all(
              color: isSelected ? AppTheme.accentPrimary(context) : AppTheme.borderSubtle(context),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: isSelected ? AppTheme.accentPrimary(context) : AppTheme.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeWallpaperPicker extends StatefulWidget {
  const _ThemeWallpaperPicker({required this.theme});
  final OnlineTheme theme;

  @override
  State<_ThemeWallpaperPicker> createState() => _ThemeWallpaperPickerState();
}

class _ThemeWallpaperPickerState extends State<_ThemeWallpaperPicker> {
  List<OnlineWallpaper> _wallpapers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final results = await DownloadService.instance.search(
      widget.theme.searchQuery,
      perPage: 12,
    );
    if (!mounted) return;
    setState(() {
      _wallpapers = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.theme.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wallpapers.isEmpty
              ? Center(
                  child: Text(tr('search_no_results'), style: AppTypography.bodySecondary),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 2 / 3,
                  ),
                  itemCount: _wallpapers.length,
                  itemBuilder: (context, i) {
                    final wallpaper = _wallpapers[i];
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, wallpaper),
                      child: ClipRRect(
                        borderRadius: AppRadius.mdRadius,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              wallpaper.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppTheme.surfaceRaised(context),
                                child: Icon(Icons.broken_image, color: AppTheme.textSecondary(context)),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                  ),
                                ),
                                child: Text(
                                  wallpaper.author,
                                  style: AppTypography.bodySecondary.copyWith(color: Colors.white, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
