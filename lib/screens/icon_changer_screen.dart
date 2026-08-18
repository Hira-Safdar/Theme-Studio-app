import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/app_strings.dart';
import '../services/icon_matching_service.dart';
import '../services/icon_pack_service.dart';
import '../services/native_bridge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/disclosure_banner.dart';
import '../widgets/icon_list_row.dart';
import '../widgets/pack_selector.dart';

/// "Auto" -- koi bundled asset nahi, koi manual pick bhi nahi. Har
/// installed app ka REAL icon leke native side par ek consistent shape +
/// duotone color treatment apply hoti hai, taake har app apna unique icon
/// paaye lekin poori list ek "pack" jaisi consistent dikhe.
const String autoCategoryId = 'auto';

/// "Custom" ek alag tab hai (bundled pack nahi) -- sirf yahan user gallery
/// se apna icon pick/edit kar sakta hai. Ye kabhi bhi bundledIconPacks ya
/// Auto tab ke saath mix nahi hoti.
const String customCategoryId = 'custom';

/// Tab selector me dikhne wali poori list -- 3 bundled packs + Auto + Custom.
const List<String> categoryTabs = [...IconMatchingService.bundledIconPacks, autoCategoryId, customCategoryId];

String _categoryDisplayName(String id) {
  switch (id) {
    case 'cartoon':
      return 'Cartoon';
    case 'flat_colors':
      return 'Flat colors';
    case 'dark_mode':
      return 'Dark mode';
    case autoCategoryId:
      return 'Auto';
    case customCategoryId:
      return 'Custom';
    default:
      return id;
  }
}

/// "Auto" tab ke shape options -- native side (MainActivity.kt) mein
/// "circle" / "squircle" string se hi match hote hain, seedhe wahi bhejte
/// hain, koi extra mapping nahi chahiye.
const List<String> autoShapeOptions = ['circle', 'squircle'];

String _shapeDisplayName(String id) => id == 'circle' ? 'Circle' : 'Squircle';

/// Auto tab ke do design "styles" -- dono same shape+accent controls use
/// karte hain, sirf background/border treatment alag hota hai (native
/// side [applyDuotoneTheme] vs [applyNeonGlassTheme]).
const List<String> autoStyleOptions = ['classic', 'neon'];

String _autoStyleDisplayName(String id) => id == 'neon' ? 'Neon Glass' : 'Classic';

/// Auto tab ke liye accent color presets -- AppColors.moodSwatches "Home
/// preset" ke liye reserved hain (dekho app_theme.dart), isliye yahan alag
/// dedicated palette rakhi hai.
const List<Color> autoAccentPresets = [
  Color(0xFF00FFF0), // Cyan -- app ka apna accentPrimary
  Color(0xFFFF7A59), // Coral
  Color(0xFF8B7CFF), // Violet
  Color(0xFF4FD8B8), // Mint
  Color(0xFFF5A623), // Amber
];

String _colorToHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

/// Curated exact-package mapping aur keyword-guess logic ab shared
/// IconMatchingService mein hai (services/icon_matching_service.dart) --
/// taake ThemeController bhi wahi exact matching use kar sake jo yahan
/// dikhti hai.

class IconChangerScreen extends StatefulWidget {
  const IconChangerScreen({super.key});
  @override
  State<IconChangerScreen> createState() => _IconChangerScreenState();
}

class _IconChangerScreenState extends State<IconChangerScreen> {
  String activeCategory = categoryTabs.first;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  bool _loadingApps = true;
  List<AppEntry> _apps = [];

  final Map<String, IconRowStatus> _rowStatus = {};
  final Map<String, String> _customIconPaths = {};
  final Map<String, Uint8List> _oldIconBytes = {};

  // "Auto" tab state -- shape, style, ya accent badalte hi saari preview
  // icons dobara generate hoti hain.
  String _autoShape = autoShapeOptions.first;
  String _autoStyle = autoStyleOptions.first;
  Color _autoAccent = autoAccentPresets.first;
  bool _loadingAutoPreviews = false;
  final Map<String, String> _autoPreviewPaths = {};
  Timer? _autoDebounce;

  // Checkbox reference design (Themie-style) me sab default-selected hote
  // hain -- "Apply All" isi selection set par kaam karta hai. Apps load
  // hone ke baad populate hota hai (ab const nahi ho sakta).
  final Set<String> _selectedPackages = {};

  bool get _isCustomTab => activeCategory == customCategoryId;
  bool get _isAutoTab => activeCategory == autoCategoryId;

  /// Kya [app] ke paas ABHI ke active tab ke hisaab se koi dikhane wala
  /// icon maujood hai -- Custom tab par user-picked icon, Auto tab par
  /// generated+cached themed icon, bundled tabs (Cartoon/Flat colors/Dark
  /// mode) par guessed iconKey.
  bool _appHasIcon(AppEntry app) {
    if (_isCustomTab) return _customIconPaths[app.packageName] != null;
    if (_isAutoTab) return _autoPreviewPaths[app.packageName] != null;
    return app.iconKey != null;
  }

  /// [_apps] ko do groups mein split karke wapas jodta hai -- jin apps ka
  /// icon maujood hai wo pehle, phir baaki -- taake user ko turant pata
  /// chale ke konsi apps abhi apply karne layak hain. Har group ke andar
  /// original (alphabetical) order barqarar rehta hai, isliye simple
  /// split-and-concat use kiya hai (List.sort() stable guarantee nahi
  /// deta, isliye usse groups ke andar order badal sakta tha).
  List<AppEntry> get _sortedApps {
    final q = _searchQuery.toLowerCase();
    final filtered = q.isEmpty
        ? _apps
        : _apps.where((a) =>
            a.label.toLowerCase().contains(q) ||
            a.packageName.toLowerCase().contains(q)).toList();
    final withIcon = <AppEntry>[];
    final withoutIcon = <AppEntry>[];
    for (final app in filtered) {
      (_appHasIcon(app) ? withIcon : withoutIcon).add(app);
    }
    return [...withIcon, ...withoutIcon];
  }

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  /// Device ki real installed (launchable) apps list native side se
  /// laata hai -- demoApps ki hardcoded/hardcoded-OEM list ki jagah.
  /// Isi ke baad hi custom icons, old icons, aur (agar Auto tab active ho)
  /// auto previews load hote hain.
  Future<void> _loadInstalledApps() async {
    final installed = await NativeBridgeService.instance.getInstalledApps();
    if (!mounted) return;

    final apps = installed
        .map((a) => AppEntry(
              a.packageName,
              a.label.isNotEmpty ? a.label : a.packageName,
              IconMatchingService.instance.guessIconKey(a.packageName, a.label),
            ))
        .toList();

    setState(() {
      _apps = apps;
      _loadingApps = false;
    });

    _loadExistingCustomIcons();
    _loadOldIcons();
    if (_isAutoTab) _loadAutoPreviews();
    // Bundled tabs ke liye foran selection update karo (iconKey-based)
    if (!_isAutoTab && !_isCustomTab) _refreshSelection();
  }

  /// Har app ka asal (device par currently laga hua) launcher icon
  /// native side (PackageManager) se fetch karta hai -- row ke "before"
  /// preview ke liye. Koi bhi error par bytes null rehte hain aur UI
  /// khud generic fallback icon dikha deta hai.
  Future<void> _loadOldIcons() async {
    final results = await Future.wait(_apps.map((app) async {
      try {
        final bytes = await NativeBridgeService.instance
            .getAppIcon(app.packageName)
            .timeout(const Duration(seconds: 5));
        return MapEntry(app.packageName, bytes);
      } on TimeoutException {
        return MapEntry(app.packageName, null);
      }
    }));
    if (!mounted) return;
    setState(() {
      for (final entry in results) {
        if (entry.value != null) {
          _oldIconBytes[entry.key] = entry.value!;
        }
      }
    });
  }

  Future<void> _loadExistingCustomIcons() async {
    // Parallel fetch -- sab apps ke custom icon paths ek saath fetch hote
    // hain, sequential await ke bajaye. Phir ek hi setState se sab update.
    final results = await Future.wait(_apps.map((app) async {
      final path = await IconPackService.instance.getCustomIconPath(app.packageName);
      return MapEntry(app.packageName, path);
    }));
    if (!mounted) return;
    setState(() {
      for (final entry in results) {
        if (entry.value != null) {
          _customIconPaths[entry.key] = entry.value!;
        }
      }
    });
    // Custom icons load hone ke baad selection refresh karo (agar custom tab active hai)
    if (_isCustomTab) _refreshSelection();
  }

  /// Har app ke liye native se themed (duotone/neon + shape-masked) icon
  /// generate karwata hai, aur ek real file me cache karta hai (Image.file
  /// preview + shortcut creation dono isi file se kaam karte hain). Shape,
  /// style, ya accent color badalne par dobara call hota hai -- cache-key
  /// mein teeno shamil hain isliye purani generation reuse nahi hoti.
  Future<void> _loadAutoPreviews() async {
    if (_apps.isEmpty) return;
    setState(() => _loadingAutoPreviews = true);

    final accentHex = _colorToHex(_autoAccent);
    final results = await Future.wait(_apps.map((app) async {
      final bytes = await NativeBridgeService.instance.getThemedAppIcon(
        packageName: app.packageName,
        shape: _autoShape,
        accentColorHex: accentHex,
        style: _autoStyle,
      );
      if (bytes == null) return null;
      final path = await IconPackService.instance.bytesToFile(
        bytes,
        '${app.packageName}_auto_${_autoStyle}_${_autoShape}_$accentHex',
      );
      return MapEntry(app.packageName, path);
    }));

    if (!mounted) return;
    setState(() {
      _autoPreviewPaths
        ..clear()
        ..addEntries(results.whereType<MapEntry<String, String>>());
      _loadingAutoPreviews = false;
    });
    // Auto previews load hone ke baad selection refresh karo
    _refreshSelection();
  }

  void _onCategoryChanged(String id) {
    setState(() => activeCategory = id);
    if (id == autoCategoryId && _autoPreviewPaths.isEmpty && !_loadingAutoPreviews) {
      _loadAutoPreviews();
    }
    // Tab change par selection refresh karo -- sirf available icons wale apps
    _refreshSelection();
  }

  /// Selection ko refresh karta hai -- sirf wo apps select rehte hain
  /// jinke paas current tab ke liye icon available hai. Baqi apps
  /// (jinke liye koi icon/bundle nahi) automatically deselect ho jaate hain
  /// taake "Apply All" par unke liye error na aaye.
  void _refreshSelection() {
    setState(() {
      _selectedPackages
        ..clear()
        ..addAll(_apps.where(_appHasIcon).map((a) => a.packageName));
    });
  }

  @override
  void dispose() {
    _autoDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onAutoShapeChanged(String shape) {
    setState(() => _autoShape = shape);
    _debounceAutoPreviews();
  }

  void _onAutoStyleChanged(String style) {
    setState(() => _autoStyle = style);
    _debounceAutoPreviews();
  }

  void _onAutoAccentChanged(Color color) {
    setState(() => _autoAccent = color);
    _debounceAutoPreviews();
  }

  /// Auto tab ke controls (shape/style/accent) mein se koi bhi change hone
  /// par turant _loadAutoPreviews() call karne ke bajaye 250ms rukte hain --
  /// agar user tezi se multiple changes kare (e.g. color picker drag kare)
  /// to har change par poori list regenerate karna wasteful hota, debounce
  /// se sirf aakhri change par ek baar hota hai.
  void _debounceAutoPreviews() {
    _autoDebounce?.cancel();
    _autoDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _isAutoTab) _loadAutoPreviews();
    });
  }

  void _toggleSelected(String packageName, bool? value) {
    setState(() {
      if (value == true) {
        _selectedPackages.add(packageName);
      } else {
        _selectedPackages.remove(packageName);
      }
    });
  }

  /// [app] ke liye is waqt jo tab active hai (bundled pack, Auto, ya
  /// Custom) usi ke hisaab se icon apply karta hai. Custom tab par sirf
  /// tab apply hota hai jab user ne pehle koi icon pick kiya ho; bundled
  /// tab par sirf tab jab is app ke liye koi iconKey guess ho saka ho;
  /// Auto tab par sirf tab jab uska themed preview generate ho chuka ho.
  Future<void> _applyIcon(AppEntry app) async {
    final customPath = _customIconPaths[app.packageName];
    final autoPath = _autoPreviewPaths[app.packageName];

    if (_isCustomTab && customPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pick a custom icon for ${app.label} first')),
      );
      return;
    }
    if (_isAutoTab && autoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Still generating ${app.label}\'s icon -- try again in a moment')),
      );
      return;
    }
    if (!_isCustomTab && !_isAutoTab && app.iconKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No bundled icon for ${app.label} -- try Auto or Custom tab')),
      );
      return;
    }

    setState(() => _rowStatus[app.packageName] = IconRowStatus.applying);

    try {
      final String filePath;
      if (_isCustomTab) {
        filePath = customPath!; // already ek real file path hai
      } else if (_isAutoTab) {
        filePath = autoPath!; // already ek real (cached) file path hai
      } else {
        final assetPath =
            IconPackService.instance.bundledAssetPath(activeCategory, app.iconKey!);
        filePath = await IconPackService.instance.assetToFile(assetPath, app.packageName);
      }

      final ok = await NativeBridgeService.instance.createIconShortcut(
        packageName: app.packageName,
        appLabel: app.label,
        iconFilePath: filePath,
      );

      if (!mounted) return;
      setState(() {
        _rowStatus[app.packageName] = ok ? IconRowStatus.applied : IconRowStatus.failed;
      });

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shortcut request sent for ${app.label}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t apply ${app.label} — tap to retry')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _rowStatus[app.packageName] = IconRowStatus.failed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t apply ${app.label} — tap to retry')),
      );
    }
  }

  /// Selected rows ko ek-ek karke apply karta hai (sequential -- Android
  /// ek waqt me ek hi "Add to Home Screen" confirmation dialog theek se
  /// dikhata hai, isliye parallel requests bhejna reliable nahi hoga).
  /// Apps jinke paas icon nahi hai wo silently skip ho jaate hain.
  Future<void> _applyAllSelected() async {
    final targets = _apps
        .where((a) => _selectedPackages.contains(a.packageName) && _appHasIcon(a))
        .toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No apps with available icons selected')),
      );
      return;
    }
    for (final app in targets) {
      await _applyIcon(app);
    }
  }

  Future<void> _pickCustomIcon(AppEntry app) async {
    try {
      final path = await IconPackService.instance.pickAndSaveCustomIcon(app.packageName);
      if (path == null) return; // user cancelled
      if (!mounted) return;
      setState(() {
        _customIconPaths[app.packageName] = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Custom icon saved for ${app.label} — tap Apply')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t save custom icon — tap to retry')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ek hi baar compute karte hain -- ListView.builder ke itemBuilder ke
    // andar dobara sort karna har row ke liye wasteful hota.
    final sortedApps = _sortedApps;
    return Scaffold(
      appBar: AppBar(title: Text(tr('icon_changer_title'))),
      body: Column(
        children: [
          const DisclosureBanner(
            message: 'Applying an icon creates a Home Screen shortcut. '
                'Android will confirm before adding it.',
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: PackSelector(
              options: categoryTabs,
              selected: activeCategory,
              onChanged: _onCategoryChanged,
              labelBuilder: _categoryDisplayName,
            ),
          ),
          if (_isAutoTab) _AutoControls(
            shape: _autoShape,
            style: _autoStyle,
            accent: _autoAccent,
            onShapeChanged: _onAutoShapeChanged,
            onStyleChanged: _onAutoStyleChanged,
            onAccentChanged: _onAutoAccentChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loadingApps ? null : _applyAllSelected,
                icon: const Icon(Icons.done_all),
                label: Text('Apply All (${_selectedPackages.length} selected)'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!_loadingApps && _apps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: tr('search_apps_hint'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdRadius,
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.bgSurfaceRaised,
                ),
              ),
            ),
          if (!_loadingApps && _apps.isNotEmpty)
            const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _loadingApps
                ? const Center(child: CircularProgressIndicator())
                : _apps.isEmpty
                    ? const Center(child: Text('No installed apps found'))
                    : _sortedApps.isEmpty
                        ? Center(child: Text(tr('search_no_results')))
                        : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                        itemCount: sortedApps.length,
                        itemBuilder: (context, i) {
                          final app = sortedApps[i];
                          final customPath = _customIconPaths[app.packageName];
                          final autoPath = _autoPreviewPaths[app.packageName];

                          // Bundled tabs (Cartoon/Flat colors/Dark mode) hamesha
                          // apna fixed asset dikhate hain. Custom tab par sirf
                          // custom-picked icon (agar set hai). Auto tab par
                          // generated+cached themed icon file (agar ban chuki ho).
                          final String previewPath;
                          final bool previewIsFile;
                          if (_isCustomTab) {
                            previewPath = customPath ?? '';
                            previewIsFile = customPath != null;
                          } else if (_isAutoTab) {
                            previewPath = autoPath ?? '';
                            previewIsFile = autoPath != null;
                          } else if (app.iconKey != null) {
                            previewPath = IconPackService.instance
                                .bundledAssetPath(activeCategory, app.iconKey!);
                            previewIsFile = false;
                          } else {
                            previewPath = '';
                            previewIsFile = false;
                          }

                          return IconListRow(
                            label: app.label,
                            packageName: app.packageName,
                            status: _rowStatus[app.packageName] ?? IconRowStatus.idle,
                            hasCustomIcon: _isCustomTab && customPath != null,
                            previewPath: previewPath,
                            previewIsFile: previewIsFile,
                            canEditIcon: _isCustomTab,
                            isSelected: _selectedPackages.contains(app.packageName),
                            oldIconBytes: _oldIconBytes[app.packageName],
                            onToggleSelected: (value) =>
                                _toggleSelected(app.packageName, value),
                            onPickCustomIcon: () => _pickCustomIcon(app),
                            onApply: () => _applyIcon(app),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// "Auto" tab ke liye shape + style + accent-color controls -- PackSelector
/// (shape aur style ke liye) + ek chhota accent-swatch row. Jab tak preview
/// generate ho rahi ho, ek thin progress indicator dikhta hai.
class _AutoControls extends StatelessWidget {
  const _AutoControls({
    required this.shape,
    required this.style,
    required this.accent,
    required this.onShapeChanged,
    required this.onStyleChanged,
    required this.onAccentChanged,
  });

  final String shape;
  final String style;
  final Color accent;
  final ValueChanged<String> onShapeChanged;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<Color> onAccentChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        0,
        AppSpacing.screenPadding,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PackSelector(
            options: autoStyleOptions,
            selected: style,
            onChanged: onStyleChanged,
            labelBuilder: _autoStyleDisplayName,
          ),
          const SizedBox(height: AppSpacing.sm),
          PackSelector(
            options: autoShapeOptions,
            selected: shape,
            onChanged: onShapeChanged,
            labelBuilder: _shapeDisplayName,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: autoAccentPresets.map((color) {
              final isSelected = color.toARGB32() == accent.toARGB32();
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: GestureDetector(
                  onTap: () => onAccentChanged(color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.textPrimary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.black87)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}