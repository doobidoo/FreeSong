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
    private static final String KEY_PAGE_TURNER_MODE = "page_turner_mode";

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
     * Get the page turner mode ("scroll" or "navigate").
     */
    public static String getPageTurnerMode(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getString(KEY_PAGE_TURNER_MODE, "scroll");
    }

    /**
     * Set the page turner mode ("scroll" or "navigate").
     */
    public static void setPageTurnerMode(Context context, String mode) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        prefs.edit().putString(KEY_PAGE_TURNER_MODE, mode).apply();
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
