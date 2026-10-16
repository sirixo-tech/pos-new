package com.selfx.pos.customer_display_android

import android.app.Activity
import android.app.ActivityManager
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val kioskChannelName = "selfx_qr_display/kiosk"
    private val lockPreferences by lazy {
        getSharedPreferences("selfx_qr_display_lock", Context.MODE_PRIVATE)
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingHomeResult: MethodChannel.Result? = null
    private val bringToFrontRunnable = Runnable {
        if (launcherLocked && !window.decorView.hasWindowFocus()) {
            bringLockedAppToFront()
        }
    }

    private var launcherLocked: Boolean
        get() = lockPreferences.getBoolean("locked", false)
        set(value) {
            lockPreferences.edit().putBoolean("locked", value).apply()
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kioskChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterKiosk" -> enterLauncherLock(result)
                    "exitKiosk" -> exitLauncherLock(result)
                    "getKioskStatus" -> result.success(launcherStatus())
                    else -> result.notImplemented()
                }
            }
    }

    private fun enterLauncherLock(result: MethodChannel.Result) {
        if (isDefaultHome()) {
            launcherLocked = true
            applyImmersiveMode()
            result.success(launcherStatus())
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
                pendingHomeResult = result
                startActivityForResult(
                    roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME),
                    requestHomeRole,
                )
                return
            }
        }
        startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
        result.error(
            "HOME_SELECTION_REQUIRED",
            "Choose SELFX QR Connect as the default Home app, then tap Lock again.",
            null,
        )
    }

    private fun exitLauncherLock(result: MethodChannel.Result) {
        launcherLocked = false
        restoreSystemUi()
        result.success(launcherStatus())
    }

    @Deprecated("Deprecated in Android; retained for the Home role request result.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestHomeRole) return
        val result = pendingHomeResult ?: return
        pendingHomeResult = null
        if (resultCode == Activity.RESULT_OK && isDefaultHome()) {
            launcherLocked = true
            applyImmersiveMode()
            result.success(launcherStatus())
        } else {
            result.error(
                "HOME_SELECTION_CANCELLED",
                "SELFX QR Connect must be selected as the default Home app.",
                null,
            )
        }
    }

    override fun onStart() {
        mainHandler.removeCallbacks(bringToFrontRunnable)
        super.onStart()
    }

    override fun onStop() {
        super.onStop()
        if (!launcherLocked) return
        mainHandler.removeCallbacks(bringToFrontRunnable)
        mainHandler.postDelayed(bringToFrontRunnable, 500)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && launcherLocked) applyImmersiveMode()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(bringToFrontRunnable)
        super.onDestroy()
    }

    private fun bringLockedAppToFront() {
        if (!launcherLocked || isFinishing) return
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        try {
            activityManager.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
        } catch (_: SecurityException) {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    )
                },
            )
        }
    }

    private fun isDefaultHome(): Boolean {
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = packageManager.resolveActivity(
            homeIntent,
            PackageManager.MATCH_DEFAULT_ONLY,
        )
        return resolved?.activityInfo?.packageName == packageName
    }

    @Suppress("DEPRECATION")
    private fun applyImmersiveMode() {
        window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }

    @Suppress("DEPRECATION")
    private fun restoreSystemUi() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }
    private fun launcherStatus(): Map<String, Boolean> = mapOf(
        "locked" to launcherLocked,
        "defaultHome" to isDefaultHome(),
    )

    companion object {
        private const val requestHomeRole = 4107
    }
}
