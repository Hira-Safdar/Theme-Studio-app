package com.example.theme_studio

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.widget.RemoteViews

/// Ye ek chota, working example hai ke Home Screen widget kaise banta hai.
/// Flutter isse SEEDHA control nahi kar sakta -- RemoteViews aur
/// AppWidgetManager purely native concepts hain.
class BatteryWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateBatteryWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == WidgetClickActions.ACTION_WIDGET_CLICK) {
            val type = intent.getStringExtra(WidgetClickActions.EXTRA_WIDGET_TYPE) ?: return
            WidgetClickActions.handleClick(context, type)
            return
        }
        super.onReceive(context, intent)
    }

    companion object {
        fun updateBatteryWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val batteryIntent = context.registerReceiver(
                null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val percentage = if (level >= 0 && scale > 0) (level * 100 / scale) else 0

            val style = WidgetStyleHelper.styleFor(context, "battery")
            val mode = WidgetStyleHelper.modeFor(context, "battery")
            val views = RemoteViews(context.packageName, R.layout.widget_battery)
            WidgetStyleHelper.applyBackground(views, R.id.widget_root, style, mode)
            WidgetStyleHelper.applyTextColors(
                views, mode, primaryIds = listOf(R.id.battery_percentage_text)
            )
            views.setTextViewText(R.id.battery_percentage_text, "$percentage%")
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetClickActions.buildClickPendingIntent(
                    context, BatteryWidgetProvider::class.java, "battery", widgetId
                )
            )

            manager.updateAppWidget(widgetId, views)
        }
    }
}