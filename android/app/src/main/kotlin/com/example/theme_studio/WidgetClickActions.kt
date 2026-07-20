package com.example.theme_studio

import android.app.PendingIntent
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.AlarmClock
import android.provider.Settings

/// Har widget type ke tap par kya karna hai -- ek hi jagah define, sab
/// providers sirf yahan se PendingIntent banate hain aur onReceive() mein
/// [handleClick] ko forward karte hain. Isse har provider mein duplicate
/// click-handling code nahi likhna padta.
object WidgetClickActions {

    const val ACTION_WIDGET_CLICK = "com.example.theme_studio.ACTION_WIDGET_CLICK"
    const val EXTRA_WIDGET_TYPE = "widget_type"

    /// Provider ke onUpdate() mein widget_root par ye laga do -- tap hote
    /// hi yehi provider ka onReceive() [ACTION_WIDGET_CLICK ke saath] chalega.
    /// [widgetId] ko request code ke tor par use karte hain taake multiple
    /// pinned instances (ek se zyada widget copies) ek dusre ka PendingIntent
    /// overwrite na karein.
    fun <T : AppWidgetProvider> buildClickPendingIntent(
        context: Context,
        providerClass: Class<T>,
        widgetType: String,
        widgetId: Int,
    ): PendingIntent {
        val intent = Intent(context, providerClass).apply {
            action = ACTION_WIDGET_CLICK
            putExtra(EXTRA_WIDGET_TYPE, widgetType)
        }
        return PendingIntent.getBroadcast(
            context,
            widgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /// Provider ke onReceive() se call karo jab [ACTION_WIDGET_CLICK] aaye.
    fun handleClick(context: Context, widgetType: String) {
        when (widgetType) {
            "battery" -> openBatterySettings(context)
            "clock" -> openClockApp(context)
            "calendar" -> openCalendarApp(context)
            "weather" -> openWeatherApp(context)
            "notes" -> openNotesEditor(context)
        }
    }

    private fun openBatterySettings(context: Context) {
        // Settings.ACTION_POWER_USAGE_SUMMARY constant kuch compileSdk
        // versions ke stubs mein maujood nahi hai (deprecated) -- raw
        // action string use kar rahe hain taake build kisi SDK version par
        // na tooté, behavior wahi rehta hai.
        val intent = Intent("android.intent.action.POWER_USAGE_SUMMARY").newTaskFlag()
        safeStart(context, intent) {
            safeStart(context, Intent(Settings.ACTION_SETTINGS).newTaskFlag())
        }
    }

    private fun openClockApp(context: Context) {
        safeStart(context, Intent(AlarmClock.ACTION_SHOW_ALARMS).newTaskFlag())
    }

    private fun openCalendarApp(context: Context) {
        val todayUri = Uri.parse("content://com.android.calendar/time/")
            .buildUpon()
            .appendPath(System.currentTimeMillis().toString())
            .build()
        val viewToday = Intent(Intent.ACTION_VIEW).apply {
            data = todayUri
        }.newTaskFlag()

        safeStart(context, viewToday) {
            val fallback = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_APP_CALENDAR)
            }.newTaskFlag()
            safeStart(context, fallback)
        }
    }

    /// [Intent.CATEGORY_APP_WEATHER] se koi bhi installed weather app milta
    /// hai to seedha wahi khulta hai; koi na mile (bohat kam devices par
    /// hota hai) to Google search fallback -- ye hamesha available hota hai.
    private fun openWeatherApp(context: Context) {
        val weatherIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_APP_WEATHER)
        }.newTaskFlag()

        val resolved = context.packageManager.resolveActivity(weatherIntent, 0)
        if (resolved != null) {
            safeStart(context, weatherIntent)
        } else {
            safeStart(
                context,
                Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=weather"))
                    .newTaskFlag(),
            )
        }
    }

    /// Notes ka tap ab pehle device ka apna (real) Notes app kholne ki
    /// koshish karta hai -- baaki widgets ke pattern jaisa. Sirf tab humari
    /// apni in-app "Edit Note" screen fallback ke tor par khulti hai jab
    /// device par koi notes app resolve na ho (jaise kuch Infinix/lightweight
    /// OEM builds par).
    private val knownNotesPackages = listOf(
        "com.samsung.android.app.notes", // Samsung Notes
        "com.google.android.keep",       // Google Keep
        "com.miui.notes",                // Xiaomi/MIUI Notes
        "com.coloros.note",              // Oppo/Realme (ColorOS) Notes
        "com.nearme.note",               // Oppo (older ColorOS) Notes
        "com.oneplus.note",              // OnePlus Notes
        "com.vivo.notes",                // Vivo Notes
        "com.huawei.notepad",            // Huawei Notepad
    )

    fun openNotesEditor(context: Context) {
        // 1) Android ka official "create note" intent -- stylus/S-Pen
        //    shortcut isi se OEM Notes app (jaise Samsung Notes) kholta hai.
        val createNoteIntent = Intent("android.intent.action.CREATE_NOTE").newTaskFlag()
        if (safeStart(context, createNoteIntent)) return

        // 2) Known OEM notes app packages seedha try karo.
        for (pkg in knownNotesPackages) {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(pkg)
            if (launchIntent != null && safeStart(context, launchIntent.newTaskFlag())) return
        }

        // 3) Koi notes app na mile -- humari apni app ke andar chhota
        //    "Edit Note" screen fallback ke tor par.
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra(MainActivity.EXTRA_OPEN_NOTES_EDITOR, true)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        context.startActivity(intent)
    }

    private fun Intent.newTaskFlag(): Intent = apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }

    /// @return true agar activity successfully start ho gayi.
    private fun safeStart(context: Context, intent: Intent, onFail: (() -> Unit)? = null): Boolean {
        return try {
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            // Koi matching app na mile (ActivityNotFoundException) ya
            // package-visibility block kare -- fallback try karo, warna
            // silently ignore (widget tap se app crash nahi hona chahiye).
            onFail?.invoke()
            false
        }
    }
}