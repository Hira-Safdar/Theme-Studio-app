import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/online_icon_pack.dart';
import '../services/app_strings.dart';
import '../services/icon_matching_service.dart';
import '../services/icon_pack_service.dart';
import '../services/native_bridge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_list_row.dart';

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

const List<String> autoStyleOptions = ['classic', 'neon'];

/// Auto tab ke liye accent color presets -- AppColors.moodSwatches "Home
/// preset" ke liye reserved hain (dekho app_theme.dart), isliye yahan alag
/// dedicated palette rakhi hai.
const List<Color> autoAccentPresets = [
  Color(0xFF00FFF0), // Cyan
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
  const IconChangerScreen({super.key, this.initialOnlinePack, this.initialBundledPack});
  final OnlineIconPack? initialOnlinePack;
  final String? initialBundledPack;
  @override
  State<IconChangerScreen> createState() => _IconChangerScreenState();
}

class _IconChangerScreenState extends State<IconChangerScreen> {
  OnlineIconPack? _onlinePack;
  String get _onlinePackCategoryId => _onlinePack != null ? 'online_${_onlinePack!.id}' : '';
  bool get _isOnlinePackTab => _onlinePack != null && activeCategory == _onlinePackCategoryId;

  String _effectiveCategoryDisplayName(String id) {
    if (_onlinePack != null && id == _onlinePackCategoryId) return _onlinePack!.name;
    return _categoryDisplayName(id);
  }

  String activeCategory = '';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  bool _loadingApps = true;
  List<AppEntry> _apps = [];

  final Map<String, IconRowStatus> _rowStatus = {};
  final Map<String, String> _customIconPaths = {};
  final Map<String, Uint8List> _oldIconBytes = {};

  final String _autoShape = autoShapeOptions.first;
  final String _autoStyle = autoStyleOptions.first;
  final Color _autoAccent = autoAccentPresets.first;
  final Map<String, String> _autoPreviewPaths = {};

  final Map<String, String> _onlineIconCache = {};
  bool _loadingOnlineIcons = false;

  final Set<String> _selectedPackages = {};

  bool get _isCustomTab => activeCategory == customCategoryId;
  bool get _isAutoTab => activeCategory == autoCategoryId;

  bool _appHasIcon(AppEntry app) {
    if (_isCustomTab) return _customIconPaths[app.packageName] != null;
    if (_isAutoTab) return _autoPreviewPaths[app.packageName] != null;
    if (_isOnlinePackTab) return _onlinePack!.iconUrls.containsKey(app.packageName);
    return app.iconKey != null;
  }

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
    _onlinePack = widget.initialOnlinePack;
    if (_onlinePack != null) {
      activeCategory = _onlinePackCategoryId;
    } else if (widget.initialBundledPack != null &&
        categoryTabs.contains(widget.initialBundledPack)) {
      activeCategory = widget.initialBundledPack!;
    } else {
      activeCategory = categoryTabs.first;
    }
    _loadInstalledApps();
  }

  /// Device ki real installed (launchable) apps list native side se
  /// laata hai.
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
    if (_isOnlinePackTab) _bulkDownloadOnlineIcons();
    if (!_isAutoTab && !_isCustomTab && !_isOnlinePackTab) _refreshSelection();
  }

  /// Har app ka asal launcher icon native side se fetch karta hai.
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

  Future<void> _downloadOnlineIcon(String packageName) async {
    if (_onlinePack == null) return;
    final url = _onlinePack!.iconUrls[packageName];
    if (url == null || _onlineIconCache.containsKey(packageName)) return;

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/online_icon_${_onlinePack!.id}_$packageName.png');
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) {
          setState(() {
            _onlineIconCache[packageName] = file.path;
          });
        }
      }
    } catch (_) {}
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
    });
    _refreshSelection();
  }

  Future<void> _bulkDownloadOnlineIcons() async {
    if (_onlinePack == null) return;
    setState(() => _loadingOnlineIcons = true);
    final entries = _onlinePack!.iconUrls.entries.toList();
    await Future.wait(entries.map((e) async {
      if (_onlineIconCache.containsKey(e.key)) return;
      try {
        final response = await http.get(Uri.parse(e.value)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/online_icon_${_onlinePack!.id}_${e.key}.png');
          await file.writeAsBytes(response.bodyBytes);
          _onlineIconCache[e.key] = file.path;
        }
      } catch (_) {}
    }));
    if (mounted) {
      setState(() => _loadingOnlineIcons = false);
      _refreshSelection();
    }
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
    _searchController.dispose();
    super.dispose();
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
    if (_isOnlinePackTab && !_onlinePack!.iconUrls.containsKey(app.packageName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No icon in this pack for ${app.label}')),
      );
      return;
    }
    if (!_isCustomTab && !_isAutoTab && !_isOnlinePackTab && app.iconKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No bundled icon for ${app.label} -- try Auto or Custom tab')),
      );
      return;
    }

    setState(() => _rowStatus[app.packageName] = IconRowStatus.applying);

    try {
      final String filePath;
      if (_isCustomTab) {
        filePath = customPath!;
      } else if (_isAutoTab) {
        filePath = autoPath!;
      } else if (_isOnlinePackTab) {
        final cached = _onlineIconCache[app.packageName];
        if (cached == null) {
          await _downloadOnlineIcon(app.packageName);
          final downloaded = _onlineIconCache[app.packageName];
          if (downloaded == null) throw Exception('Failed to download icon');
          filePath = downloaded;
        } else {
          filePath = cached;
        }
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
    final sortedApps = _sortedApps;
    final packName = _onlinePack != null
        ? _onlinePack!.name
        : _effectiveCategoryDisplayName(activeCategory);
    return Scaffold(
      appBar: AppBar(title: Text(packName)),
      body: Column(
        children: [
          if (!_loadingApps && _apps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
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
                  fillColor: AppTheme.surfaceRaised(context),
                ),
              ),
            ),
          if (_isOnlinePackTab && _loadingOnlineIcons)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppTheme.accentPrimary(context)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text(
                    'Downloading icons...',
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loadingApps
                ? const Center(child: CircularProgressIndicator())
                : _apps.isEmpty
                    ? const Center(child: Text('No installed apps found'))
                    : sortedApps.isEmpty
                        ? Center(child: Text(tr('search_no_results')))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenPadding,
                            ),
                            itemCount: sortedApps.length,
                            itemBuilder: (context, i) {
                              final app = sortedApps[i];
                              final customPath = _customIconPaths[app.packageName];
                              final autoPath = _autoPreviewPaths[app.packageName];

                              final String previewPath;
                              final bool previewIsFile;
                              if (_isCustomTab) {
                                previewPath = customPath ?? '';
                                previewIsFile = customPath != null;
                              } else if (_isAutoTab) {
                                previewPath = autoPath ?? '';
                                previewIsFile = autoPath != null;
                              } else if (_isOnlinePackTab && _onlinePack!.iconUrls.containsKey(app.packageName)) {
                                final cachedPath = _onlineIconCache[app.packageName];
                                previewPath = cachedPath ?? '';
                                previewIsFile = cachedPath != null;
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loadingApps ? null : _applyAllSelected,
                icon: const Icon(Icons.done_all),
                label: Text('Apply All (${_selectedPackages.length} selected)'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}