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
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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

                // Real app icon leke automatically ek consistent shape +
                // duotone color treatment apply karta hai -- "Auto" tab ke
                // liye, jahan har installed app ka khud-ba-khud themed icon
                // ban jaata hai, koi manual PNG design kiye bagair.
                "getThemedAppIcon" -> {
                    val packageName = call.argument<String>("packageName")
                    val shape = call.argument<String>("shape") ?: "circle"
                    val accentColor = call.argument<String>("accentColor")
                    result.success(getThemedAppIconBytes(packageName, shape, accentColor))
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
                    result.success(requestPinWidget(widgetType))
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
        accentColorHex: String?
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
            val themed = applyDuotoneTheme(source, shape, accent)
            val stream = ByteArrayOutputStream()
            themed.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            // Sabse aam wajah: app installed nahi (PackageManager.NameNotFoundException)
            e.printStackTrace()
            null
        }
    }

    /// [source] = asal app icon. Steps: (1) canvas ko chosen shape (circle
    /// ya squircle) tak clip karo, (2) accent color ka darker shade se
    /// backplate bharo, (3) source icon ko grayscale karke accent-tint karo
    /// (duotone) aur center mein thoda inset karke draw karo.
    private fun applyDuotoneTheme(source: Bitmap, shape: String, accent: Int): Bitmap {
        val size = 192 // fixed output size -- sab themed icons same resolution
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        val path = Path()
        if (shape == "circle") {
            path.addCircle(size / 2f, size / 2f, size / 2f, Path.Direction.CW)
        } else {
            // squircle -- generous corner radius, iOS-style rounded square
            val r = size * 0.32f
            path.addRoundRect(0f, 0f, size.toFloat(), size.toFloat(), r, r, Path.Direction.CW)
        }
        canvas.clipPath(path) // isse aage jo bhi draw hoga, shape ke bahar nahi jayega

        // 1) Backplate -- accent ka darker shade, poori shape bharta hai.
        val platePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = darkenColor(accent, 0.35f) }
        canvas.drawRect(0f, 0f, size.toFloat(), size.toFloat(), platePaint)

        // 2) Grayscale -> accent-tint (duotone) color filter.
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

        // Icon ko backplate se thoda chota (center mein inset karke) draw
        // karo, taake plate ka border sab icons mein consistent dikhe.
        val inset = size * 0.16f
        val iconRect = RectF(inset, inset, size - inset, size - inset)
        canvas.drawBitmap(source, null, iconRect, iconPaint)

        return output
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
    private fun requestPinWidget(widgetType: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val appWidgetManager = getSystemService(AppWidgetManager::class.java) ?: return false

        // widgetType ke hisaab se sahi Provider class select karo.
        val provider = when (widgetType) {
            "battery" -> ComponentName(this, BatteryWidgetProvider::class.java)
            "clock" -> ComponentName(this, ClockWidgetProvider::class.java)
            else -> return false
        }

        return if (appWidgetManager.isRequestPinAppWidgetSupported) {
            appWidgetManager.requestPinAppWidget(provider, null, null)
            true
        } else {
            false
        }
    }
}