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
        val mode = WidgetStyleHelper.modeFor(context, "notes")
        // Tap par device ka apna (real) Notes app khulta hai -- Android kisi
        // bhi app ko doosri app ka private data padhne nahi deta, isliye
        // yahan us app mein saved actual text kabhi preview nahi ho sakta.
        // Static label hi sahi/honest hai, stale ya hamesha-empty text se
        // behtar.
        val noteText = "Tap to open Notes"

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_notes)
            WidgetStyleHelper.applyBackground(views, R.id.widget_root, style, mode)
            WidgetStyleHelper.applyTextColors(views, mode, secondaryIds = listOf(R.id.notes_text))
            views.setTextViewText(R.id.notes_text, noteText)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetClickActions.buildClickPendingIntent(
                    context, NotesWidgetProvider::class.java, "notes", widgetId
                )
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        if (intent.action == WidgetClickActions.ACTION_WIDGET_CLICK) {
            val type = intent.getStringExtra(WidgetClickActions.EXTRA_WIDGET_TYPE) ?: return
            WidgetClickActions.handleClick(context, type)
            return
        }
        super.onReceive(context, intent)
    }
}