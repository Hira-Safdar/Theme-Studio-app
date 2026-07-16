package com.example.theme_studio

import android.app.WallpaperManager
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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
