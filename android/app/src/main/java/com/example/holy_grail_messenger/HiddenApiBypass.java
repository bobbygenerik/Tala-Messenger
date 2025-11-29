package com.example.holy_grail_messenger;

import android.os.Build;
import android.util.Log;
import java.lang.reflect.Method;

public class HiddenApiBypass {
    private static final String TAG = "HiddenApiBypass";

    public static void bypass() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return;
        }

        try {
            Method forName = Class.class.getDeclaredMethod("forName", String.class);
            Method getDeclaredMethod = Class.class.getDeclaredMethod("getDeclaredMethod", String.class, Class[].class);

            Class<?> vmRuntimeClass = (Class<?>) forName.invoke(null, "dalvik.system.VMRuntime");
            Method getRuntime = (Method) getDeclaredMethod.invoke(vmRuntimeClass, "getRuntime", null);
            Method setHiddenApiExemptions = (Method) getDeclaredMethod.invoke(vmRuntimeClass, "setHiddenApiExemptions", new Class[]{String[].class});

            Object vmRuntime = getRuntime.invoke(null);
            setHiddenApiExemptions.invoke(vmRuntime, new Object[]{new String[]{"L"}});
            
            Log.d(TAG, "Hidden API restrictions bypassed successfully.");
        } catch (Exception e) {
            Log.e(TAG, "Failed to bypass hidden API restrictions", e);
        }
    }
}
