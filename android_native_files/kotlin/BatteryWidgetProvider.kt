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

    companion object {
        fun updateBatteryWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val batteryIntent = context.registerReceiver(
                null,
                IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val percentage = if (level >= 0 && scale > 0) (level * 100 / scale) else 0

            val views = RemoteViews(context.packageName, R.layout.widget_battery)
            views.setTextViewText(R.id.battery_percentage_text, "$percentage%")

            manager.updateAppWidget(widgetId, views)
        }
    }
}
