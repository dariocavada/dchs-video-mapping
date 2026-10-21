package dev.dariocavada.dchs_video_mapping

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Some TV firmware explicitly starts its vendor launcher instead of the chosen Home app. */
class PlayerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED || !AndroidStartup.isEnabled(context)) return
        try {
            context.startActivity(
                Intent(context, MainActivity::class.java).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                ),
            )
            Log.i("DchsStartup", "Requested the selected player after boot")
        } catch (error: Exception) {
            Log.e("DchsStartup", "Firmware did not allow player startup", error)
        }
    }
}
