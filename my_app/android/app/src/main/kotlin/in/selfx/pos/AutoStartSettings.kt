package `in`.selfx.pos

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.app.UiModeManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Boot preference and user-granted background activity launch access. */
class AutoStartSettings(private val activity: Activity) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isSupported" -> result.success(true)
                "isEnabled" -> result.success(isEnabled(activity))
                "getStatus" -> {
                    val ui = activity.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    result.success(mapOf(
                        "enabled" to isEnabled(activity),
                        "permissionGranted" to canLaunchAtBoot(activity),
                        "isTv" to (ui.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION),
                    ))
                }
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    check(preferences(activity).edit().putBoolean(KEY, enabled).commit()) {
                        "Unable to save auto-start setting"
                    }
                    activity.packageManager.setComponentEnabledSetting(
                        ComponentName(activity, BootReceiver::class.java),
                        if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP,
                    )
                    result.success(true)
                }
                "openPermissionSettings" -> result.success(openSettings(
                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${activity.packageName}")),
                ))
                "openAppSettings" -> result.success(openSettings(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:${activity.packageName}")),
                ))
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("AUTO_START", error.message, null)
        }
    }

    private fun openSettings(intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: android.content.ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }

    companion object {
        private const val KEY = "flutter.pos_auto_start_enabled"
        private fun preferences(context: Context) =
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        fun isEnabled(context: Context): Boolean = preferences(context).getBoolean(KEY, true)

        fun canLaunchAtBoot(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
            val policy = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            return Settings.canDrawOverlays(context) || policy?.isDeviceOwnerApp(context.packageName) == true
        }
    }
}
