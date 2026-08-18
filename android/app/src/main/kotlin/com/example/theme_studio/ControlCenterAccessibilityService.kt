package com.example.theme_studio

import android.accessibilityservice.AccessibilityService
import android.bluetooth.BluetoothAdapter
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.SeekBar
import android.widget.Toast

class ControlCenterAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ControlCenter"
        private val BG_OFF = Color.parseColor("#22FFFFFF")
        private val BG_ON = Color.parseColor("#5500FFF0")
    }

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    // Toggle states
    private var wifiOn = false
    private var bluetoothOn = false
    private var flashlightOn = false

    // Swipe gesture tracking
    private var initialY = 0f
    private var isSwiping = false
    private val swipeThreshold = 40

    override fun onServiceConnected() {
        super.onServiceConnected()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        addTriggerStrip()
        Log.d(TAG, "Service connected, trigger strip added")
    }

    // --- Trigger strip (top-right) ---

    private inner class TriggerView(context: Context) : View(context) {
        init {
            isClickable = true
            isFocusable = true
            isFocusableInTouchMode = true
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            Log.d(TAG, "Trigger touch: action=${event.actionMasked} y=${event.y}")
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    initialY = event.y
                    isSwiping = false
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaY = event.y - initialY
                    if (deltaY > swipeThreshold && !isSwiping) {
                        isSwiping = true
                        Log.d(TAG, "Swipe down detected, showing overlay")
                        showControlCenterOverlay()
                    }
                    return true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    isSwiping = false
                    return true
                }
            }
            return super.onTouchEvent(event)
        }
    }

    private fun addTriggerStrip() {
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val halfWidth = screenWidth / 2
        val triggerHeight = 80

        val params = WindowManager.LayoutParams(
            halfWidth,
            triggerHeight,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.END or Gravity.TOP

        val trigger = TriggerView(this)
        windowManager?.addView(trigger, params)
        Log.d(TAG, "Trigger added: ${halfWidth}x${triggerHeight} at top-right")
    }

    // --- Overlay ---

    private fun showControlCenterOverlay() {
        if (overlayView != null) {
            Log.d(TAG, "Overlay already showing")
            return
        }

        try {
            val inflater = LayoutInflater.from(this)
            overlayView = inflater.inflate(R.layout.control_center_overlay, null)
            Log.d(TAG, "Overlay inflated successfully")

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            )
            params.gravity = Gravity.TOP

            setupControls()
            windowManager?.addView(overlayView, params)
            Log.d(TAG, "Overlay added to window manager")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay: ${e.message}", e)
            overlayView = null
        }
    }

    private fun setupControls() {
        overlayView ?: return
        Log.d(TAG, "Setting up controls")

        // Read current states
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifiOn = wifiManager.isWifiEnabled
            Log.d(TAG, "WiFi initial state: $wifiOn")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read WiFi state: ${e.message}")
            wifiOn = false
        }
        try {
            val btAdapter = BluetoothAdapter.getDefaultAdapter()
            bluetoothOn = btAdapter?.isEnabled == true
            Log.d(TAG, "Bluetooth initial state: $bluetoothOn")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read Bluetooth state: ${e.message}")
            bluetoothOn = false
        }

        // Apply initial visual states
        updateToggleVisual(R.id.btn_wifi, wifiOn)
        updateToggleVisual(R.id.btn_bluetooth, bluetoothOn)
        updateToggleVisual(R.id.btn_flashlight, flashlightOn)

        // WiFi click - opens WiFi settings (direct toggle deprecated on Android 10+)
        overlayView?.findViewById<View>(R.id.btn_wifi)?.setOnClickListener {
            Log.d(TAG, "WiFi button clicked, opening WiFi settings")
            try {
                val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    Intent(Settings.ACTION_WIFI_SETTINGS)
                } else {
                    // For older Android versions, try direct toggle
                    val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                    wifiOn = !wifiOn
                    @Suppress("DEPRECATION")
                    wifiManager.isWifiEnabled = wifiOn
                    updateToggleVisual(R.id.btn_wifi, wifiOn)
                    return@setOnClickListener
                }
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                hideControlCenterOverlay()
            } catch (e: Exception) {
                Log.e(TAG, "WiFi settings failed: ${e.message}")
                Toast.makeText(applicationContext, "Cannot open WiFi settings", Toast.LENGTH_SHORT).show()
            }
        }

        // Bluetooth click - opens Bluetooth settings (direct toggle deprecated on Android 13+)
        overlayView?.findViewById<View>(R.id.btn_bluetooth)?.setOnClickListener {
            Log.d(TAG, "Bluetooth button clicked, opening Bluetooth settings")
            try {
                val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                hideControlCenterOverlay()
            } catch (e: Exception) {
                Log.e(TAG, "Bluetooth settings failed: ${e.message}")
                Toast.makeText(applicationContext, "Cannot open Bluetooth settings", Toast.LENGTH_SHORT).show()
            }
        }

        // Flashlight click
        overlayView?.findViewById<View>(R.id.btn_flashlight)?.setOnClickListener {
            Log.d(TAG, "Flashlight button clicked, current state: $flashlightOn")
            flashlightOn = !flashlightOn
            toggleFlashlight(flashlightOn)
            updateToggleVisual(R.id.btn_flashlight, flashlightOn)
        }

        // Settings click: open settings + auto-close overlay
        overlayView?.findViewById<View>(R.id.btn_settings)?.setOnClickListener {
            Log.d(TAG, "Settings button clicked")
            val intent = Intent(Settings.ACTION_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            hideControlCenterOverlay()
        }

        // Swipe-up to close on entire overlay (ScrollView)
        overlayView?.findViewById<View>(R.id.scroll_root)?.setOnTouchListener { _, event ->
            Log.d(TAG, "Overlay touch: action=${event.actionMasked} y=${event.y}")
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    initialY = event.y
                    isSwiping = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaY = event.y - initialY
                    if (deltaY < -swipeThreshold && !isSwiping) {
                        isSwiping = true
                        Log.d(TAG, "Swipe up detected (deltaY=$deltaY), closing overlay")
                        hideControlCenterOverlay()
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    isSwiping = false
                    true
                }
                else -> false
            }
        }

        // Brightness slider
        setupBrightnessSlider()

        // Volume slider
        setupVolumeSlider()
    }

    private fun updateToggleVisual(viewId: Int, isOn: Boolean) {
        overlayView?.findViewById<View>(viewId)?.apply {
            setBackgroundColor(if (isOn) BG_ON else BG_OFF)
            Log.d(TAG, "Updated view $viewId background to ${if (isOn) "ON" else "OFF"}")
        }
    }

    private fun setupBrightnessSlider() {
        overlayView?.findViewById<SeekBar>(R.id.seekbar_brightness)?.apply {
            max = 255
            try {
                val currentBrightness = Settings.System.getInt(
                    contentResolver,
                    Settings.System.SCREEN_BRIGHTNESS,
                    128
                )
                progress = currentBrightness
                Log.d(TAG, "Brightness SeekBar initialized: current=$currentBrightness")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to read brightness: ${e.message}")
                progress = 128
            }

            // Check WRITE_SETTINGS permission
            val canWriteBrightness = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.System.canWrite(applicationContext)
            } else {
                true
            }
            Log.d(TAG, "WRITE_SETTINGS permission granted: $canWriteBrightness")

            // Let SeekBar handle touches normally, just prevent ScrollView from intercepting
            setOnTouchListener { v, event ->
                Log.d(TAG, "Brightness SeekBar touch: action=${event.actionMasked}")
                v.parent.requestDisallowInterceptTouchEvent(true)
                false // Let SeekBar handle it
            }
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    Log.d(TAG, "Brightness progress changed: $progress, fromUser=$fromUser")
                    if (fromUser) {
                        if (canWriteBrightness) {
                            try {
                                Settings.System.putInt(
                                    contentResolver,
                                    Settings.System.SCREEN_BRIGHTNESS,
                                    progress
                                )
                                Log.d(TAG, "Brightness set to $progress - SUCCESS")
                            } catch (e: SecurityException) {
                                Log.e(TAG, "Brightness permission denied: ${e.message}")
                                // Fallback: open display settings
                                openDisplaySettings()
                            } catch (e: Exception) {
                                Log.e(TAG, "Brightness change failed: ${e.message}", e)
                            }
                        } else {
                            // No permission - open display settings directly
                            Log.w(TAG, "No WRITE_SETTINGS permission, opening display settings")
                            openDisplaySettings()
                        }
                    }
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {
                    Log.d(TAG, "Brightness tracking started")
                }
                override fun onStopTrackingTouch(seekBar: SeekBar?) {
                    Log.d(TAG, "Brightness tracking stopped")
                }
            })
        }
    }

    private fun setupVolumeSlider() {
        overlayView?.findViewById<SeekBar>(R.id.seekbar_volume)?.apply {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            max = maxVol
            progress = currentVol
            Log.d(TAG, "Volume SeekBar initialized: max=$maxVol, current=$currentVol")

            // Let SeekBar handle touches normally, just prevent ScrollView from intercepting
            setOnTouchListener { v, event ->
                Log.d(TAG, "Volume SeekBar touch: action=${event.actionMasked}")
                v.parent.requestDisallowInterceptTouchEvent(true)
                false // Let SeekBar handle it
            }
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    Log.d(TAG, "Volume progress changed: $progress, fromUser=$fromUser")
                    if (fromUser) {
                        try {
                            audioManager.setStreamVolume(
                                AudioManager.STREAM_MUSIC,
                                progress,
                                0
                            )
                            Log.d(TAG, "Volume set to $progress - SUCCESS")
                        } catch (e: Exception) {
                            Log.e(TAG, "Volume change failed: ${e.message}", e)
                        }
                    }
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {
                    Log.d(TAG, "Volume tracking started")
                }
                override fun onStopTrackingTouch(seekBar: SeekBar?) {
                    Log.d(TAG, "Volume tracking stopped")
                }
            })
        }
    }

    private fun toggleFlashlight(on: Boolean) {
        Log.d(TAG, "Toggle flashlight: $on")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val cameraManager = getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                val cameraId = cameraManager.cameraIdList[0]
                cameraManager.setTorchMode(cameraId, on)
                Log.d(TAG, "Flashlight set to $on - SUCCESS")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Flashlight failed: ${e.message}", e)
        }
    }

    private fun openDisplaySettings() {
        Log.d(TAG, "Opening display settings for brightness control")
        try {
            val intent = Intent(Settings.ACTION_DISPLAY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            hideControlCenterOverlay()
        } catch (e: Exception) {
            Log.e(TAG, "Cannot open display settings: ${e.message}")
            Toast.makeText(applicationContext, "Cannot open display settings", Toast.LENGTH_SHORT).show()
        }
    }

    private fun hideControlCenterOverlay() {
        Log.d(TAG, "Hiding overlay")
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
            Log.d(TAG, "Overlay removed")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {
        Log.d(TAG, "Service interrupted")
        hideControlCenterOverlay()
    }
}
