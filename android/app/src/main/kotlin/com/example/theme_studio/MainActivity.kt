package com.example.theme_studio

import android.app.WallpaperManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.theme_studio/native"
    private var methodChannel: MethodChannel? = null

    companion object {
        /// NotesWidgetProvider (fallback, jab device par koi real notes app
        /// na mile) isi extra ke saath MainActivity ko launch karta hai.
        const val EXTRA_OPEN_NOTES_EDITOR = "open_notes_editor"
    }

    /// Cold start (app band thi, widget tap se pehli dafa khuli) -- Flutter
    /// side ko seedha "/notes_editor" route par le jaate hain, splash
    /// screen ke bagair (widget tap ka matlab hi hai seedha note edit karna).
    override fun getInitialRoute(): String? {
        if (intent?.getBooleanExtra(EXTRA_OPEN_NOTES_EDITOR, false) == true) {
            return "/notes_editor"
        }
        return super.getInitialRoute()
    }

    /// Warm start -- app already chal rahi thi (launchMode="singleTop" ki
    /// wajah se yahin call aata hai, nayi Activity instance nahi banti).
    /// Flutter engine already ready hai, isliye method channel se seedha
    /// Dart ko batate hain ke navigate kare.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(EXTRA_OPEN_NOTES_EDITOR, false)) {
            methodChannel?.invokeMethod("openNotesEditor", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {

                // ---------------- WALLPAPER ----------------
                "setWallpaper" -> {
                    val path = call.argument<String>("path")
                    val target = call.argument<String>("target") ?: "both"
                    result.success(setWallpaperFromPath(path, target))
                }

                // ---------------- ICON SHORTCUT ----------------
                "createShortcut" -> {
                    val packageName = call.argument<String>("packageName")
                    val appLabel = call.argument<String>("appLabel")
                    val iconPath = call.argument<String>("iconPath")
                    result.success(createCustomIconShortcut(packageName, appLabel, iconPath))
                }
                "isPinShortcutSupported" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val sm = getSystemService(ShortcutManager::class.java)
                        result.success(sm?.isRequestPinShortcutSupported ?: false)
                    } else {
                        result.success(false)
                    }
                }
                // Installed app ka current (asal) launcher icon PNG bytes ke
                // tor par wapas bhejta hai -- Icon Changer screen ke "before"
                // preview ke liye. Package not found ya koi bhi error par null.
                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName")
                    result.success(getAppIconBytes(packageName))
                }

                // Device par jitni bhi "launchable" apps installed hain
                // (jinki Home Screen / app drawer me entry hoti hai) unki
                // real list -- Icon Changer screen ab isse populate hoti hai,
                // hardcoded demo list ke bajaye.
                "getInstalledApps" -> {
                    result.success(getInstalledLaunchableApps())
                }

                // ---------------- NOTES WIDGET (in-app fallback editor) ----------------
                // Ye sirf tab use hota hai jab device par koi real notes app
                // resolve nahi hota (WidgetClickActions.openNotesEditor ka
                // last-resort fallback) -- normal case mein Samsung
                // Notes/Google Keep wagera seedha khulte hain, ye path nahi
                // chalta.
                "getNoteText" -> {
                    val prefs = getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
                    result.success(prefs.getString("notes_text", null))
                }
                "saveNoteText" -> {
                    val text = call.argument<String>("text") ?: ""
                    saveNoteTextAndRefreshWidget(text)
                    result.success(true)
                }
                // In-app "Notes" card ke footnote se bhi wahi flow chalana hai
                // jo pinned widget tap par chalta hai -- pehle device ka real
                // Notes app (CREATE_NOTE / known OEM packages), warna hamari
                // apni fallback editor. Isse behavior har jagah consistent
                // rehta hai (hamesha mobile ka apna Notes app khulta hai).
                "openNotesApp" -> {
                    WidgetClickActions.openNotesEditor(this)
                    result.success(true)
                }

                // Real app icon leke automatically ek consistent shape +
                // duotone color treatment apply karta hai -- "Auto" tab ke
                // liye, jahan har installed app ka khud-ba-khud themed icon
                // ban jaata hai, koi manual PNG design kiye bagair.
                "getThemedAppIcon" -> {
                    val packageName = call.argument<String>("packageName")
                    val shape = call.argument<String>("shape") ?: "circle"
                    val accentColor = call.argument<String>("accentColor")
                    val style = call.argument<String>("style") ?: "classic"
                    result.success(getThemedAppIconBytes(packageName, shape, accentColor, style))
                }

                // ---------------- CONTROL CENTER (Accessibility) ----------------
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }

                // ---------------- WIDGETS ----------------
                "requestPinWidget" -> {
                    val widgetType = call.argument<String>("widgetType") ?: "battery"
                    val style = call.argument<String>("style") ?: "minimal"
                    val mode = call.argument<String>("mode") ?: WidgetStyleHelper.MODE_DARK
                    result.success(requestPinWidget(widgetType, style, mode))
                }
                "updateWidgetStyle" -> {
                    val widgetType = call.argument<String>("widgetType") ?: "battery"
                    val style = call.argument<String>("style") ?: "minimal"
                    val mode = call.argument<String>("mode") ?: WidgetStyleHelper.MODE_DARK
                    result.success(updateWidgetStyle(widgetType, style, mode))
                }
                "getPinnedWidgetCounts" -> {
                    result.success(getPinnedWidgetCounts())
                }

                // ---------------- WEATHER WIDGET LOCATION ----------------
                // Flutter side permission_handler se ACCESS_COARSE_LOCATION
                // maang chuka hota hai is call se pehle -- yahan sirf last-known
                // location padh kar (Geocoder se) "City, Country" banate hain,
                // cache karte hain (pinned widget ke liye) aur wapas bhejte hain
                // (in-app preview turant update karne ke liye).
                "getWeatherLocation" -> {
                    result.success(fetchAndCacheWeatherLocation())
                }
                "getWeatherSnapshot" -> {
                    val prefs = getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
                    result.success(
                        mapOf(
                            "temperature" to prefs.getString("weather_temp", null),
                            "condition" to prefs.getString("weather_condition", null),
                        )
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    // ============ WALLPAPER LOGIC ============
    private fun setWallpaperFromPath(path: String?, target: String): Boolean {
        if (path == null) return false
        return try {
            val file = File(path)
            if (!file.exists()) return false
            val bitmap = BitmapFactory.decodeFile(path)
            val wallpaperManager = WallpaperManager.getInstance(applicationContext)

            when (target) {
                "home" -> wallpaperManager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_SYSTEM)
                "lock" -> wallpaperManager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_LOCK)
                else -> {
                    // "both" -- Android 13+ ke liye FLAG_SYSTEM or FLAG_LOCK combine
                    wallpaperManager.setBitmap(
                        bitmap, null, true,
                        WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                    )
                }
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // ============ APP ICON FETCH (for Icon Changer "before" preview) ============
    private fun getAppIconBytes(packageName: String?): ByteArray? {
        if (packageName == null) return null
        return try {
            val drawable: Drawable = packageManager.getApplicationIcon(packageName)
            val bitmap = drawableToBitmap(drawable)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            // Sabse aam wajah: PackageManager.NameNotFoundException agar
            // app device par installed nahi hai (demo/uninstalled package).
            e.printStackTrace()
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 108
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 108
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    // ============ AUTO ICON THEMING (duotone + shape mask) ============
    // Kisi bhi installed app ka real launcher icon leke, ek consistent
    // "pack" style banata hai -- taake har app alag/unique rahe (asal
    // artwork wahi hai) lekin sab icons ek hi shape + color-language share
    // karein. Zero manual design -- purely programmatic.
    private fun getThemedAppIconBytes(
        packageName: String?,
        shape: String,
        accentColorHex: String?,
        style: String
    ): ByteArray? {
        if (packageName == null) return null
        return try {
            val drawable = packageManager.getApplicationIcon(packageName)
            val source = drawableToBitmap(drawable)
            val accent = try {
                Color.parseColor(accentColorHex ?: "#00FFF0")
            } catch (e: Exception) {
                Color.parseColor("#00FFF0")
            }
            val themed = if (style == "neon") {
                applyNeonGlassTheme(source, shape, accent)
            } else {
                applyDuotoneTheme(source, shape, accent)
            }
            val stream = ByteArrayOutputStream()
            themed.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            // Sabse aam wajah: app installed nahi (PackageManager.NameNotFoundException)
            e.printStackTrace()
            null
        }
    }

    /// [source] = asal app icon. Steps: (1) shadow/elevation, (2) gradient
    /// backplate, (3) icon ko transparent-padding trim karke consistent
    /// scale pe normalize karo, phir grayscale+accent-tint (duotone) karke
    /// draw karo, (4) ring/outline border, (5) corner accent badge. Sab
    /// icons ek hi "signature" share karte hain chahe asal artwork alag ho.
    private fun applyDuotoneTheme(source: Bitmap, shape: String, accent: Int): Bitmap {
        val size = 192 // fixed output size -- sab themed icons same resolution
        val margin = size * 0.07f // shadow + ring ke liye jagah chhodte hain
        val plate = RectF(margin, margin, size - margin, size - margin)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        val path = Path()
        if (shape == "circle") {
            path.addOval(plate, Path.Direction.CW)
        } else {
            // squircle -- generous corner radius, iOS-style rounded square
            val r = plate.width() * 0.34f
            path.addRoundRect(plate, r, r, Path.Direction.CW)
        }

        // 1) Shadow/elevation -- plate shape ka halka blurred saaya, thoda
        // neeche offset, taake sab icons "floating" jaisi depth paayein.
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(90, 0, 0, 0)
            maskFilter = BlurMaskFilter(size * 0.035f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.save()
        canvas.translate(0f, size * 0.03f)
        canvas.drawPath(path, shadowPaint)
        canvas.restore()

        // 2) Gradient backplate -- accent se uske darker shade tak, diagonal.
        // Flat color se zyada "designed" lagta hai, har icon isi gradient
        // recipe ko accent ke hisaab se follow karta hai.
        val plateGradient = LinearGradient(
            plate.left, plate.top, plate.right, plate.bottom,
            accent, darkenColor(accent, 0.45f),
            Shader.TileMode.CLAMP
        )
        val platePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { shader = plateGradient }
        canvas.drawPath(path, platePaint)

        // 3) Icon -- pehle transparent padding trim karo (consistent scale
        // normalization: kuch apps ke icons poora square bharte hain, kuch
        // mein zyada padding hoti hai -- trim karke sab ka visual weight
        // barabar kar dete hain), phir grayscale+accent-tint (duotone).
        val trimmed = try {
            val bounds = computeOpaqueBounds(source)
            Bitmap.createBitmap(source, bounds.left, bounds.top, bounds.width(), bounds.height())
        } catch (e: Exception) {
            source
        }

        val grayscale = ColorMatrix()
        grayscale.setSaturation(0f)
        val tint = ColorMatrix(
            floatArrayOf(
                Color.red(accent) / 255f, 0f, 0f, 0f, 0f,
                0f, Color.green(accent) / 255f, 0f, 0f, 0f,
                0f, 0f, Color.blue(accent) / 255f, 0f, 0f,
                0f, 0f, 0f, 1f, 0f
            )
        )
        grayscale.postConcat(tint)
        val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            colorFilter = ColorMatrixColorFilter(grayscale)
        }

        canvas.save()
        canvas.clipPath(path)
        val iconInset = plate.width() * 0.22f
        val iconRect = RectF(
            plate.left + iconInset, plate.top + iconInset,
            plate.right - iconInset, plate.bottom - iconInset
        )
        canvas.drawBitmap(trimmed, null, iconRect, iconPaint)
        canvas.restore()

        // 4) Ring/outline border -- plate shape ke around ek thin, consistent
        // stroke, har icon pe same rehta hai.
        val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = size * 0.02f
            color = Color.argb(200, 255, 255, 255)
        }
        canvas.drawPath(path, ringPaint)

        // 5) Corner accent badge -- bottom-right corner par ek chhota dot,
        // pack ki "signature" jaisa, har icon pe identical.
        val badgeRadius = size * 0.075f
        val badgeCenterX = plate.right - badgeRadius * 0.3f
        val badgeCenterY = plate.bottom - badgeRadius * 0.3f
        val badgeRingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        canvas.drawCircle(badgeCenterX, badgeCenterY, badgeRadius + size * 0.012f, badgeRingPaint)
        val badgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent }
        canvas.drawCircle(badgeCenterX, badgeCenterY, badgeRadius, badgePaint)

        return output
    }

    /// "Neon Glass" style -- [source] = asal app icon. Elements: outer neon
    /// glow, two-tone diagonal split background, frosted-glass overlay,
    /// dot-grid micro-texture, glossy top-shine, aur gradient ring border.
    /// Icon khud wahi grayscale+accent-tint (duotone) treatment leta hai
    /// jo Classic style mein hai, taake dono styles ek hi color-identity
    /// share karein, sirf background/border ka treatment alag ho.
    private fun applyNeonGlassTheme(source: Bitmap, shape: String, accent: Int): Bitmap {
        val size = 192
        val margin = size * 0.10f // neon glow ke liye extra jagah
        val plate = RectF(margin, margin, size - margin, size - margin)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        val path = Path()
        if (shape == "circle") {
            path.addOval(plate, Path.Direction.CW)
        } else {
            val r = plate.width() * 0.34f
            path.addRoundRect(plate, r, r, Path.Direction.CW)
        }

        val secondary = shiftHue(accent, 40f) // two-tone split ke liye complement

        // 1) Outer glow (neon) -- BlurMaskFilter.Blur.OUTER sirf shape ke
        // BAHAR blur karta hai, andar transparent rehta hai. Plate se
        // pehle draw karte hain taake glow neeche/bahar dikhe.
        val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = accent
            maskFilter = BlurMaskFilter(size * 0.05f, BlurMaskFilter.Blur.OUTER)
        }
        canvas.drawPath(path, glowPaint)

        canvas.save()
        canvas.clipPath(path)

        // 2) Two-tone diagonal split background.
        val splitPaintA = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent }
        canvas.drawRect(plate, splitPaintA)
        val splitPaintB = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = secondary }
        val diagonal = Path().apply {
            moveTo(plate.left, plate.bottom)
            lineTo(plate.right, plate.bottom)
            lineTo(plate.right, plate.top)
            close()
        }
        canvas.drawPath(diagonal, splitPaintB)

        // 3) Frosted glass overlay -- halka milky/semi-transparent layer.
        val glassPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(55, 255, 255, 255)
        }
        canvas.drawRect(plate, glassPaint)

        // 4) Dot-grid micro-texture -- subtle material-jaisa feel.
        val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(45, 255, 255, 255)
        }
        val step = size * 0.09f
        var gy = plate.top + step / 2
        while (gy < plate.bottom) {
            var gx = plate.left + step / 2
            while (gx < plate.right) {
                canvas.drawCircle(gx, gy, size * 0.006f, dotPaint)
                gx += step
            }
            gy += step
        }

        // 5) Inner glow / glossy top-shine.
        val shineRect = RectF(plate.left, plate.top, plate.right, plate.top + plate.height() * 0.55f)
        val shinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f, shineRect.top, 0f, shineRect.bottom,
                Color.argb(90, 255, 255, 255), Color.argb(0, 255, 255, 255),
                Shader.TileMode.CLAMP
            )
        }
        canvas.drawOval(shineRect, shinePaint)

        // 6) Icon -- trim (consistent scale) + grayscale/accent-tint (duotone).
        val trimmed = try {
            val bounds = computeOpaqueBounds(source)
            Bitmap.createBitmap(source, bounds.left, bounds.top, bounds.width(), bounds.height())
        } catch (e: Exception) {
            source
        }
        val grayscale = ColorMatrix()
        grayscale.setSaturation(0f)
        val tint = ColorMatrix(
            floatArrayOf(
                Color.red(accent) / 255f, 0f, 0f, 0f, 0f,
                0f, Color.green(accent) / 255f, 0f, 0f, 0f,
                0f, 0f, Color.blue(accent) / 255f, 0f, 0f,
                0f, 0f, 0f, 1f, 0f
            )
        )
        grayscale.postConcat(tint)
        val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            colorFilter = ColorMatrixColorFilter(grayscale)
        }
        val iconInset = plate.width() * 0.22f
        val iconRect = RectF(
            plate.left + iconInset, plate.top + iconInset,
            plate.right - iconInset, plate.bottom - iconInset
        )
        canvas.drawBitmap(trimmed, null, iconRect, iconPaint)

        canvas.restore()

        // 7) Gradient ring border -- solid stroke ki jagah accent->white.
        val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = size * 0.02f
            shader = LinearGradient(
                plate.left, plate.top, plate.right, plate.bottom,
                accent, Color.WHITE,
                Shader.TileMode.CLAMP
            )
        }
        canvas.drawPath(path, ringPaint)

        return output
    }

    /// Accent color ka hue thoda shift karke ek complementary secondary
    /// color deta hai -- two-tone split background ke doosre rang ke liye.
    private fun shiftHue(color: Int, degrees: Float): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        hsv[0] = (hsv[0] + degrees) % 360f
        return Color.HSVToColor(hsv)
    }

    /// Source bitmap ke non-transparent pixels ki bounding box dhoondta hai
    /// -- alag-alag app icons mein built-in padding alag hoti hai, is trim
    /// ke bagair "consistent inset/scale" possible nahi (kuch icons chhote
    /// aur kuch bade dikhte). Alpha > 10 wale pixels hi "content" maane
    /// jaate hain (halke anti-aliased edges ignore ho jaate hain).
    private fun computeOpaqueBounds(bitmap: Bitmap): Rect {
        val w = bitmap.width
        val h = bitmap.height
        val pixels = IntArray(w * h)
        bitmap.getPixels(pixels, 0, w, 0, 0, w, h)

        var left = w
        var top = h
        var right = 0
        var bottom = 0
        for (y in 0 until h) {
            val rowOffset = y * w
            for (x in 0 until w) {
                val alpha = (pixels[rowOffset + x] ushr 24) and 0xFF
                if (alpha > 10) {
                    if (x < left) left = x
                    if (x > right) right = x
                    if (y < top) top = y
                    if (y > bottom) bottom = y
                }
            }
        }
        return if (right < left || bottom < top) {
            Rect(0, 0, w, h) // fully-transparent edge case -- poora bitmap use karo
        } else {
            Rect(left, top, right + 1, bottom + 1)
        }
    }

    private fun darkenColor(color: Int, amount: Float): Int {
        val r = (Color.red(color) * (1 - amount)).toInt().coerceIn(0, 255)
        val g = (Color.green(color) * (1 - amount)).toInt().coerceIn(0, 255)
        val b = (Color.blue(color) * (1 - amount)).toInt().coerceIn(0, 255)
        return Color.rgb(r, g, b)
    }

    // ============ INSTALLED APPS (real device list) ============
    // Har wo app jiski Home Screen / app drawer me apni entry hoti hai
    // (ACTION_MAIN + CATEGORY_LAUNCHER) -- ye query OEM-independent hai,
    // isliye Samsung/Infinix/stock Android sab par sahi package names
    // aur labels return karta hai, hardcoded list ke bajaye.
    private fun getInstalledLaunchableApps(): List<Map<String, String>> {
        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)

        val resolveInfos = packageManager.queryIntentActivities(mainIntent, 0)
        val ownPackage = packageName // apni khud ki app list me na dikhe

        val seen = LinkedHashSet<String>()
        val apps = mutableListOf<Map<String, String>>()

        for (info in resolveInfos) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == ownPackage) continue
            if (!seen.add(pkg)) continue // kai apps ke 2 launcher activities ho sakti hain

            val label = try {
                info.loadLabel(packageManager).toString()
            } catch (e: Exception) {
                pkg
            }
            apps.add(mapOf("packageName" to pkg, "label" to label))
        }

        // Label ke hisaab se alphabetically sort -- predictable UI order.
        return apps.sortedBy { it["label"]?.lowercase() ?: "" }
    }

    // ============ NOTES WIDGET (in-app fallback editor) ============
    /// Note text SharedPreferences mein save karta hai aur agar Notes
    /// widget kahin bhi pinned hai to usse turant refresh (re-render)
    /// karta hai -- user ko dobara pin karne ki zarurat nahi.
    private fun saveNoteTextAndRefreshWidget(text: String) {
        val prefs = getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString("notes_text", text).apply()

        val manager = AppWidgetManager.getInstance(this)
        val ids = manager.getAppWidgetIds(ComponentName(this, NotesWidgetProvider::class.java))
        if (ids.isNotEmpty()) {
            val updateIntent = Intent(this, NotesWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            sendBroadcast(updateIntent)
        }
    }

    // ============ SHORTCUT LOGIC ============
    private fun createCustomIconShortcut(
        packageName: String?,
        appLabel: String?,
        iconPath: String?
    ): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (packageName == null || appLabel == null || iconPath == null) return false

        val shortcutManager = getSystemService(ShortcutManager::class.java) ?: return false
        if (!shortcutManager.isRequestPinShortcutSupported) return false

        return try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                ?: return false
            launchIntent.action = Intent.ACTION_MAIN

            val bitmap = BitmapFactory.decodeFile(iconPath) ?: return false
            val customIcon = Icon.createWithBitmap(bitmap)

            val shortcut = ShortcutInfo.Builder(this, "shortcut_$packageName")
                .setShortLabel(appLabel)
                .setLongLabel(appLabel)
                .setIcon(customIcon)
                .setIntent(launchIntent)
                .build()

            shortcutManager.requestPinShortcut(shortcut, null)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // ============ ACCESSIBILITY CHECK ============
    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedComponentName = ComponentName(this, ControlCenterAccessibilityService::class.java)
        val enabledServicesSetting = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentName = ComponentName.unflattenFromString(colonSplitter.next())
            if (componentName != null && componentName == expectedComponentName) {
                return true
            }
        }
        return false
    }

    // ============ WIDGET PIN REQUEST ============
    private fun providerFor(widgetType: String): ComponentName? = when (widgetType) {
        "battery" -> ComponentName(this, BatteryWidgetProvider::class.java)
        "clock" -> ComponentName(this, ClockWidgetProvider::class.java)
        "weather" -> ComponentName(this, WeatherWidgetProvider::class.java)
        "calendar" -> ComponentName(this, CalendarWidgetProvider::class.java)
        "notes" -> ComponentName(this, NotesWidgetProvider::class.java)
        else -> null
    }

    private fun requestPinWidget(widgetType: String, style: String, mode: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val appWidgetManager = getSystemService(AppWidgetManager::class.java) ?: return false
        val provider = providerFor(widgetType) ?: return false

        // Style + mode ko PEHLE save kar dete hain -- taake pinning ke baad
        // jab provider ka onUpdate pehli dafa chale, sahi values already
        // SharedPreferences mein maujood hon.
        WidgetStyleHelper.saveStyle(this, widgetType, style)
        WidgetStyleHelper.saveMode(this, widgetType, mode)

        return if (appWidgetManager.isRequestPinAppWidgetSupported) {
            appWidgetManager.requestPinAppWidget(provider, null, null)
            true
        } else {
            false
        }
    }

    /// User agar app ke andar style/mode badalta hai (bina naya widget pin
    /// kiye), to already-pinned instances ko bhi turant re-style karta
    /// hai -- provider ka apna onUpdate() reuse karte hain (broadcast ke
    /// zariye), taake update-logic kahin duplicate na ho.
    private fun updateWidgetStyle(widgetType: String, style: String, mode: String): Boolean {
        val provider = providerFor(widgetType) ?: return false
        WidgetStyleHelper.saveStyle(this, widgetType, style)
        WidgetStyleHelper.saveMode(this, widgetType, mode)

        val appWidgetManager = getSystemService(AppWidgetManager::class.java) ?: return false
        val ids = appWidgetManager.getAppWidgetIds(provider)
        if (ids.isEmpty()) return true // koi pinned instance nahi -- agli baar pin hone par apply hogi

        val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
            component = provider
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        sendBroadcast(intent)
        return true
    }

    /// Har widget type ke abhi kitne instances Home Screen par pinned hain,
    /// seedha AppWidgetManager se -- ye system ki apni live state hai
    /// (koi manual counter maintain nahi karna padta), isliye add/remove
    /// dono khud-ba-khud sahi reflect hote hain, chahe remove user ne
    /// Home Screen se directly kiya ho (long-press > Remove).
    private fun getPinnedWidgetCounts(): Map<String, Int> {
        val appWidgetManager = getSystemService(AppWidgetManager::class.java) ?: return emptyMap()
        val types = listOf("battery", "clock", "weather", "calendar", "notes")
        return types.associateWith { type ->
            providerFor(type)?.let { appWidgetManager.getAppWidgetIds(it).size } ?: 0
        }
    }

    /// Open-Meteo (free, koi API key ya signup nahi chahiye) se real
    /// current temperature + condition fetch karke SharedPreferences mein
    /// cache karta hai, phir pinned Weather widgets ko refresh karta hai.
    /// Yahi cache dono jagah use hoti hai -- pinned widget (native) aur
    /// in-app preview (Dart ka getWeatherSnapshot). Geocoder ki tarah ye
    /// bhi thodi der ka blocking network call hai -- existing pattern se
    /// consistent, aur ek single quick request hone ki wajah se practically
    /// ANR ka risk nahi.
    private fun fetchAndCacheCurrentWeather(lat: Double, lon: Double) {
        try {
            val url = java.net.URL(
                "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true"
            )
            val connection = url.openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 8000
            connection.readTimeout = 8000

            if (connection.responseCode != 200) {
                connection.disconnect()
                return
            }
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            connection.disconnect()

            val current = org.json.JSONObject(body).getJSONObject("current_weather")
            val tempC = current.getDouble("temperature")
            val code = current.getInt("weathercode")

            val prefs = getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putString("weather_temp", "${Math.round(tempC)}°")
                .putString("weather_condition", weatherCodeToLabel(code))
                .apply()
        } catch (e: Exception) {
            // Network na ho, API down ho, ya JSON parse fail ho -- cache
            // jaisi thi waisi rehti hai (ya khaali), UI khud fallback dikhati hai.
            e.printStackTrace()
        }
    }

    /// WMO weather-interpretation codes (Open-Meteo isi standard ko follow
    /// karta hai) ko chhoti insaan-parh-sake condition string mein badalta hai.
    private fun weatherCodeToLabel(code: Int): String = when (code) {
        0 -> "Clear sky"
        1, 2 -> "Partly cloudy"
        3 -> "Overcast"
        45, 48 -> "Foggy"
        51, 53, 55 -> "Drizzle"
        56, 57 -> "Freezing drizzle"
        61, 63, 65 -> "Rain"
        66, 67 -> "Freezing rain"
        71, 73, 75, 77 -> "Snow"
        80, 81, 82 -> "Rain showers"
        85, 86 -> "Snow showers"
        95 -> "Thunderstorm"
        96, 99 -> "Thunderstorm, hail"
        else -> "Unknown"
    }

    // ============ WEATHER WIDGET LOCATION ============
    /// Last-known location (GPS ya NETWORK provider, jo bhi pehle mile)
    /// leke Geocoder se "City, Country" banata hai, cache karta hai
    /// (WeatherWidgetProvider isi cache se padhta hai) aur pinned weather
    /// widgets ko turant refresh bhi karta hai -- taake home-screen widget
    /// bhi in-app preview jitna hi up-to-date rahe. Permission na di gayi
    /// ho, location off ho, ya geocoding fail ho -- har case mein null,
    /// UI khud "location unavailable" handle karti hai.
    private fun fetchAndCacheWeatherLocation(): String? {
        // Context.checkSelfPermission() seedha API 23+ ka core-platform
        // method hai -- koi extra androidx dependency add karne ki
        // zaroorat nahi.
        val hasFine = checkSelfPermission(
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        val hasCoarse = checkSelfPermission(
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED

        if (!hasFine && !hasCoarse) return null

        return try {
            val locationManager =
                getSystemService(Context.LOCATION_SERVICE) as? android.location.LocationManager
                    ?: return null

            // GPS_PROVIDER ko PEHLE try karte hain -- zyada precise fix
            // deta hai (kuch meter tak), NETWORK_PROVIDER sirf fallback hai
            // (cell tower/Wi-Fi based, 1-3km tak off ho sakta hai). GPS
            // sirf ACCESS_FINE_LOCATION granted hone par kaam karta hai --
            // agar sirf coarse mili hai to GPS_PROVIDER call apne aap
            // SecurityException dega aur neeche ka catch NETWORK_PROVIDER
            // par fallback kar dega.
            val providers = listOf(
                android.location.LocationManager.GPS_PROVIDER,
                android.location.LocationManager.NETWORK_PROVIDER
            )
            var location: android.location.Location? = null
            for (p in providers) {
                try {
                    if (locationManager.isProviderEnabled(p)) {
                        val last = locationManager.getLastKnownLocation(p)
                        if (last != null) {
                            location = last
                            break
                        }
                    }
                } catch (e: SecurityException) {
                    // Is provider ke liye permission nahi -- agla try karo.
                }
            }
            if (location == null) return null

            @Suppress("DEPRECATION")
            val geocoder = android.location.Geocoder(this, java.util.Locale.getDefault())
            @Suppress("DEPRECATION")
            val addresses = geocoder.getFromLocation(location.latitude, location.longitude, 1)
            val address = addresses?.firstOrNull() ?: return null

            val city = address.locality ?: address.subAdminArea ?: address.adminArea
            val country = address.countryName
            val label = listOfNotNull(city, country).joinToString(", ")
            if (label.isBlank()) return null

            val prefs = getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString("weather_location", label).apply()

            // Location mil gayi -- isi lat/lon se real current weather bhi
            // fetch karke cache kar dete hain (widget aur in-app preview
            // dono isi cache se padhte hain).
            fetchAndCacheCurrentWeather(location.latitude, location.longitude)

            val appWidgetManager = getSystemService(AppWidgetManager::class.java)
            val ids = appWidgetManager?.getAppWidgetIds(
                ComponentName(this, WeatherWidgetProvider::class.java)
            )
            if (ids != null && ids.isNotEmpty()) {
                val updateIntent = Intent(this, WeatherWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                sendBroadcast(updateIntent)
            }

            label
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}