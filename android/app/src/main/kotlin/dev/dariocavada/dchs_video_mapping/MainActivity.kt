package dev.dariocavada.dchs_video_mapping

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.embedding.engine.renderer.FlutterRenderer
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val startup by lazy { AndroidStartup(this) }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        startup.onActivityResult(requestCode)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT == Build.VERSION_CODES.R &&
            Build.HARDWARE.equals("amlogic", ignoreCase = true) &&
            Build.MODEL == "X96_X10Pro") {
            // This firmware caps texture output at 14 buffers, while Flutter's
            // ImageReader requires at least 18. Keep a compositable GL texture
            // so calibration and Bezier clipping still work. Flutter exposes
            // this switch as a testing API; recheck it on engine upgrades.
            // GL textures require the GLES renderer, not Impeller Vulkan.
            intent.putExtra(FlutterShellArgs.ARG_KEY_TOGGLE_IMPELLER, false)
            FlutterRenderer.debugForceSurfaceProducerGlTextures = true
            android.util.Log.i("DchsVideo", "Using GL video textures for X96_X10Pro Android 11")
        }
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
                    "startupStatus" -> result.success(startup.status())
                    "startupSet" -> startup.setEnabled(call.argument<Boolean>("enabled") == true, result)
                    "openAndroidHome" -> startup.openPreviousHome(result)
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
