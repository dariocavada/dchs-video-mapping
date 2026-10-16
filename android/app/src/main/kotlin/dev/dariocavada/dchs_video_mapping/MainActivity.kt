package dev.dariocavada.dchs_video_mapping

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun locked(): Boolean =
        (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dchs_video_mapping/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "output" -> {
                        val manager = getSystemService(Context.DISPLAY_SERVICE) as android.hardware.display.DisplayManager
                        val screen = if (android.os.Build.VERSION.SDK_INT >= 30) display else manager.getDisplay(android.view.Display.DEFAULT_DISPLAY)
                        result.success(mapOf("key" to "${screen?.displayId}:${screen?.name}:${screen?.mode?.physicalWidth}x${screen?.mode?.physicalHeight}@${screen?.mode?.refreshRate}"))
                    }
                    "status" -> result.success(locked())
                    "start" -> {
                        val policy = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        // Never use screen pinning as a substitute for a provisioned kiosk.
                        if (policy.isLockTaskPermitted(packageName)) {
                            try { if (!locked()) startLockTask() } catch (_: SecurityException) {}
                        }
                        result.success(locked())
                    }
                    "stop" -> {
                        try { if (locked()) stopLockTask() } catch (_: SecurityException) {}
                        result.success(locked())
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
