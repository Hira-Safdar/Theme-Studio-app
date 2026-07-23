package com.example.theme_studio

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ClockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val style = WidgetStyleHelper.styleFor(context, "clock")
            val mode = WidgetStyleHelper.modeFor(context, "clock")
            val views = RemoteViews(context.packageName, R.layout.widget_clock)
            WidgetStyleHelper.applyBackground(views, R.id.widget_root, style, mode)
            WidgetStyleHelper.applyTextColors(views, mode, primaryIds = listOf(R.id.clock_text))
            val time = SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date())
            views.setTextViewText(R.id.clock_text, time)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetClickActions.buildClickPendingIntent(
                    context, ClockWidgetProvider::class.java, "clock", widgetId
                )
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
        // Har onUpdate ke baad agla minute-tick (re)arm -- idempotent hai,
        // pehli pin, reboot ke baad system-trigger, ya humari apni tick
        // chain -- sab isi ek jagah se chain ko zinda rakhte hain.
        WidgetStyleHelper.scheduleNextTick(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        WidgetStyleHelper.scheduleNextTick(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // Sirf tab band karo jab Battery ke bhi 0 instances hon -- ticker
        // dono widgets share karta hai.
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val clockIds = appWidgetManager.getAppWidgetIds(ComponentName(context, ClockWidgetProvider::class.java))
        val batteryIds = appWidgetManager.getAppWidgetIds(ComponentName(context, BatteryWidgetProvider::class.java))
        if (clockIds.isEmpty() && batteryIds.isEmpty()) {
            WidgetStyleHelper.cancelTick(context)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            WidgetClickActions.ACTION_WIDGET_CLICK -> {
                val type = intent.getStringExtra(WidgetClickActions.EXTRA_WIDGET_TYPE) ?: return
                WidgetClickActions.handleClick(context, type)
            }
            // Har minute ka tick -- Clock ke saath Battery ko bhi refresh
            // karte hain (existing onUpdate() reuse karke, alag se koi
            // duplicate update-logic nahi), phir agla tick reschedule.
            WidgetStyleHelper.ACTION_WIDGET_TICK -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val clockIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, ClockWidgetProvider::class.java)
                )
                val batteryIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, BatteryWidgetProvider::class.java)
                )
                if (clockIds.isNotEmpty()) onUpdate(context, appWidgetManager, clockIds)
                if (batteryIds.isNotEmpty()) {
                    for (id in batteryIds) {
                        BatteryWidgetProvider.updateBatteryWidget(context, appWidgetManager, id)
                    }
                }
                if (clockIds.isNotEmpty() || batteryIds.isNotEmpty()) {
                    WidgetStyleHelper.scheduleNextTick(context)
                }
            }
            else -> super.onReceive(context, intent)
        }
    }
}