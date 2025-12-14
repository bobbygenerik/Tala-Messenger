package com.example.holy_grail_messenger

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Service for maintaining local message cache across platforms
 * Handles message storage, thread management, and RCS state simulation
 */
class MessageCacheService : Service() {
    
    companion object {
        private const val TAG = "MessageCacheService"
        private const val CACHE_FILE = "unified_messages.json"
    }

    private lateinit var cacheFile: File
    private val messageCache = mutableMapOf<String, MutableList<CachedMessage>>()
    private val typingStates = mutableMapOf<String, TypingState>()
    private val readStates = mutableMapOf<String, MutableMap<String, Long>>()

    data class CachedMessage(
        val id: String,
        val platform: String,
        val sender: String,
        val message: String,
        val conversationId: String,
        val timestamp: Long,
        var isRead: Boolean = false,
        var reactions: MutableList<Reaction> = mutableListOf()
    )

    data class TypingState(
        val platform: String,
        val conversationId: String,
        val sender: String,
        val isTyping: Boolean,
        val timestamp: Long
    )

    data class Reaction(
        val emoji: String,
        val sender: String,
        val timestamp: Long
    )

    override fun onCreate() {
        super.onCreate()
        cacheFile = File(filesDir, CACHE_FILE)
        loadCache()
        Log.d(TAG, "MessageCacheService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let { handleIntent(it) }
        return START_STICKY // Keep service running
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            "CACHE_MESSAGE" -> {
                val platform = intent.getStringExtra("platform") ?: return
                val sender = intent.getStringExtra("sender") ?: return
                val message = intent.getStringExtra("message") ?: return
                val conversationId = intent.getStringExtra("conversationId") ?: return
                val timestamp = intent.getLongExtra("timestamp", System.currentTimeMillis())
                
                cacheMessage(platform, sender, message, conversationId, timestamp)
            }
            "MARK_READ" -> {
                val platform = intent.getStringExtra("platform") ?: return
                val conversationId = intent.getStringExtra("conversationId") ?: return
                markConversationRead(platform, conversationId)
            }
            "ADD_REACTION" -> {
                val messageId = intent.getStringExtra("messageId") ?: return
                val emoji = intent.getStringExtra("emoji") ?: return
                val sender = intent.getStringExtra("sender") ?: return
                addReaction(messageId, emoji, sender)
            }
            "UPDATE_TYPING" -> {
                val platform = intent.getStringExtra("platform") ?: return
                val conversationId = intent.getStringExtra("conversationId") ?: return
                val sender = intent.getStringExtra("sender") ?: return
                val isTyping = intent.getBooleanExtra("isTyping", false)
                updateTypingState(platform, conversationId, sender, isTyping)
            }
        }
    }

    private fun cacheMessage(platform: String, sender: String, message: String, conversationId: String, timestamp: Long) {
        val messageId = "${platform}_${conversationId}_${timestamp}"
        val cachedMessage = CachedMessage(
            id = messageId,
            platform = platform,
            sender = sender,
            message = message,
            conversationId = conversationId,
            timestamp = timestamp
        )

        val threadKey = "${platform}_${conversationId}"
        if (!messageCache.containsKey(threadKey)) {
            messageCache[threadKey] = mutableListOf()
        }
        
        messageCache[threadKey]?.add(cachedMessage)
        saveCache()
        
        Log.d(TAG, "Cached message: $platform - $sender: $message")
        
        // Notify unified inbox
        broadcastCacheUpdate(threadKey, cachedMessage)
    }

    private fun markConversationRead(platform: String, conversationId: String) {
        val threadKey = "${platform}_${conversationId}"
        messageCache[threadKey]?.forEach { message ->
            message.isRead = true
        }
        
        // Update read state tracking
        if (!readStates.containsKey(threadKey)) {
            readStates[threadKey] = mutableMapOf()
        }
        readStates[threadKey]?.put("last_read", System.currentTimeMillis())
        
        saveCache()
        Log.d(TAG, "Marked conversation as read: $threadKey")
    }

    private fun addReaction(messageId: String, emoji: String, sender: String) {
        // Find message across all threads
        for (thread in messageCache.values) {
            val message = thread.find { it.id == messageId }
            if (message != null) {
                // Remove existing reaction from same sender
                message.reactions.removeAll { it.sender == sender }
                // Add new reaction
                message.reactions.add(Reaction(emoji, sender, System.currentTimeMillis()))
                saveCache()
                Log.d(TAG, "Added reaction $emoji to message $messageId")
                return
            }
        }
    }

    private fun updateTypingState(platform: String, conversationId: String, sender: String, isTyping: Boolean) {
        val threadKey = "${platform}_${conversationId}"
        
        if (isTyping) {
            typingStates[threadKey] = TypingState(platform, conversationId, sender, true, System.currentTimeMillis())
        } else {
            typingStates.remove(threadKey)
        }
        
        // Broadcast typing state to UI
        val intent = Intent("com.example.holy_grail_messenger.TYPING_UPDATE")
        intent.putExtra("threadKey", threadKey)
        intent.putExtra("sender", sender)
        intent.putExtra("isTyping", isTyping)
        sendBroadcast(intent)
        
        Log.d(TAG, "Updated typing state: $threadKey - $sender typing: $isTyping")
    }

    private fun loadCache() {
        if (!cacheFile.exists()) return
        
        try {
            val jsonString = cacheFile.readText()
            val jsonObject = JSONObject(jsonString)
            
            // Load messages
            val messagesJson = jsonObject.optJSONObject("messages")
            messagesJson?.keys()?.forEach { threadKey ->
                val threadArray = messagesJson.getJSONArray(threadKey)
                val messages = mutableListOf<CachedMessage>()
                
                for (i in 0 until threadArray.length()) {
                    val messageJson = threadArray.getJSONObject(i)
                    val reactions = mutableListOf<Reaction>()
                    
                    val reactionsArray = messageJson.optJSONArray("reactions")
                    if (reactionsArray != null) {
                        for (j in 0 until reactionsArray.length()) {
                            val reactionJson = reactionsArray.getJSONObject(j)
                            reactions.add(Reaction(
                                reactionJson.getString("emoji"),
                                reactionJson.getString("sender"),
                                reactionJson.getLong("timestamp")
                            ))
                        }
                    }
                    
                    messages.add(CachedMessage(
                        id = messageJson.getString("id"),
                        platform = messageJson.getString("platform"),
                        sender = messageJson.getString("sender"),
                        message = messageJson.getString("message"),
                        conversationId = messageJson.getString("conversationId"),
                        timestamp = messageJson.getLong("timestamp"),
                        isRead = messageJson.optBoolean("isRead", false),
                        reactions = reactions
                    ))
                }
                
                messageCache[threadKey] = messages
            }
            
            Log.d(TAG, "Loaded ${messageCache.size} conversation threads from cache")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading cache", e)
        }
    }

    private fun saveCache() {
        try {
            val jsonObject = JSONObject()
            val messagesJson = JSONObject()
            
            messageCache.forEach { (threadKey, messages) ->
                val threadArray = JSONArray()
                messages.forEach { message ->
                    val messageJson = JSONObject().apply {
                        put("id", message.id)
                        put("platform", message.platform)
                        put("sender", message.sender)
                        put("message", message.message)
                        put("conversationId", message.conversationId)
                        put("timestamp", message.timestamp)
                        put("isRead", message.isRead)
                        
                        val reactionsArray = JSONArray()
                        message.reactions.forEach { reaction ->
                            val reactionJson = JSONObject().apply {
                                put("emoji", reaction.emoji)
                                put("sender", reaction.sender)
                                put("timestamp", reaction.timestamp)
                            }
                            reactionsArray.put(reactionJson)
                        }
                        put("reactions", reactionsArray)
                    }
                    threadArray.put(messageJson)
                }
                messagesJson.put(threadKey, threadArray)
            }
            
            jsonObject.put("messages", messagesJson)
            cacheFile.writeText(jsonObject.toString())
            
        } catch (e: Exception) {
            Log.e(TAG, "Error saving cache", e)
        }
    }

    private fun broadcastCacheUpdate(threadKey: String, message: CachedMessage) {
        val intent = Intent("com.example.holy_grail_messenger.CACHE_UPDATE")
        intent.putExtra("threadKey", threadKey)
        intent.putExtra("messageId", message.id)
        intent.putExtra("platform", message.platform)
        intent.putExtra("sender", message.sender)
        intent.putExtra("message", message.message)
        intent.putExtra("timestamp", message.timestamp)
        sendBroadcast(intent)
    }

    /**
     * Get unified inbox data for Flutter layer
     */
    fun getUnifiedInbox(): List<Map<String, Any>> {
        val inbox = mutableListOf<Map<String, Any>>()
        
        messageCache.forEach { (threadKey, messages) ->
            if (messages.isNotEmpty()) {
                val lastMessage = messages.maxByOrNull { it.timestamp }
                val unreadCount = messages.count { !it.isRead }
                
                inbox.add(mapOf<String, Any>(
                    "threadKey" to threadKey,
                    "platform" to (lastMessage?.platform ?: ""),
                    "sender" to (lastMessage?.sender ?: ""),
                    "lastMessage" to (lastMessage?.message ?: ""),
                    "timestamp" to (lastMessage?.timestamp ?: 0L),
                    "unreadCount" to unreadCount,
                    "isTyping" to (typingStates[threadKey]?.isTyping ?: false)
                ))
            }
        }
        
        return inbox.sortedByDescending { it["timestamp"] as? Long ?: 0 }
    }
}