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
                    checkRcsAccess(result)
                }
                "sendSms" -> {
                    val address = call.argument<String>("address")
                    val body = call.argument<String>("body")
                    if (address != null && body != null) {
                        sendSms(address, body, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Address or body missing", null)
                    }
                }
                "deleteConversation" -> {
                    val threadId = call.argument<String>("threadId")
                    if (threadId != null) {
                        deleteConversation(threadId, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "threadId is null", null)
                    }
                }
                "markAsRead" -> {
                    val threadId = call.argument<String>("threadId")
                    if (threadId != null) {
                        markAsRead(threadId, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "threadId is null", null)
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
                "debugRcsMethods" -> {
                    debugRcsMethods(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkRcsAccess(result: MethodChannel.Result) {
        val debugInfo = StringBuilder()
        try {
            // 1. Try Public API (Android R+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    val imsManager = context.getSystemService(Context.TELEPHONY_IMS_SERVICE)
                    if (imsManager != null) {
                        result.success("Success: Got ImsManager via getSystemService!")
                        return
                    }
                } catch (e: Exception) {
                    debugInfo.append("getSystemService failed: ${e.message}\n")
                }
            }

            // 2. Try Reflection on android.telephony.ims.ImsManager
            try {
                val className = "android.telephony.ims.ImsManager"
                val imsManagerClass = Class.forName(className)
                
                // Try getInstance(Context) - sometimes used
                try {
                    val getInstance = imsManagerClass.getDeclaredMethod("getInstance", Context::class.java)
                    val instance = getInstance.invoke(null, context)
                    result.success("Success: Got ImsManager via getInstance(Context)!")
                    return
                } catch (e: Exception) { debugInfo.append("getInstance(Context) failed\n") }

                // Try getInstance(Context, int)
                try {
                    val subId = android.telephony.SubscriptionManager.getDefaultSmsSubscriptionId()
                    val getInstance = imsManagerClass.getDeclaredMethod("getInstance", Context::class.java, Int::class.javaPrimitiveType)
                    val instance = getInstance.invoke(null, context, subId)
                    result.success("Success: Got ImsManager via getInstance(Context, int)!")
                    return
                } catch (e: Exception) { debugInfo.append("getInstance(Context, int) failed\n") }

            } catch (e: Exception) {
                debugInfo.append("Reflection failed: ${e.message}\n")
            }

            result.success("Failed. Debug Info:\n$debugInfo")
        } catch (e: Exception) {
            Log.e("RCS_CRACK", "Critical Failure", e)
            result.error("RCS_ERROR", "Critical Error: ${e.message}", null)
        }
    }

    private fun sendSms(address: String, body: String, result: MethodChannel.Result) {
        try {
            val smsManager = android.telephony.SmsManager.getDefault()
            smsManager.sendTextMessage(address, null, body, null, null)
            result.success(null)
        } catch (e: Exception) {
            result.error("SEND_SMS_ERROR", e.message, null)
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
            val statusIdx = cursor.getColumnIndex(Telephony.Sms.STATUS)

            while (cursor.moveToNext()) {
                messages.add(mapOf(
                    "id" to cursor.getString(idIdx),
                    "body" to cursor.getString(bodyIdx),
                    "date" to cursor.getLong(dateIdx),
                    "isMe" to (cursor.getInt(typeIdx) == Telephony.Sms.MESSAGE_TYPE_SENT),
                    "status" to cursor.getInt(statusIdx)
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
    private fun deleteConversation(threadId: String, result: MethodChannel.Result) {
        try {
            val uri = Telephony.Sms.CONTENT_URI
            val selection = "${Telephony.Sms.THREAD_ID} = ?"
            val selectionArgs = arrayOf(threadId)
            contentResolver.delete(uri, selection, selectionArgs)
            result.success(null)
        } catch (e: Exception) {
            result.error("DELETE_ERROR", e.message, null)
        }
    }

    private fun markAsRead(threadId: String, result: MethodChannel.Result) {
        try {
            val uri = Telephony.Sms.CONTENT_URI
            val values = android.content.ContentValues()
            values.put(Telephony.Sms.READ, 1)
            val selection = "${Telephony.Sms.THREAD_ID} = ? AND ${Telephony.Sms.READ} = 0"
            val selectionArgs = arrayOf(threadId)
            contentResolver.update(uri, values, selection, selectionArgs)
            result.success(null)
        } catch (e: Exception) {
            result.error("MARK_READ_ERROR", e.message, null)
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

    private fun debugRcsMethods(result: MethodChannel.Result) {
        val debugInfo = StringBuilder()
        try {
            val classesToCheck = listOf(
                "android.telephony.ims.ImsRcsManager",
                "android.telephony.ims.RcsMessageStore",
                "android.telephony.ims.RcsControllerCall",
                "com.android.internal.telephony.ims.RcsMessageStoreController"
            )

            for (className in classesToCheck) {
                try {
                    debugInfo.append("\n--- Class: $className ---\n")
                    val clazz = Class.forName(className)
                    val methods = clazz.declaredMethods
                    for (method in methods) {
                        debugInfo.append("Method: ${method.name}(")
                        val params = method.parameterTypes
                        for (p in params) {
                            debugInfo.append("${p.simpleName}, ")
                        }
                        debugInfo.append(")\n")
                    }
                } catch (e: ClassNotFoundException) {
                    debugInfo.append("Class not found: $className\n")
                }
            }
            result.success(debugInfo.toString())
        } catch (e: Exception) {
            result.error("DEBUG_ERROR", e.message, null)
        }
    }
}
