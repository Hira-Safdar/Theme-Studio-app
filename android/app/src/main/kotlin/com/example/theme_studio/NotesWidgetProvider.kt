package com.example.theme_studio

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/// NOTE: Abhi ek static placeholder text dikhata hai. Real note-taking
/// (user apna text likh kar save kare, wahi widget par dikhe) ke liye ek
/// chhota "edit note" flow chahiye hoga (Flutter side se
/// SharedPreferences["widget_styles"]["notes_text"] mein likhna, yahan se
/// padhna) -- ye future scope hai, abhi ke liye placeholder kaafi hai.
class NotesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val style = WidgetStyleHelper.styleFor(context, "notes")
        val prefs = context.getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
        val noteText = prefs.getString("notes_text", null) ?: "Tap to add a note"

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_notes)
            WidgetStyleHelper.applyBackground(views, R.id.widget_root, style)
            views.setTextViewText(R.id.notes_text, noteText)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}