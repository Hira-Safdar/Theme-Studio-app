package com.example.theme_studio

import android.content.Context
import android.widget.RemoteViews

/// Sab widgets (Battery, Clock, Weather, Calendar, Notes) ke liye ek hi
/// shared "style + mode" concept:
///   - style: Minimal / Gradient / Neon Glass (background look)
///   - mode: Dark / Light (background shade + matching text colors)
/// 3 styles x 2 modes = 6 total looks. Har provider apna style/mode
/// SharedPreferences se padhta hai aur [applyBackground] + [applyTextColor]
/// se sahi drawable/colors set karta hai, taake ye logic ek hi jagah rahe,
/// har provider mein duplicate na ho.
object WidgetStyleHelper {
    const val PREFS_NAME = "widget_styles"

    const val MODE_DARK = "dark"
    const val MODE_LIGHT = "light"

    /// [widgetType] e.g. "battery", "clock", "weather", "calendar", "notes".
    fun styleFor(context: Context, widgetType: String): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString("style_$widgetType", "minimal") ?: "minimal"
    }

    fun saveStyle(context: Context, widgetType: String, style: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString("style_$widgetType", style)
            .apply()
    }

    fun modeFor(context: Context, widgetType: String): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString("mode_$widgetType", MODE_DARK) ?: MODE_DARK
    }

    fun saveMode(context: Context, widgetType: String, mode: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString("mode_$widgetType", mode)
            .apply()
    }

    /// [rootViewId] us widget layout ke root container ka id hona chahiye
    /// (e.g. R.id.widget_root) -- RemoteViews.setInt(..., "setBackgroundResource", ...)
    /// runtime par background drawable badalta hai, bina alag layout XML
    /// banaye har style/mode combo ke liye.
    fun applyBackground(views: RemoteViews, rootViewId: Int, style: String, mode: String) {
        val isLight = mode == MODE_LIGHT
        val bgRes = when (style) {
            "gradient" -> if (isLight) R.drawable.widget_bg_gradient_light else R.drawable.widget_bg_gradient
            "neon" -> if (isLight) R.drawable.widget_bg_neon_light else R.drawable.widget_bg_neon
            else -> if (isLight) R.drawable.widget_bg_minimal_light else R.drawable.widget_bg_minimal
        }
        views.setInt(rootViewId, "setBackgroundResource", bgRes)
    }

    /// Bold/headline values (temp, time, percentage, date number) -- dark
    /// mode mein bright accent cyan, light mode mein readability ke liye
    /// deep teal (same accent family, just dark enough for light backgrounds).
    fun primaryTextColor(mode: String): Int {
        return if (mode == MODE_LIGHT) 0xFF007A72.toInt() else 0xFF00FFF0.toInt()
    }

    /// Body/secondary text (condition, location, day label, note body) --
    /// dark mode mein white, light mode mein near-black.
    fun secondaryTextColor(mode: String): Int {
        return if (mode == MODE_LIGHT) 0xFF1A1A1A.toInt() else 0xFFFFFFFF.toInt()
    }

    /// Convenience: applies primary color to [primaryIds] and secondary
    /// color to [secondaryIds] in one call, so providers don't repeat the
    /// mode branch themselves.
    fun applyTextColors(
        views: RemoteViews,
        mode: String,
        primaryIds: List<Int> = emptyList(),
        secondaryIds: List<Int> = emptyList()
    ) {
        val primary = primaryTextColor(mode)
        val secondary = secondaryTextColor(mode)
        primaryIds.forEach { views.setTextColor(it, primary) }
        secondaryIds.forEach { views.setTextColor(it, secondary) }
    }
}