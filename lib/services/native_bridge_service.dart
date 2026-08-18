import 'dart:io';
import 'package:flutter/foundation.dart'; // debugPrint ke liye
import 'package:flutter/services.dart';

/// Device par real installed (launchable) app ka minimal record --
/// [getInstalledApps] se aata hai. Iconography ka koi concept yahan nahi,
/// wo UI layer (icon_changer_screen.dart) khud label/package se guess
/// karta hai, kyunke bundled icon packs sirf 10 fixed categories cover
/// karte hain.
///
/// [isSystemApp] -- true agar ye app ROM ka hissa hai (pre-installed).
/// Emulators par khaas taur par bohat saari dummy/third-party test apps
/// installed hoti hain jinke naam/keywords real system apps se milte-julte
/// hote hain (do "Browser" apps, do "Calculator" apps waghera) -- isi
/// wajah se keyword-based icon matching (jo poori installed-apps list par
/// chalti hai) confuse ho sakti hai. Callers is flag se apna matching
/// scope sirf system apps tak seemit rakh sakte hain.
class InstalledApp {
  final String packageName;
  final String label;
  final bool isSystemApp;
  const InstalledApp({
    required this.packageName,
    required this.label,
    this.isSystemApp = false,
  });
}

/// Ye class Flutter <-> Kotlin ke beech saara MethodChannel communication
/// handle karti hai. Naam se hi clear hai: "native se pull ya push" jo bhi
/// karna ho, yahin se ho.
class NativeBridgeService {
  NativeBridgeService._();
  static final NativeBridgeService instance = NativeBridgeService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.theme_studio/native');

  // ---------------- WALLPAPER ----------------

  /// [imagePath] ek real file-system path hona chahiye (asset nahi).
  /// [target] = "home", "lock", ya "both"
  Future<bool> setWallpaper(String imagePath, {String target = 'both'}) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('setWallpaper', {
        'path': imagePath,
        'target': target,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Wallpaper set failed: ${e.message}');
      return false;
    }
  }

  // ---------------- ICON SHORTCUT ----------------

  /// Installed app ka asal (current) launcher icon PNG bytes ke tor par
  /// laata hai -- Icon Changer screen ke "before -> after" preview ke liye.
  /// App uninstalled ho ya koi aur error aaye to null milega -- UI ko
  /// khud fallback (generic icon) dikhana chahiye.
  Future<Uint8List?> getAppIcon(String packageName) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('getAppIcon failed for $packageName: ${e.message}');
      return null;
    }
  }

  /// [packageName] jis app ka icon replace karna hai (e.g. "com.whatsapp")
  /// [appLabel] Home Screen par dikhne wala naam
  /// [iconFilePath] ek real PNG file ka path (asset ya custom, dono ko
  /// pehle IconPackService se file path me convert karna hoga)
  ///
  /// NOTE: Ye system ka "Add to Home Screen" confirmation dialog dikhayega.
  /// User ko manually confirm karna padega -- ye Android security policy hai,
  /// isko skip nahi kiya ja sakta.
  Future<bool> createIconShortcut({
    required String packageName,
    required String appLabel,
    required String iconFilePath,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('createShortcut', {
        'packageName': packageName,
        'appLabel': appLabel,
        'iconPath': iconFilePath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Shortcut creation failed: ${e.message}');
      return false;
    }
  }

  Future<bool> isPinShortcutSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isPinShortcutSupported');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('isPinShortcutSupported failed: ${e.message}');
      return false;
    }
  }

  /// Device par jitni bhi "launchable" apps installed hain unki real list
  /// (package name + label) -- demoApps ki jagah ye use hoti hai, taake
  /// Samsung/Infinix/koi bhi OEM ho, sahi package names hi milein.
  /// Non-Android platforms ya koi bhi error par khaali list milegi --
  /// UI ko khud "no apps found" state dikhana chahiye.
  Future<List<InstalledApp>> getInstalledApps() async {
    if (!Platform.isAndroid) return [];
    try {
      final result = await _channel.invokeMethod<List<Object?>>('getInstalledApps');
      if (result == null) return [];
      return result
          .whereType<Map<Object?, Object?>>()
          .map((raw) => InstalledApp(
                packageName: raw['packageName'] as String? ?? '',
                label: raw['label'] as String? ?? '',
                isSystemApp: raw['isSystemApp'] as bool? ?? false,
              ))
          .where((app) => app.packageName.isNotEmpty)
          .toList();
    } on PlatformException catch (e) {
      debugPrint('getInstalledApps failed: ${e.message}');
      return [];
    }
  }

  /// "Auto" tab ke liye -- kisi bhi installed app ka real icon leke,
  /// native side par consistent [shape] ("circle"/"squircle"), [style]
  /// ("classic"/"neon") aur duotone [accentColorHex] (e.g. "#00FFF0")
  /// treatment apply karke wapas bhejta hai. Har app automatically apna
  /// unique-but-themed icon paata hai, koi manual PNG ke bagair.
  Future<Uint8List?> getThemedAppIcon({
    required String packageName,
    required String shape,
    required String accentColorHex,
    String style = 'classic',
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<Uint8List>('getThemedAppIcon', {
        'packageName': packageName,
        'shape': shape,
        'accentColor': accentColorHex,
        'style': style,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('getThemedAppIcon failed for $packageName: ${e.message}');
      return null;
    }
  }

  // ---------------- CONTROL CENTER (Accessibility overlay) ----------------

  Future<bool> isAccessibilityServiceEnabled() async {
    if (!Platform.isAndroid) return false;
    final result =
        await _channel.invokeMethod<bool>('isAccessibilityEnabled');
    return result ?? false;
  }

  /// User ko seedha Settings > Accessibility screen par le jaata hai,
  /// jahan wo humari service ko manually ON karega. Ye bhi automatic
  /// nahi ho sakta -- Android khud user consent maangta hai.
  Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  // ---------------- NOTES WIDGET (in-app fallback editor) ----------------
  // Ye path sirf tab chalta hai jab Notes widget tap par device par koi
  // real notes app (Samsung Notes/Google Keep/wagera) resolve nahi hota --
  // WidgetClickActions.kt (Kotlin) ka last-resort fallback isi screen ko
  // launch karta hai.

  Future<String?> getNoteText() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getNoteText');
    } on PlatformException catch (e) {
      debugPrint('getNoteText failed: ${e.message}');
      return null;
    }
  }

  Future<bool> saveNoteText(String text) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('saveNoteText', {'text': text});
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('saveNoteText failed: ${e.message}');
      return false;
    }
  }

  /// Pehle device ka real Notes app (CREATE_NOTE / known OEM packages) kholne
  /// ki koshish karta hai -- widget tap wala hi flow, taake in-app card se
  /// bhi behavior consistent rahe. Koi notes app na mile to hamari apni
  /// fallback editor khulti hai (native side already handle karta hai).
  Future<void> openNotesApp() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openNotesApp');
    } on PlatformException catch (e) {
      debugPrint('openNotesApp failed: ${e.message}');
    }
  }

  // ---------------- WEATHER WIDGET LOCATION ----------------

  /// Caller ko location permission pehle khud maangni chahiye
  /// (permission_handler se) -- ye method sirf last-known location padh
  /// kar "City, Country" string banata hai aur native side cache/pinned-
  /// widget refresh bhi karta hai. Permission na ho, location off ho, ya
  /// geocoding fail ho to null -- caller "location unavailable" dikhaye.
  Future<String?> getWeatherLocation() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getWeatherLocation');
    } on PlatformException catch (e) {
      debugPrint('getWeatherLocation failed: ${e.message}');
      return null;
    }
  }

  /// Location fetch hone ke turant baad native side jo real temp/condition
  /// (Open-Meteo se) cache karta hai, wahi yahan se padhte hain -- koi naya
  /// network call nahi, sirf cached values. Fetch abhi tak na hui ho to
  /// sab null/khaali milte hain -- caller "--°"/loading state dikhaye.
  ///
  /// NOTE: `hourly` baaki keys jaisi plain String nahi -- ye ek List of
  /// maps hai (har ghante ka time/temp/condition), isliye poore result ko
  /// ek hi type mein blindly cast nahi kar sakte, har key ko uske apne
  /// type ke hisaab se nikaalna padta hai.
  Future<Map<String, dynamic>> getWeatherSnapshot() async {
    if (!Platform.isAndroid) return {};
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getWeatherSnapshot');
      if (result == null) return {};

      final hourlyRaw = result['hourly'];
      final hourly = hourlyRaw is List
          ? hourlyRaw
              .whereType<Map<Object?, Object?>>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
              .toList()
          : <Map<String, String>>[];

      return {
        'temperature': result['temperature'] as String?,
        'condition': result['condition'] as String?,
        'feelsLike': result['feelsLike'] as String?,
        'humidity': result['humidity'] as String?,
        'wind': result['wind'] as String?,
        'hourly': hourly,
      };
    } on PlatformException catch (e) {
      debugPrint('getWeatherSnapshot failed: ${e.message}');
      return {};
    }
  }

  /// Sirf cached label padhta hai -- na GPS, na permission prompt, na
  /// network call. Widgets screen khulte hi ye chalta hai taake koi
  /// surprising "location khud badal gayi" na ho, sirf jo user ne pehle
  /// khud choose ki thi wahi dikhe. Kabhi location choose hi na ki ho to null.
  Future<String?> getSavedWeatherLocation() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getSavedWeatherLocation');
    } on PlatformException catch (e) {
      debugPrint('getSavedWeatherLocation failed: ${e.message}');
      return null;
    }
  }

  /// City-name search (Open-Meteo Geocoding, native side call karta hai) --
  /// har result mein name/admin1(region)/country/lat/lon hote hain. Query
  /// bohat chhoti ho (< 2 characters) to native khaali list de deta hai.
  Future<List<Map<String, dynamic>>> searchWeatherLocations(String query) async {
    if (!Platform.isAndroid) return [];
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'searchWeatherLocations',
        {'query': query},
      );
      if (result == null) return [];
      return result
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } on PlatformException catch (e) {
      debugPrint('searchWeatherLocations failed: ${e.message}');
      return [];
    }
  }

  /// User ne search results mein se jo jagah choose ki, usi ke liye native
  /// side real weather fetch/cache karta hai aur label save karta hai --
  /// isi cache se pinned Weather widget bhi turant sync ho jata hai.
  Future<bool> setWeatherLocation({
    required double lat,
    required double lon,
    required String label,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('setWeatherLocation', {
        'lat': lat,
        'lon': lon,
        'label': label,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('setWeatherLocation failed: ${e.message}');
      return false;
    }
  }

  /// Har widget type ke abhi kitne instances Home Screen par pinned hain
  /// -- seedha AppWidgetManager se aata hai (live system state), isliye
  /// hamesha accurate hota hai chahe user ne widget Home Screen se
  /// directly remove kiya ho. Error/non-Android par khaali map -- caller
  /// har type ke liye 0 treat kare.
  Future<Map<String, int>> getPinnedWidgetCounts() async {
    if (!Platform.isAndroid) return {};
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getPinnedWidgetCounts');
      if (result == null) return {};
      return result.map((key, value) => MapEntry(key.toString(), (value as int?) ?? 0));
    } on PlatformException catch (e) {
      debugPrint('getPinnedWidgetCounts failed: ${e.message}');
      return {};
    }
  }

  // ---------------- WIDGET PIN / STYLE ----------------

  /// Apna khud ka custom widget (Battery/Clock/Weather/Calendar/Notes)
  /// Home Screen par pin karne ki request bhejta hai. Style/mode bhi
  /// saath bhejte hain taake pinned widget turant sahi look mein dikhe.
  /// [fontSize], [textColorHex], [bgOpacity], [cornerRadius] customization
  /// params bhi saath jaate hain taake native side unhe apply kar sake.
  Future<bool> requestPinWidget({
    required String widgetType,
    required String style,
    required String mode,
    double? fontSize,
    String? textColorHex,
    double? bgOpacity,
    double? cornerRadius,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPinWidget', {
        'widgetType': widgetType,
        'style': style,
        'mode': mode,
        if (fontSize != null) 'fontSize': fontSize,
        if (textColorHex != null) 'textColor': textColorHex,
        if (bgOpacity != null) 'bgOpacity': bgOpacity,
        if (cornerRadius != null) 'cornerRadius': cornerRadius,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('requestPinWidget failed: ${e.message}');
      return false;
    }
  }

  /// Device par installed real Notes/Weather app ka asal widget pin
  /// karne ki request (custom widget ke bajaye). Sirf "notes" aur
  /// "weather" types ke liye -- baaki types requestPinWidget se pin
  /// hote hain.
  Future<bool> requestPinExternalWidget(String widgetType) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPinExternalWidget', {
        'widgetType': widgetType,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('requestPinExternalWidget failed: ${e.message}');
      return false;
    }
  }

  /// Already-pinned widgets ko naya style/mode apply karne par turant
  /// refresh karta hai -- user ko re-pin nahi karna padta.
  Future<bool> updateWidgetStyle({
    required String widgetType,
    required String style,
    required String mode,
    double? fontSize,
    String? textColorHex,
    double? bgOpacity,
    double? cornerRadius,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('updateWidgetStyle', {
        'widgetType': widgetType,
        'style': style,
        'mode': mode,
        if (fontSize != null) 'fontSize': fontSize,
        if (textColorHex != null) 'textColor': textColorHex,
        if (bgOpacity != null) 'bgOpacity': bgOpacity,
        if (cornerRadius != null) 'cornerRadius': cornerRadius,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('updateWidgetStyle failed: ${e.message}');
      return false;
    }
  }

  // ---------------- WIDGET CUSTOMIZATION ----------------

  Future<bool> saveWidgetCustomization({
    required double fontSize,
    required String textColorHex,
    required double bgOpacity,
    required double cornerRadius,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('saveWidgetCustomization', {
        'fontSize': fontSize,
        'textColor': textColorHex,
        'bgOpacity': bgOpacity,
        'cornerRadius': cornerRadius,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('saveWidgetCustomization failed: ${e.message}');
      return false;
    }
  }

  Future<Map<String, dynamic>> getWidgetCustomization() async {
    if (!Platform.isAndroid) return {};
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getWidgetCustomization');
      if (result == null) return {};
      return result.map((key, value) => MapEntry(key.toString(), value));
    } on PlatformException catch (e) {
      debugPrint('getWidgetCustomization failed: ${e.message}');
      return {};
    }
  }

  /// Native (Kotlin) se Dart ko bheje gaye calls sunta hai. Abhi sirf
  /// "openNotesEditor" ke liye use hota hai -- jab app already chal rahi ho
  /// (warm start) aur Notes widget ka fallback-editor tap aaye, MainActivity
  /// isi channel par invokeMethod karta hai taake Dart navigate kar sake.
  /// Ye MaterialApp ke top-level state se ek hi dafa register hona chahiye.
  void setIncomingCallHandler(Future<void> Function(String method) handler) {
    _channel.setMethodCallHandler((call) async {
      await handler(call.method);
    });
  }
}