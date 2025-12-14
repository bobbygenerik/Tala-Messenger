package com.example.holy_grail_messenger

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.*
import android.widget.*
import androidx.core.content.ContextCompat

/**
 * Service for displaying bubble overlay UI
 * Provides floating chat bubbles and conversation interface
 */
class BubbleOverlayService : Service() {
    
    companion object {
        private const val TAG = "BubbleOverlayService"
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: View? = null
    private var chatOverlayView: View? = null
    private var isChatVisible = false

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        Log.d(TAG, "BubbleOverlayService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "SHOW_BUBBLE" -> {
                val sender = intent.getStringExtra("sender") ?: "Unknown"
                val message = intent.getStringExtra("message") ?: ""
                showBubble(sender, message)
            }
            "HIDE_BUBBLE" -> hideBubble()
            "SHOW_CHAT" -> {
                val threadKey = intent.getStringExtra("threadKey") ?: ""
                showChatOverlay(threadKey)
            }
            "HIDE_CHAT" -> hideChatOverlay()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun showBubble(sender: String, message: String) {
        if (bubbleView != null) return // Already showing

        bubbleView = createBubbleView(sender, message)
        
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 20
            y = 100
        }

        try {
            windowManager?.addView(bubbleView, params)
            Log.d(TAG, "Bubble shown for $sender")
        } catch (e: Exception) {
            Log.e(TAG, "Error showing bubble", e)
        }
    }

    private fun createBubbleView(sender: String, message: String): View {
        val bubbleLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(16, 16, 16, 16)
            background = ContextCompat.getDrawable(this@BubbleOverlayService, android.R.drawable.dialog_holo_light_frame)
        }

        val senderText = TextView(this).apply {
            text = sender
            textSize = 14f
            setTextColor(android.graphics.Color.BLACK)
        }

        val messageText = TextView(this).apply {
            text = if (message.length > 50) message.take(47) + "..." else message
            textSize = 12f
            setTextColor(android.graphics.Color.GRAY)
        }

        val buttonLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }

        val replyButton = Button(this).apply {
            text = "Reply"
            textSize = 10f
            setOnClickListener {
                // Show chat overlay
                val intent = Intent(this@BubbleOverlayService, BubbleOverlayService::class.java).apply {
                    action = "SHOW_CHAT"
                    putExtra("threadKey", "${sender}_conversation")
                }
                startService(intent)
            }
        }

        val dismissButton = Button(this).apply {
            text = "×"
            textSize = 12f
            setOnClickListener {
                hideBubble()
            }
        }

        buttonLayout.addView(replyButton)
        buttonLayout.addView(dismissButton)

        bubbleLayout.addView(senderText)
        bubbleLayout.addView(messageText)
        bubbleLayout.addView(buttonLayout)

        // Make draggable
        makeDraggable(bubbleLayout)

        return bubbleLayout
    }

    private fun makeDraggable(view: View) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    val params = view.layoutParams as WindowManager.LayoutParams
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val params = view.layoutParams as WindowManager.LayoutParams
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager?.updateViewLayout(view, params)
                    true
                }
                else -> false
            }
        }
    }

    private fun showChatOverlay(threadKey: String) {
        if (isChatVisible) return

        chatOverlayView = createChatOverlayView(threadKey)
        
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            (windowManager?.defaultDisplay?.width?.times(0.9))?.toInt() ?: 800,
            (windowManager?.defaultDisplay?.height?.times(0.7))?.toInt() ?: 600,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        try {
            windowManager?.addView(chatOverlayView, params)
            isChatVisible = true
            hideBubble() // Hide bubble when chat is open
            Log.d(TAG, "Chat overlay shown for $threadKey")
        } catch (e: Exception) {
            Log.e(TAG, "Error showing chat overlay", e)
        }
    }

    private fun createChatOverlayView(threadKey: String): View {
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = ContextCompat.getDrawable(this@BubbleOverlayService, android.R.drawable.dialog_holo_light_frame)
            setPadding(16, 16, 16, 16)
        }

        // Header
        val headerLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val titleText = TextView(this).apply {
            text = "Unified Chat - $threadKey"
            textSize = 16f
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
            setTextColor(android.graphics.Color.BLACK)
        }

        val closeButton = Button(this).apply {
            text = "×"
            textSize = 16f
            setOnClickListener { hideChatOverlay() }
        }

        headerLayout.addView(titleText)
        headerLayout.addView(closeButton)

        // Messages area (ScrollView with ListView)
        val messagesScrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        val messagesLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        // Add sample messages (in real implementation, load from cache)
        addSampleMessages(messagesLayout)

        messagesScrollView.addView(messagesLayout)

        // Input area
        val inputLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val messageInput = EditText(this).apply {
            hint = "Type a message..."
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }

        val sendButton = Button(this).apply {
            text = "Send"
            setOnClickListener {
                val message = messageInput.text.toString()
                if (message.isNotBlank()) {
                    sendUnifiedMessage(threadKey, message)
                    messageInput.text.clear()
                }
            }
        }

        inputLayout.addView(messageInput)
        inputLayout.addView(sendButton)

        mainLayout.addView(headerLayout)
        mainLayout.addView(messagesScrollView)
        mainLayout.addView(inputLayout)

        return mainLayout
    }

    private fun addSampleMessages(layout: LinearLayout) {
        // Sample messages - in real implementation, load from MessageCacheService
        val messages = listOf(
            "Hello there!" to false,
            "Hi! How are you?" to true,
            "I'm doing great, thanks!" to false
        )

        messages.forEach { (text, isMe) ->
            val messageView = TextView(this).apply {
                this.text = text
                textSize = 14f
                setPadding(12, 8, 12, 8)
                
                if (isMe) {
                    gravity = Gravity.END
                    background = ContextCompat.getDrawable(this@BubbleOverlayService, android.R.drawable.btn_default)
                    setTextColor(android.graphics.Color.WHITE)
                } else {
                    gravity = Gravity.START
                    background = ContextCompat.getDrawable(this@BubbleOverlayService, android.R.drawable.editbox_background)
                    setTextColor(android.graphics.Color.BLACK)
                }
            }
            
            val params = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            params.setMargins(8, 8, 8, 8)
            messageView.layoutParams = params
            
            layout.addView(messageView)
        }
    }

    private fun sendUnifiedMessage(threadKey: String, message: String) {
        // Determine platform from threadKey and send via appropriate method
        val platform = when {
            threadKey.contains("google_messages") -> "google_messages"
            threadKey.contains("messenger") -> "messenger"
            else -> "sms" // Default to SMS
        }

        // Send via accessibility service or intent
        val intent = Intent("com.example.holy_grail_messenger.SEND_MESSAGE")
        intent.putExtra("platform", platform)
        intent.putExtra("message", message)
        intent.putExtra("threadKey", threadKey)
        sendBroadcast(intent)

        Log.d(TAG, "Sent unified message: $platform - $message")
    }

    private fun hideBubble() {
        bubbleView?.let {
            try {
                windowManager?.removeView(it)
                bubbleView = null
                Log.d(TAG, "Bubble hidden")
            } catch (e: Exception) {
                Log.e(TAG, "Error hiding bubble", e)
            }
        }
    }

    private fun hideChatOverlay() {
        chatOverlayView?.let {
            try {
                windowManager?.removeView(it)
                chatOverlayView = null
                isChatVisible = false
                Log.d(TAG, "Chat overlay hidden")
            } catch (e: Exception) {
                Log.e(TAG, "Error hiding chat overlay", e)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        hideBubble()
        hideChatOverlay()
    }
}