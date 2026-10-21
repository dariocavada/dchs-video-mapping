package dev.dariocavada.dchs_video_mapping

import android.app.Activity
import android.app.ActivityManager
import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.net.Uri
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel

/** Optional Home entry: Android starts its chosen Home app after boot. */
class AndroidStartup(private val activity: Activity) {
    private val manager get() = activity.packageManager
    private val preferences = activity.getSharedPreferences("android_startup", 0)
    private val homeEntry = ComponentName(activity, "${activity.packageName}.PlayerHome")
    private val homeIntent get() = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
    private var pending: MethodChannel.Result? = null

    private fun isHome(): Boolean = isSelectedHome(activity)

    fun status(): Map<String, Boolean> = mapOf(
        "supported" to true,
        "enabled" to isEnabled(activity),
        "requiresDisplayPermission" to requiresDisplayPermission(),
    )

    private fun finishRequest() {
        val result = pending
        pending = null
        if (!isEnabled(activity)) setEntry(false)
        result?.success(status())
    }

    private fun requestDisplayPermissionOrFinish() {
        if (isHome() && requiresDisplayPermission() && !Settings.canDrawOverlays(activity)) {
            activity.startActivityForResult(
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${activity.packageName}")),
                REQUEST_DISPLAY,
            )
        } else finishRequest()
    }

    private fun setEntry(enabled: Boolean) {
        manager.setComponentEnabledSetting(
            homeEntry,
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }

    private fun checkUnlocked() {
        val tasks = activity.getSystemService(Activity.ACTIVITY_SERVICE) as ActivityManager
        check(tasks.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE) {
            "Exit managed kiosk mode through its device administrator first."
        }
    }

    private fun rememberHome() {
        val current = manager.resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo
        if (current != null && current.packageName != activity.packageName &&
            !current.name.endsWith("FallbackHome") && current.packageName != "android") {
            preferences.edit().putString(
                "previous_home", ComponentName(current.packageName, current.name).flattenToString(),
            ).apply()
        }
    }

    fun setEnabled(enabled: Boolean, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("startup_pending", "Finish the Android Home selection first.", null)
            return
        }
        try {
            checkUnlocked()
            if (!enabled) {
                setEntry(false)
                result.success(status())
                return
            }
            if (isEnabled(activity)) {
                result.success(status())
                return
            }
            pending = result
            if (isHome()) {
                requestDisplayPermissionOrFinish()
                return
            }
            rememberHome()
            setEntry(true)
            val request = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roles = activity.getSystemService(RoleManager::class.java)
                if (roles != null && roles.isRoleAvailable(RoleManager.ROLE_HOME)) {
                    roles.createRequestRoleIntent(RoleManager.ROLE_HOME)
                } else Intent(Settings.ACTION_HOME_SETTINGS)
            } else Intent(Settings.ACTION_HOME_SETTINGS)
            activity.startActivityForResult(request, REQUEST_HOME)
        } catch (error: Exception) {
            pending = null
            if (enabled && !isEnabled(activity)) setEntry(false)
            result.error("startup_unavailable", error.message ?: "Unable to select the Home app.", null)
        }
    }

    fun onActivityResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_HOME && requestCode != REQUEST_DISPLAY) return false
        if (pending == null) return true
        try {
            if (requestCode == REQUEST_HOME) requestDisplayPermissionOrFinish()
            else finishRequest()
        } catch (error: Exception) {
            val result = pending
            pending = null
            if (!isEnabled(activity)) setEntry(false)
            result?.error("startup_unavailable", error.message, null)
        }
        return true
    }

    fun openPreviousHome(result: MethodChannel.Result) {
        try {
            checkUnlocked()
            val saved = preferences.getString("previous_home", null)?.let(ComponentName::unflattenFromString)
            val candidates = manager.queryIntentActivities(homeIntent, 0)
            val target = candidates.firstOrNull {
                it.activityInfo.packageName != activity.packageName &&
                    !it.activityInfo.name.endsWith("FallbackHome") &&
                    saved == ComponentName(it.activityInfo.packageName, it.activityInfo.name)
            } ?: candidates.firstOrNull {
                it.activityInfo.packageName != activity.packageName &&
                    !it.activityInfo.name.endsWith("FallbackHome")
            }
            check(target != null) { "No other Android Home app is available." }
            activity.startActivity(
                Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                    .setComponent(ComponentName(target.activityInfo.packageName, target.activityInfo.name))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            result.success(null)
        } catch (error: Exception) {
            result.error("home_unavailable", error.message ?: "Unable to open Android Home.", null)
        }
    }

    companion object {
        private const val REQUEST_HOME = 7316
        private const val REQUEST_DISPLAY = 7317

        // This firmware explicitly launches its factory Home after boot, even when
        // another Home is selected. Its BOOT_COMPLETED fallback needs the Android
        // 11 background-activity exception; no overlay window is ever created.
        fun requiresDisplayPermission(): Boolean =
            Build.VERSION.SDK_INT == Build.VERSION_CODES.R &&
                Build.HARDWARE.equals("amlogic", ignoreCase = true) &&
                Build.MODEL.equals("X96_X10Pro", ignoreCase = true)

        fun isEnabled(context: Context): Boolean = isSelectedHome(context) &&
            (!requiresDisplayPermission() || Settings.canDrawOverlays(context))

        private fun isSelectedHome(context: Context): Boolean {
            val manager = context.packageManager
            val entry = ComponentName(context, "${context.packageName}.PlayerHome")
            return manager.getComponentEnabledSetting(entry) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED &&
                manager.resolveActivity(
                    Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
                    PackageManager.MATCH_DEFAULT_ONLY,
                )?.activityInfo?.packageName == context.packageName
        }
    }
}
