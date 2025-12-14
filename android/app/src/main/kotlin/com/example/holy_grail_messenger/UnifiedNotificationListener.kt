package com.example.holy_grail_messenger

import android.app.Notification
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * NotificationListenerService for intercepting notifications from:
 * - Google Messages (com.google.android.apps.messaging)
 * - Facebook Messenger (com.facebook.orca)
 * - Open Bubbles and other messaging platforms
 */
class UnifiedNotificationListener : NotificationListenerService() {
    
    companion object {
        private const val TAG = "UnifiedNotificationListener"
        private const val GOOGLE_MESSAGES_PACKAGE = "com.google.android.apps.messaging"
        private const val FACEBOOK_MESSENGER_PACKAGE = "com.facebook.orca"
        private const val WHATSAPP_PACKAGE = "com.whatsapp"
        private const val TELEGRAM_PACKAGE = "org.telegram.messenger"
        private const val SIGNAL_PACKAGE = "org.thoughtcrime.securesms"
        private const val OPEN_BUBBLES_PACKAGE = "com.txusballesteros.bubbles"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName
        
        when (packageName) {
            GOOGLE_MESSAGES_PACKAGE -> handleGoogleMessagesNotification(sbn)
            FACEBOOK_MESSENGER_PACKAGE -> handleMessengerNotification(sbn)
            WHATSAPP_PACKAGE -> handleWhatsAppNotification(sbn)
            TELEGRAM_PACKAGE -> handleTelegramNotification(sbn)
            SIGNAL_PACKAGE -> handleSignalNotification(sbn)
            OPEN_BUBBLES_PACKAGE -> handleOpenBubblesNotification(sbn)
            else -> return // Ignore other notifications
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Handle notification removal (e.g., message read)
        val packageName = sbn.packageName
        Log.d(TAG, "Notification removed from $packageName")
        
        // Update local cache to mark as read
        val intent = Intent("com.example.holy_grail_messenger.MESSAGE_READ")
        intent.putExtra("package", packageName)
        intent.putExtra("notificationId", sbn.id)
        sendBroadcast(intent)
    }

    private fun handleGoogleMessagesNotification(sbn: StatusBarNotification) {
        val notification = sbn.notification
        val extras = notification.extras
        
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
        
        Log.d(TAG, "Google Messages - Title: $title, Text: $text, SubText: $subText")
        
        // Extract conversation/thread info
        val conversationId = extractConversationId(extras, GOOGLE_MESSAGES_PACKAGE)
        
        // Cache the message
        cacheMessage(
            platform = "google_messages",
            sender = title ?: "Unknown",
            message = text ?: "",
            conversationId = conversationId,
            timestamp = sbn.postTime
        )
        
        // Suppress original notification
        cancelNotification(sbn.key)
    }

    private fun handleMessengerNotification(sbn: StatusBarNotification) {
        val notification = sbn.notification
        val extras = notification.extras
        
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        
        Log.d(TAG, "Messenger - Title: $title, Text: $text")
        
        val conversationId = extractConversationId(extras, FACEBOOK_MESSENGER_PACKAGE)
        
        cacheMessage(
            platform = "messenger",
            sender = title ?: "Unknown",
            message = text ?: "",
            conversationId = conversationId,
            timestamp = sbn.postTime
        )
        
        cancelNotification(sbn.key)
    }

    private fun extractConversationId(extras: Bundle, packageName: String): String {
        // Try to extract conversation/thread ID from notification extras
        return when (packageName) {
            GOOGLE_MESSAGES_PACKAGE -> {
                // Google Messages often includes thread info in extras
                extras.getString("android.conversationId") 
                    ?: extras.getString("thread_id") 
                    ?: "unknown_thread"
            }
            FACEBOOK_MESSENGER_PACKAGE -> {
                // Messenger conversation extraction
                extras.getString("conversation_id") 
                    ?: extras.getString("thread_key") 
                    ?: "unknown_conversation"
            }
            WHATSAPP_PACKAGE -> {
                // WhatsApp conversation extraction
                extras.getString("android.conversationId")
                    ?: extras.getString("chat_id")
                    ?: "unknown_whatsapp"
            }
            TELEGRAM_PACKAGE -> {
                // Telegram conversation extraction
                extras.getString("chat_id")
                    ?: extras.getString("dialog_id")
                    ?: "unknown_telegram"
            }
            SIGNAL_PACKAGE -> {
                // Signal conversation extraction
                extras.getString("thread_id")
                    ?: extras.getString("recipient_id")
                    ?: "unknown_signal"
            }
            OPEN_BUBBLES_PACKAGE -> {
                // Open Bubbles conversation extraction
                extras.getString("bubble_id")
                    ?: extras.getString("conversation_id")
                    ?: "unknown_bubble"
            }
            else -> "unknown"
        }
    }

    private fun handleWhatsAppNotification(sbn: StatusBarNotification) {
        val notification = sbn.notification
        val extras = notification.extras
        
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        
        Log.d(TAG, "WhatsApp - Title: $title, Text: $text")
        
        val conversationId = extractConversationId(extras, WHATSAPP_PACKAGE)
        
        cacheMessage(
            platform = "whatsapp",
            sender = title ?: "Unknown",
            message = text ?: "",
            conversationId = conversationId,
            timestamp = sbn.postTime
        )
        
        cancelNotification(sbn.key)
    }

    private fun handleTelegramNotification(sbn: StatusBarNotification) {
        val notification = sbn.notification
        val extras = notification.extras
        
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        
        Log.d(TAG, "Telegram - Title: $title, Text: $text")
        
        val conversationId = extractConversationId(extras, TELEGRAM_PACKAGE)
        
        cacheMessage(
            platform = "telegram",
            sender = title ?: "Unknown",
            message = text ?: "",
            conversationId = conversationId,
            timestamp = sbn.postTime
        )
        
        cancelNotification(sbn.key)
    }

    private fun handleSignalNotification(sbn: StatusBarNotification) {
        val notification = sbn.notification
        val extras = notification.extras
        
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        
        Log.d(TAG, "Signal - Title: $title, Text: $text")
        
        val conversationId = extractConversationId(extras, SIGNAL_PACKAGE)
        
        cacheMessage(
            platform = "signal",
            sender = title ?: "Unknown",
            message = text ?: "",
            conversationId = conversationId,
            timestamp = sbn.postTime
        )
        
        cancelNotification(sbn.key)
    }

    private fun handleOpenBubblesNotification(sbn: StatusBarNotification) {
        val notification = sbn.notification
        val extras = notification.extras
        
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        
        Log.d(TAG, "Open Bubbles - Title: $title, Text: $text")
        
        val conversationId = extractConversationId(extras, OPEN_BUBBLES_PACKAGE)
        
        cacheMessage(
            platform = "open_bubbles",
            sender = title ?: "Unknown",
            message = text ?: "",
            conversationId = conversationId,
            timestamp = sbn.postTime
        )
        
        // Don't cancel Open Bubbles notifications - let them show as bubbles
    }

    private fun cacheMessage(
        platform: String,
        sender: String,
        message: String,
        conversationId: String,
        timestamp: Long
    ) {
        // Send to MessageCacheService
        val intent = Intent(this, MessageCacheService::class.java).apply {
            action = "CACHE_MESSAGE"
            putExtra("platform", platform)
            putExtra("sender", sender)
            putExtra("message", message)
            putExtra("conversationId", conversationId)
            putExtra("timestamp", timestamp)
        }
        startService(intent)
        
        // Notify Flutter layer
        val flutterIntent = Intent("com.example.holy_grail_messenger.NEW_MESSAGE")
        flutterIntent.putExtra("platform", platform)
        flutterIntent.putExtra("sender", sender)
        flutterIntent.putExtra("message", message)
        flutterIntent.putExtra("conversationId", conversationId)
        sendBroadcast(flutterIntent)
    }
}