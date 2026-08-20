import 'package:flutter/material.dart';
import '../models/online_icon_pack.dart';
import '../services/icon_matching_service.dart';
import '../services/icon_pack_api.dart';
import '../theme/app_theme.dart';
import 'icon_changer_screen.dart';

const Map<String, List<Color>> _packGradients = {
  'cartoon': [Color(0xFF00E676), Color(0xFF1B5E20)],
  'flat_colors': [Color(0xFF2979FF), Color(0xFF0D47A1)],
  'dark_mode': [Color(0xFF616161), Color(0xFF212121)],
  'neon_glow': [Color(0xFF00E5FF), Color(0xFF006064)],
  'pastel_dream': [Color(0xFFE040FB), Color(0xFF4A148C)],
  'line_black': [Color(0xFF82B1FF), Color(0xFF1A237E)],
  'glass_morphism': [Color(0xFF80DEEA), Color(0xFF006064)],
  'pixel_art': [Color(0xFFFFAB40), Color(0xFFE65100)],
  'watercolor': [Color(0xFFF48FB1), Color(0xFF880E4F)],
  'gradient_mesh': [Color(0xFF7C4DFF), Color(0xFF311B92)],
  'outline_mono': [Color(0xFFBDBDBD), Color(0xFF212121)],
};

const Map<String, IconData> _packIcons = {
  'cartoon': Icons.emoji_emotions,
  'flat_colors': Icons.palette,
  'dark_mode': Icons.dark_mode,
  'neon_glow': Icons.bolt,
  'pastel_dream': Icons.auto_awesome,
  'line_black': Icons.line_style,
  'glass_morphism': Icons.blur_on,
  'pixel_art': Icons.grid_on,
  'watercolor': Icons.brush,
  'gradient_mesh': Icons.gradient,
  'outline_mono': Icons.crop_square,
};

const Map<String, String> _packLabels = {
  'cartoon': 'Cartoon',
  'flat_colors': 'Flat Colors',
  'dark_mode': 'Dark Mode',
  'neon_glow': 'Neon Glow',
  'pastel_dream': 'Pastel Dream',
  'line_black': 'Line Black',
  'glass_morphism': 'Glass',
  'pixel_art': 'Pixel Art',
  'watercolor': 'Watercolor',
  'gradient_mesh': 'Gradient',
  'outline_mono': 'Outline',
};

const List<String> _bundledPreviewKeys = [
  'browser', 'camera', 'clock', 'calculator', 'contacts', 'phone',
];

class OnlineIconPacksScreen extends StatefulWidget {
  const OnlineIconPacksScreen({super.key});

  @override
  State<OnlineIconPacksScreen> createState() => _OnlineIconPacksScreenState();
}

class _OnlineIconPacksScreenState extends State<OnlineIconPacksScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<OnlineIconPack> _onlinePacks = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchPacks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchPacks({bool forceRefresh = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final packs = await IconPackApi.instance.fetch(forceRefresh: forceRefresh);
      if (mounted) setState(() { _onlinePacks = packs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<OnlineIconPack> get _filteredOnline {
    if (_query.isEmpty) return _onlinePacks;
    return IconPackApi.instance.search(_query);
  }

  @override
  Widget build(BuildContext context) {
    const bundledPacks = IconMatchingService.bundledIconPacks;
    final onlinePacks = _filteredOnline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Icon Packs'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => _fetchPacks(forceRefresh: true),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focusNode,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: AppTypography.body.copyWith(
                color: AppTheme.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: 'Search icon packs...',
                hintStyle: AppTypography.body.copyWith(
                  color: AppTheme.textSecondary(context),
                ),
                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary(context)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surfaceRaised(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdRadius,
                  borderSide: BorderSide(color: AppTheme.borderSubtle(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdRadius,
                  borderSide: BorderSide(color: AppTheme.borderSubtle(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdRadius,
                  borderSide: BorderSide(color: AppTheme.borderFocus(context), width: 1.5),
                ),
              ),
            ),
          ),

          // ── Content ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Bundled packs
                Text(
                  'Bundled Packs',
                  style: AppTypography.heading.copyWith(
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 2 / 3,
                  ),
                  itemCount: bundledPacks.length,
                  itemBuilder: (context, i) {
                    final packId = bundledPacks[i];
                    final previewAssets = _bundledPreviewKeys
                        .map((key) => 'assets/icon_packs/$packId/$key.png')
                        .toList();
                    return _PackTile(
                      id: packId,
                      label: _packLabels[packId] ?? packId,
                      description: '',
                      icon: _packIcons[packId] ?? Icons.palette,
                      colors: _packGradients[packId] ?? [Colors.grey, Colors.black87],
                      badge: 'Bundled',
                      previewAssets: previewAssets,
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IconChangerScreen(initialBundledPack: packId),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Online packs header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.isEmpty ? 'Online Packs' : 'Search Results (${onlinePacks.length})',
                        style: AppTypography.heading.copyWith(
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                    ),
                    if (IconPackApi.instance.endpointUrl != null)
                      Text(
                        'API',
                        style: AppTypography.label.copyWith(
                          color: AppTheme.accentPrimary(context),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Online packs content
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null && onlinePacks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off, size: 48, color: AppTheme.textSecondary(context)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Failed to load packs',
                          style: AppTypography.body.copyWith(color: AppTheme.textSecondary(context)),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextButton(onPressed: () => _fetchPacks(forceRefresh: true), child: const Text('Retry')),
                      ],
                    ),
                  )
                else if (onlinePacks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary(context)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _query.isEmpty ? 'No packs available' : 'No packs match "$_query"',
                          style: AppTypography.body.copyWith(color: AppTheme.textSecondary(context)),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 2 / 3,
                    ),
                    itemCount: onlinePacks.length,
                    itemBuilder: (context, i) {
                      final pack = onlinePacks[i];
                      final colors = _packGradients[pack.id] ?? [Colors.teal, Colors.black87];
                      final previewUrls = pack.iconUrls.values.take(6).toList();
                      return _PackTile(
                        id: pack.id,
                        label: pack.name,
                        description: pack.description,
                        icon: _packIcons[pack.id] ?? Icons.palette,
                        colors: colors,
                        badge: '${pack.iconCount} icons',
                        previewNetworkUrls: previewUrls,
                        onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IconChangerScreen(initialOnlinePack: pack),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.colors,
    required this.badge,
    required this.onTap,
    this.previewAssets,
    this.previewNetworkUrls,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final String badge;
  final VoidCallback onTap;
  final List<String>? previewAssets;
  final List<String>? previewNetworkUrls;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.lgRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors[0].withValues(alpha: 0.45),
                    colors[1].withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Text(
                  badge,
                  style: AppTypography.label.copyWith(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
            Center(child: _buildPreviewGrid()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, AppSpacing.xl, AppSpacing.sm, AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: colors[0], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.body.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewGrid() {
    final assets = previewAssets;
    final urls = previewNetworkUrls;
    if (assets != null && assets.isNotEmpty) return _AssetIconGrid(assets: assets, tintColor: colors[0]);
    if (urls != null && urls.isNotEmpty) return _NetworkIconGrid(urls: urls);
    return Icon(icon, color: colors[0], size: 48);
  }
}

class _AssetIconGrid extends StatelessWidget {
  const _AssetIconGrid({required this.assets, required this.tintColor});
  final List<String> assets;
  final Color tintColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
        children: assets.take(6).map((path) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  color: tintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image, color: tintColor, size: 16),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NetworkIconGrid extends StatelessWidget {
  const _NetworkIconGrid({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1,
        children: urls.take(6).map((url) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, color: Colors.white54, size: 16),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
