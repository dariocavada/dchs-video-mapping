package dev.dariocavada.dchs_video_mapping

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/** Forward the optional Home entry to the same player task used by its icon. */
class PlayerHome : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startActivity(
            Intent(this, MainActivity::class.java).addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            ),
        )
        finish()
    }
}
