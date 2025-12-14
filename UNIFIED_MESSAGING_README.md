# Unified Messaging Architecture Implementation

This implementation provides a unified messaging hub that integrates Google Messages (RCS + SMS), Facebook Messenger, and supports bubble overlays according to your specification.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter UI Layer                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │  Unified Inbox  │  │  Bubble Overlay │  │  Chat View  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                 Native Android Services                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │ Notification     │  │ Accessibility    │  │ Message    │ │
│  │ Listener Service │  │ Service          │  │ Cache      │ │
│  └──────────────────┘  └──────────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│              Native Messaging Apps                          │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │ Google Messages  │  │ Facebook         │  │ Open       │ │
│  │ (RCS/SMS)        │  │ Messenger        │  │ Bubbles    │ │
│  └──────────────────┘  └──────────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. UnifiedNotificationListener
- **Purpose**: Intercepts notifications from Google Messages and Messenger
- **Features**:
  - Extracts sender, message content, conversation IDs
  - Suppresses original notifications
  - Caches messages locally
  - Broadcasts to Flutter layer

### 2. UnifiedAccessibilityService
- **Purpose**: Detects UI changes for typing indicators and read receipts
- **Features**:
  - Monitors text changes in messaging apps
  - Detects typing indicators ("typing...", "is typing")
  - Identifies read receipt states
  - Automates message sending via UI interaction

### 3. MessageCacheService
- **Purpose**: Local message storage and thread management
- **Features**:
  - Unified message cache across platforms
  - Thread/conversation grouping
  - Simulated RCS features (typing, reactions, read receipts)
  - JSON-based persistence

### 4. BubbleOverlayService
- **Purpose**: Floating bubble interface
- **Features**:
  - Draggable message bubbles
  - Expandable chat overlay
  - Quick reply functionality
  - System overlay integration

### 5. Flutter Integration
- **UnifiedMessagingService**: Dart service for native communication
- **UnifiedInbox**: Widget displaying all conversations
- **Platform-specific styling**: Visual indicators for each messaging platform

## Setup Instructions

### 1. Permissions Required
The app needs these permissions to function:

```xml
<!-- Notification interception -->
<uses-permission android:name="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" />

<!-- Bubble overlays -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

<!-- UI automation -->
<uses-permission android:name="android.permission.BIND_ACCESSIBILITY_SERVICE" />

<!-- Background operation -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

### 2. User Setup Process
1. **Notification Access**: Settings → Apps → Special Access → Notification Access → Enable for Tala
2. **Accessibility Service**: Settings → Accessibility → Tala → Enable
3. **Overlay Permission**: Settings → Apps → Tala → Display over other apps → Allow

### 3. Testing the Implementation

#### Test Notification Interception:
1. Send a message to Google Messages
2. Check if notification is suppressed
3. Verify message appears in unified inbox

#### Test Accessibility Features:
1. Open Google Messages
2. Start typing in a conversation
3. Check if typing indicator is detected

#### Test Bubble Overlay:
1. Receive a message
2. Tap "Show as Bubble" in unified inbox
3. Verify draggable bubble appears

## Simulated RCS Features

### Typing Indicators
- **Detection**: Monitors UI text changes and "typing" indicators
- **Simulation**: Shows typing status in unified inbox
- **Cross-platform**: Works with both Google Messages and Messenger

### Read Receipts
- **Detection**: Identifies read status changes via accessibility events
- **Simulation**: Updates message status in local cache
- **Visual**: Shows read/delivered indicators in UI

### Reactions
- **Storage**: Local cache supports emoji reactions
- **UI**: Displays reactions in conversation view
- **Simulation**: Client-side only, doesn't send to network

## Platform-Specific Handling

### Google Messages
- **Package**: `com.google.android.apps.messaging`
- **Notification extraction**: Title, text, conversation ID
- **Accessibility**: Detects compose field, send button
- **Intent sending**: Uses SMS intents for message sending

### Facebook Messenger
- **Package**: `com.facebook.orca`
- **Notification extraction**: Sender, message content
- **Accessibility**: Monitors typing indicators
- **Sending**: Launches app, uses accessibility automation

### SMS Fallback
- **Direct SMS**: Uses existing SMS functionality
- **Integration**: Appears alongside other platforms in unified view

## Security & Privacy

### Data Handling
- **Local only**: All message caching is local to device
- **No network**: Simulated features don't send network requests
- **Encryption**: Consider encrypting local cache file

### Permissions
- **Minimal scope**: Only monitors specified messaging apps
- **User control**: All permissions require explicit user consent
- **Transparency**: Clear explanation of what each permission does

## Extensibility Hooks

### Adding New Platforms
1. Add package name to accessibility service config
2. Implement platform-specific notification parsing
3. Add UI automation for message sending
4. Update Flutter UI with platform styling

### Auto-Reply System
```kotlin
// Hook in MessageCacheService
private fun processIncomingMessage(message: CachedMessage) {
    if (shouldAutoReply(message)) {
        val reply = generateAutoReply(message)
        sendAutoReply(message.platform, reply, message.sender)
    }
}
```

### Smart Reactions
```kotlin
// Hook in UnifiedAccessibilityService
private fun suggestReaction(message: String): String {
    // AI/ML-based reaction suggestion
    return when {
        message.contains("thanks") -> "👍"
        message.contains("funny") -> "😂"
        else -> "❤️"
    }
}
```

## Troubleshooting

### Common Issues

1. **Notifications not intercepted**
   - Check notification listener permission
   - Verify app is enabled in notification access settings
   - Restart notification listener service

2. **Accessibility not working**
   - Enable accessibility service in settings
   - Check if target apps are installed
   - Verify accessibility service is running

3. **Bubbles not showing**
   - Enable overlay permission
   - Check if battery optimization is disabled
   - Verify BubbleOverlayService is running

### Debug Commands
```bash
# Check if services are running
adb shell dumpsys activity services | grep holy_grail_messenger

# Monitor accessibility events
adb shell settings put secure enabled_accessibility_services com.example.holy_grail_messenger/.UnifiedAccessibilityService

# Check notification listener
adb shell cmd notification allow_listener com.example.holy_grail_messenger/com.example.holy_grail_messenger.UnifiedNotificationListener
```

## Future Enhancements

1. **AI Integration**: Smart replies, message categorization
2. **Cross-device sync**: Sync unified inbox across devices
3. **Advanced automation**: Scheduled messages, auto-responses
4. **Analytics**: Message patterns, response times
5. **Backup/restore**: Export/import unified message history

## Compliance Notes

- **No APK modification**: Works with unmodified messaging apps
- **No protocol bypass**: Doesn't interfere with RCS/Messenger protocols
- **Client-side simulation**: All enhanced features are local only
- **User consent**: All permissions require explicit user approval