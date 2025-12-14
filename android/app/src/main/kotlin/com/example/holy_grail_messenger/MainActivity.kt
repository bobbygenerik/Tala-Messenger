package com.example.holy_grail_messenger

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.Telephony
import android.database.Cursor
import android.net.Uri
import android.telephony.SmsManager
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.holy_grail_messenger/sms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Attempt to bypass hidden API restrictions
        HiddenApiBypass.bypass()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getConversations" -> {
                    getConversations(result)
                }
                "getMessages" -> {
                    val threadId = call.argument<String>("threadId")
                    if (threadId != null) {
                        getMessages(threadId, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "threadId is null", null)
                    }
                }
                "sendSms" -> {
                    val address = call.argument<String>("address")
                    val body = call.argument<String>("body")
                    if (address != null && body != null) {
                        sendSms(address, body, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing arguments", null)
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        launchApp(packageName, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "packageName is null", null)
                    }
                }
                "launchVideoCall" -> {
                    val packageName = call.argument<String>("packageName")
                    val contact = call.argument<String>("contact")
                    if (packageName != null && contact != null) {
                        launchVideoCall(packageName, contact, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing arguments", null)
                    }
                }
                "requestNotificationAccess" -> {
                    requestNotificationAccess(result)
                }
                "requestAccessibilityAccess" -> {
                    requestAccessibilityAccess(result)
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission(result)
                }
                "getUnifiedInbox" -> {
                    getUnifiedInbox(result)
                }
                "sendUnifiedMessage" -> {
                    val platform = call.argument<String>("platform")
                    val message = call.argument<String>("message")
                    val recipient = call.argument<String>("recipient")
                    if (platform != null && message != null && recipient != null) {
                        sendUnifiedMessage(platform, message, recipient, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing arguments", null)
                    }
                }
                "showBubble" -> {
                    val sender = call.argument<String>("sender")
                    val message = call.argument<String>("message")
                    if (sender != null && message != null) {
                        showBubble(sender, message)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing arguments", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }



    private fun getConversations(result: MethodChannel.Result) {
        try {
            val conversations = mutableListOf<Map<String, Any>>()
            val uri = Telephony.Sms.Conversations.CONTENT_URI
            val projection = arrayOf(
                Telephony.Sms.Conversations.THREAD_ID,
                Telephony.Sms.Conversations.MESSAGE_COUNT,
                Telephony.Sms.Conversations.SNIPPET
            )
            
            val cursor = contentResolver.query(uri, projection, null, null, "date DESC")
            cursor?.use {
                while (it.moveToNext()) {
                    val threadId = it.getLong(0)
                    val messageCount = it.getInt(1)
                    val snippet = it.getString(2) ?: ""
                    
                    // Get the address for this thread
                    val address = getAddressForThread(threadId)
                    
                    conversations.add(mapOf(
                        "threadId" to threadId.toString(),
                        "address" to address,
                        "snippet" to snippet,
                        "messageCount" to messageCount,
                        "date" to System.currentTimeMillis(),
                        "read" to 1
                    ))
                }
            }
            result.success(conversations)
        } catch (e: Exception) {
            Log.e("SMS", "Error getting conversations", e)
            result.error("SMS_ERROR", e.message, null)
        }
    }
    
    private fun getAddressForThread(threadId: Long): String {
        val uri = Uri.parse("content://mms-sms/conversations/$threadId/recipients")
        val cursor = contentResolver.query(uri, null, null, null, null)
        return cursor?.use {
            if (it.moveToFirst()) {
                it.getString(0) ?: "Unknown"
            } else "Unknown"
        } ?: "Unknown"
    }
    
    private fun getMessages(threadId: String, result: MethodChannel.Result) {
        try {
            val messages = mutableListOf<Map<String, Any>>()
            val uri = Telephony.Sms.CONTENT_URI
            val selection = "${Telephony.Sms.THREAD_ID} = ?"
            val selectionArgs = arrayOf(threadId)
            
            val cursor = contentResolver.query(uri, null, selection, selectionArgs, "date DESC")
            cursor?.use {
                while (it.moveToNext()) {
                    val id = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms._ID))
                    val body = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY)) ?: ""
                    val address = it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)) ?: ""
                    val date = it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE))
                    val type = it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.TYPE))
                    val read = it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.READ))
                    
                    messages.add(mapOf(
                        "id" to id,
                        "body" to body,
                        "address" to address,
                        "date" to date,
                        "isMe" to (type == Telephony.Sms.MESSAGE_TYPE_SENT),
                        "read" to read,
                        "status" to if (type == Telephony.Sms.MESSAGE_TYPE_SENT) 1 else -1
                    ))
                }
            }
            result.success(messages)
        } catch (e: Exception) {
            Log.e("SMS", "Error getting messages", e)
            result.error("SMS_ERROR", e.message, null)
        }
    }
    
    private fun sendSms(address: String, body: String, result: MethodChannel.Result) {
        try {
            val smsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(address, null, body, null, null)
            result.success(null)
        } catch (e: Exception) {
            Log.e("SMS", "Error sending SMS", e)
            result.error("SMS_ERROR", e.message, null)
        }
    }

    private fun launchApp(packageName: String, result: MethodChannel.Result) {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                startActivity(launchIntent)
                result.success(null)
            } else {
                result.error("APP_NOT_FOUND", "App not found", null)
            }
        } catch (e: Exception) {
            result.error("LAUNCH_ERROR", e.message, null)
        }
    }
    
    private fun launchVideoCall(packageName: String, contact: String, result: MethodChannel.Result) {
        try {
            when (packageName) {
                "com.google.android.apps.meetings" -> {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://meet.google.com/new"))
                    startActivity(intent)
                }
                "com.whatsapp" -> {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/$contact"))
                    startActivity(intent)
                }
                "us.zoom.videomeetings" -> {
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    if (intent != null) {
                        startActivity(intent)
                    } else {
                        val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://zoom.us/start/videomeeting"))
                        startActivity(webIntent)
                    }
                }
                else -> {
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    if (intent != null) {
                        startActivity(intent)
                    } else {
                        result.error("APP_NOT_FOUND", "App not found", null)
                        return
                    }
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("LAUNCH_ERROR", e.message, null)
        }
    }



    private fun requestNotificationAccess(result: MethodChannel.Result) {
        try {
            val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    private fun requestAccessibilityAccess(result: MethodChannel.Result) {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    private fun requestOverlayPermission(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                intent.data = android.net.Uri.parse("package:$packageName")
                startActivity(intent)
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("PERMISSION_ERROR", e.message, null)
        }
    }

    private fun getUnifiedInbox(result: MethodChannel.Result) {
        try {
            // This would typically get data from MessageCacheService
            // For now, return sample data
            val inbox = listOf(
                mapOf(
                    "threadKey" to "google_messages_123",
                    "platform" to "google_messages",
                    "sender" to "John Doe",
                    "lastMessage" to "Hey, how are you?",
                    "timestamp" to System.currentTimeMillis(),
                    "unreadCount" to 2,
                    "isTyping" to false
                ),
                mapOf(
                    "threadKey" to "messenger_456",
                    "platform" to "messenger",
                    "sender" to "Jane Smith",
                    "lastMessage" to "See you later!",
                    "timestamp" to System.currentTimeMillis() - 3600000,
                    "unreadCount" to 0,
                    "isTyping" to true
                )
            )
            result.success(inbox)
        } catch (e: Exception) {
            result.error("INBOX_ERROR", e.message, null)
        }
    }

    private fun sendUnifiedMessage(platform: String, message: String, recipient: String, result: MethodChannel.Result) {
        try {
            when (platform) {
                "google_messages" -> {
                    // Launch Google Messages with intent
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = android.net.Uri.parse("smsto:$recipient")
                        putExtra("sms_body", message)
                        `package` = "com.google.android.apps.messaging"
                    }
                    startActivity(intent)
                }
                "messenger" -> {
                    // Launch Messenger with intent
                    val intent = packageManager.getLaunchIntentForPackage("com.facebook.orca")
                    if (intent != null) {
                        startActivity(intent)
                        // Note: Messenger doesn't support direct message intents easily
                        // Would need accessibility service to automate
                    }
                }
                "open_bubbles" -> {
                    // Launch Open Bubbles or create new bubble
                    val intent = packageManager.getLaunchIntentForPackage("com.txusballesteros.bubbles")
                    if (intent != null) {
                        startActivity(intent)
                    } else {
                        // Create bubble directly using our bubble service
                        showBubble(recipient, message)
                    }
                }
                "whatsapp" -> {
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = android.net.Uri.parse("https://wa.me/$recipient?text=${android.net.Uri.encode(message)}")
                    }
                    startActivity(intent)
                }
                "telegram" -> {
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = android.net.Uri.parse("tg://msg?to=$recipient&text=${android.net.Uri.encode(message)}")
                    }
                    startActivity(intent)
                }
                "sms" -> {
                    // Launch default SMS app (Google Messages)
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = android.net.Uri.parse("smsto:$recipient")
                        putExtra("sms_body", message)
                    }
                    startActivity(intent)
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("SEND_ERROR", e.message, null)
        }
    }

    private fun showBubble(sender: String, message: String) {
        val intent = Intent(this, BubbleOverlayService::class.java).apply {
            action = "SHOW_BUBBLE"
            putExtra("sender", sender)
            putExtra("message", message)
        }
        startService(intent)
    }
}
