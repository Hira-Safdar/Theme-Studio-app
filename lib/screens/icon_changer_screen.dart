import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/icon_pack_service.dart';
import '../services/native_bridge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/disclosure_banner.dart';
import '../widgets/icon_list_row.dart';
import '../widgets/pack_selector.dart';

/// Ek app entry: package name, label, aur icon-pack lookup ke liye keyword.
/// [iconKey] ab nullable hai -- device par installed har app hamare 10
/// bundled categories (browser/calculator/...) mein fit nahi hoti, aisi
/// apps ke liye bundled tabs par sirf generic fallback icon dikhega
/// (Custom tab hamesha available rehta hai).
class AppEntry {
  final String packageName;
  final String label;
  final String? iconKey;
  const AppEntry(this.packageName, this.label, this.iconKey);
}

/// Bundled (pre-made) icon packs -- matches assets/icon_packs/<id>/ folder
/// structure. Ye teeno "edit" nahi ho sakte -- fixed/curated packs hain.
const List<String> bundledIconPacks = ['cartoon', 'flat_colors', 'dark_mode'];

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
const List<String> categoryTabs = [...bundledIconPacks, autoCategoryId, customCategoryId];

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

/// Curated exact-package mapping -- well-known apps (WhatsApp, Instagram,
/// etc.) ko unka apna distinct iconKey milta hai, generic category-guess
/// (neeche wala _guessKeywordIconKey) ki wajah se ek jaisa shared icon nahi
/// milta. Ye check hamesha keyword-guess se PEHLE hota hai (dekho
/// _guessIconKey neeche). Ye sirf bundled (Cartoon/Flat/Dark) tabs par
/// istemal hoti hai -- Auto tab is se independent hai (wo har app ka
/// apna real icon hi use karta hai, mapping ki zaroorat nahi).
///
/// NOTE -- asset status: filhaal sirf 10 keys ke PNGs bundled hain
/// (browser/calculator/calendar/camera/clock/contacts/gallery/messages/
/// phone/settings). Neeche wale naye keys (whatsapp/messenger/instagram/
/// facebook/youtube/telegram/gmail/snapchat/tiktok/x/spotify/netflix) ke
/// liye tab tak generic fallback icon hi dikhega jab tak aap
/// assets/icon_packs/<pack>/<key>.png add na karo -- crash nahi hoga
/// (IconListRow ka errorBuilder sambhal leta hai), matlab code abhi se
/// future-proof hai. Jaise-jaise PNGs add karti jaogi, wo apps automatically
/// apna distinct icon dikhane lagengi, koi aur code change nahi chahiye.
const Map<String, String> curatedPackageIconKeys = {
  'com.whatsapp': 'whatsapp',
  'com.whatsapp.w4b': 'whatsapp',
  'com.facebook.orca': 'messenger',
  'com.facebook.katana': 'facebook',
  'com.facebook.lite': 'facebook',
  'com.instagram.android': 'instagram',
  'com.google.android.youtube': 'youtube',
  'org.telegram.messenger': 'telegram',
  'com.google.android.gm': 'gmail',
  'com.snapchat.android': 'snapchat',
  'com.zhiliaoapp.musically': 'tiktok',
  'com.ss.android.ugc.trill': 'tiktok',
  'com.twitter.android': 'x',
  'com.spotify.music': 'spotify',
  'com.netflix.mediaclient': 'netflix',
};

/// Bundled icon packs sirf 10 fixed keywords cover karte hain (browser,
/// calculator, calendar, camera, clock, contacts, gallery, messages,
/// phone, settings). Real device par installed kisi bhi app ke liye
/// package name + label me in keywords ko dhoond kar best-guess iconKey
/// nikalta hai. Match na mile to null (row par bundled tabs pe generic
/// fallback icon dikhega, Custom/Auto tab phir bhi kaam karega).
String? _guessKeywordIconKey(String packageName, String label) {
  final p = packageName.toLowerCase();
  final l = label.toLowerCase();
  bool has(List<String> needles) =>
      needles.any((n) => p.contains(n) || l.contains(n));

  if (has(['chrome', 'browser', 'firefox', 'internet', 'webview'])) return 'browser';
  if (has(['calculator', 'calc'])) return 'calculator';
  if (has(['calendar'])) return 'calendar';
  if (has(['camera'])) return 'camera';
  if (has(['clock', 'deskclock', 'alarm'])) return 'clock';
  if (has(['contacts', 'people'])) return 'contacts';
  if (has(['gallery', 'photos', 'album', 'gallery3d'])) return 'gallery';
  if (has(['messag', 'sms', 'mms'])) return 'messages';
  if (has(['dialer', 'incallui']) || l == 'phone') return 'phone';
  if (has(['settings'])) return 'settings';
  return null;
}

/// Final iconKey resolver (bundled tabs ke liye): pehle curated
/// exact-package table check hoti hai (well-known apps ko unka apna icon),
/// tabhi na mile to generic keyword-category guess pe fallback hota hai.
String? _guessIconKey(String packageName, String label) {
  return curatedPackageIconKeys[packageName] ??
      _guessKeywordIconKey(packageName, label);
}

class IconChangerScreen extends StatefulWidget {
  const IconChangerScreen({super.key});
  @override
  State<IconChangerScreen> createState() => _IconChangerScreenState();
}

class _IconChangerScreenState extends State<IconChangerScreen> {
  String activeCategory = categoryTabs.first;

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

  // Checkbox reference design (Themie-style) me sab default-selected hote
  // hain -- "Apply All" isi selection set par kaam karta hai. Apps load
  // hone ke baad populate hota hai (ab const nahi ho sakta).
  final Set<String> _selectedPackages = {};

  bool get _isCustomTab => activeCategory == customCategoryId;
  bool get _isAutoTab => activeCategory == autoCategoryId;

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
              _guessIconKey(a.packageName, a.label),
            ))
        .toList();

    setState(() {
      _apps = apps;
      _selectedPackages
        ..clear()
        ..addAll(apps.map((a) => a.packageName));
      _loadingApps = false;
    });

    _loadExistingCustomIcons();
    _loadOldIcons();
    if (_isAutoTab) _loadAutoPreviews();
  }

  /// Har app ka asal (device par currently laga hua) launcher icon
  /// native side (PackageManager) se fetch karta hai -- row ke "before"
  /// preview ke liye. Koi bhi error par bytes null rehte hain aur UI
  /// khud generic fallback icon dikha deta hai.
  Future<void> _loadOldIcons() async {
    final results = await Future.wait(_apps.map((app) async {
      final bytes = await NativeBridgeService.instance.getAppIcon(app.packageName);
      return MapEntry(app.packageName, bytes);
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
    for (final app in _apps) {
      final path = await IconPackService.instance.getCustomIconPath(app.packageName);
      if (path != null && mounted) {
        setState(() {
          _customIconPaths[app.packageName] = path;
        });
      }
    }
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
  }

  void _onCategoryChanged(String id) {
    setState(() => activeCategory = id);
    if (id == autoCategoryId && _autoPreviewPaths.isEmpty && !_loadingAutoPreviews) {
      _loadAutoPreviews();
    }
  }

  void _onAutoShapeChanged(String shape) {
    setState(() => _autoShape = shape);
    _loadAutoPreviews();
  }

  void _onAutoStyleChanged(String style) {
    setState(() => _autoStyle = style);
    _loadAutoPreviews();
  }

  void _onAutoAccentChanged(Color color) {
    setState(() => _autoAccent = color);
    _loadAutoPreviews();
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
  Future<void> _applyAllSelected() async {
    final targets = _apps.where((a) => _selectedPackages.contains(a.packageName)).toList();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one app first')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Icon changer')),
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
          Expanded(
            child: _loadingApps
                ? const Center(child: CircularProgressIndicator())
                : _apps.isEmpty
                    ? const Center(child: Text('No installed apps found'))
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                        itemCount: _apps.length,
                        itemBuilder: (context, i) {
                          final app = _apps[i];
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