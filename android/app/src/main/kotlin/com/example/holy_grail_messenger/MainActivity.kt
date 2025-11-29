package com.example.holy_grail_messenger

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.holy_grail_messenger/sms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Attempt to bypass hidden API restrictions
        HiddenApiBypass.bypass()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestDefaultSms" -> {
                    requestDefaultSms()
                    result.success(null)
                }
                "isDefaultSms" -> {
                    result.success(isDefaultSms())
                }
                "getConversations" -> {
                    result.success(getConversations())
                }
                "getMessages" -> {
                    val threadId = call.argument<String>("threadId")
                    if (threadId != null) {
                        result.success(getMessages(threadId))
                    } else {
                        result.error("INVALID_ARGUMENT", "threadId is null", null)
                    }
                }
                "checkRcsAccess" -> {
                    result.success(checkRcsAccess())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkRcsAccess(): Boolean {
        try {
            // Try to get the ImsManager class
            val imsManagerClass = Class.forName("android.telephony.ims.ImsManager")
            Log.d("RCS_CRACK", "Found ImsManager class: $imsManagerClass")
            
            // Note: Instantiating it usually requires a context or subscription ID.
            // This is just a probe to see if the class is visible after bypass.
            return true
        } catch (e: Exception) {
            Log.e("RCS_CRACK", "Failed to access ImsManager", e)
            return false
        }
    }

    private fun getConversations(): List<Map<String, Any>> {
        val conversations = mutableListOf<Map<String, Any>>()
        
        // Query the SMS inbox directly to get address and body, grouped by thread_id
        val inboxUri = Telephony.Sms.Inbox.CONTENT_URI
        val inboxProjection = arrayOf(
            Telephony.Sms.THREAD_ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE
        )
        val sortOrder = "${Telephony.Sms.DATE} DESC"
        
        // We'll use a set to keep track of unique threads we've added
        val seenThreads = mutableSetOf<String>()

        contentResolver.query(inboxUri, inboxProjection, null, null, sortOrder)?.use { cursor ->
            val threadIdIdx = cursor.getColumnIndex(Telephony.Sms.THREAD_ID)
            val addressIdx = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIdx = cursor.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = cursor.getColumnIndex(Telephony.Sms.DATE)

            while (cursor.moveToNext()) {
                val threadId = cursor.getString(threadIdIdx)
                if (threadId != null && !seenThreads.contains(threadId)) {
                    val address = cursor.getString(addressIdx) ?: "Unknown"
                    val body = cursor.getString(bodyIdx) ?: ""
                    val date = cursor.getLong(dateIdx)
                    
                    conversations.add(mapOf(
                        "threadId" to threadId,
                        "address" to address,
                        "snippet" to body,
                        "date" to date
                    ))
                    seenThreads.add(threadId)
                }
            }
        }
        return conversations
    }

    private fun getMessages(threadId: String): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        val uri = Telephony.Sms.CONTENT_URI
        val selection = "${Telephony.Sms.THREAD_ID} = ?"
        val selectionArgs = arrayOf(threadId)
        val sortOrder = "${Telephony.Sms.DATE} ASC"

        contentResolver.query(uri, null, selection, selectionArgs, sortOrder)?.use { cursor ->
            val idIdx = cursor.getColumnIndex(Telephony.Sms._ID)
            val bodyIdx = cursor.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = cursor.getColumnIndex(Telephony.Sms.DATE)
            val typeIdx = cursor.getColumnIndex(Telephony.Sms.TYPE)

            while (cursor.moveToNext()) {
                messages.add(mapOf(
                    "id" to cursor.getString(idIdx),
                    "body" to cursor.getString(bodyIdx),
                    "date" to cursor.getLong(dateIdx),
                    "isMe" to (cursor.getInt(typeIdx) == Telephony.Sms.MESSAGE_TYPE_SENT)
                ))
            }
        }
        return messages
    }

    private fun isDefaultSms(): Boolean {
        return Telephony.Sms.getDefaultSmsPackage(context) == context.packageName
    }

    private fun requestDefaultSms() {
        if (!isDefaultSms()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(RoleManager::class.java)
                if (roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
                    val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
                    startActivityForResult(intent, 1)
                }
            } else {
                val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, context.packageName)
                startActivity(intent)
            }
        }
    }
}
