package com.example.theme_studio

import android.content.Context
import android.widget.RemoteViews

/// Sab widgets (Battery, Clock, Weather, Calendar, Notes) ke liye ek hi
/// shared "style" concept -- Minimal / Gradient / Neon Glass. Har provider
/// apna style SharedPreferences se padhta hai aur [applyBackground] se
/// sahi drawable set karta hai, taake style-switching logic ek hi jagah
/// rahe, har provider mein duplicate na ho.
object WidgetStyleHelper {
    const val PREFS_NAME = "widget_styles"

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

    /// [rootViewId] us widget layout ke root container ka id hona chahiye
    /// (e.g. R.id.widget_root) -- RemoteViews.setInt(..., "setBackgroundResource", ...)
    /// runtime par background drawable badalta hai, bina alag layout XML
    /// banaye har style ke liye.
    fun applyBackground(views: RemoteViews, rootViewId: Int, style: String) {
        val bgRes = when (style) {
            "gradient" -> R.drawable.widget_bg_gradient
            "neon" -> R.drawable.widget_bg_neon
            else -> R.drawable.widget_bg_minimal
        }
        views.setInt(rootViewId, "setBackgroundResource", bgRes)
    }
}