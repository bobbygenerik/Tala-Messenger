package com.example.holy_grail_messenger

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * AccessibilityService for detecting:
 * - Typing indicators in messaging apps
 * - Read receipts and message status changes
 * - UI state changes for simulated RCS features
 */
class UnifiedAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "UnifiedAccessibilityService"
        private const val GOOGLE_MESSAGES_PACKAGE = "com.google.android.apps.messaging"
        private const val FACEBOOK_MESSENGER_PACKAGE = "com.facebook.orca"
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        
        when (packageName) {
            GOOGLE_MESSAGES_PACKAGE -> handleGoogleMessagesEvent(event)
            FACEBOOK_MESSENGER_PACKAGE -> handleMessengerEvent(event)
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }

    private fun handleGoogleMessagesEvent(event: AccessibilityEvent) {
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                detectTypingIndicator(event, "google_messages")
                detectReadReceipts(event, "google_messages")
            }
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                // User is typing - simulate typing indicator for others
                broadcastTypingStatus("google_messages", true)
            }
        }
    }

    private fun handleMessengerEvent(event: AccessibilityEvent) {
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                detectTypingIndicator(event, "messenger")
                detectReadReceipts(event, "messenger")
            }
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> {
                broadcastTypingStatus("messenger", true)
            }
        }
    }

    private fun detectTypingIndicator(event: AccessibilityEvent, platform: String) {
        val rootNode = rootInActiveWindow ?: return
        
        // Look for typing indicator text patterns
        val typingIndicators = when (platform) {
            "google_messages" -> listOf("typing", "is typing", "...")
            "messenger" -> listOf("typing", "is typing", "...")
            else -> emptyList()
        }
        
        val isTyping = findTextInNode(rootNode, typingIndicators)
        if (isTyping) {
            broadcastTypingStatus(platform, true, extractSenderFromTyping(rootNode))
        }
    }

    private fun detectReadReceipts(event: AccessibilityEvent, platform: String) {
        val rootNode = rootInActiveWindow ?: return
        
        // Look for read receipt indicators
        val readIndicators = when (platform) {
            "google_messages" -> listOf("Read", "Delivered", "Seen")
            "messenger" -> listOf("Seen", "Delivered")
            else -> emptyList()
        }
        
        val hasReadReceipt = findTextInNode(rootNode, readIndicators)
        if (hasReadReceipt) {
            broadcastReadReceipt(platform)
        }
    }

    private fun findTextInNode(node: AccessibilityNodeInfo?, searchTexts: List<String>): Boolean {
        if (node == null) return false
        
        val nodeText = node.text?.toString()?.lowercase()
        if (nodeText != null) {
            for (searchText in searchTexts) {
                if (nodeText.contains(searchText.lowercase())) {
                    return true
                }
            }
        }
        
        // Recursively search child nodes
        for (i in 0 until node.childCount) {
            if (findTextInNode(node.getChild(i), searchTexts)) {
                return true
            }
        }
        
        return false
    }

    private fun extractSenderFromTyping(rootNode: AccessibilityNodeInfo): String {
        // Try to extract who is typing from the UI
        // This is platform-specific and may need refinement
        return "Unknown"
    }

    private fun broadcastTypingStatus(platform: String, isTyping: Boolean, sender: String = "Unknown") {
        val intent = Intent("com.example.holy_grail_messenger.TYPING_STATUS")
        intent.putExtra("platform", platform)
        intent.putExtra("isTyping", isTyping)
        intent.putExtra("sender", sender)
        sendBroadcast(intent)
        
        Log.d(TAG, "Typing status: $platform - $sender is typing: $isTyping")
    }

    private fun broadcastReadReceipt(platform: String) {
        val intent = Intent("com.example.holy_grail_messenger.READ_RECEIPT")
        intent.putExtra("platform", platform)
        intent.putExtra("timestamp", System.currentTimeMillis())
        sendBroadcast(intent)
        
        Log.d(TAG, "Read receipt detected: $platform")
    }

    /**
     * Send message via accessibility automation
     * This is used when the unified UI needs to send messages through native apps
     */
    fun sendMessageViaAccessibility(platform: String, message: String, recipient: String): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        
        return when (platform) {
            "google_messages" -> sendGoogleMessage(rootNode, message, recipient)
            "messenger" -> sendMessengerMessage(rootNode, message, recipient)
            else -> false
        }
    }

    private fun sendGoogleMessage(rootNode: AccessibilityNodeInfo, message: String, recipient: String): Boolean {
        // Find compose text field and send button
        // This requires careful UI analysis of Google Messages
        val composeField = findNodeByText(rootNode, "Text message") 
            ?: findNodeByClassName(rootNode, "android.widget.EditText")
        
        if (composeField != null) {
            // Set text and trigger send
            val arguments = android.os.Bundle()
            arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, message)
            composeField.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            
            // Find and click send button
            val sendButton = findNodeByText(rootNode, "Send") 
                ?: findNodeByContentDescription(rootNode, "Send")
            
            return sendButton?.performAction(AccessibilityNodeInfo.ACTION_CLICK) == true
        }
        
        return false
    }

    private fun sendMessengerMessage(rootNode: AccessibilityNodeInfo, message: String, recipient: String): Boolean {
        // Similar implementation for Messenger
        val composeField = findNodeByClassName(rootNode, "android.widget.EditText")
        
        if (composeField != null) {
            val arguments = android.os.Bundle()
            arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, message)
            composeField.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
            
            val sendButton = findNodeByContentDescription(rootNode, "Send")
            return sendButton?.performAction(AccessibilityNodeInfo.ACTION_CLICK) == true
        }
        
        return false
    }

    private fun findNodeByText(node: AccessibilityNodeInfo?, text: String): AccessibilityNodeInfo? {
        if (node == null) return null
        
        if (node.text?.toString()?.contains(text, ignoreCase = true) == true) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val result = findNodeByText(node.getChild(i), text)
            if (result != null) return result
        }
        
        return null
    }

    private fun findNodeByClassName(node: AccessibilityNodeInfo?, className: String): AccessibilityNodeInfo? {
        if (node == null) return null
        
        if (node.className?.toString() == className) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val result = findNodeByClassName(node.getChild(i), className)
            if (result != null) return result
        }
        
        return null
    }

    private fun findNodeByContentDescription(node: AccessibilityNodeInfo?, description: String): AccessibilityNodeInfo? {
        if (node == null) return null
        
        if (node.contentDescription?.toString()?.contains(description, ignoreCase = true) == true) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val result = findNodeByContentDescription(node.getChild(i), description)
            if (result != null) return result
        }
        
        return null
    }
}