package com.sciometa.osd

import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Enable immersive mode on app startup
        enableImmersiveMode()
    }

    private fun enableImmersiveMode() {
        // Hide the navigation bar and status bar
        WindowCompat.setDecorFitsSystemWindows(window, false)

        val windowInsetsController = WindowInsetsControllerCompat(window, window.decorView)

        // Hide the navigation bar and status bar
        windowInsetsController.hide(WindowInsetsCompat.Type.navigationBars() or WindowInsetsCompat.Type.statusBars())

        // Set the behavior to show bars temporarily when user swipes
        windowInsetsController.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE

        // Keep screen on (useful for display mode)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        Log.d("MainActivity", "Immersive mode enabled - navigation bar and status bar hidden")
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // Re-enable immersive mode when focus is regained
            enableImmersiveMode()
        }
    }
}
