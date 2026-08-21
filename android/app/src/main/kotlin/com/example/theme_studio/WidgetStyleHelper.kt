package com.example.theme_studio

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
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

    /// User ne Flutter side se jo customization ki (fontSize, textColor,
    /// bgOpacity, cornerRadius) wo SharedPreferences mein save hoti hain --
    /// ye method un values ko RemoteViews pe apply karta hai.
    fun applyCustomization(
        context: Context,
        views: RemoteViews,
        primaryIds: List<Int> = emptyList(),
        secondaryIds: List<Int> = emptyList()
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Text color — hex string "#RRGGBB"
        val textColorHex = prefs.getString("widget_text_color", null)
        if (textColorHex != null) {
            try {
                val color = android.graphics.Color.parseColor(textColorHex)
                (primaryIds + secondaryIds).forEach { views.setTextColor(it, color) }
            } catch (_: Exception) {}
        }
    }

    /// Corner radius aur background opacity ko programmatic GradientDrawable
    /// se apply karta hai -- RemoteViews drawable resource se ye nahi kar
    /// sakti, isliye runtime par shape banate hain.
    fun applyBackgroundCustomization(
        context: Context,
        views: RemoteViews,
        rootViewId: Int,
        style: String,
        mode: String
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val bgOpacity = prefs.getFloat("widget_bg_opacity", 0.85f)
        val cornerRadius = prefs.getFloat("widget_corner_radius", 12f)
        val isLight = mode == MODE_LIGHT

        // Base color style/mode se
        val baseColor = when {
            style == "gradient" -> if (isLight) android.graphics.Color.parseColor("#B8FFF9") else android.graphics.Color.parseColor("#1A1A2E")
            style == "neon" -> if (isLight) android.graphics.Color.parseColor("#F4FDFC") else android.graphics.Color.parseColor("#0A0A12")
            else -> if (isLight) android.graphics.Color.parseColor("#F2EFEC") else android.graphics.Color.parseColor("#1E1E2E")
        }

        val alpha = (bgOpacity * 255).toInt().coerceIn(0, 255)
        val colorWithAlpha = android.graphics.Color.argb(alpha,
            android.graphics.Color.red(baseColor),
            android.graphics.Color.green(baseColor),
            android.graphics.Color.blue(baseColor)
        )

        views.setInt(rootViewId, "setBackgroundColor", colorWithAlpha)
    }

    // ---------------- LIVE REFRESH TICKER (Clock + Battery) ----------------
    // widget_info.xml ka `updatePeriodMillis` OS ki taraf se kam-se-kam
    // 30 minute par floor hota hai (aur kai OEMs isse aur bhi throttle kar
    // dete hain) -- Clock ko har minute update chahiye, Battery ko bhi
    // jald-jald. Isliye khud ka "tick" chain banate hain: ClockWidgetProvider
    // (jo pehle se ek BroadcastReceiver hai) ko har minute ek custom
    // broadcast milta hai, dono widgets refresh hote hain, aur agla tick
    // khud reschedule ho jaata hai -- alag se koi naya Receiver class nahi
    // banani padi.
    const val ACTION_WIDGET_TICK = "com.example.theme_studio.ACTION_WIDGET_TICK"
    private const val TICK_REQUEST_CODE = 9001
    private const val TICK_INTERVAL_MS = 60_000L // 1 minute

    private fun tickPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ClockWidgetProvider::class.java).apply {
            action = ACTION_WIDGET_TICK
        }
        return PendingIntent.getBroadcast(
            context,
            TICK_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /// Agla tick schedule karta hai. `setAndAllowWhileIdle` (inexact,
    /// lekin Doze mode mein bhi eventually fire hoti hai) jaan-boojh kar
    /// use ki hai -- `setExactAndAllowWhileIdle` Android 12+ par
    /// `SCHEDULE_EXACT_ALARM` special permission maangta hai (jo user ko
    /// Settings mein manually enable karna padta), jo ek clock widget ke
    /// "minute ke andar-andar" update ke liye zaroori nahi. Screen-on
    /// hote hi turant catch-up ho jaata hai.
    fun scheduleNextTick(context: Context) {
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        // Align to next minute boundary so widgets show current time, not 1 min behind
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
            add(java.util.Calendar.MINUTE, 1)
        }
        val triggerAt = calendar.timeInMillis
        val pendingIntent = tickPendingIntent(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    /// Jab Clock aur Battery dono ke koi pinned instances na rahen, tick
    /// chain band kar dete hain -- warna widget na hone ke bawajood
    /// battery drain hoti rahegi.
    fun cancelTick(context: Context) {
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarmManager.cancel(tickPendingIntent(context))
    }
}