package com.example.theme_studio

import android.app.PendingIntent
import android.app.WallpaperManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
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
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
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

        /// WeatherWidgetProvider (tap par) isi extra ke saath MainActivity
        /// ko launch karta hai -- ab weather widget tap karne par koi bhi
        /// random installed weather app nahi khulta, seedha humari apni
        /// "choose location" screen khulti hai, taake widget mein wahi
        /// location/temp dikhe jo user ne khud app ke andar select ki ho.
        const val EXTRA_OPEN_WEATHER_LOCATION = "open_weather_location"

        /// requestPinShortcut() ka confirmation callback broadcast action --
        /// har request apna khud ka unique suffix (requestId) laga leta hai
        /// (dekho createCustomIconShortcut) taake "Apply All" me ek ke baad
        /// ek chalne wale multiple requests ka PendingIntent/receiver aapas
        /// mein collide na karein.
        private const val PIN_SHORTCUT_ACTION_PREFIX =
            "com.example.theme_studio.PIN_SHORTCUT_RESULT_"

        /// Itni der wait karte hain ke user Android ka "Add to Home Screen"
        /// dialog confirm/dismiss kare -- agar is se zyada time guzar jaye
        /// (user ne dialog ko yun hi chhod diya, ya kisi wajah se system
        /// broadcast kabhi nahi aata) to hum result ko hamesha ke liye latka
        /// hua nahi chhod sakte, isliye ek safe "false" fallback bhej dete hain.
        private const val PIN_SHORTCUT_TIMEOUT_MS = 15000L
    }

    /// Har naye pin-shortcut request ko apna unique requestId chahiye.
    private var shortcutRequestSeq = 0

    /// Cold start (app band thi, widget tap se pehli dafa khuli) -- Flutter
    /// side ko seedha "/notes_editor" route par le jaate hain, splash
    /// screen ke bagair (widget tap ka matlab hi hai seedha note edit karna).
    override fun getInitialRoute(): String? {
        if (intent?.getBooleanExtra(EXTRA_OPEN_NOTES_EDITOR, false) == true) {
            return "/notes_editor"
        }
        if (intent?.getBooleanExtra(EXTRA_OPEN_WEATHER_LOCATION, false) == true) {
            return "/weather_location"
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
        if (intent.getBooleanExtra(EXTRA_OPEN_WEATHER_LOCATION, false)) {
            methodChannel?.invokeMethod("openWeatherLocation", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {

                // ---------------- WALLPAPER ----------------
                // Bitmap decode + crop + WallpaperManager.setBitmap sab
                // heavy kaam hai -- main thread par karne se low-RAM devices
                // (Infinix etc.) pe OOM/ANR hota hai aur app restart ho
                // jaata hai. Background thread pe move karte hain (waise hi
                // jaise getWeatherLocation).
                "setWallpaper" -> {
                    val path = call.argument<String>("path")
                    val target = call.argument<String>("target") ?: "both"
                    Thread {
                        val ok = setWallpaperFromPath(path, target)
                        runOnUiThread { result.success(ok) }
                    }.start()
                }

                // ---------------- ICON SHORTCUT ----------------
                "createShortcut" -> {
                    val packageName = call.argument<String>("packageName")
                    val appLabel = call.argument<String>("appLabel")
                    val iconPath = call.argument<String>("iconPath")
                    createCustomIconShortcut(packageName, appLabel, iconPath, result)
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
                "requestPinExternalWidget" -> {
                    val widgetType = call.argument<String>("widgetType") ?: "notes"
                    result.success(requestPinExternalWidget(widgetType))
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
                //
                // IMPORTANT: fetchAndCacheWeatherLocation() ke andar Geocoder
                // (blocking) aur ek real HTTP call hai -- MethodChannel
                // handlers by default MAIN/UI thread par chalte hain, isliye
                // seedha yahan call karna NetworkOnMainThreadException deta
                // tha aur (jab tak exception/timeout resolve na ho) UI ko
                // freeze kar deta tha. Frozen UI ke dauraan agar user "Pin
                // Weather Widget" tap kare to wo tap process hi nahi hota --
                // isi wajah se widget "add nahi ho raha" jaisa mehsoos hota
                // tha. Fix: poora kaam background Thread par, result sirf
                // wapas UI thread par (runOnUiThread) deliver karte hain --
                // MethodChannel.Result async completion support karta hai,
                // isliye ye bilkul valid/supported pattern hai.
                "getWeatherLocation" -> {
                    Thread {
                        val location = fetchAndCacheWeatherLocation()
                        runOnUiThread { result.success(location) }
                    }.start()
                }
                "getWeatherSnapshot" -> {
                    val prefs = getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
                    val hourlyJson = prefs.getString("weather_hourly_json", null)
                    val hourlyList: List<Map<String, String>> = if (hourlyJson != null) {
                        try {
                            val arr = org.json.JSONArray(hourlyJson)
                            (0 until arr.length()).map { i ->
                                val obj = arr.getJSONObject(i)
                                mapOf(
                                    "time" to obj.optString("time", ""),
                                    "temp" to obj.optString("temp", "--°"),
                                    "condition" to obj.optString("condition", ""),
                                )
                            }
                        } catch (e: Exception) {
                            emptyList()
                        }
                    } else {
                        emptyList()
                    }

                    result.success(
                        mapOf(
                            "temperature" to prefs.getString("weather_temp", null),
                            "condition" to prefs.getString("weather_condition", null),
                            "feelsLike" to prefs.getString("weather_feels_like", null),
                            "humidity" to prefs.getString("weather_humidity", null),
                            "wind" to prefs.getString("weather_wind", null),
                            "hourly" to hourlyList,
                        )
                    )
                }

                /// GPS/permission ki zaroorat nahi -- sirf jo location user
                /// ne pehle khud choose ki thi (setWeatherLocation) wo cached
                /// label seedha SharedPreferences se wapas kar dete hain.
                /// Isse widgets screen khulte hi koi naya (surprising) GPS
                /// fetch nahi hota -- sirf wahi dikhta hai jo user ne chuna.
                "getSavedWeatherLocation" -> {
                    val prefs = getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
                    result.success(prefs.getString("weather_location", null))
                }

                /// Open-Meteo Geocoding API (free, no key) se city-name
                /// search -- user ko match karne wali jaghain (city, region,
                /// country + lat/lon) dikhane ke liye, taake wo apni asal
                /// location khud pick kar sake. Network call hai isliye
                /// background Thread par (UI freeze na ho).
                "searchWeatherLocations" -> {
                    val query = call.argument<String>("query") ?: ""
                    Thread {
                        val matches = searchWeatherLocations(query)
                        runOnUiThread { result.success(matches) }
                    }.start()
                }

                /// User ne search results mein se ek jagah choose kar li --
                /// isi lat/lon ke liye real weather fetch/cache karte hain
                /// aur label ko "manually chosen" location ke tor par save
                /// karte hain. Yahi cache Weather widget aur in-app preview
                /// dono padhte hain, isliye widget bhi turant sync ho jata hai.
                "setWeatherLocation" -> {
                    val lat = call.argument<Double>("lat")
                    val lon = call.argument<Double>("lon")
                    val label = call.argument<String>("label")
                    if (lat == null || lon == null || label.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        Thread {
                            val ok = setManualWeatherLocation(lat, lon, label)
                            runOnUiThread { result.success(ok) }
                        }.start()
                    }
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
            val bitmap = BitmapFactory.decodeFile(path) ?: return false
            val wallpaperManager = WallpaperManager.getInstance(applicationContext)

            // Screen dimensions le ke bitmap ko center-crop karke fill karo
            val dm = resources.displayMetrics
            val screenW = dm.widthPixels
            val screenH = dm.heightPixels
            val cropped = centerCropBitmap(bitmap, screenW, screenH)

            when (target) {
                "home" -> wallpaperManager.setBitmap(cropped, null, true, WallpaperManager.FLAG_SYSTEM)
                "lock" -> wallpaperManager.setBitmap(cropped, null, true, WallpaperManager.FLAG_LOCK)
                else -> {
                    wallpaperManager.setBitmap(
                        cropped, null, true,
                        WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                    )
                }
            }
            if (cropped !== bitmap) bitmap.recycle()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // Bitmap ko screen dimensions ke liye center-crop karta hai --
    // source ka center portion screen aspect ratio mein fit hota hai,
    // baaki edges crop ho jaati hain. Result hamesha screen-size ka hota hai.
    private fun centerCropBitmap(source: Bitmap, targetW: Int, targetH: Int): Bitmap {
        if (targetW <= 0 || targetH <= 0) return source
        val srcW = source.width
        val srcH = source.height
        val targetRatio = targetW.toFloat() / targetH.toFloat()
        val srcRatio = srcW.toFloat() / srcH.toFloat()

        val cropW: Int
        val cropH: Int
        var offsetX = 0
        var offsetY = 0

        if (srcRatio > targetRatio) {
            // Source zyada wide hai -- height ko screen ke barabar, width center se crop
            cropH = srcH
            cropW = (srcH * targetRatio).toInt().coerceAtMost(srcW)
            offsetX = (srcW - cropW) / 2
        } else {
            // Source zyada lamba hai -- width ko screen ke barabar, height center se crop
            cropW = srcW
            cropH = (srcW / targetRatio).toInt().coerceAtMost(srcH)
            offsetY = (srcH - cropH) / 2
        }

        val cropped = Bitmap.createBitmap(source, offsetX, offsetY, cropW, cropH)
        // Agar cropped size already screen size hai to scale bhi karo
        return Bitmap.createScaledBitmap(cropped, targetW, targetH, true).also {
            if (it !== cropped) cropped.recycle()
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
    //
    // [isSystemApp] bhi bhejte hain (ApplicationInfo.FLAG_SYSTEM se) --
    // emulators par khaas taur par bohat saari dummy/test apps installed
    // hoti hain jinke naam/keywords real system apps se milte-julte hote
    // hain (e.g. do "Browser" apps), jo keyword-based icon matching ko
    // confuse kar sakti hain. Dart side chahe to sirf system apps tak
    // matching limit kar sakta hai.
    private fun getInstalledLaunchableApps(): List<Map<String, Any>> {
        val mainIntent = Intent(Intent.ACTION_MAIN, null)
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)

        val resolveInfos = packageManager.queryIntentActivities(mainIntent, 0)
        val ownPackage = packageName // apni khud ki app list me na dikhe

        val seen = LinkedHashSet<String>()
        val apps = mutableListOf<Map<String, Any>>()

        for (info in resolveInfos) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == ownPackage) continue
            if (!seen.add(pkg)) continue // kai apps ke 2 launcher activities ho sakti hain

            val label = try {
                info.loadLabel(packageManager).toString()
            } catch (e: Exception) {
                pkg
            }

            val appInfo = info.activityInfo?.applicationInfo
            val isSystemApp = appInfo != null &&
                (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            apps.add(mapOf("packageName" to pkg, "label" to label, "isSystemApp" to isSystemApp))
        }

        // Label ke hisaab se alphabetically sort -- predictable UI order.
        return apps.sortedBy { (it["label"] as? String)?.lowercase() ?: "" }
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
    /// Pehle ye function requestPinShortcut() call karke turant "true"
    /// bhej deta tha -- jabke wo sirf itna confirm karta hai ke system ne
    /// "Add to Home Screen" dialog dikhana accept kar liya, ye nahi ke user
    /// ne wakai confirm kiya. Isi wajah se "Apply All" (icon_changer_screen
    /// ki _applyAllSelected, jo sequential await karti hai) turant agla
    /// request bhej deta tha, aur dialogs stack ho jaate the -- sirf pehla
    /// (ya kuch) icon hi asal mein add hota tha.
    ///
    /// Fix: requestPinShortcut ko ek PendingIntent callback dete hain. Jab
    /// tak launcher us callback ko fire nahi karta (matlab user ne dialog
    /// confirm kar diya), Dart side ka result pending rehta hai -- isliye
    /// "Apply All" ka loop khud-ba-khud ek-ek dialog ke liye rukta hai,
    /// aur sab icons ke liye chal sakta hai. Agar user dialog ko ignore
    /// ya dismiss kar de, ek timeout fallback hai taake result hamesha ke
    /// liye latka na rahe.
    private fun createCustomIconShortcut(
        packageName: String?,
        appLabel: String?,
        iconPath: String?,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(false)
            return
        }
        if (packageName == null || appLabel == null || iconPath == null) {
            result.success(false)
            return
        }

        val shortcutManager = getSystemService(ShortcutManager::class.java)
        if (shortcutManager == null || !shortcutManager.isRequestPinShortcutSupported) {
            result.success(false)
            return
        }

        try {
            Log.d("ThemeStudio", "createCustomIconShortcut: Starting for packageName=$packageName, appLabel=$appLabel, iconPath=$iconPath")

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent == null) {
                Log.e("ThemeStudio", "createCustomIconShortcut: launchIntent is null for $packageName")
                result.success(false)
                return
            }
            launchIntent.action = Intent.ACTION_MAIN

            val iconFile = java.io.File(iconPath)
            if (!iconFile.exists()) {
                Log.e("ThemeStudio", "createCustomIconShortcut: Icon file does not exist: $iconPath")
                result.success(false)
                return
            }
            Log.d("ThemeStudio", "createCustomIconShortcut: Icon file exists, size=${iconFile.length()} bytes")

            // Bitmap decode heavy hai -- background thread pe karte hain
            // taake main thread freeze na ho aur low-RAM devices pe OOM na ho.
            Thread {
                val bitmap = BitmapFactory.decodeFile(iconPath)
                if (bitmap == null) {
                    Log.e("ThemeStudio", "createCustomIconShortcut: BitmapFactory.decodeFile returned null for $iconPath")
                    runOnUiThread { result.success(false) }
                    return@Thread
                }
                Log.d("ThemeStudio", "createCustomIconShortcut: Bitmap decoded successfully, ${bitmap.width}x${bitmap.height}")
                val customIcon = Icon.createWithBitmap(bitmap)

                runOnUiThread {
                    try {
                        // Unique shortcut ID with icon path hash - ensures each icon change is treated as new pin
                        val iconHash = iconPath.hashCode().toString(16).replace("-", "n")
                        val shortcutId = "theme_studio_${packageName}_$iconHash"
                        Log.d("ThemeStudio", "createCustomIconShortcut: shortcutId=$shortcutId")
                        val shortcut = ShortcutInfo.Builder(this, shortcutId)
                            .setShortLabel(appLabel)
                            .setLongLabel(appLabel)
                            .setIcon(customIcon)
                            .setIntent(launchIntent)
                            .build()

                        // Check if this exact shortcut (same icon) is already pinned
                        val pinnedShortcuts = shortcutManager.pinnedShortcuts
                        val alreadyPinned = pinnedShortcuts.any { it.id == shortcutId }
                        Log.d("ThemeStudio", "createCustomIconShortcut: Total pinned=${pinnedShortcuts.size}, alreadyPinned=$alreadyPinned")
                        if (alreadyPinned) {
                            Log.d("ThemeStudio", "createCustomIconShortcut: $packageName shortcut already pinned with same icon, updating in place")
                            shortcutManager.updateShortcuts(listOf(shortcut))
                            result.success(true)
                            return@runOnUiThread
                        }

                        // Har request ka apna unique action + request code -- taake
                        // "Apply All" ke doosre/tisre shortcut ka receiver ya
                        // PendingIntent pehle wale se collide na kare.
                        val requestId = shortcutRequestSeq++
                        val action = "$PIN_SHORTCUT_ACTION_PREFIX$requestId"

                        var settled = false
                        val handler = Handler(Looper.getMainLooper())
                        var receiverRef: BroadcastReceiver? = null
                        var timeoutRunnable: Runnable? = null

                        fun finish(success: Boolean) {
                            if (settled) return
                            settled = true
                            timeoutRunnable?.let { handler.removeCallbacks(it) }
                            receiverRef?.let {
                                try {
                                    unregisterReceiver(it)
                                } catch (e: Exception) {
                                    // pehle hi unregistered ho chuka (timeout/receiver
                                    // dono ka race) -- ignore, koi masla nahi.
                                }
                            }
                            result.success(success)
                        }

                        val receiver = object : BroadcastReceiver() {
                            override fun onReceive(context: Context, intent: Intent) {
                                Log.d("ThemeStudio", "createCustomIconShortcut: Pin confirmation received for $packageName (shortcutId=$shortcutId)")
                                finish(true)
                            }
                        }
                        receiverRef = receiver

                        val filter = IntentFilter(action)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                        } else {
                            @Suppress("UnspecifiedRegisterReceiverFlag")
                            registerReceiver(receiver, filter)
                        }

                        timeoutRunnable = Runnable {
                            Log.w("ThemeStudio", "createCustomIconShortcut: Timeout waiting for pin confirmation for $packageName")
                            finish(false)
                        }
                        handler.postDelayed(timeoutRunnable, PIN_SHORTCUT_TIMEOUT_MS)

                        val callbackIntent = Intent(action).setPackage(applicationContext.packageName)
                        val pendingIntent = PendingIntent.getBroadcast(
                            this,
                            requestId,
                            callbackIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        Log.d("ThemeStudio", "createCustomIconShortcut: Calling requestPinShortcut for $packageName with shortcutId=$shortcutId")
                        shortcutManager.requestPinShortcut(shortcut, pendingIntent.intentSender)
                        Log.d("ThemeStudio", "createCustomIconShortcut: requestPinShortcut returned for $packageName")
                    } catch (e: Exception) {
                        Log.e("ThemeStudio", "createCustomIconShortcut: Exception in UI thread: ${e.message}", e)
                        e.printStackTrace()
                        result.success(false)
                    }
                }
            }.start()
        } catch (e: Exception) {
            Log.e("ThemeStudio", "createCustomIconShortcut: Exception: ${e.message}", e)
            e.printStackTrace()
            result.success(false)
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

    /// Notes/Weather ke liye known package names -- Notes ke liye
    /// WidgetClickActions.knownNotesPackages jaisi hi list (yahan alag se
    /// rakhi hai kyunke ye object function hai, class-level property
    /// nahi -- lekin dono lists ko sync mein rakhna, agar ek update ho to
    /// dusri bhi update karo).
    private val knownNotesPackages = listOf(
        "com.samsung.android.app.notes",
        "com.google.android.keep",
        "com.miui.notes",
        "com.coloros.note",
        "com.nearme.note",
        "com.oneplus.note",
        "com.vivo.notes",
        "com.huawei.notepad",
    )

    /// NOTE: exact package names OEM/region ke hisaab se badal sakte hain
    /// -- ye best-effort curated list hai. Agar test devices (Samsung
    /// SM-G985F, Infinix X688B) par match na ho, `adb shell pm list
    /// packages | grep -i weather` chala kar sahi package name confirm
    /// karke yahan add/replace kar dena.
    private val knownWeatherPackages = listOf(
        "com.miui.weather2",       // Xiaomi/MIUI Weather
        "com.samsung.android.app.weather", // Samsung Weather (varies by version)
        "com.coloros.weather.service",     // Oppo/Realme (ColorOS) Weather
        "com.vivo.weather",        // Vivo Weather
        "com.oneplus.weather",     // OnePlus Weather
        "com.htc.weather",         // HTC Weather
        "com.google.android.apps.weather", // Google Weather (kuch devices par)
    )

    /// [packageNames] mein se pehli app jo koi bhi home-screen widget
    /// provide karti hai, uska pehla `AppWidgetProviderInfo` deta hai.
    /// `getInstalledProvidersForPackage` API 26+ hai -- isse humein us
    /// app ke "widgets" ki list milti hai bilkul waisi jaisi Android ka
    /// apna widget-picker dikhata hai.
    private fun findExternalWidgetProvider(packageNames: List<String>): AppWidgetProviderInfo? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val appWidgetManager = getSystemService(AppWidgetManager::class.java) ?: return null
        for (pkg in packageNames) {
            try {
                val providers = appWidgetManager.getInstalledProvidersForPackage(pkg, null)
                if (providers.isNotEmpty()) return providers.first()
            } catch (e: Exception) {
                // Package installed nahi, ya widget provider query fail --
                // agli candidate package try karo.
            }
        }
        return null
    }

    /// Fallback jab curated package-name list match na kare (jaise Infinix
    /// aur kai dusre Transsion/lesser-known OEM builds par, jinke Notes/
    /// Weather apps ka package name humari guessed list mein nahi hota).
    /// Curated list ki jagah ab poore device ke SAB installed widget
    /// providers scan karte hain, aur jis provider/app ka LABEL [keywords]
    /// se match kare wahi return karte hain -- app label (jo screen par
    /// dikhta hai) OEM se OEM tak package-name jitna vary nahi karta,
    /// isliye ye zyada reliable hai.
    // Package prefixes that should never be treated as a Notes/Weather
    // match even if a label happens to contain a keyword substring — this
    // is what let "memo" wrongly match Google Photos' "Memories" widget
    // (memo⊂memories). Belt-and-suspenders alongside the whole-word fix
    // below, in case a future keyword has the same kind of collision.
    private val externalWidgetDenylist = listOf(
        "com.google.android.apps.photos",
        "com.google.android.gallery3d",
        "com.google.android.youtube",
        "com.google.android.gm",
        "com.google.android.apps.maps",
        "com.google.android.music",
        "com.google.android.videos",
    )

    /// Raw `.contains()` matches ANY substring, anywhere in the word —
    /// which is how "memo" (a Notes keyword) wrongly matched "Memories"
    /// (Google Photos' widget name): memo⊂memories. This instead requires
    /// a whole-word match, allowing short suffixes (≤2 chars, e.g. the
    /// "s" in "weather"→"weathers") so legitimate plural app names still
    /// match, while still rejecting "memo"→"memories" (a 4-char suffix).
    private fun labelMatchesKeyword(text: String, keywords: List<String>): Boolean {
        val words = text.lowercase().split(Regex("[^a-z0-9]+")).filter { it.isNotEmpty() }
        return keywords.any { kw ->
            words.any { word -> word == kw || (word.startsWith(kw) && word.length - kw.length <= 2) }
        }
    }

    private fun findExternalWidgetProviderByKeyword(keywords: List<String>): AppWidgetProviderInfo? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val appWidgetManager = getSystemService(AppWidgetManager::class.java) ?: return null
        val allProviders = try {
            appWidgetManager.installedProviders
        } catch (e: Exception) {
            return null
        }

        for (provider in allProviders) {
            val pkg = provider.provider.packageName
            if (pkg == packageName) continue // apni khud ki app (Battery/Clock/etc providers) skip
            if (externalWidgetDenylist.any { pkg.startsWith(it) }) continue

            val providerLabel = try {
                provider.loadLabel(packageManager)
            } catch (e: Exception) {
                ""
            }
            val appLabel = try {
                packageManager.getApplicationLabel(
                    packageManager.getApplicationInfo(pkg, 0)
                ).toString()
            } catch (e: Exception) {
                ""
            }

            val matches = labelMatchesKeyword(providerLabel, keywords) ||
                labelMatchesKeyword(appLabel, keywords) ||
                labelMatchesKeyword(pkg.substringAfterLast('.'), keywords)
            if (matches) {
                Log.d("ThemeStudio", "findExternalWidgetProviderByKeyword: matched pkg=$pkg providerLabel='$providerLabel' appLabel='$appLabel'")
                return provider
            }
        }
        return null
    }

    /// Theme Studio ka apna custom widget pin karne ke bajaye, device par
    /// jo bhi real Notes/Weather app installed hai, USI ka asal widget
    /// Home Screen par pin karta hai. Agar koi bhi candidate app na mile,
    /// ya us app ka koi widget hi na ho, false return karta hai -- Dart
    /// side isko dekh kar hamare apne custom widget par fallback karta hai
    /// (taake user khaali-haath na rahe).
    private fun requestPinExternalWidget(widgetType: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.d("ThemeStudio", "requestPinExternalWidget($widgetType): SDK < 26, unsupported")
            return false
        }
        val candidates = when (widgetType) {
            "notes" -> knownNotesPackages
            "weather" -> knownWeatherPackages
            else -> return false
        }
        val keywords = when (widgetType) {
            "notes" -> listOf("note", "keep", "memo")
            "weather" -> listOf("weather", "climate")
            else -> return false
        }

        // Pehle fast-path: curated package-name list. Match na ho (jaise
        // Infinix par) to poore device ke widgets keyword se scan karo.
        val provider = findExternalWidgetProvider(candidates)
            ?: findExternalWidgetProviderByKeyword(keywords)
        if (provider == null) {
            Log.d("ThemeStudio", "requestPinExternalWidget($widgetType): no candidate provider found on device")
            return false
        }
        Log.d("ThemeStudio", "requestPinExternalWidget($widgetType): found provider ${provider.provider}")

        val appWidgetManager = getSystemService(AppWidgetManager::class.java) ?: return false

        return if (appWidgetManager.isRequestPinAppWidgetSupported) {
            try {
                appWidgetManager.requestPinAppWidget(provider.provider, null, null)
                Log.d("ThemeStudio", "requestPinExternalWidget($widgetType): requestPinAppWidget call succeeded")
                true
            } catch (e: Exception) {
                // Some OEM launchers (Infinix/XOS and others) reject pin
                // requests for widgets that belong to a DIFFERENT app —
                // throwing here instead of just returning false, which
                // used to prevent the clean fallback to our own widget.
                Log.d("ThemeStudio", "requestPinExternalWidget($widgetType): threw ${e::class.simpleName}: ${e.message}")
                false
            }
        } else {
            Log.d("ThemeStudio", "requestPinExternalWidget($widgetType): isRequestPinAppWidgetSupported = false")
            false
        }
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
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.d("ThemeStudio", "requestPinWidget($widgetType): SDK < 26, unsupported")
            return false
        }
        val appWidgetManager = getSystemService(AppWidgetManager::class.java) ?: return false
        val provider = providerFor(widgetType) ?: return false

        // Style + mode ko PEHLE save kar dete hain -- taake pinning ke baad
        // jab provider ka onUpdate pehli dafa chale, sahi values already
        // SharedPreferences mein maujood hon.
        WidgetStyleHelper.saveStyle(this, widgetType, style)
        WidgetStyleHelper.saveMode(this, widgetType, mode)

        Log.d("ThemeStudio", "requestPinWidget($widgetType): isRequestPinAppWidgetSupported = ${appWidgetManager.isRequestPinAppWidgetSupported}")

        return if (appWidgetManager.isRequestPinAppWidgetSupported) {
            try {
                appWidgetManager.requestPinAppWidget(provider, null, null)
                Log.d("ThemeStudio", "requestPinWidget($widgetType): requestPinAppWidget call succeeded")
                true
            } catch (e: Exception) {
                Log.d("ThemeStudio", "requestPinWidget($widgetType): threw ${e::class.simpleName}: ${e.message}")
                false
            }
        } else {
            Log.d("ThemeStudio", "requestPinWidget($widgetType): isRequestPinAppWidgetSupported = false")
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
                "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon" +
                    "&current_weather=true" +
                    "&hourly=temperature_2m,relative_humidity_2m,apparent_temperature,weathercode" +
                    "&timezone=auto&forecast_days=2"
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

            val json = org.json.JSONObject(body)
            val current = json.getJSONObject("current_weather")
            val tempC = current.getDouble("temperature")
            val code = current.getInt("weathercode")
            val windKmh = current.optDouble("windspeed", Double.NaN)
            val currentTime = current.optString("time", "")

            // "current_weather" khud feels-like/humidity nahi deta -- wo
            // sirf "hourly" array mein aate hain. Isliye current_weather
            // ke exact "time" se match karke hourly array mein wahi index
            // dhoondte hain, taake feels-like/humidity bhi USI ghante ke
            // hon jis ghante ka temperature/condition dikha rahe hain.
            val hourly = json.optJSONObject("hourly")
            var feelsLikeC: Double? = null
            var humidityPct: Int? = null
            val hourlyJsonArray = org.json.JSONArray()

            if (hourly != null) {
                val times = hourly.optJSONArray("time")
                val temps = hourly.optJSONArray("temperature_2m")
                val humidities = hourly.optJSONArray("relative_humidity_2m")
                val apparents = hourly.optJSONArray("apparent_temperature")
                val codes = hourly.optJSONArray("weathercode")

                var currentIdx = 0
                if (times != null && currentTime.isNotBlank()) {
                    for (i in 0 until times.length()) {
                        if (times.optString(i) == currentTime) {
                            currentIdx = i
                            break
                        }
                    }
                }

                if (apparents != null && currentIdx < apparents.length()) {
                    feelsLikeC = apparents.optDouble(currentIdx)
                }
                if (humidities != null && currentIdx < humidities.length()) {
                    humidityPct = humidities.optInt(currentIdx, -1).takeIf { it >= 0 }
                }

                // Agle 8 ghanton ka hourly forecast (abhi wale ghante se shuru).
                if (times != null) {
                    val endIdx = minOf(currentIdx + 8, times.length())
                    for (i in currentIdx until endIdx) {
                        val temp = temps?.optDouble(i)
                        val entry = org.json.JSONObject()
                        entry.put("time", times.optString(i))
                        entry.put(
                            "temp",
                            if (temp != null && !temp.isNaN()) "${Math.round(temp)}°" else "--°"
                        )
                        entry.put("condition", weatherCodeToLabel(codes?.optInt(i, -1) ?: -1))
                        hourlyJsonArray.put(entry)
                    }
                }
            }

            val prefs = getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
            val editor = prefs.edit()
                .putString("weather_temp", "${Math.round(tempC)}°")
                .putString("weather_condition", weatherCodeToLabel(code))
                .putString("weather_hourly_json", hourlyJsonArray.toString())

            if (feelsLikeC != null && !feelsLikeC.isNaN()) {
                editor.putString("weather_feels_like", "${Math.round(feelsLikeC)}°")
            } else {
                editor.remove("weather_feels_like")
            }
            if (humidityPct != null) {
                editor.putString("weather_humidity", "$humidityPct%")
            } else {
                editor.remove("weather_humidity")
            }
            if (!windKmh.isNaN()) {
                editor.putString("weather_wind", "${Math.round(windKmh)} km/h")
            } else {
                editor.remove("weather_wind")
            }
            editor.apply()
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

    /// Open-Meteo Geocoding API se city-name query karta hai -- har result
    /// mein "name" (city), "admin1" (state/region, ho sakta hai na ho) aur
    /// "country" milte hain, saath lat/lon bhi taake seedha weather fetch
    /// ho sake. Query khaali/blank ho ya kam se kam 2 characters na hon to
    /// khaali list -- bekar ki API calls se bachne ke liye.
    private fun searchWeatherLocations(query: String): List<Map<String, Any?>> {
        val trimmed = query.trim()
        if (trimmed.length < 2) return emptyList()

        return try {
            val encoded = java.net.URLEncoder.encode(trimmed, "UTF-8")
            val url = java.net.URL(
                "https://geocoding-api.open-meteo.com/v1/search?name=$encoded&count=8&language=en&format=json"
            )
            val connection = url.openConnection() as java.net.HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 8000
            connection.readTimeout = 8000

            if (connection.responseCode != 200) {
                connection.disconnect()
                return emptyList()
            }
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            connection.disconnect()

            val results = org.json.JSONObject(body).optJSONArray("results") ?: return emptyList()
            (0 until results.length()).mapNotNull { i ->
                val item = results.optJSONObject(i) ?: return@mapNotNull null
                val name = item.optString("name", "")
                if (name.isBlank()) return@mapNotNull null
                mapOf(
                    "name" to name,
                    "admin1" to item.optString("admin1", "").ifBlank { null },
                    "country" to item.optString("country", "").ifBlank { null },
                    "lat" to item.optDouble("latitude"),
                    "lon" to item.optDouble("longitude"),
                )
            }
        } catch (e: Exception) {
            // Network na ho ya API down ho -- khaali list, UI "no results"
            // jaisa dikha de.
            e.printStackTrace()
            emptyList()
        }
    }

    /// User ke manually chuni hui location ke liye real weather fetch/cache
    /// karta hai aur pinned Weather widgets ko refresh karta hai -- GPS
    /// wale [fetchAndCacheWeatherLocation] jaisa hi last step, bas location
    /// khud Geocoder se nahi, user ke search-selection se aati hai.
    private fun setManualWeatherLocation(lat: Double, lon: Double, label: String): Boolean {
        return try {
            val prefs = getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString("weather_location", label).apply()
            fetchAndCacheCurrentWeather(lat, lon)
            refreshPinnedWeatherWidgets()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /// Sab pinned Weather widget instances ko turant re-draw karne ke liye
    /// broadcast bhejta hai -- fetchAndCacheWeatherLocation (GPS path) aur
    /// setManualWeatherLocation (manual-pick path) dono isi ek jagah se
    /// widget refresh karte hain, taake dono jagah code duplicate na ho.
    private fun refreshPinnedWeatherWidgets() {
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
            refreshPinnedWeatherWidgets()

            label
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}