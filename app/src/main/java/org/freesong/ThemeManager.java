package org.freesong;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;

/**
 * Manages app theme (light/dark mode) with persistence.
 */
public class ThemeManager {

    private static final String PREFS_NAME = "FreeSongPrefs";
    private static final String KEY_DARK_MODE = "dark_mode";
    private static final String KEY_SPEED_BAR_VISIBLE = "speed_bar_visible";

    public static boolean isDarkMode(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getBoolean(KEY_DARK_MODE, false);
    }

    public static void setDarkMode(Context context, boolean darkMode) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit().putBoolean(KEY_DARK_MODE, darkMode).apply();
    }

    public static void toggleDarkMode(Context context) {
        setDarkMode(context, !isDarkMode(context));
    }

    public static boolean isSpeedBarVisible(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getBoolean(KEY_SPEED_BAR_VISIBLE, true);
    }

    public static void setSpeedBarVisible(Context context, boolean visible) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit().putBoolean(KEY_SPEED_BAR_VISIBLE, visible).apply();
    }

    /**
     * Apply the current theme to an activity.
     * Must be called before setContentView() in onCreate().
     */
    public static void applyTheme(Activity activity) {
        if (isDarkMode(activity)) {
            activity.setTheme(R.style.AppTheme_Dark);
        } else {
            activity.setTheme(R.style.AppTheme_Light);
        }
    }

    /**
     * Apply fullscreen theme for song view.
     * Must be called before setContentView() in onCreate().
     */
    public static void applyFullscreenTheme(Activity activity) {
        if (isDarkMode(activity)) {
            activity.setTheme(R.style.AppTheme_Dark_Fullscreen);
        } else {
            activity.setTheme(R.style.AppTheme_Light_Fullscreen);
        }
    }
}
