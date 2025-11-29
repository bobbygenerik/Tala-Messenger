package com.example.holy_grail_messenger

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Telephony.Sms.Intents.SMS_DELIVER_ACTION == intent.action) {
            // Handle incoming SMS here
            // For now, we just acknowledge it. In a real app, we'd save to DB and notify Flutter.
        }
    }
}
