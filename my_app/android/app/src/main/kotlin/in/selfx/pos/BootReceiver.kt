package `in`.selfx.pos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.d(TAG, "BootReceiver received action: $action")
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        val prefs = try {
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        } catch (_: Throwable) {
            null
        }
        // Auto start on boot is ON by default
        val isEnabled = if (prefs != null && prefs.contains("flutter.pos_auto_start_enabled")) {
            prefs.getBoolean("flutter.pos_auto_start_enabled", true)
        } else {
            true
        }

        if (!isEnabled) {
            Log.d(TAG, "Auto-start on boot is disabled in settings. Skipping launch.")
            return
        }

        if (!AutoStartSettings.canLaunchAtBoot(context)) {
            Log.w(TAG, "Boot launch needs Display over other apps access or device-owner provisioning. Open auto-start settings in the app.")
            return
        }

        Log.d(TAG, "Device boot/restart complete. Launching POS app automatically...")
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: run {
            Intent(context, MainActivity::class.java)
        }
        launchIntent.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("launched_from_boot", true)
        }

        // Allow the TV launcher to finish booting before bringing the saved
        // workspace forward. Keep the receiver alive until the launch completes.
        val pending = goAsync()
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            try {
                if (AutoStartSettings.isEnabled(context) && AutoStartSettings.canLaunchAtBoot(context)) {
                    context.startActivity(launchIntent)
                    Log.d(TAG, "POS app launch intent sent successfully.")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start activity from BootReceiver", e)
            } finally {
                pending.finish()
            }
        }, 2500)
    }

    companion object {
        private const val TAG = "BootReceiver"
    }
}
